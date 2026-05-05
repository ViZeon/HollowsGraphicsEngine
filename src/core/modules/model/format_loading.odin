package model

import vault "../../_vault"
import wr "../../_wrappers"

load_model_source :: proc(path: string) -> (source: vault.Model_Source, ok: bool) {
    ext := wr.path_ext(path)
    switch ext {
    case ".obj":
        return load_obj(path)
    case ".gltf", ".glb":
        return load_gltf(path)
    case:
        wr.fmt_println("load_model_source: unsupported format:", ext)
        return {}, false
    }
}