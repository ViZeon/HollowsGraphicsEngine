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
process_vertices :: proc(vertices: ^[]m.vec3, scale_factor: f32) -> []data.Vertex {
    // Scale all vertices
    scaled := make([]data.Vertex, len(vertices))
    for i in 0..<len(vertices) {
        scaled[i].pos.x = vertices[i].x * scale_factor
        scaled[i].pos.y = vertices[i].y * scale_factor
        scaled[i].pos.z = vertices[i].z * scale_factor
    }
    
    // Sort by floor(x), floor(y), then z
    slice.sort_by(scaled, proc(a, b: data.Vertex) -> bool {
        if m.floor(a.pos.x) != m.floor(b.pos.x) do return m.floor(a.pos.x) < m.floor(b.pos.x)
        if m.floor(a.pos.y) != m.floor(b.pos.y) do return m.floor(a.pos.y) < m.floor(b.pos.y)
        return a.pos.z < b.pos.z
    })
    
    // Verify sort
    for i in 1..<len(scaled) {
        a := scaled[i-1].pos
        b := scaled[i].pos
        if m.floor(a.x) > m.floor(b.x) || (m.floor(a.x) == m.floor(b.x) && m.floor(a.y) > m.floor(b.y)) {
            fmt.eprintf("SORTING BUG at index %d: prev (%.3f,%.3f) curr (%.3f,%.3f)\n",
                       i, a.x, a.y, b.x, b.y)
        }
    }
    
    return scaled
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