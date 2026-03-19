package vault

import math "core:math/linalg/glsl"

arrays:      [Type_ID][dynamic]any
meta_arrays: [Type_ID][dynamic]Metadata
free_lists:  [Type_ID][dynamic]int

// Render buffers — TEMPORARY
prepass_buffer: []Ref        // one Ref per pixel — reserved, not yet used
frame_pixels:   []u8         // RGB pixel output buffer

// Screen field nesting level start indices
// screen_field_ids[n] = starting index in vault.arrays[.Field] for nesting level n
// Level 0: 1 Field  (root, covers whole screen)
// Level 1: cell_size Fields
// Level 2: cell_size² Fields
// etc.
screen_field_ids: [dynamic]i32
