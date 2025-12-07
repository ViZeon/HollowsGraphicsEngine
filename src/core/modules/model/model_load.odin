package model

import "../../imports/imports_vendor"
import math "core:math/linalg/glsl"

import data "../../data"
import cgltf "vendor:cgltf"
import "core:fmt"

load_model :: proc(path: cstring) -> ([]math.vec3, bool) {
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
    
    // Find position accessor
    position_accessor: ^cgltf.accessor
    for attrib in primitive.attributes {
        if attrib.type == .position {
            position_accessor = attrib.data
            break
        }
    }
    
    if position_accessor == nil {
        fmt.println("No POSITION attribute found")
        return nil, false
    }
    
    // Extract raw vertex positions
    vertex_count := position_accessor.count
    //RAW_VERT := make([]f32, vertex_count * 3)
        // ADD THIS: Allocate the slice
    data.VERTICIES_RAW = make([]math.vec3, vertex_count)
    
    
    for i in 0..<vertex_count {
        pos: [3]f32
        read_ok := cgltf.accessor_read_float(position_accessor, i, &pos[0], 3)
        if !read_ok {
            fmt.println("Failed to read vertex", i)
            continue
        }
        
        data.VERTICIES_RAW[i].x = pos[0]
        data.VERTICIES_RAW[i].y = pos[1]
        data.VERTICIES_RAW[i].z = pos[2]
    }
    
    fmt.println("Loaded vertex count:", vertex_count)
    
    return data.VERTICIES_RAW, true
}