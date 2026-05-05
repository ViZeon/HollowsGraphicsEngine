package vault

import wr "../_wrappers"

// Raw vertex data — source of truth, loaded from file
Vertex_Source :: struct {
    pos:    wr.Vec3,
    normal: wr.Vec3,
    uv:     wr.Vec2,      // TODO: material/texture sampling
    color:  wr.Vec3,      // vertex color, defaults to {1,1,1} if not present
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