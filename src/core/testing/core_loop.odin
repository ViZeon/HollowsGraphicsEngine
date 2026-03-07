package testing

import math "core:math/linalg/glsl"
import data "../_data"
import "core:fmt"
import "core:strings"

start_functions :: proc() {
    //data_init()

    set(data.log_board, strings.builder_make(0, 0, context.temp_allocator))

    debug_init()

    screen_w := get(data.screen_width).(int)
    screen_h := get(data.screen_height).(int)
    data.frame_pixels   = make([]u8, screen_w * screen_h * 3)
    data.prepass_buffer = make([]math.ivec4, screen_w * screen_h)

    bounds, center, ok := load_model(get(data.model_path).(cstring))
    if !ok do return

    cam := get(data.cam_pos).(math.vec3)
    cam.x = center.x
    cam.y = center.y
    cam.z = bounds.z.max + 5.0
    set(data.cam_pos, cam)

    field := field_create(bounds, 4)
    field_populate(&field, data.datapoint_Composite[:])
    add(&data.field_Composite, &data.field_Composite_meta, &data.field_Composite_free, field)

    fmt.println("Field built, cells:", len(data.field_Composite[0].bits))

    generate_pixels_inplace(data.frame_pixels, screen_w, screen_h)
    frame_write_to_image()
}

update_fuctions :: proc() {
    debug_frame_begin()
    screen_w := get(data.screen_width).(int)
    screen_h := get(data.screen_height).(int)
    generate_pixels_inplace(data.frame_pixels, screen_w, screen_h)
    debug_frame_end()
    lb := get(data.log_board).(strings.Builder)
    strings.builder_reset(&lb)
    set(data.log_board, lb)
}

cpu_fragment_shader :: proc(pixel_coords: math.vec2) -> (PIXEL: math.ivec4) {
    screen_w := get(data.screen_width).(int)
    idx := int(pixel_coords.y) * screen_w + int(pixel_coords.x)
    if data.prepass_buffer != nil && idx < len(data.prepass_buffer) {
        sample := data.prepass_buffer[idx]
        if sample.w > 0 do return sample
    }

    screen_h := get(data.screen_height).(int)
    world := pixel_to_world_fov(pixel_coords, screen_w, screen_h)
    if len(data.field_Composite) > 0 && field_query(&data.field_Composite[0], world.x, world.y) {
        return math.ivec4{255, 0, 0, 255}
    }
    return math.ivec4{0, 0, 0, 255}
}