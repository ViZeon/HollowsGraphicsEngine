package vault

import math "core:math/linalg/glsl"

Transform :: struct {
    pos:   math.vec3,
    rot:   math.quat,
    scale: math.vec3,
}

// Topology for a loaded mesh — one entry per triangle, stores DataPoint indices
// dp_offset already applied at load time — indices index directly into vault.arrays[.DataPoint]
// One Face_List per model definition, shared across all instances
// TODO: model_update — on geometry change, rebuild Face_List and repopulate Field
//       on instance movement, only world Field bitfields need updating, not mesh data
Face_List :: struct {
    faces: [dynamic][3]i32,
}

Model :: struct {
    field:     Ref,
    face_list: Ref,
    bounds:    Bounds,
}

Model_Cache :: struct {
    ref:       Ref,
    mip_ref:   Ref,
    transform: Transform,
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
