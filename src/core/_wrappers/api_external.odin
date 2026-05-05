package Wrappers

// ── Imports ────────────────────────────────────────────
import math  "core:math/linalg/glsl"
import "core:os"
import "core:fmt"
import "core:mem"
import "core:reflect"
import "core:time"
import "core:strings"
import "core:strconv"
import fp    "core:path/filepath"
import "core:c"
import "base:runtime"

import glfw  "vendor:glfw"
import gl    "vendor:OpenGL"
import rl    "vendor:raylib"
import cgltf "vendor:cgltf"
import lua   "vendor:lua/5.1"
import stbi  "vendor:stb/image"

// ── Re‑export types (aliases) ───────────────────────────
Vec2       :: math.vec2
Vec3       :: math.vec3
IVec3      :: math.ivec3
Quat       :: math.quat
Time_NS    :: i64                     // time.now()._nsec type

Window_Handle :: glfw.WindowHandle
Image         :: rl.Image
Texture2D     :: rl.Texture2D
Keyboard_Key  :: rl.KeyboardKey
Config_Flags  :: rl.ConfigFlags
Lua_State     :: lua.State
CGLTF_Accessor :: ^cgltf.accessor    // opaque pointer, wrap if needed
CGLTF_Options  :: cgltf.options
CGLTF_Result   :: cgltf.result
//Builder        :: strings.Builder
Runtime_Context :: runtime.Context

// ── Math ───────────────────────────────────────────────
math_vec2         :: math.vec2
math_vec3         :: math.vec3
math_ivec3        :: math.ivec3
math_quat         :: math.quat
normalize         :: math.normalize
normalize_vec3    :: math.normalize_vec3
dot               :: math.dot
abs               :: math.abs
cross             :: math.cross
length            :: math.length
clamp 			  :: math.clamp
floor_f32         :: math.floor_f32
ceil_f32          :: math.ceil_f32
tan               :: math.tan
acos              :: math.acos
sqrt              :: math.sqrt
cos               :: math.cos
sin               :: math.sin
lerp              :: math.lerp
PI                :: math.PI
TAU               :: math.TAU

// ── OS & Filesystem ────────────────────────────────────
os_read_entire_file          :: os.read_entire_file
os_read_entire_file_from_path :: os.read_entire_file_from_path
os_make_directory            :: os.make_directory
os_exists                    :: os.exists
os_open                      :: os.open
os_close                     :: os.close
os_write_string              :: os.write_string
os_write_entire_file         :: os.write_entire_file
OS_ERROR_NONE                :: os.ERROR_NONE
OS_O_WRONLY                  :: os.O_WRONLY
OS_O_CREATE                  :: os.O_CREATE
OS_O_APPEND                  :: os.O_APPEND
OS_perm_number               :: os.perm_number

// ── Formatting ──────────────────────────────────────────
fmt_println      :: fmt.println
fmt_tprintf      :: fmt.tprintf
fmt_sbprintf     :: fmt.sbprintf
fmt_print        :: fmt.print
fmt_eprintln     :: fmt.eprintln
fmt_ctprintf     :: fmt.ctprintf

// ── Memory ──────────────────────────────────────────────
mem_alloc        :: mem.alloc
mem_free         :: mem.free
mem_copy         :: mem.copy

// ── Reflect ─────────────────────────────────────────────
size_of_typeid   :: reflect.size_of_typeid

// ── Time ────────────────────────────────────────────────
time_now         :: time.now
// helper to get nanoseconds
time_now_nsec    :: proc() -> i64 { return time.now()._nsec }

// ── Strings ─────────────────────────────────────────────
strings_builder_init        :: strings.builder_init
strings_builder_destroy     :: strings.builder_destroy
strings_builder_reset       :: strings.builder_reset
strings_to_string           :: strings.to_string
strings_clone               :: strings.clone
strings_clone_to_cstring    :: strings.clone_to_cstring
strings_split         		:: strings.split
strings_split_lines         :: strings.split_lines
strings_fields              :: strings.fields
strings_trim_space          :: strings.trim_space
strings_trim_suffix         :: strings.trim_suffix
Builder                     :: strings.Builder

// ── String Conversion ───────────────────────────────────
parse_f32 :: strconv.parse_f32
parse_int :: strconv.parse_int

// ── Filepath ────────────────────────────────────────────
path_ext  :: fp.ext
path_join :: fp.join

// ── C interop ───────────────────────────────────────────
c_size_t  :: c.size_t

// ── Runtime (for Lua allocator) ─────────────────────────
runtime_context       :: runtime.Context
runtime_mem_alloc     :: runtime.mem_alloc
runtime_mem_resize    :: runtime.mem_resize
runtime_mem_free      :: runtime.mem_free

// ── GLFW windowing ──────────────────────────────────────
glfw_init              :: glfw.Init
glfw_terminate         :: glfw.Terminate
glfw_get_primary_monitor :: glfw.GetPrimaryMonitor
glfw_get_video_mode    :: glfw.GetVideoMode
glfw_window_hint       :: glfw.WindowHint
glfw_create_window     :: glfw.CreateWindow
glfw_destroy_window    :: glfw.DestroyWindow
glfw_make_context_current :: glfw.MakeContextCurrent
glfw_set_window_title  :: glfw.SetWindowTitle
glfw_get_time          :: glfw.GetTime
glfw_swap_buffers      :: glfw.SwapBuffers
glfw_poll_events       :: glfw.PollEvents
glfw_get_framebuffer_size :: glfw.GetFramebufferSize
glfw_set_proc_address  :: glfw.gl_set_proc_address   // function pointer

GLFW_CONTEXT_VERSION_MAJOR :: glfw.CONTEXT_VERSION_MAJOR
GLFW_CONTEXT_VERSION_MINOR :: glfw.CONTEXT_VERSION_MINOR
GLFW_OPENGL_PROFILE        :: glfw.OPENGL_PROFILE
GLFW_OPENGL_CORE_PROFILE   :: glfw.OPENGL_CORE_PROFILE
GLFW_RESIZABLE             :: glfw.RESIZABLE
GLFW_TRUE                  :: glfw.TRUE
GLFW_FALSE                 :: glfw.FALSE

// ── OpenGL ──────────────────────────────────────────────
gl_load_up_to        :: gl.load_up_to
gl_viewport          :: gl.Viewport
gl_gen_buffers       :: gl.GenBuffers
gl_bind_buffer       :: gl.BindBuffer
gl_buffer_data       :: gl.BufferData
gl_bind_buffer_base  :: gl.BindBufferBase
gl_get_buffer_sub_data:: gl.GetBufferSubData
gl_delete_buffers    :: gl.DeleteBuffers
gl_gen_textures      :: gl.GenTextures
gl_bind_texture      :: gl.BindTexture
gl_tex_image_2d      :: gl.TexImage2D
gl_tex_parameter_i   :: gl.TexParameteri
gl_bind_image_texture:: gl.BindImageTexture
gl_gen_vertex_arrays :: gl.GenVertexArrays
gl_bind_vertex_array :: gl.BindVertexArray
gl_create_shader     :: gl.CreateShader
gl_shader_source     :: gl.ShaderSource
gl_compile_shader    :: gl.CompileShader
gl_get_shader_iv     :: gl.GetShaderiv
gl_get_shader_info_log:: gl.GetShaderInfoLog
gl_create_program    :: gl.CreateProgram
gl_attach_shader     :: gl.AttachShader
gl_link_program      :: gl.LinkProgram
gl_get_program_iv    :: gl.GetProgramiv
gl_get_program_info_log:: gl.GetProgramInfoLog
gl_use_program       :: gl.UseProgram
gl_get_uniform_location:: gl.GetUniformLocation
gl_uniform_1i        :: gl.Uniform1i
gl_uniform_1f        :: gl.Uniform1f
gl_uniform_2f        :: gl.Uniform2f
gl_uniform_2i        :: gl.Uniform2i
gl_dispatch_compute  :: gl.DispatchCompute
gl_memory_barrier    :: gl.MemoryBarrier
gl_clear             :: gl.Clear
gl_clear_color       :: gl.ClearColor
gl_active_texture    :: gl.ActiveTexture
gl_draw_arrays       :: gl.DrawArrays

// GL constants
GL_SHADER_STORAGE_BUFFER         :: gl.SHADER_STORAGE_BUFFER
GL_STATIC_DRAW                   :: gl.STATIC_DRAW
GL_DYNAMIC_READ                  :: gl.DYNAMIC_READ
GL_TEXTURE_2D                    :: gl.TEXTURE_2D
GL_RGBA8                         :: gl.RGBA8
GL_RGBA                          :: gl.RGBA
GL_UNSIGNED_BYTE                 :: gl.UNSIGNED_BYTE
GL_NEAREST                       :: gl.NEAREST
GL_WRITE_ONLY                    :: gl.WRITE_ONLY
GL_COMPUTE_SHADER                :: gl.COMPUTE_SHADER
GL_VERTEX_SHADER                 :: gl.VERTEX_SHADER
GL_FRAGMENT_SHADER               :: gl.FRAGMENT_SHADER
GL_COMPILE_STATUS                :: gl.COMPILE_STATUS
GL_LINK_STATUS                   :: gl.LINK_STATUS
GL_TRIANGLES                     :: gl.TRIANGLES
GL_COLOR_BUFFER_BIT              :: gl.COLOR_BUFFER_BIT
GL_SHADER_IMAGE_ACCESS_BARRIER_BIT :: gl.SHADER_IMAGE_ACCESS_BARRIER_BIT
GL_FALSE                         :: gl.FALSE
GL_TRUE                          :: gl.TRUE

// ── Raylib ──────────────────────────────────────────────
rl_init_window      :: rl.InitWindow
rl_close_window     :: rl.CloseWindow
rl_window_should_close :: rl.WindowShouldClose
rl_set_window_title :: rl.SetWindowTitle
rl_set_config_flags :: rl.SetConfigFlags
rl_begin_drawing    :: rl.BeginDrawing
rl_end_drawing      :: rl.EndDrawing
rl_clear_background :: rl.ClearBackground
rl_load_texture_from_image :: rl.LoadTextureFromImage
rl_update_texture   :: rl.UpdateTexture
rl_draw_texture     :: rl.DrawTexture
rl_draw_rectangle   :: rl.DrawRectangle
rl_draw_text        :: rl.DrawText
rl_color_alpha      :: rl.ColorAlpha
rl_get_time         :: rl.GetTime
rl_get_frame_time   :: rl.GetFrameTime
rl_get_fps          :: rl.GetFPS
rl_is_key_pressed   :: rl.IsKeyPressed
rl_is_key_down      :: rl.IsKeyDown

// Colors
RL_BLACK            :: rl.BLACK
RL_WHITE            :: rl.WHITE
RL_GREEN            :: rl.GREEN
RL_YELLOW           :: rl.YELLOW
RL_DARKGRAY         :: rl.DARKGRAY

// Pixel format
//RL_UNCOMPRESSED_R8G8B8 :: rl.UNCOMPRESSED_R8G8B8
//RL_WINDOW_RESIZABLE    :: rl.WINDOW_RESIZABLE

// Keys
KEY_F1  :: rl.KeyboardKey.F1
KEY_F2  :: rl.KeyboardKey.F2
KEY_F12 :: rl.KeyboardKey.F12
KEY_W   :: rl.KeyboardKey.W
KEY_A   :: rl.KeyboardKey.A
KEY_S   :: rl.KeyboardKey.S
KEY_D   :: rl.KeyboardKey.D
KEY_Q   :: rl.KeyboardKey.Q
KEY_E   :: rl.KeyboardKey.E
KEY_LEFT_SHIFT :: rl.KeyboardKey.LEFT_SHIFT

// ── cgltf ───────────────────────────────────────────────
cgltf_parse_file        :: cgltf.parse_file
cgltf_free              :: cgltf.free
cgltf_load_buffers      :: cgltf.load_buffers
cgltf_accessor_read_float :: cgltf.accessor_read_float
cgltf_accessor_read_index :: cgltf.accessor_read_index
CGLTF_Result_Success    :: cgltf.result.success


// ── Lua ─────────────────────────────────────────────────
lua_newstate    :: lua.newstate
lua_close       :: lua.close
luaL_dofile     :: lua.L_dofile
lua_tostring    :: lua.tostring
lua_pop         :: lua.pop
lua_getglobal   :: lua.getglobal
lua_pushstring  :: lua.pushstring
lua_pcall       :: lua.pcall


// ── stb_image ──────────────────────────────────────────
stbi_write_png  :: stbi.write_png