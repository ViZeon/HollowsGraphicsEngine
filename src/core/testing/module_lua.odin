package testing

import "core:fmt"
import lua "vendor:lua/5.4" // or whatever version you want
import "core:c"
import "base:runtime"

state: ^lua.State

lua_allocator :: proc "c" (ud: rawptr, ptr: rawptr, osize, nsize: c.size_t) -> (buf: rawptr) {
    old_size := int(osize)
    new_size := int(nsize)
    context = (^runtime.Context)(ud)^

    if ptr == nil {
        data, err := runtime.mem_alloc(new_size)
        return raw_data(data) if err == .None else nil
    } else {
        if nsize > 0 {
            data, err := runtime.mem_resize(ptr, old_size, new_size)
            return raw_data(data) if err == .None else nil
        } else {
            runtime.mem_free(ptr)
            return
        }
    }
}

lua_start :: proc() {
    _context := context
    state = lua.newstate(lua_allocator, &_context)
    defer lua.close(state)

    // Load and run file — compare to 0, not lua.OK
    if lua.L_dofile(state, "src/lua/script.lua") != 0 {
        err := lua.tostring(state, -1)
        fmt.eprintln("Error loading script:", err)
        lua.pop(state, 1)
        return
    }

    // Call the function
    lua.getglobal(state, "update")
    lua.pushstring(state, "Bitches")
    if lua.pcall(state, 1, 1, 0) == 0 {   // success = 0
        result := lua.tostring(state, -1)
        fmt.println(result)
        lua.pop(state, 1)
    } else {
        err := lua.tostring(state, -1)
        fmt.eprintln("Call error:", err)
        lua.pop(state, 1)
    }
}