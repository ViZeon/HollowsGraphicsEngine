package testing

import math_lin "core:math/linalg"
import math "core:math/linalg/glsl"
import rl "vendor:raylib"
import stbi "vendor:stb/image"

import data "../data"
import model "../modules/model"

import "core:fmt"
import "core:os"


FOV_DISTANCE: f32 = 2.00 * f32(math_lin.tan(data.FOV / 2.0))
fov: f32

//called once before render loop
raylib_start_functions :: proc() {

	start_functions()
	// Create texture
	raylib_render_frame()
}

start_functions :: proc() {
	data.CAM_POS = {-581.8, -224.2, -0.7} // Set it here
	debug_init() // ← Initialize debug system

	model_load_realtime()
	sort_by_axis(&data.MODEL_DATA.VERTICES, &data.xs, &data.ys, &data.zs)

	fmt.println("Vertex count after loading:", len(data.VERTICIES_RAW))

	// Calculate FOV for each vertex
	for i in 0 ..< len(data.MODEL_DATA.VERTICES) {
		vert_pos := data.MODEL_DATA.VERTICES[i]
		dist := f32(math_lin.distance(math.vec3{0, 0, 0}, math.vec3(vert_pos.pos)))
		fov := 2.0 * math.atan_f32(dist / 2.0)
		data.MODEL_DATA.VERTICES[i].fov = fov
	}

	// Initialize pixel buffer
	frame_pixels = make([]u8, width * height * 3)

	//Populate Spatial Grid// Call it:
	grid_spatial_populate(&data.MODEL_DATA, &data.CELLS)

	//debug_spatial_map()


	// In raylib_start_functions():
	data.CAM_POS.x = (data.MODEL_DATA.BOUNDS.x.min + data.MODEL_DATA.BOUNDS.x.max) * 0.5
	data.CAM_POS.y = (data.MODEL_DATA.BOUNDS.y.min + data.MODEL_DATA.BOUNDS.y.max) * 0.5
	data.CAM_POS.z = data.MODEL_DATA.BOUNDS.z.max + 5.0 // 5 units in front of model


	// Generate initial frame
	generate_pixels_inplace(frame_pixels, width, height)

	// Write first frame
	frame_write_to_image()
}

//called once per frame
raylib_update_functions :: proc() {


	// Camera controls with timing
	start_input := rl.GetTime()
	handle_camera_input()
	debug_time_input(rl.GetTime() - start_input)

	// Pixel generation with timing
	start_pixels := rl.GetTime()
	update_fuctions()
	debug_time_pixels(rl.GetTime() - start_pixels)

	// Texture update with timing
	start_texture := rl.GetTime()
	rl.UpdateTexture(texture, raw_data(frame_pixels))
	debug_time_texture(rl.GetTime() - start_texture)

	// Draw
	if texture.id != 0 {
		rl.DrawTexture(texture, 0, 0, rl.WHITE)
	} else {
		fmt.println("Texture not loaded!")
	}

	// Debug overlay (optional, press F1)
	debug_draw_overlay()

	// Debug frame capture
	if rl.IsKeyPressed(.F12) {
		debug_write_image(frame_pixels, width, height)
	}


}
update_fuctions :: proc() {
	debug_frame_begin() // ← Reset per-frame counters
	generate_pixels_inplace(frame_pixels, width, height)
	debug_frame_end() // ← Print stats periodically
}

//called once per pixel
cpu_fragment_shader :: proc(pixel_coords: math.vec2) -> (PIXEL: math.ivec4) {
	PIXEL_FOV_COORDS := ortho_pixel_to_world(pixel_coords, width, height)
	default_pixel := math.ivec4{0, 0, 0, 255}
	//return default_pixel

	floor_x := int(math.floor(PIXEL_FOV_COORDS.x))
	floor_y := int(math.floor(PIXEL_FOV_COORDS.y))
	floor_z := int(math.floor(PIXEL_FOV_COORDS.z))

	vertex: data.Vertex

	cell_ID := xyz_to_cell(floor_x, floor_y, floor_z)

	if cell_ID < 0 || cell_ID >= len(data.CELLS) do return default_pixel

	if len(data.CELLS[cell_ID].keys) > 0 {
		vertex_idx := data.CELLS[cell_ID].keys[0]
		if vertex_idx < 0 do vertex_idx = -vertex_idx
		vertex = data.MODEL_DATA.VERTICES[vertex_idx]
	}

	//camera_dir := math.vec3{0, 0, -1}  // ← Fixed direction

	camera_dir := math.normalize(data.CAM_POS - vertex.pos)
	dot_product := math.dot(vertex.normal, camera_dir)
	grayscale := math.max(0, dot_product)

	return math.ivec4{i32(grayscale * 255), 0, 0, 255}

}
