package data


import math "core:math/linalg/glsl"

// Window constants
WINDOW_WIDTH_PERCENT :: 0.7
WINDOW_HEIGHT_PERCENT :: 0.8
WINDOW_TITLE :: "Compute Engine"

CAM_POS : math.vec3 = {-5, 1.9, 0}  // Model is 0 to 3.8 tall, so center Y is 1.9
CAM_SPEED :: 2.0  // Units per frame

FRAME_DATA : FrameData ={
        frame_count= 0,
    previous_time= 0, 
    FRAME_TITLE = WINDOW_TITLE
}



// Spatial grid 
cells: [dynamic][dynamic][dynamic]Grid_Key

Grid_Key :: struct {
    keys: [dynamic]i32,
}

// Global spatial grid
//SPATIAL_GRID: Spatial_Grid


// Model constants

VERTICIES_RAW: []Vertex
MODEL_INITIALIZED: bool = false
MODEL_DATA: Model_Data


MODEL_PATH :: "assets/ABeautifulGame.glb"
SCALE_FACTOR :: 10.0
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
    normal: math.vec3,
    fov: f32
}

// Model data
Model_Data :: struct {
    VERTICES: []Vertex,
    BOUNDS : Bounds,
    MAX_RADIUS: f32
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
    min : f32,
    max : f32
}