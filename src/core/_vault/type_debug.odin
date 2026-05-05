package vault

import wr "../_wrappers"

Fetch_Op :: enum { Edit, Copy, Set }

Debug_Stats :: struct {
    // Per-frame performance
    pixel_time:      f64,
    input_time:      f64,
    texture_time:    f64,
    last_print_time: f64,
    last_cam_pos:    wr.Vec3,

    // Fetch counts since last print — reset each print cycle
    fetch_counts: [Type_ID][Fetch_Op]int,

    // Fetch times since last print — only populated when timing_enabled
    fetch_times:  [Type_ID][Fetch_Op]f64,

    // Toggle via F2
    timing_enabled: bool,
}

FrameData :: struct {
    frame_count:   int,
    previous_time: f64,
    FRAME_TITLE:   cstring,
}