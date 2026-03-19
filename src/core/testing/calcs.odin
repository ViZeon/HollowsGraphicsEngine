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

// TEMPORARY — reads from vault, use project_to_screen for new code
ortho_pixel_to_world :: proc(pixel_coords: math.vec2, width, height: int) -> math.vec3 {
    uv := math.vec2{pixel_coords.x / f32(width), pixel_coords.y / f32(height)}
    return math.vec3{uv.x, uv.y, (^math.vec3)(data.edit(vault.cam_pos)).z}
}

// TEMPORARY — reads from vault, use unproject_from_screen for new code
pixel_to_world_fov :: proc(pixel_coords: math.vec2, width, height: int) -> math.vec3 {
    cam_pos := (^math.vec3)(data.edit(vault.cam_pos))
    fov     := (^int)(data.edit(vault.fov))^
    return unproject_from_screen(int(pixel_coords.x), int(pixel_coords.y), cam_pos^, fov, width, height)
}

// TEMPORARY — reads from vault, use project_to_screen for new code
world_to_pixel :: proc(world_pos: math.vec3, width, height: int) -> (px, py: int, ok: bool) {
    cam_pos := (^math.vec3)(data.edit(vault.cam_pos))
    fov     := (^int)(data.edit(vault.fov))^
    return project_to_screen(world_pos, cam_pos^, fov, width, height)
}

// Stateless — projects world position to screen pixel
project_to_screen :: proc(world_pos, cam_pos: math.vec3, fov, width, height: int) -> (px, py: int, ok: bool) {
    if world_pos.z >= cam_pos.z do return 0, 0, false

    fov_rad     := f64(fov) * f64(math.PI) / 180.0
    dist        := f64(cam_pos.z - world_pos.z)
    view_height := 2.0 * math.tan(fov_rad / 2.0) * dist
    view_width  := view_height * (f64(width) / f64(height))

    ndc_x    := f64(world_pos.x - cam_pos.x) / (view_width  * 0.5)
    ndc_y    := f64(world_pos.y - cam_pos.y) / (view_height * 0.5)
    screen_x := int((ndc_x + 1.0) * 0.5 * f64(width))
    screen_y := int((ndc_y + 1.0) * 0.5 * f64(height))

    if screen_x < 0 || screen_x >= width || screen_y < 0 || screen_y >= height {
        return 0, 0, false
    }
    return screen_x, screen_y, true
}

// Stateless — reconstructs world position from pixel coords
unproject_from_screen :: proc(px, py: int, cam_pos: math.vec3, fov, width, height: int) -> math.vec3 {
    ndc_x := f64(f32(px) + 0.5) / f64(width)  * 2.0 - 1.0
    ndc_y := f64(f32(py) + 0.5) / f64(height) * 2.0 - 1.0

    fov_rad     := f64(fov) * f64(math.PI) / 180.0
    view_height := 2.0 * math.tan(fov_rad / 2.0) * f64(cam_pos.z)
    view_width  := view_height * (f64(width) / f64(height))

    return math.vec3{
        cam_pos.x + f32(ndc_x * view_width  * 0.5),
        cam_pos.y + f32(ndc_y * view_height * 0.5),
        cam_pos.z,
    }
}

// World-space size of one pixel at a given surface depth from camera
// Used to determine Hermite walk step size
pixel_world_size :: proc(cam_z, pos_z: f32, fov, screen_h: int) -> f32 {
    d := cam_z - pos_z
    if d <= 0 do return 0
    fov_rad := f64(fov) * f64(math.PI) / 180.0
    view_h  := f32(2.0 * math.tan(fov_rad / 2.0) * f64(d))
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
    grid_size := i32(1) << uint(level)
    half      := grid_size / 2
    return cell_index({cx - half, cy - half, 0}, level, 2)
}

screen_field_covered_early :: proc(field: ^vault.Field, local_px, local_py: f32) -> bool {
    bw := field.bounds.x.max - field.bounds.x.min
    bh := field.bounds.y.max - field.bounds.y.min
    nx := clamp((local_px - field.bounds.x.min) / bw, 0, 0.9999)
    ny := clamp((local_py - field.bounds.y.min) / bh, 0, 0.9999)

    for l in 0 ..< field.levels {
        gs   := i32(1) << uint(l)
        cx   := clamp(i32(math.floor_f32(nx * f32(gs))), 0, gs - 1)
        cy   := clamp(i32(math.floor_f32(ny * f32(gs))), 0, gs - 1)
        idx  := cell_idx_2d(cx, cy, l)
        if cell_get_all(field, l, idx) do return true
    }
    return false
}

// Propagates bits_any upward from a newly marked finest cell.
// bits_any parent = true if ANY child is set — so we always set the parent.
// Call after cell_set_field at finest level.
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

// Propagates bits_all upward from a newly marked finest cell.
// bits_all parent = true only if ALL children are set.
// Call after cell_set_field + screen_field_propagate_any at finest level.
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
                // BUG FIX: was cell_get_field (reads bits_any) — must read bits_all
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

// ---- Field math ----

level_offset :: proc(level: i32, dims: int) -> i32 {
    offset: i32 = 0
    count:  i32 = 1
    for i in 0 ..< level {
        offset += count
        count  *= i32(1) << uint(dims)
    }
    return offset
}

total_cells :: proc(num_levels: int, dims: int) -> i32 {
    total: i32 = 0
    count: i32 = 1
    for i in 0 ..< num_levels {
        total += count
        count *= i32(1) << uint(dims)
    }
    return total
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
