package model

import "../../imports/imports_vendor"
import math "core:math/linalg/glsl"

import data "../../data"
import cgltf "vendor:cgltf"
import "core:fmt"

load_model :: proc(path: cstring) -> ([]data.Vertex, bool) {
    // Load glTF
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
    
    mesh := gltf_data.meshes[0]
    primitive := mesh.primitives[0]
    
    // Find position accessor (existing code)
    position_accessor: ^cgltf.accessor
    for attrib in primitive.attributes {
        if attrib.type == .position {
            position_accessor = attrib.data
            break
        }
    }
    
    // Find normal accessor
    normal_accessor: ^cgltf.accessor
    for attrib in primitive.attributes {
        if attrib.type == .normal {
            normal_accessor = attrib.data
            break
        }
    }
    
    if position_accessor == nil {
        fmt.println("No POSITION attribute found")
        return nil, false
    }
    
    vertex_count := position_accessor.count
    data.VERTICIES_RAW = make([]data.Vertex, vertex_count)
    
   for i in 0..<vertex_count {
    pos: [3]f32
    read_ok := cgltf.accessor_read_float(position_accessor, i, &pos[0], 3)
    if !read_ok {
        fmt.println("Failed to read vertex", i)
        continue
    }
    
    data.VERTICIES_RAW[i].pos.x = pos[0] * data.SCALE_FACTOR
    data.VERTICIES_RAW[i].pos.y = pos[1] * data.SCALE_FACTOR
    data.VERTICIES_RAW[i].pos.z = pos[2] * data.SCALE_FACTOR
    
    // Read normal if available
    if normal_accessor != nil {
        norm: [3]f32
        norm_ok := cgltf.accessor_read_float(normal_accessor, i, &norm[0], 3)
        if norm_ok {
            data.VERTICIES_RAW[i].normal = math.vec3{norm[0], norm[1], norm[2]}
        }
    }
    
    data.VERTICIES_RAW[i].fov = -1
}
    
    return data.VERTICIES_RAW, true
}