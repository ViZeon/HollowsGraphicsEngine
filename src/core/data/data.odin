package data

// Window constants
WINDOW_WIDTH_PERCENT :: 0.7
WINDOW_HEIGHT_PERCENT :: 0.8

// Model constants
MODEL_PATH :: "assets/ABeautifulGame.glb"
SCALE_FACTOR :: 100.0

// Shader constants
COMPUTE_SHADER_PATH :: "test_compute.glsl"

// Vertex structure
Vertex :: struct {
    x, y, z: f32,
    x_cell, y_cell: i32,
    _pad: i32,
}

// Model data
Model_Data :: struct {
    vertices: []Vertex,
    vertex_count: int,
    min_z: f32,
    max_z: f32,
    world_min_x: f32,
    world_max_x: f32,
    world_min_y: f32,
    world_max_y: f32,
}

// Render state
Render_State :: struct {
    ssbo: u32,
    output_texture: u32,
    compute_program: u32,
    display_program: u32,
    vao: u32,
    window_width: i32,
    window_height: i32,
}