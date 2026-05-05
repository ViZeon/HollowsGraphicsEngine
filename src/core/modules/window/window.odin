package window

import vault "../../_vault"
import wr "../../_wrappers"

init_window :: proc(width_percent: f32, height_percent: f32, window_title: cstring) -> wr.Window_Handle {
    if !wr.glfw_init() {
        wr.fmt_println("Failed to init GLFW")
        return nil
    }

    monitor := wr.glfw_get_primary_monitor()
    mode    := wr.glfw_get_video_mode(monitor)

    window_width  := i32(f32(mode.width)  * width_percent)
    window_height := i32(f32(mode.height) * height_percent)

    wr.glfw_window_hint(wr.GLFW_CONTEXT_VERSION_MAJOR, 4)
    wr.glfw_window_hint(wr.GLFW_CONTEXT_VERSION_MINOR, 3)
    wr.glfw_window_hint(wr.GLFW_OPENGL_PROFILE, wr.GLFW_OPENGL_CORE_PROFILE)
    wr.glfw_window_hint(wr.GLFW_RESIZABLE, wr.GLFW_TRUE)

    window := wr.glfw_create_window(window_width, window_height, window_title, nil, nil)
    if window == nil {
        wr.fmt_println("Failed to create window")
        return nil
    }

    wr.glfw_make_context_current(window)
    wr.gl_load_up_to(4, 3, wr.glfw_set_proc_address)
    wr.gl_viewport(0, 0, window_width, window_height)

    return window
}

title_display_FPS :: proc(FRAME_DATA: vault.FrameData, window_title: cstring, window: ^wr.Window_Handle) -> (fData: vault.FrameData) {
    FDATA        := FRAME_DATA
    currentTime  := wr.glfw_get_time()
    FDATA.frame_count += 1

    if (currentTime - FDATA.previous_time >= 1.0) {
        frameString  := wr.fmt_tprintf("%s - %d FPS", window_title, FDATA.frame_count)
        frameCString := wr.strings_clone_to_cstring(frameString)
        wr.glfw_set_window_title(window^, frameCString)
        FDATA.frame_count   = 0
        FDATA.previous_time = currentTime
    }

    return FDATA
}