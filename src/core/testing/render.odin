package testing


import rl "vendor:raylib"
import stbi "vendor:stb/image"
import math "core:math/linalg/glsl"

import "core:os"
import "core:fmt"

    width, height := 80, 60

    output_dir :: "image_debug_output/"
    frame_pixels : []u8
    image : rl.Image
    texture : rl.Texture2D
    pixel : math.ivec4





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

            pixel = cpu_fragment_shader(math.vec2{f32(x),f32(y)})

            pixels[idx + 0] = u8(pixel.x)   // R
            pixels[idx + 1] = u8(pixel.y)  // G
            pixels[idx + 2] = u8(pixel.z)                   // B
        }
    }
    
    return pixels
}

frame_write_to_image :: proc() {

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
        rl.ClearBackground(rl.BLACK)


        raylib_update_functions()

        rl.EndDrawing()
    }
}

