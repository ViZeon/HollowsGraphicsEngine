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