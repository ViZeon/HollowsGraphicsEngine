package testing

import rl "vendor:raylib"
import stbi "vendor:stb/image"
import math "core:math/linalg/glsl"
import math_lin "core:math/linalg"

import model "../modules/model"
import data "../data"

import "core:os"
import "core:fmt"


SORTED_VERTS : []data.Vertex
closest_vert : data.Vertex

FOV_DISTANCE : f32 = 2.00 * f32(math_lin.tan(data.FOV/2.0))
fov : f32

//called once before render loop
raylib_start_functions :: proc() {
       debug_init()
    
    model_load_realtime()
    
    // Print model bounds to understand scale
    fmt.println("\n=== MODEL BOUNDS ===")
    min_pos := math.vec3{max(f32), max(f32), max(f32)}
    max_pos := math.vec3{min(f32), min(f32), min(f32)}
    
    for v in data.MODEL_DATA.VERTICES {
        min_pos.x = min(min_pos.x, v.pos.x)
        min_pos.y = min(min_pos.y, v.pos.y)
        min_pos.z = min(min_pos.z, v.pos.z)
        max_pos.x = max(max_pos.x, v.pos.x)
        max_pos.y = max(max_pos.y, v.pos.y)
        max_pos.z = max(max_pos.z, v.pos.z)
    }
    
    fmt.printf("Min: [%.1f, %.1f, %.1f]\n", min_pos.x, min_pos.y, min_pos.z)
    fmt.printf("Max: [%.1f, %.1f, %.1f]\n", max_pos.x, max_pos.y, max_pos.z)
    model_size := max_pos - min_pos
    fmt.printf("Size: [%.1f, %.1f, %.1f]\n", model_size.x, model_size.y, model_size.z)
    
    // Choose cell size based on model size
    // Rule of thumb: cell_size = model_size / 100 to 200
    max_dimension := max(model_size.x, max(model_size.y, model_size.z))
    suggested_cell_size := max_dimension / 100.0
    fmt.printf("Suggested cell_size: %.2f\n", suggested_cell_size)
    fmt.println("====================\n")
    
    // Build with appropriate cell size
    data.SPATIAL_GRID = build_spatial_grid(data.MODEL_DATA.VERTICES, suggested_cell_size)
       
    fmt.println("Vertex count after loading:", len(data.VERTICIES_RAW))
    
    // Calculate FOV for each vertex
    for i in 0..<len(data.MODEL_DATA.VERTICES) {
        vert_pos := data.MODEL_DATA.VERTICES[i]
        dist := f32(math_lin.distance(math.vec3{0,0,0}, math.vec3(vert_pos.pos)))
        fov := 2.0 * math.atan_f32(dist / 2.0)
        data.MODEL_DATA.VERTICES[i].fov = fov
    }

    // Print first few vertices to see actual positions
fmt.println("\n=== SAMPLE VERTICES ===")
for i in 0..<min(5, len(data.MODEL_DATA.VERTICES)) {
    v := data.MODEL_DATA.VERTICES[i]
    fmt.printf("Vertex %d: pos=[%.2f, %.2f, %.2f]\n", i, v.pos.x, v.pos.y, v.pos.z)
}
fmt.println("=======================\n")
    
    // Initialize pixel buffer
    frame_pixels = make([]u8, width * height * 3)
    
    // Generate initial frame
    generate_pixels_inplace(frame_pixels, width, height)
    
    // Write first frame
    frame_write_to_image()
    
    // Create texture
    raylib_render_frame()
}

//called once per frame
raylib_update_functions :: proc() {
    debug_frame_begin()  // ← Reset per-frame counters
    
    // Camera controls with timing
    start_input := rl.GetTime()
    handle_camera_input()
    debug_time_input(rl.GetTime() - start_input)
    
    // Pixel generation with timing
    start_pixels := rl.GetTime()
    generate_pixels_inplace(frame_pixels, width, height)
    debug_time_pixels(rl.GetTime() - start_pixels)
    
    // Texture update with timing
    start_texture := rl.GetTime()
    rl.UpdateTexture(texture, raw_data(frame_pixels))
    debug_time_texture(rl.GetTime() - start_texture)
    
    // Draw
    if texture.id != 0 {
        rl.DrawTexture(texture, 0, 0, rl.WHITE)
    } else {
        fmt.println("Texture not loaded!")
    }
    
    // Debug overlay (optional, press F1)
    debug_draw_overlay()
    
    // Debug frame capture
    if rl.IsKeyPressed(.F12) {
        debug_write_image(frame_pixels, width, height)
    }
    
    debug_frame_end()  // ← Print stats periodically
}

//called once per pixel
// In your cpu_fragment_shader:
cpu_fragment_shader :: proc(pixel_coords: math.vec2) -> (PIXEL: math.ivec4) {
    // Orthographic projection that matches model size
    uv := math.vec2{
        pixel_coords.x / f32(width),
        pixel_coords.y / f32(height),
    }
    
    // Model is 1.4 wide, 3.8 tall
    // View size should be slightly larger than model
    view_size := f32(5.0)  // Show 5 units
    
    world_pos := math.vec3{
        data.CAM_POS.x,  // Camera depth
        (uv.x - 0.5) * view_size,  // Screen X -> World Y (centered)
        (uv.y - 0.5) * view_size,  // Screen Y -> World Z (centered)
    }
    
    vertex_idx, vertices_checked := query_spatial_grid(
        &data.SPATIAL_GRID,
        world_pos,
        data.MODEL_DATA.VERTICES,
    )
    
    debug_record_pixel_search(i32(vertices_checked))
    
    if vertex_idx == -1 {
        return math.ivec4{0, 0, 0, 255}  // Black background
    }
    
    vertex := data.MODEL_DATA.VERTICES[vertex_idx]
    
    // Simple lighting
    light_dir := math.vec3{-1, 0, 0}
    dot_product := math.dot(vertex.normal, light_dir)
    grayscale := (dot_product + 1.0) * 0.5
    
    return math.ivec4{i32(grayscale * 255), 0, 0, 255}
}
handle_camera_input :: proc() {
    dt := rl.GetFrameTime()
    move_speed := data.CAM_SPEED * dt * 60.0
    
    // Faster movement with shift
    if rl.IsKeyDown(.LEFT_SHIFT) {
        move_speed *= 3.0
    }
    
    // WASD movement
    if rl.IsKeyDown(.W) do data.CAM_POS.y += move_speed
    if rl.IsKeyDown(.S) do data.CAM_POS.y -= move_speed
    if rl.IsKeyDown(.A) do data.CAM_POS.x -= move_speed
    if rl.IsKeyDown(.D) do data.CAM_POS.x += move_speed
    
    // Q/E for Z axis
    if rl.IsKeyDown(.Q) do data.CAM_POS.z -= move_speed
    if rl.IsKeyDown(.E) do data.CAM_POS.z += move_speed
}

model_load_realtime :: proc() {
    data.VERTICIES_RAW, data.MODEL_INITIALIZED = model.load_model(data.MODEL_PATH)
    data.MODEL_DATA.VERTICES = process_vertices(&data.VERTICIES_RAW, 1.0)  // Already scaled
    
    fmt.println("model initialized")
    data.MODEL_INITIALIZED = true
}