package testing

import data "../_data"

import "core:os"
import "core:fmt"
import fp "core:path/filepath"
import stbi "vendor:stb/image"
import "core:strings"

debug_log_save :: proc(data_to_store: string, name: string) {
    filedir, _  := fp.join({data.LOG_PATH, "text/"}, context.allocator)
    file_path, _ := fp.join({filedir, name}, context.allocator)
    os.make_directory(data.LOG_PATH)
    os.make_directory(filedir)
    ok := os.write_entire_file(file_path, data_to_store)
    fmt.println(file_path, ok)
}

frame_write_to_image :: proc() {
    @(static) frame_number := 0

    os.make_directory(data.OUTPUT_DIR)

    for {
        filename := fmt.tprintf("%sframe_%04d.png", data.OUTPUT_DIR, frame_number)
        if !os.exists(filename) {
            stbi.write_png(
                cstring(raw_data(filename)),
                i32(data.SCREEN_WIDTH),
                i32(data.SCREEN_HEIGHT),
                3,
                raw_data(data.frame_pixels),
                i32(data.SCREEN_WIDTH * 3),
            )
            debug_log_save(strings.to_string(data.LOG_BOARD), fmt.aprintf("%v", frame_number))
            frame_number += 1
            break
        }
        frame_number += 1
    }
}
