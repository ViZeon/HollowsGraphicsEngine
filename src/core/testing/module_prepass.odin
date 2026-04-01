package testing

import vault "../_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"

// PREPASS — polygon-driven pixel fill
//
// Walk world field → get model refs
// Per model → walk source polygons directly
// Per polygon:
//   1. Project verts to screen ONCE → cache screen positions
//   2. Coarse depth cull via screen field at polygon bbox level (one fetch)
//   3. Per pixel in bbox: fine depth check via field_query(create_children=true), NURBS interp, write
//   4. Propagate z bounds upward via screen_field_propagate_bounds
//
// Fragment shader — stateless, no vault access

prepass_run_old :: proc(screen_w, screen_h: int) {
    cam_pos  := (^math.vec3)(data.edit(vault.cam_pos))^
    fov      := (^int)(data.edit(vault.fov))^
    tan_hfov := math.tan(f64(fov) * f64(math.PI) / 180.0 / 2.0)
    aspect   := f64(screen_w) / f64(screen_h)

    screen_tex  := (^vault.Texture)(data.edit(vault.screen_texture))
    screen_root := (^vault.Field)(data.edit(screen_field_get_root(screen_w, screen_h)))

    // Clear screen pixels and screen field occupancy bits
    for i in 0 ..< len(screen_tex.source.pixels) { screen_tex.source.pixels[i] = 0 }
    field_clear(screen_root)

    world_dp    := (^vault.DataPoint)(data.edit(vault.world_dp))
    world_field := (^vault.Field)(data.edit(vault.Metadata{
        index = int(world_dp.metadata.index), type_id = .Field, valid = true,
    }))

    world_grid  := i32(1) << uint(world_field.levels)
    world_total := world_grid * world_grid * world_grid

    for cell_idx in 0 ..< world_total {
        if !cell_get(world_field.bits_any[:], world_field.levels, cell_idx, world_field.dims) do continue
        if len(world_field.data[cell_idx]) < 2 do continue

        // data[cell][0] = Bounds index, data[cell][1..] = model array indices
        for ref_i in 1 ..< len(world_field.data[cell_idx]) {
            model_idx := world_field.data[cell_idx][ref_i]
            model     := (^vault.Model)(vault.arrays[.Model][model_idx].data)

            for pi in 0 ..< len(model.source.polys) {
                poly := &model.source.polys[pi]
                vc   := len(poly.source.vert_indices)
                if vc == 0 do continue

                // Pre-fetch and pre-project verts once — no vault access in pixel loop
                world_pos  := make([]math.vec3, vc); defer delete(world_pos)
                normals    := make([]math.vec3, vc); defer delete(normals)
                screen_pos := make([]math.vec3, vc); defer delete(screen_pos)

                px_min, py_min := screen_w, screen_h
                px_max, py_max := 0, 0
                z_min          := max(f32)
                z_max          := -max(f32)
                any_visible    := false

                for vi in 0 ..< vc {
                    v             := &model.source.verts[poly.source.vert_indices[vi]]
                    world_pos[vi]  = v.source.pos
                    normals[vi]    = v.source.normal

                    px, py, ok    := project_to_screen(v.source.pos, cam_pos, tan_hfov, aspect, screen_w, screen_h)
                    screen_pos[vi] = math.vec3{f32(px) + 0.5, f32(py) + 0.5, 0}
                    if !ok do continue

                    any_visible = true
                    px_min = min(px_min, px); px_max = max(px_max, px)
                    py_min = min(py_min, py); py_max = max(py_max, py)
                    z_min  = min(z_min, v.source.pos.z)
                    z_max  = max(z_max, v.source.pos.z)
                }

                if !any_visible do continue

                // Coarse depth cull — one vault fetch at polygon bbox level
                if coarse, coarse_ok := screen_field_coarse_bounds(px_min, py_min, px_max, py_max, screen_w, screen_h); coarse_ok {
                    if z_min <= coarse.z.min do continue
                }

                // Clamp bbox to screen
                px_min = max(px_min, 0); py_min = max(py_min, 0)
                px_max = min(px_max, screen_w-1); py_max = min(py_max, screen_h-1)

                for py in py_min ..= py_max {
                    for px in px_min ..= px_max {
                        // Descend to pixel cell via field_query — creates child fields as needed
                        leaf, leaf_cell, leaf_ok := screen_field_get_pixel_cell(px, py, screen_w, screen_h)
                        if !leaf_ok do continue
                        // Per-pixel depth check
                        if cell_get(leaf.bits_any[:], leaf.levels, leaf_cell, leaf.dims) {
                            if len(leaf.data[leaf_cell]) > 0 {
                                b := (^vault.Bounds)(data.edit(data.resolve(leaf.data[leaf_cell][0])))
                                if z_min <= b.z.min do continue
                                b.z.min = z_min; b.z.max = z_max
                            }
                        } else {
                            if len(leaf.data[leaf_cell]) == 0 {
                                bm := data.add(.Bounds, vault.Bounds{z = {z_min, z_max}}, "px_bounds")
                                append(&leaf.data[leaf_cell], i32(bm.id))
                            } else {
                                b := (^vault.Bounds)(data.edit(data.resolve(leaf.data[leaf_cell][0])))
                                b.z.min = z_min; b.z.max = z_max
                            }
                            cell_set(leaf.bits_any[:], leaf.levels, leaf_cell, leaf.dims, true)
                        }

                        // NURBS interp — query in screen space, output in world space
                        pq          := math.vec3{f32(px)+0.5, f32(py)+0.5, 0}
                        wpos, wnorm := nurbs_interp(pq, screen_pos, world_pos, normals)

                        // Fragment shader — stateless, no vault access
                        color   := cpu_fragment_shader(wpos, wnorm)
                        buf_idx := (py * screen_w + px) * 3
                        screen_tex.source.pixels[buf_idx+0] = u8(color.x)
                        screen_tex.source.pixels[buf_idx+1] = u8(color.y)
                        screen_tex.source.pixels[buf_idx+2] = u8(color.z)

                        // Propagate z bounds upward through parent screen fields
                        screen_field_propagate_bounds(px, py, z_min, z_max, screen_w, screen_h)
                    }
                }
            }
        }
    }
}
