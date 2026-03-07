package data

import math "core:math/linalg/glsl"

arrays:      [Type_ID][dynamic]any
meta_arrays: [Type_ID][dynamic]Metadata
free_lists:  [Type_ID][dynamic]int

// Render buffers — TEMPORARY
prepass_buffer: []math.ivec4
frame_pixels:   []u8