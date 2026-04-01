package testing

import vault "../_vault"
import data  "../modules/data"
import gltf  "../modules/model"
import math  "core:math/linalg/glsl"
import "core:fmt"

load_model :: proc(path: cstring) -> (model_meta: vault.Metadata, center: math.vec3, ok: bool) {
    source, loaded := gltf.load_model_source(string(path))
    if !loaded do return {}, {}, false
    if len(source.verts) == 0 do return {}, {}, false

    // Compute bounds
    bounds: vault.Bounds
    bounds.x = {source.verts[0].source.pos.x, source.verts[0].source.pos.x}
    bounds.y = {source.verts[0].source.pos.y, source.verts[0].source.pos.y}
    bounds.z = {source.verts[0].source.pos.z, source.verts[0].source.pos.z}

    for v in source.verts {
        bounds.x.min = min(bounds.x.min, v.source.pos.x)
        bounds.x.max = max(bounds.x.max, v.source.pos.x)
        bounds.y.min = min(bounds.y.min, v.source.pos.y)
        bounds.y.max = max(bounds.y.max, v.source.pos.y)
        bounds.z.min = min(bounds.z.min, v.source.pos.z)
        bounds.z.max = max(bounds.z.max, v.source.pos.z)
    }

    transform := vault.Transform{
        pos   = {0, 0, 0},
        rot   = transmute(math.quat)[4]f32{0, 0, 0, 1},
        scale = {1, 1, 1},
    }

    field      := field_create(bounds, WORLD_FIELD_LEVELS, 3)
    field_meta := data.add(.Field, field, "model_field")
    field_ptr  := (^vault.Field)(data.edit(field_meta))

    field_model_populate(field_ptr, &source, transform, true)

    model_meta = data.add(.Model, vault.Model{
        source = source,
        cache  = vault.Model_Cache{
            bounds = bounds,
            field  = vault.Ref{index = i32(field_meta.index), version = 0},
        },
    }, "model")

    center = math.vec3{
        (bounds.x.min + bounds.x.max) * 0.5,
        (bounds.y.min + bounds.y.max) * 0.5,
        (bounds.z.min + bounds.z.max) * 0.5,
    }

    fmt.println("load_model: verts:", len(source.verts), "polys:", len(source.polys), "center:", center)
    return model_meta, center, true
}