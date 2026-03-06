package testing

import math_lin "core:math/linalg"
import math "core:math/linalg/glsl"
import rl "vendor:raylib"

import data "../_data"

import "core:fmt"

calc_FPS :: proc(frame_time: i64) -> int {
    fps := 1000000000 / frame_time
    return int(fps)
}

// OLD - flat grid coords, depended on DEPRACATED_WORLD_SIZE
// xyz_to_cell :: proc ...
// cell_to_xyz :: proc ...

trilinear_interp :: proc(
    c: [8]f32,
    fx, fy, fz: f32,
) -> f32 {
    c00 := c[0] * (1 - fx) + c[1] * fx
    c01 := c[2] * (1 - fx) + c[3] * fx
    c10 := c[4] * (1 - fx) + c[5] * fx
    c11 := c[6] * (1 - fx) + c[7] * fx
    c0  := c00 * (1 - fy) + c01 * fy
    c1  := c10 * (1 - fy) + c11 * fy
    return c0 * (1 - fz) + c1 * fz
}

handle_camera_input :: proc() {
    dt         := rl.GetFrameTime()
    move_speed := data.CAM_SPEED * dt * 60.0

    if rl.IsKeyDown(.LEFT_SHIFT) do move_speed *= 3.0

    if rl.IsKeyDown(.W) do data.CAM_POS.y += move_speed
    if rl.IsKeyDown(.S) do data.CAM_POS.y -= move_speed
    if rl.IsKeyDown(.A) do data.CAM_POS.x -= move_speed
    if rl.IsKeyDown(.D) do data.CAM_POS.x += move_speed
    if rl.IsKeyDown(.Q) do data.CAM_POS.z -= move_speed
    if rl.IsKeyDown(.E) do data.CAM_POS.z += move_speed
}

ortho_pixel_to_world :: proc(pixel_coords: math.vec2, width, height: int) -> math.vec3 {
    uv      := math.vec2{pixel_coords.x / f32(width), pixel_coords.y / f32(height)}
    // OLD: relied on DEPRACATED_WORLD_SIZE, kept for reference
    // world_x := (uv.x - 0.5) * f32(data.DEPRACATED_WORLD_SIZE * 2) + data.CAM_POS.x
    // world_y := (uv.y - 0.5) * f32(data.DEPRACATED_WORLD_SIZE * 2) + data.CAM_POS.y
    return math.vec3{uv.x, uv.y, data.CAM_POS.z}
}

pixel_to_world_fov :: proc(pixel_coords: math.vec2, width, height: int) -> math.vec3 {
    ndc_x := f64(pixel_coords.x / f32(width)) * 2.0 - 1.0
    ndc_y := f64(pixel_coords.y / f32(height)) * 2.0 - 1.0

    fov_radians := data.FOV * math.PI / 180.0
    view_height := 2.0 * math.tan(fov_radians / 2.0) * f64(data.CAM_POS.z)
    view_width  := view_height * (f64(width) / f64(height))

    return math.vec3{
        data.CAM_POS.x + f32(ndc_x * view_width * 0.5),
        data.CAM_POS.y + f32(ndc_y * view_height * 0.5),
        data.CAM_POS.z,
    }
}

// Calculate the starting offset for a given level
level_offset :: proc(level: i32) -> i32 {
    offset: i32 = 0
    count:  i32 = 1
    for i in 0 ..< level {
        offset += count
        count  *= 8
    }
    return offset
}

// Calculate total number of cells across all levels
total_cells :: proc(num_levels: int) -> i32 {
    total: i32 = 0
    count: i32 = 1
    for i in 0 ..< num_levels {
        total += count
        count *= 8
    }
    return total
}

// Convert linear index to 3D coordinates at a given level
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

// 3D coordinates to linear index at a given level
xyz_to_index :: proc(xyz: math.ivec3, level: int) -> i32 {
    grid_size: i32 = 1 << uint(level)
    half      := grid_size / 2
    x := xyz.x + half
    y := xyz.y + half
    z := xyz.z + half
    return z * grid_size * grid_size + y * grid_size + x
}

parent_index :: proc(child_index: int) -> int {
    return child_index / 8
}

first_child_index :: proc(parent_index: int) -> int {
    return parent_index * 8
}

cell_get_field :: proc(field: ^data.Field, level: int, index: i32) -> bool {
    absolute_index := level_offset(i32(level)) + index
    slot           := absolute_index / 32
    if slot < 0 || int(slot) >= len(field.bits) do return false
    bit := u32(absolute_index % 32)
    return (field.bits[slot] & (1 << bit)) != 0
}

cell_set_field :: proc(field: ^data.Field, level: int, index: i32, value: bool) {
    absolute_index := level_offset(i32(level)) + index
    slot           := absolute_index / 32
    if slot < 0 || int(slot) >= len(field.bits) do return
    bit := u32(absolute_index % 32)
    if value {
        field.bits[slot] |= (1 << bit)
    } else {
        field.bits[slot] &= ~(1 << bit)
    }
}

// OLD - Mipmap_Bitfield system, replaced by Field
// level_count :: proc ...
// bitfield_create :: proc ...
// cell_get :: proc ...
// cell_set :: proc ...
// model_bitfield_set :: proc ...
// model_bitfield_get :: proc ...
// ray_aabb_hit :: proc ...
// octree_query :: proc ...