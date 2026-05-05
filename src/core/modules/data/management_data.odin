package data

import vault "../../_vault"
import wr "../../_wrappers"

_debug_ptr :: proc() -> ^vault.Debug_Stats {
    if !vault.debug_stats.valid do return nil
    return (^vault.Debug_Stats)(vault.arrays[.Debug_Stats][vault.debug_stats.index].data)
}

_fetch_begin :: proc(meta: vault.Metadata, op: vault.Fetch_Op) -> i64 {
    stats := _debug_ptr()
    if stats == nil do return 0
    stats.fetch_counts[meta.type_id][op] += 1
    if stats.timing_enabled do return wr.time_now_nsec()
    return 0
}

_fetch_end :: proc(meta: vault.Metadata, op: vault.Fetch_Op, start: i64) {
    if start == 0 do return
    stats := _debug_ptr()
    if stats == nil do return
    stats.fetch_times[meta.type_id][op] += f64(wr.time_now_nsec() - start)
}

// Adds a value to the typed store, registers its Metadata, returns a Metadata copy
add :: proc(type_id: vault.Type_ID, value: any, name: string = "") -> vault.Metadata {
    size   := wr.size_of_typeid(value.id)
    ptr, _  := wr.mem_alloc(size)
    wr.mem_copy(ptr, value.data, size)
    stable := any{data = ptr, id = value.id}

    idx: int
    if len(vault.free_lists[type_id]) > 0 {
        idx = pop(&vault.free_lists[type_id])
        wr.mem_free(vault.arrays[type_id][idx].data)
        vault.arrays[type_id][idx]      = stable
        vault.meta_arrays[type_id][idx] = vault.Metadata{index = idx, name = name, valid = true, type_id = type_id}
    } else {
        idx = len(vault.arrays[type_id])
        append(&vault.arrays[type_id],      stable)
        append(&vault.meta_arrays[type_id], vault.Metadata{index = idx, name = name, valid = true, type_id = type_id})
    }

    // Register Metadata in vault.arrays[.Metadata] — assigns universal id
    meta     := vault.meta_arrays[type_id][idx]
    meta_id  := len(vault.arrays[.Metadata])
    meta.id   = meta_id

    meta_ptr, _ := wr.mem_alloc(size_of(vault.Metadata))
    wr.mem_copy(meta_ptr, &meta, size_of(vault.Metadata))
    append(&vault.arrays[.Metadata],      any{data = meta_ptr, id = typeid_of(vault.Metadata)})
    append(&vault.meta_arrays[.Metadata], vault.Metadata{id = meta_id, index = meta_id, name = name, valid = true, type_id = .Metadata})

    // Update stored meta with id
    vault.meta_arrays[type_id][idx].id = meta_id

    return vault.meta_arrays[type_id][idx]
}

// Resolves a universal Metadata id to its Metadata
// Use to look up type_id + index from an i32 stored in field.data[cell]
resolve :: proc(id: i32) -> vault.Metadata {
    if int(id) < 0 || int(id) >= len(vault.arrays[.Metadata]) do return vault.Metadata{}
    return (^vault.Metadata)(vault.arrays[.Metadata][id].data)^
}

edit :: proc(meta: vault.Metadata) -> rawptr {
    start  := _fetch_begin(meta, .Edit)
    result := vault.arrays[meta.type_id][meta.index].data
    _fetch_end(meta, .Edit, start)
    return result
}

copy :: proc(meta: vault.Metadata) -> any {
    start  := _fetch_begin(meta, .Copy)
    result := vault.arrays[meta.type_id][meta.index]
    _fetch_end(meta, .Copy, start)
    return result
}

set :: proc(meta: vault.Metadata, value: any) {
    start := _fetch_begin(meta, .Set)
    vault.arrays[meta.type_id][meta.index] = value
    _fetch_end(meta, .Set, start)
}

remove :: proc(meta: vault.Metadata) {
    wr.mem_free(vault.arrays[meta.type_id][meta.index].data)
    vault.meta_arrays[meta.type_id][meta.index].valid = false
    append(&vault.free_lists[meta.type_id], meta.index)
}

preallocate :: proc(type_id: vault.Type_ID, capacity: int) {
    reserve(&vault.arrays[type_id],      capacity)
    reserve(&vault.meta_arrays[type_id], capacity)
}


data_check_occupancy :: proc(index_type: int, index_id: int) -> string{
    // add a check for the existence of metadata
    return ""
}