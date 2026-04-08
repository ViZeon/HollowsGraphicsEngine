package testing

import math  "core:math/linalg/glsl"
import vault "../_vault"
import data  "../modules/data"
import gltf  "../modules/model"
import "core:fmt"
import "core:strings"


start_functions :: proc() {
    session_init()
    strings.builder_reset((^strings.Builder)(data.edit(vault.log_board)))
    debug_init()

    g_screen_w = (^int)(data.edit(vault.screen_width))^
    g_screen_h = (^int)(data.edit(vault.screen_height))^

cam = Camera{ pos = {0, 3, 12}, dir = {0, 0, -1}, fov = math.PI / 2.0 }
    
    scene = scene_init()

    //prepass_run(g_screen_w, g_screen_h)
    frame_write_to_image()
}

update_fuctions :: proc() {
    debug_frame_begin()





update_turntable(0.016)

    for i in 0 ..< len(screen_tex.source.pixels) {
        screen_tex.source.pixels[i]= 0
}

    //prepass_run(g_screen_w, g_screen_h)
    prepass_run(scene)
    debug_frame_end()
}

// Fragment shader — stateless, no vault access
// Receives pre-fetched world pos + normal, returns RGB
cpu_fragment_shader :: proc(pos, normal: math.vec3) -> math.ivec3 {
    light_dir := math.normalize_vec3(math.vec3{0.4, 0.8, 0.3})
    d         := math.dot(math.normalize_vec3(normal), light_dir)
    if d < 0 do d = 0
    c := i32(d * 255)
    return math.ivec3{c, c, c}
}
