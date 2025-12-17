package testing

import "core:fmt"
import "core:math"
import m "core:math/linalg/glsl"
import data "../data"

// Remove these duplicate definitions:
// Spatial_Grid :: struct { ... }
// Grid_Key :: struct { ... }

// Now use data.Spatial_Grid and data.Grid_Key everywhere

build_spatial_grid :: proc(vertices: []data.Vertex, cell_size: f32 = 1.0) -> data.Spatial_Grid {
    grid := data.Spatial_Grid{
        cells = make(map[data.Grid_Key][dynamic]i32),
        cell_size = cell_size,
    }
    
    // Track bounds
    min_key := data.Grid_Key{max(i32), max(i32), max(i32)}
    max_key := data.Grid_Key{min(i32), min(i32), min(i32)}
    
    for vertex, idx in vertices {
        key := data.Grid_Key{
            x = i32(m.floor(vertex.pos.x / cell_size)),
            y = i32(m.floor(vertex.pos.y / cell_size)),
            z = i32(m.floor(vertex.pos.z / cell_size)),
        }
        
        // Track min/max keys
        min_key.x = min(min_key.x, key.x)
        min_key.y = min(min_key.y, key.y)
        min_key.z = min(min_key.z, key.z)
        max_key.x = max(max_key.x, key.x)
        max_key.y = max(max_key.y, key.y)
        max_key.z = max(max_key.z, key.z)
        
        if key not_in grid.cells {
            grid.cells[key] = make([dynamic]i32)
        }
        
        append(&grid.cells[key], i32(idx))
    }
    
    // Debug stats
    total_vertices := 0
    max_per_cell := 0
    for key, cell in grid.cells {
        count := len(cell)
        total_vertices += count
        if count > max_per_cell {
            max_per_cell = count
        }
    }
    
    avg_per_cell := f32(total_vertices) / f32(len(grid.cells))
    fmt.printf("Spatial Grid Built:\n")
    fmt.printf("  Cells: %d\n", len(grid.cells))
    fmt.printf("  Cell size: %.1f units\n", cell_size)
    fmt.printf("  Cell key bounds: [%d,%d,%d] to [%d,%d,%d]\n", 
               min_key.x, min_key.y, min_key.z, max_key.x, max_key.y, max_key.z)
    fmt.printf("  Avg vertices/cell: %.1f\n", avg_per_cell)
    fmt.printf("  Max vertices/cell: %d\n", max_per_cell)
    
    // Show a few sample cells
    fmt.println("  Sample cells:")
    count := 0
    for key, cell in grid.cells {
        if count < 5 {
            fmt.printf("    Cell [%d,%d,%d] has %d verts\n", key.x, key.y, key.z, len(cell))
            count += 1
        }
    }
    
    return grid
}
query_spatial_grid :: proc(
    grid: ^data.Spatial_Grid,
    pos: m.vec3,
    vertices: []data.Vertex,
) -> (closest_idx: int, vertices_checked: int) {
    
    center_key := data.Grid_Key{
        x = i32(m.floor(pos.x / grid.cell_size)),
        y = i32(m.floor(pos.y / grid.cell_size)),
        z = i32(m.floor(pos.z / grid.cell_size)),
    }
    
    // DEBUG: Print EVERY time now to see what's happening
    @static call_count := 0
    call_count += 1
    
    if call_count == 1 {  // First pixel
        fmt.printf("\n=== GRID QUERY DEBUG (First Pixel) ===\n")
        fmt.printf("Query pos: [%.3f, %.3f, %.3f]\n", pos.x, pos.y, pos.z)
        fmt.printf("Cell size: %.3f\n", grid.cell_size)
        fmt.printf("Calculated cell key: [%d, %d, %d]\n", center_key.x, center_key.y, center_key.z)
        fmt.printf("Total cells in grid: %d\n", len(grid.cells))
        
        // Check if center cell exists
        if center_key in grid.cells {
            fmt.printf("✓ CENTER CELL EXISTS with %d vertices\n", len(grid.cells[center_key]))
        } else {
            fmt.printf("✗ CENTER CELL DOES NOT EXIST\n")
        }
        
        // Check all 27 neighbors
        fmt.println("Checking 27 neighbors:")
        neighbor_count := 0
        for dx in i32(-1)..=1 {
            for dy in i32(-1)..=1 {
                for dz in i32(-1)..=1 {
                    test_key := data.Grid_Key{
                        x = center_key.x + dx,
                        y = center_key.y + dy,
                        z = center_key.z + dz,
                    }
                    if test_key in grid.cells {
                        fmt.printf("  ✓ Neighbor [%d,%d,%d] has %d verts\n", 
                                  test_key.x, test_key.y, test_key.z, len(grid.cells[test_key]))
                        neighbor_count += 1
                    }
                }
            }
        }
        fmt.printf("Found %d neighbors with vertices\n", neighbor_count)
        fmt.println("======================================\n")
    }
    
    min_dist := f32(max(f32))
    closest_idx = -1
    vertices_checked = 0
    
    // Don't do early exit - just check all 27 cells
    for dx in i32(-1)..=1 {
        for dy in i32(-1)..=1 {
            for dz in i32(-1)..=1 {
                neighbor_key := data.Grid_Key{
                    x = center_key.x + dx,
                    y = center_key.y + dy,
                    z = center_key.z + dz,
                }
                
                cell_vertices, exists := grid.cells[neighbor_key]
                if !exists do continue
                
                for vert_id in cell_vertices {
                    vertices_checked += 1
                    dist := distance(vertices[vert_id].pos, pos)
                    
                    if dist < min_dist {
                        min_dist = dist
                        closest_idx = int(vert_id)
                    }
                }
            }
        }
    }
    
    if call_count == 1 {
        fmt.printf("First pixel result: Found vertex %d, checked %d vertices, dist=%.3f\n\n", 
                   closest_idx, vertices_checked, min_dist)
    }
    
    return closest_idx, vertices_checked
}
query_spatial_grid_smart :: proc(
    grid: ^data.Spatial_Grid,
    pos: m.vec3,
    vertices: []data.Vertex,
) -> (closest_idx: int, vertices_checked: int) {
    
    center_key := data.Grid_Key{
        x = i32(m.floor(pos.x / grid.cell_size)),
        y = i32(m.floor(pos.y / grid.cell_size)),
        z = i32(m.floor(pos.z / grid.cell_size)),
    }
    
    min_dist := f32(max(f32))
    closest_idx = -1
    vertices_checked = 0
    
    if cell_vertices, exists := grid.cells[center_key]; exists {
        for vert_id in cell_vertices {
            vertices_checked += 1
            dist := distance(vertices[vert_id].pos, pos)
            
            if dist < min_dist {
                min_dist = dist
                closest_idx = int(vert_id)
            }
        }
    }
    
    if min_dist <= grid.cell_size * 0.5 {
        return closest_idx, vertices_checked
    }
    
    for dx in i32(-1)..=1 {
        for dy in i32(-1)..=1 {
            for dz in i32(-1)..=1 {
                if dx == 0 && dy == 0 && dz == 0 do continue
                
                neighbor_key := data.Grid_Key{
                    x = center_key.x + dx,
                    y = center_key.y + dy,
                    z = center_key.z + dz,
                }
                
                cell_vertices, exists := grid.cells[neighbor_key]
                if !exists do continue
                
                for vert_id in cell_vertices {
                    vertices_checked += 1
                    dist := distance(vertices[vert_id].pos, pos)
                    
                    if dist < min_dist {
                        min_dist = dist
                        closest_idx = int(vert_id)
                    }
                }
            }
        }
    }
    
    return closest_idx, vertices_checked
}

destroy_spatial_grid :: proc(grid: ^data.Spatial_Grid) {
    for key, &cell in grid.cells {
        delete(cell)
    }
    delete(grid.cells)
}