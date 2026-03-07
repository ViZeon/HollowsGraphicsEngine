package data

import math "core:math/linalg/glsl"
import "core:strings"

// Primitives
bool_Direct:      [dynamic]bool
bool_Direct_meta: [dynamic]Metadata
bool_Direct_free: [dynamic]int

int_Direct:      [dynamic]int
int_Direct_meta: [dynamic]Metadata
int_Direct_free: [dynamic]int

i32_Direct:      [dynamic]i32
i32_Direct_meta: [dynamic]Metadata
i32_Direct_free: [dynamic]int

i64_Direct:      [dynamic]i64
i64_Direct_meta: [dynamic]Metadata
i64_Direct_free: [dynamic]int

f32_Direct:      [dynamic]f32
f32_Direct_meta: [dynamic]Metadata
f32_Direct_free: [dynamic]int

f64_Direct:      [dynamic]f64
f64_Direct_meta: [dynamic]Metadata
f64_Direct_free: [dynamic]int

u32_Direct:      [dynamic]u32
u32_Direct_meta: [dynamic]Metadata
u32_Direct_free: [dynamic]int

cstring_Direct:      [dynamic]cstring
cstring_Direct_meta: [dynamic]Metadata
cstring_Direct_free: [dynamic]int

vec3_Direct:      [dynamic]math.vec3
vec3_Direct_meta: [dynamic]Metadata
vec3_Direct_free: [dynamic]int

// Engine types
vertex_Direct:      [dynamic]Vertex
vertex_Direct_meta: [dynamic]Metadata
vertex_Direct_free: [dynamic]int

debug_stats_Direct:      [dynamic]Debug_Stats
debug_stats_Direct_meta: [dynamic]Metadata
debug_stats_Direct_free: [dynamic]int

frame_data_Direct:      [dynamic]FrameData
frame_data_Direct_meta: [dynamic]Metadata
frame_data_Direct_free: [dynamic]int

// External library types
strings_builder_Direct:      [dynamic]strings.Builder
strings_builder_Direct_meta: [dynamic]Metadata
strings_builder_Direct_free: [dynamic]int