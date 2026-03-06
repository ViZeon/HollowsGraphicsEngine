package testing

import math_lin "core:math/linalg"
import math "core:math/linalg/glsl"

import data "../_data"

import "core:fmt"
import "core:strings"

// called once before render loop
start_functions :: proc() {
    data.LOG_BOARD   = strings.builder_make(0, 0, context.temp_allocator)
    data.CAM_POS     = {-581.8, -224.2, -0.7}
    debug_init()
    data.frame_pixels = make([]u8, data.SCREEN_WIDTH * data.SCREEN_HEIGHT * 3)

    // Load model
    dps, bounds, center, ok := load_model(data.MODEL_PATH)
    if !ok do return
    data.datapoints = dps

    // Camera centered on model
    data.CAM_POS.x = center.x
    data.CAM_POS.y = center.y
    data.CAM_POS.z = bounds.z.max + 5.0

    // Build field
    field := field_create(bounds, 4)
    field_populate(&field, data.datapoints[:])
    append(&data.fields, field)

    fmt.println("Field built, cells:", len(data.fields[0].bits))

    // Generate initial frame
    generate_pixels_inplace(data.frame_pixels, data.SCREEN_WIDTH, data.SCREEN_HEIGHT)
    frame_write_to_image()
}

// called once per frame
update_fuctions :: proc() {
    debug_frame_begin()
    generate_pixels_inplace(data.frame_pixels, data.SCREEN_WIDTH, data.SCREEN_HEIGHT)
    debug_frame_end()
    strings.builder_reset(&data.LOG_BOARD)
}

// called once per pixel
cpu_fragment_shader :: proc(pixel_coords: math.vec2) -> (PIXEL: math.ivec4) {
    world := pixel_to_world_fov(pixel_coords, data.SCREEN_WIDTH, data.SCREEN_HEIGHT)

    if len(data.fields) > 0 && field_query(&data.fields[0], world.x, world.y) {
        return math.ivec4{255, 0, 0, 255}
    }
    return math.ivec4{0, 0, 0, 255}
}
