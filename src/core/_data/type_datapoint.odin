package data

import math "core:math/linalg/glsl"

DataPointType :: enum {
    Vertex,
    Model,
}

DataPoint :: struct {
    pos:    math.vec3,
    normal: math.vec3,
    type:   DataPointType,
    ref:    Ref,
}