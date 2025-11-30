package render

import "../../imports/imports_vendor"
import "../../data"
import os "core:os"
import "core:fmt"
import "vendor:glfw"
import gl "vendor:OpenGL"  

debug_ssbo: u32
buffer_size: int

init_render :: proc(window: glfw.WindowHandle, model: data.Model_Data) -> data.Render_State {
    state: data.Render_State
    
    // Get window size
    width, height := glfw.GetFramebufferSize(window)
    state.window_width = width
    state.window_height = height
    
    // Create SSBO for vertices
    gl.GenBuffers(1, &state.ssbo)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, state.ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, len(model.vertices) * size_of(data.Vertex), 
                  raw_data(model.vertices), gl.STATIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, state.ssbo)

    // Create buffer sized for all pixels
    // Before dispatch
    buffer_size = int(state.window_width * state.window_height * size_of([2]i32))

    gl.GenBuffers(1, &debug_ssbo)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, debug_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, buffer_size, nil, gl.DYNAMIC_READ)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, debug_ssbo)

    // Create output texture
    gl.GenTextures(1, &state.output_texture)
    gl.BindTexture(gl.TEXTURE_2D, state.output_texture)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.BindImageTexture(0, state.output_texture, 0, gl.FALSE, 0, gl.WRITE_ONLY, gl.RGBA8)
    
    // Load and compile compute shader
    compute_source, ok := os.read_entire_file(data.COMPUTE_SHADER_PATH, context.allocator)
    if !ok {
        fmt.println("Failed to read compute shader")
        return state
    }
    defer delete(compute_source)
    
    compute_shader := gl.CreateShader(gl.COMPUTE_SHADER)
    shader_source := [1]cstring{cstring(raw_data(compute_source))}
    shader_length := [1]i32{i32(len(compute_source))}
    gl.ShaderSource(compute_shader, 1, &shader_source[0], &shader_length[0])
    gl.CompileShader(compute_shader)
    
    success: i32
    gl.GetShaderiv(compute_shader, gl.COMPILE_STATUS, &success)
    if success == 0 {
        info_log: [512]u8
        gl.GetShaderInfoLog(compute_shader, 512, nil, &info_log[0])
        fmt.println("Compute shader compilation failed:")
        fmt.println(cstring(&info_log[0]))
        return state
    }
    
    state.compute_program = gl.CreateProgram()
    gl.AttachShader(state.compute_program, compute_shader)
    gl.LinkProgram(state.compute_program)
    
    gl.GetProgramiv(state.compute_program, gl.LINK_STATUS, &success)
    if success == 0 {
        info_log: [512]u8
        gl.GetProgramInfoLog(state.compute_program, 512, nil, &info_log[0])
        fmt.println("Compute program linking failed:")
        fmt.println(cstring(&info_log[0]))
        return state
    }
    
    // Create display shaders
    display_vert := `#version 430
out vec2 uv;
void main() {
    vec2 verts[6] = vec2[](
        vec2(-1, -1), vec2(1, -1), vec2(1, 1),
        vec2(-1, -1), vec2(1, 1), vec2(-1, 1)
    );
    gl_Position = vec4(verts[gl_VertexID], 0.0, 1.0);
    uv = verts[gl_VertexID] * 0.5 + 0.5;
}
`
    
    display_frag := `#version 430
in vec2 uv;
out vec4 color;
uniform sampler2D tex;
void main() {
    color = texture(tex, uv);
}
`
    
    vert_shader := gl.CreateShader(gl.VERTEX_SHADER)
    vert_src := [1]cstring{cstring(raw_data(display_vert))}
    vert_len := [1]i32{i32(len(display_vert))}
    gl.ShaderSource(vert_shader, 1, &vert_src[0], &vert_len[0])
    gl.CompileShader(vert_shader)
    
    frag_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
    frag_src := [1]cstring{cstring(raw_data(display_frag))}
    frag_len := [1]i32{i32(len(display_frag))}
    gl.ShaderSource(frag_shader, 1, &frag_src[0], &frag_len[0])
    gl.CompileShader(frag_shader)
    
    state.display_program = gl.CreateProgram()
    gl.AttachShader(state.display_program, vert_shader)
    gl.AttachShader(state.display_program, frag_shader)
    gl.LinkProgram(state.display_program)
    
    // Create VAO (required for core profile)
    gl.GenVertexArrays(1, &state.vao)
    gl.BindVertexArray(state.vao)
    
    // Set sampler uniform
    gl.UseProgram(state.display_program)
    loc := gl.GetUniformLocation(state.display_program, "tex")
    if loc != -1 {
        gl.Uniform1i(loc, 0)
    }
    gl.UseProgram(0)
    
    gl.ClearColor(0.1, 0.1, 0.15, 1.0)
    
    return state
}

frame_render :: proc(window: ^glfw.WindowHandle, model: ^data.Model_Data, state: ^data.Render_State) {
    // Compute pass
    gl.UseProgram(state.compute_program)
    gl.Uniform1i(gl.GetUniformLocation(state.compute_program, "vertex_count"), i32(model.vertex_count))
    gl.Uniform1f(gl.GetUniformLocation(state.compute_program, "min_z"), model.min_z)
    gl.Uniform1f(gl.GetUniformLocation(state.compute_program, "max_z"), model.max_z)
    gl.Uniform2f(gl.GetUniformLocation(state.compute_program, "world_min"), model.world_min_x, model.world_min_y)
    gl.Uniform2f(gl.GetUniformLocation(state.compute_program, "world_max"), model.world_max_x, model.world_max_y)
    gl.Uniform2i(gl.GetUniformLocation(state.compute_program, "screen_size"), state.window_width, state.window_height)
    
    gl.DispatchCompute(u32((state.window_width + 15) / 16), u32((state.window_height + 15) / 16), 1)
    gl.MemoryBarrier(gl.SHADER_IMAGE_ACCESS_BARRIER_BIT)




    // Read back (after MemoryBarrier)
    // Read entire debug buffer
    debug_data := make([][2]i32, state.window_width * state.window_height)
    defer delete(debug_data)

    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, debug_ssbo)
    gl.GetBufferSubData(gl.SHADER_STORAGE_BUFFER, 0, buffer_size, raw_data(debug_data))

    @static printed := false
    if !printed {
        for y in 0..<min(5, state.window_height) {
            for x in 0..<min(10, state.window_width) {
                idx := y * state.window_width + x
                fmt.printf("(%d,%d): (%d,%d)  ", x, y, debug_data[idx][0], debug_data[idx][1])
            }
            fmt.println()
        }
        printed = true
    }

    gl.DeleteBuffers(1, &debug_ssbo)
 



    // Display pass
    gl.Clear(gl.COLOR_BUFFER_BIT)
    gl.UseProgram(state.display_program)
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, state.output_texture)
    gl.BindVertexArray(state.vao)
    gl.DrawArrays(gl.TRIANGLES, 0, 6)
    
    glfw.SwapBuffers(window^)
    glfw.PollEvents()
}