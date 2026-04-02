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

    field_meta := data.add(.Field, field_create(aligned, WORLD_FIELD_LEVELS, 3), "world_field_meta")
    //scene_field := 
    //
    dp_meta    := data.add(.DataPoint, vault.DataPoint{
        pos    = bounds_center(aligned),
        normal = math.vec3{0, 1, 0},
        metadata    = field_meta,
    }, "world_dp")

    vault.world_dp = field_meta

    model_path             := (^cstring)(data.edit(vault.model_path))^
    model_meta, _, ok      := load_model(model_path)
    if !ok do return field_meta

    scene_add_model(model_meta, dp_meta)

    model := (^vault.Model)(data.edit(model_meta))
    cam   := (^math.vec3)(data.edit(vault.cam_pos))
    cam.x  = bounds_center(model.cache.bounds).x
    cam.y  = bounds_center(model.cache.bounds).y
    cam.z  = model.cache.bounds.z.max + 5.0

    fmt.println("scene_init: world field created, bounds:", aligned)
    return dp_meta
}

// Registers a model in the world field hierarchy
scene_add_model :: proc(model_metadata: vault.Metadata, scene: vault.Metadata) {

    scene_datapoint:= (^vault.DataPoint)(data.edit(scene))
    scene_field:= (^vault.Field)(data.edit(scene_datapoint.metadata))

    model := (^vault.Model)(data.edit(model_metadata))

    world_dp    := scene_datapoint
    world_field := scene_field

    model_ref:= model.cache.field
    model_field := (^vault.Field)(data.edit(model_ref))
   


    transform := vault.Transform{
        pos   = bounds_center(model.cache.bounds),
        rot   = quaternion(w=1, x=0, y=0, z=0),
        scale = {1, 1, 1},
    }

    field_update_parent(world_field, model_field, transform, &model.cache.occupied_cells, i32(model_metadata.index))
    fmt.println("scene_add_model: model registered in world field")
}
