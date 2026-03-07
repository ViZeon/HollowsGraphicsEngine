package testing

import data "../_data"
import math "core:math/linalg/glsl"
import rl "vendor:raylib"
import "core:fmt"

image:   rl.Image
texture: rl.Texture2D

raylib_render_frame :: proc() {
    screen_w := get(data.screen_width).(int)
    screen_h := get(data.screen_height).(int)
    image = rl.Image{
        data    = raw_data(data.frame_pixels),
        width   = i32(screen_w),
        height  = i32(screen_h),
        mipmaps = 1,
        format  = .UNCOMPRESSED_R8G8B8,
    }
    texture = rl.LoadTextureFromImage(image)
}

raylib_render :: proc() {
    screen_w := get(data.screen_width).(int)
    screen_h := get(data.screen_height).(int)
    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(i32(screen_w), i32(screen_h), "Software Renderer")
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
        debug_write_image(data.frame_pixels, get(data.screen_width).(int), get(data.screen_height).(int))
    }
}

raylib_handle_camera_input :: proc() {
    dt         := rl.GetFrameTime()
    cam_speed  := get(data.cam_speed).(f32)
    move_speed := cam_speed * dt * 60.0
    if rl.IsKeyDown(.LEFT_SHIFT) do move_speed *= 3.0

    cam := get(data.cam_pos).(math.vec3)
    if rl.IsKeyDown(.W) do cam.y += move_speed
    if rl.IsKeyDown(.S) do cam.y -= move_speed
    if rl.IsKeyDown(.A) do cam.x -= move_speed
    if rl.IsKeyDown(.D) do cam.x += move_speed
    if rl.IsKeyDown(.Q) do cam.z -= move_speed
    if rl.IsKeyDown(.E) do cam.z += move_speed
    set(data.cam_pos, cam)
}