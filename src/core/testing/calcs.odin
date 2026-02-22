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
	cell_scale := data.DEPRACATED_WORLD_SIZE / data.CELL_SIZE * 2 // meters per cell

	// Shift coords from [-150,150] to [0,300], then divide to get cell index [0,2]
	x := cell_scale / 2 + x_coord
	y := cell_scale / 2 + y_coord
	z := cell_scale / 2 + z_coord

	// Flatten to 1D: z*9 + y*3 + x
	ID := z * cell_scale * cell_scale + y * cell_scale + x

	return i32(ID)
}
cell_to_xyz :: proc(ID: i32) -> (x: i32, y: i32, z: i32) {
	cell_scale := i32(data.DEPRACATED_WORLD_SIZE / data.CELL_SIZE * 2)

	// Extract cell indices from flattened ID
	z = ID / (cell_scale * cell_scale)
	y = (ID % (cell_scale * cell_scale)) / cell_scale
	x = ID % cell_scale

	// Convert back to world coords by reversing the shift
	x = x - cell_scale / 2
	y = y - cell_scale / 2
	z = z - cell_scale / 2

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
	world_x := (uv.x - 0.5) * f32(data.DEPRACATED_WORLD_SIZE * 2) + data.CAM_POS.x
	world_y := (uv.y - 0.5) * f32(data.DEPRACATED_WORLD_SIZE * 2) + data.CAM_POS.y

	return math.vec3{world_x, world_y, data.CAM_POS.z}
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

level_count :: proc(mf: ^data.Mipmap_Bitfield) -> int {
	max_level := 0
	for total_cells(max_level + 1) <= i32(len(mf.bits)) * 32 {
		max_level += 1
	}
	max_level -= 1
	return max_level
}

// Calculate the starting offset for a given level
level_offset :: proc(level: i32) -> i32 {
	offset :i32= 0
	count :i32= 1
	for i in 0 ..< level {
		offset += count
		count *= 8 // Each cell subdivides into 8
	}
	return offset
}

// Calculate total number of cells across all levels
total_cells :: proc(num_levels: int) -> i32 {
	total :i32= 0
	count :i32= 1
	for i in 0 ..< num_levels {
		total += count
		count *= 8
	}
	return total
}

// For level with N cells, next level has N/8 cells
// Total cells = N + N/8 + N/64 + N/512 + ...
bitfield_create :: proc(num_levels: int) -> data.Mipmap_Bitfield {
	total := total_cells(num_levels + 1)
	num_u32s := (total + 31) / 32
	return data.Mipmap_Bitfield{bits = make([dynamic]u32, num_u32s)}
}

cell_get :: proc(mf: ^data.Mipmap_Bitfield, level: int, index: i32) -> bool {
	absolute_index := level_offset(i32(level)) + index
	slot := absolute_index / 32
	bit := u32(absolute_index % 32)
	return (mf.bits[slot] & (1 << bit)) != 0
}

cell_set :: proc(mf: ^data.Mipmap_Bitfield, level: int, index: i32, value: bool) {
	absolute_index :i32= level_offset(i32(level)) + index
	slot := absolute_index / 32
	bit := u32(absolute_index % 32)

	if value {
		mf.bits[slot] |= (1 << bit)
	} else {
		mf.bits[slot] &= ~(1 << bit)
	}
}


// Get parent in level above
parent_index :: proc(child_index: int) -> int {
	return child_index / 8
}

// Get children in level below
first_child_index :: proc(parent_index: int) -> int {
	return parent_index * 8
}


// Convert linear index to 3D coordinates at a given level
index_to_xyz :: proc(index: i32, level: int) -> (xyz: math.ivec3) {
	grid_size :i32= 1 << uint(level) // 2^level cells per axis

	// Decode index (row-major order)
	xyz.z = index / (grid_size * grid_size)
	xyz.y = (index / grid_size) % grid_size
	xyz.x = index % grid_size

	// Center coordinates (shift by half grid)
	half := grid_size / 2
	xyz.x -= half
	xyz.y -= half
	xyz.z -= half

	return
}

// Reverse: 3D coordinates to index
xyz_to_index :: proc(xyz: math.ivec3, level: int) -> i32 {
	grid_size :i32= 1 << uint(level)
	half := grid_size / 2

	// Uncenter
	x := xyz.x + half
	y := xyz.y + half
	z := xyz.z + half

	return z * grid_size * grid_size + y * grid_size + x
}

model_bitfield_set :: proc(
    mf: ^data.Mipmap_Bitfield,
    model: data.Model_Data,
) {

    lvl_count := level_count(mf)

    grid_size : i32 = 1 << uint(lvl_count)
    half      : i32 = grid_size / 2

    // Use model bounds to normalize into voxel space
    range_x := model.BOUNDS.x.max - model.BOUNDS.x.min
    range_y := model.BOUNDS.y.max - model.BOUNDS.y.min
    range_z := model.BOUNDS.z.max - model.BOUNDS.z.min

    if range_x == 0 || range_y == 0 || range_z == 0 {
        return
    }

    // --------------------------------------------
    // 1️⃣ Populate finest level from vertices
    // --------------------------------------------

    for i in 0 ..< len(model.VERTICES) {

        v := model.VERTICES[i]

        nx := (v.pos.x - model.BOUNDS.x.min) / range_x
        ny := (v.pos.y - model.BOUNDS.y.min) / range_y
        nz := (v.pos.z - model.BOUNDS.z.min) / range_z

        if nx < 0 || nx > 1 ||
           ny < 0 || ny > 1 ||
           nz < 0 || nz > 1 {
            continue
        }

        gx := i32(nx * f32(grid_size))
        gy := i32(ny * f32(grid_size))
        gz := i32(nz * f32(grid_size))

        if gx >= grid_size do gx = grid_size - 1
        if gy >= grid_size do gy = grid_size - 1
        if gz >= grid_size do gz = grid_size - 1

        gx -= half
        gy -= half
        gz -= half

        index := xyz_to_index(math.ivec3{gx, gy, gz}, lvl_count)

        if index < 0 {
            continue
        }

        cell_set(mf, lvl_count, index, true)
    }

    // --------------------------------------------
    // 2️⃣ Propagate occupancy upward
    // --------------------------------------------

    for level := lvl_count - 1; level >= 0; level -= 1 {

        parent_count : i32 = 1 << (3 * u32(level))

        for p in 0 ..< parent_count {

            first_child : i32 = p * 8

            occupied := false

            for c in 0 ..< 8 {
                if cell_get(mf, level + 1, first_child + i32(c)) {
                    occupied = true
                    break
                }
            }

            if occupied {
                cell_set(mf, level, p, true)
            }
        }
    }
}


model_bitfield_get :: proc(mf: ^data.Mipmap_Bitfield,model: data.Model_Data,) -> [dynamic]i32 {

    level_count := level_count(mf)

    min_x := i32(model.BOUNDS.x.min)
    max_x := i32(model.BOUNDS.x.max)

    min_y := i32(model.BOUNDS.y.min)
    max_y := i32(model.BOUNDS.y.max)

    min_z := i32(model.BOUNDS.z.min)
    max_z := i32(model.BOUNDS.z.max)

    index_occupied: [dynamic]i32

    for x in min_x ..< max_x {
        for y in min_y ..< max_y {
            for z in min_z ..< max_z {

                index := xyz_to_index(
                    math.ivec3{x, y, z},
                    level_count,
                )

                if index < 0 {
                    continue
                }

                if cell_get(mf, level_count, index) {
                    append(&index_occupied, index)
                }
            }
        }
    }
    fmt.println("Root occupied:", cell_get(&data.WORLD_BITFIELD, 0, 0))


    return index_occupied
}


