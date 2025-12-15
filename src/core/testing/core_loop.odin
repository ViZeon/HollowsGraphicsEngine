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
    debug_init()  // ← Initialize debug system
    
    model_load_realtime()
    sort_by_axis(&data.MODEL_DATA.VERTICES, &data.xs, &data.ys, &data.zs)
    
    fmt.println("Vertex count after loading:", len(data.VERTICIES_RAW))
    
    // Calculate FOV for each vertex
    for i in 0..<len(data.MODEL_DATA.VERTICES) {
        vert_pos := data.MODEL_DATA.VERTICES[i]
        dist := f32(math_lin.distance(math.vec3{0,0,0}, math.vec3(vert_pos.pos)))
        fov := 2.0 * math.atan_f32(dist / 2.0)
        data.MODEL_DATA.VERTICES[i].fov = fov
    }
    
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
cpu_fragment_shader :: proc(pixel_coords: math.vec2) -> (PIXEL: math.ivec4) {
    uv := math.vec3{
        pixel_coords.x / f32(width),
        pixel_coords.y / f32(height),
        0
    }
    
    PIXEL_SHIFT := data.CULLING_RANGE * FOV_DISTANCE
    PIXEL_FOV_COORDS := math.vec3{
        uv.x * PIXEL_SHIFT + data.CAM_POS.x, 
        uv.y * PIXEL_SHIFT + data.CAM_POS.y,
        0.0 + data.CAM_POS.z
    }
    
    vertex : data.Vertex
    range_base := math.ivec2{0, i32(len(data.MODEL_DATA.VERTICES))}
    
    range_x := binary_search_insert(0, &data.MODEL_DATA.VERTICES, PIXEL_FOV_COORDS.x, range_base.x, range_base.y)
    range_y := binary_search_insert(1, &data.MODEL_DATA.VERTICES, PIXEL_FOV_COORDS.y, range_x.x, range_x.y)
    
    // Record debug stats
    range_size := range_y.y - range_y.x
    debug_record_pixel_search(range_size)
    
    z_vert_ID : int
    left := range_y.x
    right := range_y.y
    z_dist : f32 = data.CULLING_RANGE
    
    // Linear search through filtered vertices
    for i in left..< right {
        if distance(data.MODEL_DATA.VERTICES[i].pos, PIXEL_FOV_COORDS) < z_dist {
            z_dist = distance(data.MODEL_DATA.VERTICES[i].pos, PIXEL_FOV_COORDS)
            z_vert_ID = int(i)
        }
    }
    
    vertex = data.MODEL_DATA.VERTICES[z_vert_ID]
    
    // Camera facing direction (down -Z axis)
    camera_dir := math.vec3{0, 0, -1}
    dot_product := math.dot(vertex.normal, camera_dir)
    grayscale := math.max(0, dot_product)
    
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
    data.MODEL_DATA.VERTICES = process_vertices(&data.VERTICIES_RAW, data.SCALE_FACTOR)
    
    fmt.println("model initialized")
    data.MODEL_INITIALIZED = true
}