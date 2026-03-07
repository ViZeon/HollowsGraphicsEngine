package data

Model :: struct {
    field:  Ref,
    bounds: Bounds,
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