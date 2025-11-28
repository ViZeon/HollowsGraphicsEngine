package model

import "../../imports/imports_vendor"
import cgltf "vendor:cgltf"
import "core:fmt"
import os "core:os"
import "core:fmt"
import "core:math"
import "core:slice"


model_load :: proc (MODEL_PATH:string) -> () {

    // Load glTF
    options: cgltf.options
    data, result := cgltf.parse_file(options, "assets/ABeautifulGame.glb")
    if result != .success {
        fmt.println("Failed to load glTF:", result)
        return
    }
    defer cgltf.free(data)
    
    result = cgltf.load_buffers(options, data, "assets/ABeautifulGame.glb")
    if result != .success {
        fmt.println("Failed to load buffers:", result)
        return
    }
    
    fmt.println("Loaded meshes:", len(data.meshes))
    
    mesh := data.meshes[0]
    primitive := mesh.primitives[0]
    
    position_accessor: ^cgltf.accessor
    for attrib in primitive.attributes {
        if attrib.type == .position {
            position_accessor = attrib.data
            break
        }
    }
        if position_accessor == nil {
        fmt.println("No POSITION attribute found")
        return
    }
    
    vertex_count := position_accessor.count
    vertices := make([]Vertex, vertex_count)
    defer delete(vertices)
}