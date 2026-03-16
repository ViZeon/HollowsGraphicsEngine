package vault

Field :: struct {
    // Occupancy bitfields — dual for transparency early entry/exit
    bits_any: [dynamic]u32,       // "is there anything here"
    bits_all: [dynamic]u32,       // "is it ALL transparent" — early exit

    // Data field — parallel to finest-level bitfield cells
    data:     [dynamic][dynamic]i32,

    // Spatial info
    bounds:   Bounds,
    levels:   int,
    dims:     int,   // 1, 2, or 3 — only axes used are allocated
}
