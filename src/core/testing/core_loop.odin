package testing

import math_lin "core:math/linalg"
import math "core:math/linalg/glsl"
import rl "vendor:raylib"
import stbi "vendor:stb/image"

import data "../_data"
import model "../modules/model"

import "core:fmt"
import "core:os"
import "core:strings"


FOV_DISTANCE: f32 = 2.00 * f32(math_lin.tan(data.FOV / 2.0))
fov: f32

//called once before render loop
raylib_start_functions :: proc() {

	start_functions()
	// Create texture
	raylib_render_frame()
}
start_functions :: proc() {
	data.LOG_BOARD = strings.builder_make(0, 0, context.temp_allocator)
	data.CAM_POS = {-581.8, -224.2, -0.7}
	debug_init()
	frame_pixels = make([]u8, data.SCREEN_WIDTH * data.SCREEN_HEIGHT * 3)

	/*
	model_load_realtime()
	sort_by_axis(&data.MODEL_DATA.VERTICES, &data.xs, &data.ys, &data.zs)
	fmt.println("RAW Vertex count after loading:", len(data.VERTICIES_RAW))
	fmt.println("Vertex count after loading:", len(data.MODEL_DATA.VERTICES))

	// Calculate FOV for each vertex
	for i in 0 ..< len(data.MODEL_DATA.VERTICES) {
		vert_pos := data.MODEL_DATA.VERTICES[i]
		dist := f32(math_lin.distance(math.vec3{0, 0, 0}, math.vec3(vert_pos.pos)))
		fov := 2.0 * math.atan_f32(dist / 2.0)
		data.MODEL_DATA.VERTICES[i].fov = fov
	}

	// Initialize pixel buffer
	frame_pixels = make([]u8, data.SCREEN_WIDTH * data.SCREEN_HEIGHT * 3)

	// Populate Spatial Grid
	grid_spatial_populate(&data.MODEL_DATA, &data.CELLS)
	debug_grid_population()

	// Camera centered on model
	data.CAM_POS.x = (data.MODEL_DATA.BOUNDS.x.min + data.MODEL_DATA.BOUNDS.x.max) * 0.5
	data.CAM_POS.y = (data.MODEL_DATA.BOUNDS.y.min + data.MODEL_DATA.BOUNDS.y.max) * 0.5
	data.CAM_POS.z = data.MODEL_DATA.BOUNDS.z.max + 5.0

	// Debug cell round-trip
	a_ID: i32 = 43957
	x_ID, y_ID, z_ID := cell_to_xyz(a_ID)
	xyz_ID := xyz_to_cell(x_ID, y_ID, z_ID)
	fmt.println(a_ID)
	fmt.println(x_ID, y_ID, z_ID)
	fmt.println(xyz_ID)

	// First 5 verts
	fmt.println("First 5 vertex positions:")
	for i in 0 ..< min(5, len(data.MODEL_DATA.VERTICES)) {
		fmt.printf(
			"  Vert %d: [%.1f, %.1f, %.1f]\n",
			i,
			data.MODEL_DATA.VERTICES[i].pos.x,
			data.MODEL_DATA.VERTICES[i].pos.y,
			data.MODEL_DATA.VERTICES[i].pos.z,
		)
	}

	// Build bitfield BEFORE generating pixels
	data.WORLD_BITFIELD = bitfield_create(4)
	fmt.println(len(data.WORLD_BITFIELD.bits))
	fmt.println(data.MODEL_DATA.BOUNDS)
	fmt.println(cell_get(&data.WORLD_BITFIELD, 4, 67))
	fmt.println(cell_get(&data.WORLD_BITFIELD, 4, 66))

	model_bitfield_set(&data.WORLD_BITFIELD, data.MODEL_DATA)
	model_bitfield := model_bitfield_get(&data.WORLD_BITFIELD, data.MODEL_DATA)


	//data.MODEL_CENTER = (data.MODEL_DATA.BOUNDS.min + data.MODEL_DATA.BOUNDS.max) * 0.5
	//data.MODEL_HALF_EXTENTS = (data.MODEL_DATA.BOUNDS.max - data.MODEL_DATA.BOUNDS.min) * 0.5

	fmt.println(model_bitfield)
*/


	// Load model
	dps, bounds, center, ok := load_model(data.MODEL_PATH)
	if !ok do return
	data.datapoints = dps

	// Camera centered on model
	data.CAM_POS.x = center.x
	data.CAM_POS.y = center.y
	data.CAM_POS.z = bounds.z.max + 5.0

	// Build field
	field := field_create(bounds, 4)
	field_populate(&field, data.datapoints[:])
	append(&data.fields, field)

	fmt.println("Field built, cells:", len(data.fields[0].bits))

	// Generate initial frame
	generate_pixels_inplace(frame_pixels, data.SCREEN_WIDTH, data.SCREEN_HEIGHT)
	frame_write_to_image()
}
/*
render_prepass :: proc(model: data.Model_Data) {
}
*/

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
		debug_write_image(frame_pixels, data.SCREEN_WIDTH, data.SCREEN_HEIGHT)
	}


}
update_fuctions :: proc() {
	debug_frame_begin() // ← Reset per-frame counters
	generate_pixels_inplace(frame_pixels, data.SCREEN_WIDTH, data.SCREEN_HEIGHT)
	debug_frame_end() // ← Print stats periodically
	strings.builder_reset(&data.LOG_BOARD)
}

//called once per pixel
cpu_fragment_shader :: proc(pixel_coords: math.vec2) -> (PIXEL: math.ivec4) {
    world := pixel_to_world_fov(pixel_coords, data.SCREEN_WIDTH, data.SCREEN_HEIGHT)

    if len(data.fields) > 0 && field_query(&data.fields[0], world.x, world.y) {
        return math.ivec4{255, 0, 0, 255}
    }
    return math.ivec4{0, 0, 0, 255}

	/*
	world := pixel_to_world_fov(pixel_coords, data.SCREEN_WIDTH, data.SCREEN_HEIGHT)

	// Fast reject: does this pixel's ray even hit the model bounds?
	ray_dir := math.vec3{0, 0, -1} // orthographic for now, replace with proper ray later
	hit, _ := ray_aabb_hit(data.CAM_POS, ray_dir, data.MODEL_DATA.BOUNDS)
	if !hit do return math.ivec4{0, 0, 0, 255}

	// Traverse octree for this X,Y column
	if octree_query(world.x, world.y, &data.WORLD_BITFIELD, data.MODEL_DATA.BOUNDS, 4) {
		return math.ivec4{255, 0, 0, 255}
	}
	return math.ivec4{0, 0, 0, 255}


	
    ray_dir := pixel_to_ray(pixel_coords, width, height)
	if ray_march(data.CAM_POS, ray_dir, &data.WORLD_BITFIELD, 4, 200, 0.1) {
		return math.ivec4{255, 0, 0, 255}
	}
	return math.ivec4{0, 0, 0, 255}

	world := pixel_to_world_fov(pixel_coords, data.SCREEN_WIDTH, data.SCREEN_HEIGHT)

	if octree_query(world.x, world.y, &data.WORLD_BITFIELD, 4) {
		return math.ivec4{255, 0, 0, 255}
	}
	return math.ivec4{0, 0, 0, 255}
*/

	/*
	floor_x := i32(math.floor(PIXEL_FOV_COORDS.x))
	floor_y := i32(math.floor(PIXEL_FOV_COORDS.y))
	floor_z := i32(math.floor(PIXEL_FOV_COORDS.z))

	vertex: data.Vertex

	cell_ID := xyz_to_cell(floor_x, floor_y, floor_z)

	if cell_ID < 0 || cell_ID >= i32(len(data.CELLS)) do return default_pixel

	if len(data.CELLS[cell_ID].keys) > 0 {

		ID_curr := data.CELLS[cell_ID].keys[0]
		//fmt.println(ID_curr)
		ID_closest := 0

		if ID_curr < 0 {
			cell_ID = -ID_curr
			ID_curr = data.CELLS[cell_ID].keys[0]
		}

		dist := math.distance_vec3(PIXEL_FOV_COORDS, data.MODEL_DATA.VERTICES[ID_curr].pos)

		for i in 0 ..< len(data.CELLS[cell_ID].keys) {
			ID_curr = data.CELLS[cell_ID].keys[i]
			if math.distance_vec3(PIXEL_FOV_COORDS, data.MODEL_DATA.VERTICES[ID_curr].pos) < dist {
				dist = math.distance_vec3(PIXEL_FOV_COORDS, data.MODEL_DATA.VERTICES[ID_curr].pos)
				ID_closest = i
			}
		}

		vertex_idx := data.CELLS[cell_ID].keys[ID_closest]
		//if vertex_idx < 0 do vertex_idx = -vertex_idx
		vertex = data.MODEL_DATA.VERTICES[vertex_idx]

		fmt.sbprintf(&data.LOG_BOARD, "%+v\n", data.MODEL_DATA.VERTICES[vertex_idx])
		fmt.sbprintf(&data.LOG_BOARD, "%+v\n", PIXEL_FOV_COORDS)

	}


	//camera_dir := math.vec3{0, 0, -1}  // ← Fixed direction

	camera_dir := math.normalize(data.CAM_POS - vertex.pos)
	dot_product := math.dot(vertex.normal, camera_dir)
	grayscale := math.max(0, dot_product)

	//debug_pixel_lookup(pixel_coords, PIXEL_FOV_COORDS, int(cell_ID))

	return math.ivec4{i32(grayscale * 255), 0, 0, 255}
*/
}
