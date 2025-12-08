package testing

import data "../data"
import "core:math"
import m "core:math/linalg/glsl"

distance :: proc(a: m.vec3, b: m.vec3) -> f32 {
    dx := a.x - b.x
    dy := a.y - b.y
    dz := a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
}

nearest_neighbor :: proc(query: m.vec3, points: []data.Vertex) -> data.Vertex {
    
	       if len(points) == 0 {
           return data.Vertex{} // Return empty vertex
       }
    min_idx := 0
    min_dist := distance(query, points[0].pos)
    for i in 1..< len(points) {
        d := distance(query, points[i].pos)
        if d < min_dist {
            min_dist = d
            min_idx = i
        }
    }
    return points[min_idx]
}

trilinear_interp :: proc(
    c: [8]f32, // cube corner values
    fx, fy, fz: f32 // fractional coords in [0,1]
) -> f32 {
    // Interpolate along x
    c00 := c[0]*(1-fx) + c[1]*fx
    c01 := c[2]*(1-fx) + c[3]*fx
    c10 := c[4]*(1-fx) + c[5]*fx
    c11 := c[6]*(1-fx) + c[7]*fx

    // Interpolate along y
    c0 := c00*(1-fy) + c01*fy
    c1 := c10*(1-fy) + c11*fy

    // Interpolate along z
    return c0*(1-fz) + c1*fz
}


get_vert_value :: proc( index: int, axis: int) ->  f32 {
    if index > -1 {
        if axis == 0 {
            return data.MODEL_DATA.VERTICES[index].pos.x;
        }
        if (axis == 1) {
            return data.MODEL_DATA.VERTICES[index].pos.y;
        }
        if (axis == 2) {
            return data.MODEL_DATA.VERTICES[index].pos.z;
        }


        //vertices[i].x_cell = i32(math.floor(x * scale_factor))
        //vertices[i].y_cell = i32(math.floor(y * scale_factor))


    }
    return 0;
}






/*
// Returns index where value would be inserted to maintain sorted order
// If exact match found, returns that index
binary_search_insert :: proc(axis: int, target: f32) -> int {
    left, right := 0, len(get_vert_value()) - 1
    
    for left <= right {
        mid := left + (right - left) / 2
        
        if arr[mid] == target do return mid
        
        if arr[mid] < target {
            left = mid + 1
        } else {
            right = mid - 1
        }
    }
    
    return left  // insertion point
}
*/