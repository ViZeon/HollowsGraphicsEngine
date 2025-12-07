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

FOV_DISTANCE : f32 = 2.00 * f32(math_lin.tan(data.FOV/2.0))

    // Odin
    fov : f32

//called once before render loop
raylib_start_functions ::proc () {

	 model_load_realtime()

     fmt.println("Vertex count after loading:", len(data.VERTICIES_RAW))
     
    for i in 0..<len(data.MODEL_DATA.VERTICES) {
        vert_pos := data.MODEL_DATA.VERTICES[i]
        dist := f32(math_lin.distance(math.vec3{0,0,0}, math.vec3(vert_pos.pos)))
        fov := 2.0 * math.atan_f32(dist / 2.0)

        data.MODEL_DATA.VERTICES[i].fov = fov

        //fmt.println(fov)
    }


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
    
    
    PIXEL_SHIFT := data.CULLING_RANGE * FOV_DISTANCE
    PIXEL_RANGE_WIDTH := PIXEL_SHIFT / f32(width)
    PIXEL_RANGE_HEIGHT := PIXEL_SHIFT / f32(height)
    

    PIXEL_FOV_COORDS := math.vec3{  uv.x * PIXEL_SHIFT, 
                                    uv.y * PIXEL_SHIFT,
                                    0.0}


    range_x := scan_verts(0,
                        f32(PIXEL_FOV_COORDS.x ),
                        0,
                        len(data.MODEL_DATA.VERTICES) - 1)
    range_y := scan_verts(1,
                        f32(PIXEL_FOV_COORDS.y ),
                        range_x.x,
                        range_x.y)
    range := scan_verts(2,
                    f32(0),
                        range_y.x,
                        range_y.y)


    range_z := scan_verts(2,
                    f32(0),
                    0,
                    len(data.MODEL_DATA.VERTICES) - 1)

    



    //fmt.println("pixel is in range")

             fov = 0

            AVERAGE : math.vec3

    subset : []data.Vertex
    if range.x > -1 && range.y > -1 {
        subset = data.MODEL_DATA.VERTICES[range.x:range.y]

        fmtrng := range.y-range.x
        fmt.println(fmtrng)

        if len(subset) > 0 {

            closest_vert = nearest_neighbor(uv, subset)
            //fmt.println("has proper range")



            for VERT in subset {
                AVERAGE += VERT.pos
                fov += VERT.fov
                
            }

            AVERAGE = AVERAGE / f32(len(subset))
            fov = fov / f32(len(subset))

        }

    } else{
        closest_vert = data.Vertex{ PIXEL_FOV_COORDS, PIXEL_SHIFT }
        //fmt.println("out of range")
    }




   



    // Your original visualization approach
    tmp_pixel := [4]i32{
        i32(math.distance(PIXEL_FOV_COORDS.x, AVERAGE.x) * 256),
        i32(math.distance(PIXEL_FOV_COORDS.y, AVERAGE.y) * 256),
        i32(AVERAGE.z * 0),
        256,
    }

        // Your original visualization approach
    tmp_pixel = [4]i32{
        i32( AVERAGE.x * 256),
        i32(AVERAGE.y * 256),
        i32(AVERAGE.z * 0),
        256,
    }
    /*
    tmp_pixel = math.ivec4 {i32(AVERAGE.x), i32(AVERAGE.x), i32(AVERAGE.x), 0}

            tmp_pixel = [4]i32{
    i32(  f32(width)/closest_vert.pos.x *256*0 ),
        i32(f32(height) / closest_vert.pos.y ),
        i32(closest_vert.pos.z * 0),
    256.0,
    }
    */

        fmt.println(PIXEL_FOV_COORDS, AVERAGE, fov, range_x, PIXEL_RANGE_WIDTH, PIXEL_RANGE_HEIGHT)

        return tmp_pixel


        //seems like it needs FOV implentation for accurate measurment
        // or to calculate cullin distance, by max model width

        // maybe the initial version should be FOV independent

}

model_load_realtime :: proc () {
    data.VERTICIES_RAW, data.MODEL_INITIALIZED = model.load_model(data.MODEL_PATH)
    data.MODEL_DATA.VERTICES = process_vertices(&data.VERTICIES_RAW, data.SCALE_FACTOR)
    
    fmt.println("model initialized")
    data.MODEL_INITIALIZED = true
}