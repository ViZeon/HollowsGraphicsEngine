package testing

import vault "../_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"

ref_valid :: proc(ref: vault.Ref, version: u32) -> bool {
    return ref.index >= 0 && ref.version == version
}

// Top-down field traversal within a single field (or across nested child fields)
// Returns hit=true if world_x/y is occupied in front of cam
// create_children=true: creates child fields in data[cell][1] when descending past finest level
// leaf/leaf_cell out params: filled on hit with the leaf field ptr and cell index
field_query :: proc(
    field:           ^vault.Field,
    world_x, world_y, cam_z: f32,
    create_children: bool          = false,
    leaf:            ^^vault.Field = nil,
    leaf_cell:       ^i32          = nil,
) -> bool {
    if cam_z <= field.bounds.z.min do return false

    flat    := (field.bounds.z.max - field.bounds.z.min) < 0.01 || field.dims < 3
    current := field
    nx      := (world_x - current.bounds.x.min) / (current.bounds.x.max - current.bounds.x.min)
    ny      := (world_y - current.bounds.y.min) / (current.bounds.y.max - current.bounds.y.min)

    for {
        bw := current.bounds.x.max - current.bounds.x.min
        bh := current.bounds.y.max - current.bounds.y.min

        for level in 0..=current.levels {
            grid_size := i32(1) << uint(level)
            half      := grid_size / 2
            lx        := i32(math.floor_f32(nx * f32(grid_size))) - half
            ly        := i32(math.floor_f32(ny * f32(grid_size))) - half

            if lx+half < 0 || lx+half >= grid_size || ly+half < 0 || ly+half >= grid_size do return false

            lz  := i32(0) - half
            idx := cell_index(math.ivec3{lx, ly, lz}, level, current.dims)

            if level == current.levels {
                // Check for child field to descend into
                if len(current.data[idx]) >= 2 {
                    m := data.resolve(current.data[idx][1])
                    if m.type_id == .Field {
                        child := (^vault.Field)(data.edit(m))
                        nx     = (world_x - child.bounds.x.min) / (child.bounds.x.max - child.bounds.x.min)
                        ny     = (world_y - child.bounds.y.min) / (child.bounds.y.max - child.bounds.y.min)
                        current = child
                        break
                    }
                }

                // Optionally create child field if not yet at pixel resolution
                if create_children {
                    cell_w := bw / f32(grid_size)
                    cell_h := bh / f32(grid_size)
                    if cell_w > 1.0 || cell_h > 1.0 {
                        levels     := (^int)(data.edit(vault.screen_field_levels))^
                        child_meta := data.add(.Field, field_create(vault.Bounds{
                            x = {current.bounds.x.min + f32(lx+half)*cell_w,   current.bounds.x.min + f32(lx+half+1)*cell_w},
                            y = {current.bounds.y.min + f32(ly+half)*cell_h,   current.bounds.y.min + f32(ly+half+1)*cell_h},
                            z = current.bounds.z,
                        }, levels, 2), "screen_tile")
                        if len(current.data[idx]) == 0 {
                            bm := data.add(.Bounds, vault.Bounds{}, "screen_cell_bounds")
                            append(&current.data[idx], i32(bm.id))
                        }
                        if len(current.data[idx]) < 2 { append(&current.data[idx], i32(child_meta.id))
                        } else { current.data[idx][1] = i32(child_meta.id) }
                        cell_set(current.bits_any[:], current.levels, idx, current.dims, true)
                        child := (^vault.Field)(data.edit(child_meta))
                        nx     = (world_x - child.bounds.x.min) / (child.bounds.x.max - child.bounds.x.min)
                        ny     = (world_y - child.bounds.y.min) / (child.bounds.y.max - child.bounds.y.min)
                        current = child
                        break
                    }
                }

                // Leaf — return result
                if leaf      != nil do leaf^      = current
                if leaf_cell != nil do leaf_cell^ = idx
                return cell_get(current.bits_any[:], level, idx, current.dims)
            }

            // Mid-level — check occupancy
            bz      := current.bounds.z.max - current.bounds.z.min
            cell_z  := bz / f32(grid_size)
            z_count := grid_size if current.dims == 3 else i32(1)
            any     := false
            for lz_u := z_count - 1; lz_u >= 0; lz_u -= 1 {
                lz2 := lz_u - half
                if !flat && current.dims == 3 {
                    if current.bounds.z.min + f32(lz_u+1)*cell_z >= cam_z do continue
                }
                if cell_get(current.bits_any[:], level, cell_index(math.ivec3{lx, ly, lz2}, level, current.dims), current.dims) {
                    any = true; break
                }
            }
            if !any do return false
        }
    }
    return false
}



// Zeros occupancy bits — recurses into child fields found in data[cell][1]
field_clear :: proc(field: ^vault.Field) {
    for i in 0 ..< len(field.bits_any) { field.bits_any[i] = 0 }
    finest := i32(1) << (uint(field.levels) * uint(field.dims))
    for cell in 0 ..< finest {
        if len(field.data[cell]) < 2 do continue
        m := data.resolve(field.data[cell][1])
        if m.type_id == .Field do field_clear((^vault.Field)(data.edit(m)))
    }
}

// ---- Screen field ----
//
// Nested 2D field hierarchy covering screen space, ~4kb per tile.
// Configured via vault.screen_field_levels.
// data[cell][0] = Metadata id of vault Bounds (z-extent of subtree)
// data[cell][1] = Metadata id of child Field or DataPoint

screen_field_get_root :: proc(screen_w, screen_h: int) -> vault.Metadata {
    for i in 0 ..< len(vault.meta_arrays[.Field]) {
        m := vault.meta_arrays[.Field][i]
        if m.valid && m.name == "screen_root" do return m
    }
    levels := (^int)(data.edit(vault.screen_field_levels))^
    return data.add(.Field, field_create(vault.Bounds{
        x = {0, f32(screen_w)}, y = {0, f32(screen_h)}, z = {0, 1},
    }, levels, 2), "screen_root")
}

// Returns z-bounds of smallest screen field cell containing the polygon bbox — one fetch per polygon
screen_field_coarse_bounds :: proc(px_min, py_min, px_max, py_max, screen_w, screen_h: int) -> (b: vault.Bounds, ok: bool) {
    current := (^vault.Field)(data.edit(screen_field_get_root(screen_w, screen_h)))
    for {
        grid_size := i32(1) << uint(current.levels)
        half      := grid_size / 2
        bw        := current.bounds.x.max - current.bounds.x.min
        bh        := current.bounds.y.max - current.bounds.y.min
        cell_w    := bw / f32(grid_size)
        cell_h    := bh / f32(grid_size)

        cx_min := clamp(i32(math.floor_f32((f32(px_min) - current.bounds.x.min) / bw * f32(grid_size))) - half, -half, half-1)
        cx_max := clamp(i32(math.floor_f32((f32(px_max) - current.bounds.x.min) / bw * f32(grid_size))) - half, -half, half-1)
        cy_min := clamp(i32(math.floor_f32((f32(py_min) - current.bounds.y.min) / bh * f32(grid_size))) - half, -half, half-1)
        cy_max := clamp(i32(math.floor_f32((f32(py_max) - current.bounds.y.min) / bh * f32(grid_size))) - half, -half, half-1)

        if cx_min != cx_max || cy_min != cy_max {
            if !cell_get(current.bits_any[:], 0, 0, current.dims) || len(current.data[0]) == 0 do return {}, false
            return (^vault.Bounds)(data.edit(data.resolve(current.data[0][0])))^, true
        }

        idx := cell_index(math.ivec3{cx_min, cy_min, 0}, current.levels, current.dims)
        if !cell_get(current.bits_any[:], current.levels, idx, current.dims) || len(current.data[idx]) == 0 do return {}, false
        if cell_w <= 1.0 && cell_h <= 1.0 do return (^vault.Bounds)(data.edit(data.resolve(current.data[idx][0])))^, true
        if len(current.data[idx]) >= 2 {
            m := data.resolve(current.data[idx][1])
            if m.type_id == .Field { current = (^vault.Field)(data.edit(m)); continue }
        }
        return (^vault.Bounds)(data.edit(data.resolve(current.data[idx][0])))^, true
    }
}

// Propagates z bounds upward from a written pixel — expands parent bounds if outside current range
screen_field_propagate_bounds :: proc(px, py: int, z_min, z_max: f32, screen_w, screen_h: int) {
    _propagate_bounds_recursive((^vault.Field)(data.edit(screen_field_get_root(screen_w, screen_h))), px, py, z_min, z_max)
}

_propagate_bounds_recursive :: proc(field: ^vault.Field, px, py: int, z_min, z_max: f32) {
    grid_size := i32(1) << uint(field.levels)
    half      := grid_size / 2
    bw        := field.bounds.x.max - field.bounds.x.min
    bh        := field.bounds.y.max - field.bounds.y.min
    nx        := (f32(px) + 0.5 - field.bounds.x.min) / bw
    ny        := (f32(py) + 0.5 - field.bounds.y.min) / bh
    cx        := clamp(i32(math.floor_f32(nx * f32(grid_size))) - half, -half, half-1)
    cy        := clamp(i32(math.floor_f32(ny * f32(grid_size))) - half, -half, half-1)
    idx       := cell_index(math.ivec3{cx, cy, 0}, field.levels, field.dims)

    if len(field.data[idx]) == 0 {
        bm := data.add(.Bounds, vault.Bounds{z = {z_min, z_max}}, "screen_cell_bounds")
        append(&field.data[idx], i32(bm.id))
    } else {
        b := (^vault.Bounds)(data.edit(data.resolve(field.data[idx][0])))
        if z_min < b.z.min do b.z.min = z_min
        if z_max > b.z.max do b.z.max = z_max
    }
    cell_set(field.bits_any[:], field.levels, idx, field.dims, true)
    if len(field.data[idx]) >= 2 {
        m := data.resolve(field.data[idx][1])
        if m.type_id == .Field do _propagate_bounds_recursive((^vault.Field)(data.edit(m)), px, py, z_min, z_max)
    }
}


screen_field_get_pixel_cell :: proc(px, py, screen_w, screen_h: int) -> (leaf: ^vault.Field, cell_idx: i32, ok: bool) {
    current := (^vault.Field)(data.edit(screen_field_get_root(screen_w, screen_h)))
    for {
        grid_size := i32(1) << uint(current.levels)
        half      := grid_size / 2
        bw        := current.bounds.x.max - current.bounds.x.min
        bh        := current.bounds.y.max - current.bounds.y.min
        cell_w    := bw / f32(grid_size)
        cell_h    := bh / f32(grid_size)
        nx  := (f32(px) + 0.5 - current.bounds.x.min) / bw
        ny  := (f32(py) + 0.5 - current.bounds.y.min) / bh
        cx  := clamp(i32(math.floor_f32(nx * f32(grid_size))) - half, -half, half-1)
        cy  := clamp(i32(math.floor_f32(ny * f32(grid_size))) - half, -half, half-1)
        idx := cell_index(math.ivec3{cx, cy, 0}, current.levels, current.dims)
        if cell_w <= 1.0 && cell_h <= 1.0 do return current, idx, true
        if len(current.data[idx]) < 2 || data.resolve(current.data[idx][1]).type_id != .Field {
            levels     := (^int)(data.edit(vault.screen_field_levels))^
            child_meta := data.add(.Field, field_create(vault.Bounds{
                x = {current.bounds.x.min + f32(cx+half)*cell_w, current.bounds.x.min + f32(cx+half+1)*cell_w},
                y = {current.bounds.y.min + f32(cy+half)*cell_h, current.bounds.y.min + f32(cy+half+1)*cell_h},
                z = current.bounds.z,
            }, levels, 2), "screen_tile")
            if len(current.data[idx]) == 0 {
                bm := data.add(.Bounds, vault.Bounds{}, "screen_cell_bounds")
                append(&current.data[idx], i32(bm.id))
            }
            if len(current.data[idx]) < 2 { append(&current.data[idx], i32(child_meta.id))
            } else { current.data[idx][1] = i32(child_meta.id) }
            cell_set(current.bits_any[:], current.levels, idx, current.dims, true)
        }
        current = (^vault.Field)(data.edit(data.resolve(current.data[idx][1])))
    }
    return nil, 0, false
}