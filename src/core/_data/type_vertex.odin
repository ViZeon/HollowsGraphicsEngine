package data

import math "core:math/linalg/glsl"

// Raw vertex data — source of truth, loaded from file
Vertex :: struct {
    pos:    math.vec3,
    normal: math.vec3,
}

// Cached vertex — refs raw vert, holds topology and any derived data
Vertex_Cached :: struct {
    ref:       Ref,
    neighbors: [dynamic]Ref,
}