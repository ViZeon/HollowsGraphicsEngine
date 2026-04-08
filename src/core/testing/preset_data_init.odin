package testing

import vault "../../core/_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"
import "core:strings"

data_init :: proc() {
    vault.app_closed   = data.add(.Bool, false,  "app_closed")
    vault.app_time     = data.add(.I64,  i64(0), "app_time")
    vault.frame_time   = data.add(.I64,  i64(0), "frame_time")
    vault.fps          = data.add(.Int,  0,      "fps")

    vault.debug_time      = data.add(.F64, f64(2.0), "debug_time")
    vault.debug_last_time = data.add(.F64, f64(0.0), "debug_last_time")

    vault.window_width_percent  = data.add(.F32,     f32(0.7),                 "window_width_percent")
    vault.window_height_percent = data.add(.F32,     f32(0.8),                 "window_height_percent")
    vault.window_title          = data.add(.CString, cstring("Compute Engine"), "window_title")

    vault.cam_pos   = data.add(.Vec3, math.vec3{}, "cam_pos")
    vault.cam_speed = data.add(.F32,  f32(0.01),    "cam_speed")

    vault.screen_width  = data.add(.Int, 1920, "screen_width")
    vault.screen_height = data.add(.Int, 1080,  "screen_height")

    vault.screen_field_levels = data.add(.Int, 7, "screen_field_levels")

    //vault.model_path          = data.add(.CString, cstring("assets/ABeautifulGame.glb"), "model_path")
    //vault.model_path          = data.add(.CString, cstring("assets/kenny_blaster/blaster-g.glb"), "model_path")
    //vault.model_path          = data.add(.CString, cstring("assets/LowPolychars3.glb"), "model_path")
    vault.model_path          = data.add(.CString, cstring("assets/boxSphere.glb"), "model_path")
    
    vault.compute_shader_path = data.add(.CString, cstring("test_compute.glsl"),         "compute_shader_path")

    // Debug paths — all under ./debug/
    vault.log_path         = data.add(.CString, cstring("./debug/"),             "log_path")
    vault.output_dir       = data.add(.CString, cstring("./debug/images/"),      "output_dir")
    vault.session_log_path = data.add(.CString, cstring("./debug/session.log"),  "session_log_path")

    vault.scale_factor  = data.add(.F32, f32(10.0),  "scale_factor")
    vault.fov           = data.add(.Int, 60,          "fov")
    vault.culling_range = data.add(.F32, f32(300.0),  "culling_range")

    // Scene — world_dp initialized by scene_init at startup, placeholder here
    vault.world_dp = vault.Metadata{valid = false}

    w := (^int)(data.edit(vault.screen_width))^
    h := (^int)(data.edit(vault.screen_height))^
    vault.screen_texture = data.add(.Texture, vault.Texture{source = {
        pixels = make([dynamic]u8, 
        w*h*3), 
        width = i32(w), 
        height = i32(h), 
        format = .RGB}}, 
        "screen_texture")

    vault.frame_data  = data.add(.FrameData,       vault.FrameData{},   "frame_data")
    vault.debug_stats = data.add(.Debug_Stats,     vault.Debug_Stats{}, "debug_stats")
    vault.log_board   = data.add(.Strings_Builder, strings.Builder{},   "log_board")



    screen_tex = (^vault.Texture)(data.edit(vault.screen_texture))
}


// globals
screen_tex :^vault.Texture
//screen_tex_empty :^vault.Texture

g_screen_w: int
g_screen_h: int

scene: vault.Metadata