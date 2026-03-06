package data

// Runtime data - live heap arrays, edited during execution
// TEMPORARY: flat arrays, generation tracking to be added
datapoints:  [dynamic]DataPoint
fields:      [dynamic]Field

// Pixel buffer — TEMPORARY, will move to renderer state
frame_pixels: []u8

// Debug state
debug_stats: Debug_Stats
