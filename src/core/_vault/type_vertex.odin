package vault

import math "core:math/linalg/glsl"

// Raw vertex data — source of truth, loaded from file
Vertex_Source :: struct {
    pos:    math.vec3,
    normal: math.vec3,
    uv:     math.vec2, // TODO: material/texture sampling
    color:  math.vec3,  // vertex color, defaults to {1,1,1} if not present
}

// Cached vertex — refs raw vert, holds topology and derived data
Vertex_Cache :: struct {
    neighbors: [dynamic]Ref,
    mip_ref:   Ref,            // representative DataPoint for this level
}

Vertex :: struct {
    source: Vertex_Source,
    cache:  Vertex_Cache,
}