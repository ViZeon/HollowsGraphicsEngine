package testing

import vault "../_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"

// ============================================================
// PREPASS — face-driven Hermite surface walk
//
// For each face: walks edges and face interior in 3D world space
// using cubic Hermite curves (pos + normal as tangent).
// Each step projects to its screen pixel — no 2D interpolation.
// Step size = pixel footprint at current surface depth.
// Boundary edges are walked for all 3 edges.
// Face interior: each base edge point spawns an inward walk toward
// opposite vert. Base edge = closest to camera (highest avg Z).
// Adjacent faces share an edge — identical walk → no seams.
// ============================================================

prepass_run :: proc(screen_w, screen_h: int) {
    cam_pos := (^math.vec3)(data.edit(vault.cam_pos))^
    cam_fov := (^int)(data.edit(vault.fov))^

    for i in 0 ..< len(vault.frame_pixels) {
        vault.frame_pixels[i] = 0
    }

    // TODO: per-instance transforms via Model_Cache iteration
    // For now: identity transform, all instances share one transform
    transform := vault.Transform{
        pos   = math.vec3{0, 0, 0},
       rot   = transmute(math.quat)[4]f32{0, 0, 0, 1},
        scale = math.vec3{1, 1, 1},
    }

    // Iterate DataPoints of type .Model — each ref indexes vault.arrays[.Model]
    for dp_idx in 0 ..< len(vault.arrays[.DataPoint]) {
        meta := vault.meta_arrays[.DataPoint][dp_idx]
        if !meta.valid do continue
        dp := (^vault.DataPoint)(vault.arrays[.DataPoint][dp_idx].data)
        if dp.type != .Model do continue

        model     := (^vault.Model)(vault.arrays[.Model][dp.ref.index].data)
        face_list := (^vault.Face_List)(vault.arrays[.Face_List][model.face_list.index].data)

        for face in face_list.faces {
            prepass_process_face(face, transform, cam_pos, cam_fov, screen_w, screen_h)
        }
    }
}

// Processes one face: backface cull, find base edge, walk all edges + fill
prepass_process_face :: proc(
    face:      [3]i32,
    transform: vault.Transform,
    cam_pos:   math.vec3,
    cam_fov:   int,
    screen_w, screen_h: int,
) {
    dp_count := len(vault.arrays[.DataPoint])
    if int(face[0]) >= dp_count || int(face[1]) >= dp_count || int(face[2]) >= dp_count do return

    dp0 := (^vault.DataPoint)(vault.arrays[.DataPoint][face[0]].data)
    dp1 := (^vault.DataPoint)(vault.arrays[.DataPoint][face[1]].data)
    dp2 := (^vault.DataPoint)(vault.arrays[.DataPoint][face[2]].data)

    p := [3]math.vec3{
        apply_transform(dp0.pos, transform),
        apply_transform(dp1.pos, transform),
        apply_transform(dp2.pos, transform),
    }
    n := [3]math.vec3{
        apply_transform_normal(dp0.normal, transform),
        apply_transform_normal(dp1.normal, transform),
        apply_transform_normal(dp2.normal, transform),
    }

    // Quick z-cull: skip if all verts behind camera
    if p[0].z >= cam_pos.z && p[1].z >= cam_pos.z && p[2].z >= cam_pos.z do return

    // Backface cull using face normal
    edge0       := p[1] - p[0]
    edge1       := p[2] - p[0]
    face_normal := math.normalize_vec3(vec3_cross(edge0, edge1))
    to_cam      := math.normalize_vec3(cam_pos - p[0])
    if math.dot(face_normal, to_cam) <= 0 do return

    // Base edge = closest to camera = highest average Z
    avg_z := [3]f32{
        (p[0].z + p[1].z) * 0.5,
        (p[1].z + p[2].z) * 0.5,
        (p[2].z + p[0].z) * 0.5,
    }
    base := 0
    if avg_z[1] > avg_z[base] do base = 1
    if avg_z[2] > avg_z[base] do base = 2

    // Reorder: pa/pb = base edge verts, pc = opposite vert
    ia := base
    ib := (base + 1) % 3
    ic := (base + 2) % 3

    pa := p[ia]; na := n[ia]
    pb := p[ib]; nb := n[ib]
    pc := p[ic]; nc := n[ic]

    // Walk the two non-base edges for boundary coverage
    walk_edge(pa, na, pc, nc, cam_pos, cam_fov, screen_w, screen_h)
    walk_edge(pb, nb, pc, nc, cam_pos, cam_fov, screen_w, screen_h)

    // Walk base edge — each step also spawns inward fill toward pc
    ma_ab, mb_ab := edge_tangents(pa, na, pb, nb)

    t := f32(0)
    for t <= 1.0001 {
        tc    := clamp(t, 0, 1)
        pos_e := hermite_pos(pa, ma_ab, pb, mb_ab, tc)
        norm_e := hermite_normal(na, nb, tc)

        // Write base edge pixel
        px, py, edge_ok := project_to_screen(pos_e, cam_pos, cam_fov, screen_w, screen_h)
        if edge_ok {
            write_surface_pixel(px, py, pos_e, norm_e, screen_w, screen_h)
        }

        // Inward walk from this edge point toward pc
        walk_inward(pos_e, norm_e, pc, nc, cam_pos, cam_fov, screen_w, screen_h)

        if t >= 1.0 do break
        tang     := hermite_tangent(pa, ma_ab, pb, mb_ab, tc)
        tang_len := math.length(tang)
        if tang_len < 1e-6 do break
        pws := pixel_world_size(cam_pos.z, pos_e.z, cam_fov, screen_h)
        if pws <= 0 do break
        dt := pws / tang_len
        t   = min(t + dt, 1.0001)
    }
}

// Walks edge A→B as Hermite curve, writes each step to its screen pixel
walk_edge :: proc(
    pa, na, pb, nb: math.vec3,
    cam_pos: math.vec3,
    cam_fov, screen_w, screen_h: int,
) {
    ma, mb := edge_tangents(pa, na, pb, nb)
    t := f32(0)
    for t <= 1.0001 {
        tc   := clamp(t, 0, 1)
        pos  := hermite_pos(pa, ma, pb, mb, tc)
        norm := hermite_normal(na, nb, tc)

        px, py, ok := project_to_screen(pos, cam_pos, cam_fov, screen_w, screen_h)
        if ok do write_surface_pixel(px, py, pos, norm, screen_w, screen_h)

        if t >= 1.0 do break
        tang     := hermite_tangent(pa, ma, pb, mb, tc)
        tang_len := math.length(tang)
        if tang_len < 1e-6 do break
        pws := pixel_world_size(cam_pos.z, pos.z, cam_fov, screen_h)
        if pws <= 0 do break
        t = min(t + pws / tang_len, 1.0001)
    }
}

// Walks from a base edge point inward toward opposite vert pc
// Normal interpolated between edge normal and nc across the inward path
walk_inward :: proc(
    pe, ne, pc, nc: math.vec3,
    cam_pos: math.vec3,
    cam_fov, screen_w, screen_h: int,
) {
    me, mc := edge_tangents(pe, ne, pc, nc)
    t := f32(0)
    for t <= 1.0001 {
        tc   := clamp(t, 0, 1)
        pos  := hermite_pos(pe, me, pc, mc, tc)
        norm := hermite_normal(ne, nc, tc)

        px, py, ok := project_to_screen(pos, cam_pos, cam_fov, screen_w, screen_h)
        if ok do write_surface_pixel(px, py, pos, norm, screen_w, screen_h)

        if t >= 1.0 do break
        tang     := hermite_tangent(pe, me, pc, mc, tc)
        tang_len := math.length(tang)
        if tang_len < 1e-6 do break
        pws := pixel_world_size(cam_pos.z, pos.z, cam_fov, screen_h)
        if pws <= 0 do break
        t = min(t + pws / tang_len, 1.0001)
    }
}

// Writes a shaded pixel if not already covered by screen field
write_surface_pixel :: proc(px, py: int, pos, normal: math.vec3, screen_w, screen_h: int) {
    if !screen_pixel_mark(px, py, screen_w, screen_h) do return
    proxy := vault.DataPoint{
        pos    = pos,
        normal = normal,
        type   = .Vertex,
        ref    = vault.REF_INVALID,
    }
    color   := cpu_fragment_shader(&proxy)
    buf_idx := (py * screen_w + px) * 3
    vault.frame_pixels[buf_idx + 0] = u8(color.x)
    vault.frame_pixels[buf_idx + 1] = u8(color.y)
    vault.frame_pixels[buf_idx + 2] = u8(color.z)
}

// ---- Hermite curve math ----

// Cubic Hermite position at t in [0,1]
// pa, pb: endpoint positions — ma, mb: tangent vectors at each endpoint
hermite_pos :: proc(pa, ma, pb, mb: math.vec3, t: f32) -> math.vec3 {
    t2 := t * t
    t3 := t2 * t
    h00 := 2*t3 - 3*t2 + 1
    h10 := t3 - 2*t2 + t
    h01 := -2*t3 + 3*t2
    h11 := t3 - t2
    return pa*h00 + ma*h10 + pb*h01 + mb*h11
}

// Cubic Hermite tangent (derivative of hermite_pos) at t
hermite_tangent :: proc(pa, ma, pb, mb: math.vec3, t: f32) -> math.vec3 {
    t2   := t * t
    dh00 := 6*t2 - 6*t
    dh10 := 3*t2 - 4*t + 1
    dh01 := -6*t2 + 6*t
    dh11 := 3*t2 - 2*t
    return pa*dh00 + ma*dh10 + pb*dh01 + mb*dh11
}

// Interpolated surface normal at t — linear blend normalized
// Preserves surface curvature from normal field
hermite_normal :: proc(na, nb: math.vec3, t: f32) -> math.vec3 {
    return math.normalize_vec3(na*(1-t) + nb*t)
}

// Derives Hermite tangent vectors from an edge's positions and normals.
// Projects the chord direction onto the tangent plane at each endpoint.
// This makes the curve arrive/leave tangent to the local surface.
edge_tangents :: proc(pa, na, pb, nb: math.vec3) -> (ma, mb: math.vec3) {
    chord := pb - pa
    if math.length(chord) < 1e-6 do return chord, chord

    ma = chord - math.dot(chord, na) * na
    mb = chord - math.dot(chord, nb) * nb

    // Fallback: if tangent collapses (chord nearly parallel to normal), use chord
    if math.length(ma) < 1e-6 do ma = chord
    if math.length(mb) < 1e-6 do mb = chord
    return
}

// Cross product (not in glsl import directly accessible — local helper)
vec3_cross :: proc(a, b: math.vec3) -> math.vec3 {
    return math.vec3{
        a.y*b.z - a.z*b.y,
        a.z*b.x - a.x*b.z,
        a.x*b.y - a.y*b.x,
    }
}

// ---- Screen field coverage ----

// Marks pixel as covered. Returns true if newly covered, false if already covered.
// BUG FIX 1: bits_any now propagated upward via screen_field_propagate_any
// BUG FIX 2: bits_all propagation fixed in screen_field_propagate_all (uses cell_get_all not cell_get_field)
screen_pixel_mark :: proc(px, py, screen_w, screen_h: int) -> bool {
    if len(vault.screen_field_ids) == 0 do return true

    nesting   := (^int)(data.edit(vault.screen_field_nesting))^
    cell_size := (^int)(data.edit(vault.screen_field_cell_size))^

    levels := 0
    cs     := 1
    for cs < cell_size { cs *= 4; levels += 1 }
    grid_1d := i32(1) << uint(levels)

    MAX_NESTING :: 8
    nest_field_idx: [MAX_NESTING]int
    nest_cx:        [MAX_NESTING]i32
    nest_cy:        [MAX_NESTING]i32

    local_px    := f32(px)
    local_py    := f32(py)
    parent_flat := 0

    for nest in 0 ..< nesting {
        field_vault_idx := int(vault.screen_field_ids[nest]) + (nest == 0 ? 0 : parent_flat)
        if field_vault_idx >= len(vault.arrays[.Field]) do return true

        field := (^vault.Field)(vault.arrays[.Field][field_vault_idx].data)

        if screen_field_covered_early(field, local_px, local_py) do return false

        cx, cy     := screen_pixel_to_cell_2d(local_px, local_py, field.bounds, field.levels)
        finest_idx := cell_idx_2d(cx, cy, field.levels)
        cell_flat  := int(cy) * int(grid_1d) + int(cx)

        nest_field_idx[nest] = field_vault_idx
        nest_cx[nest]        = cx
        nest_cy[nest]        = cy

        if nest == nesting - 1 {
            if cell_get_field(field, field.levels, finest_idx) do return false
            cell_set_field(field, field.levels, finest_idx, true)

            // Propagate within this Field — bits_any first, then bits_all
            screen_field_propagate_any(field, cx, cy)
            screen_field_propagate_all(field, cx, cy)

            // Propagate upward through parent nesting levels
            for n := nest - 1; n >= 0; n -= 1 {
                parent_field := (^vault.Field)(vault.arrays[.Field][nest_field_idx[n]].data)
                pcx  := nest_cx[n]
                pcy  := nest_cy[n]
                pidx := cell_idx_2d(pcx, pcy, parent_field.levels)

                cell_set_field(parent_field, parent_field.levels, pidx, true)
                screen_field_propagate_any(parent_field, pcx, pcy)
                screen_field_propagate_all(parent_field, pcx, pcy)

                if !cell_get_all(parent_field, 0, 0) do break
            }

            return true
        } else {
            bw     := field.bounds.x.max - field.bounds.x.min
            bh     := field.bounds.y.max - field.bounds.y.min
            cell_w := bw / f32(grid_1d)
            cell_h := bh / f32(grid_1d)
            local_px    -= f32(cx) * cell_w
            local_py    -= f32(cy) * cell_h
            parent_flat  = parent_flat * cell_size + cell_flat
        }
    }

    return false
}

// ---- Transform helpers ----

apply_transform :: proc(pos: math.vec3, t: vault.Transform) -> math.vec3 {
    return pos * t.scale + t.pos
}

apply_transform_normal :: proc(normal: math.vec3, t: vault.Transform) -> math.vec3 {
    return normal
}

// ============================================================
// OLD VERT-DRIVEN PREPASS — kept for reference, not called
// Remove when face walk is confirmed stable
// ============================================================

/*
prepass_run_verts :: proc(screen_w, screen_h: int) {
    cam_pos := (^math.vec3)(data.edit(vault.cam_pos))^
    cam_fov := (^int)(data.edit(vault.fov))^

    for i in 0 ..< len(vault.frame_pixels) {
        vault.frame_pixels[i] = 0
    }

    for fi in 0 ..< len(vault.meta_arrays[.Field]) {
        meta := vault.meta_arrays[.Field][fi]
        if !meta.valid || meta.name != "model_field" do continue
        transform := vault.Transform{
            pos   = math.vec3{0, 0, 0},
            rot   = transmute(math.quat)[4]f32{0, 0, 0, 1},
            scale = math.vec3{1, 1, 1},
        }
        prepass_process_model(transform, cam_pos, cam_fov, screen_w, screen_h)
    }
}

prepass_process_model :: proc(
    transform: vault.Transform,
    cam_pos:   math.vec3,
    cam_fov:   int,
    screen_w, screen_h: int,
) {
    dp_count := len(vault.arrays[.DataPoint])
    for dp_idx in 0 ..< dp_count {
        meta := vault.meta_arrays[.DataPoint][dp_idx]
        if !meta.valid do continue
        dp := (^vault.DataPoint)(vault.arrays[.DataPoint][dp_idx].data)
        if dp.type != .Vertex do continue

        pos    := apply_transform(dp.pos, transform)
        normal := apply_transform_normal(dp.normal, transform)

        to_cam := math.normalize_vec3(cam_pos - pos)
        if math.dot(normal, to_cam) <= 0 do continue

        px, py, ok := project_to_screen(pos, cam_pos, cam_fov, screen_w, screen_h)
        if !ok do continue

        if dp.ref.index < 0 do continue
        cache := (^vault.Vertex_Cache)(vault.arrays[.Vertex_Cache][dp.ref.index].data)

        prepass_write_pixel(px, py, dp_idx, pos, normal, cache, transform, cam_pos, cam_fov, screen_w, screen_h)

        for n_ref in cache.neighbors {
            if int(n_ref.index) >= dp_count do continue
            n_dp  := (^vault.DataPoint)(vault.arrays[.DataPoint][n_ref.index].data)
            n_pos := apply_transform(n_dp.pos, transform)
            n_px, n_py, n_ok := project_to_screen(n_pos, cam_pos, cam_fov, screen_w, screen_h)
            if !n_ok do continue
            prepass_write_pixel(n_px, n_py, dp_idx, pos, normal, cache, transform, cam_pos, cam_fov, screen_w, screen_h)
        }
    }
}

prepass_write_pixel :: proc(
    px, py:    int,
    src_idx:   int,
    src_pos:   math.vec3,
    src_norm:  math.vec3,
    cache:     ^vault.Vertex_Cache,
    transform: vault.Transform,
    cam_pos:   math.vec3,
    cam_fov:   int,
    screen_w, screen_h: int,
) {
    if !screen_pixel_mark(px, py, screen_w, screen_h) do return

    dp_count    := len(vault.arrays[.DataPoint])
    pixel_world := unproject_from_screen(px, py, cam_pos, cam_fov, screen_w, screen_h)

    total_w     := f32(0)
    interp_pos  := math.vec3{0, 0, 0}
    interp_norm := math.vec3{0, 0, 0}

    self_d := math.length(pixel_world - src_pos)
    self_w := f32(1.0) / (self_d + 0.0001)
    interp_pos  += src_pos  * self_w
    interp_norm += src_norm * self_w
    total_w     += self_w

    for n_ref in cache.neighbors {
        if int(n_ref.index) >= dp_count do continue
        n_dp   := (^vault.DataPoint)(vault.arrays[.DataPoint][n_ref.index].data)
        n_pos  := apply_transform(n_dp.pos, transform)
        n_norm := apply_transform_normal(n_dp.normal, transform)
        n_d    := math.length(pixel_world - n_pos)
        n_w    := f32(1.0) / (n_d + 0.0001)
        interp_pos  += n_pos  * n_w
        interp_norm += n_norm * n_w
        total_w     += n_w
    }

    if total_w > 0 {
        interp_pos  /= total_w
        interp_norm  = math.normalize_vec3(interp_norm / total_w)
    }

    proxy := vault.DataPoint{
        pos    = interp_pos,
        normal = interp_norm,
        type   = .Vertex,
        ref    = vault.REF_INVALID,
    }
    color   := cpu_fragment_shader(&proxy)
    buf_idx := (py * screen_w + px) * 3
    vault.frame_pixels[buf_idx + 0] = u8(color.x)
    vault.frame_pixels[buf_idx + 1] = u8(color.y)
    vault.frame_pixels[buf_idx + 2] = u8(color.z)
}
*/
