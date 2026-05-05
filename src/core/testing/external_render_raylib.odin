package testing

import vault "../../core/_vault"
import data  "../modules/data"
import wr "../_wrappers"

image:   wr.Image
texture: wr.Texture2D



raylib_render_frame :: proc() {
    screen_w := (^int)(data.edit(vault.screen_width))^
    screen_h := (^int)(data.edit(vault.screen_height))^
// raylib_render_frame:

    image = wr.Image{
        data    = raw_data(screen_tex.source.pixels),
        width   = i32(screen_w),
        height  = i32(screen_h),
        mipmaps = 1,
        format  = .UNCOMPRESSED_R8G8B8,
    }
    texture = wr.rl_load_texture_from_image(image)
}

raylib_render :: proc() {
    screen_w := (^int)(data.edit(vault.screen_width))^
    screen_h := (^int)(data.edit(vault.screen_height))^
    wr.rl_set_config_flags({.WINDOW_RESIZABLE})
    wr.rl_init_window(i32(screen_w), i32(screen_h), "Software Renderer")
    defer wr.rl_close_window()

    raylib_start_functions()

    for !wr.rl_window_should_close() {
        wr.rl_set_window_title(wr.fmt_ctprintf("Software Renderer - FPS: %d", wr.rl_get_fps()))
        wr.rl_begin_drawing()
        wr.rl_clear_background(wr.RL_BLACK)
        raylib_update_functions()
        wr.rl_end_drawing()
    }
}

raylib_start_functions :: proc() {
    start_functions()
    raylib_render_frame()
}

raylib_update_functions :: proc() {
    // F2 — toggle fetch timing (before debug_frame_end reads it)
    if wr.rl_is_key_pressed(wr.KEY_F2) do debug_toggle_timing()

    start_input := wr.rl_get_time()
    raylib_handle_camera_input()
    debug_time_input(wr.rl_get_time() - start_input)

    start_pixels := wr.rl_get_time()
    update_fuctions()
    debug_time_pixels(wr.rl_get_time() - start_pixels)

    start_texture := wr.rl_get_time()

    wr.rl_update_texture(texture, raw_data(screen_tex.source.pixels))
    debug_time_texture(wr.rl_get_time() - start_texture)

    if texture.id != 0 {
        wr.rl_draw_texture(texture, 0, 0, wr.RL_WHITE)
    } else {
        wr.fmt_println("Texture not loaded!")
    }

    debug_draw_overlay()

    if wr.rl_is_key_pressed(wr.KEY_F12) {
        debug_write_image(
            screen_tex.source.pixels[:],
            (^int)(data.edit(vault.screen_width))^,
            (^int)(data.edit(vault.screen_height))^,
        )
    }
}

debug_draw_overlay :: proc() {
    stats   := (^vault.Debug_Stats)(data.edit(vault.debug_stats))
    cam_pos := (^wr.Vec3)(data.edit(vault.cam_pos))

    if wr.rl_is_key_down(wr.KEY_F1) {
        fps := (^int)(data.edit(vault.fps))^
        wr.rl_draw_rectangle(10, 10, 280, 100, wr.rl_color_alpha(wr.RL_BLACK, 0.7))
        y := i32(20)
        wr.rl_draw_text(wr.fmt_ctprintf("FPS: %d", fps), 20, y, 20, wr.RL_GREEN)
        y += 25
        wr.rl_draw_text(wr.fmt_ctprintf("Pixel: %.1fms", stats.pixel_time * 1000), 20, y, 20, wr.RL_YELLOW)
        y += 25
        wr.rl_draw_text(wr.fmt_ctprintf("Cam: [%.1f, %.1f, %.1f]", cam_pos.x, cam_pos.y, cam_pos.z), 20, y, 20, wr.RL_WHITE)
        y += 25
        if stats.timing_enabled {
            wr.rl_draw_text("F2: timing ON",  20, y, 16, wr.RL_GREEN)
        } else {
            wr.rl_draw_text("F2: timing OFF", 20, y, 16, wr.RL_DARKGRAY)
        }
        wr.rl_draw_text("Hold F1: overlay | F12: capture", 10, 570, 16, wr.RL_DARKGRAY)
    } else {
        wr.rl_draw_text("F1: debug overlay", 10, 570, 16, wr.RL_DARKGRAY)
    }
}

raylib_handle_camera_input :: proc() {
    dt         := wr.rl_get_frame_time()
    cam_speed  := (^f32)(data.edit(vault.cam_speed))^
    move_speed := cam_speed * dt * 60.0
    if wr.rl_is_key_down(wr.KEY_LEFT_SHIFT) do move_speed *= 3.0

    cam := (^wr.Vec3)(data.edit(vault.cam_pos))
    if wr.rl_is_key_down(wr.KEY_W) do cam.y += move_speed
    if wr.rl_is_key_down(wr.KEY_S) do cam.y -= move_speed
    if wr.rl_is_key_down(wr.KEY_A) do cam.x -= move_speed
    if wr.rl_is_key_down(wr.KEY_D) do cam.x += move_speed
    if wr.rl_is_key_down(wr.KEY_Q) do cam.z -= move_speed
    if wr.rl_is_key_down(wr.KEY_E) do cam.z += move_speed
}