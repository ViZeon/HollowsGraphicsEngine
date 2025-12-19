package testing

import math_lin "core:math/linalg"
import math "core:math/linalg/glsl"
import rl "vendor:raylib"
import stbi "vendor:stb/image"

import data "../data"
import model "../modules/model"

import "core:fmt"
import "core:os"


SORTED_VERTS: []data.Vertex
closest_vert: data.Vertex

FOV_DISTANCE: f32 = 2.00 * f32(math_lin.tan(data.FOV / 2.0))
fov: f32

//called once before render loop
raylib_start_functions :: proc() {
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
	grid_spatial_populate(&data.MODEL_DATA, &data.cells)

	debug_spatial_map()


// In raylib_start_functions():
data.CAM_POS.x = (data.MODEL_DATA.BOUNDS.x.min + data.MODEL_DATA.BOUNDS.x.max) * 0.5
data.CAM_POS.y = (data.MODEL_DATA.BOUNDS.y.min + data.MODEL_DATA.BOUNDS.y.max) * 0.5
data.CAM_POS.z = data.MODEL_DATA.BOUNDS.z.max + 5.0  // 5 units in front of model


	// Generate initial frame
	generate_pixels_inplace(frame_pixels, width, height)

	// Write first frame
	frame_write_to_image()

	// Create texture
	raylib_render_frame()
}

//called once per frame
raylib_update_functions :: proc() {
	debug_frame_begin() // ← Reset per-frame counters

	// Camera controls with timing
	start_input := rl.GetTime()
	handle_camera_input()
	debug_time_input(rl.GetTime() - start_input)

	// Pixel generation with timing
	start_pixels := rl.GetTime()
	generate_pixels_inplace(frame_pixels, width, height)
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

	debug_frame_end() // ← Print stats periodically
}

//called once per pixel
cpu_fragment_shader :: proc(pixel_coords: math.vec2) -> (PIXEL: math.ivec4) {

	uv := math.vec3{pixel_coords.x / f32(width), pixel_coords.y / f32(height), 0}

	PIXEL_SHIFT := data.CULLING_RANGE * FOV_DISTANCE
	PIXEL_FOV_COORDS := math.vec3 {
		uv.x * PIXEL_SHIFT + data.CAM_POS.x,
		uv.y * PIXEL_SHIFT + data.CAM_POS.y,
		0.0 + data.CAM_POS.z,
	}

PIXEL_FOV_COORDS = ortho_pixel_to_world(pixel_coords, width, height)
    
    // Fixed: subtract minimum bounds to get positive grid indices
    floor_x := int(math.floor(PIXEL_FOV_COORDS.x - data.MODEL_DATA.BOUNDS.x.min))
    floor_y := int(math.floor(PIXEL_FOV_COORDS.y - data.MODEL_DATA.BOUNDS.y.min))
    floor_z := int(math.floor(PIXEL_FOV_COORDS.z - data.MODEL_DATA.BOUNDS.z.min))
    
    vertex: data.Vertex
    
    if check_bounds(floor_x, floor_y, floor_z, data.MODEL_DATA.BOUNDS) {
        if len(data.cells) > 0 && 
           floor_x < len(data.cells) &&
           floor_y < len(data.cells[floor_x]) &&
           floor_z < len(data.cells[floor_x][floor_y]) &&
           len(data.cells[floor_x][floor_y][floor_z].keys) != 0 {
            vertex = data.MODEL_DATA.VERTICES[data.cells[floor_x][floor_y][floor_z].keys[0]]
        }
    }

	// Camera facing direction (down -Z axis)
	camera_dir := math.vec3{0, 0, -1}
	dot_product := math.dot(vertex.normal, camera_dir)
	grayscale := math.max(0, dot_product)

	return math.ivec4{i32(grayscale * 255), 0, 0, 255}

}

handle_camera_input :: proc() {
	dt := rl.GetFrameTime()
	move_speed := data.CAM_SPEED * dt * 60.0

	// Faster movement with shift
	if rl.IsKeyDown(.LEFT_SHIFT) {
		move_speed *= 3.0
	}

	// WASD movement
	if rl.IsKeyDown(.W) do data.CAM_POS.y += move_speed
	if rl.IsKeyDown(.S) do data.CAM_POS.y -= move_speed
	if rl.IsKeyDown(.A) do data.CAM_POS.x -= move_speed
	if rl.IsKeyDown(.D) do data.CAM_POS.x += move_speed

	// Q/E for Z axis
	if rl.IsKeyDown(.Q) do data.CAM_POS.z -= move_speed
	if rl.IsKeyDown(.E) do data.CAM_POS.z += move_speed
}

model_load_realtime :: proc() {
	data.VERTICIES_RAW, data.MODEL_INITIALIZED = model.load_model(data.MODEL_PATH)
	data.MODEL_DATA = process_vertices(&data.VERTICIES_RAW, data.SCALE_FACTOR)

	fmt.println("model initialized")
	data.MODEL_INITIALIZED = true
}

ortho_pixel_to_world :: proc(pixel_coords: math.vec2, width, height: int) -> math.vec3 {
    bounds := data.MODEL_DATA.BOUNDS

    // Model dimensions
    model_width := f32(bounds.x.max - bounds.x.min)
    model_height := f32(bounds.y.max - bounds.y.min)

    // Aspect ratios
    screen_aspect := f32(width) / f32(height)
    model_aspect := model_width / model_height

    // Fit model to screen
    scale: f32
    if model_aspect > screen_aspect {
        scale = model_width
    } else {
        scale = model_height
    }

    // UV to world coordinates
    uv := math.vec2{pixel_coords.x / f32(width), pixel_coords.y / f32(height)}

    // ADD camera offset to world position
    return math.vec3 {
        (uv.x - 0.5) * scale + data.CAM_POS.x,  // ← Use camera X
        (uv.y - 0.5) * scale + data.CAM_POS.y,  // ← Use camera Y
        data.CAM_POS.z,
    }
}