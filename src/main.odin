package main

//import "core:imports/imports_vendor"
//import "core:imports/imports_local"
import data "core/data"
import window "core/modules/window"
import model "core/modules/model"
import render "core/modules/render"
import testing "core/testing"
import "vendor:glfw"
import "core:fmt"
import "core:strings"


import "core:sys/windows"
import "base:runtime"

// Global state
g_running: bool = true
g_width: i32 = 800
g_height: i32 = 600
g_pixels: []u32

WindowProc :: proc "stdcall" (hwnd: windows.HWND, msg: u32, wparam: windows.WPARAM, lparam: windows.LPARAM) -> windows.LRESULT {
    context = runtime.default_context()
    
    switch msg {
    case windows.WM_CLOSE, windows.WM_DESTROY:
        g_running = false
        windows.PostQuitMessage(0)
        return 0
        
    case windows.WM_SIZE:
        g_width = i32(lparam & 0xFFFF)
        g_height = i32((lparam >> 16) & 0xFFFF)
        delete(g_pixels)
        g_pixels = make([]u32, g_width * g_height)
        return 0
        
    case windows.WM_KEYDOWN:
        if wparam == windows.VK_ESCAPE {
            g_running = false
        }
        return 0
    }
    
    return windows.DefWindowProcW(hwnd, msg, wparam, lparam)
}

main :: proc() {
    instance := windows.HINSTANCE(windows.GetModuleHandleW(nil))
    
    wc := windows.WNDCLASSEXW{
        cbSize = size_of(windows.WNDCLASSEXW),
        style = windows.CS_HREDRAW | windows.CS_VREDRAW | windows.CS_OWNDC,
        lpfnWndProc = WindowProc,
        hInstance = instance,
        hCursor = windows.LoadCursorW(nil, transmute(windows.wstring)windows.IDC_ARROW),
        lpszClassName = windows.utf8_to_wstring("SoftwareRendererClass"),
    }
    
    if windows.RegisterClassExW(&wc) == 0 {
        fmt.println("Failed to register window class")
        return
    }
    
    hwnd := windows.CreateWindowExW(
        0,
        wc.lpszClassName,
        windows.utf8_to_wstring("Software Renderer"),
        windows.WS_OVERLAPPEDWINDOW | windows.WS_VISIBLE,
        windows.CW_USEDEFAULT, windows.CW_USEDEFAULT,
        g_width, g_height,
        nil, nil, instance, nil,
    )
    
    if hwnd == nil {
        fmt.println("Failed to create window")
        return
    }
    
    g_pixels = make([]u32, g_width * g_height)
    defer delete(g_pixels)
    
    hdc := windows.GetDC(hwnd)
    defer windows.ReleaseDC(hwnd, hdc)
    
    // Main loop
    frame_count := 0
    start_time := u64(windows.timeGetTime())
    
    for g_running {
        // Process messages
        msg: windows.MSG
        for windows.PeekMessageW(&msg, nil, 0, 0, windows.PM_REMOVE) {
            windows.TranslateMessage(&msg)
            windows.DispatchMessageW(&msg)
        }
        
        // Software render - fill with red
        for i in 0..<len(g_pixels) {
            g_pixels[i] = 0xFF0000FF // RGBA: Red
        }
        
        // Blit to window using DIB
        bmi := windows.BITMAPINFO{
            bmiHeader = windows.BITMAPINFOHEADER{
                biSize = size_of(windows.BITMAPINFOHEADER),
                biWidth = g_width,
                biHeight = -g_height, // Negative for top-down
                biPlanes = 1,
                biBitCount = 32,
                biCompression = windows.BI_RGB,
            },
        }
        
        windows.StretchDIBits(
            hdc,
            0, 0, g_width, g_height,
            0, 0, g_width, g_height,
            raw_data(g_pixels),
            &bmi,
            windows.DIB_RGB_COLORS,
            windows.SRCCOPY,
        )
        
        // FPS counter
        frame_count += 1
        current_time := u64(windows.timeGetTime())
        if current_time - start_time >= 1000 {
            fps := f64(frame_count) / f64(current_time - start_time) * 1000.0
            title := fmt.tprintf("Software Renderer - FPS: %.0f\x00", fps)
            windows.SetWindowTextW(hwnd, windows.utf8_to_wstring(title))
            frame_count = 0
            start_time = current_time
        }
    }
}
/*
main :: proc() {
    window_handle := window.init_window(data.WINDOW_WIDTH_PERCENT, data.WINDOW_HEIGHT_PERCENT, data.WINDOW_TITLE)
    defer glfw.Terminate()
    defer glfw.DestroyWindow(window_handle)
    
    raw_vertices, vertex_count, ok := model.load_model(data.MODEL_PATH)
    if !ok {
        return
    }
    defer delete(raw_vertices)
    
    model_data := testing.process_vertices(raw_vertices, vertex_count, data.SCALE_FACTOR)
    defer delete(model_data.vertices)
    
    render_state := render.init_render(window_handle, model_data)
    
    for !glfw.WindowShouldClose(window_handle) {
        //render.frame_render(&window_handle, &model_data, &render_state)

        data.FRAME_DATA = window.title_display_FPS(data.FRAME_DATA, data.WINDOW_TITLE, &window_handle)
    }
}
*/
title_display_FPS :: proc (FRAME_DATA: data.FrameData, window_title: cstring) -> (fData: data.FrameData) {
    // Measure speed
    FDATA := FRAME_DATA
    currentTime := glfw.GetTime();
    FDATA.frame_count += 1;
    
    // If a second has passed.
    if (currentTime - FDATA.previous_time >= 1.0) {
        frameString: string = fmt.tprintf("%s - %d FPS", window_title, FDATA.frame_count)
        frameCString := strings.clone_to_cstring(frameString)
        FDATA.FRAME_TITLE = frameCString
        
        FDATA.frame_count = 0;
        FDATA.previous_time = currentTime;  // ← Add this line!
    }
    
    return FDATA;
}