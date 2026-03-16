package testing

import vault "../../core/_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"
import rl    "vendor:raylib"
import "core:fmt"

image:   rl.Image
texture: rl.Texture2D

raylib_render_frame :: proc() {
    screen_w := (^int)(data.edit(vault.screen_width))^
    screen_h := (^int)(data.edit(vault.screen_height))^
    image = rl.Image{
        data    = raw_data(vault.frame_pixels),
        width   = i32(screen_w),
        height  = i32(screen_h),
        mipmaps = 1,
        format  = .UNCOMPRESSED_R8G8B8,
    }
    texture = rl.LoadTextureFromImage(image)
}

raylib_render :: proc() {
    screen_w := (^int)(data.edit(vault.screen_width))^
    screen_h := (^int)(data.edit(vault.screen_height))^
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
    // F2 — toggle fetch timing (before debug_frame_end reads it)
    if rl.IsKeyPressed(.F2) do debug_toggle_timing()

    start_input := rl.GetTime()
    raylib_handle_camera_input()
    debug_time_input(rl.GetTime() - start_input)

    start_pixels := rl.GetTime()
    update_fuctions()
    debug_time_pixels(rl.GetTime() - start_pixels)

    start_texture := rl.GetTime()
    rl.UpdateTexture(texture, raw_data(vault.frame_pixels))
    debug_time_texture(rl.GetTime() - start_texture)

    if texture.id != 0 {
        rl.DrawTexture(texture, 0, 0, rl.WHITE)
    } else {
        fmt.println("Texture not loaded!")
    }

    debug_draw_overlay()

    if rl.IsKeyPressed(.F12) {
        debug_write_image(
            vault.frame_pixels,
            (^int)(data.edit(vault.screen_width))^,
            (^int)(data.edit(vault.screen_height))^,
        )
    }
}

debug_draw_overlay :: proc() {
    stats   := (^vault.Debug_Stats)(data.edit(vault.debug_stats))
    cam_pos := (^math.vec3)(data.edit(vault.cam_pos))

    if rl.IsKeyDown(.F1) {
        fps := (^int)(data.edit(vault.fps))^
        rl.DrawRectangle(10, 10, 280, 100, rl.ColorAlpha(rl.BLACK, 0.7))
        y := i32(20)
        rl.DrawText(fmt.ctprintf("FPS: %d", fps), 20, y, 20, rl.GREEN)
        y += 25
        rl.DrawText(fmt.ctprintf("Pixel: %.1fms", stats.pixel_time * 1000), 20, y, 20, rl.YELLOW)
        y += 25
        rl.DrawText(fmt.ctprintf("Cam: [%.1f, %.1f, %.1f]", cam_pos.x, cam_pos.y, cam_pos.z), 20, y, 20, rl.WHITE)
        y += 25
        if stats.timing_enabled {
            rl.DrawText("F2: timing ON",  20, y, 16, rl.GREEN)
        } else {
            rl.DrawText("F2: timing OFF", 20, y, 16, rl.DARKGRAY)
        }
        rl.DrawText("Hold F1: overlay | F12: capture", 10, 570, 16, rl.DARKGRAY)
    } else {
        rl.DrawText("F1: debug overlay", 10, 570, 16, rl.DARKGRAY)
    }
}

raylib_handle_camera_input :: proc() {
    dt         := rl.GetFrameTime()
    cam_speed  := (^f32)(data.edit(vault.cam_speed))^
    move_speed := cam_speed * dt * 60.0
    if rl.IsKeyDown(.LEFT_SHIFT) do move_speed *= 3.0

    cam := (^math.vec3)(data.edit(vault.cam_pos))
    if rl.IsKeyDown(.W) do cam.y += move_speed
    if rl.IsKeyDown(.S) do cam.y -= move_speed
    if rl.IsKeyDown(.A) do cam.x -= move_speed
    if rl.IsKeyDown(.D) do cam.x += move_speed
    if rl.IsKeyDown(.Q) do cam.z -= move_speed
    if rl.IsKeyDown(.E) do cam.z += move_speed
}
