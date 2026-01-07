package testing

import data "../data"
import math "core:math/linalg/glsl"
import rl "vendor:raylib"
import stbi "vendor:stb/image"

import "core:fmt"
import "core:os"

width, height := 320, 240

output_dir :: "image_debug_output/"
frame_pixels: []u8
image: rl.Image
texture: rl.Texture2D
pixel: math.ivec4


raylib_render_frame :: proc() {

	// Create image and texture
	image = rl.Image {
		data    = raw_data(frame_pixels),
		width   = i32(width),
		height  = i32(height),
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8,
	}

	texture = rl.LoadTextureFromImage(image)

}

// Generate pixel data
// Allocates new buffer (if needed)
generate_pixels :: proc(width, height: int) -> []u8 {
	pixels := make([]u8, width * height * 3)
	generate_pixels_inplace(pixels, width, height)
	return pixels
}

// Reuses existing buffer (use in update loop)
generate_pixels_inplace :: proc(pixels: []u8, width, height: int) {
	for y in 0 ..< height {
		for x in 0 ..< width {
			idx := (y * width + x) * 3
			pixel := cpu_fragment_shader(math.vec2{f32(x), f32(y)})

			pixels[idx + 0] = u8(pixel.x) // R
			pixels[idx + 1] = u8(pixel.y) // G
			pixels[idx + 2] = u8(pixel.z) // B
		}
	}
}

raylib_render :: proc() {
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

buffer_render :: proc() {
	start_functions()

	for !data.APP_CLOSED {
		update_fuctions()
	}
}
