package testing

import data "../_data"
import math "core:math/linalg/glsl"
import "core:strings"

data_init :: proc() {
    data.app_closed   = add(&data.bool_Direct, &data.bool_Direct_meta, &data.bool_Direct_free, false, "app_closed")
    data.app_time     = add(&data.i64_Direct,  &data.i64_Direct_meta,  &data.i64_Direct_free,  0,     "app_time")
    data.frame_time   = add(&data.i64_Direct,  &data.i64_Direct_meta,  &data.i64_Direct_free,  0,     "frame_time")
    data.fps          = add(&data.int_Direct,  &data.int_Direct_meta,  &data.int_Direct_free,  0,     "fps")

    data.debug_time      = add(&data.f64_Direct, &data.f64_Direct_meta, &data.f64_Direct_free, 2.0, "debug_time")
    data.debug_last_time = add(&data.f64_Direct, &data.f64_Direct_meta, &data.f64_Direct_free, 0.0, "debug_last_time")

    data.window_width_percent  = add(&data.f32_Direct,     &data.f32_Direct_meta,     &data.f32_Direct_free,     0.7,              "window_width_percent")
    data.window_height_percent = add(&data.f32_Direct,     &data.f32_Direct_meta,     &data.f32_Direct_free,     0.8,              "window_height_percent")
    data.window_title          = add(&data.cstring_Direct,  &data.cstring_Direct_meta, &data.cstring_Direct_free, "Compute Engine", "window_title")

    data.cam_pos   = add(&data.vec3_Direct, &data.vec3_Direct_meta, &data.vec3_Direct_free, math.vec3{}, "cam_pos")
    data.cam_speed = add(&data.f32_Direct,  &data.f32_Direct_meta,  &data.f32_Direct_free,  0.1,         "cam_speed")

    data.screen_width  = add(&data.int_Direct, &data.int_Direct_meta, &data.int_Direct_free, 1280, "screen_width")
    data.screen_height = add(&data.int_Direct, &data.int_Direct_meta, &data.int_Direct_free, 720,  "screen_height")

    data.model_path          = add(&data.cstring_Direct, &data.cstring_Direct_meta, &data.cstring_Direct_free, "assets/ABeautifulGame.glb", "model_path")
    data.log_path            = add(&data.cstring_Direct, &data.cstring_Direct_meta, &data.cstring_Direct_free, "./debug/",                  "log_path")
    data.output_dir          = add(&data.cstring_Direct, &data.cstring_Direct_meta, &data.cstring_Direct_free, "image_debug_output/",       "output_dir")
    data.compute_shader_path = add(&data.cstring_Direct, &data.cstring_Direct_meta, &data.cstring_Direct_free, "test_compute.glsl",         "compute_shader_path")

    data.scale_factor  = add(&data.f32_Direct, &data.f32_Direct_meta, &data.f32_Direct_free, 10.0,  "scale_factor")
    data.fov           = add(&data.int_Direct, &data.int_Direct_meta, &data.int_Direct_free, 60,    "fov")
    data.culling_range = add(&data.f32_Direct, &data.f32_Direct_meta, &data.f32_Direct_free, 300.0, "culling_range")

    data.frame_data  = add(&data.frame_data_Direct,   &data.frame_data_Direct_meta,   &data.frame_data_Direct_free,   data.FrameData{},   "frame_data")
    data.debug_stats = add(&data.debug_stats_Direct,   &data.debug_stats_Direct_meta,  &data.debug_stats_Direct_free,  data.Debug_Stats{}, "debug_stats")
    data.log_board   = add(&data.strings_builder_Direct, &data.strings_builder_Direct_meta, &data.strings_builder_Direct_free, strings.Builder{}, "log_board")
}