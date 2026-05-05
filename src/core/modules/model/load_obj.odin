package model

import vault "../../_vault"
import wr "../../_wrappers"

load_obj :: proc(path: string) -> (source: vault.Model_Source, ok: bool) {
    data, err := wr.os_read_entire_file_from_path(path, context.allocator)
    if err != wr.OS_ERROR_NONE do return {}, false
    defer delete(data, context.allocator)

    // Raw import buffers — OBJ stores positions/normals/uvs separately
    positions: [dynamic]wr.Vec3; defer delete(positions)
    normals:   [dynamic]wr.Vec3; defer delete(normals)
    uvs:       [dynamic]wr.Vec2; defer delete(uvs)
    colors:    [dynamic]wr.Vec3; defer delete(colors)

    source.name = wr.strings_clone(wr.strings_trim_suffix(path, ".obj"))
    source.path = wr.strings_clone(path)

    lines := wr.strings_split_lines(string(data))
    defer delete(lines)

    for line in lines {
        line := wr.strings_trim_space(line)
        if len(line) == 0 || line[0] == '#' do continue

        parts := wr.strings_fields(line)
        if len(parts) == 0 do continue

        switch parts[0] {
        case "v":
            x, _ := wr.parse_f32(parts[1])
            y, _ := wr.parse_f32(parts[2])
            z, _ := wr.parse_f32(parts[3])
            append(&positions, wr.Vec3{x, y, z})
            if len(parts) >= 7 {
                r, _ := wr.parse_f32(parts[4])
                g, _ := wr.parse_f32(parts[5])
                b, _ := wr.parse_f32(parts[6])
                append(&colors, wr.Vec3{r, g, b})
            } else {
                append(&colors, wr.Vec3{1, 1, 1})
            }

        case "vn":
            x, _ := wr.parse_f32(parts[1])
            y, _ := wr.parse_f32(parts[2])
            z, _ := wr.parse_f32(parts[3])
            append(&normals, wr.Vec3{x, y, z})

        case "vt":
            u, _ := wr.parse_f32(parts[1])
            v, _ := wr.parse_f32(parts[2])
            append(&uvs, wr.Vec2{u, v})

        case "f":
            poly: vault.Polygon
            for i in 1 ..< len(parts) {
                sub := wr.strings_split(parts[i], "/")

                pos_idx, _ := wr.parse_int(sub[0])
                pos_idx -= 1

                uv_idx   := -1
                norm_idx := -1
                if len(sub) > 1 && len(sub[1]) > 0 {
                    uv_idx, _ = wr.parse_int(sub[1])
                    uv_idx -= 1
                }
                if len(sub) > 2 && len(sub[2]) > 0 {
                    norm_idx, _ = wr.parse_int(sub[2])
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

    wr.fmt_println("obj_load: verts:", len(source.verts), "polys:", len(source.polys))
    return source, true
}