package testing

import "core:os"
import "core:fmt"
import "core:mem"
import "core:encoding/endian"
import data "../data"
import math "core:math/linalg/glsl"

CACHE_DIR :: "cache/"
CACHE_VERSION :: 1 // Increment when data structure changes

Cache_Header :: struct {
    version: u32,
    scale_factor: f32,
    vertex_count: i32,
    bounds: data.Bounds,
    max_radius: f32,
}

Grid_Cache_Header :: struct {
    version: u32,
    size_x: i32,
    size_y: i32,
    size_z: i32,
}

// Generate cache filename from model path
get_cache_path :: proc(model_path: string, suffix: string) -> string {
    // Extract filename without extension
    base := model_path
    if idx := len(model_path) - 1; idx >= 0 {
        for i := idx; i >= 0; i -= 1 {
            if model_path[i] == '/' || model_path[i] == '\\' {
                base = model_path[i+1:]
                break
            }
        }
    }
    
    // Remove extension
    if idx := len(base) - 1; idx >= 0 {
        for i := idx; i >= 0; i -= 1 {
            if base[i] == '.' {
                base = base[:i]
                break
            }
        }
    }
    
    return fmt.tprintf("%s%s_%s.cache", CACHE_DIR, base, suffix)
}

// Save processed model data
save_model_cache :: proc(model_data: ^data.Model_Data, model_path: string, scale: f32) -> bool {
    os.make_directory(CACHE_DIR)
    
    cache_path := get_cache_path(model_path, "model")
    defer delete(cache_path)
    
    file, err := os.open(cache_path, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
    if err != os.ERROR_NONE {
        fmt.printf("Failed to create cache: %v\n", err)
        return false
    }
    defer os.close(file)
    
    // Write header
    header := Cache_Header{
        version = CACHE_VERSION,
        scale_factor = scale,
        vertex_count = i32(len(model_data.VERTICES)),
        bounds = model_data.BOUNDS,
        max_radius = model_data.MAX_RADIUS,
    }
    
    os.write_ptr(file, &header, size_of(Cache_Header))
    
    // Write vertices
    vertex_bytes := len(model_data.VERTICES) * size_of(data.Vertex)
    os.write_ptr(file, raw_data(model_data.VERTICES), vertex_bytes)
    
    fmt.printf("Saved model cache: %s (%d vertices)\n", cache_path, len(model_data.VERTICES))
    return true
}

// Load processed model data
load_model_cache :: proc(model_path: string, scale: f32) -> (data.Model_Data, bool) {
    cache_path := get_cache_path(model_path, "model")
    defer delete(cache_path)
    
    if !os.exists(cache_path) {
        return {}, false
    }
    
    file, err := os.open(cache_path, os.O_RDONLY)
    if err != os.ERROR_NONE {
        return {}, false
    }
    defer os.close(file)
    
    // Read header
    header: Cache_Header
    bytes_read, read_err := os.read_ptr(file, &header, size_of(Cache_Header))
    if read_err != os.ERROR_NONE || bytes_read != size_of(Cache_Header) {
        fmt.println("Cache header read failed")
        return {}, false
    }
    
    // Validate version and scale
    if header.version != CACHE_VERSION {
        fmt.println("Cache version mismatch")
        return {}, false
    }
    
    if header.scale_factor != scale {
        fmt.println("Cache scale mismatch")
        return {}, false
    }
    
    // Read vertices
    vertices := make([]data.Vertex, header.vertex_count)
    vertex_bytes := int(header.vertex_count) * size_of(data.Vertex)
    bytes_read, read_err = os.read_ptr(file, raw_data(vertices), vertex_bytes)
    if read_err != os.ERROR_NONE || bytes_read != vertex_bytes {
        fmt.println("Cache vertices read failed")
        delete(vertices)
        return {}, false
    }
    
    fmt.printf("Loaded model cache: %d vertices\n", len(vertices))
    
    return data.Model_Data{
        VERTICES = vertices,
        BOUNDS = header.bounds,
        MAX_RADIUS = header.max_radius,
    }, true
}

// Save spatial grid
save_grid_cache :: proc(cells: ^[dynamic][dynamic][dynamic]data.Grid_Key, model_path: string) -> bool {
    if len(cells) == 0 do return false
    
    os.make_directory(CACHE_DIR)
    
    cache_path := get_cache_path(model_path, "grid")
    defer delete(cache_path)
    
    file, err := os.open(cache_path, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
    if err != os.ERROR_NONE {
        fmt.printf("Failed to create grid cache: %v\n", err)
        return false
    }
    defer os.close(file)
    
    // Write header
    header := Grid_Cache_Header{
        version = CACHE_VERSION,
        size_x = i32(len(cells)),
        size_y = i32(len(cells[0])),
        size_z = i32(len(cells[0][0])),
    }
    
    os.write_ptr(file, &header, size_of(Grid_Cache_Header))
    
    // Write grid cells
    total_cells := 0
    for x in 0 ..< len(cells) {
        for y in 0 ..< len(cells[x]) {
            for z in 0 ..< len(cells[x][y]) {
                cell := &cells[x][y][z]
                
                // Write key count
                count := i32(len(cell.keys))
                os.write_ptr(file, &count, size_of(i32))
                
                // Write keys
                if count > 0 {
                    key_bytes := int(count) * size_of(i32)
                    os.write_ptr(file, raw_data(cell.keys), key_bytes)
                }
                
                total_cells += 1
            }
        }
    }
    
    fmt.printf("Saved grid cache: %d cells\n", total_cells)
    return true
}

// Load spatial grid
load_grid_cache :: proc(cells: ^[dynamic][dynamic][dynamic]data.Grid_Key, model_path: string) -> bool {
    cache_path := get_cache_path(model_path, "grid")
    defer delete(cache_path)
    
    if !os.exists(cache_path) {
        return false
    }
    
    file, err := os.open(cache_path, os.O_RDONLY)
    if err != os.ERROR_NONE {
        return false
    }
    defer os.close(file)
    
    // Read header
    header: Grid_Cache_Header
    bytes_read, read_err := os.read_ptr(file, &header, size_of(Grid_Cache_Header))
    if read_err != os.ERROR_NONE || bytes_read != size_of(Grid_Cache_Header) {
        fmt.println("Grid cache header read failed")
        return false
    }
    
    if header.version != CACHE_VERSION {
        fmt.println("Grid cache version mismatch")
        return false
    }
    
    // Allocate grid
    resize(cells, int(header.size_x))
    for x in 0 ..< int(header.size_x) {
        resize(&cells[x], int(header.size_y))
        for y in 0 ..< int(header.size_y) {
            resize(&cells[x][y], int(header.size_z))
        }
    }
    
    // Read cells
    for x in 0 ..< int(header.size_x) {
        for y in 0 ..< int(header.size_y) {
            for z in 0 ..< int(header.size_z) {
                // Read key count
                count: i32
                bytes_read, read_err = os.read_ptr(file, &count, size_of(i32))
                if read_err != os.ERROR_NONE {
                    fmt.println("Grid cell count read failed")
                    return false
                }
                
                // Read keys
                if count > 0 {
                    cell := &cells[x][y][z]
                    resize(&cell.keys, int(count))
                    
                    key_bytes := int(count) * size_of(i32)
                    bytes_read, read_err = os.read_ptr(file, raw_data(cell.keys), key_bytes)
                    if read_err != os.ERROR_NONE {
                        fmt.println("Grid keys read failed")
                        return false
                    }
                }
            }
        }
    }
    
    fmt.printf("Loaded grid cache: %dx%dx%d cells\n", header.size_x, header.size_y, header.size_z)
    return true
}
