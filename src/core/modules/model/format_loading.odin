package model

import vault "../../_vault"
import fp    "core:path/filepath"
import "core:fmt"

load_model_source :: proc(path: string) -> (source: vault.Model_Source, ok: bool) {
    ext := fp.ext(path)
    switch ext {
    case ".obj":
        return load_obj(path)
    case ".gltf", ".glb":
        return load_gltf(path)
    case:
        fmt.println("load_model_source: unsupported format:", ext)
        return {}, false
    }
}