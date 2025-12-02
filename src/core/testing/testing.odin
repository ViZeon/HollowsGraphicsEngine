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
process_vertices :: proc(raw_vertices: []f32, vertex_count: int, scale_factor: f32) -> data.Model_Data {
    model_data: data.Model_Data
    
    vertices := make([]data.Vertex, vertex_count)
    
    min_z := f32(math.F32_MAX)
    max_z := f32(math.F32_MIN)
    
    // Scale and calculate cells
    for i in 0..<vertex_count {
        x := raw_vertices[i*3 + 0]
        y := raw_vertices[i*3 + 1]
        z := raw_vertices[i*3 + 2]
        
        vertices[i].coordinates.x = x * scale_factor
        vertices[i].coordinates.y = y * scale_factor
        vertices[i].coordinates.z = z * scale_factor
        vertices[i].x_cell = i32(math.floor(x * scale_factor))
        vertices[i].y_cell = i32(math.floor(y * scale_factor))
        vertices[i]._pad = 0
        
        if vertices[i].coordinates.z < min_z do min_z = vertices[i].coordinates.z
        if vertices[i].coordinates.z > max_z do max_z = vertices[i].coordinates.z
    }
    
    // Sort vertices
    slice.sort_by(vertices, proc(a, b: data.Vertex) -> bool {
        if a.x_cell != b.x_cell do return a.x_cell < b.x_cell
        if a.y_cell != b.y_cell do return a.y_cell < b.y_cell
        return a.coordinates.z < b.coordinates.z
    })

    // Verify sort
    for i in 1..<len(vertices) {
        a := vertices[i-1]
        b := vertices[i]
        if a.x_cell > b.x_cell || (a.x_cell == b.x_cell && a.y_cell > b.y_cell) {
            fmt.eprintf("SORTING BUG at index %d: prev (%d,%d) curr (%d,%d)\n",
                       i, a.x_cell, a.y_cell, b.x_cell, b.y_cell)
        }
    }
    
    // Calculate world bounds
    world_min_x := vertices[0].coordinates.x
    world_max_x := vertices[0].coordinates.x
    world_min_y := vertices[0].coordinates.y
    world_max_y := vertices[0].coordinates.y
    
    for v in vertices {
        if v.coordinates.x < world_min_x do world_min_x = v.coordinates.x
        if v.coordinates.x > world_max_x do world_max_x = v.coordinates.x
        if v.coordinates.y < world_min_y do world_min_y = v.coordinates.y
        if v.coordinates.y > world_max_y do world_max_y = v.coordinates.y
    }
    
    // Populate model data
    model_data.vertices = vertices
    model_data.vertex_count = vertex_count
    /*
    model_data.min_z = min_z
    model_data.max_z = max_z
    model_data.world_min_x = world_min_x
    model_data.world_max_x = world_max_x
    model_data.world_min_y = world_min_y
    model_data.world_max_y = world_max_y
    */

    model_data.world_min_x,
    model_data.world_max_x, 
    model_data.world_min_y, 
    model_data.world_max_y, 
    min_z, 
    max_z = find_bounds(model_data.vertices)

    // Store in your model data

    // Debug output
    fmt.println("Min Z:", min_z, "Max Z:", max_z)
    fmt.println("Vertex count:", vertex_count)
    fmt.printf("World bounds after scaling: X %.1f .. %.1f Y %.1f .. %.1f\n",
               world_min_x, world_max_x, world_min_y, world_max_y)
    
    fmt.println("\nFirst 5 sorted vertices:")
    for i in 0..<min(5, len(vertices)) {
        v := vertices[i]
        fmt.printf("[%d] (%.2f, %.2f, %.2f) cell:(%d, %d)\n", i, v.coordinates.x, v.coordinates.y, v.coordinates.z, v.x_cell, v.y_cell)
    }
    
    return model_data
}

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
}


render_sort :: proc() {

}