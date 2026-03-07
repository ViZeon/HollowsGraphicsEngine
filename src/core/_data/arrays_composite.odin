package data

import math "core:math/linalg/glsl"

datapoint_Composite:      [dynamic]DataPoint
datapoint_Composite_meta: [dynamic]Metadata
datapoint_Composite_free: [dynamic]int

field_Composite:      [dynamic]Field
field_Composite_meta: [dynamic]Metadata
field_Composite_free: [dynamic]int

model_Composite:      [dynamic]Model
model_Composite_meta: [dynamic]Metadata
model_Composite_free: [dynamic]int

// Render buffers — TEMPORARY
prepass_buffer: []math.ivec4
frame_pixels:   []u8