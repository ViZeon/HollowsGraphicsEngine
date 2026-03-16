package vault

import math "core:math/linalg/glsl"

arrays:      [Type_ID][dynamic]any
meta_arrays: [Type_ID][dynamic]Metadata
free_lists:  [Type_ID][dynamic]int

// Render buffers — TEMPORARY
prepass_buffer: []Ref        // one Ref per pixel — points to finest resolved DataPoint
frame_pixels:   []u8
