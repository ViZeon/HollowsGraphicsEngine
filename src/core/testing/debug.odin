package testing

import data "../data"

import "core:time"
import "core:fmt"
import math "core:math/linalg/glsl"
import rl "vendor:raylib"

// Debug state
Debug_Stats :: struct {
	// Performance timing
	input_time:             f64,
	pixel_time:             f64,
	texture_time:           f64,
	last_print_time:        f64,

	// Pixel shader stats
	total_pixels_processed: int,
	total_vertices_checked: int,
	max_range_size:         i32,
	min_range_size:         i32,

	// Per-frame counters (reset each frame)
	frame_vertices_checked: int,
	frame_pixels_processed: int,

	// Camera info
	last_cam_pos:           math.vec3,
}

debug_stats: Debug_Stats

// Initialize debug system
debug_init :: proc() {
	debug_stats = Debug_Stats{}
	debug_stats.min_range_size = max(i32)
	debug_stats.last_print_time = rl.GetTime()
	debug_stats.last_cam_pos = data.CAM_POS
}

// Reset per-frame counters
debug_frame_begin :: proc() {
	debug_stats.frame_vertices_checked = 0
	debug_stats.frame_pixels_processed = 0
}

// Print frame statistics
debug_frame_end :: proc() {
	data.FRAME_TIME = time.now()._nsec - data.APP_TIME
	data.FPS = calc_FPS(data.FRAME_TIME)
	data.APP_TIME = time.now()._nsec 
	current_time := data.APP_TIME / 1000000000

	// Print timing every 2 seconds
	if f64(current_time) - debug_stats.last_print_time > data.DEBUG_TIME {
		avg_vertices_per_pixel :=
			f32(debug_stats.total_vertices_checked) / f32(debug_stats.total_pixels_processed)
		frame_avg :=
			f32(debug_stats.frame_vertices_checked) / f32(debug_stats.frame_pixels_processed)

		fmt.printf("=== PERFORMANCE ===\n")
		fmt.printf(
			"Input: %.3fms | Pixels: %.1fms | Texture: %.3fms | FPS: %d\n",
			debug_stats.input_time * 1000,
			debug_stats.pixel_time * 1000,
			debug_stats.texture_time * 1000,
// Here v
			data.FPS,
		)

		fmt.printf("=== VERTEX CHECKS ===\n")
		fmt.printf(
			"This frame avg: %.1f verts/pixel | Overall avg: %.1f verts/pixel\n",
			frame_avg,
			avg_vertices_per_pixel,
		)
		fmt.printf(
			"Range sizes - Min: %d | Max: %d\n",
			debug_stats.min_range_size,
			debug_stats.max_range_size,
		)

		fmt.printf("=== CAMERA ===\n")
		fmt.printf("Pos: [%.1f, %.1f, %.1f]\n", data.CAM_POS.x, data.CAM_POS.y, data.CAM_POS.z)

		if data.CAM_POS != debug_stats.last_cam_pos {
			fmt.printf(
				"Camera moved: delta [%.1f, %.1f, %.1f]\n",
				data.CAM_POS.x - debug_stats.last_cam_pos.x,
				data.CAM_POS.y - debug_stats.last_cam_pos.y,
				data.CAM_POS.z - debug_stats.last_cam_pos.z,
			)
		}

		fmt.println("Bounds X:", data.MODEL_DATA.BOUNDS.x)
		fmt.println("Bounds Y:", data.MODEL_DATA.BOUNDS.y)
		fmt.println("Bounds Z:", data.MODEL_DATA.BOUNDS.z)
		fmt.println()

		fmt.println(data.FRAME_TIME, data.APP_TIME)

		debug_stats.last_print_time = f64(current_time)
		debug_stats.last_cam_pos = data.CAM_POS
	}
}

// Record timing for input
debug_time_input :: proc(time: f64) {
	debug_stats.input_time = time
}

// Record timing for pixel generation
debug_time_pixels :: proc(time: f64) {
	debug_stats.pixel_time = time
}

// Record timing for texture update
debug_time_texture :: proc(time: f64) {
	debug_stats.texture_time = time
}

// Record vertex search stats (call from fragment shader)
debug_record_pixel_search :: proc(range_size: i32) {
	debug_stats.total_pixels_processed += 1
	debug_stats.frame_pixels_processed += 1

	debug_stats.total_vertices_checked += int(range_size)
	debug_stats.frame_vertices_checked += int(range_size)

	if range_size > debug_stats.max_range_size {
		debug_stats.max_range_size = range_size
	}

	if range_size < debug_stats.min_range_size && range_size > 0 {
		debug_stats.min_range_size = range_size
	}
}

// Write debug image with info overlay
debug_write_image :: proc(frame_pixels: []u8, width, height: int) {
	frame_write_to_image()

	fmt.println("=== DEBUG FRAME CAPTURED ===")
	fmt.printf("Camera: [%.1f, %.1f, %.1f]\n", data.CAM_POS.x, data.CAM_POS.y, data.CAM_POS.z)
	fmt.printf("FPS: %d\n", rl.GetFPS())
	fmt.printf(
		"Avg verts checked: %.1f\n",
		f32(debug_stats.frame_vertices_checked) / f32(debug_stats.frame_pixels_processed),
	)
	fmt.printf("Range: %d - %d vertices\n", debug_stats.min_range_size, debug_stats.max_range_size)
	fmt.println("===========================\n")
}

// Print model loading stats
debug_model_loaded :: proc(vertex_count: int, bounds: data.Bounds) {
	fmt.println("=== MODEL LOADED ===")
	fmt.printf("Vertices: %d\n", vertex_count)
	fmt.printf("Bounds X: [%d, %d]\n", bounds.x.min, bounds.x.max)
	fmt.printf("Bounds Y: [%d, %d]\n", bounds.y.min, bounds.y.max)
	fmt.printf("Bounds Z: [%d, %d]\n", bounds.z.min, bounds.z.max)
	fmt.println("===================\n")
}

// Optional: Draw on-screen debug overlay
debug_draw_overlay :: proc() {
	if rl.IsKeyDown(.F1) {
		rl.DrawRectangle(10, 10, 300, 120, rl.ColorAlpha(rl.BLACK, 0.7))

		y := i32(20)
		rl.DrawText(fmt.ctprintf("FPS: %d", rl.GetFPS()), 20, y, 20, rl.GREEN)
		y += 25

		rl.DrawText(
			fmt.ctprintf(
				"Cam: [%.0f, %.0f, %.0f]",
				data.CAM_POS.x,
				data.CAM_POS.y,
				data.CAM_POS.z,
			),
			20,
			y,
			20,
			rl.WHITE,
		)
		y += 25

		avg := f32(debug_stats.frame_vertices_checked) / f32(debug_stats.frame_pixels_processed)
		rl.DrawText(fmt.ctprintf("Verts/Pixel: %.1f", avg), 20, y, 20, rl.YELLOW)
		y += 25

		rl.DrawText(
			fmt.ctprintf("Range: %d-%d", debug_stats.min_range_size, debug_stats.max_range_size),
			20,
			y,
			20,
			rl.WHITE,
		)

		// Help text
		rl.DrawText("Hold F1 for debug overlay", 10, 550, 16, rl.GRAY)
		rl.DrawText("F12: Capture debug image", 10, 570, 16, rl.GRAY)
	} else {
		rl.DrawText("F1: Debug overlay", 10, 570, 16, rl.DARKGRAY)
	}
}

debug_spatial_map :: proc() {
	for i in 0..< 10 {
			fmt.println(data.cells[i])
		}
}

// Run at the begin of every frame
clear_screen :: proc() {
    // Clear from saved pos to current, then Restore cursor pos
    fmt.print("\e[3J\e8")
}

// Run before at least once before `clear_screen`. 
// Anything after this point will be reset every frame.
save_screen_pos :: proc() {
    fmt.print("\e7", flush = false) // Save cursor pos
}