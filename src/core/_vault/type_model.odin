package vault

import math "core:math/linalg/glsl"

Transform :: struct {
    pos:   math.vec3,
    rot:   math.quat,
    scale: math.vec3,
}

Model :: struct {
    field:  Ref,
    bounds: Bounds,
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
