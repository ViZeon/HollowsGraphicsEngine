package testing

import data "../_data"
import "core:os"
import "core:fmt"
import fp "core:path/filepath"
import stbi "vendor:stb/image"
import "core:strings"

debug_log_save :: proc(data_to_store: string, name: string) {
    log_path := string((^cstring)(get(data.log_path))^)
    filedir, _   := fp.join({log_path, "text/"}, context.allocator)
    file_path, _ := fp.join({filedir, name}, context.allocator)
    os.make_directory(log_path)
    os.make_directory(filedir)
    ok := os.write_entire_file(file_path, data_to_store)
    fmt.println(file_path, ok)
}

frame_write_to_image :: proc() {
    @(static) frame_number := 0

    output_dir := string((^cstring)(get(data.output_dir))^)
    screen_w   := (^int)(get(data.screen_width))^
    screen_h   := (^int)(get(data.screen_height))^
    lb         := (^strings.Builder)(get(data.log_board))

    os.make_directory(output_dir)

    for {
        filename := fmt.tprintf("%sframe_%04d.png", output_dir, frame_number)
        if !os.exists(filename) {
            stbi.write_png(
                cstring(raw_data(filename)),
                i32(screen_w), i32(screen_h), 3,
                raw_data(data.frame_pixels),
                i32(screen_w * 3),
            )
            debug_log_save(strings.to_string(lb^), fmt.aprintf("%v", frame_number))
            frame_number += 1
            break
        }
        frame_number += 1
    }
}