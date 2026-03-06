package model

import math "core:math/linalg/glsl"
import data "../../_data"
import "core:fmt"
import cgltf "vendor:cgltf"

// Loads raw vertex data from a glTF file.
// Returns local slice — caller owns the memory.
// NOTE: only loads mesh[0]/primitive[0], multi-mesh support TBD
load_model :: proc(path: cstring) -> ([]data.Vertex, bool) {
    options: cgltf.options
    gltf_data, result := cgltf.parse_file(options, path)
    if result != .success {
        fmt.println("Failed to load glTF:", result)
        return nil, false
    }
    defer cgltf.free(gltf_data)

    result = cgltf.load_buffers(options, gltf_data, path)
    if result != .success {
        fmt.println("Failed to load buffers:", result)
        return nil, false
    }

    fmt.println("Loaded meshes:", len(gltf_data.meshes))

    primitive := gltf_data.meshes[0].primitives[0]

    position_accessor: ^cgltf.accessor
    normal_accessor:   ^cgltf.accessor

    for attrib in primitive.attributes {
        if attrib.type == .position do position_accessor = attrib.data
        if attrib.type == .normal   do normal_accessor   = attrib.data
    }

    if position_accessor == nil {
        fmt.println("No POSITION attribute found")
        return nil, false
    }

    vertex_count := position_accessor.count
    vertices     := make([]data.Vertex, vertex_count)

    for i in 0 ..< vertex_count {
        pos: [3]f32
        if !cgltf.accessor_read_float(position_accessor, i, &pos[0], 3) {
            fmt.println("Failed to read vertex", i)
            continue
        }
        vertices[i].pos = math.vec3{pos[0], pos[1], pos[2]}

        if normal_accessor != nil {
            norm: [3]f32
            if cgltf.accessor_read_float(normal_accessor, i, &norm[0], 3) {
                vertices[i].normal = math.vec3{norm[0], norm[1], norm[2]}
            }
        }
    }

    return vertices, true
}