package vault

import wr "../_wrappers"

Model_Source :: struct {
    name:  string,
    path:  string,
    verts: [dynamic]Vertex,
    polys: [dynamic]Polygon,
    edges: [dynamic]Edge,
}

//TODO: Replace Ref field type with MetaData
Model_Cache :: struct {
    bounds:         Bounds,
    field:          Metadata,
    occupied_cells: [dynamic]i32,
}

Model :: struct {
    source: Model_Source,
    cache:  Model_Cache,
}


// TODO: PBR material — albedo, metallic, roughness, normal map, emissive
// refs Texture by index