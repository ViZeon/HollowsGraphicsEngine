package testing

import data "../data"
import model "../modules/model"

import "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:slice"
import m "core:math/linalg/glsl"


tmp_pixel : m.ivec4



// Process raw vertices into Model_Data
process_vertices :: proc(vertices: ^[]data.Vertex, scale_factor: f32) -> []data.Vertex {
    // Scale all vertices
    scaled := make([]data.Vertex, len(vertices))
    for i in 0..<len(vertices) {
        scaled[i].pos.x = vertices[i].pos.x * scale_factor
        scaled[i].pos.y = vertices[i].pos.y * scale_factor
        scaled[i].pos.z = vertices[i].pos.z * scale_factor

        scaled [i].normal = vertices[i].normal
    }


    
    return scaled
}

sort_by_axis :: proc (list : ^[]data.Vertex, xs: ^[]data.Sorted_Axis, ys: ^[]data.Sorted_Axis, zs: ^[]data.Sorted_Axis) {
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
        xs^[i] = data.Sorted_Axis{ list^[i].pos.x, i }
        ys^[i] = data.Sorted_Axis{ list^[i].pos.y, i }
        zs^[i] = data.Sorted_Axis{ list^[i].pos.z, i }
    }

    // Sort X axis by: floored X → floored Y → Z
    sort_by_axis_order(&xs, &list, {.X, .Y, .Z}, {true, true, false})

    // Sort Y axis by: floored X → floored Y → Z
    sort_by_axis_order(&ys, &list, {.X, .Y, .Z}, {true, true, false})

    // Sort Z axis by: floored X → floored Y → Z
    sort_by_axis_order(&zs, &list, {.X, .Y, .Z}, {true, true, false})
}

Axis_Type :: enum {
    X, Y, Z
}

get_axis_value :: proc(v: ^data.Vertex, axis: Axis_Type) -> f32 {
    switch axis {
    case .X: return v.pos.x
    case .Y: return v.pos.y
    case .Z: return v.pos.z
    }
    return 0
}

sort_by_axis_order :: proc(slice: ^[]data.Sorted_Axis, list: []data.Vertex, order: [3]Axis_Type, floor_mask: [3]bool) {
    slice.sort_by(slice^, proc(a, b: data.Sorted_Axis) -> bool {
        a_vertex := &list[a.index]
        b_vertex := &list[b.index]
        
        for i in 0..<3 {
            axis := order[i]
            a_val := get_axis_value(a_vertex, axis)
            b_val := get_axis_value(b_vertex, axis)
            
            if floor_mask[i] {
                a_val = math.floor(a_val)
                b_val = math.floor(b_val)
            }
            
            if a_val != b_val {
                return a_val < b_val
            }
        }
        return false
    })
}