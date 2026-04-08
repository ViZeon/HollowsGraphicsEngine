package testing

import vault "../_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"


cam :Camera

// Global or persistent state
cam_theta  : f32 = 0.0
cam_phi    : f32 = 0.4 // Slight top-down tilt
cam_radius : f32 = 10.0
target_pos : Vec3 = {0, 0, 0}

    // Rotation speed: 1.0 means ~57 degrees per second
    rotation_speed : f32 = 10.0

prepass_run :: proc(scene : vault.Metadata) {
	scene_datapoint:= (^vault.DataPoint)(data.edit(scene))
	scene_field:= (^vault.Field)(data.edit(scene_datapoint.metadata))

	cell_zero := cell_get(scene_field.bits_any[:], 0,0,3)
	//debug_print( scene_field.data[0])
		
		screen_tex  := (^vault.Texture)(data.edit(vault.screen_texture))
	prepass(screen_tex.source.pixels[:],int(g_screen_w),int(g_screen_h))

	//debug_print(scene_datapoint)
	//debug_print(scene_field.bounds)
} 


// ----------------------------------------------------------------
// Toggle
// ----------------------------------------------------------------

Interior_Mode :: enum { Scanline, UV }
INTERIOR_MODE :: Interior_Mode.UV // switch here to compare

// ----------------------------------------------------------------
// Types
// ----------------------------------------------------------------

Vec3 :: [3]f32

Camera :: struct {
    pos: Vec3,
    dir: Vec3, // stub — rotation not yet implemented
    fov: f32,  // radians, horizontal
}

Polygon :: struct {
    verts:   []Vec3,
    normals: []Vec3,
    // uvs: [][2]f32 — hook for imported UVs later
}

// ----------------------------------------------------------------
// Test data
// ----------------------------------------------------------------

make_test_polygon :: proc(center: Vec3, n: int, radius: f32) -> Polygon {
    verts   := make([]Vec3, n)
    normals := make([]Vec3, n)
    for i in 0..<n {
        angle  := f32(i) / f32(n) * math.TAU
        v := Vec3{
            center.x + math.cos(angle) * radius,
            center.y,
            center.z + math.sin(angle) * radius,
        }
        verts[i]   = v
        normals[i] = math.normalize(Vec3{v.x - center.x, 1, v.z - center.z})
    }
    return Polygon{verts = verts, normals = normals}
}

make_test_scene :: proc() -> []Polygon {
    polys    := make([]Polygon, 3)
    polys[0]  = make_test_polygon({-4, 0, 0}, 3, 1.5) // triangle
    polys[1]  = make_test_polygon({ 0, 0, 0}, 4, 1.5) // quad
    polys[2]  = make_test_polygon({ 4, 0, 0}, 6, 1.5) // hexagon
    return polys
}

free_polygon :: proc(p: Polygon) {
    delete(p.verts)
    delete(p.normals)
}

// ----------------------------------------------------------------
// Hermite
// ----------------------------------------------------------------

TANGENT_SCALE :: f32(1.0)

hermite_pos :: proc(p0, t0, p1, t1: Vec3, t: f32) -> Vec3 {
    t2 := t * t
    t3 := t2 * t
    return (2*t3 - 3*t2 + 1)*p0 +
           (  t3 - 2*t2 + t)*t0 +
           (-2*t3 + 3*t2    )*p1 +
           (  t3 -   t2     )*t1
}

hermite_deriv :: proc(p0, t0, p1, t1: Vec3, t: f32) -> Vec3 {
    t2 := t * t
    return (6*t2 - 6*t    )*p0 +
           (3*t2 - 4*t + 1)*t0 +
           (-6*t2 + 6*t   )*p1 +
           (3*t2 - 2*t    )*t1
}


update_turntable :: proc(dt: f32) {

    
    // We pass a fake "mouse delta" based purely on time
    fake_delta := [2]f32{ rotation_speed * dt, 0.0 }
    
    update_camera_orbit(&cam, target_pos, fake_delta, cam_radius, &cam_theta, &cam_phi)
}

// Call this every frame before your prepass loop
// mouse_delta is {delta_x, delta_y} from your input handler
update_camera_orbit :: proc(cam: ^Camera, target: Vec3, mouse_delta: [2]f32, radius: f32, theta, phi: ^f32) {
    theta^ += mouse_delta.x * 0.01
    phi^   -= mouse_delta.y * 0.01
    
    // Clamp pitch to avoid breaking the neck (gimbal lock)
    phi^ = clamp(phi^, -math.PI/2 + 0.01, math.PI/2 - 0.01)

    cam.pos.x = target.x + radius * math.cos(phi^) * math.sin(theta^)
    cam.pos.y = target.y + radius * math.sin(phi^)
    cam.pos.z = target.z + radius * math.cos(phi^) * math.cos(theta^)

    cam.dir = math.normalize(target - cam.pos)
}

// Replaces your old project function
project :: proc(p: Vec3, cam: Camera, w, h: int) -> ([2]f32, bool) {
    forward  := math.normalize(cam.dir)
    world_up := Vec3{0, 1, 0}
    
    // Fallback if looking straight down/up
    if math.abs(math.dot(forward, world_up)) > 0.999 do world_up = {0, 0, -1}
    
    right := math.normalize(math.cross(forward, world_up))
    up    := math.cross(right, forward)

    // Transform point to camera space
    rel := p - cam.pos
    p_cam := Vec3{
        math.dot(rel, right),
        math.dot(rel, up),
        math.dot(rel, forward), 
    }

    // Behind camera check
    if p_cam.z <= 0.1 do return {}, false

    aspect  := f32(w) / f32(h)
    inv_tan := 1.0 / math.tan(cam.fov * 0.5)

    ndc_x := (p_cam.x / p_cam.z) * inv_tan / aspect
    ndc_y := (p_cam.y / p_cam.z) * inv_tan

    px := (ndc_x + 1) * 0.5 * f32(w)
    py := (1 - (ndc_y + 1) * 0.5) * f32(h)

    return {px, py}, true
}

write_splat :: proc(pixels: []u8, x, y, w, h: int, color: Vec3) {
    // Writes a 2x2 block. Cheap antialiasing and gap-filling.
    write_pixel(pixels, x,   y,   w, h, color)
    write_pixel(pixels, x+1, y,   w, h, color)
    write_pixel(pixels, x,   y+1, w, h, color)
    write_pixel(pixels, x+1, y+1, w, h, color)
}

// ----------------------------------------------------------------
// Pixel write
// ----------------------------------------------------------------

write_pixel :: proc(pixels: []u8, x, y, w, h: int, color: Vec3) {
    if x < 0 || x >= w || y < 0 || y >= h do return
    idx := (y * w + x) * 3
    pixels[idx+0] = u8(clamp(color.x, 0, 255))
    pixels[idx+1] = u8(clamp(color.y, 0, 255))
    pixels[idx+2] = u8(clamp(color.z, 0, 255))
}

// ----------------------------------------------------------------
// 2D helpers
// TODO: generalize to arbitrary plane via polygon normal
//       test polys are on Y=0 so XZ is used as local 2D
// ----------------------------------------------------------------

to_local2d :: proc(v: Vec3) -> [2]f32 {
    return {v.x, v.z}
}

point_in_polygon :: proc(p: [2]f32, verts: [][2]f32) -> bool {
    n      := len(verts)
    inside := false
    j      := n - 1
    for i in 0..<n {
        vi := verts[i]; vj := verts[j]
        if ((vi.y > p.y) != (vj.y > p.y)) &&
           (p.x < (vj.x - vi.x) * (p.y - vi.y) / (vj.y - vi.y) + vi.x) {
            inside = !inside
        }
        j = i
    }
    return inside
}

// ----------------------------------------------------------------
// Mean value coordinates
// Per-vertex weights summing to 1, positive inside the polygon
// ----------------------------------------------------------------

mean_value_coords :: proc(p: [2]f32, verts: [][2]f32, out: []f32) {
    n := len(verts)

    for i in 0..<n {
        j := (i + 1) % n
        k := (i + n - 1) % n

        vi := [2]f32{verts[i].x - p.x, verts[i].y - p.y}
        vj := [2]f32{verts[j].x - p.x, verts[j].y - p.y}
        vk := [2]f32{verts[k].x - p.x, verts[k].y - p.y}

        ri := math.sqrt(vi.x*vi.x + vi.y*vi.y)
        if ri < 1e-6 {
            for idx in 0..<n do out[idx] = 0
            out[i] = 1
            return
        }

        rj     := math.sqrt(vj.x*vj.x + vj.y*vj.y)
        rk     := math.sqrt(vk.x*vk.x + vk.y*vk.y)
        cos_a  := clamp((vi.x*vj.x + vi.y*vj.y) / (ri * rj), -1, 1)
        cos_b  := clamp((vk.x*vi.x + vk.y*vi.y) / (rk * ri), -1, 1)
        a      := math.acos(cos_a)
        b      := math.acos(cos_b)
        out[i]  = (math.tan(a * 0.5) + math.tan(b * 0.5)) / ri
    }

    sum := f32(0)
    for w in out do sum += w
    if sum < 1e-8 do return
    for i in 0..<n do out[i] /= sum
}

// ----------------------------------------------------------------
// Surface evaluation at a local-2D point
// Blends Hermite edge curves weighted by mean value coords
// w_buf: caller-allocated scratch []f32 of len N — avoids alloc in hot path
// ----------------------------------------------------------------

eval_surface :: proc(
    p2d:     [2]f32,
    poly:    Polygon,
    local2d: [][2]f32,
    w_buf:   []f32,
) -> (pos: Vec3, norm: Vec3) {
    n := len(poly.verts)
    mean_value_coords(p2d, local2d, w_buf)

    pos_sum  := Vec3{}
    norm_sum := Vec3{}
    w_total  := f32(0)

    for i in 0..<n {
        j      := (i + 1) % n
        wi     := w_buf[i]
        wj     := w_buf[j]
        edge_w := wi * wj
        if edge_w < 1e-8 do continue

        t  := wj / (wi + wj)
        p0 := poly.verts[i];  p1 := poly.verts[j]
        t0 := poly.normals[i] * TANGENT_SCALE
        t1 := poly.normals[j] * TANGENT_SCALE

        epos   := hermite_pos(p0, t0, p1, t1, t)
        ederiv := hermite_deriv(p0, t0, p1, t1, t)

        pos_sum  += edge_w * epos
        norm_sum += edge_w * math.normalize(ederiv)
        w_total  += edge_w
    }

    if w_total < 1e-8 do return {}, {}
    return pos_sum / w_total, math.normalize(norm_sum / w_total)
}

// ----------------------------------------------------------------
// Sample 4 pixel corners, average, write to screen
// ----------------------------------------------------------------

sample_and_write :: proc(
    corners:       [4][2]f32,
    poly:          Polygon,
    local2d:       [][2]f32,
    w_buf:         []f32,
    pixels:        []u8,
    width, height: int,
    cam:           Camera,
) {
    avg_pos  := Vec3{}
    avg_norm := Vec3{}
    valid    := 0

    for c in corners {
        if !point_in_polygon(c, local2d) do continue
        cp, cn := eval_surface(c, poly, local2d, w_buf)
        avg_pos  += cp
        avg_norm += cn
        valid    += 1
    }
    if valid == 0 do return

    avg_pos  /= f32(valid)
    avg_norm  = math.normalize(avg_norm)

    screen, ok := project(avg_pos, cam, width, height)
    if !ok do return

    color := Vec3{
        (avg_norm.x + 1) * 0.5 * 255,
        (avg_norm.y + 1) * 0.5 * 255,
        (avg_norm.z + 1) * 0.5 * 255,
    }
    write_pixel(pixels, int(screen.x), int(screen.y), width, height, color)
}

// ----------------------------------------------------------------
// Estimate adaptive step sizes in local 2D
// Returns (su, sv) so that 1 step ≈ 1 screen pixel at center
// ----------------------------------------------------------------

estimate_steps :: proc(
    poly:          Polygon,
    local2d:       [][2]f32,
    w_buf:         []f32,
    cam:           Camera,
    width, height: int,
    center:        [2]f32,
) -> (su, sv: f32) {
    PROBE :: f32(0.01)

    c3d, _    := eval_surface(center, poly, local2d, w_buf)
    sc, ok_c  := project(c3d, cam, width, height)

    pu3d, _   := eval_surface({center.x + PROBE, center.y}, poly, local2d, w_buf)
    spu, ok_u := project(pu3d, cam, width, height)

    pv3d, _   := eval_surface({center.x, center.y + PROBE}, poly, local2d, w_buf)
    spv, ok_v := project(pv3d, cam, width, height)

    su = PROBE; sv = PROBE

    if ok_c && ok_u {
        d := math.length([2]f32{spu.x - sc.x, spu.y - sc.y})
        if d > 0.0001 do su = PROBE / d
    }
    if ok_c && ok_v {
        d := math.length([2]f32{spv.x - sc.x, spv.y - sc.y})
        if d > 0.0001 do sv = PROBE / d
    }
    return
}

// ----------------------------------------------------------------
// Interior: Scanline
// Walks bounding box in local 2D row by row
// ----------------------------------------------------------------

fill_interior_scanline :: proc(
    pixels:        []u8,
    width, height: int,
    poly:          Polygon,
    cam:           Camera,
) {
    n       := len(poly.verts)
    local2d := make([][2]f32, n)
    w_buf   := make([]f32, n)
    defer delete(local2d)
    defer delete(w_buf)

    for i in 0..<n do local2d[i] = to_local2d(poly.verts[i])

    mn := local2d[0]; mx := local2d[0]
    for v in local2d {
        mn.x = min(mn.x, v.x); mx.x = max(mx.x, v.x)
        mn.y = min(mn.y, v.y); mx.y = max(mx.y, v.y)
    }

    center     := [2]f32{(mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5}
    su, sv     := estimate_steps(poly, local2d, w_buf, cam, width, height, center)

    v := mn.y
    for v <= mx.y {
        u := mn.x
        for u <= mx.x {
            if point_in_polygon([2]f32{u, v}, local2d) {
                corners := [4][2]f32{
                    {u - su*0.5, v - sv*0.5},
                    {u + su*0.5, v - sv*0.5},
                    {u - su*0.5, v + sv*0.5},
                    {u + su*0.5, v + sv*0.5},
                }
                sample_and_write(corners, poly, local2d, w_buf, pixels, width, height, cam)
            }
            u += su
        }
        v += sv
    }
}

// ----------------------------------------------------------------
// Interior: UV
// Walks [0,1]x[0,1], maps to local 2D via planar projection
// Hook: swap generate_planar_uvs for imported poly.uvs when available
// ----------------------------------------------------------------

fill_interior_uv :: proc(
    pixels:        []u8,
    width, height: int,
    poly:          Polygon,
    cam:           Camera,
) {
    n       := len(poly.verts)
    local2d := make([][2]f32, n)
    w_buf   := make([]f32, n)
    defer delete(local2d)
    defer delete(w_buf)

    for i in 0..<n do local2d[i] = to_local2d(poly.verts[i])

    mn := local2d[0]; mx := local2d[0]
    for v in local2d {
        mn.x = min(mn.x, v.x); mx.x = max(mx.x, v.x)
        mn.y = min(mn.y, v.y); mx.y = max(mx.y, v.y)
    }
    rx := mx.x - mn.x; if rx < 1e-6 do rx = 1
    ry := mx.y - mn.y; if ry < 1e-6 do ry = 1

    center_loc := [2]f32{mn.x + 0.5 * rx, mn.y + 0.5 * ry}
    su, sv     := estimate_steps(poly, local2d, w_buf, cam, width, height, center_loc)
    su_uv      := su / rx
    sv_uv      := sv / ry

    v := f32(0)
    for v <= 1.0 {
        u := f32(0)
        for u <= 1.0 {
            loc := [2]f32{mn.x + u * rx, mn.y + v * ry}
            if point_in_polygon(loc, local2d) {
                corners := [4][2]f32{
                    {mn.x + (u - su_uv*0.5) * rx, mn.y + (v - sv_uv*0.5) * ry},
                    {mn.x + (u + su_uv*0.5) * rx, mn.y + (v - sv_uv*0.5) * ry},
                    {mn.x + (u - su_uv*0.5) * rx, mn.y + (v + sv_uv*0.5) * ry},
                    {mn.x + (u + su_uv*0.5) * rx, mn.y + (v + sv_uv*0.5) * ry},
                }
                sample_and_write(corners, poly, local2d, w_buf, pixels, width, height, cam)
            }
            u += su_uv
        }
        v += sv_uv
    }
}

// ----------------------------------------------------------------
// Edge walk
// ----------------------------------------------------------------

fill_edges :: proc(pixels: []u8, width, height: int, poly: Polygon, cam: Camera) {
    n := len(poly.verts)
    for i in 0..<n {
        j  := (i + 1) % n
        p0 := poly.verts[i];  p1 := poly.verts[j]
        t0 := poly.normals[i] * TANGENT_SCALE
        t1 := poly.normals[j] * TANGENT_SCALE

        t := f32(0)
        for t <= 1.0 {
            pos  := hermite_pos(p0, t0, p1, t1, t)
            dpos := hermite_deriv(p0, t0, p1, t1, t)

            screen, ok := project(pos, cam, width, height)
            if ok {
                norm  := math.normalize(dpos)
                color := Vec3{
                    (norm.x + 1) * 0.5 * 255,
                    (norm.y + 1) * 0.5 * 255,
                    (norm.z + 1) * 0.5 * 255,
                }
                write_pixel(pixels, int(screen.x), int(screen.y), width, height, color)
            }

            DT_PROBE :: f32(0.005)
            next_pos       := pos + dpos * DT_PROBE
            screen_next, ok2 := project(next_pos, cam, width, height)

            if ok && ok2 {
                d := math.length([2]f32{screen_next.x - screen.x, screen_next.y - screen.y})
                if d > 0.0001 { t += DT_PROBE / d } else { t += 0.001 }
            } else {
                t += 0.001
            }
        }
    }
}

// ----------------------------------------------------------------
// Modified Types
// ----------------------------------------------------------------

Internal_Quad :: struct {
    p: [4]Vec3,
    n: [4]Vec3,
    is_outer: [4]bool, 
}

// ----------------------------------------------------------------
// Surface Math
// ----------------------------------------------------------------

eval_coons :: proc(q: Internal_Quad, u, v: f32) -> (pos, norm: Vec3) {
    // Edge interp: Hermite for boundaries, Linear for internal cuts
    c0 := q.is_outer[0] ? hermite_pos(q.p[0], q.n[0], q.p[1], q.n[1], u) : math.lerp(q.p[0], q.p[1], u)
    c1 := q.is_outer[1] ? hermite_pos(q.p[1], q.n[1], q.p[2], q.n[2], v) : math.lerp(q.p[1], q.p[2], v)
    c2 := q.is_outer[2] ? hermite_pos(q.p[3], q.n[3], q.p[2], q.n[2], u) : math.lerp(q.p[3], q.p[2], u)
    c3 := q.is_outer[3] ? hermite_pos(q.p[0], q.n[0], q.p[3], q.n[3], v) : math.lerp(q.p[0], q.p[3], v)

    lc_uv := math.lerp(c3, c1, u)
    ld_uv := math.lerp(c0, c2, v)
    b_uv  := math.lerp(math.lerp(q.p[0], q.p[1], u), math.lerp(q.p[3], q.p[2], u), v)

    pos = lc_uv + ld_uv - b_uv
    norm = math.normalize(math.lerp(math.lerp(q.n[0], q.n[1], u), math.lerp(q.n[3], q.n[2], u), v))
    return
}

// ----------------------------------------------------------------
// Subdivision & Rasterization
// ----------------------------------------------------------------

fill_quad :: proc(pixels: []u8, w, h: int, q: Internal_Quad, cam: Camera) {
    v := f32(0)
    for v <= 1.0 {
        u := f32(0)
        // Sample Jacobian at start of row to estimate dv
        p_v0, _ := eval_coons(q, 0, v)
        p_v1, _ := eval_coons(q, 0, v + 0.001)
        s_v0, _ := project(p_v0, cam, w, h)
        s_v1, _ := project(p_v1, cam, w, h)
        dv := 1.0 / (math.length(s_v1 - s_v0) / 0.001 + 0.01)

        for u <= 1.0 {
            pos, norm := eval_coons(q, u, v)
            
            // Adaptive du via screen-space Jacobian
            eps := f32(0.001)
            p_u1, _ := eval_coons(q, u + eps, v)
            s0, ok  := project(pos, cam, w, h)
            s1, _   := project(p_u1, cam, w, h)
            
// Inside your nested loop in fill_quad:
            du := 1.0 / (math.length(s1 - s0) / eps + 0.01)
            
            // Multiply step by 0.75 to overlap samples and prevent stretching gaps
            du *= 0.75 

            if ok {
                color := Vec3{(norm.x + 1) * 127, (norm.y + 1) * 127, (norm.z + 1) * 127}
                // Use splat instead of single pixel
                write_splat(pixels, int(s0.x), int(s0.y), w, h, color)
            }
            u += max(du, 0.001)
        }
        v += max(dv, 0.001)
    }
}

subdivide_and_fill :: proc(pixels: []u8, w, h: int, poly: Polygon, cam: Camera) {
    n := len(poly.verts)
    cp, cn := Vec3{}, Vec3{}
    for i in 0..<n { cp += poly.verts[i]; cn += poly.normals[i] }
    cp /= f32(n); cn = math.normalize(cn)

    for i in 0..<n {
        prev := (i + n - 1) % n
        m_prev_p := (poly.verts[i] + poly.verts[prev]) * 0.5
        m_prev_n := math.normalize(poly.normals[i] + poly.normals[prev])
        
        next := (i + 1) % n
        m_next_p := (poly.verts[i] + poly.verts[next]) * 0.5
        m_next_n := math.normalize(poly.normals[i] + poly.normals[next])

        q := Internal_Quad{
            p = { poly.verts[i], m_next_p, cp, m_prev_p },
            n = { poly.normals[i], m_next_n, cn, m_prev_n },
            is_outer = { true, false, false, true },
        }
        fill_quad(pixels, w, h, q, cam)
    }
}

// ----------------------------------------------------------------
// Entry
// ----------------------------------------------------------------

prepass :: proc(pixels: []u8, width, height: int) {
    
    scene := make_test_scene()
    defer {
        for p in scene do free_polygon(p)
        delete(scene)
    }

    for poly in scene {
        fill_edges(pixels, width, height, poly, cam)
        subdivide_and_fill(pixels, width, height, poly, cam)
    }
}