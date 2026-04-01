package testing

import math  "core:math/linalg/glsl"
import rl    "vendor:raylib"
import vault "../_vault"
import data  "../modules/data"

calc_FPS :: proc(frame_time: i64) -> int {
    return int(1000000000 / frame_time)
}

// Future: volume interpolation for 8-corner cube
trilinear_interp :: proc(c: [8]f32, fx, fy, fz: f32) -> f32 {
    c00 := c[0]*(1-fx) + c[1]*fx;  c01 := c[2]*(1-fx) + c[3]*fx
    c10 := c[4]*(1-fx) + c[5]*fx;  c11 := c[6]*(1-fx) + c[7]*fx
    c0  := c00*(1-fy)  + c01*fy;   c1  := c10*(1-fy)  + c11*fy
    return c0*(1-fz) + c1*fz
}

// Future: orthographic projection mode
ortho_pixel_to_world :: proc(pixel_coords: math.vec2, width, height: int) -> math.vec3 {
    uv := math.vec2{pixel_coords.x / f32(width), pixel_coords.y / f32(height)}
    return math.vec3{uv.x, uv.y, (^math.vec3)(data.edit(vault.cam_pos)).z}
}

// ---- Bounds math ----

bounds_center :: proc(b: vault.Bounds) -> math.vec3 {
    return math.vec3{(b.x.min+b.x.max)*0.5, (b.y.min+b.y.max)*0.5, (b.z.min+b.z.max)*0.5}
}

bounds_contains :: proc(outer, inner: vault.Bounds) -> bool {
    return inner.x.min >= outer.x.min && inner.x.max <= outer.x.max &&
           inner.y.min >= outer.y.min && inner.y.max <= outer.y.max &&
           inner.z.min >= outer.z.min && inner.z.max <= outer.z.max
}

bounds_expand_parent :: proc(b: vault.Bounds) -> vault.Bounds {
    cx := (b.x.min+b.x.max)*0.5; cy := (b.y.min+b.y.max)*0.5; cz := (b.z.min+b.z.max)*0.5
    hw := (b.x.max-b.x.min)*8.0; hh := (b.y.max-b.y.min)*8.0; hd := (b.z.max-b.z.min)*8.0
    return vault.Bounds{
        x = {cx-hw, cx+hw}, y = {cy-hh, cy+hh}, z = {cz-hd, cz+hd},
    }
}

bounds_align_to_grid :: proc(b: vault.Bounds, levels: int) -> vault.Bounds {
    cell_size := (b.x.max - b.x.min) / f32(i32(1) << uint(levels))
    snap_down := proc(v, cell: f32) -> f32 { return math.floor_f32(v / cell) * cell }
    snap_up   :: proc(v, cell: f32) -> f32 { return math.ceil_f32(v  / cell) * cell }
    return vault.Bounds{
        x = {snap_down(b.x.min, cell_size), snap_up(b.x.max, cell_size)},
        y = {snap_down(b.y.min, cell_size), snap_up(b.y.max, cell_size)},
        z = {snap_down(b.z.min, cell_size), snap_up(b.z.max, cell_size)},
    }
}

// Tight bounds from a slice of world positions
bounds_from_positions :: proc(positions: []math.vec3) -> vault.Bounds {
    if len(positions) == 0 do return {}
    b := vault.Bounds{x = {positions[0].x, positions[0].x}, y = {positions[0].y, positions[0].y}, z = {positions[0].z, positions[0].z}}
    for p in positions[1:] {
        b.x.min = min(b.x.min, p.x); b.x.max = max(b.x.max, p.x)
        b.y.min = min(b.y.min, p.y); b.y.max = max(b.y.max, p.y)
        b.z.min = min(b.z.min, p.z); b.z.max = max(b.z.max, p.z)
    }
    return b
}

// ---- Field bit math ----

level_offset :: proc(level: i32, dims: int) -> i32 {
    if dims == 2 do return ((i32(1) << (uint(level)*2)) - 1) / 3
    if dims == 3 do return ((i32(1) << (uint(level)*3)) - 1) / 7
    offset, count: i32 = 0, 1
    for i in 0 ..< level { offset += count; count *= i32(1) << uint(dims) }
    return offset
}

total_cells :: proc(num_levels: int, dims: int) -> i32 { return level_offset(i32(num_levels), dims) }
bits_slots  :: proc(bit_count: i32)                   -> i32 { return (bit_count + 31) / 32 }

// ---- Cell indexing ----

cell_index :: proc(xyz: math.ivec3, level: int, dims: int) -> i32 {
    g := i32(1) << uint(level); h := g / 2
    x, y, z := xyz.x+h, xyz.y+h, xyz.z+h
    switch dims {
    case 1: return x
    case 2: return y*g + x
    case 3: return z*g*g + y*g + x
    }
    return 0
}

// dims-aware index → xyz
index_to_xyz :: proc(index: i32, level: int, dims: int) -> (xyz: math.ivec3) {
    g: i32 = 1 << uint(level); h := g / 2
    switch dims {
    case 1: xyz.x = index - h
    case 2: xyz.y = index/g - h; xyz.x = index%g - h
    case 3: xyz.z = index/(g*g) - h; xyz.y = (index/g)%g - h; xyz.x = index%g - h
    }
    return
}

cell_get :: proc(bits: []u32, level: int, index: i32, dims: int) -> bool {
    ai   := level_offset(i32(level), dims) + index
    slot := ai / 32
    if slot < 0 || int(slot) >= len(bits) do return false
    return (bits[slot] & (1 << u32(ai%32))) != 0
}

cell_set :: proc(bits: []u32, level: int, index: i32, dims: int, value: bool) {
    ai   := level_offset(i32(level), dims) + index
    slot := ai / 32
    if slot < 0 || int(slot) >= len(bits) do return
    bit := u32(1) << u32(ai%32)
    if value { bits[slot] |= bit } else { bits[slot] &= ~bit }
}

// ---- Cell spatial helpers ----

// Converts bbox (in field local space) to finest-level cell range
// Returns grid params needed for cell_index and field_cell_center
field_bbox_to_cell_range :: proc(field: ^vault.Field, bbox: vault.Bounds) -> (
    cx_min, cx_max, cy_min, cy_max, cz_min, cz_max: i32,
    grid_size, half: i32,
    cell_x, cell_y, cell_z: f32,
) {
    grid_size = i32(1) << uint(field.levels); half = grid_size / 2
    bx := field.bounds.x.max - field.bounds.x.min
    by := field.bounds.y.max - field.bounds.y.min
    bz := field.bounds.z.max - field.bounds.z.min
    cell_x = bx / f32(grid_size); cell_y = by / f32(grid_size); cell_z = bz / f32(grid_size)

    cx_min = clamp(i32(math.floor_f32((bbox.x.min - field.bounds.x.min) / bx * f32(grid_size))) - half, -half, half-1)
    cx_max = clamp(i32(math.ceil_f32( (bbox.x.max - field.bounds.x.min) / bx * f32(grid_size))) - half, -half, half-1)
    cy_min = clamp(i32(math.floor_f32((bbox.y.min - field.bounds.y.min) / by * f32(grid_size))) - half, -half, half-1)
    cy_max = clamp(i32(math.ceil_f32( (bbox.y.max - field.bounds.y.min) / by * f32(grid_size))) - half, -half, half-1)
    cz_min = clamp(i32(math.floor_f32((bbox.z.min - field.bounds.z.min) / bz * f32(grid_size))) - half, -half, half-1)
    cz_max = clamp(i32(math.ceil_f32( (bbox.z.max - field.bounds.z.min) / bz * f32(grid_size))) - half, -half, half-1)
    return
}

// World center position of a cell at finest level
field_cell_center :: proc(field: ^vault.Field, cx, cy, cz, half: i32, cell_x, cell_y, cell_z: f32) -> math.vec3 {
    return math.vec3{
        field.bounds.x.min + (f32(cx+half) + 0.5) * cell_x,
        field.bounds.y.min + (f32(cy+half) + 0.5) * cell_y,
        field.bounds.z.min + (f32(cz+half) + 0.5) * cell_z,
    }
}

// ---- Field ops ----

field_create :: proc(bounds: vault.Bounds, levels: int, dims: int) -> vault.Field {
    total := total_cells(levels+1, dims)
    field: vault.Field
    field.bounds   = bounds; field.levels = levels; field.dims = dims
    field.bits_any = make([dynamic]u32, bits_slots(total))
    field.bits_all = make([dynamic]u32, bits_slots(total))
    field.data     = make([dynamic][dynamic]i32, i32(1) << (uint(levels) * uint(dims)))
    return field
}

// Bottom-up propagation of bits_any through a single field
// With cell_bounds: also expands parent Bounds entries to cover child bounds (finest-level indexed)
field_propagate :: proc(field: ^vault.Field, cell_bounds: ^[dynamic]vault.Bounds = nil) {
    for level := field.levels - 1; level >= 0; level -= 1 {
        children_per := i32(1) << uint(field.dims)
        parent_count := i32(1) << (uint(field.dims) * uint(level))
        for pi in 0 ..< parent_count {
            first := pi * children_per
            for c in 0 ..< children_per {
                child_idx := first + i32(c)
                if !cell_get(field.bits_any[:], level+1, child_idx, field.dims) do continue
                cell_set(field.bits_any[:], level, i32(pi), field.dims, true)
                if cell_bounds != nil && int(child_idx) < len(cell_bounds) && int(pi) < len(cell_bounds) {
                    cb := cell_bounds[child_idx]; pb := &cell_bounds[pi]
                    pb.x.min = min(pb.x.min, cb.x.min); pb.x.max = max(pb.x.max, cb.x.max)
                    pb.y.min = min(pb.y.min, cb.y.min); pb.y.max = max(pb.y.max, cb.y.max)
                    pb.z.min = min(pb.z.min, cb.z.min); pb.z.max = max(pb.z.max, cb.z.max)
                }
                break
            }
        }
    }
}

// Prefetches bitfield into L1 cache before traversal
field_cache_warm :: proc(field: ^vault.Field) { for b in field.bits_any { _ = b } }

// ---- Transform ----

world_to_local :: proc(pos: math.vec3, t: vault.Transform) -> math.vec3 { return (pos - t.pos) / t.scale }
local_to_world :: proc(pos: math.vec3, t: vault.Transform) -> math.vec3 { return pos * t.scale + t.pos  }

// ---- Interpolation ----

// Generic NURBS-style inverse distance weighting
// query and sample_pos in same coordinate space
// out_pos and out_normal can be in a different space (e.g. world pos from screen-space query)
nurbs_interp :: proc(query: math.vec3, sample_pos, out_pos, out_normal: []math.vec3) -> (pos, normal: math.vec3) {
    total_weight := f32(0)
    for i in 0 ..< len(sample_pos) {
        d := math.length(query - sample_pos[i])
        w := 1.0 / max(d*d, 1e-6)
        pos    += out_pos[i]    * w
        normal += out_normal[i] * w
        total_weight += w
    }
    if total_weight > 0 {
        pos    /= total_weight
        normal  = math.normalize_vec3(normal / total_weight)
    }
    return
}

// ---- Projection ----

// Projects world position to screen pixel — ok=false if behind cam or out of bounds
project_to_screen :: proc(world_pos, cam_pos: math.vec3, tan_hfov, aspect: f64, screen_w, screen_h: int) -> (px, py: int, ok: bool) {
    if world_pos.z >= cam_pos.z do return 0, 0, false
    dist        := f64(cam_pos.z - world_pos.z)
    view_height := 2.0 * tan_hfov * dist
    view_width  := view_height * aspect
    ndc_x    := f64(world_pos.x - cam_pos.x) / (view_width  * 0.5)
    ndc_y    := f64(world_pos.y - cam_pos.y) / (view_height * 0.5)
    screen_x := int((ndc_x + 1.0) * 0.5 * f64(screen_w))
    screen_y := int((ndc_y + 1.0) * 0.5 * f64(screen_h))
    if screen_x < 0 || screen_x >= screen_w || screen_y < 0 || screen_y >= screen_h do return 0, 0, false
    return screen_x, screen_y, true
}

// ---- Surface ops ----

// Tests whether a surface (point + normal) passes through a cell of given size
surface_covers_cell :: proc(interp_pos, interp_normal, cell_center: math.vec3, cell_size: f32) -> bool {
    return abs(math.dot(cell_center - interp_pos, interp_normal)) <= cell_size * 0.5
}

// Populates a field from a polygon surface source
// For each polygon: computes cell bbox, steps cells, NURBS-interps surface, marks bits, optionally caches verts
field_model_populate :: proc(field: ^vault.Field, source: ^vault.Model_Source, transform: vault.Transform, cache: bool) {
    for i in 0 ..< len(source.polys) {
        poly := &source.polys[i]
        vc   := len(poly.source.vert_indices)
        if vc == 0 do continue

        // Pre-fetch vert data — all in world space
        world_pos := make([]math.vec3, vc); defer delete(world_pos)
        normals   := make([]math.vec3, vc); defer delete(normals)
        local_pos := make([]math.vec3, vc); defer delete(local_pos)
        for j in 0 ..< vc {
            v            := &source.verts[poly.source.vert_indices[j]]
            world_pos[j]  = v.source.pos
            normals[j]    = v.source.normal
            local_pos[j]  = world_to_local(v.source.pos, transform)
        }

        // bbox in local field space for cell range
        bbox := bounds_from_positions(local_pos)
        cx_min, cx_max, cy_min, cy_max, cz_min, cz_max, _, half, cell_x, cell_y, cell_z := field_bbox_to_cell_range(field, bbox)
        cell_size   := max(cell_x, max(cell_y, cell_z))
        z_max_iter  := cz_max if field.dims == 3 else cz_min

        for cz := cz_min; cz <= z_max_iter; cz += 1 {
            for cy := cy_min; cy <= cy_max; cy += 1 {
                for cx := cx_min; cx <= cx_max; cx += 1 {
                    lp := field_cell_center(field, cx, cy, cz, half, cell_x, cell_y, cell_z)
                    wp := local_to_world(lp, transform)

                    // Interp in world space — query = cell world center, sample from vert world positions
                    ip, in_ := nurbs_interp(wp, world_pos, world_pos, normals)
                    if !surface_covers_cell(ip, in_, wp, cell_size) do continue

                    flat_idx := cell_index(math.ivec3{cx, cy, cz}, field.levels, field.dims)
                    cell_set(field.bits_any[:], field.levels, flat_idx, field.dims, true)

                    if cache {
                        cached := vault.Vertex{source = {pos = ip, normal = in_, color = {1,1,1}}}
                        if len(field.data[flat_idx]) > 0 {
                            (^vault.Vertex)(vault.arrays[.Vertex][field.data[flat_idx][0]].data)^ = cached
                        } else {
                            meta := data.add(.Vertex, cached, "cell_cache")
                            append(&field.data[flat_idx], i32(meta.index))
                        }
                    }
                }
            }
        }
    }
    field_propagate(field)
}

// Maps occupied child field cells into parent field at matching resolution
// Clears old model entries, finds matching child level, transforms centers, marks parent cells
// data[cell][0] = Bounds index, data[cell][1..] = model indices
field_update_parent :: proc(parent: ^vault.Field, child: ^vault.Field, child_transform: vault.Transform, occupied_cells: ^[dynamic]i32, model_idx: i32) {
    parent_grid := i32(1) << uint(parent.levels)
    parent_cell_size := min(
        (parent.bounds.x.max - parent.bounds.x.min) / f32(parent_grid),
        min(
            (parent.bounds.y.max - parent.bounds.y.min) / f32(parent_grid),
            (parent.bounds.z.max - parent.bounds.z.min) / f32(parent_grid),
        ),
    )

    // Clear old occupied cells — remove this model's ref, preserve others and bounds
    for cell_idx in occupied_cells^ {
        if len(parent.data[cell_idx]) == 0 do continue
        new_data: [dynamic]i32
        append(&new_data, parent.data[cell_idx][0])  // preserve bounds ref
        for i in 1 ..< len(parent.data[cell_idx]) {
            if parent.data[cell_idx][i] != model_idx do append(&new_data, parent.data[cell_idx][i])
        }
        delete(parent.data[cell_idx])
        parent.data[cell_idx] = new_data
        if len(parent.data[cell_idx]) <= 1 {
            clear(&parent.data[cell_idx])
            cell_set(parent.bits_any[:], parent.levels, cell_idx, parent.dims, false)
        }
    }
    clear(occupied_cells)
    field_propagate(parent)

    // Find first child level whose cell size <= parent cell size
    child_level := child.levels
    for l := 0; l <= child.levels; l += 1 {
        child_grid := i32(1) << uint(l)
        cs := min(
            (child.bounds.x.max - child.bounds.x.min) / f32(child_grid),
            min(
                (child.bounds.y.max - child.bounds.y.min) / f32(child_grid),
                (child.bounds.z.max - child.bounds.z.min) / f32(child_grid),
            ),
        )
        if cs <= parent_cell_size { child_level = l; break }
    }

    child_grid := i32(1) << uint(child_level)
    child_half := child_grid / 2
    total      := i32(1)
    for _ in 0 ..< child.dims { total *= child_grid }

    parent_half := parent_grid / 2
    pbx := parent.bounds.x.max - parent.bounds.x.min
    pby := parent.bounds.y.max - parent.bounds.y.min
    pbz := parent.bounds.z.max - parent.bounds.z.min
    child_cell_x := (child.bounds.x.max - child.bounds.x.min) / f32(child_grid)
    child_cell_y := (child.bounds.y.max - child.bounds.y.min) / f32(child_grid)
    child_cell_z := (child.bounds.z.max - child.bounds.z.min) / f32(child_grid)

    for idx in 0 ..< total {
        if !cell_get(child.bits_any[:], child_level, idx, child.dims) do continue

        xyz := index_to_xyz(idx, child_level, child.dims)
        lp  := math.vec3{
            child.bounds.x.min + (f32(xyz.x+child_half) + 0.5) * child_cell_x,
            child.bounds.y.min + (f32(xyz.y+child_half) + 0.5) * child_cell_y,
            child.bounds.z.min + (f32(xyz.z+child_half) + 0.5) * child_cell_z,
        }
        wp := local_to_world(lp, child_transform)

        nx := (wp.x - parent.bounds.x.min) / pbx
        ny := (wp.y - parent.bounds.y.min) / pby
        nz := (wp.z - parent.bounds.z.min) / pbz

        cx := clamp(i32(math.floor_f32(nx * f32(parent_grid))) - parent_half, -parent_half, parent_half-1)
        cy := clamp(i32(math.floor_f32(ny * f32(parent_grid))) - parent_half, -parent_half, parent_half-1)
        cz := clamp(i32(math.floor_f32(nz * f32(parent_grid))) - parent_half, -parent_half, parent_half-1)
        if parent.dims < 3 do cz = -parent_half

        pidx := cell_index(math.ivec3{cx, cy, cz}, parent.levels, parent.dims)
        cell_set(parent.bits_any[:], parent.levels, pidx, parent.dims, true)

        if len(parent.data[pidx]) == 0 {
            bm := data.add(.Bounds, vault.Bounds{x={wp.x,wp.x}, y={wp.y,wp.y}, z={wp.z,wp.z}}, "cell_bounds")
            append(&parent.data[pidx], i32(bm.index))
            append(&parent.data[pidx], model_idx)
        } else {
            b := (^vault.Bounds)(data.edit(vault.Metadata{index = int(parent.data[pidx][0]), type_id = .Bounds, valid = true}))
            b.x.min = min(b.x.min, wp.x); b.x.max = max(b.x.max, wp.x)
            b.y.min = min(b.y.min, wp.y); b.y.max = max(b.y.max, wp.y)
            b.z.min = min(b.z.min, wp.z); b.z.max = max(b.z.max, wp.z)
            append(&parent.data[pidx], model_idx)
        }
        append(occupied_cells, pidx)
    }

    field_propagate(parent)
}
