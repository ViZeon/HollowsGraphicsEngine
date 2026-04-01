package vault

import math "core:math/linalg/glsl"

DataPointType :: enum {
    Vertex,
    Polygon,
    Model,
    Field,
}

DataPoint :: struct {
    pos:    math.vec3,
    normal: math.vec3,
    type:   DataPointType,
    metadata:    Metadata,
}

Transform :: struct {
    pos:   math.vec3,
    rot:   math.quat,
    scale: math.vec3,
}