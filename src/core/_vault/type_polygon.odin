package vault

import math "core:math/linalg/glsl"

Polygon_Source :: struct {
    vert_indices:  [dynamic]i32,  // indices into Model.source.verts, supports tris/quads/ngons
    material_slot: i32,
}

Polygon_Cache :: struct {
    normal:    math.vec3,        // derived face normal
    neighbors: [dynamic]i32,     // adjacent polygon indices
    mip_ref:   Ref,
}

Polygon :: struct {
    source: Polygon_Source,
    cache:  Polygon_Cache,
}