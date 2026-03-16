package testing

import vault "../_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"

ref_valid :: proc(ref: vault.Ref, version: u32) -> bool {
    return ref.index >= 0 && ref.version == version
}

field_query :: proc(field: ^vault.Field, world_x, world_y, cam_z: f32) -> bool {
    if cam_z <= field.bounds.z.min do return false

    z_depth := field.bounds.z.max - field.bounds.z.min
    flat    := z_depth < 0.01 || field.dims < 3

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
        bz     := field.bounds.z.max - field.bounds.z.min
        cell_z := bz / f32(grid_size)

        z_count := grid_size if field.dims == 3 else i32(1)

        for lz_u := z_count - 1; lz_u >= 0; lz_u -= 1 {
            lz := lz_u - half

            if !flat && field.dims == 3 {
                cell_world_z := field.bounds.z.min + f32(lz_u + 1) * cell_z
                if cell_world_z >= cam_z do continue
            }

            idx := cell_index(math.ivec3{lx, ly, lz}, level, field.dims)
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
