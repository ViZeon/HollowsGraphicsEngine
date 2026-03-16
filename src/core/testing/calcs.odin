package testing

import math "core:math/linalg/glsl"
import rl   "vendor:raylib"
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

    ndc_x := f64(pixel_coords.x / f32(width))  * 2.0 - 1.0
    ndc_y := f64(pixel_coords.y / f32(height)) * 2.0 - 1.0

    fov_radians := f64(fov) * f64(math.PI) / 180.0
    view_height := 2.0 * math.tan(fov_radians / 2.0) * f64(cam_pos.z)
    view_width  := view_height * (f64(width) / f64(height))

    return math.vec3{
        cam_pos.x + f32(ndc_x * view_width  * 0.5),
        cam_pos.y + f32(ndc_y * view_height * 0.5),
        cam_pos.z,
    }
}

// Projects a world position to screen pixel coordinates
// Returns false if behind camera or outside screen
world_to_pixel :: proc(world_pos: math.vec3, width, height: int) -> (px, py: int, ok: bool) {
    cam_pos := (^math.vec3)(data.edit(vault.cam_pos))
    fov     := (^int)(data.edit(vault.fov))^

    if world_pos.z >= cam_pos.z do return 0, 0, false

    fov_radians := f64(fov) * f64(math.PI) / 180.0
    dist        := f64(cam_pos.z - world_pos.z)
    view_height := 2.0 * math.tan(fov_radians / 2.0) * dist
    view_width  := view_height * (f64(width) / f64(height))

    ndc_x := f64(world_pos.x - cam_pos.x) / (view_width  * 0.5)
    ndc_y := f64(world_pos.y - cam_pos.y) / (view_height * 0.5)

    screen_x := int((ndc_x + 1.0) * 0.5 * f64(width))
    screen_y := int((ndc_y + 1.0) * 0.5 * f64(height))

    if screen_x < 0 || screen_x >= width || screen_y < 0 || screen_y >= height {
        return 0, 0, false
    }
    return screen_x, screen_y, true
}

level_offset :: proc(level: i32, dims: int) -> i32 {
    offset: i32 = 0
    count:  i32 = 1
    for i in 0 ..< level {
        offset += count
        count  *= i32(1) << uint(dims)  // 2^dims children per cell
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

// Returns flat index for a cell at given level — dims-aware
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

// Legacy alias used by existing code — assumes 3D
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
