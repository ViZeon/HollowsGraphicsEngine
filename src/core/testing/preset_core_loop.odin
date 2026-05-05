package testing

import wr "../_wrappers"
import vault "../_vault"
import data  "../modules/data"
import gltf  "../modules/model"


start_functions :: proc() {
    session_init()
    wr.strings_builder_reset((^wr.Builder)(data.edit(vault.log_board)))
    debug_init()

    g_screen_w = (^int)(data.edit(vault.screen_width))^
    g_screen_h = (^int)(data.edit(vault.screen_height))^

cam = Camera{ pos = {0, 3, 12}, dir = {0, 0, -1}, fov = wr.PI / 2.0 }
    
    scene = scene_init()

    //prepass_run(g_screen_w, g_screen_h)
    frame_write_to_image()
}

update_fuctions :: proc() {
    debug_frame_begin()


lua_start()


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
cpu_fragment_shader :: proc(pos, normal: wr.Vec3) -> wr.IVec3 {
    light_dir := wr.normalize_vec3(wr.Vec3{0.4, 0.8, 0.3})
    d         := wr.dot(wr.normalize_vec3(normal), light_dir)
    if d < 0 do d = 0
    c := i32(d * 255)
    return wr.IVec3{c, c, c}
}