package testing

import math  "core:math/linalg/glsl"
import vault "../_vault"
import data  "../modules/data"
import gltf  "../modules/model"
import "core:fmt"
import "core:strings"

@(private) g_screen_field: vault.Field
@(private) g_screen_w:     int
@(private) g_screen_h:     int

start_functions :: proc() {
    session_init()
    strings.builder_reset((^strings.Builder)(data.edit(vault.log_board)))
    debug_init()

    g_screen_w = (^int)(data.edit(vault.screen_width))^
    g_screen_h = (^int)(data.edit(vault.screen_height))^
    vault.frame_pixels   = make([]u8, g_screen_w * g_screen_h * 3)
    vault.prepass_buffer = make([]vault.Ref, g_screen_w * g_screen_h)

    scene_init()

    // Load model — get bounds and raw mesh for field populate
    model_path := (^cstring)(data.edit(vault.model_path))^
    bounds, center, ok := load_model(model_path)
    if !ok do return

    cam := (^math.vec3)(data.edit(vault.cam_pos))
    cam.x = center.x
    cam.y = center.y
    cam.z = bounds.z.max + 5.0

    // Re-load raw mesh for index data needed by field_populate
    // (raw_mesh freed after load_model, need indices for polygon mapping)
    raw_mesh, raw_ok := gltf.load_gltf(model_path)
    if !raw_ok do return
    defer gltf.free_raw_mesh(&raw_mesh)

    dp_offset := len(vault.arrays[.DataPoint]) - len(raw_mesh.positions)

    field := field_create(bounds, WORLD_FIELD_LEVELS, 3)
    field_populate(&field, dp_offset, raw_mesh.indices)

    model_field_meta := data.add(.Field, field, "model_field")
    scene_add_model(bounds, i32(model_field_meta.index))

    field_ptr := (^vault.Field)(data.edit(model_field_meta))
    fmt.println("Level 0 root occupied:", cell_get_field(field_ptr, 0, 0))

    occupied_finest := 0
    grid_size := i32(1) << uint(field_ptr.levels)
    for i in 0 ..< grid_size * grid_size * grid_size {
        if cell_get_field(field_ptr, field_ptr.levels, i32(i)) do occupied_finest += 1
    }
    fmt.println("Occupied finest cells:", occupied_finest)
    fmt.println("Field built, cells:",    len(field_ptr.bits_any))

    g_screen_field = prepass_run(g_screen_w, g_screen_h)
    generate_pixels_inplace(vault.frame_pixels, g_screen_w, g_screen_h)
    frame_write_to_image()
}

update_fuctions :: proc() {
    debug_frame_begin()
    prepass_free(&g_screen_field)
    g_screen_field = prepass_run(g_screen_w, g_screen_h)
    generate_pixels_inplace(vault.frame_pixels, g_screen_w, g_screen_h)
    debug_frame_end()
}

cpu_fragment_shader :: proc(pixel_coords: math.vec2) -> (PIXEL: math.ivec4) {
    px := int(pixel_coords.x)
    py := int(pixel_coords.y)

    pixel_idx := i32(py * g_screen_w + px)

    if pixel_idx < 0 || pixel_idx >= i32(len(g_screen_field.data)) {
        return math.ivec4{0,0,0,255}
    }

    refs := g_screen_field.data[pixel_idx]
if len(refs) == 0 {
    return math.ivec4{0,0,0,255}
}

proxy_idx := refs[0]

entry := vault.arrays[.DataPoint][proxy_idx]
dp := (^vault.DataPoint)(entry.data)

light_dir := math.normalize_vec3(math.vec3{0.4,0.8,0.3})

n := math.normalize_vec3(dp.normal)
d := math.dot(n, light_dir)
if d < 0 do d = 0

c := i32(d * 255)

return math.ivec4{c,c,c,255}
}