package testing

import math  "core:math/linalg/glsl"
import rl    "vendor:raylib"
import vault "../_vault"
import data  "../modules/data"
import "core:fmt"

calc_FPS :: proc(frame_time: i64) -> int {
    return int(1000000000 / frame_time)
}

trilinear_interp :: proc(c: [8]f32, fx, fy, fz: f32) -> f32 {
    c00 := c[0] * (1 - fx) + c[1] * fx
    c01 := c[2] * (1 - fx) + c[3] * fx
    c10 := c[4] * (1 - fx) + c[5] * fx
    c11 := c[6] * (1 - fx) + c[7] * fx
    c0  := c00 * (1 - fy) + c01 * fy
    c1  := c10 * (1 - fy) + c11 * fy
    return c0 * (1 - fz) + c1 * fz
}

ortho_pixel_to_world :: proc(pixel_coords: math.vec2, width, height: int) -> math.vec3 {
    uv := math.vec2{pixel_coords.x / f32(width), pixel_coords.y / f32(height)}
    return math.vec3{uv.x, uv.y, (^math.vec3)(data.edit(vault.cam_pos)).z}
}

pixel_to_world_fov :: proc(pixel_coords: math.vec2, width, height: int) -> math.vec3 {
    cam_pos := (^math.vec3)(data.edit(vault.cam_pos))
    fov     := (^int)(data.edit(vault.fov))^
    fov_rad := f64(fov) * f64(math.PI) / 180.0
    return unproject_from_screen(int(pixel_coords.x), int(pixel_coords.y), cam_pos^, math.tan(fov_rad / 2.0), f64(width)/f64(height), width, height)
}

world_to_pixel :: proc(world_pos: math.vec3, width, height: int) -> (px, py: int, ok: bool) {
    cam_pos := (^math.vec3)(data.edit(vault.cam_pos))
    fov     := (^int)(data.edit(vault.fov))^
    fov_rad := f64(fov) * f64(math.PI) / 180.0
    return project_to_screen(world_pos, cam_pos^, math.tan(fov_rad / 2.0), f64(width)/f64(height), width, height)
}

project_to_screen :: proc(world_pos, cam_pos: math.vec3, tan_half_fov, aspect: f64, width, height: int) -> (px, py: int, ok: bool) {
    if world_pos.z >= cam_pos.z do return 0, 0, false

    dist        := f64(cam_pos.z - world_pos.z)
    view_height := 2.0 * tan_half_fov * dist
    view_width  := view_height * aspect

    ndc_x    := f64(world_pos.x - cam_pos.x) / (view_width  * 0.5)
    ndc_y    := f64(world_pos.y - cam_pos.y) / (view_height * 0.5)
    screen_x := int((ndc_x + 1.0) * 0.5 * f64(width))
    screen_y := int((ndc_y + 1.0) * 0.5 * f64(height))

    if screen_x < 0 || screen_x >= width || screen_y < 0 || screen_y >= height {
        return 0, 0, false
    }
    return screen_x, screen_y, true
}

unproject_from_screen :: proc(px, py: int, cam_pos: math.vec3, tan_half_fov, aspect: f64, width, height: int) -> math.vec3 {
    ndc_x := f64(f32(px) + 0.5) / f64(width)  * 2.0 - 1.0
    ndc_y := f64(f32(py) + 0.5) / f64(height) * 2.0 - 1.0

    view_height := 2.0 * tan_half_fov * f64(cam_pos.z)
    view_width  := view_height * aspect

    return math.vec3{
        cam_pos.x + f32(ndc_x * view_width  * 0.5),
        cam_pos.y + f32(ndc_y * view_height * 0.5),
        cam_pos.z,
    }
}

pixel_world_size :: proc(cam_z, pos_z: f32, tan_half_fov: f64, screen_h: int) -> f32 {
    d := cam_z - pos_z
    if d <= 0 do return 0
    view_h  := f32(2.0 * tan_half_fov * f64(d))
    return view_h / f32(screen_h)
}

// ---- Screen field coordinate helpers ----

screen_pixel_to_cell_2d :: proc(local_px, local_py: f32, bounds: vault.Bounds, levels: int) -> (cx, cy: i32) {
    bw       := bounds.x.max - bounds.x.min
    bh       := bounds.y.max - bounds.y.min
    nx       := clamp((local_px - bounds.x.min) / bw, 0, 0.9999)
    ny       := clamp((local_py - bounds.y.min) / bh, 0, 0.9999)
    grid_1d  := i32(1) << uint(levels)
    cx        = i32(math.floor_f32(nx * f32(grid_1d)))
    cy        = i32(math.floor_f32(ny * f32(grid_1d)))
    cx        = clamp(cx, 0, grid_1d - 1)
    cy        = clamp(cy, 0, grid_1d - 1)
    return
}

cell_idx_2d :: proc(cx, cy: i32, level: int) -> i32 {
    return cy * (i32(1) << uint(level)) + cx
}

screen_field_propagate_any :: proc(field: ^vault.Field, cx_finest, cy_finest: i32) {
    cx := cx_finest
    cy := cy_finest
    for l := field.levels - 1; l >= 0; l -= 1 {
        pcx  := cx / 2
        pcy  := cy / 2
        pidx := cell_idx_2d(pcx, pcy, l)
        cell_set_field(field, l, pidx, true)
        cx = pcx
        cy = pcy
    }
}

screen_field_propagate_all :: proc(field: ^vault.Field, cx_finest, cy_finest: i32) {
    cx := cx_finest
    cy := cy_finest
    for l := field.levels - 1; l >= 0; l -= 1 {
        pcx := cx / 2
        pcy := cy / 2
        child_l  := l + 1
        all_set  := true
        for dy in i32(0) ..< 2 {
            for dx in i32(0) ..< 2 {
                cidx := cell_idx_2d(pcx*2 + dx, pcy*2 + dy, child_l)
                if !cell_get_all(field, child_l, cidx) {
                    all_set = false
                    break
                }
            }
            if !all_set do break
        }
        pidx := cell_idx_2d(pcx, pcy, l)
        if all_set {
            cell_set_all(field, l, pidx, true)
            cx = pcx
            cy = pcy
        } else {
            break
        }
    }
}

// OPTIMIZED: Direct spatial lookup, bypassing top-down looping
screen_pixel_mark :: proc(px, py, screen_w, screen_h, nesting, cell_size: int) -> bool {
    if len(vault.screen_field_ids) == 0 do return true

    levels := 0
    cs     := 1
    for cs < cell_size { cs *= 4; levels += 1 }
    grid_1d := i32(1) << uint(levels)

    MAX_NESTING :: 8
    nest_field_idx: [MAX_NESTING]int
    nest_cx:        [MAX_NESTING]i32
    nest_cy:[MAX_NESTING]i32

    local_px    := f32(px)
    local_py    := f32(py)
    parent_flat := 0

    for nest in 0 ..< nesting {
        field_vault_idx := int(vault.screen_field_ids[nest]) + (nest == 0 ? 0 : parent_flat)
        if field_vault_idx >= len(vault.arrays[.Field]) do return true

        field := (^vault.Field)(vault.arrays[.Field][field_vault_idx].data)

        cx, cy     := screen_pixel_to_cell_2d(local_px, local_py, field.bounds, field.levels)
        finest_idx := cell_idx_2d(cx, cy, field.levels)
        cell_flat  := int(cy) * int(grid_1d) + int(cx)

        nest_field_idx[nest] = field_vault_idx
        nest_cx[nest]        = cx
        nest_cy[nest]        = cy

        if nest == nesting - 1 {
            // FAST PATH: $O(1) Direct Lookup to see if finest cell is already painted!
            if cell_get_field(field, field.levels, finest_idx) do return false

            cell_set_field(field, field.levels, finest_idx, true)

            screen_field_propagate_any(field, cx, cy)
            screen_field_propagate_all(field, cx, cy)

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
            // SPATIAL CULLING: If the whole parent cell is full, skip going deeper!
            if cell_get_all(field, field.levels, finest_idx) do return false

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

// ---- Field math ----

level_offset :: proc(level: i32, dims: int) -> i32 {
    if dims == 2 {
        return ((i32(1) << (uint(level) * 2)) - 1) / 3
    } else if dims == 3 {
        return ((i32(1) << (uint(level) * 3)) - 1) / 7
    }
    
    offset: i32 = 0
    count:  i32 = 1
    for i in 0 ..< level {
        offset += count
        count  *= i32(1) << uint(dims)
    }
    return offset
}

total_cells :: proc(num_levels: int, dims: int) -> i32 {
    return level_offset(i32(num_levels), dims)
}

cell_index :: proc(xyz: math.ivec3, level: int, dims: int) -> i32 {
    grid_size := i32(1) << uint(level)
    half      := grid_size / 2
    x := xyz.x + half
    y := xyz.y + half
    z := xyz.z + half
    switch dims {
    case 1: return x
    case 2: return y * grid_size + x
    case 3: return z * grid_size * grid_size + y * grid_size + x
    }
    return 0
}

xyz_to_index :: proc(xyz: math.ivec3, level: int) -> i32 {
    return cell_index(xyz, level, 3)
}

index_to_xyz :: proc(index: i32, level: int) -> (xyz: math.ivec3) {
    grid_size: i32 = 1 << uint(level)
    xyz.z = index / (grid_size * grid_size)
    xyz.y = (index / grid_size) % grid_size
    xyz.x = index % grid_size
    half  := grid_size / 2
    xyz.x -= half
    xyz.y -= half
    xyz.z -= half
    return
}

parent_index      :: proc(child_index: int)  -> int { return child_index / 8 }
first_child_index :: proc(parent_index: int) -> int { return parent_index * 8 }

cell_get_field :: proc(field: ^vault.Field, level: int, index: i32) -> bool {
    absolute_index := level_offset(i32(level), field.dims) + index
    slot           := absolute_index / 32
    if slot < 0 || int(slot) >= len(field.bits_any) do return false
    bit := u32(absolute_index % 32)
    return (field.bits_any[slot] & (1 << bit)) != 0
}

cell_set_field :: proc(field: ^vault.Field, level: int, index: i32, value: bool) {
    absolute_index := level_offset(i32(level), field.dims) + index
    slot           := absolute_index / 32
    if slot < 0 || int(slot) >= len(field.bits_any) do return
    bit := u32(absolute_index % 32)
    if value {
        field.bits_any[slot] |= (1 << bit)
    } else {
        field.bits_any[slot] &= ~(1 << bit)
    }
}

cell_get_all :: proc(field: ^vault.Field, level: int, index: i32) -> bool {
    absolute_index := level_offset(i32(level), field.dims) + index
    slot           := absolute_index / 32
    if slot < 0 || int(slot) >= len(field.bits_all) do return false
    bit := u32(absolute_index % 32)
    return (field.bits_all[slot] & (1 << bit)) != 0
}

cell_set_all :: proc(field: ^vault.Field, level: int, index: i32, value: bool) {
    absolute_index := level_offset(i32(level), field.dims) + index
    slot           := absolute_index / 32
    if slot < 0 || int(slot) >= len(field.bits_all) do return
    bit := u32(absolute_index % 32)
    if value {
        field.bits_all[slot] |= (1 << bit)
    } else {
        field.bits_all[slot] &= ~(1 << bit)
    }
}

field_cache_warm :: proc(field: ^vault.Field) {
    for b in field.bits_any { _ = b }
}