package window

import "../../imports/imports_vendor"
import "core:fmt"
import "vendor:glfw"
import gl "vendor:OpenGL"

init_window :: proc(width_percent: f32, height_percent: f32) -> glfw.WindowHandle {
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
    
    window := glfw.CreateWindow(window_width, window_height, "Compute Engine", nil, nil)
    if window == nil {
        fmt.println("Failed to create window")
        return nil
    }
    
    glfw.MakeContextCurrent(window)
    gl.load_up_to(4, 3, glfw.gl_set_proc_address)
    gl.Viewport(0, 0, window_width, window_height)
    
    return window
}