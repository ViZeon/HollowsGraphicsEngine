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
	offset: i32 = 0
	count: i32 = 1
	for i in 0 ..< level {
		offset += count
		count *= 8 // Each cell subdivides into 8
	}
	return offset
}

// Calculate total number of cells across all levels
total_cells :: proc(num_levels: int) -> i32 {
	total: i32 = 0
	count: i32 = 1
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
    if slot < 0 || int(slot) >= len(mf.bits) do return false
    bit := u32(absolute_index % 32)
    return (mf.bits[slot] & (1 << bit)) != 0
}

cell_set :: proc(mf: ^data.Mipmap_Bitfield, level: int, index: i32, value: bool) {
	absolute_index: i32 = level_offset(i32(level)) + index
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
	grid_size: i32 = 1 << uint(level) // 2^level cells per axis

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
	grid_size: i32 = 1 << uint(level)
	half := grid_size / 2

	// Uncenter
	x := xyz.x + half
	y := xyz.y + half
	z := xyz.z + half

	return z * grid_size * grid_size + y * grid_size + x
}


model_bitfield_set :: proc(mf: ^data.Mipmap_Bitfield, model: data.Model_Data) {
	lvl_count := level_count(mf)
	grid_size := i32(1) << uint(lvl_count)
	half := grid_size / 2

	// Mark only cells that contain actual vertices
	for v in model.VERTICES {
		x := i32(math.floor_f32(v.pos.x))
		y := i32(math.floor_f32(v.pos.y))
		z := i32(math.floor_f32(v.pos.z))

		if x < -half || x >= half || y < -half || y >= half || z < -half || z >= half {
			continue
		}

		index := xyz_to_index(math.ivec3{x, y, z}, lvl_count)
		cell_set(mf, lvl_count, index, true)
	}

	// Propagate fine -> coarse (unchanged)
	for level := lvl_count - 1; level >= 0; level -= 1 {
		parent_count: i32 = 1 << (3 * u32(level))
		for p in 0 ..< parent_count {
			first_child: i32 = i32(p) * 8
			occupied := false
			for c in 0 ..< 8 {
				if cell_get(mf, level + 1, first_child + i32(c)) {
					occupied = true
					break
				}
			}
			if occupied do cell_set(mf, level, i32(p), true)
		}
	}
}

model_bitfield_get :: proc(mf: ^data.Mipmap_Bitfield, model: data.Model_Data) -> [dynamic]i32 {

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

				index := xyz_to_index(math.ivec3{x, y, z}, level_count)

				total := i32(len(mf.bits)) * 32
				if index < 0 || index >= total {
					continue
				}

				if cell_get(mf, level_count, index) {
					append(&index_occupied, index)
				}
			}
		}
	}

	return index_occupied
}

/*


pixel_to_ray :: proc(pixel_coords: math.vec2, width, height: int) -> math.vec3 {
    ndc_x := (pixel_coords.x / f32(width)) * 2.0 - 1.0
    ndc_y := (pixel_coords.y / f32(height)) * 2.0 - 1.0

    aspect      := f32(width) / f32(height)
    tan_half_fov := math.tan_f32(f32(data.FOV) * math.PI / 180.0 * 0.5)

    return math.normalize(math.vec3{
        ndc_x * aspect * tan_half_fov,
        -ndc_y * tan_half_fov, // flip Y: screen down = world up
        -1.0,                  // looking in -Z
    })
}

ray_march :: proc(
    origin:    math.vec3,
    direction: math.vec3,
    mf:        ^data.Mipmap_Bitfield,
    level:     int,
    max_steps: int,
    step_size: f32,
) -> bool {
    grid_size := i32(1) << uint(level)
    total     := grid_size * grid_size * grid_size

    pos := origin
    for _ in 0 ..< max_steps {
        idx := xyz_to_index(math.ivec3{i32(pos.x), i32(pos.y), i32(pos.z)}, level)
        if idx >= 0 && idx < total {
            if cell_get(mf, level, idx) {
                return true
            }
        }
        pos += direction * step_size
    }
    return false
}

// OLD - ray march approach, replaced by octree_query
// pixel_to_ray :: proc ...
// ray_march :: proc ...


octree_query :: proc(
    world_x:   f32,
    world_y:   f32,
    mf:        ^data.Mipmap_Bitfield,
    max_level: int,
) -> bool {
    // Coarse levels: early exit if column is entirely empty
    for level in 0..<max_level {
        grid_size := i32(1) << uint(level)
        half      := grid_size / 2

        x_idx := i32(math.floor_f32(world_x)) + half
        y_idx := i32(math.floor_f32(world_y)) + half

        if x_idx < 0 || x_idx >= grid_size ||
           y_idx < 0 || y_idx >= grid_size {
            return false
        }

        any_occupied := false
        for z_idx in 0..<grid_size {
            idx := xyz_to_index(
                math.ivec3{x_idx - half, y_idx - half, z_idx - half},
                level,
            )
            if cell_get(mf, level, idx) {
                any_occupied = true
                break
            }
        }
        if !any_occupied do return false
    }

    // Finest level: frontmost Z
    grid_size := i32(1) << uint(max_level)
    half      := grid_size / 2

    x_idx := i32(math.floor_f32(world_x)) + half
    y_idx := i32(math.floor_f32(world_y)) + half

    if x_idx < 0 || x_idx >= grid_size ||
       y_idx < 0 || y_idx >= grid_size {
        return false
    }

    for z_idx := grid_size - 1; z_idx >= 0; z_idx -= 1 {
        idx := xyz_to_index(
            math.ivec3{x_idx - half, y_idx - half, z_idx - half},
            max_level,
        )
        if cell_get(mf, max_level, idx) do return true
    }
    return false
}

// Returns true if the ray hits the AABB, and sets t_min, t_max.
ray_aabb_intersect :: proc(
    origin, dir: math.vec3,
    aabb_min, aabb_max: math.vec3,
) -> (hit: bool, t_min: f32, t_max: f32) {
    t1 := (aabb_min.x - origin.x) / dir.x
    t2 := (aabb_max.x - origin.x) / dir.x
    t_min = min(t1, t2)
    t_max = max(t1, t2)

    t1 = (aabb_min.y - origin.y) / dir.y
    t2 = (aabb_max.y - origin.y) / dir.y
    t_min = max(t_min, min(t1, t2))
    t_max = min(t_max, max(t1, t2))

    t1 = (aabb_min.z - origin.z) / dir.z
    t2 = (aabb_max.z - origin.z) / dir.z
    t_min = max(t_min, min(t1, t2))
    t_max = min(t_max, max(t1, t2))

    hit = t_max >= max(t_min, 0.0)
    return
}

node_aabb :: proc(level: int, index: i32) -> (min, max: math.vec3) {
    xyz := index_to_xyz(index, level)
    min = math.vec3{ f32(xyz.x), f32(xyz.y), f32(xyz.z) }
    max = min + 1.0
    return
}

// OLD - replaced by ray_aabb_hit + octree_query
// pixel_to_ray :: proc ...
// ray_march :: proc ...
// octree_query (previous version) :: proc ...

ray_aabb_hit :: proc(origin, dir: math.vec3, bounds: data.Bounds) -> (hit: bool, t: f32) {
    t_min: f32 = -1e9
    t_max: f32 =  1e9

    // X slab
    if dir.x != 0 {
        tx1 := (bounds.x.min - origin.x) / dir.x
        tx2 := (bounds.x.max - origin.x) / dir.x
        t_min = math.max_f32(t_min, math.min_f32(tx1, tx2))
        t_max = math.min_f32(t_max, math.max_f32(tx1, tx2))
    } else if origin.x < bounds.x.min || origin.x > bounds.x.max {
        return false, 0
    }

    // Y slab
    if dir.y != 0 {
        ty1 := (bounds.y.min - origin.y) / dir.y
        ty2 := (bounds.y.max - origin.y) / dir.y
        t_min = math.max_f32(t_min, math.min_f32(ty1, ty2))
        t_max = math.min_f32(t_max, math.max_f32(ty1, ty2))
    } else if origin.y < bounds.y.min || origin.y > bounds.y.max {
        return false, 0
    }

    // Z slab
    if dir.z != 0 {
        tz1 := (bounds.z.min - origin.z) / dir.z
        tz2 := (bounds.z.max - origin.z) / dir.z
        t_min = math.max_f32(t_min, math.min_f32(tz1, tz2))
        t_max = math.min_f32(t_max, math.max_f32(tz1, tz2))
    } else if origin.z < bounds.z.min || origin.z > bounds.z.max {
        return false, 0
    }

    return t_max >= t_min && t_max >= 0, math.max_f32(t_min, 0)
}

// Top-down octree traversal — no stepping
// At coarse levels: early exit if X,Y column is entirely empty
// At finest level: scan Z front to back, return first hit
octree_query :: proc(
    world_x, world_y: f32,
    mf:               ^data.Mipmap_Bitfield,
    max_level:        int,
) -> bool {
    // Center coords relative to model
    cx := i32(math.floor_f32(world_x - data.MODEL_CENTER.x))
    cy := i32(math.floor_f32(world_y - data.MODEL_CENTER.y))

    for level in 0..=max_level {
        grid_size := i32(1) << uint(level)
        half      := grid_size / 2
        scale     := i32(1) << uint(max_level - level) // world units per cell at this level

        lx := cx / scale
        ly := cy / scale

        if lx < -half || lx >= half ||
           ly < -half || ly >= half {
            return false
        }

        // Scan Z front to back (camera at +Z looking in -Z, so high Z = front)
        any_occupied := false
        for lz := half - 1; lz >= -half; lz -= 1 {
            idx := xyz_to_index(math.ivec3{lx, ly, lz}, level)
            if cell_get(mf, level, idx) {
                any_occupied = true
                if level == max_level do return true // frontmost hit
                break // coarse level: column has something, go finer
            }
        }
        if !any_occupied do return false
    }
    return false
}
*/


// OLD - replaced by ray_aabb_hit + octree_query
// pixel_to_ray :: proc ...
// ray_march :: proc ...
// octree_query (previous version) :: proc ...

ray_aabb_hit :: proc(origin, dir: math.vec3, bounds: data.Bounds) -> (hit: bool, t: f32) {
	t_min: f32 = -1e9
	t_max: f32 = 1e9

	// X slab
	if dir.x != 0 {
		tx1 := (bounds.x.min - origin.x) / dir.x
		tx2 := (bounds.x.max - origin.x) / dir.x
		t_min = math.max_f32(t_min, math.min_f32(tx1, tx2))
		t_max = math.min_f32(t_max, math.max_f32(tx1, tx2))
	} else if origin.x < bounds.x.min || origin.x > bounds.x.max {
		return false, 0
	}

	// Y slab
	if dir.y != 0 {
		ty1 := (bounds.y.min - origin.y) / dir.y
		ty2 := (bounds.y.max - origin.y) / dir.y
		t_min = math.max_f32(t_min, math.min_f32(ty1, ty2))
		t_max = math.min_f32(t_max, math.max_f32(ty1, ty2))
	} else if origin.y < bounds.y.min || origin.y > bounds.y.max {
		return false, 0
	}

	// Z slab
	if dir.z != 0 {
		tz1 := (bounds.z.min - origin.z) / dir.z
		tz2 := (bounds.z.max - origin.z) / dir.z
		t_min = math.max_f32(t_min, math.min_f32(tz1, tz2))
		t_max = math.min_f32(t_max, math.max_f32(tz1, tz2))
	} else if origin.z < bounds.z.min || origin.z > bounds.z.max {
		return false, 0
	}

	return t_max >= t_min && t_max >= 0, math.max_f32(t_min, 0)
}

// Top-down octree traversal — no stepping
// At coarse levels: early exit if X,Y column is entirely empty
// At finest level: scan Z front to back, return first hit
octree_query :: proc(
    world_x, world_y: f32,
    mf:               ^data.Mipmap_Bitfield,
    bounds:           data.Bounds,
    max_level:        int,
) -> bool {
    // Normalize world pos into [0,1] model space
    nx := (world_x - bounds.x.min) / (bounds.x.max - bounds.x.min)
    ny := (world_y - bounds.y.min) / (bounds.y.max - bounds.y.min)

    for level in 0..=max_level {
        grid_size := i32(1) << uint(level)
        half      := grid_size / 2

        lx := i32(math.floor_f32(nx * f32(grid_size))) - half
        ly := i32(math.floor_f32(ny * f32(grid_size))) - half

        if lx + half < 0 || lx + half >= grid_size ||
           ly + half < 0 || ly + half >= grid_size {
            return false
        }

        any_occupied := false
        for lz_u := grid_size - 1; lz_u >= 0; lz_u -= 1 {
            lz := lz_u - half
            idx := xyz_to_index(math.ivec3{lx, ly, lz}, level)
            if cell_get(mf, level, idx) {
                any_occupied = true
                if level == max_level do return true
                break
            }
        }
        if !any_occupied do return false
    }
    return false
}


cell_get_field :: proc(field: ^data.Field, level: int, index: i32) -> bool {
    absolute_index := level_offset(i32(level)) + index
    slot := absolute_index / 32
    if slot < 0 || int(slot) >= len(field.bits) do return false
    bit := u32(absolute_index % 32)
    return (field.bits[slot] & (1 << bit)) != 0
}

cell_set_field :: proc(field: ^data.Field, level: int, index: i32, value: bool) {
    absolute_index := level_offset(i32(level)) + index
    slot := absolute_index / 32
    if slot < 0 || int(slot) >= len(field.bits) do return
    bit := u32(absolute_index % 32)
    if value {
        field.bits[slot] |= (1 << bit)
    } else {
        field.bits[slot] &= ~(1 << bit)
    }
}