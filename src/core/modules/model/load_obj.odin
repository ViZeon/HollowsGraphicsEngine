package model

import vault "../../_vault"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:fmt"
import math "core:math/linalg/glsl"

load_obj :: proc(path: string) -> (source: vault.Model_Source, ok: bool) {
    data, err := os.read_entire_file_from_path(path, context.allocator)
    if err != os.ERROR_NONE do return {}, false
    defer delete(data, context.allocator)

    // Raw import buffers — OBJ stores positions/normals/uvs separately
    positions: [dynamic]math.vec3; defer delete(positions)
    normals:   [dynamic]math.vec3; defer delete(normals)
    uvs:       [dynamic]math.vec2; defer delete(uvs)
    colors:    [dynamic]math.vec3; defer delete(colors)

    source.name = strings.clone(strings.trim_suffix(path, ".obj"))
    source.path = strings.clone(path)

    lines := strings.split_lines(string(data))
    defer delete(lines)

    for line in lines {
        line := strings.trim_space(line)
        if len(line) == 0 || line[0] == '#' do continue

        parts := strings.fields(line)
        if len(parts) == 0 do continue

        switch parts[0] {
        case "v":
            x, _ := strconv.parse_f32(parts[1])
            y, _ := strconv.parse_f32(parts[2])
            z, _ := strconv.parse_f32(parts[3])
            append(&positions, math.vec3{x, y, z})
            if len(parts) >= 7 {
                r, _ := strconv.parse_f32(parts[4])
                g, _ := strconv.parse_f32(parts[5])
                b, _ := strconv.parse_f32(parts[6])
                append(&colors, math.vec3{r, g, b})
            } else {
                append(&colors, math.vec3{1, 1, 1})
            }

        case "vn":
            x, _ := strconv.parse_f32(parts[1])
            y, _ := strconv.parse_f32(parts[2])
            z, _ := strconv.parse_f32(parts[3])
            append(&normals, math.vec3{x, y, z})

        case "vt":
            u, _ := strconv.parse_f32(parts[1])
            v, _ := strconv.parse_f32(parts[2])
            append(&uvs, math.vec2{u, v})

        case "f":
            poly: vault.Polygon
            for i in 1 ..< len(parts) {
                sub := strings.split(parts[i], "/")

                pos_idx, _ := strconv.parse_int(sub[0])
                pos_idx -= 1

                uv_idx   := -1
                norm_idx := -1
                if len(sub) > 1 && len(sub[1]) > 0 {
                    uv_idx, _ = strconv.parse_int(sub[1])
                    uv_idx -= 1
                }
                if len(sub) > 2 && len(sub[2]) > 0 {
                    norm_idx, _ = strconv.parse_int(sub[2])
                    norm_idx -= 1
                }

                vert: vault.Vertex
                if pos_idx >= 0 && pos_idx < len(positions) {
                    vert.source.pos   = positions[pos_idx]
                    vert.source.color = colors[pos_idx]
                }
                if norm_idx >= 0 && norm_idx < len(normals) {
                    vert.source.normal = normals[norm_idx]
                }
                if uv_idx >= 0 && uv_idx < len(uvs) {
                    vert.source.uv = uvs[uv_idx]
                }

                vert_idx := i32(len(source.verts))
                append(&source.verts, vert)
                append(&poly.source.vert_indices, vert_idx)
            }
            poly.source.material_slot = 0  // TODO: parse usemtl
            append(&source.polys, poly)
        }
    }

    // TODO: build edges from poly topology
    // TODO: compute face normals for polys missing normals
    // TODO: deduplicate verts

    fmt.println("obj_load: verts:", len(source.verts), "polys:", len(source.polys))
    return source, true
}