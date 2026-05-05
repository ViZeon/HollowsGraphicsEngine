package testing

import vault "../../core/_vault"
import data  "../modules/data"
import wr "../_wrappers"

debug_init :: proc() {
    stats := (^vault.Debug_Stats)(data.edit(vault.debug_stats))
    stats.last_print_time = 0
    stats.last_cam_pos    = (^wr.Vec3)(data.edit(vault.cam_pos))^
    save_screen_pos()
}

debug_frame_begin :: proc() {}

debug_frame_end :: proc() {
    app_time := (^i64)(data.edit(vault.app_time))
    frame_t  := wr.time_now_nsec() - app_time^
    (^i64)(data.edit(vault.frame_time))^ = frame_t
    (^int)(data.edit(vault.fps))^        = calc_FPS(frame_t)
    app_time^                            = wr.time_now_nsec()

    stats        := (^vault.Debug_Stats)(data.edit(vault.debug_stats))
    debug_t      := (^f64)(data.edit(vault.debug_time))^
    current_time := f64(wr.time_now_nsec()) / 1e9

    if current_time - stats.last_print_time >= debug_t {
        snapshot := debug_build_snapshot(stats)
        debug_print_snapshot(snapshot)
        session_log_append(snapshot)
        stats.last_print_time = current_time
        stats.last_cam_pos    = (^wr.Vec3)(data.edit(vault.cam_pos))^
        stats.fetch_counts    = {}
        stats.fetch_times     = {}
    }
}

debug_build_snapshot :: proc(stats: ^vault.Debug_Stats) -> string {
    fps     := (^int)(data.edit(vault.fps))^
    cam_pos := (^wr.Vec3)(data.edit(vault.cam_pos))

    sb: wr.Builder
    wr.strings_builder_init(&sb)
    defer wr.strings_builder_destroy(&sb)

    wr.fmt_sbprintf(&sb, "=== HOLLOWS ENGINE ===\n")
    wr.fmt_sbprintf(&sb, "FPS: %d | Pixel: %.1fms | Input: %.3fms | Texture: %.3fms\n",
        fps,
        stats.pixel_time   * 1000,
        stats.input_time   * 1000,
        stats.texture_time * 1000,
    )
    wr.fmt_sbprintf(&sb, "Camera: [%.2f, %.2f, %.2f]\n\n", cam_pos.x, cam_pos.y, cam_pos.z)

    wr.fmt_sbprintf(&sb, "--- DATA (valid / total) ---\n")
    grand_valid := 0
    grand_total := 0
    for type_id in vault.Type_ID {
        total := len(vault.arrays[type_id])
        if total == 0 do continue
        valid := 0
        for i in 0 ..< total {
            if vault.meta_arrays[type_id][i].valid do valid += 1
        }
        grand_valid += valid
        grand_total += total
        wr.fmt_sbprintf(&sb, "  %-18v %d / %d\n", type_id, valid, total)
    }
    wr.fmt_sbprintf(&sb, "  %-18v %d / %d\n\n", "TOTAL", grand_valid, grand_total)

    wr.fmt_sbprintf(&sb, "--- FETCHES (edit / copy / set) ---\n")
    for type_id in vault.Type_ID {
        e := stats.fetch_counts[type_id][.Edit]
        c := stats.fetch_counts[type_id][.Copy]
        s := stats.fetch_counts[type_id][.Set]
        if e == 0 && c == 0 && s == 0 do continue
        wr.fmt_sbprintf(&sb, "  %-18v %d / %d / %d\n", type_id, e, c, s)
    }

    debug_field_occupancy(&sb)

    if stats.timing_enabled {
        wr.fmt_sbprintf(&sb, "\n--- FETCH TIMES ns (edit / copy / set) ---\n")
        for type_id in vault.Type_ID {
            e := stats.fetch_times[type_id][.Edit]
            c := stats.fetch_times[type_id][.Copy]
            s := stats.fetch_times[type_id][.Set]
            if e == 0 && c == 0 && s == 0 do continue
            wr.fmt_sbprintf(&sb, "  %-18v %.0f / %.0f / %.0f\n", type_id, e, c, s)
        }
    } else {
        wr.fmt_sbprintf(&sb, "\n[F2: enable fetch timing]\n")
    }

    return wr.strings_clone(wr.strings_to_string(sb))
}

debug_print_snapshot :: proc(snapshot: string) {
    clear_screen()
    wr.fmt_print(snapshot)
}

debug_field_occupancy :: proc(sb: ^wr.Builder) {
    wr.fmt_sbprintf(sb, "\n--- FIELD OCCUPANCY ---\n")

    // Only print non-sf fields in full, summarize sf fields
    sf_count    := 0
    sf_occupied := 0

    for i in 0 ..< len(vault.meta_arrays[.Field]) {
        meta := vault.meta_arrays[.Field][i]
        if !meta.valid do continue
        field := (^vault.Field)(vault.arrays[.Field][i].data)

        // Screen fields — summarize instead of printing each one
        if meta.name == "sf" {
            sf_count += 1
            // Count any occupied cells at finest level
            grid_size := i32(1) << uint(field.levels)
            total_2d  := grid_size * grid_size
            for idx in 0 ..< total_2d {
                if cell_get(field.bits_any[:], field.levels, i32(idx), field.dims) {
                    sf_occupied += 1
                    break
                }
            }
            continue
        }

        wr.fmt_sbprintf(sb, "  Field[%d] '%s' levels:%d dims:%d\n", i, meta.name, field.levels, field.dims)
        wr.fmt_sbprintf(sb, "    bounds X:[%.4f,%.4f] Y:[%.4f,%.4f] Z:[%.4f,%.4f]\n",
            field.bounds.x.min, field.bounds.x.max,
            field.bounds.y.min, field.bounds.y.max,
            field.bounds.z.min, field.bounds.z.max,
        )
        for level in 0..=field.levels {
            grid_size := i32(1) << uint(level)
            // Dims-aware total cell count
            total := i32(1)
            for _ in 0 ..< field.dims { total *= grid_size }
            occupied := 0
            for idx in 0 ..< total {
                if cell_get(field.bits_any[:], level, i32(idx), field.dims) do occupied += 1
            }
            wr.fmt_sbprintf(sb, "    level %d: %d / %d cells occupied\n", level, occupied, total)
        }
    }

    // Screen field summary
    if sf_count > 0 {
        wr.fmt_sbprintf(sb, "\n  Screen Fields: %d total | %d with occupied cells\n", sf_count, sf_occupied)
        // Print root screen field (first sf) in detail
        for i in 0 ..< len(vault.meta_arrays[.Field]) {
            meta := vault.meta_arrays[.Field][i]
            if !meta.valid || meta.name != "sf" do continue
            field := (^vault.Field)(vault.arrays[.Field][i].data)
            wr.fmt_sbprintf(sb, "  Root SF [%d] levels:%d dims:%d bounds X:[%.0f,%.0f] Y:[%.0f,%.0f]\n",
                i, field.levels, field.dims,
                field.bounds.x.min, field.bounds.x.max,
                field.bounds.y.min, field.bounds.y.max,
            )
            for level in 0..=field.levels {
                grid_size := i32(1) << uint(level)
                total     := grid_size * grid_size  // dims=2
                occupied  := 0
                for idx in 0 ..< total {
                    if cell_get(field.bits_any[:], field.levels, i32(idx), field.dims) do occupied += 1
                }
                wr.fmt_sbprintf(sb, "    level %d: %d / %d\n", level, occupied, total)
            }
            break  // only root
        }
    }
}

debug_toggle_timing :: proc() {
    stats := (^vault.Debug_Stats)(data.edit(vault.debug_stats))
    stats.timing_enabled = !stats.timing_enabled
}

debug_write_image :: proc(pixels: []u8, width, height: int) {
    stats    := (^vault.Debug_Stats)(data.edit(vault.debug_stats))
    snapshot := debug_build_snapshot(stats)
    frame_write_to_image(snapshot)
}


debug_print :: proc(data: any) {
    wr.fmt_println("Showcasing: ", data)
}

debug_time_input   :: proc(t: f64) { (^vault.Debug_Stats)(data.edit(vault.debug_stats)).input_time   = t }
debug_time_pixels  :: proc(t: f64) { (^vault.Debug_Stats)(data.edit(vault.debug_stats)).pixel_time   = t }
debug_time_texture :: proc(t: f64) { (^vault.Debug_Stats)(data.edit(vault.debug_stats)).texture_time = t }

clear_screen    :: proc() { wr.fmt_print("\e[3J\e8") }
save_screen_pos :: proc() { wr.fmt_print("\e7", flush = false) }