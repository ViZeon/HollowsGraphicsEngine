package testing

import data "../_data"
import math "core:math/linalg/glsl"

ref_valid :: proc(ref: data.Ref, version: u32) -> bool {
    return ref.index >= 0 && ref.version == version
}

field_query :: proc(field: ^data.Field, world_x, world_y: f32) -> bool {
    bx := field.bounds.x.max - field.bounds.x.min
    by := field.bounds.y.max - field.bounds.y.min

    nx := (world_x - field.bounds.x.min) / bx
    ny := (world_y - field.bounds.y.min) / by

    for level in 0..=field.levels {
        grid_size := i32(1) << uint(level)
        half      := grid_size / 2

        lx := i32(math.floor_f32(nx * f32(grid_size))) - half
        ly := i32(math.floor_f32(ny * f32(grid_size))) - half

        if lx + half < 0 || lx + half >= grid_size ||
           ly + half < 0 || ly + half >= grid_size {
            return false
        }

        any_occupied := false
        for lz_u := grid_size - 1; lz_u >= 0; lz_u -= 1 {
            lz := lz_u - half
            idx := xyz_to_index(math.ivec3{lx, ly, lz}, level)
            if cell_get_field(field, level, idx) {
                any_occupied = true
                if level == field.levels do return true
                break
            }
        }
        if !any_occupied do return false
    }
    return false
}