package testing

import data "../data"
import model "../modules/model"

import "core:fmt"
import "core:math"
//import "core:"
import m "core:math/linalg/glsl"
import os "core:os"
import os2 "core:os/os2"
import "core:slice"
import "vendor:raylib"


tmp_pixel: m.ivec4


model_load_realtime :: proc() {

	if os.exists(data.CACHE_PATH) {
		data_verts :=
			os.read_entire_file_from_filename_or_err(data.CACHE_PATH) or_else panic(
				"you fool! You've doomed us all!",
			)
		data.MODEL_DATA.VERTICES = slice.reinterpret([]data.Vertex, data_verts)

		for i in 0 ..< 5 {
			fmt.println(data_verts[i])
			fmt.println(data.MODEL_DATA.VERTICES[i])
		}
		//or if you want to check specific errors
		/*
		data_verts, err := os.read_entire_file_from_filename_or_err("verts.bin")
		if err == .Invalid_Dir {
			fmt.printfln("actually I'm ok with this")
		}
		*/
	} else {
		data.VERTICIES_RAW, data.MODEL_INITIALIZED = model.load_model(data.MODEL_PATH)
		data.MODEL_DATA = process_vertices(&data.VERTICIES_RAW, data.SCALE_FACTOR)

		os.write_entire_file(data.CACHE_PATH, slice.to_bytes(data.MODEL_DATA.VERTICES[:]))
	}
	fmt.println("model initialized")
	data.MODEL_INITIALIZED = true
	/*
		data_verts :=
			os2.read_entire_file("verts.bin") or_else panic(
				"you fool! You've doomed us all!",
			)
*/

	//

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
	scaled := make([]data.Vertex, len(vertices)) or_else panic("failed to make")
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

grid_spatial_populate :: proc(model: ^data.Model_Data, cells: ^[dynamic]data.Grid_Key) {
	
	if len(model.VERTICES) == 0 do return

	size_x: int = int(model.BOUNDS.x.max - model.BOUNDS.x.min) + 1
	size_y: int = int(model.BOUNDS.y.max - model.BOUNDS.y.min) + 1
	size_z: int = int(model.BOUNDS.z.max - model.BOUNDS.z.min) + 1


	// Allocate grid
	cell_scale := data.WORLD_SIZE / data.CELL_SIZE * 2
	total_cells := cell_scale * cell_scale * cell_scale
	
	resize(cells, total_cells)
	fmt.println("Allocated cells:", len(cells))

	// Populate with vertices
	for i in 0 ..< len(model.VERTICES) {
		x := i32(m.floor(model.VERTICES[i].pos.x))
		y := i32(m.floor(model.VERTICES[i].pos.y))
		z := i32(m.floor(model.VERTICES[i].pos.z))
		
		//fmt.println(x,y,z)
		//fmt.println (xyz_to_cell(x, y, z) ,  len(cells) -xyz_to_cell(x, y, z) )
		if xyz_to_cell(x, y, z) >= 0  && xyz_to_cell(x, y, z) < i32(len(cells)){
			append(&cells[xyz_to_cell(x, y, z)].keys, i32(i))
			//fmt.println(&cells[xyz_to_cell(x, y, z)].keys)
		}
	}

	// 6 directional sweeps
	sweep_direction(cells, model) // X forward
	// X backward

}

sweep_direction :: proc(
    cells: ^[dynamic]data.Grid_Key,
    model: ^data.Model_Data,
) {
    vert_last := i32(-1)
    
    // Iterate over actual world coordinate range
    for x := i32(model.BOUNDS.x.min); x <= i32(model.BOUNDS.x.max); x += 1 {
        for y := i32(model.BOUNDS.y.min); y <= i32(model.BOUNDS.y.max); y += 1 {
            for z := i32(model.BOUNDS.z.min); z <= i32(model.BOUNDS.z.max); z += 1 {
                ID := xyz_to_cell(x, y, z)
                
                if ID < 0 || ID >= i32(len(cells)) do continue
                
                if len(cells[ID].keys) > 0 && cells[ID].keys[0] >= 0 {
                    vert_last = ID
                } else {
                    append(&cells[ID].keys, -vert_last)
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
