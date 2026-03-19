package vault

// App state
app_closed:   Metadata
app_time:     Metadata
frame_time:   Metadata
fps:          Metadata

// Timing
debug_time:      Metadata
debug_last_time: Metadata

// Window
window_width_percent:  Metadata
window_height_percent: Metadata
window_title:          Metadata

// Camera
cam_pos:   Metadata
cam_speed: Metadata

// Screen
screen_width:  Metadata
screen_height: Metadata

// Asset paths
model_path:          Metadata
compute_shader_path: Metadata

// Debug paths
log_path:         Metadata
output_dir:       Metadata
session_log_path: Metadata

// Config
scale_factor:  Metadata
fov:           Metadata
culling_range: Metadata

// Scene
world_dp: Metadata   // DataPoint of type .Field — root of the world hierarchy

// Frame
frame_data:  Metadata
debug_stats: Metadata

// External
log_board: Metadata

// Screen field config
// screen_field_ids lives in arrays.odin as [dynamic]i32 — start index per nesting level
screen_field_nesting:   Metadata   // int  — how many Fields deep (default 2)
screen_field_cell_size: Metadata   // int  — finest cells per Field (default 1024, must be power of 4)
screen_field_dirty:     Metadata   // bool — triggers rebuild on next frame
