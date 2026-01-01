package data

import "core:time"

import math "core:math/linalg/glsl"

APP_CLOSED := false

APP_TIME : i64 = 0.0
FRAME_TIME : i64 = 0.0

FPS := 0
DEBUG_TIME := 2.0
DEBUG_LAST_TIME := 0.0

// Window constants
WINDOW_WIDTH_PERCENT :: 0.7
WINDOW_HEIGHT_PERCENT :: 0.8
WINDOW_TITLE :: "Compute Engine"

CAM_POS: math.vec3 = {-581.8, -224.2, -0.7} // Model is 0 to 3.8 tall, so center Y is 1.9
CAM_SPEED :: 0.1 // Units per frame

FRAME_DATA: FrameData = {
	frame_count   = 0,
	previous_time = 0,
	FRAME_TITLE   = WINDOW_TITLE,
}


// Spatial grid
cells: [dynamic][dynamic][dynamic]Grid_Key

Grid_Key :: struct {
	keys: [dynamic]i32,
	closest: [dynamic]i32
}

// Global spatial grid
//SPATIAL_GRID: Spatial_Grid


// Model constants

VERTICIES_RAW: []Vertex
MODEL_INITIALIZED: bool = false
MODEL_DATA: Model_Data

CACHE_PATH :: "cache/verts.bin"
MODEL_PATH :: "assets/ABeautifulGame.glb"
SCALE_FACTOR :: 50.0
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
	pos:    math.vec3,
	normal: math.vec3,
	fov:    f32,
}

// Model data
Model_Data :: struct {
	VERTICES:   []Vertex,
	BOUNDS:     Bounds,
	MAX_RADIUS: f32,
}

// Render state
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
