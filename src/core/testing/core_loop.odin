package testing

import rl "vendor:raylib"
import stbi "vendor:stb/image"
import math "core:math/linalg/glsl"
import math_lin "core:math/linalg"

import model "../modules/model"

import data "../data"

import "core:os"
import "core:fmt"


SORTED_VERTS : []data.Vertex
closest_vert : data.Vertex

//called once before render loop
raylib_start_functions ::proc () {

	 model_load_realtime()


    frame_pixels = generate_pixels(width, height)

    defer delete(frame_pixels)



    frame_write_to_image()
    raylib_render_frame()
       
}

//callded once per frame
raylib_update_functions :: proc () {

	//fmt.println(closest_vert)

    if texture.id != 0 {
        rl.DrawTexture(texture, 0, 0, rl.WHITE)
    } else {
        fmt.println("Texture not loaded!")
    }
}

//called oncve per pixel
cpu_fragment_shader :: proc (pixel_coords: math.vec2) -> (PIXEL : math.ivec4) {
    
    uv := math.vec3{
        pixel_coords.x / f32(width),
        pixel_coords.y / f32(height),
        0
    }
    
    FOV_DISTANCE : f32 = 2.00 * f32(math_lin.tan(data.FOV/2.0))
    PIXEL_SHIFT := data.CULLING_RANGE * FOV_DISTANCE
    PIXEL_RANGE_WIDTH := PIXEL_SHIFT / f32(width)
    PIXEL_RANGE_HEIGHT := PIXEL_SHIFT / f32(height)
    

    PIXEL_FOV_COORDS := math.vec3{  uv.x * PIXEL_SHIFT, 
                                    uv.y * PIXEL_SHIFT,
                                    0.0}


    range_x := scan_verts(3,
                        f32(PIXEL_FOV_COORDS.x - PIXEL_RANGE_WIDTH),
                        f32(PIXEL_FOV_COORDS.x + PIXEL_RANGE_WIDTH),
                        0,
                        data.vertex_count - 1)
    range := scan_verts(4,
                        f32(PIXEL_FOV_COORDS.y - PIXEL_RANGE_WIDTH),
                        f32(PIXEL_FOV_COORDS.y + PIXEL_RANGE_WIDTH),
                        range_x.x,
                        range_x.y)
    
    if range.x != -1 && range.y != -1 {
        fmt.println("pixel is in range")
        subset := data.MODEL_DATA.vertices[range.x:range.y]
        
        // Find 4 nearest vertices
        nearest: [4]data.Vertex
        distances: [4]f32 = {1e38, 1e38, 1e38, 1e38}
        
        for vert in subset {
            dist := math.distance(PIXEL_FOV_COORDS.xy, vert.coordinates.xy)
            
            for i in 0..<4 {
                if dist < distances[i] {
                    for j := 3; j > i; j -= 1 {
                        distances[j] = distances[j-1]
                        nearest[j] = nearest[j-1]
                    }
                    distances[i] = dist
                    nearest[i] = vert
                    break
                }
            }
        }
        
        // Inverse distance weighting (simpler than bilinear)
        total_weight: f32 = 0
        interpolated_vert := math.vec3{0, 0, 0}
        
        weighted_pixel : [4]i32

        for i in 0..<4 {
            //if distances[i] < PIXEL_RANGE_WIDTH  {
                // Pixel exactly on vertex
                weighted_pixel = [4]i32{
                    i32(math.distance(PIXEL_FOV_COORDS.x, interpolated_vert.x) * 256),
                    i32(math.distance(PIXEL_FOV_COORDS.y, interpolated_vert.y) * 256),
                    i32(nearest[i].coordinates.z * 0),
                    256,
                }
                //return tmp_pixel
            //}
            
            weight := 1.0 / (distances[i] * distances[i])
            total_weight += weight
            interpolated_vert += weight * nearest[i].coordinates
        }
        
        interpolated_vert /= total_weight
        
        // Your original visualization approach
        tmp_pixel := [4]i32{
            i32(math.distance(PIXEL_FOV_COORDS.x, interpolated_vert.x) * 256),
            i32(math.distance(PIXEL_FOV_COORDS.y, interpolated_vert.y) * 256),
            i32(interpolated_vert.z * 0),
            256,
        }

        //tmp_pixel = weighted_pixel

        fmt.println(PIXEL_FOV_COORDS, interpolated_vert, weighted_pixel, distances)

        return tmp_pixel
    }
    
    return [4]i32{0, 0, 0, 255}
}

model_load_realtime :: proc () {
	    //process_vertices()

        data.raw_vertices, data.vertex_count, data.model_initialized = model.load_model(data.MODEL_PATH)

    //defer delete(raw_vertices)
    
    data.MODEL_DATA = process_vertices(data.raw_vertices, data.vertex_count, data.SCALE_FACTOR)

    fmt.println("model initialized")

    data.model_initialized = true

}