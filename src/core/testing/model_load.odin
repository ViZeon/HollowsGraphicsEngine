package testing

import data "../data"
import model "../modules/model"

import "core:fmt"
import "core:math"
//import "core:"
import m "core:math/linalg/glsl"
import "core:slice"
import "vendor:raylib"


tmp_pixel: m.ivec4


model_load_realtime :: proc() {
	data.VERTICIES_RAW, data.MODEL_INITIALIZED = model.load_model(data.MODEL_PATH)
	data.MODEL_DATA = process_vertices(&data.VERTICIES_RAW, data.SCALE_FACTOR)

	fmt.println("model initialized")
	data.MODEL_INITIALIZED = true
}

// Process raw vertices into Model_Data
process_vertices :: proc(vertices: ^[]data.Vertex, scale_factor: f32) -> data.Model_Data {


	// Init bounds from first vertex
	first := vertices[0]
	min_x := first.pos.x
	min_y := first.pos.y
	min_z := first.pos.z

	max_x := min_x
	max_y := min_y
	max_z := min_z

	MAX_RADIUS: f32

	// Scale all vertices
	scaled := make([]data.Vertex, len(vertices))
	for i in 0 ..< len(vertices) {
		scaled[i].pos.x = vertices[i].pos.x * scale_factor
		scaled[i].pos.y = vertices[i].pos.y * scale_factor
		scaled[i].pos.z = vertices[i].pos.z * scale_factor

		scaled[i].normal = vertices[i].normal

		// Find bounds
		x := scaled[i].pos.x
		y := scaled[i].pos.y
		z := scaled[i].pos.z

		if x < min_x do min_x = x
		if y < min_y do min_y = y
		if z < min_z do min_z = z

		if x > max_x do max_x = x
		if y > max_y do max_y = y
		if z > max_z do max_z = z

		if MAX_RADIUS < max_x do MAX_RADIUS = max_x
		if MAX_RADIUS < max_y do MAX_RADIUS = max_y
		if MAX_RADIUS < max_z do MAX_RADIUS = max_z
	}

	bounds: data.Bounds

	bounds.x.min = min_x
	bounds.y.min = min_y
	bounds.z.min = min_z


	bounds.x.max = max_x
	bounds.y.max = max_y
	bounds.z.max = max_z


	// Sort by floor(x), floor(y), then z
	slice.sort_by(scaled, proc(a, b: data.Vertex) -> bool {
		if m.floor(a.pos.x) != m.floor(b.pos.x) do return m.floor(a.pos.x) < m.floor(b.pos.x)
		if m.floor(a.pos.y) != m.floor(b.pos.y) do return m.floor(a.pos.y) < m.floor(b.pos.y)
		return a.pos.z < b.pos.z
	})

	return data.Model_Data{scaled, bounds, MAX_RADIUS}
}

grid_spatial_populate :: proc(
	model: ^data.Model_Data,
	cells: ^[dynamic][dynamic][dynamic]data.Grid_Key,
) {
	if len(model.VERTICES) == 0 do return

	size_x: int = int(model.BOUNDS.x.max - model.BOUNDS.x.min) + 1
	size_y: int = int(model.BOUNDS.y.max - model.BOUNDS.y.min) + 1
	size_z: int = int(model.BOUNDS.z.max - model.BOUNDS.z.min) + 1

	// Allocate grid
	resize(cells, size_x)
	for x in 0 ..< size_x {
		resize(&cells[x], size_y)
		for y in 0 ..< size_y {
			resize(&cells[x][y], size_z)
		}
	}

	// Populate with vertices
	for i in 0 ..< len(model.VERTICES) {
		x := int(m.floor(model.VERTICES[i].pos.x - model.BOUNDS.x.min))
		y := int(m.floor(model.VERTICES[i].pos.y - model.BOUNDS.y.min))
		z := int(m.floor(model.VERTICES[i].pos.z - model.BOUNDS.z.min))

		if x >= 0 && x < size_x && y >= 0 && y < size_y && z >= 0 && z < size_z {
			append(&cells[x][y][z].keys, i32(i))
		}
	}

	// 6 directional sweeps
	sweep_direction(cells, size_x, size_y, size_z) // X forward
	// X backward

}

sweep_direction :: proc(
	cells: ^[dynamic][dynamic][dynamic]data.Grid_Key,
	size_x, size_y, size_z: int,
) {
	//sizes := [3]int{size_x, size_y, size_z}
	vert_last_x := i32(-1)
	vert_last_y := i32(-1)
	vert_last_z := i32(-1)


	for x in 0 ..< size_x {
		for y in 0 ..< size_y {
			for z in 0 ..< size_z {

				//vert_last_floor := := cells [vert_last_x] [vert_last_y] [vert_last_z]


				// Check if cell has real vertex
				if len(cells[x][y][z].keys) > 0 && cells[x][y][z].keys[0] >= 0 {
					vert_last_x = cells[x][y][z].keys[0]
					vert_last_y = cells[x][y][z].keys[0]
					vert_last_z = cells[x][y][z].keys[0]

				} else {
					append(&cells[x][y][z].keys, -vert_last_x)
					append(&cells[x][y][z].keys, -vert_last_y)
					append(&cells[x][y][z].keys, -vert_last_z)
				}

			}
		}
	}
}
sort_by_axis :: proc(
	list: ^[]data.Vertex,
	xs: ^[]data.Sorted_Axis,
	ys: ^[]data.Sorted_Axis,
	zs: ^[]data.Sorted_Axis,
) {
	xs^ = make([]data.Sorted_Axis, len(list))
	ys^ = make([]data.Sorted_Axis, len(list))
	zs^ = make([]data.Sorted_Axis, len(list))

	// Fill them
	for i in 0 ..< len(list) {
		xs[i] = data.Sorted_Axis{list[i].pos.x, i}
		ys[i] = data.Sorted_Axis{list[i].pos.y, i}
		zs[i] = data.Sorted_Axis{list[i].pos.z, i}
	}

	// Sort them independently

	for i in 0 ..< len(list^) {
		xs^[i] = data.Sorted_Axis{list^[i].pos.x, i}
		ys^[i] = data.Sorted_Axis{list^[i].pos.y, i}
		zs^[i] = data.Sorted_Axis{list^[i].pos.z, i}
	}

	slice.sort_by(xs^, proc(a, b: data.Sorted_Axis) -> bool {
		return a.value < b.value
	})

	slice.sort_by(ys^, proc(a, b: data.Sorted_Axis) -> bool {
		return a.value < b.value
	})

	slice.sort_by(zs^, proc(a, b: data.Sorted_Axis) -> bool {
		return a.value < b.value
	})


}


check_bounds :: proc(x: int, y: int, z: int, bounds: data.Bounds) -> bool {
	size_x := int(bounds.x.max - bounds.x.min) + 1
	size_y := int(bounds.y.max - bounds.y.min) + 1
	size_z := int(bounds.z.max - bounds.z.min) + 1

	if x >= size_x || x < 0 do return false
	if y >= size_y || y < 0 do return false
	if z >= size_z || z < 0 do return false

	return true
}
