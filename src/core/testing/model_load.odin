package testing

import data "../_data"
import model "../modules/model"
import math "core:math/linalg/glsl"
import "core:fmt"

load_model :: proc(path: cstring) -> (bounds: data.Bounds, center: math.vec3, ok: bool) {
    raw_verts, loaded := model.load_model(path)
    if !loaded do return {}, {}, false

    bounds.x.min = raw_verts[0].pos.x
    bounds.x.max = raw_verts[0].pos.x
    bounds.y.min = raw_verts[0].pos.y
    bounds.y.max = raw_verts[0].pos.y
    bounds.z.min = raw_verts[0].pos.z
    bounds.z.max = raw_verts[0].pos.z

    for v in raw_verts {
        if v.pos.x < bounds.x.min do bounds.x.min = v.pos.x
        if v.pos.x > bounds.x.max do bounds.x.max = v.pos.x
        if v.pos.y < bounds.y.min do bounds.y.min = v.pos.y
        if v.pos.y > bounds.y.max do bounds.y.max = v.pos.y
        if v.pos.z < bounds.z.min do bounds.z.min = v.pos.z
        if v.pos.z > bounds.z.max do bounds.z.max = v.pos.z

        vert_meta := add(&data.vertex_Direct, &data.vertex_Direct_meta, &data.vertex_Direct_free,
            data.Vertex{pos = v.pos, normal = v.normal})

        cached_meta := add(&data.cached_vertex_Flat, &data.cached_vertex_Flat_meta, &data.cached_vertex_Flat_free,
            data.Vertex_Cached{ref = data.Ref{index = i32(vert_meta.index), version = 0}})

        add(&data.datapoint_Composite, &data.datapoint_Composite_meta, &data.datapoint_Composite_free,
            data.DataPoint{
                pos    = v.pos,
                normal = v.normal,
                type   = .Vertex,
                ref    = data.Ref{index = i32(cached_meta.index), version = 0},
            })
    }

    center = math.vec3{
        (bounds.x.min + bounds.x.max) * 0.5,
        (bounds.y.min + bounds.y.max) * 0.5,
        (bounds.z.min + bounds.z.max) * 0.5,
    }

    fmt.println("load_model: loaded", len(data.datapoint_Composite), "datapoints, center:", center)
    return bounds, center, true
}

field_create :: proc(bounds: data.Bounds, levels: int) -> data.Field {
    field: data.Field
    field.bounds = bounds
    field.levels = levels

    total    := total_cells(levels + 1)
    num_u32s := (total + 31) / 32
    field.bits = make([dynamic]u32, num_u32s)

    finest_count := i32(1) << uint(levels)
    finest_count  = finest_count * finest_count * finest_count
    field.refs = make([dynamic][dynamic]i32, finest_count)

    return field
}

field_populate :: proc(field: ^data.Field, datapoints: []data.DataPoint) {
    grid_size := i32(1) << uint(field.levels)
    half      := grid_size / 2

    bx := field.bounds.x.max - field.bounds.x.min
    by := field.bounds.y.max - field.bounds.y.min
    bz := field.bounds.z.max - field.bounds.z.min

    for i in 0 ..< len(datapoints) {
        dp := datapoints[i]

        nx := (dp.pos.x - field.bounds.x.min) / bx
        ny := (dp.pos.y - field.bounds.y.min) / by
        nz := (dp.pos.z - field.bounds.z.min) / bz

        x := i32(math.floor_f32(nx * f32(grid_size))) - half
        y := i32(math.floor_f32(ny * f32(grid_size))) - half
        z := i32(math.floor_f32(nz * f32(grid_size))) - half

        if x < -half || x >= half ||
           y < -half || y >= half ||
           z < -half || z >= half {
            continue
        }

        idx := xyz_to_index(math.ivec3{x, y, z}, field.levels)
        cell_set_field(field, field.levels, idx, true)
        append(&field.refs[idx], i32(i))
    }

    for level := field.levels - 1; level >= 0; level -= 1 {
        parent_count := i32(1) << (3 * u32(level))
        for p in 0 ..< parent_count {
            first_child := i32(p) * 8
            for c in 0 ..< 8 {
                if cell_get_field(field, level + 1, first_child + i32(c)) {
                    cell_set_field(field, level, i32(p), true)
                    break
                }
            }
        }
    }
}