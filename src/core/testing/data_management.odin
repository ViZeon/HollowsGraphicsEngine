package testing

import data "../_data"
import "core:mem"
import "core:reflect"

add :: proc(type_id: data.Type_ID, value: any, name: string = "") -> data.Metadata {
    size   := reflect.size_of_typeid(value.id)
    ptr, _  := mem.alloc(size)
    mem.copy(ptr, value.data, size)
    stable := any{data = ptr, id = value.id}

    idx: int
    if len(data.free_lists[type_id]) > 0 {
        idx = pop(&data.free_lists[type_id])
        mem.free(data.arrays[type_id][idx].data)
        data.arrays[type_id][idx]      = stable
        data.meta_arrays[type_id][idx] = data.Metadata{index = idx, name = name, valid = true, type_id = type_id}
    } else {
        idx = len(data.arrays[type_id])
        append(&data.arrays[type_id],      stable)
        append(&data.meta_arrays[type_id], data.Metadata{index = idx, name = name, valid = true, type_id = type_id})
    }
    return data.meta_arrays[type_id][idx]
}

get :: proc(meta: data.Metadata) -> rawptr {
    return data.arrays[meta.type_id][meta.index].data
}

get_val :: proc(meta: data.Metadata) -> any {
    return data.arrays[meta.type_id][meta.index]
}

set_val :: proc(meta: data.Metadata, value: any) {
    data.arrays[meta.type_id][meta.index] = value
}

remove :: proc(meta: data.Metadata) {
    mem.free(data.arrays[meta.type_id][meta.index].data)
    data.meta_arrays[meta.type_id][meta.index].valid = false
    append(&data.free_lists[meta.type_id], meta.index)
}