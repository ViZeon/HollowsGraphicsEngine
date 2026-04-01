package model

import vault "../../_vault"
import math  "core:math/linalg/glsl"
import "core:fmt"
import "core:strings"
import cgltf "vendor:cgltf"

load_gltf :: proc(path: string) -> (source: vault.Model_Source, ok: bool) {
    path_c := strings.clone_to_cstring(path)
    defer delete(path_c)

    options: cgltf.options
    gltf_data, result := cgltf.parse_file(options, path_c)
    if result != .success {
        fmt.println("gltf_load: failed to parse:", result)
        return {}, false
    }
    defer cgltf.free(gltf_data)

    result = cgltf.load_buffers(options, gltf_data, path_c)
    if result != .success {
        fmt.println("gltf_load: failed to load buffers:", result)
        return {}, false
    }

    fmt.println("gltf_load: meshes found:", len(gltf_data.meshes))

    primitive := gltf_data.meshes[0].primitives[0]

    position_accessor: ^cgltf.accessor
    normal_accessor:   ^cgltf.accessor

    for attrib in primitive.attributes {
        if attrib.type == .position do position_accessor = attrib.data
        if attrib.type == .normal   do normal_accessor   = attrib.data
    }

    if position_accessor == nil {
        fmt.println("gltf_load: no POSITION attribute found")
        return {}, false
    }

    source.name = strings.clone(path)
    source.path = strings.clone(path)

    vertex_count := position_accessor.count
    for i in 0 ..< vertex_count {
        vert: vault.Vertex
        pos: [3]f32
        if cgltf.accessor_read_float(position_accessor, i, &pos[0], 3) {
            vert.source.pos = math.vec3{pos[0], pos[1], pos[2]}
        }
        if normal_accessor != nil {
            norm: [3]f32
            if cgltf.accessor_read_float(normal_accessor, i, &norm[0], 3) {
                vert.source.normal = math.vec3{norm[0], norm[1], norm[2]}
            }
        }
        vert.source.color = {1, 1, 1}
        append(&source.verts, vert)
    }

    // Build polys from index buffer — glTF is always triangles
    if primitive.indices != nil {
        index_count := primitive.indices.count
        face_count  := index_count / 3
        fmt.println("gltf_load: indices:", index_count, "faces:", face_count)
        for f in 0 ..< face_count {
            poly: vault.Polygon
            append(&poly.source.vert_indices, i32(cgltf.accessor_read_index(primitive.indices, f * 3 + 0)))
            append(&poly.source.vert_indices, i32(cgltf.accessor_read_index(primitive.indices, f * 3 + 1)))
            append(&poly.source.vert_indices, i32(cgltf.accessor_read_index(primitive.indices, f * 3 + 2)))
            poly.source.material_slot = 0
            append(&source.polys, poly)
        }
    } else {
        fmt.println("gltf_load: no index buffer — generating sequential triangles")
        face_count := vertex_count / 3
        for f in 0 ..< face_count {
            poly: vault.Polygon
            append(&poly.source.vert_indices, i32(f * 3 + 0))
            append(&poly.source.vert_indices, i32(f * 3 + 1))
            append(&poly.source.vert_indices, i32(f * 3 + 2))
            append(&source.polys, poly)
        }
    }

    fmt.println("gltf_load: verts:", len(source.verts), "polys:", len(source.polys))
    return source, true
}