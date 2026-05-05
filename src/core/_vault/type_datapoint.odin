package vault

import wr "../_wrappers"

DataPointType :: enum {
    Vertex,
    Polygon,
    Model,
    Field,
}

DataPoint :: struct {
    pos:    wr.Vec3,
    normal: wr.Vec3,
    //type:   DataPointType,
    metadata:    Metadata,
}

Transform :: struct {
    pos:   wr.Vec3,
    rot:   wr.Quat,
    scale: wr.Vec3,
}