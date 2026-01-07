package testing

import data "../data"

import "core:os"
import os2 "core:os/os2"
import "core:fmt"
import "core:path/filepath"
import stbi "vendor:stb/image"
import "core:strings"


debug_log_save :: proc (data_to_store:string, name:string) {
	
	
	filedir :=	filepath.join({data.LOG_PATH,"text/"})
	filepath := filepath.join({filedir,name})
	err := os.make_directory(data.LOG_PATH)
	err1 := os.make_directory(filedir)
	//file, err := os.open(filepath, os.O_WRONLY, 0o777)
	//defer os.close(file)

	//fmt.fprintln(file, data_to_store)


	fmt.println(filepath)
	
	ok := os2.write_entire_file(filepath, data_to_store)
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
				i32(width),
				i32(height),
				3,
				raw_data(frame_pixels),
				i32(width * 3),
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
