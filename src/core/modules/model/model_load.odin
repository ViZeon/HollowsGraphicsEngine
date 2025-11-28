package model

import "../../imports/imports_vendor"
import "../../data"
import cgltf "vendor:cgltf"
import "core:fmt"

load_model :: proc(path: cstring) -> ([]f32, int, bool) {
    // Load glTF
    options: cgltf.options
    gltf_data, result := cgltf.parse_file(options, path)
    if result != .success {
        fmt.println("Failed to load glTF:", result)
        return nil, 0, false
    }
    defer cgltf.free(gltf_data)
    
    result = cgltf.load_buffers(options, gltf_data, path)
    if result != .success {
        fmt.println("Failed to load buffers:", result)
        return nil, 0, false
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
        return nil, 0, false
    }
    
    // Extract raw vertex positions
    vertex_count := position_accessor.count
    raw_vertices := make([]f32, vertex_count * 3)
    
    for i in 0..<vertex_count {
        pos: [3]f32
        read_ok := cgltf.accessor_read_float(position_accessor, i, &pos[0], 3)
        if !read_ok {
            fmt.println("Failed to read vertex", i)
            continue
        }
        
        raw_vertices[i*3 + 0] = pos[0]
        raw_vertices[i*3 + 1] = pos[1]
        raw_vertices[i*3 + 2] = pos[2]
    }
    
    fmt.println("Loaded vertex count:", vertex_count)
    
    return raw_vertices, int(vertex_count), true
}