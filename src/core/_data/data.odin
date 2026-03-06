package data

import "core:time"
import "core:strings"
import math "core:math/linalg/glsl"

APP_CLOSED := false

APP_TIME:   i64 = 0.0
FRAME_TIME: i64 = 0.0

FPS            := 0
DEBUG_TIME     := 2.0
DEBUG_LAST_TIME := 0.0

// Window constants
WINDOW_WIDTH_PERCENT  :: 0.7
WINDOW_HEIGHT_PERCENT :: 0.8
WINDOW_TITLE          :: "Compute Engine"

CAM_POS:   math.vec3
CAM_SPEED :: 0.1

FRAME_DATA: FrameData = {
    frame_count   = 0,
    previous_time = 0,
    FRAME_TITLE   = WINDOW_TITLE,
}

// Demo models, uncomment the target one
MODEL_PATH :: "assets/ABeautifulGame.glb"
//MODEL_PATH :: "assets/kenny_blaster/blaster-e.glb"
//MODEL_PATH :: "assets/1mSphere.glb"
LOG_PATH :: "./debug/"

// TODO: move to model handling system
SCALE_FACTOR :: 10.0

FOV           :: 60
CULLING_RANGE :: 300.0

// Shader constants
COMPUTE_SHADER_PATH :: "test_compute.glsl"

LOG_BOARD: strings.Builder

// TEMPORARY: screen resolution, will move to proper render state
SCREEN_WIDTH:  int = 1280
SCREEN_HEIGHT: int = 720

// OLD - flat grid system, replaced by Field
// CELLS: [dynamic]Grid_Key
// DEPRACATED_WORLD_SIZE: i32 = 100
// CELL_SIZE: i32 = 1
// WORLD_SIZE: i32 = 1000
// Cell :: struct { Children_exist: bool, Children: []int }
// Grid_Key :: struct { keys: [dynamic]i32, closest: [dynamic]i32, Average: Vertex }
// VERTICIES_RAW: []Vertex
// MODEL_INITIALIZED: bool = false
// MODEL_DATA: Model_Data
// MODEL_CENTER: math.vec3
// xs: []Sorted_Axis
// ys: []Sorted_Axis
// zs: []Sorted_Axis
// WORLD_BITFIELD: Mipmap_Bitfield
// Mipmap_Bitfield :: struct { bits: [dynamic]u32, transbits: [dynamic]u32 }
// Sorted_Axis :: struct { value: f32, index: int }

// Vertex — kept as intermediary for cgltf loading, feeds into DataPoint
Vertex :: struct {
    pos:    math.vec3,
    normal: math.vec3,
    fov:    f32,
}

// OLD - superseded by DataPoint + Field
// Model_Data :: struct { VERTICES: []Vertex, BOUNDS: Bounds, MAX_RADIUS: f32 }

// Render state — kept for OpenGL pipeline (not yet active)
Render_State :: struct {
    ssbo:            u32,
    output_texture:  u32,
    compute_program: u32,
    display_program: u32,
    vao:             u32,
    window_width:    i32,
    window_height:   i32,
}

FrameData :: struct {
    frame_count:   int,
    previous_time: f64,
    FRAME_TITLE:   cstring,
}

Bounds :: struct {
    x: Range,
    y: Range,
    z: Range,
}

Range :: struct {
    min: f32,
    max: f32,
}