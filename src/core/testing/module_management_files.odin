package testing

import vault "../../core/_vault"
import data  "../modules/data"
import wr "../_wrappers"

// Call at startup — scans debug/ for existing sessions, creates next numbered folder,
// updates all debug path handles to point into it
session_init :: proc() {
    base := "./debug"
    wr.os_make_directory(base)

    // Find next session number
    session_num := 1
    for {
        path := wr.fmt_tprintf("%s/session_%04d", base, session_num)
        if !wr.os_exists(path) do break
        session_num += 1
    }

    session_root := wr.fmt_tprintf("%s/session_%04d", base, session_num)
    wr.os_make_directory(session_root)
    wr.os_make_directory(wr.fmt_tprintf("%s/text",   session_root))
    wr.os_make_directory(wr.fmt_tprintf("%s/images", session_root))

    // Update all debug path handles to point into this session
    log_root     := wr.fmt_tprintf("%s/",         session_root)
    images_dir   := wr.fmt_tprintf("%s/images/",  session_root)
    session_log  := wr.fmt_tprintf("%s/session.log", session_root)

    (^cstring)(data.edit(vault.log_path))^         = wr.strings_clone_to_cstring(log_root)
    (^cstring)(data.edit(vault.output_dir))^       = wr.strings_clone_to_cstring(images_dir)
    (^cstring)(data.edit(vault.session_log_path))^ = wr.strings_clone_to_cstring(session_log)

    wr.fmt_println("Session:", session_root)
}

// Appends a snapshot to the running session log
session_log_append :: proc(snapshot: string) {
    session_path := string((^cstring)(data.edit(vault.session_log_path))^)
    flags        := wr.OS_O_WRONLY | wr.OS_O_CREATE | wr.OS_O_APPEND
    fd, err      := wr.os_open(session_path, flags, wr.OS_perm_number(0o644))
    if err != wr.OS_ERROR_NONE do return
    defer wr.os_close(fd)
    wr.os_write_string(fd, snapshot)
    wr.os_write_string(fd, "\n---\n")
}

// Writes a named snapshot txt to session text/
debug_log_save :: proc(content: string, name: string) {
    log_path     := string((^cstring)(data.edit(vault.log_path))^)
    filedir, _   := wr.path_join({log_path, "text/"}, context.allocator)
    file_path, _ := wr.path_join({filedir, name},     context.allocator)
    _ = wr.os_write_entire_file(file_path, transmute([]byte)content)
}

// Writes current frame pixels to a sequentially numbered PNG
// and saves an optional log snapshot alongside it
frame_write_to_image :: proc(log_snapshot: string = "") {
    @(static) frame_number := 0

    output_dir := string((^cstring)(data.edit(vault.output_dir))^)
    screen_w   := (^int)(data.edit(vault.screen_width))^
    screen_h   := (^int)(data.edit(vault.screen_height))^

    for {
        filename := wr.fmt_tprintf("%sframe_%04d.png", output_dir, frame_number)
        if !wr.os_exists(filename) {
            wr.stbi_write_png(
                cstring(raw_data(filename)),
                i32(screen_w), i32(screen_h), 3,
                raw_data(screen_tex.source.pixels),
                i32(screen_w * 3),
            )
            if log_snapshot != "" {
                debug_log_save(log_snapshot, wr.fmt_tprintf("%04d.txt", frame_number))
            }
            frame_number += 1
            break
        }
        frame_number += 1
    }
}