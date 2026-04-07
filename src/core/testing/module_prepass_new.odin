package testing

import vault "../_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"

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



// ------------------------------------------------
// Types
// ------------------------------------------------

Vec3 :: [3]f32
Vec2 :: [2]f32

Camera :: struct {
    pos: Vec3,
    dir: Vec3, // unused until cam rotation is implemented
    fov: f32,  // radians, horizontal
}

Polygon :: struct {
    verts:   []Vec3,
    normals: []Vec3,
}

// ------------------------------------------------
// Test data
// ------------------------------------------------

// Verts on a circle, normals tilted outward+up like a dome patch
make_test_polygon :: proc(center: Vec3, n: int, radius: f32) -> Polygon {
    verts   := make([]Vec3, n)
    normals := make([]Vec3, n)
    for i in 0..<n {
        angle := f32(i) / f32(n) * math.TAU
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
    polys := make([]Polygon, 3)
    polys[0] = make_test_polygon({-4, 0, 0}, 3, 1.5) // triangle
    polys[1] = make_test_polygon({ 0, 0, 0}, 4, 1.5) // quad
    polys[2] = make_test_polygon({ 4, 0, 0}, 6, 1.5) // hexagon
    return polys
}

free_polygon :: proc(p: Polygon) {
    delete(p.verts)
    delete(p.normals)
}

// ------------------------------------------------
// Hermite curve
// ------------------------------------------------

// Tangent scale: controls how strongly normals bend the edge
TANGENT_SCALE :: f32(1.0)

hermite_pos :: proc(p0, t0, p1, t1: Vec3, t: f32) -> Vec3 {
    t2 := t * t
    t3 := t2 * t
    return (2*t3 - 3*t2 + 1)*p0 +
           (  t3 - 2*t2 + t)*t0 +
           (-2*t3 + 3*t2    )*p1 +
           (  t3 -   t2     )*t1
}

// Derivative of position w.r.t. t — used for adaptive stepping
hermite_deriv :: proc(p0, t0, p1, t1: Vec3, t: f32) -> Vec3 {
    t2 := t * t
    return (6*t2 - 6*t    )*p0 +
           (3*t2 - 4*t + 1)*t0 +
           (-6*t2 + 6*t   )*p1 +
           (3*t2 - 2*t    )*t1
}

// ------------------------------------------------
// Projection
// ------------------------------------------------

// Returns screen pixel coords and whether the point is in front of camera
// Camera looks down -Z in world space for now
// Rotation via cam.dir is a stub — replace when cam is ready
project :: proc(p: Vec3, cam: Camera, w, h: int) -> (Vec2, bool) {
    rel := p - cam.pos

    // TODO: apply cam.dir rotation here
    // rel = rotate(rel, cam.dir)

    if rel.z >= 0 do return {}, false // behind camera

    aspect   := f32(w) / f32(h)
    inv_tan  := 1.0 / math.tan(cam.fov * 0.5)

    // NDC: -1..1 on both axes, X accounts for aspect
    ndc_x :=  (rel.x / -rel.z) * inv_tan / aspect
    ndc_y :=  (rel.y / -rel.z) * inv_tan

    px := (ndc_x + 1) * 0.5 * f32(w)
    py := (1 - (ndc_y + 1) * 0.5) * f32(h)

    return {px, py}, true
}

// ------------------------------------------------
// Pixel write
// ------------------------------------------------

write_pixel :: proc(pixels: []u8, x, y, w, h: int, color: Vec3) {
    if x < 0 || x >= w || y < 0 || y >= h do return
    idx := (y * w + x) * 3
    pixels[idx + 0] = u8(clamp(color.x, 0, 255))
    pixels[idx + 1] = u8(clamp(color.y, 0, 255))
    pixels[idx + 2] = u8(clamp(color.z, 0, 255))
}

// ------------------------------------------------
// Prepass
// ------------------------------------------------

prepass :: proc(pixels: []u8, width, height: int) {
    cam := Camera{
        pos = {0, 3, 12},
        dir = {0, 0, -1},
        fov = math.PI / 2.0, // 90 degrees horizontal
    }

    // TODO: object rotation transform goes here (not implemented)

    scene := make_test_scene()
    defer {
        for p in scene do free_polygon(p)
        delete(scene)
    }

    for poly in scene {
        n := len(poly.verts)

        // Walk each edge of the polygon
        for i in 0..<n {
            j  := (i + 1) % n
            p0 := poly.verts[i]
            p1 := poly.verts[j]
            t0 := poly.normals[i] * TANGENT_SCALE
            t1 := poly.normals[j] * TANGENT_SCALE

            // Adaptive walk: step size set so each step ≈ 1 pixel on screen
            t := f32(0)
            for t <= 1.0 {
                pos  := hermite_pos(p0, t0, p1, t1, t)
                dpos := hermite_deriv(p0, t0, p1, t1, t)

                screen, ok := project(pos, cam, width, height)
                if ok {
                    // Visualize by normal-derived color — placeholder, replace with shader
                    norm := math.normalize(dpos)
                    color := Vec3{
                        (norm.x + 1) * 0.5 * 255,
                        (norm.y + 1) * 0.5 * 255,
                        (norm.z + 1) * 0.5 * 255,
                    }
                    write_pixel(pixels, int(screen.x), int(screen.y), width, height, color)
                }

                // Estimate screen-space coverage of this derivative step
                DT_PROBE :: f32(0.005)
                next_pos   := pos + dpos * DT_PROBE
                screen_next, ok2 := project(next_pos, cam, width, height)

                if ok && ok2 {
                    screen_dist := math.length(screen_next - screen)
                    if screen_dist > 0.0001 {
                        // Scale dt so we move exactly 1 pixel
                        t += DT_PROBE / screen_dist
                    } else {
                        t += 0.001 // degenerate fallback
                    }
                } else {
                    t += 0.001
                }
            }
        }
    }


    // TODO: interior fill — next step
}