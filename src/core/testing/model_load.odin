package testing

import vault  "../_vault"
import data   "../modules/data"
import gltf   "../modules/model"
import math   "core:math/linalg/glsl"
import "core:fmt"

// Full model creation — loads mesh, builds verts, DataPoints, neighbors,
// Face_List, Field, and Model struct. Returns model Metadata and center.
// Call once per model at load time.
//
// model_update (future): handles live geometry changes and world bitfield
// updates on instance movement. Field repopulation and Face_List rebuild
// only needed on geometry change; world bitfields update on transform change.
load_model :: proc(path: cstring) -> (model_meta: vault.Metadata, center: math.vec3, ok: bool) {
    raw_mesh, loaded := gltf.load_gltf(path)
    if !loaded do return {}, {}, false
    defer gltf.free_raw_mesh(&raw_mesh)

    vert_count := len(raw_mesh.positions)
    face_count := len(raw_mesh.indices) / 3

    data.preallocate(.Vertex,       vert_count)
    data.preallocate(.Vertex_Cache, vert_count)
    data.preallocate(.DataPoint,    vert_count)

    bounds: vault.Bounds
    bounds.x.min = raw_mesh.positions[0].x
    bounds.x.max = raw_mesh.positions[0].x
    bounds.y.min = raw_mesh.positions[0].y
    bounds.y.max = raw_mesh.positions[0].y
    bounds.z.min = raw_mesh.positions[0].z
    bounds.z.max = raw_mesh.positions[0].z

    dp_offset := len(vault.arrays[.DataPoint])

    for i in 0 ..< vert_count {
        pos    := raw_mesh.positions[i]
        normal := raw_mesh.normals[i]

        if pos.x < bounds.x.min do bounds.x.min = pos.x
        if pos.x > bounds.x.max do bounds.x.max = pos.x
        if pos.y < bounds.y.min do bounds.y.min = pos.y
        if pos.y > bounds.y.max do bounds.y.max = pos.y
        if pos.z < bounds.z.min do bounds.z.min = pos.z
        if pos.z > bounds.z.max do bounds.z.max = pos.z

        vert_meta  := data.add(.Vertex, vault.Vertex{pos = pos, normal = normal})
        cache_meta := data.add(.Vertex_Cache, vault.Vertex_Cache{
            ref     = vault.Ref{index = i32(vert_meta.index), version = 0},
            mip_ref = vault.REF_INVALID,
        })
        data.add(.DataPoint, vault.DataPoint{
            pos    = pos,
            normal = normal,
            type   = .Vertex,
            ref    = vault.Ref{index = i32(cache_meta.index), version = 0},
        })
    }

    // Neighbor refs from face topology — used for tangent quality in Hermite surface walk
    build_neighbors_from_indices(raw_mesh.indices, dp_offset)

    // Face_List — raw indices converted to DataPoint indices via dp_offset
    // Stored once per model definition, shared by all instances
    face_list: vault.Face_List
    face_list.faces = make([dynamic][3]i32, face_count)
    for f in 0 ..< face_count {
        face_list.faces[f] = [3]i32{
            i32(dp_offset) + i32(raw_mesh.indices[f * 3 + 0]),
            i32(dp_offset) + i32(raw_mesh.indices[f * 3 + 1]),
            i32(dp_offset) + i32(raw_mesh.indices[f * 3 + 2]),
        }
    }
    face_list_meta := data.add(.Face_List, face_list, "face_list")

    // Field — spatial structure for world hierarchy traversal
    field := field_create(bounds, WORLD_FIELD_LEVELS, 3)
    field_populate(&field, dp_offset, raw_mesh.indices)
    model_field_meta := data.add(.Field, field, "model_field")

    // Model — owns field ref, face_list ref, and bounds
    model := vault.Model{
        field     = vault.Ref{index = i32(model_field_meta.index), version = 0},
        face_list = vault.Ref{index = i32(face_list_meta.index),  version = 0},
        bounds    = bounds,
    }
    model_meta = data.add(.Model, model, "model")

    center = math.vec3{
        (bounds.x.min + bounds.x.max) * 0.5,
        (bounds.y.min + bounds.y.max) * 0.5,
        (bounds.z.min + bounds.z.max) * 0.5,
    }

    fmt.println("load_model: verts:", vert_count, "faces:", face_count, "center:", center)

    // Verify field
    field_ptr := (^vault.Field)(vault.arrays[.Field][model_field_meta.index].data)
    fmt.println("load_model: field root occupied:", cell_get_field(field_ptr, 0, 0))

    occupied_finest := 0
    grid_size       := i32(1) << uint(field_ptr.levels)
    for i in 0 ..< grid_size * grid_size * grid_size {
        if cell_get_field(field_ptr, field_ptr.levels, i32(i)) do occupied_finest += 1
    }
    fmt.println("load_model: occupied finest cells:", occupied_finest)

    return model_meta, center, true
}

// dims: 1, 2, or 3
field_create :: proc(bounds: vault.Bounds, levels: int, dims: int = 3) -> vault.Field {
    field: vault.Field
    field.bounds = bounds
    field.levels = levels
    field.dims   = dims

    total    := total_cells(levels + 1, dims)
    num_u32s := (total + 31) / 32
    field.bits_any = make([dynamic]u32, num_u32s)
    field.bits_all = make([dynamic]u32, num_u32s)

    finest_count := i32(1) << (uint(levels) * uint(dims))
    field.data    = make([dynamic][dynamic]i32, finest_count)

    return field
}

// Populates field using polygon coverage — each face maps to all cells it covers
field_populate :: proc(field: ^vault.Field, dp_offset: int, indices: []u32) {
    face_count := len(indices) / 3
    for f in 0 ..< face_count {
        i0 := dp_offset + int(indices[f * 3 + 0])
        i1 := dp_offset + int(indices[f * 3 + 1])
        i2 := dp_offset + int(indices[f * 3 + 2])
        map_polygon_to_field(field, [3]int{i0, i1, i2})
    }

    for level := field.levels - 1; level >= 0; level -= 1 {
        children_per_cell := i32(1) << uint(field.dims)
        parent_count      := i32(1) << (uint(field.dims) * uint(level))
        for pi in 0 ..< parent_count {
            first_child := pi * children_per_cell
            for c in 0 ..< children_per_cell {
                if cell_get_field(field, level + 1, first_child + i32(c)) {
                    cell_set_field(field, level, i32(pi), true)
                    break
                }
            }
        }
    }
}

build_mip_refs :: proc(field: ^vault.Field) {
    // TODO: per-cell averaged DataPoint for mip early-out
}
