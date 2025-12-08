package data


import math "core:math/linalg/glsl"

// Window constants
WINDOW_WIDTH_PERCENT :: 0.7
WINDOW_HEIGHT_PERCENT :: 0.8
WINDOW_TITLE :: "Compute Engine"

FRAME_DATA : FrameData ={
        frame_count= 0,
    previous_time= 0, 
    FRAME_TITLE = WINDOW_TITLE
}

// Model constants

VERTICIES_RAW: []math.vec3
MODEL_INITIALIZED: bool = false
MODEL_DATA: Model_Data


MODEL_PATH :: "assets/ABeautifulGame.glb"
SCALE_FACTOR :: 300.0
FOV :: 120
CULLING_RANGE :: 300.0

// Shader constants
COMPUTE_SHADER_PATH :: "test_compute.glsl"


// Create arrays
xs: []Sorted_Axis 
ys: []Sorted_Axis
zs: []Sorted_Axis









// Each entry holds the value and the original index
Sorted_Axis :: struct {
    value: f32,
    index: int,
}

// Vertex structure
Vertex :: struct {
    pos: math.vec3,
    fov: f32
}

// Model data
Model_Data :: struct {
    VERTICES: []Vertex,
    BOUNDS : Bounds
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

FrameData :: struct {
    frame_count : int,
    previous_time : f64,
    FRAME_TITLE :cstring
}

Bounds :: struct {
    x : Range,
    y : Range,
    z : Range
}

Range :: struct {
    min : int,
    max : int
}