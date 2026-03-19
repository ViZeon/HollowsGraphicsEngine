package testing

import vault "../_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"

// Runs the prepass for one frame.
// Iterates model fields spatially front-to-back, walks polygons,
// applies instance transforms, interpolates surface per pixel,
// shades and writes directly to vault.frame_pixels.
// Returns coverage bitfield only — no per-pixel data stored.
// Caller must call prepass_free after frame.
prepass_run :: proc(screen_w, screen_h: int) -> vault.Field {
    cam_pos := (^math.vec3)(data.edit(vault.cam_pos))^

    pixel_count := screen_w * screen_h
    num_u32s    := (pixel_count + 31) / 32

    // Coverage bitfield only — .data intentionally not allocated
    screen_field: vault.Field
    screen_field.bounds = vault.Bounds{
        x = vault.Range{min = 0, max = f32(screen_w)},
        y = vault.Range{min = 0, max = f32(screen_h)},
        z = vault.Range{min = 0, max = 0},
    }
    screen_field.levels   = 0
    screen_field.dims     = 2
    screen_field.bits_any = make([dynamic]u32, num_u32s)
    screen_field.bits_all = make([dynamic]u32, num_u32s)
    // screen_field.data not allocated — direct pixel write path

    // Clear pixel buffer each frame
    for i in 0 ..< len(vault.frame_pixels) {
        vault.frame_pixels[i] = 0
    }

    for fi in 0 ..< len(vault.meta_arrays[.Field]) {
        meta := vault.meta_arrays[.Field][fi]
        if !meta.valid || meta.name != "model_field" do continue

        model_field := (^vault.Field)(vault.arrays[.Field][fi].data)

        transform := vault.Transform{
            pos   = math.vec3{0, 0, 0},
            rot   = transmute(math.quat)[4]f32{0, 0, 0, 1},
            scale = math.vec3{1, 1, 1},
        }

        prepass_walk_field(model_field, &screen_field, transform, cam_pos, screen_w, screen_h)
    }

    return screen_field
}

// Walks a model field spatially front-to-back
prepass_walk_field :: proc(
    model_field:  ^vault.Field,
    screen_field: ^vault.Field,
    transform:    vault.Transform,
    cam_pos:      math.vec3,
    screen_w, screen_h: int,
) {
    grid_size := i32(1) << uint(model_field.levels)
    half      := grid_size / 2

    bz     := model_field.bounds.z.max - model_field.bounds.z.min
    cell_z := bz / f32(grid_size)

    for lz_u := grid_size - 1; lz_u >= 0; lz_u -= 1 {
        cell_world_z := model_field.bounds.z.min + f32(lz_u) * cell_z
        if cell_world_z >= cam_pos.z do continue

        lz := lz_u - half

        for ly_u := i32(0); ly_u < grid_size; ly_u += 1 {
            ly := ly_u - half
            for lx_u := i32(0); lx_u < grid_size; lx_u += 1 {
                lx := lx_u - half

                idx := cell_index(math.ivec3{lx, ly, lz}, model_field.levels, model_field.dims)
                if !cell_get_field(model_field, model_field.levels, idx) do continue
                if len(model_field.data[idx]) == 0 do continue

                prepass_process_cell(
                    model_field,
                    screen_field,
                    idx,
                    transform,
                    cam_pos,
                    screen_w,
                    screen_h,
                )
            }
        }
    }
}

// Processes all polygon data in one cell.
// Shades and writes resolved pixels directly to vault.frame_pixels.
prepass_process_cell :: proc(
    model_field:  ^vault.Field,
    screen_field: ^vault.Field,
    cell_idx:     i32,
    transform:    vault.Transform,
    cam_pos:      math.vec3,
    screen_w, screen_h: int,
) {
    cell_data := model_field.data[cell_idx]
    if len(cell_data) == 0 do return

    poly_count := len(cell_data) / 3
    for p in 0 ..< poly_count {
        i0 := cell_data[p * 3 + 0]
        i1 := cell_data[p * 3 + 1]
        i2 := cell_data[p * 3 + 2]

        if int(i0) >= len(vault.arrays[.DataPoint]) ||
           int(i1) >= len(vault.arrays[.DataPoint]) ||
           int(i2) >= len(vault.arrays[.DataPoint]) { continue }

        dp0 := (^vault.DataPoint)(vault.arrays[.DataPoint][i0].data)
        dp1 := (^vault.DataPoint)(vault.arrays[.DataPoint][i1].data)
        dp2 := (^vault.DataPoint)(vault.arrays[.DataPoint][i2].data)

        p0 := apply_transform(dp0.pos, transform)
        p1 := apply_transform(dp1.pos, transform)
        p2 := apply_transform(dp2.pos, transform)

        n0 := apply_transform_normal(dp0.normal, transform)
        n1 := apply_transform_normal(dp1.normal, transform)
        n2 := apply_transform_normal(dp2.normal, transform)

        avg_normal := math.normalize(n0 + n1 + n2)

        // Back-face culling
        // NOTE: uses base geometry normal only — revisit when displacement/normal maps added
        to_cam := math.normalize(cam_pos - (p0 + p1 + p2) / 3.0)
        if math.dot(avg_normal, to_cam) <= 0 do continue

        px0, py0, ok0 := world_to_pixel(p0, screen_w, screen_h)
        px1, py1, ok1 := world_to_pixel(p1, screen_w, screen_h)
        px2, py2, ok2 := world_to_pixel(p2, screen_w, screen_h)

        if !ok0 && !ok1 && !ok2 do continue

        min_px := max(0, min(px0, min(px1, px2)))
        max_px := min(screen_w - 1, max(px0, max(px1, px2)))
        min_py := max(0, min(py0, min(py1, py2)))
        max_py := min(screen_h - 1, max(py0, max(py1, py2)))

        for py := min_py; py <= max_py; py += 1 {
            for px := min_px; px <= max_px; px += 1 {
                pixel_idx := i32(py * screen_w + px)
                slot      := pixel_idx / 32
                bit       := u32(pixel_idx % 32)

                // Skip already resolved pixels
                if int(slot) < len(screen_field.bits_any) &&
                   (screen_field.bits_any[slot] & (1 << bit)) != 0 { continue }

                world := pixel_to_world_fov(math.vec2{f32(px), f32(py)}, screen_w, screen_h)

                interp_pos, interp_normal := interpolate_surface(p0, n0, p1, n1, p2, n2, world)

                // Verify interpolated point is within polygon
                bary := barycentric(p0, p1, p2, interp_pos)
                if bary.x < -0.01 || bary.y < -0.01 || bary.z < -0.01 do continue

                // Mark pixel resolved
                if int(slot) < len(screen_field.bits_any) {
                    screen_field.bits_any[slot] |= (1 << bit)
                }

                // Build transient DataPoint for shading — no allocation
                proxy := vault.DataPoint{
                    pos    = interp_pos,
                    normal = interp_normal,
                    type   = .Vertex,
                    ref    = vault.REF_INVALID,
                }

                // Shade and write directly to pixel buffer
                color    := cpu_fragment_shader(&proxy)
                buf_idx  := int(pixel_idx) * 3
                vault.frame_pixels[buf_idx + 0] = u8(color.x)
                vault.frame_pixels[buf_idx + 1] = u8(color.y)
                vault.frame_pixels[buf_idx + 2] = u8(color.z)
            }
        }
    }
}

// Applies position transform (translation + scale)
// TODO: apply quaternion rotation when needed
apply_transform :: proc(pos: math.vec3, t: vault.Transform) -> math.vec3 {
    return pos * t.scale + t.pos
}

// Applies rotation-only transform to a normal
apply_transform_normal :: proc(normal: math.vec3, t: vault.Transform) -> math.vec3 {
    // TODO: apply quaternion rotation to normal
    return normal
}

// Frees screen field memory — data slice is nil so no-op on that loop
prepass_free :: proc(screen_field: ^vault.Field) {
    for i in 0 ..< len(screen_field.data) {
        delete(screen_field.data[i])
    }
    delete(screen_field.bits_any)
    delete(screen_field.bits_all)
    delete(screen_field.data)
}
