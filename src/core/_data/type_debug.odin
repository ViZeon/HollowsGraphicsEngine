package data

import math "core:math/linalg/glsl"

Debug_Stats :: struct {
    input_time:             f64,
    pixel_time:             f64,
    texture_time:           f64,
    last_print_time:        f64,
    total_pixels_processed: int,
    total_vertices_checked: int,
    max_range_size:         i32,
    min_range_size:         i32,
    frame_vertices_checked: int,
    frame_pixels_processed: int,
    last_cam_pos:           math.vec3,
}