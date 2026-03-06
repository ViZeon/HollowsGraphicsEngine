package testing

import data "../data"

import "core:os"
import "core:fmt"
import fp "core:path/filepath"
import stbi "vendor:stb/image"
import "core:strings"


debug_log_save :: proc (data_to_store:string, name:string) {
	
	filedir, _ := fp.join({data.LOG_PATH,"text/"}, context.allocator)
	file_path, _ := fp.join({filedir,name}, context.allocator)
	err := os.make_directory(data.LOG_PATH)
	err1 := os.make_directory(filedir)
	//file, err := os.open(file_path, os.O_WRONLY, 0o777)
	//defer os.close(file)

	//fmt.fprintln(file, data_to_store)

	fmt.println(file_path)
	
	ok := os.write_entire_file(file_path, data_to_store)
	fmt.println(ok, err)
}

frame_write_to_image :: proc() {
	@(static) frame_number := 0 // ← Make this static so it persists

	// Create directory if it doesn't exist
	os.make_directory(output_dir)

	// Find next available number
	for {
		filename := fmt.tprintf("%sframe_%04d.png", output_dir, frame_number)
		if !os.exists(filename) {
			stbi.write_png(
				cstring(raw_data(filename)),
				i32(data.SCREEN_WIDTH),
				i32(data.SCREEN_HEIGHT),
				3,
				raw_data(frame_pixels),
				i32(data.SCREEN_WIDTH * 3),
			)
			debug_log_save(strings.to_string(data.LOG_BOARD), fmt.aprintf("%v",frame_number))
			//fmt.printf("Wrote %s\n", filename)
			//fmt.println(fmt.aprintf("%v",frame_number))

			frame_number += 1 // ← Increment for next call
			break
		}
		frame_number += 1
	}
}
