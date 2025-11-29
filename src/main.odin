package main

//import "core:imports/imports_vendor"
//import "core:imports/imports_local"
import data "core/data"
import window "core/modules/window"
import model "core/modules/model"
import render "core/modules/render"
import testing "core/testing"
import "vendor:glfw"

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
        render.frame_render(&window_handle, &model_data, &render_state)

        data.FRAME_DATA = window.title_display_FPS(data.FRAME_DATA, data.WINDOW_TITLE, &window_handle)
    }
}