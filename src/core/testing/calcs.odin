package testing

import math_lin "core:math/linalg"
import math "core:math/linalg/glsl"
import rl "vendor:raylib"
import stbi "vendor:stb/image"

import data "../data"
import model "../modules/model"

import "core:fmt"
import "core:os"


calc_FPS :: proc(frame_time: i64) -> int {
	fps := 1000000000 / frame_time
	return int(fps)
}


xyz_to_cell :: proc(x_coord: i32, y_coord: i32, z_coord: i32) -> i32 {
	cell_scale := data.WORLD_SIZE / data.CELL_SIZE * 2 // meters per cell

	// Shift coords from [-150,150] to [0,300], then divide to get cell index [0,2]
	x := cell_scale/2 + x_coord
	y := cell_scale/2 + y_coord
	z := cell_scale/2 + z_coord

	// Flatten to 1D: z*9 + y*3 + x
	ID := z * cell_scale * cell_scale + y * cell_scale + x

	return i32(ID)
}
cell_to_xyz :: proc(ID: i32) -> (x: i32, y: i32, z: i32) {
	cell_scale :  = i32(data.WORLD_SIZE / data.CELL_SIZE * 2)

	// Extract cell indices from flattened ID
	z = ID / (cell_scale * cell_scale)
	y = (ID % (cell_scale * cell_scale)) / cell_scale
	x = ID % cell_scale

	// Convert back to world coords by reversing the shift
	x = x - cell_scale/2
	y = y - cell_scale/2
	z = z - cell_scale/2

	return
}


trilinear_interp :: proc(
	c: [8]f32, // cube corner values
	fx, fy, fz: f32, // fractional coords in [0,1]
) -> f32 {
	// Interpolate along x
	c00 := c[0] * (1 - fx) + c[1] * fx
	c01 := c[2] * (1 - fx) + c[3] * fx
	c10 := c[4] * (1 - fx) + c[5] * fx
	c11 := c[6] * (1 - fx) + c[7] * fx

	// Interpolate along y
	c0 := c00 * (1 - fy) + c01 * fy
	c1 := c10 * (1 - fy) + c11 * fy

	// Interpolate along z
	return c0 * (1 - fz) + c1 * fz
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

ortho_pixel_to_world :: proc(pixel_coords: math.vec2, width, height: int) -> math.vec3 {
	// Convert pixel to [0,1] UV space
	uv := math.vec2{pixel_coords.x / f32(width), pixel_coords.y / f32(height)}
	
	// Map UV to world grid space [-WORLD_SIZE, WORLD_SIZE]
	world_x := (uv.x - 0.5) * f32(data.WORLD_SIZE * 2) + data.CAM_POS.x
	world_y := (uv.y - 0.5) * f32(data.WORLD_SIZE * 2) + data.CAM_POS.y
	
	return math.vec3 {
		world_x,
		world_y,
		data.CAM_POS.z,
	}
}

pixel_to_world_fov :: proc(pixel_coords: math.vec2, width, height: int) -> math.vec3 {
	// Convert pixel to [-1, 1] normalized device coordinates
	ndc_x := f64(pixel_coords.x / f32(width)) * 2.0 - 1.0
	ndc_y := f64(pixel_coords.y / f32(height)) * 2.0 - 1.0
	
	// Calculate view size based on FOV and distance
	fov_radians := data.FOV * math.PI / 180.0
	view_height := 2.0 * math.tan(fov_radians / 2.0) * f64(data.CAM_POS.z)
	view_width := view_height * (f64(width) / f64(height))
	
	return math.vec3 {
		data.CAM_POS.x + f32(ndc_x * view_width * 0.5),
		data.CAM_POS.y + f32(ndc_y * view_height * 0.5),
		data.CAM_POS.z,
	}
}
