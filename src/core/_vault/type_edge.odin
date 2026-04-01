package vault

Edge_Source :: struct {
    vert_a: i32,    // index into Model.source.verts
    vert_b: i32,
    crease: f32,    // subdivision crease weight
}

Edge_Cache :: struct {
    poly_a: i32,    // adjacent polygon indices, -1 if boundary
    poly_b: i32,
    sharp:  bool,   // hard edge flag, derived from smooth groups
}

Edge :: struct {
    source: Edge_Source,
    cache:  Edge_Cache,
}