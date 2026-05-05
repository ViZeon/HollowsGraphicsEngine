package testing

import wr "../_wrappers"

state: ^wr.Lua_State

lua_allocator :: proc "c" (ud: rawptr, ptr: rawptr, osize, nsize: wr.c_size_t) -> (buf: rawptr) {
    old_size := int(osize)
    new_size := int(nsize)
    context = (^wr.Runtime_Context)(ud)^

    if ptr == nil {
        data, err := wr.runtime_mem_alloc(new_size)
        return raw_data(data) if err == .None else nil
    } else {
        if nsize > 0 {
            data, err := wr.runtime_mem_resize(ptr, old_size, new_size)
            return raw_data(data) if err == .None else nil
        } else {
            wr.runtime_mem_free(ptr)
            return
        }
    }
}

lua_start :: proc() {
    _context := context
    state = wr.lua_newstate(lua_allocator, &_context)
    defer wr.lua_close(state)

    // Load and run file — compare to 0, not lua.OK
    if wr.luaL_dofile(state, "src/lua/script.lua") != 0 {
        err := wr.lua_tostring(state, -1)
        wr.fmt_eprintln("Error loading script:", err)
        wr.lua_pop(state, 1)
        return
    }

    // Call the function
    wr.lua_getglobal(state, "update")
    wr.lua_pushstring(state, "Bitches")
    if wr.lua_pcall(state, 1, 1, 0) == 0 {   // success = 0
        result := wr.lua_tostring(state, -1)
        wr.fmt_println(result)
        wr.lua_pop(state, 1)
    } else {
        err := wr.lua_tostring(state, -1)
        wr.fmt_eprintln("Call error:", err)
        wr.lua_pop(state, 1)
    }
}