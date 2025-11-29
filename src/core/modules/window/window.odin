package window

import "../../imports/imports_vendor"
import "../../data"
import "core:fmt"
import "core:strings"
import os "core:os"
import "core:strconv" 
import "vendor:glfw"
import gl "vendor:OpenGL"



init_window :: proc(width_percent: f32, height_percent: f32, window_title: cstring) -> glfw.WindowHandle {
    if !glfw.Init() {
        fmt.println("Failed to init GLFW")
        return nil
    }

    monitor := glfw.GetPrimaryMonitor()
    mode := glfw.GetVideoMode(monitor)
    
    window_width := i32(f32(mode.width) * width_percent)
    window_height := i32(f32(mode.height) * height_percent)

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
    
    window := glfw.CreateWindow(window_width, window_height, window_title, nil, nil)
    if window == nil {
        fmt.println("Failed to create window")
        return nil
    }
    
    glfw.MakeContextCurrent(window)
    gl.load_up_to(4, 3, glfw.gl_set_proc_address)
    gl.Viewport(0, 0, window_width, window_height)
    
    return window
}
title_display_FPS :: proc (FRAME_DATA: data.FrameData, window_title: cstring, window: ^glfw.WindowHandle) -> (fData: data.FrameData) {
    // Measure speed
    FDATA := FRAME_DATA
    currentTime := glfw.GetTime();
    FDATA.frame_count += 1;
    
    // If a second has passed.
    if (currentTime - FDATA.previous_time >= 1.0) {
        frameString: string = fmt.tprintf("%s - %d FPS", window_title, FDATA.frame_count)
        frameCString := strings.clone_to_cstring(frameString)
        glfw.SetWindowTitle(window^, frameCString)
        
        FDATA.frame_count = 0;
        FDATA.previous_time = currentTime;  // ← Add this line!
    }
    
    return FDATA;
}