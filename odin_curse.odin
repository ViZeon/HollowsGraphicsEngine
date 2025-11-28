package main
import os "core:os"
import "core:fmt"
import "core:math"
import "core:slice"
import "vendor:glfw"
import gl "vendor:OpenGL"
import cgltf "vendor:cgltf"

WINDOW_WIDTH_PERCENT :: 0.7
WINDOW_HEIGHT_PERCENT :: 0.8
SCALE_FACTOR :: 100.0

Vertex :: struct {
    x, y, z: f32,
    x_cell, y_cell: i32,
    // padding to keep typical 16/8-byte alignment safe if needed
    _pad: i32,
}

main :: proc() {
    if !glfw.Init() {
        fmt.println("Failed to init GLFW")
        return
    }
    defer glfw.Terminate()

    monitor := glfw.GetPrimaryMonitor()
    mode := glfw.GetVideoMode(monitor)
    
    window_width := i32(f32(mode.width) * WINDOW_WIDTH_PERCENT)
    window_height := i32(f32(mode.height) * WINDOW_HEIGHT_PERCENT)

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
    
    window := glfw.CreateWindow(window_width, window_height, "Compute Engine", nil, nil)
    if window == nil {
        fmt.println("Failed to create window")
        return
    }
    defer glfw.DestroyWindow(window)
    
    glfw.MakeContextCurrent(window)
    gl.load_up_to(4, 3, glfw.gl_set_proc_address)

    // Ensure viewport is valid at least once
    gl.Viewport(0, 0, window_width, window_height)
    
    // Load glTF
    options: cgltf.options
    data, result := cgltf.parse_file(options, "ABeautifulGame.glb")
    if result != .success {
        fmt.println("Failed to load glTF:", result)
        return
    }
    defer cgltf.free(data)
    
    result = cgltf.load_buffers(options, data, "ABeautifulGame.glb")
    if result != .success {
        fmt.println("Failed to load buffers:", result)
        return
    }
    
    fmt.println("Loaded meshes:", len(data.meshes))
    
    mesh := data.meshes[0]
    primitive := mesh.primitives[0]
    
    position_accessor: ^cgltf.accessor
    for attrib in primitive.attributes {
        if attrib.type == .position {
            position_accessor = attrib.data
            break
        }
    }
    
    if position_accessor == nil {
        fmt.println("No POSITION attribute found")
        return
    }
    
    vertex_count := position_accessor.count
    vertices := make([]Vertex, vertex_count)
    defer delete(vertices)
    
    min_z := f32(math.F32_MAX)
    max_z := f32(math.F32_MIN)
    
    for i in 0..<vertex_count {
        pos: [3]f32
        read_ok := cgltf.accessor_read_float(position_accessor, i, &pos[0], 3)
        if !read_ok {
            fmt.println("Failed to read vertex", i)
            continue
        }
        
        vertices[i].x = pos[0] * SCALE_FACTOR
        vertices[i].y = pos[1] * SCALE_FACTOR
        vertices[i].z = pos[2] * SCALE_FACTOR
        vertices[i].x_cell = i32(math.floor(pos[0] * SCALE_FACTOR))
        vertices[i].y_cell = i32(math.floor(pos[1] * SCALE_FACTOR))
        vertices[i]._pad = 0
        
        if vertices[i].z < min_z do min_z = vertices[i].z
        if vertices[i].z > max_z do max_z = vertices[i].z
    }
    
    slice.sort_by(vertices, proc(a, b: Vertex) -> bool {
        if a.x_cell != b.x_cell do return a.x_cell < b.x_cell
        if a.y_cell != b.y_cell do return a.y_cell < b.y_cell
        return a.z < b.z
    })

    // Verify the sort really worked
    for i in 1..<len(vertices) {
        a := vertices[i-1]
        b := vertices[i]
        if a.x_cell > b.x_cell ||
          (a.x_cell == b.x_cell && a.y_cell > b.y_cell) {
            fmt.eprintf("SORTING BUG at index %d: prev (%d,%d)  curr (%d,%d)\n",
                         i, a.x_cell, a.y_cell, b.x_cell, b.y_cell)
        }
    }
    
    fmt.println("Min Z:", min_z, "Max Z:", max_z)
    fmt.println("Vertex count:", vertex_count)
    
    // Create SSBO for vertices
    ssbo: u32
    gl.GenBuffers(1, &ssbo)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, len(vertices) * size_of(Vertex), raw_data(vertices), gl.STATIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, ssbo)
    
    // Create output texture
    output_texture: u32
    gl.GenTextures(1, &output_texture)
    gl.BindTexture(gl.TEXTURE_2D, output_texture)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, window_width, window_height, 0, gl.RGBA, gl.FLOAT, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    // bind image unit 0 as write-only for compute shader
    gl.BindImageTexture(0, output_texture, 0, gl.FALSE, 0, gl.WRITE_ONLY, gl.RGBA32F)
    

    
	// Read file to string
compute_source, ok := os.read_entire_file("test_compute.glsl", context.allocator)
if !ok {
    fmt.println("Failed to read compute shader")
    return
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
        return
    }
    
    compute_program := gl.CreateProgram()
    gl.AttachShader(compute_program, compute_shader)
    gl.LinkProgram(compute_program)
    
    gl.GetProgramiv(compute_program, gl.LINK_STATUS, &success)
    if success == 0 {
        info_log: [512]u8
        gl.GetProgramInfoLog(compute_program, 512, nil, &info_log[0])
        fmt.println("Compute program linking failed:")
        fmt.println(cstring(&info_log[0]))
        return
    }
    
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
    
    display_program := gl.CreateProgram()
    gl.AttachShader(display_program, vert_shader)
    gl.AttachShader(display_program, frag_shader)
    gl.LinkProgram(display_program)
    
    world_min_x := vertices[0].x
    world_max_x := vertices[0].x
    world_min_y := vertices[0].y
    world_max_y := vertices[0].y
    
    for v in vertices {
        if v.x < world_min_x do world_min_x = v.x
        if v.x > world_max_x do world_max_x = v.x
        if v.y < world_min_y do world_min_y = v.y
        if v.y > world_max_y do world_max_y = v.y
    }
    

    fmt.printf("World bounds after scaling: X %.1f .. %.1f    Y %.1f .. %.1f\n",
           world_min_x, world_max_x, world_min_y, world_max_y)

    fmt.println("World bounds: X[", world_min_x, ",", world_max_x, "] Y[", world_min_y, ",", world_max_y, "]")
    
    fmt.println("\nFirst 5 sorted vertices:")
    for i in 0..<min(5, len(vertices)) {
        v := vertices[i]
        fmt.printf("[%d] (%.2f, %.2f, %.2f) cell:(%d, %d)\n", i, v.x, v.y, v.z, v.x_cell, v.y_cell)
    }
    
    // --- REQUIRED FOR CORE PROFILE (dummy VAO) ---
    vao: u32
    gl.GenVertexArrays(1, &vao)
    gl.BindVertexArray(vao)

    // Set sampler "tex" to texture unit 0 on the display program
    gl.UseProgram(display_program)
    loc := gl.GetUniformLocation(display_program, "tex")
    if loc != -1 {
        gl.Uniform1i(loc, 0)
    }
    gl.UseProgram(0)

    gl.ClearColor(0.1, 0.1, 0.15, 1.0)
    fmt.println("OpenGL 4.3 initialized")
    
    for !glfw.WindowShouldClose(window) {
        gl.UseProgram(compute_program)
        gl.Uniform1i(gl.GetUniformLocation(compute_program, "vertex_count"), i32(vertex_count))
        gl.Uniform1f(gl.GetUniformLocation(compute_program, "min_z"), min_z)
        gl.Uniform1f(gl.GetUniformLocation(compute_program, "max_z"), max_z)
        gl.Uniform2f(gl.GetUniformLocation(compute_program, "world_min"), world_min_x, world_min_y)
        gl.Uniform2f(gl.GetUniformLocation(compute_program, "world_max"), world_max_x, world_max_y)
        gl.Uniform2i(gl.GetUniformLocation(compute_program, "screen_size"), window_width, window_height)
        
        gl.DispatchCompute(u32((window_width + 15) / 16), u32((window_height + 15) / 16), 1)
        gl.MemoryBarrier(gl.SHADER_IMAGE_ACCESS_BARRIER_BIT)
        
        gl.Clear(gl.COLOR_BUFFER_BIT)

        // Display pass: bind texture unit 0 explicitly and draw the full-screen quad generated in VS
        gl.UseProgram(display_program)
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, output_texture)

        // Bind VAO as required by core profile (it's empty; vertex shader uses gl_VertexID)
        gl.BindVertexArray(vao)

        gl.DrawArrays(gl.TRIANGLES, 0, 6)
        
        glfw.SwapBuffers(window)
        glfw.PollEvents()
    }
}
