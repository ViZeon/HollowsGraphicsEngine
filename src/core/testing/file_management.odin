package testing

import vault "../../core/_vault"
import data  "../modules/data"
import "core:os"
import "core:fmt"
import "core:strings"
import fp   "core:path/filepath"
import stbi "vendor:stb/image"

// Call at startup — scans debug/ for existing sessions, creates next numbered folder,
// updates all debug path handles to point into it
session_init :: proc() {
    base := "./debug"
    os.make_directory(base)

    // Find next session number
    session_num := 1
    for {
        path := fmt.tprintf("%s/session_%04d", base, session_num)
        if !os.exists(path) do break
        session_num += 1
    }

    session_root := fmt.tprintf("%s/session_%04d", base, session_num)
    os.make_directory(session_root)
    os.make_directory(fmt.tprintf("%s/text",   session_root))
    os.make_directory(fmt.tprintf("%s/images", session_root))

    // Update all debug path handles to point into this session
    log_root     := fmt.tprintf("%s/",         session_root)
    images_dir   := fmt.tprintf("%s/images/",  session_root)
    session_log  := fmt.tprintf("%s/session.log", session_root)

    (^cstring)(data.edit(vault.log_path))^         = strings.clone_to_cstring(log_root)
    (^cstring)(data.edit(vault.output_dir))^       = strings.clone_to_cstring(images_dir)
    (^cstring)(data.edit(vault.session_log_path))^ = strings.clone_to_cstring(session_log)

    fmt.println("Session:", session_root)
}

// Appends a snapshot to the running session log
session_log_append :: proc(snapshot: string) {
    session_path := string((^cstring)(data.edit(vault.session_log_path))^)
    flags        := os.O_WRONLY | os.O_CREATE | os.O_APPEND
    fd, err      := os.open(session_path, flags, os.perm_number(0o644))
    if err != os.ERROR_NONE do return
    defer os.close(fd)
    os.write_string(fd, snapshot)
    os.write_string(fd, "\n---\n")
}

// Writes a named snapshot txt to session text/
debug_log_save :: proc(content: string, name: string) {
    log_path     := string((^cstring)(data.edit(vault.log_path))^)
    filedir, _   := fp.join({log_path, "text/"}, context.allocator)
    file_path, _ := fp.join({filedir, name},     context.allocator)
    _ = os.write_entire_file(file_path, transmute([]byte)content)
}

// Writes current frame pixels to a sequentially numbered PNG
// and saves an optional log snapshot alongside it
frame_write_to_image :: proc(log_snapshot: string = "") {
    @(static) frame_number := 0

    output_dir := string((^cstring)(data.edit(vault.output_dir))^)
    screen_w   := (^int)(data.edit(vault.screen_width))^
    screen_h   := (^int)(data.edit(vault.screen_height))^

    for {
        filename := fmt.tprintf("%sframe_%04d.png", output_dir, frame_number)
        if !os.exists(filename) {
            stbi.write_png(
                cstring(raw_data(filename)),
                i32(screen_w), i32(screen_h), 3,
                raw_data(vault.frame_pixels),
                i32(screen_w * 3),
            )
            if log_snapshot != "" {
                debug_log_save(log_snapshot, fmt.tprintf("%04d.txt", frame_number))
            }
            frame_number += 1
            break
        }
        frame_number += 1
    }
}
