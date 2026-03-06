package testing

// TEMPORARY: raylib display layer — will be replaced by custom renderer
// image and texture live here because rl types cannot go in data package

import data "../_data"
import math "core:math/linalg/glsl"
import rl "vendor:raylib"
import "core:fmt"

image:   rl.Image
texture: rl.Texture2D

raylib_render_frame :: proc() {
    image = rl.Image{
        data    = raw_data(data.frame_pixels),
        width   = i32(data.SCREEN_WIDTH),
        height  = i32(data.SCREEN_HEIGHT),
        mipmaps = 1,
        format  = .UNCOMPRESSED_R8G8B8,
    }
    texture = rl.LoadTextureFromImage(image)
}

raylib_render :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(i32(data.SCREEN_WIDTH), i32(data.SCREEN_HEIGHT), "Software Renderer")
    defer rl.CloseWindow()

    raylib_start_functions()

    for !rl.WindowShouldClose() {
        rl.SetWindowTitle(fmt.ctprintf("Software Renderer - FPS: %d", rl.GetFPS()))
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        raylib_update_functions()
        rl.EndDrawing()
    }
}


raylib_start_functions :: proc() {
    start_functions()
    raylib_render_frame()
}

raylib_update_functions :: proc() {
    start_input := rl.GetTime()
    raylib_handle_camera_input()
    debug_time_input(rl.GetTime() - start_input)

    start_pixels := rl.GetTime()
    update_fuctions()
    debug_time_pixels(rl.GetTime() - start_pixels)

    start_texture := rl.GetTime()
    rl.UpdateTexture(texture, raw_data(data.frame_pixels))
    debug_time_texture(rl.GetTime() - start_texture)

    if texture.id != 0 {
        rl.DrawTexture(texture, 0, 0, rl.WHITE)
    } else {
        fmt.println("Texture not loaded!")
    }

    debug_draw_overlay()

    if rl.IsKeyPressed(.F12) {
        debug_write_image(data.frame_pixels, data.SCREEN_WIDTH, data.SCREEN_HEIGHT)
    }
}

raylib_handle_camera_input :: proc() {
    dt         := rl.GetFrameTime()
    move_speed := data.CAM_SPEED * dt * 60.0

    if rl.IsKeyDown(.LEFT_SHIFT) do move_speed *= 3.0

    if rl.IsKeyDown(.W) do data.CAM_POS.y += move_speed
    if rl.IsKeyDown(.S) do data.CAM_POS.y -= move_speed
    if rl.IsKeyDown(.A) do data.CAM_POS.x -= move_speed
    if rl.IsKeyDown(.D) do data.CAM_POS.x += move_speed
    if rl.IsKeyDown(.Q) do data.CAM_POS.z -= move_speed
    if rl.IsKeyDown(.E) do data.CAM_POS.z += move_speed
}