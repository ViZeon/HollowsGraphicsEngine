package testing

import data "../data"
import model "../modules/model"

import "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:slice"
import m "core:math/linalg/glsl"


tmp_pixel : m.ivec4



// Process raw vertices into Model_Data
process_vertices :: proc(VERTICES: ^[]m.vec3, scale_factor: f32) -> []data.Vertex {
    model_data: data.Model_Data
    
    //vertices := make([]data.Vertex, vertex_count)
        // ADD THIS: Allocate the vertices slice
    data.MODEL_DATA.VERTICES = make([]data.Vertex, len(VERTICES))
    
    min_z := f32(math.F32_MAX)
    max_z := f32(math.F32_MIN)
    
    // Scale and calculate cells
    for i in 0..<len(VERTICES)-1 {
        
        data.MODEL_DATA.VERTICES[i].pos.x = VERTICES[i].x * scale_factor
        data.MODEL_DATA.VERTICES[i].pos.y = VERTICES[i].y * scale_factor
        data.MODEL_DATA.VERTICES[i].pos.z = VERTICES[i].z * scale_factor
        

        //replace with the find bounds method after fixing both
        if data.MODEL_DATA.VERTICES[i].pos.z < min_z do min_z = data.MODEL_DATA.VERTICES[i].pos.z
        if data.MODEL_DATA.VERTICES[i].pos.z > max_z do max_z = data.MODEL_DATA.VERTICES[i].pos.z
    }
    
    // Sort vertices
    slice.sort_by(data.VERTICIES_RAW, proc(a, b: m.vec3) -> bool {
        if m.floor( a.x) != m.floor( b.x) do return m.floor( a.x) < m.floor( b.x)
        if m.floor( a.y) != m.floor( b.y) do return m.floor( a.y) < m.floor( b.y)
        return a.z < b.z
    })

    // Verify sort
    for i in 1..<len(data.VERTICIES_RAW) {
        a := data.VERTICIES_RAW[i-1]
        b := data.VERTICIES_RAW[i]
        if m.floor(a.x) > m.floor(b.x) || (m.floor(a.x) == m.floor(b.x) && m.floor(a.y) > m.floor(b.y)) {
            fmt.eprintf("SORTING BUG at index %d: prev (%d,%d) curr (%d,%d)\n",
                       i, a.x, a.y, b.x, b.y)
        }
    }

    fmt.println("\nFirst 5 sorted vertices:")
    for i in 0..<min(5, len(data.VERTICIES_RAW)) {
        v := data.VERTICIES_RAW[i]
        fmt.printf("[%d] (%.2f, %.2f, %.2f) cell:(%d, %d)\n", i, v.x, v.y, v.z)
    }
    
    return model_data.VERTICES
}
/*
find_bounds :: proc(vertices: []data.Vertex) -> (min_x, max_x, min_y, max_y, min_z, max_z: f32) {
    if len(vertices) == 0 {
        return 0, 0, 0, 0, 0, 0
    }
    
    // Start with first vertex
    min_x = vertices[0].coordinates.x
    max_x = vertices[0].coordinates.x
    min_y = vertices[0].coordinates.y
    max_y = vertices[0].coordinates.y
    min_z = vertices[0].coordinates.z
    max_z = vertices[0].coordinates.z
    
    // Check all other vertices
    for i in 1..<len(vertices) {
        v := vertices[i]
        
        if v.coordinates.x < min_x do min_x = v.coordinates.x
        if v.coordinates.x > max_x do max_x = v.coordinates.x
        
        if v.coordinates.y < min_y do min_y = v.coordinates.y
        if v.coordinates.y > max_y do max_y = v.coordinates.y
        
        if v.coordinates.z < min_z do min_z = v.coordinates.z
        if v.coordinates.z > max_z do max_z = v.coordinates.z
    }
    
    return
}*/