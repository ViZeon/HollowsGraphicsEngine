package testing

import vault "../_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"

// ---- Neighbor building ----
// Walks face index data, builds adjacency per vertex into Vertex_Cache.neighbors
// Call once on model load after DataPoints are registered
// dp_offset: index of first DataPoint for this model in the DataPoint array
build_neighbors_from_indices :: proc(
    indices:   []u32,
    dp_offset: int,
) {
    // For each face (triangle = 3 indices)
    face_count := len(indices) / 3
    for f in 0 ..< face_count {
        i0 := int(indices[f * 3 + 0])
        i1 := int(indices[f * 3 + 1])
        i2 := int(indices[f * 3 + 2])

        // Each vert gets the other two as neighbors
        add_neighbor(dp_offset + i0, dp_offset + i1)
        add_neighbor(dp_offset + i0, dp_offset + i2)
        add_neighbor(dp_offset + i1, dp_offset + i0)
        add_neighbor(dp_offset + i1, dp_offset + i2)
        add_neighbor(dp_offset + i2, dp_offset + i0)
        add_neighbor(dp_offset + i2, dp_offset + i1)
    }
}

// Adds a neighbor ref to a Vertex_Cache if not already present
// dp_idx: DataPoint index — gets its Vertex_Cache via ref chain
add_neighbor :: proc(dp_idx: int, neighbor_dp_idx: int) {
    if dp_idx >= len(vault.arrays[.DataPoint]) do return
    dp := (^vault.DataPoint)(vault.arrays[.DataPoint][dp_idx].data)

    // dp.ref points to Vertex_Cache
    if dp.ref.index < 0 do return
    cache := (^vault.Vertex_Cache)(vault.arrays[.Vertex_Cache][dp.ref.index].data)

    neighbor_ref := vault.Ref{index = i32(neighbor_dp_idx), version = 0}

    // Check not already present
    for existing in cache.neighbors {
        if existing.index == neighbor_ref.index do return
    }
    append(&cache.neighbors, neighbor_ref)
}

// ---- Polygon cell coverage ----
// For a triangle defined by 3 DataPoint indices, marks all field cells
// the polygon's surface passes through, storing all 3 vert refs in each cell
// Uses normal-curved surface interpolation to determine true cell coverage
map_polygon_to_field :: proc(
    field:      ^vault.Field,
    dp_idx:     [3]int,
) {
    if dp_idx[0] >= len(vault.arrays[.DataPoint]) || dp_idx[1] >= len(vault.arrays[.DataPoint]) || dp_idx[2] >= len(vault.arrays[.DataPoint]) do return

    dp0 := (^vault.DataPoint)(vault.arrays[.DataPoint][dp_idx[0]].data)
    dp1 := (^vault.DataPoint)(vault.arrays[.DataPoint][dp_idx[1]].data)
    dp2 := (^vault.DataPoint)(vault.arrays[.DataPoint][dp_idx[2]].data)

    // Bounding box of polygon in field space
    min_x := min(dp0.pos.x, min(dp1.pos.x, dp2.pos.x))
    max_x := max(dp0.pos.x, max(dp1.pos.x, dp2.pos.x))
    min_y := min(dp0.pos.y, min(dp1.pos.y, dp2.pos.y))
    max_y := max(dp0.pos.y, max(dp1.pos.y, dp2.pos.y))
    min_z := min(dp0.pos.z, min(dp1.pos.z, dp2.pos.z))
    max_z := max(dp0.pos.z, max(dp1.pos.z, dp2.pos.z))

    grid_size := i32(1) << uint(field.levels)
    half      := grid_size / 2

    bx := field.bounds.x.max - field.bounds.x.min
    by := field.bounds.y.max - field.bounds.y.min
    bz := field.bounds.z.max - field.bounds.z.min

    cell_size_x := bx / f32(grid_size)
    cell_size_y := by / f32(grid_size)
    cell_size_z := bz / f32(grid_size)

    // Convert bbox to cell range
    cx_min := i32(math.floor_f32((min_x - field.bounds.x.min) / bx * f32(grid_size))) - half
    cx_max := i32(math.ceil_f32( (max_x - field.bounds.x.min) / bx * f32(grid_size))) - half
    cy_min := i32(math.floor_f32((min_y - field.bounds.y.min) / by * f32(grid_size))) - half
    cy_max := i32(math.ceil_f32( (max_y - field.bounds.y.min) / by * f32(grid_size))) - half
    cz_min := i32(math.floor_f32((min_z - field.bounds.z.min) / bz * f32(grid_size))) - half
    cz_max := i32(math.ceil_f32( (max_z - field.bounds.z.min) / bz * f32(grid_size))) - half

    // Clamp to field
    cx_min = clamp(cx_min, -half, half - 1)
    cx_max = clamp(cx_max, -half, half - 1)
    cy_min = clamp(cy_min, -half, half - 1)
    cy_max = clamp(cy_max, -half, half - 1)
    cz_min = clamp(cz_min, -half, half - 1)
    cz_max = clamp(cz_max, -half, half - 1)

    z_range := cz_max - cz_min + 1 if field.dims == 3 else i32(1)

    for cz := cz_min; cz <= cz_min + z_range - 1; cz += 1 {
        for cy := cy_min; cy <= cy_max; cy += 1 {
            for cx := cx_min; cx <= cx_max; cx += 1 {
                // Cell center in world space
                cell_cx := field.bounds.x.min + (f32(cx + half) + 0.5) * cell_size_x
                cell_cy := field.bounds.y.min + (f32(cy + half) + 0.5) * cell_size_y
                cell_cz := field.bounds.z.min + (f32(cz + half) + 0.5) * cell_size_z

                cell_center := math.vec3{cell_cx, cell_cy, cell_cz}

                // Check if polygon surface passes through this cell
                // Uses normal-curved surface test
                if !polygon_covers_cell(
                    dp0.pos, dp0.normal,
                    dp1.pos, dp1.normal,
                    dp2.pos, dp2.normal,
                    cell_center,
                    max(cell_size_x, max(cell_size_y, cell_size_z)),
                ) {continue}

                idx := cell_index(math.ivec3{cx, cy, cz}, field.levels, field.dims)
                cell_set_field(field, field.levels, idx, true)

                // Store all 3 vert refs in this cell
                append(&field.data[idx], i32(dp_idx[0]))
                append(&field.data[idx], i32(dp_idx[1]))
                append(&field.data[idx], i32(dp_idx[2]))
            }
        }
    }
}

// Tests if a polygon's normal-curved surface passes through a cell
// cell_center: world position of cell center
// cell_size:   size of the cell (for proximity threshold)
polygon_covers_cell :: proc(
    p0, n0: math.vec3,
    p1, n1: math.vec3,
    p2, n2: math.vec3,
    cell_center: math.vec3,
    cell_size:   f32,
) -> bool {
    // Find closest point on the linear triangle to cell center
    closest := closest_point_on_triangle(p0, p1, p2, cell_center)
    dist    := math.length(cell_center - closest)

    // Linear proximity check — cell is covered if within cell_size of triangle
    if dist > cell_size * 0.5 do return false

    // Normal-curve check — interpolate normal at closest point
    // and verify cell center is on the front side of the curved surface
    bary   := barycentric(p0, p1, p2, closest)
    normal := math.normalize(n0 * bary.x + n1 * bary.y + n2 * bary.z)
    to_cell := cell_center - closest

    // Cell is covered if it's within the surface slab defined by the normal
    // (not too far in the normal direction either way)
    normal_dist := abs(math.dot(to_cell, normal))
    return normal_dist <= cell_size * 0.5
}

// Barycentric coordinates of point p projected onto triangle (a, b, c)
barycentric :: proc(a, b, c, p: math.vec3) -> math.vec3 {
    v0 := b - a
    v1 := c - a
    v2 := p - a
    d00 := math.dot(v0, v0)
    d01 := math.dot(v0, v1)
    d11 := math.dot(v1, v1)
    d20 := math.dot(v2, v0)
    d21 := math.dot(v2, v1)
    denom := d00 * d11 - d01 * d01
    if abs(denom) < 1e-10 do return math.vec3{1, 0, 0}
    v := (d11 * d20 - d01 * d21) / denom
    w := (d00 * d21 - d01 * d20) / denom
    u := 1.0 - v - w
    return math.vec3{u, v, w}
}

// Closest point on triangle (a, b, c) to point p
closest_point_on_triangle :: proc(a, b, c, p: math.vec3) -> math.vec3 {
    ab := b - a
    ac := c - a
    ap := p - a

    d1 := math.dot(ab, ap)
    d2 := math.dot(ac, ap)
    if d1 <= 0 && d2 <= 0 do return a

    bp := p - b
    d3 := math.dot(ab, bp)
    d4 := math.dot(ac, bp)
    if d3 >= 0 && d4 <= d3 do return b

    cp := p - c
    d5 := math.dot(ab, cp)
    d6 := math.dot(ac, cp)
    if d6 >= 0 && d5 <= d6 do return c

    vc := d1 * d4 - d3 * d2
    if vc <= 0 && d1 >= 0 && d3 <= 0 {
        v := d1 / (d1 - d3)
        return a + ab * v
    }

    vb := d5 * d2 - d1 * d6
    if vb <= 0 && d2 >= 0 && d6 <= 0 {
        w := d2 / (d2 - d6)
        return a + ac * w
    }

    va := d3 * d6 - d5 * d4
    if va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0 {
        w := (d4 - d3) / ((d4 - d3) + (d5 - d6))
        return b + (c - b) * w
    }

    denom := 1.0 / (va + vb + vc)
    v := vb * denom
    w := vc * denom
    return a + ab * v + ac * w
}

// ---- Interpolation ----
// Given a world position within a polygon, returns interpolated pos and normal
// Normal transition uses Catmull-Rom-like blending for smooth surface curvature
// NOTE: neighbor-of-neighbor data improves tangent quality for Catmull-Rom;
//       currently uses immediate neighbors only — extend when needed
interpolate_surface :: proc(
    p0, n0: math.vec3,
    p1, n1: math.vec3,
    p2, n2: math.vec3,
    world_pos: math.vec3,
) -> (pos, normal: math.vec3) {
    bary := barycentric(p0, p1, p2, world_pos)
    bary  = math.vec3{
        max(0, bary.x),
        max(0, bary.y),
        max(0, bary.z),
    }
    total := bary.x + bary.y + bary.z
    if total > 0 do bary /= total

    // Position: linear barycentric
    pos = p0 * bary.x + p1 * bary.y + p2 * bary.z

    // Normal: spherical blend (slerp-like via normalize of weighted sum)
    // Catmull-Rom extension point — tangents could be derived from neighbors here
    normal = math.normalize(n0 * bary.x + n1 * bary.y + n2 * bary.z)

    return
}
