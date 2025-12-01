package testing

import "vendor:raylib"
import "../data"
import "core:fmt"
import "core:math"
import "core:slice"

import rl "vendor:raylib"
import stbi "vendor:stb/image"

import "core:os"

    width, height := 800, 600

    output_dir :: "image_debug_output/"
    frame_pixels : []u8
    image : rl.Image
    texture : rl.Texture2D


raylib_start_functions ::proc () {
    frame_pixels = generate_pixels(width, height)

    defer delete(frame_pixels)

    frame_write_to_image()
    raylib_render_frame()
       
}
raylib_update_functions :: proc () {
        if texture.id != 0 {
        rl.DrawTexture(texture, 0, 0, rl.WHITE)
    } else {
        fmt.println("Texture not loaded!")
    }
}




raylib_render_frame :: proc () {

        // Create image and texture
        image = rl.Image{
            data = raw_data(frame_pixels),
            width = i32(width),
            height = i32(height),
            mipmaps = 1,
            format = .UNCOMPRESSED_R8G8B8,
        }

                texture = rl.LoadTextureFromImage(image)
  
}

// Generate pixel data
generate_pixels :: proc(width, height: int) -> []u8 {
    pixels := make([]u8, width * height * 3)
    
    for y in 0..<height {
        for x in 0..<width {
            idx := (y * width + x) * 3
            pixels[idx + 0] = u8(x * 255 / width)   // R
            pixels[idx + 1] = u8(y * 255 / height)  // G
            pixels[idx + 2] = 128                    // B
        }
    }
    
    return pixels
}

frame_write_to_image :: proc() {
    // RGB image



    // Write PNG
    //stbi.write_png("output.png", i32(width), i32(height), 3, raw_data(pixels), i32(width * 3))
    // Find next available filename

    frame_number := 0

    // Create directory if it doesn't exist
    os.make_directory(output_dir)

    // Find next available number
    for {
        filename := fmt.tprintf("%sframe_%04d.png", output_dir, frame_number)
        if !os.exists(filename) {
            stbi.write_png(cstring(raw_data(filename)), i32(width), i32(height), 3, raw_data(frame_pixels), i32(width * 3))
            fmt.printf("Wrote %s\n", filename)
            break
        }
        frame_number += 1
    }
}

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
        
        vertices[i].x = x * scale_factor
        vertices[i].y = y * scale_factor
        vertices[i].z = z * scale_factor
        vertices[i].x_cell = i32(math.floor(x * scale_factor))
        vertices[i].y_cell = i32(math.floor(y * scale_factor))
        vertices[i]._pad = 0
        
        if vertices[i].z < min_z do min_z = vertices[i].z
        if vertices[i].z > max_z do max_z = vertices[i].z
    }
    
    // Sort vertices
    slice.sort_by(vertices, proc(a, b: data.Vertex) -> bool {
        if a.x_cell != b.x_cell do return a.x_cell < b.x_cell
        if a.y_cell != b.y_cell do return a.y_cell < b.y_cell
        return a.z < b.z
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
    world_min_x := vertices[0].x
    world_max_x := vertices[0].x
    world_min_y := vertices[0].y
    world_max_y := vertices[0].y
    
    for v in vertices {
        if v.x < world_min_x do world_min_x = v.x
        if v.x > world_max_x do world_max_x = v.x
        if v.y < world_min_y do world_min_y = v.y
        if v.y > world_max_y do world_max_y = v.y
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
        fmt.printf("[%d] (%.2f, %.2f, %.2f) cell:(%d, %d)\n", i, v.x, v.y, v.z, v.x_cell, v.y_cell)
    }
    
    return model_data
}

find_bounds :: proc(vertices: []data.Vertex) -> (min_x, max_x, min_y, max_y, min_z, max_z: f32) {
    if len(vertices) == 0 {
        return 0, 0, 0, 0, 0, 0
    }
    
    // Start with first vertex
    min_x = vertices[0].x
    max_x = vertices[0].x
    min_y = vertices[0].y
    max_y = vertices[0].y
    min_z = vertices[0].z
    max_z = vertices[0].z
    
    // Check all other vertices
    for i in 1..<len(vertices) {
        v := vertices[i]
        
        if v.x < min_x do min_x = v.x
        if v.x > max_x do max_x = v.x
        
        if v.y < min_y do min_y = v.y
        if v.y > max_y do max_y = v.y
        
        if v.z < min_z do min_z = v.z
        if v.z > max_z do max_z = v.z
    }
    
    return
}

raylib_render :: proc () {
        rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(i32(width), i32(height), "Software Renderer")
    defer rl.CloseWindow()
    
    //rl.SetTargetFPS(60)

    raylib_start_functions()

    for !rl.WindowShouldClose() {

        // Update title with FPS
        rl.SetWindowTitle(fmt.ctprintf("Software Renderer - FPS: %d", rl.GetFPS()))
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.RED)


        raylib_update_functions()

        rl.EndDrawing()
    }
}

render_sort :: proc() {

}