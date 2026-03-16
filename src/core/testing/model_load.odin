package testing

import vault  "../_vault"
import data   "../modules/data"
import gltf   "../modules/model"
import math   "core:math/linalg/glsl"
import "core:fmt"

load_model :: proc(path: cstring) -> (bounds: vault.Bounds, center: math.vec3, ok: bool) {
    raw_mesh, loaded := gltf.load_gltf(path)
    if !loaded do return {}, {}, false
    defer gltf.free_raw_mesh(&raw_mesh)

    vert_count := len(raw_mesh.positions)

    data.preallocate(.Vertex,       vert_count)
    data.preallocate(.Vertex_Cache, vert_count)
    data.preallocate(.DataPoint,    vert_count)

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

        vert_meta := data.add(.Vertex, vault.Vertex{pos = pos, normal = normal})

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

    // Build neighbor refs from face topology
    build_neighbors_from_indices(raw_mesh.indices, dp_offset)

    center = math.vec3{
        (bounds.x.min + bounds.x.max) * 0.5,
        (bounds.y.min + bounds.y.max) * 0.5,
        (bounds.z.min + bounds.z.max) * 0.5,
    }

    fmt.println("load_model: verts:", vert_count, "faces:", len(raw_mesh.indices) / 3, "center:", center)
    return bounds, center, true
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
    field.data = make([dynamic][dynamic]i32, finest_count)

    return field
}

// Populates field using polygon coverage — each face maps to all cells it covers
// dp_offset: first DataPoint index for this model
field_populate :: proc(field: ^vault.Field, dp_offset: int, indices: []u32) {
    face_count := len(indices) / 3
    for f in 0 ..< face_count {
        i0 := dp_offset + int(indices[f * 3 + 0])
        i1 := dp_offset + int(indices[f * 3 + 1])
        i2 := dp_offset + int(indices[f * 3 + 2])
        map_polygon_to_field(field, [3]int{i0, i1, i2})
    }

    // Propagate occupancy upward through levels
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
