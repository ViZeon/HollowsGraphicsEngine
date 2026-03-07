package testing

import data "../_data"
import "core:time"
import "core:fmt"
import math "core:math/linalg/glsl"
import rl "vendor:raylib"

debug_init :: proc() {
    stats := (^data.Debug_Stats)(get(data.debug_stats))
    stats.min_range_size  = max(i32)
    stats.last_print_time = rl.GetTime()
    stats.last_cam_pos    = (^math.vec3)(get(data.cam_pos))^
}

debug_frame_begin :: proc() {
    stats := (^data.Debug_Stats)(get(data.debug_stats))
    stats.frame_vertices_checked = 0
    stats.frame_pixels_processed = 0
}

debug_frame_end :: proc() {
    app_time  := (^i64)(get(data.app_time))
    frame_t   := time.now()._nsec - app_time^
    (^i64)(get(data.frame_time))^ = frame_t
    (^int)(get(data.fps))^        = calc_FPS(frame_t)
    app_time^                     = time.now()._nsec

    current_time := app_time^ / 1000000000
    stats        := (^data.Debug_Stats)(get(data.debug_stats))
    debug_t      := (^f64)(get(data.debug_time))^

    if f64(current_time) - stats.last_print_time > debug_t {
        avg   := f32(stats.total_vertices_checked) / f32(stats.total_pixels_processed)
        favg  := f32(stats.frame_vertices_checked)  / f32(stats.frame_pixels_processed)

        fmt.printf("=== PERFORMANCE ===\n")
        fmt.printf("Input: %.3fms | Pixels: %.1fms | Texture: %.3fms | FPS: %d\n",
            stats.input_time * 1000, stats.pixel_time * 1000, stats.texture_time * 1000,
            (^int)(get(data.fps))^)
        fmt.printf("=== VERTEX CHECKS ===\n")
        fmt.printf("This frame avg: %.1f verts/pixel | Overall avg: %.1f verts/pixel\n", favg, avg)
        fmt.printf("Range sizes - Min: %d | Max: %d\n", stats.min_range_size, stats.max_range_size)

        cam_pos := (^math.vec3)(get(data.cam_pos))
        fmt.printf("=== CAMERA ===\n")
        fmt.printf("Pos: [%.1f, %.1f, %.1f]\n", cam_pos.x, cam_pos.y, cam_pos.z)

        if cam_pos^ != stats.last_cam_pos {
            fmt.printf("Camera moved: delta [%.1f, %.1f, %.1f]\n",
                cam_pos.x - stats.last_cam_pos.x,
                cam_pos.y - stats.last_cam_pos.y,
                cam_pos.z - stats.last_cam_pos.z)
        }

        fmt.println((^i64)(get(data.frame_time))^, app_time^)
        stats.last_print_time = f64(current_time)
        stats.last_cam_pos    = cam_pos^
    }
}

debug_time_input   :: proc(t: f64) { (^data.Debug_Stats)(get(data.debug_stats)).input_time   = t }
debug_time_pixels  :: proc(t: f64) { (^data.Debug_Stats)(get(data.debug_stats)).pixel_time   = t }
debug_time_texture :: proc(t: f64) { (^data.Debug_Stats)(get(data.debug_stats)).texture_time = t }

debug_record_pixel_search :: proc(range_size: i32) {
    stats := (^data.Debug_Stats)(get(data.debug_stats))
    stats.total_pixels_processed += 1
    stats.frame_pixels_processed += 1
    stats.total_vertices_checked += int(range_size)
    stats.frame_vertices_checked += int(range_size)
    if range_size > stats.max_range_size do stats.max_range_size = range_size
    if range_size < stats.min_range_size && range_size > 0 do stats.min_range_size = range_size
}

debug_write_image :: proc(pixels: []u8, width, height: int) {
    frame_write_to_image()
    cam_pos := (^math.vec3)(get(data.cam_pos))
    stats   := (^data.Debug_Stats)(get(data.debug_stats))
    fmt.println("=== DEBUG FRAME CAPTURED ===")
    fmt.printf("Camera: [%.1f, %.1f, %.1f]\n", cam_pos.x, cam_pos.y, cam_pos.z)
    fmt.printf("FPS: %d\n", rl.GetFPS())
    fmt.printf("Avg verts checked: %.1f\n", f32(stats.frame_vertices_checked) / f32(stats.frame_pixels_processed))
    fmt.printf("Range: %d - %d vertices\n", stats.min_range_size, stats.max_range_size)
    fmt.println("===========================\n")
}

debug_model_loaded :: proc(vertex_count: int, bounds: data.Bounds) {
    fmt.println("=== MODEL LOADED ===")
    fmt.printf("Vertices: %d\n", vertex_count)
    fmt.printf("Bounds X: [%f, %f]\n", bounds.x.min, bounds.x.max)
    fmt.printf("Bounds Y: [%f, %f]\n", bounds.y.min, bounds.y.max)
    fmt.printf("Bounds Z: [%f, %f]\n", bounds.z.min, bounds.z.max)
    fmt.println("===================\n")
}

debug_draw_overlay :: proc() {
    stats   := (^data.Debug_Stats)(get(data.debug_stats))
    cam_pos := (^math.vec3)(get(data.cam_pos))

    if rl.IsKeyDown(.F1) {
        rl.DrawRectangle(10, 10, 300, 120, rl.ColorAlpha(rl.BLACK, 0.7))
        y := i32(20)
        rl.DrawText(fmt.ctprintf("FPS: %d", rl.GetFPS()), 20, y, 20, rl.GREEN)
        y += 25
        rl.DrawText(fmt.ctprintf("Cam: [%.0f, %.0f, %.0f]", cam_pos.x, cam_pos.y, cam_pos.z), 20, y, 20, rl.WHITE)
        y += 25
        avg := f32(stats.frame_vertices_checked) / f32(stats.frame_pixels_processed)
        rl.DrawText(fmt.ctprintf("Verts/Pixel: %.1f", avg), 20, y, 20, rl.YELLOW)
        y += 25
        rl.DrawText(fmt.ctprintf("Range: %d-%d", stats.min_range_size, stats.max_range_size), 20, y, 20, rl.WHITE)
        rl.DrawText("Hold F1 for debug overlay", 10, 550, 16, rl.GRAY)
        rl.DrawText("F12: Capture debug image",  10, 570, 16, rl.GRAY)
    } else {
        rl.DrawText("F1: Debug overlay", 10, 570, 16, rl.DARKGRAY)
    }
}

clear_screen    :: proc() { fmt.print("\e[3J\e8") }
save_screen_pos :: proc() { fmt.print("\e7", flush = false) }