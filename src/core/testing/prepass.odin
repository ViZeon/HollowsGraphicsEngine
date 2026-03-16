package testing

import vault "../_vault"
import data "../modules/data"
import math "core:math/linalg/glsl"

// Runs the prepass for one frame.
// Iterates model fields spatially (front to back), walks polygons,
// applies instance transforms, interpolates surface per pixel,
// writes results to a local screen-space field.
// Returns screen field — caller must call prepass_free after rendering.
prepass_run :: proc(screen_w, screen_h: int) -> vault.Field {
	cam_pos := (^math.vec3)(data.edit(vault.cam_pos))^
	cam_z := cam_pos.z

	// Allocate flat 2D screen field — one cell per pixel
	pixel_count := screen_w * screen_h
	num_u32s := (pixel_count + 31) / 32

	screen_field: vault.Field
	screen_field.bounds = vault.Bounds {
		x = vault.Range{min = 0, max = f32(screen_w)},
		y = vault.Range{min = 0, max = f32(screen_h)},
		z = vault.Range{min = 0, max = 0},
	}
	screen_field.levels = 0
	screen_field.dims = 2
	screen_field.bits_any = make([dynamic]u32, num_u32s)
	screen_field.bits_all = make([dynamic]u32, num_u32s)
	screen_field.data = make([dynamic][dynamic]i32, pixel_count)

	// Walk all model fields
	for fi in 0 ..< len(vault.meta_arrays[.Field]) {
		meta := vault.meta_arrays[.Field][fi]
		if !meta.valid || meta.name != "model_field" do continue

		model_field := (^vault.Field)(vault.arrays[.Field][fi].data)

		// Find all Model_Cache instances referencing this field
		// For now: identity transform only (one instance)
		// TODO: iterate Model_Cache array for multiple instances
		transform := vault.Transform {
			pos   = math.vec3{0, 0, 0},
			rot   = transmute(math.quat)[4]f32{0, 0, 0, 1},
			scale = math.vec3{1, 1, 1},
		}

		prepass_walk_field(model_field, &screen_field, transform, cam_pos, screen_w, screen_h)
	}

	return screen_field
}

// Walks a model field spatially front-to-back, processes each occupied cell's polygons
prepass_walk_field :: proc(
	model_field: ^vault.Field,
	screen_field: ^vault.Field,
	transform: vault.Transform,
	cam_pos: math.vec3,
	screen_w, screen_h: int,
) {
	grid_size := i32(1) << uint(model_field.levels)
	half := grid_size / 2

	bz := model_field.bounds.z.max - model_field.bounds.z.min
	cell_z := bz / f32(grid_size)

	// Walk Z front to back (closest Z to camera first)
	for lz_u := grid_size - 1; lz_u >= 0; lz_u -= 1 {
		cell_world_z := model_field.bounds.z.min + f32(lz_u) * cell_z
		if cell_world_z >= cam_pos.z do continue

		lz := lz_u - half

		for ly_u := i32(0); ly_u < grid_size; ly_u += 1 {
			ly := ly_u - half
			for lx_u := i32(0); lx_u < grid_size; lx_u += 1 {
				lx := lx_u - half

				idx := cell_index(math.ivec3{lx, ly, lz}, model_field.levels, model_field.dims)
				if !cell_get_field(model_field, model_field.levels, idx) do continue
				if len(model_field.data[idx]) == 0 do continue

				prepass_process_cell(
					model_field,
					screen_field,
					idx,
					transform,
					cam_pos,
					screen_w,
					screen_h,
				)
			}
		}
	}
}

// Processes all polygon data in one cell — deduplicates polygon triples,
// checks normal facing, interpolates surface, writes to screen field
prepass_process_cell :: proc(
	model_field: ^vault.Field,
	screen_field: ^vault.Field,
	cell_idx: i32,
	transform: vault.Transform,
	cam_pos: math.vec3,
	screen_w, screen_h: int,
) {
	cell_data := model_field.data[cell_idx]
	if len(cell_data) == 0 do return

	// Data is stored as triples (i0, i1, i2) per polygon
	// Process in groups of 3
	poly_count := len(cell_data) / 3
	for p in 0 ..< poly_count {
		i0 := cell_data[p * 3 + 0]
		i1 := cell_data[p * 3 + 1]
		i2 := cell_data[p * 3 + 2]

		if int(i0) >= len(vault.arrays[.DataPoint]) ||
		   int(i1) >= len(vault.arrays[.DataPoint]) ||
		   int(i2) >= len(vault.arrays[.DataPoint]) {continue}

		dp0 := (^vault.DataPoint)(vault.arrays[.DataPoint][i0].data)
		dp1 := (^vault.DataPoint)(vault.arrays[.DataPoint][i1].data)
		dp2 := (^vault.DataPoint)(vault.arrays[.DataPoint][i2].data)

		// Apply instance transform to positions
		p0 := apply_transform(dp0.pos, transform)
		p1 := apply_transform(dp1.pos, transform)
		p2 := apply_transform(dp2.pos, transform)

		// Apply transform to normals (rotation only, no translation/scale)
		n0 := apply_transform_normal(dp0.normal, transform)
		n1 := apply_transform_normal(dp1.normal, transform)
		n2 := apply_transform_normal(dp2.normal, transform)

		// Polygon average normal
		avg_normal := math.normalize(n0 + n1 + n2)

		// Back-face culling — skip if polygon faces away from camera
		// IMPORTANT: this check uses base geometry normal only.
		// At finer detail levels (displacement maps, normal maps), the effective
		// normal direction may differ. This culling may need revision when
		// finer detail levels are introduced. Do NOT remove this comment.
		to_cam := math.normalize(cam_pos - (p0 + p1 + p2) / 3.0)
		if math.dot(avg_normal, to_cam) <= 0 do continue

		// Project all 3 verts to screen to get pixel coverage region
		px0, py0, ok0 := world_to_pixel(p0, screen_w, screen_h)
		px1, py1, ok1 := world_to_pixel(p1, screen_w, screen_h)
		px2, py2, ok2 := world_to_pixel(p2, screen_w, screen_h)

		// Skip if all verts are off screen
		if !ok0 && !ok1 && !ok2 do continue

		// Pixel bounding box of polygon
		min_px := max(0, min(px0, min(px1, px2)))
		max_px := min(screen_w - 1, max(px0, max(px1, px2)))
		min_py := max(0, min(py0, min(py1, py2)))
		max_py := min(screen_h - 1, max(py0, max(py1, py2)))

		// For each pixel in bbox, interpolate and write
		for py := min_py; py <= max_py; py += 1 {
			for px := min_px; px <= max_px; px += 1 {
				pixel_idx := i32(py * screen_w + px)
				slot := pixel_idx / 32
				bit := u32(pixel_idx % 32)

				// Skip already resolved pixels
				if int(slot) < len(screen_field.bits_any) &&
				   (screen_field.bits_any[slot] & (1 << bit)) != 0 {continue}

				// Get world position for this pixel
				world := pixel_to_world_fov(math.vec2{f32(px), f32(py)}, screen_w, screen_h)

				// Interpolate surface at this world position
				interp_pos, interp_normal := interpolate_surface(p0, n0, p1, n1, p2, n2, world)
				proxy_meta := data.add(
					.DataPoint,
					vault.DataPoint {
						pos = interp_pos,
						normal = interp_normal,
						type = .Vertex,
						ref = vault.REF_INVALID,
					},
				)

				proxy_idx := i32(proxy_meta.index)

				// Verify interpolated point is actually within the polygon
				bary := barycentric(p0, p1, p2, interp_pos)
				if bary.x < -0.01 || bary.y < -0.01 || bary.z < -0.01 do continue

				// Mark pixel resolved
				if int(slot) < len(screen_field.bits_any) {
					screen_field.bits_any[slot] |= (1 << bit)
				}

// Store proxy + original verts
append(&screen_field.data[pixel_idx], proxy_idx)
				append(&screen_field.data[pixel_idx], i0)
				append(&screen_field.data[pixel_idx], i1)
				append(&screen_field.data[pixel_idx], i2)
			}
		}
	}
}

// Applies position transform (translation + scale, no rotation yet)
// TODO: apply quaternion rotation when needed
apply_transform :: proc(pos: math.vec3, t: vault.Transform) -> math.vec3 {
	return pos * t.scale + t.pos
}

// Applies rotation-only transform to a normal
apply_transform_normal :: proc(normal: math.vec3, t: vault.Transform) -> math.vec3 {
	// TODO: apply quaternion rotation to normal
	// For identity transform this is a no-op
	return normal
}

// Checks if a pixel is resolved in the screen field
prepass_pixel_hit :: proc(screen_field: ^vault.Field, px, py, screen_w: int) -> bool {
	pixel_idx := i32(py * screen_w + px)
	slot := pixel_idx / 32
	bit := u32(pixel_idx % 32)
	if int(slot) >= len(screen_field.bits_any) do return false
	return (screen_field.bits_any[slot] & (1 << bit)) != 0
}

// Frees screen field memory
prepass_free :: proc(screen_field: ^vault.Field) {
	for i in 0 ..< len(screen_field.data) {
		delete(screen_field.data[i])
	}
	delete(screen_field.bits_any)
	delete(screen_field.bits_all)
	delete(screen_field.data)
}
