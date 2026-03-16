package data

import vault "../../_vault"

import "core:mem"
import "core:reflect"
import "core:time"

// Internal: direct pointer to debug stats, bypasses management system
// Returns nil if debug_stats not yet initialized — safe to call at any point
_debug_ptr :: proc() -> ^vault.Debug_Stats {
    if !vault.debug_stats.valid do return nil
    return (^vault.Debug_Stats)(vault.arrays[.Debug_Stats][vault.debug_stats.index].data)
}

// Adds a value to the typed store, returns a handle
add :: proc(type_id: vault.Type_ID, value: any, name: string = "") -> vault.Metadata {
    size   := reflect.size_of_typeid(value.id)
    ptr, _  := mem.alloc(size)
    mem.copy(ptr, value.data, size)
    stable := any{data = ptr, id = value.id}

    idx: int
    if len(vault.free_lists[type_id]) > 0 {
        idx = pop(&vault.free_lists[type_id])
        mem.free(vault.arrays[type_id][idx].data)
        vault.arrays[type_id][idx]      = stable
        vault.meta_arrays[type_id][idx] = vault.Metadata{index = idx, name = name, valid = true, type_id = type_id}
    } else {
        idx = len(vault.arrays[type_id])
        append(&vault.arrays[type_id],      stable)
        append(&vault.meta_arrays[type_id], vault.Metadata{index = idx, name = name, valid = true, type_id = type_id})
    }
    return vault.meta_arrays[type_id][idx]
}

// Returns a pointer to the stored value — modify in place, no copy
edit :: proc(meta: vault.Metadata) -> rawptr {
    stats := _debug_ptr()
    start := i64(0)
    if stats != nil {
        stats.fetch_counts[meta.type_id][.Edit] += 1
        if stats.timing_enabled do start = time.now()._nsec
    }
    result := vault.arrays[meta.type_id][meta.index].data
    if stats != nil && stats.timing_enabled && start != 0 {
        stats.fetch_times[meta.type_id][.Edit] += f64(time.now()._nsec - start)
    }
    return result
}

// Returns a copy of the stored value
copy :: proc(meta: vault.Metadata) -> any {
    stats := _debug_ptr()
    start := i64(0)
    if stats != nil {
        stats.fetch_counts[meta.type_id][.Copy] += 1
        if stats.timing_enabled do start = time.now()._nsec
    }
    result := vault.arrays[meta.type_id][meta.index]
    if stats != nil && stats.timing_enabled && start != 0 {
        stats.fetch_times[meta.type_id][.Copy] += f64(time.now()._nsec - start)
    }
    return result
}

// Overwrites the stored value
set :: proc(meta: vault.Metadata, value: any) {
    stats := _debug_ptr()
    start := i64(0)
    if stats != nil {
        stats.fetch_counts[meta.type_id][.Set] += 1
        if stats.timing_enabled do start = time.now()._nsec
    }
    vault.arrays[meta.type_id][meta.index] = value
    if stats != nil && stats.timing_enabled && start != 0 {
        stats.fetch_times[meta.type_id][.Set] += f64(time.now()._nsec - start)
    }
}

// Frees the slot and marks it available for reuse
remove :: proc(meta: vault.Metadata) {
    mem.free(vault.arrays[meta.type_id][meta.index].data)
    vault.meta_arrays[meta.type_id][meta.index].valid = false
    append(&vault.free_lists[meta.type_id], meta.index)
}

// Reserves capacity upfront — call after knowing count, before populating
// Prevents reallocation and keeps pointers stable
preallocate :: proc(type_id: vault.Type_ID, capacity: int) {
    reserve(&vault.arrays[type_id],      capacity)
    reserve(&vault.meta_arrays[type_id], capacity)
}
