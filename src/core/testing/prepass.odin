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

    // FETCH ONCE PER FRAME
    nesting   := (^int)(data.edit(vault.screen_field_nesting))^
    cell_size := (^int)(data.edit(vault.screen_field_cell_size))^

    // PRE-CALCULATE TRIG: Remove from inner loops
    fov_rad      := f64(cam_fov) * f64(math.PI) / 180.0
    tan_half_fov := math.tan(fov_rad / 2.0)
    aspect       := f64(screen_w) / f64(screen_h)

    for i in 0 ..< len(vault.frame_pixels) {
        vault.frame_pixels[i] = 0
    }

    transform := vault.Transform{
        pos   = math.vec3{0, 0, 0},
        rot   = transmute(math.quat)[4]f32{0, 0, 0, 1},
        scale = math.vec3{1, 1, 1},
    }

    for dp_idx in 0 ..< len(vault.arrays[.DataPoint]) {
        meta := vault.meta_arrays[.DataPoint][dp_idx]
        if !meta.valid do continue
        dp := (^vault.DataPoint)(vault.arrays[.DataPoint][dp_idx].data)
        if dp.type != .Model do continue

        model     := (^vault.Model)(vault.arrays[.Model][dp.ref.index].data)
        face_list := (^vault.Face_List)(vault.arrays[.Face_List][model.face_list.index].data)

        for face in face_list.faces {
            prepass_process_face(face, transform, cam_pos, tan_half_fov, aspect, screen_w, screen_h, nesting, cell_size)
        }
    }
}

prepass_process_face :: proc(
    face:[3]i32,
    transform: vault.Transform,
    cam_pos:   math.vec3,
    tan_half_fov, aspect: f64,
    screen_w, screen_h, nesting, cell_size: int,
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
    n :=[3]math.vec3{
        apply_transform_normal(dp0.normal, transform),
        apply_transform_normal(dp1.normal, transform),
        apply_transform_normal(dp2.normal, transform),
    }

    if p[0].z >= cam_pos.z && p[1].z >= cam_pos.z && p[2].z >= cam_pos.z do return

    edge0       := p[1] - p[0]
    edge1       := p[2] - p[0]
    face_normal := math.normalize_vec3(vec3_cross(edge0, edge1))
    to_cam      := math.normalize_vec3(cam_pos - p[0])
    if math.dot(face_normal, to_cam) <= 0 do return

    avg_z := [3]f32{
        (p[0].z + p[1].z) * 0.5,
        (p[1].z + p[2].z) * 0.5,
        (p[2].z + p[0].z) * 0.5,
    }
    base := 0
    if avg_z[1] > avg_z[base] do base = 1
    if avg_z[2] > avg_z[base] do base = 2

    ia := base
    ib := (base + 1) % 3
    ic := (base + 2) % 3

    pa := p[ia]; na := n[ia]
    pb := p[ib]; nb := n[ib]
    pc := p[ic]; nc := n[ic]

    walk_edge(pa, na, pc, nc, cam_pos, tan_half_fov, aspect, screen_w, screen_h, nesting, cell_size)
    walk_edge(pb, nb, pc, nc, cam_pos, tan_half_fov, aspect, screen_w, screen_h, nesting, cell_size)

    ma_ab, mb_ab := edge_tangents(pa, na, pb, nb)

    t := f32(0)
    last_px, last_py := -1, -1

    for t <= 1.0001 {
        tc    := clamp(t, 0, 1)
        pos_e := hermite_pos(pa, ma_ab, pb, mb_ab, tc)
        norm_e := hermite_normal(na, nb, tc)

        px, py, edge_ok := project_to_screen(pos_e, cam_pos, tan_half_fov, aspect, screen_w, screen_h)
        
        // FILTER: Only touch the spatial grid if the pixel changed!
        if edge_ok && (px != last_px || py != last_py) {
            write_surface_pixel(px, py, pos_e, norm_e, screen_w, screen_h, nesting, cell_size)
            last_px = px
            last_py = py
        }

        walk_inward(pos_e, norm_e, pc, nc, cam_pos, tan_half_fov, aspect, screen_w, screen_h, nesting, cell_size)

        if t >= 1.0 do break
        tang     := hermite_tangent(pa, ma_ab, pb, mb_ab, tc)
        tang_len := math.length(tang)
        if tang_len < 1e-6 do break
        pws := pixel_world_size(cam_pos.z, pos_e.z, tan_half_fov, screen_h)
        if pws <= 0 do break
        dt := pws / tang_len
        t   = min(t + dt, 1.0001)
    }
}

walk_edge :: proc(
    pa, na, pb, nb: math.vec3,
    cam_pos: math.vec3,
    tan_half_fov, aspect: f64,
    screen_w, screen_h, nesting, cell_size: int,
) {
    ma, mb := edge_tangents(pa, na, pb, nb)
    t := f32(0)
    last_px, last_py := -1, -1

    for t <= 1.0001 {
        tc   := clamp(t, 0, 1)
        pos  := hermite_pos(pa, ma, pb, mb, tc)
        norm := hermite_normal(na, nb, tc)

        px, py, ok := project_to_screen(pos, cam_pos, tan_half_fov, aspect, screen_w, screen_h)
        
        // FILTER: Kill Sub-pixel Overdraw
        if ok && (px != last_px || py != last_py) {
            write_surface_pixel(px, py, pos, norm, screen_w, screen_h, nesting, cell_size)
            last_px = px
            last_py = py
        }

        if t >= 1.0 do break
        tang     := hermite_tangent(pa, ma, pb, mb, tc)
        tang_len := math.length(tang)
        if tang_len < 1e-6 do break
        pws := pixel_world_size(cam_pos.z, pos.z, tan_half_fov, screen_h)
        if pws <= 0 do break
        t = min(t + pws / tang_len, 1.0001)
    }
}

walk_inward :: proc(
    pe, ne, pc, nc: math.vec3,
    cam_pos: math.vec3,
    tan_half_fov, aspect: f64,
    screen_w, screen_h, nesting, cell_size: int,
) {
    me, mc := edge_tangents(pe, ne, pc, nc)
    t := f32(0)
    last_px, last_py := -1, -1

    for t <= 1.0001 {
        tc   := clamp(t, 0, 1)
        pos  := hermite_pos(pe, me, pc, mc, tc)
        norm := hermite_normal(ne, nc, tc)

        px, py, ok := project_to_screen(pos, cam_pos, tan_half_fov, aspect, screen_w, screen_h)
        
        // FILTER: Kill Sub-pixel Overdraw
        if ok && (px != last_px || py != last_py) {
            write_surface_pixel(px, py, pos, norm, screen_w, screen_h, nesting, cell_size)
            last_px = px
            last_py = py
        }

        if t >= 1.0 do break
        tang     := hermite_tangent(pe, me, pc, mc, tc)
        tang_len := math.length(tang)
        if tang_len < 1e-6 do break
        pws := pixel_world_size(cam_pos.z, pos.z, tan_half_fov, screen_h)
        if pws <= 0 do break
        t = min(t + pws / tang_len, 1.0001)
    }
}

write_surface_pixel :: proc(px, py: int, pos, normal: math.vec3, screen_w, screen_h, nesting, cell_size: int) {
    if !screen_pixel_mark(px, py, screen_w, screen_h, nesting, cell_size) do return
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

hermite_pos :: proc(pa, ma, pb, mb: math.vec3, t: f32) -> math.vec3 {
    t2 := t * t; t3 := t2 * t
    return pa*(2*t3 - 3*t2 + 1) + ma*(t3 - 2*t2 + t) + pb*(-2*t3 + 3*t2) + mb*(t3 - t2)
}

hermite_tangent :: proc(pa, ma, pb, mb: math.vec3, t: f32) -> math.vec3 {
    t2   := t * t
    return pa*(6*t2 - 6*t) + ma*(3*t2 - 4*t + 1) + pb*(-6*t2 + 6*t) + mb*(3*t2 - 2*t)
}

hermite_normal :: proc(na, nb: math.vec3, t: f32) -> math.vec3 {
    return math.normalize_vec3(na*(1-t) + nb*t)
}

edge_tangents :: proc(pa, na, pb, nb: math.vec3) -> (ma, mb: math.vec3) {
    chord := pb - pa
    if math.length(chord) < 1e-6 do return chord, chord
    ma = chord - math.dot(chord, na) * na
    mb = chord - math.dot(chord, nb) * nb
    if math.length(ma) < 1e-6 do ma = chord
    if math.length(mb) < 1e-6 do mb = chord
    return
}

vec3_cross :: proc(a, b: math.vec3) -> math.vec3 {
    return math.vec3{a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x}
}

apply_transform :: proc(pos: math.vec3, t: vault.Transform) -> math.vec3 { return pos * t.scale + t.pos }
apply_transform_normal :: proc(normal: math.vec3, t: vault.Transform) -> math.vec3 { return normal }