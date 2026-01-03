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


xyz_to_cell :: proc(x_coord: int, y_coord: int, z_coord: int) -> int {
	cell_scale := data.WORLD_SIZE / data.CELL_SIZE *2// meters per cell

	// Shift coords from [-150,150] to [0,300], then divide to get cell index [0,2]
	x := cell_scale + x_coord
	y := cell_scale + y_coord
	z := cell_scale + z_coord

	// Flatten to 1D: z*9 + y*3 + x
	ID := z * cell_scale * cell_scale + y * cell_scale + x

	return ID
}
cell_to_xyz :: proc(ID: int) -> (x: int, y: int, z: int) {
    cell_scale := data.WORLD_SIZE / data.CELL_SIZE * 2
    
    // Extract cell indices from flattened ID
    z = ID / (cell_scale * cell_scale)
    y = (ID % (cell_scale * cell_scale)) / cell_scale
    x = ID % cell_scale
    
    // Convert back to world coords by reversing the shift
    x = x - cell_scale
    y = y - cell_scale
    z = z - cell_scale
    
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
		(uv.x - 0.5) * scale + data.CAM_POS.x, // ← Use camera X
		(uv.y - 0.5) * scale + data.CAM_POS.y, // ← Use camera Y
		data.CAM_POS.z,
	}
}
