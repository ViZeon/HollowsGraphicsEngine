package data

Field :: struct {
    // Occupancy
    bits:       [dynamic]u32,
    // Refs into flat DataPoint array
    refs:       [dynamic][dynamic]i32,
    // Spatial info
    bounds:     Bounds,
    levels:     int,
}