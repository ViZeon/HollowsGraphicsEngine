package testing

import data "../_data"
import math "core:math/linalg/glsl"
import "core:strings"

data_init :: proc() {
    data.app_closed   = add(.Bool, false,  "app_closed")
    data.app_time     = add(.I64,  i64(0), "app_time")
    data.frame_time   = add(.I64,  i64(0), "frame_time")
    data.fps          = add(.Int,  0,      "fps")

    data.debug_time      = add(.F64, 2.0, "debug_time")
    data.debug_last_time = add(.F64, 0.0, "debug_last_time")

    data.window_width_percent  = add(.F32,     f32(0.7),         "window_width_percent")
    data.window_height_percent = add(.F32,     f32(0.8),         "window_height_percent")
    data.window_title          = add(.CString, cstring("Compute Engine"), "window_title")

    data.cam_pos   = add(.Vec3, math.vec3{}, "cam_pos")
    data.cam_speed = add(.F32,  f32(0.1),    "cam_speed")

    data.screen_width  = add(.Int, 1280, "screen_width")
    data.screen_height = add(.Int, 720,  "screen_height")

    data.model_path          = add(.CString, cstring("assets/ABeautifulGame.glb"), "model_path")
    data.log_path            = add(.CString, cstring("./debug/"),                  "log_path")
    data.output_dir          = add(.CString, cstring("image_debug_output/"),       "output_dir")
    data.compute_shader_path = add(.CString, cstring("test_compute.glsl"),         "compute_shader_path")

    data.scale_factor  = add(.F32, f32(10.0),  "scale_factor")
    data.fov           = add(.Int, 60,         "fov")
    data.culling_range = add(.F32, f32(300.0), "culling_range")

    data.frame_data  = add(.FrameData,      data.FrameData{},   "frame_data")
    data.debug_stats = add(.Debug_Stats,    data.Debug_Stats{}, "debug_stats")
    data.log_board   = add(.Strings_Builder, strings.Builder{}, "log_board")
}