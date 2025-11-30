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


import rl "vendor:raylib"

main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(800, 600, "Software Renderer")
    defer rl.CloseWindow()
    
    //rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        // Update title with FPS
        rl.SetWindowTitle(fmt.ctprintf("Software Renderer - FPS: %d", rl.GetFPS()))
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.RED)
        rl.EndDrawing()
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