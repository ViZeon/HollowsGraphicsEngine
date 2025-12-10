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







// Returns index where value would be inserted to maintain sorted order
// If exact match found, returns that index
binary_search_insert :: proc(arr: ^[]data.Sorted_Axis, target: f32, start: i32, end: i32) -> m.ivec2 {
    left := start
    right := end//len(arr) - 1

    // Standard binary-search narrowing
    for right - left > 3 {
        mid := left + (right - left) / 2

        if arr[mid].value < target {
            left = mid + 1
        } else {
            right = mid
        }
    }

    /*
    // Now window is small: compare directly
    best_index := left
    best_dist  := abs(arr[left].value - target)

    for i := left+1; i <= right; i += 1 {
        d := abs(arr[i].value - target)
        if d < best_dist {
            best_dist = d
            best_index = i
        }
    }
    */

    return {left,right}
}


find_z_range_for_point :: proc(arr: ^[]data.Vertex, target: m.vec3) -> m.ivec2 {

    tx := m.floor(target.x);
    ty := m.floor(target.y);

    compare_key := proc(v: data.Vertex, tx, ty: f32) -> int {
        vx := m.floor(v.pos.x);
        vy := m.floor(v.pos.y);

        if vx < tx do return -1;
        if vx > tx do return  1;

        if vy < ty do return -1;
        if vy > ty do return  1;

        return 0;
    };



    first := -1;
    last  := -1;

    // ---- find FIRST ----
    {
        left := 0;
        right := len(arr^) - 1;

        for left <= right {
            mid := (left + right) / 2;
            cmp := compare_key(arr^[mid], tx, ty);


            if cmp == 0 {
                first = mid;
                right = mid - 1; // search left side
            } else if cmp < 0 {
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
    }

    // not found at all
    if first < 0 {
        return m.ivec2{-1, -1};
    }

    // ---- find LAST ----
    {
        left := first;                 // optimization
        right := len(arr^) - 1;

        for left <= right {
            mid := (left + right) / 2;
            cmp := compare_key(arr^[mid], tx, ty);


            if cmp == 0 {
                last = mid;
                left = mid + 1; // search right side
            } else if cmp < 0 {
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
    }

    return m.ivec2{ i32(first), i32(last) };

}
