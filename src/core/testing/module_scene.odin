package testing

import vault "../_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"
import "core:fmt"

WORLD_FIELD_LEVELS :: 4

// TODO: accept a Scene param when scene management is implemented
scene_init :: proc() -> vault.Metadata {
    default_bounds := vault.Bounds{x = {-8, 8}, y = {-8, 8}, z = {-8, 8}}
    aligned        := bounds_align_to_grid(default_bounds, WORLD_FIELD_LEVELS)

    field_meta := data.add(.Field, field_create(aligned, WORLD_FIELD_LEVELS, 3), "world_field")
    //scene_field := 
    //
    dp_meta    := data.add(.DataPoint, vault.DataPoint{
        pos    = bounds_center(aligned),
        normal = math.vec3{0, 1, 0},
        type   = .Field,
        metadata    = field_meta,
    }, "world_dp")
    vault.world_dp = vault.Metadata{index = dp_meta.index, type_id = .DataPoint, valid = true}

    model_path             := (^cstring)(data.edit(vault.model_path))^
    model_meta, _, ok      := load_model(model_path)
    if !ok do return vault.world_dp

    scene_add_model(vault.Ref{index = i32(model_meta.index), version = 0})

    model := (^vault.Model)(data.edit(model_meta))
    cam   := (^math.vec3)(data.edit(vault.cam_pos))
    cam.x  = bounds_center(model.cache.bounds).x
    cam.y  = bounds_center(model.cache.bounds).y
    cam.z  = model.cache.bounds.z.max + 5.0

    fmt.println("scene_init: world field created, bounds:", aligned)
    return vault.world_dp
}

// Registers a model in the world field hierarchy
scene_add_model :: proc(model_ref: vault.Ref) {
    model := (^vault.Model)(vault.arrays[.Model][model_ref.index].data)

    world_dp    := (^vault.DataPoint)(data.edit(vault.world_dp))
    world_field := (^vault.Field)(data.edit(vault.Metadata{
        index = int(world_dp.metadata.index), type_id = .Field, valid = true,
    }))
    model_field := (^vault.Field)(data.edit(vault.Metadata{
        index = int(model.cache.field.index), type_id = .Field, valid = true,
    }))

    transform := vault.Transform{
        pos   = bounds_center(model.cache.bounds),
        rot   = quaternion(w=1, x=0, y=0, z=0),
        scale = {1, 1, 1},
    }

    field_update_parent(world_field, model_field, transform, &model.cache.occupied_cells, i32(model_ref.index))
    fmt.println("scene_add_model: model registered in world field")
}
