package model

import math "core:math/linalg/glsl"
import "core:fmt"
import cgltf "vendor:cgltf"

// Raw mesh data returned from glTF — caller owns all slices
Raw_Mesh :: struct {
    positions: []math.vec3,
    normals:   []math.vec3,
    indices:   []u32,        // face topology — 3 indices per triangle
}

// Loads raw mesh data from a glTF file
// Returns Raw_Mesh — caller owns and must delete all slices
// NOTE: only loads mesh[0]/primitive[0], multi-mesh support TBD
load_gltf :: proc(path: cstring) -> (mesh: Raw_Mesh, ok: bool) {
    options: cgltf.options
    gltf_data, result := cgltf.parse_file(options, path)
    if result != .success {
        fmt.println("gltf_load: failed to parse:", result)
        return {}, false
    }
    defer cgltf.free(gltf_data)

    result = cgltf.load_buffers(options, gltf_data, path)
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

    vertex_count := position_accessor.count
    mesh.positions = make([]math.vec3, vertex_count)
    mesh.normals   = make([]math.vec3, vertex_count)

    for i in 0 ..< vertex_count {
        pos: [3]f32
        if !cgltf.accessor_read_float(position_accessor, i, &pos[0], 3) {
            fmt.println("gltf_load: failed to read position", i)
            continue
        }
        mesh.positions[i] = math.vec3{pos[0], pos[1], pos[2]}

        if normal_accessor != nil {
            norm: [3]f32
            if cgltf.accessor_read_float(normal_accessor, i, &norm[0], 3) {
                mesh.normals[i] = math.vec3{norm[0], norm[1], norm[2]}
            }
        }
    }

    // Load index buffer for face topology
    if primitive.indices != nil {
        index_count  := primitive.indices.count
        mesh.indices  = make([]u32, index_count)
        for i in 0 ..< index_count {
            mesh.indices[i] = u32(cgltf.accessor_read_index(primitive.indices, i))
        }
        fmt.println("gltf_load: indices loaded:", index_count, "faces:", index_count / 3)
    } else {
        fmt.println("gltf_load: no index buffer — generating sequential indices")
        mesh.indices = make([]u32, vertex_count)
        for i in 0 ..< vertex_count {
            mesh.indices[i] = u32(i)
        }
    }

    fmt.println("gltf_load: verts:", vertex_count)
    return mesh, true
}

// Frees all slices in a Raw_Mesh
free_raw_mesh :: proc(mesh: ^Raw_Mesh) {
    delete(mesh.positions)
    delete(mesh.normals)
    delete(mesh.indices)
}
