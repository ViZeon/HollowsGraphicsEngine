package testing

import math "core:math/linalg/glsl"
import data "../_data"
import "core:fmt"
import "core:strings"

start_functions :: proc() {
    strings.builder_reset((^strings.Builder)(get(data.log_board)))
    debug_init()
    screen_w := (^int)(get(data.screen_width))^
    screen_h := (^int)(get(data.screen_height))^
    data.frame_pixels   = make([]u8, screen_w * screen_h * 3)
    data.prepass_buffer = make([]math.ivec4, screen_w * screen_h)
    bounds, center, ok := load_model((^cstring)(get(data.model_path))^)
    if !ok do return
    cam := (^math.vec3)(get(data.cam_pos))
    cam.x = center.x
    cam.y = center.y
    cam.z = bounds.z.max + 5.0
    field := field_create(bounds, 4)
    dp_slice := make([]data.DataPoint, len(data.arrays[.DataPoint]))
    for i in 0 ..< len(data.arrays[.DataPoint]) {
        dp_slice[i] = data.arrays[.DataPoint][i].(data.DataPoint)
    }
    fmt.println("First dp pos:", dp_slice[0].pos)
    fmt.println("Last dp pos:", dp_slice[len(dp_slice)-1].pos)
    field_populate(&field, dp_slice[:])
    delete(dp_slice)
    add(.Field, field, "model_field")
    field_ptr := (^data.Field)(data.arrays[.Field][0].data)
    fmt.println("Level 0 root occupied:", cell_get_field(field_ptr, 0, 0))
    occupied_finest := 0
    grid_size := i32(1) << uint(field_ptr.levels)
    for i in 0 ..< grid_size * grid_size * grid_size {
        if cell_get_field(field_ptr, field_ptr.levels, i32(i)) do occupied_finest += 1
    }
    fmt.println("Occupied finest cells:", occupied_finest)
    fmt.println("Field built, cells:", len((^data.Field)(data.arrays[.Field][0].data).bits))
    generate_pixels_inplace(data.frame_pixels, screen_w, screen_h)
    frame_write_to_image()
}

update_fuctions :: proc() {
    debug_frame_begin()
    screen_w := (^int)(get(data.screen_width))^
    screen_h := (^int)(get(data.screen_height))^
    generate_pixels_inplace(data.frame_pixels, screen_w, screen_h)
    debug_frame_end()
    strings.builder_reset((^strings.Builder)(get(data.log_board)))
}

cpu_fragment_shader :: proc(pixel_coords: math.vec2) -> (PIXEL: math.ivec4) {
    screen_w := (^int)(get(data.screen_width))^
    screen_h := (^int)(get(data.screen_height))^
    idx := int(pixel_coords.y) * screen_w + int(pixel_coords.x)
    if data.prepass_buffer != nil && idx < len(data.prepass_buffer) {
        sample := data.prepass_buffer[idx]
        if sample.w > 0 do return sample
    }

    world := pixel_to_world_fov(pixel_coords, screen_w, screen_h)
    if len(data.arrays[.Field]) > 0 {
        field := (^data.Field)(data.arrays[.Field][0].data)
        if field_query(field, world.x, world.y) {
            return math.ivec4{255, 0, 0, 255}
        }
    }
    return math.ivec4{0, 0, 0, 255}
}