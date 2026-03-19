package testing

import math  "core:math/linalg/glsl"
import vault "../_vault"
import data  "../modules/data"
import gltf  "../modules/model"
import "core:fmt"
import "core:strings"

@(private) g_screen_w: int
@(private) g_screen_h: int

start_functions :: proc() {
    session_init()
    strings.builder_reset((^strings.Builder)(data.edit(vault.log_board)))
    debug_init()

    g_screen_w = (^int)(data.edit(vault.screen_width))^
    g_screen_h = (^int)(data.edit(vault.screen_height))^
    vault.frame_pixels   = make([]u8, g_screen_w * g_screen_h * 3)
    vault.prepass_buffer = make([]vault.Ref, g_screen_w * g_screen_h)

    scene_init()

    model_path          := (^cstring)(data.edit(vault.model_path))^
    model_meta, center, ok := load_model(model_path)
    if !ok do return

    model := (^vault.Model)(vault.arrays[.Model][model_meta.index].data)

    cam   := (^math.vec3)(data.edit(vault.cam_pos))
    cam.x  = center.x
    cam.y  = center.y
    cam.z  = model.bounds.z.max + 5.0

    scene_add_model(vault.Ref{index = i32(model_meta.index), version = 0})

    screen_fields_rebuild(g_screen_w, g_screen_h)
    prepass_run(g_screen_w, g_screen_h)
    frame_write_to_image()
}

update_fuctions :: proc() {
    debug_frame_begin()

    dirty := (^bool)(data.edit(vault.screen_field_dirty))^
    if dirty {
        screen_fields_rebuild(g_screen_w, g_screen_h)
    } else {
        screen_fields_clear()
    }

    prepass_run(g_screen_w, g_screen_h)
    debug_frame_end()
}

// Stateless — shades a DataPoint directly
cpu_fragment_shader :: proc(dp: ^vault.DataPoint) -> math.ivec4 {
    light_dir := math.normalize_vec3(math.vec3{0.4, 0.8, 0.3})
    n := math.normalize_vec3(dp.normal)
    d := math.dot(n, light_dir)
    if d < 0 do d = 0
    c := i32(d * 255)
    return math.ivec4{c, c, c, 255}
}

// ---- Screen field management ----

screen_fields_rebuild :: proc(screen_w, screen_h: int) {
    nesting   := (^int)(data.edit(vault.screen_field_nesting))^
    cell_size := (^int)(data.edit(vault.screen_field_cell_size))^

    levels := 0
    cs     := 1
    for cs < cell_size { cs *= 4; levels += 1 }

    grid_1d := 1 << uint(levels)

    for nest_start in vault.screen_field_ids {
        _ = nest_start
    }
    clear(&vault.screen_field_ids)

    count := 1
    for nest in 0 ..< nesting {
        start_idx := len(vault.arrays[.Field])
        append(&vault.screen_field_ids, i32(start_idx))

        level_w := f32(screen_w)
        level_h := f32(screen_h)
        for _ in 0 ..< nest {
            level_w /= f32(grid_1d)
            level_h /= f32(grid_1d)
        }

        bounds := vault.Bounds{
            x = {min = 0, max = level_w},
            y = {min = 0, max = level_h},
            z = {min = 0, max = 0},
        }

        data.preallocate(.Field, count)
        for _ in 0 ..< count {
            f := field_create_screen(bounds, levels)
            data.add(.Field, f, "sf")
        }

        count *= cell_size
    }

    (^bool)(data.edit(vault.screen_field_dirty))^ = false
    fmt.println("screen_fields_rebuild: nesting=", nesting, "cell_size=", cell_size, "levels=", levels, "grid_1d=", grid_1d)
}

screen_fields_clear :: proc() {
    nesting   := (^int)(data.edit(vault.screen_field_nesting))^
    cell_size := (^int)(data.edit(vault.screen_field_cell_size))^

    count := 1
    for nest in 0 ..< nesting {
        start := int(vault.screen_field_ids[nest])
        for i in 0 ..< count {
            f := (^vault.Field)(vault.arrays[.Field][start + i].data)
            for j in 0 ..< len(f.bits_any) { f.bits_any[j] = 0 }
            for j in 0 ..< len(f.bits_all) { f.bits_all[j] = 0 }
        }
        count *= cell_size
    }
}

field_create_screen :: proc(bounds: vault.Bounds, levels: int) -> vault.Field {
    field: vault.Field
    field.bounds = bounds
    field.levels = levels
    field.dims   = 2

    total    := total_cells(levels + 1, 2)
    num_u32s := (total + 31) / 32
    field.bits_any = make([dynamic]u32, num_u32s)
    field.bits_all = make([dynamic]u32, num_u32s)
    return field
}
