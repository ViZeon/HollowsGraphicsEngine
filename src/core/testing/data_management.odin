package testing

import data "../_data"
import math "core:math/linalg/glsl"
import "core:strings"

add :: proc(array: ^[dynamic]$T, meta_array: ^[dynamic]data.Metadata, free_list: ^[dynamic]int, value: T, name: string = "") -> data.Metadata {
    idx: int
    if len(free_list^) > 0 {
        idx = pop(free_list)
        array[idx]      = value
        meta_array[idx] = data.Metadata{index = idx, name = name, valid = true, type = typeid_of(T)}
    } else {
        idx = len(array^)
        append(array,      value)
        append(meta_array, data.Metadata{index = idx, name = name, valid = true, type = typeid_of(T)})
    }
    return meta_array[idx]
}

remove :: proc(meta_array: ^[dynamic]data.Metadata, free_list: ^[dynamic]int, meta: data.Metadata) {
    meta_array[meta.index].valid = false
    append(free_list, meta.index)
}

get :: proc(meta: data.Metadata) -> any {
    switch meta.type {
    case bool:               return data.bool_Direct[meta.index]
    case int:                return data.int_Direct[meta.index]
    case i32:                return data.i32_Direct[meta.index]
    case i64:                return data.i64_Direct[meta.index]
    case f32:                return data.f32_Direct[meta.index]
    case f64:                return data.f64_Direct[meta.index]
    case u32:                return data.u32_Direct[meta.index]
    case cstring:            return data.cstring_Direct[meta.index]
    case math.vec3:          return data.vec3_Direct[meta.index]
    case data.Vertex:        return data.vertex_Direct[meta.index]
    case data.Debug_Stats:   return data.debug_stats_Direct[meta.index]
    case data.FrameData:     return data.frame_data_Direct[meta.index]
    case strings.Builder:    return data.strings_builder_Direct[meta.index]
    case data.Vertex_Cached: return data.cached_vertex_Flat[meta.index]
    case data.DataPoint:     return data.datapoint_Composite[meta.index]
    case data.Field:         return data.field_Composite[meta.index]
    case data.Model:         return data.model_Composite[meta.index]
    }
    return nil
}

set :: proc(meta: data.Metadata, value: any) {
    switch meta.type {
    case bool:               data.bool_Direct[meta.index]             = value.(bool)
    case int:                data.int_Direct[meta.index]              = value.(int)
    case i32:                data.i32_Direct[meta.index]              = value.(i32)
    case i64:                data.i64_Direct[meta.index]              = value.(i64)
    case f32:                data.f32_Direct[meta.index]              = value.(f32)
    case f64:                data.f64_Direct[meta.index]              = value.(f64)
    case u32:                data.u32_Direct[meta.index]              = value.(u32)
    case cstring:            data.cstring_Direct[meta.index]          = value.(cstring)
    case math.vec3:          data.vec3_Direct[meta.index]             = value.(math.vec3)
    case data.Vertex:        data.vertex_Direct[meta.index]           = value.(data.Vertex)
    case data.Debug_Stats:   data.debug_stats_Direct[meta.index]      = value.(data.Debug_Stats)
    case data.FrameData:     data.frame_data_Direct[meta.index]       = value.(data.FrameData)
    case strings.Builder:    data.strings_builder_Direct[meta.index]  = value.(strings.Builder)
    case data.Vertex_Cached: data.cached_vertex_Flat[meta.index]      = value.(data.Vertex_Cached)
    case data.DataPoint:     data.datapoint_Composite[meta.index]     = value.(data.DataPoint)
    case data.Field:         data.field_Composite[meta.index]         = value.(data.Field)
    case data.Model:         data.model_Composite[meta.index]         = value.(data.Model)
    }
}