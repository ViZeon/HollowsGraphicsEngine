package testing

import vault "../../core/_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"
import "core:fmt"

WORLD_FIELD_LEVELS  :: 4
WORLD_FIELD_DEFAULT :: f32(16.0)

// ---- field_sync ----
field_sync :: proc(root_dp_index: i32, target_bounds: vault.Bounds) -> i32 {
    if root_dp_index < 0 {
        aligned    := bounds_align_to_grid(target_bounds, WORLD_FIELD_LEVELS)
        field      := field_create(aligned, WORLD_FIELD_LEVELS)
        field_meta := data.add(.Field, field, "field")
        dp_meta    := data.add(.DataPoint, vault.DataPoint{
            pos    = bounds_center(aligned),
            normal = math.vec3{0, 1, 0},
            type   = .Field,
            ref    = vault.Ref{index = i32(field_meta.index), version = 0},
        }, "field_dp")
        return i32(dp_meta.index)
    }

    root_dp := (^vault.DataPoint)(data.edit(vault.Metadata{
        index   = int(root_dp_index),
        type_id = .DataPoint,
        valid   = true,
    }))
    field := (^vault.Field)(data.edit(vault.Metadata{
        index   = int(root_dp.ref.index),
        type_id = .Field,
        valid   = true,
    }))

    for !bounds_contains(field.bounds, target_bounds) {
        parent_bounds     := bounds_expand_parent(field.bounds)
        parent_field      := field_create(parent_bounds, WORLD_FIELD_LEVELS)
        parent_field_meta := data.add(.Field, parent_field, "field")

        _ = data.add(.DataPoint, vault.DataPoint{
            pos    = bounds_center(field.bounds),
            normal = math.vec3{0, 1, 0},
            type   = .Field,
            ref    = root_dp.ref,
        }, "field_child_dp")

        root_dp.ref = vault.Ref{index = i32(parent_field_meta.index), version = 0}
        root_dp.pos = bounds_center(parent_bounds)

        field = (^vault.Field)(data.edit(vault.Metadata{
            index   = int(root_dp.ref.index),
            type_id = .Field,
            valid   = true,
        }))

        fmt.println("field_sync: nested upward, new bounds:", field.bounds)
    }

    return root_dp_index
}

// ---- scene_init ----
scene_init :: proc() {
    default_bounds := vault.Bounds{
        x = vault.Range{min = -8, max = 8},
        y = vault.Range{min = -8, max = 8},
        z = vault.Range{min = -8, max = 8},
    }
    world_dp_index := field_sync(-1, default_bounds)
    vault.world_dp = vault.Metadata{
        index   = int(world_dp_index),
        type_id = .DataPoint,
        valid   = true,
    }
    fmt.println("scene_init: world field created, bounds:", default_bounds)
}

// ---- scene_add_model ----
// Registers model in the world hierarchy.
// model_ref indexes into vault.arrays[.Model] — the Model struct owns field and face_list.
scene_add_model :: proc(model_ref: vault.Ref) {
    model        := (^vault.Model)(vault.arrays[.Model][model_ref.index].data)
    model_bounds := model.bounds

    // Ensure world covers model bounds
    world_dp_index       := i32(vault.world_dp.index)
    world_dp_index        = field_sync(world_dp_index, model_bounds)
    vault.world_dp.index  = int(world_dp_index)

    world_dp := (^vault.DataPoint)(data.edit(vault.Metadata{
        index   = int(world_dp_index),
        type_id = .DataPoint,
        valid   = true,
    }))
    world_field := (^vault.Field)(data.edit(vault.Metadata{
        index   = int(world_dp.ref.index),
        type_id = .Field,
        valid   = true,
    }))

    center := bounds_center(model_bounds)

    // DataPoint of type .Model — ref indexes into vault.arrays[.Model]
    model_dp_meta := data.add(.DataPoint, vault.DataPoint{
        pos    = center,
        normal = math.vec3{0, 1, 0},
        type   = .Model,
        ref    = model_ref,
    }, "model_dp")

    // Insert model DataPoint into world field at its position
    grid_size := i32(1) << uint(world_field.levels)
    half      := grid_size / 2
    bx := world_field.bounds.x.max - world_field.bounds.x.min
    by := world_field.bounds.y.max - world_field.bounds.y.min
    bz := world_field.bounds.z.max - world_field.bounds.z.min
    nx := (center.x - world_field.bounds.x.min) / bx
    ny := (center.y - world_field.bounds.y.min) / by
    nz := (center.z - world_field.bounds.z.min) / bz
    cx := clamp(i32(math.floor_f32(nx * f32(grid_size))) - half, -half, half - 1)
    cy := clamp(i32(math.floor_f32(ny * f32(grid_size))) - half, -half, half - 1)
    cz := clamp(i32(math.floor_f32(nz * f32(grid_size))) - half, -half, half - 1)
    idx := cell_index(math.ivec3{cx, cy, cz}, world_field.levels, world_field.dims)
    cell_set_field(world_field, world_field.levels, idx, true)
    append(&world_field.data[idx], i32(model_dp_meta.index))

    // Propagate occupancy upward
    for level := world_field.levels - 1; level >= 0; level -= 1 {
        children_per_cell := i32(1) << uint(world_field.dims)
        parent_count      := i32(1) << (uint(world_field.dims) * uint(level))
        for pi in 0 ..< parent_count {
            first_child := pi * children_per_cell
            for c in 0 ..< children_per_cell {
                if cell_get_field(world_field, level + 1, first_child + i32(c)) {
                    cell_set_field(world_field, level, i32(pi), true)
                    break
                }
            }
        }
    }

    fmt.printf("scene_add_model: model at [%.3f, %.3f, %.3f] inserted into world field\n",
        center.x, center.y, center.z)
}

// ---- Bounds helpers ----

bounds_center :: proc(b: vault.Bounds) -> math.vec3 {
    return math.vec3{
        (b.x.min + b.x.max) * 0.5,
        (b.y.min + b.y.max) * 0.5,
        (b.z.min + b.z.max) * 0.5,
    }
}

bounds_contains :: proc(outer, inner: vault.Bounds) -> bool {
    return inner.x.min >= outer.x.min && inner.x.max <= outer.x.max &&
           inner.y.min >= outer.y.min && inner.y.max <= outer.y.max &&
           inner.z.min >= outer.z.min && inner.z.max <= outer.z.max
}

bounds_expand_parent :: proc(b: vault.Bounds) -> vault.Bounds {
    cx := (b.x.min + b.x.max) * 0.5
    cy := (b.y.min + b.y.max) * 0.5
    cz := (b.z.min + b.z.max) * 0.5
    hw := (b.x.max - b.x.min) * 8.0
    hh := (b.y.max - b.y.min) * 8.0
    hd := (b.z.max - b.z.min) * 8.0
    return vault.Bounds{
        x = vault.Range{min = cx - hw, max = cx + hw},
        y = vault.Range{min = cy - hh, max = cy + hh},
        z = vault.Range{min = cz - hd, max = cz + hd},
    }
}

bounds_align_to_grid :: proc(b: vault.Bounds, levels: int) -> vault.Bounds {
    cell_size := (b.x.max - b.x.min) / f32(i32(1) << uint(levels))
    snap_down := proc(v, cell: f32) -> f32 { return math.floor_f32(v / cell) * cell }
    snap_up   :: proc(v, cell: f32) -> f32 { return math.ceil_f32(v / cell)  * cell }
    return vault.Bounds{
        x = vault.Range{min = snap_down(b.x.min, cell_size), max = snap_up(b.x.max, cell_size)},
        y = vault.Range{min = snap_down(b.y.min, cell_size), max = snap_up(b.y.max, cell_size)},
        z = vault.Range{min = snap_down(b.z.min, cell_size), max = snap_up(b.z.max, cell_size)},
    }
}
