package vault

import math "core:math/linalg/glsl"

DataPointType :: enum {
    Vertex,
    Model,
    Field,
}

DataPoint :: struct {
    pos:    math.vec3,
    normal: math.vec3,
    type:   DataPointType,
    ref:    Ref,
}
