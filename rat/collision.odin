package rat

import "core:math"
import "vendor:raylib"

CELL_SIZE :: 32
GRID_WIDTH :: 16
GRID_HEIGHT :: 16

SpatialGrid :: struct {
	cells:        [GRID_WIDTH][GRID_HEIGHT][dynamic]Id,
	active_cells: [dynamic][2]u32,
	// per-entity-slot stamp for O(1) dedup during a range query (see
	// get_entities_in_range). A slot was already collected this query iff
	// seen[slot] == seen_tick; bumping the tick invalidates all stamps at once.
	seen:         []u32,
	seen_tick:    u32,
}

create_spatial_grid :: proc() -> SpatialGrid {
	grid: SpatialGrid
	grid.active_cells = make([dynamic][2]u32, 0, 64)
	grid.seen = make([]u32, MAX_ENTITIES) // zero-filled; first tick is 1

	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_HEIGHT {
			grid.cells[x][y] = make([dynamic]u32, 0, 8)
		}
	}
	return grid
}

delete_spatial_grid :: proc(grid: ^SpatialGrid) {
	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_HEIGHT {
			delete(grid.cells[x][y])
		}
	}
	delete(grid.active_cells)
	delete(grid.seen)
}

// -----------------------------------------------------------------------------
// Convex polygon representation
//
// Every collider is reduced to a world-space convex polygon, centered on the
// entity's transform and rotated by transform.rotation (degrees, matching the
// renderer). A rectangle is 4 verts; an ellipse is an N-gon. One SAT test
// (poly_overlap) then handles every shape combination, and rotation is baked
// into the vertices so it comes for free.
// -----------------------------------------------------------------------------

MAX_POLY_VERTS :: 16
ELLIPSE_SEGMENTS :: 12 // facets used to approximate an ellipse; bump for accuracy

Poly :: struct {
	verts: [MAX_POLY_VERTS]raylib.Vector2,
	count: int,
}

// rotate local-space point by `rot_deg` (clockwise in screen space, like raylib
// draw calls) and translate to `center`.
@(private = "file")
place_vert :: #force_inline proc(center: raylib.Vector2, lx, ly, cos_r, sin_r: f32) -> raylib.Vector2 {
	return raylib.Vector2{center.x + lx * cos_r - ly * sin_r, center.y + lx * sin_r + ly * cos_r}
}

make_rect_poly :: proc(center: raylib.Vector2, r: Box, rot_deg: f32) -> Poly {
	hw := r.width * 0.5
	hh := r.height * 0.5

	p: Poly
	p.count = 4

	// fast path: axis-aligned, no trig
	if rot_deg == 0 {
		p.verts[0] = {center.x - hw, center.y - hh}
		p.verts[1] = {center.x + hw, center.y - hh}
		p.verts[2] = {center.x + hw, center.y + hh}
		p.verts[3] = {center.x - hw, center.y + hh}
		return p
	}

	rot := math.to_radians_f32(rot_deg)
	cos_r := math.cos(rot)
	sin_r := math.sin(rot)

	p.verts[0] = place_vert(center, -hw, -hh, cos_r, sin_r)
	p.verts[1] = place_vert(center, hw, -hh, cos_r, sin_r)
	p.verts[2] = place_vert(center, hw, hh, cos_r, sin_r)
	p.verts[3] = place_vert(center, -hw, hh, cos_r, sin_r)
	return p
}

make_ellipse_poly :: proc(center: raylib.Vector2, e: Ellipse, rot_deg: f32) -> Poly {
	rot := math.to_radians_f32(rot_deg)
	cos_r := math.cos(rot)
	sin_r := math.sin(rot)

	p: Poly
	p.count = ELLIPSE_SEGMENTS
	for i in 0 ..< ELLIPSE_SEGMENTS {
		theta := (f32(i) / f32(ELLIPSE_SEGMENTS)) * 2.0 * math.PI
		p.verts[i] = place_vert(center, math.cos(theta) * e.rx, math.sin(theta) * e.ry, cos_r, sin_r)
	}
	return p
}

// world-space convex polygon for an entity's collider at an explicit position.
shape_poly_at :: proc(world: ^World, id: Id, pos: raylib.Vector2, rot_deg: f32) -> (Poly, bool) {
	if r, ok := get(&world.colliders_aabb, id); ok {
		return make_rect_poly(pos, r^, rot_deg), true
	}
	if e, ok := get(&world.colliders_ellipse, id); ok {
		return make_ellipse_poly(pos, e^, rot_deg), true
	}
	return {}, false
}

// world-space convex polygon for an entity's collider at its current transform.
collider_poly :: proc(world: ^World, id: Id) -> (Poly, bool) {
	t, ok := get(&world.transforms, id)
	if !ok do return {}, false
	return shape_poly_at(world, id, t.position, t.rotation)
}

@(private = "file")
poly_bounds :: proc(p: ^Poly) -> (mn: raylib.Vector2, mx: raylib.Vector2) {
	mn = p.verts[0]
	mx = p.verts[0]
	for i in 1 ..< p.count {
		v := p.verts[i]
		mn.x = min(mn.x, v.x)
		mn.y = min(mn.y, v.y)
		mx.x = max(mx.x, v.x)
		mx.y = max(mx.y, v.y)
	}
	return
}

@(private = "file")
project_poly :: proc(p: ^Poly, axis: raylib.Vector2) -> (mn: f32, mx: f32) {
	d := p.verts[0].x * axis.x + p.verts[0].y * axis.y
	mn = d
	mx = d
	for i in 1 ..< p.count {
		dd := p.verts[i].x * axis.x + p.verts[i].y * axis.y
		mn = min(mn, dd)
		mx = max(mx, dd)
	}
	return
}

// returns true if any edge-normal of `p` separates the two polygons.
// (Axes don't need normalizing — we only compare projections on the same axis.)
@(private = "file")
has_separating_axis :: proc(p, q: ^Poly) -> bool {
	for i in 0 ..< p.count {
		a := p.verts[i]
		b := p.verts[(i + 1) % p.count]
		axis := raylib.Vector2{-(b.y - a.y), b.x - a.x} // edge normal

		min_p, max_p := project_poly(p, axis)
		min_q, max_q := project_poly(q, axis)

		if max_p < min_q || max_q < min_p do return true
	}
	return false
}

// Separating Axis Theorem overlap test for two convex polygons.
poly_overlap :: proc(a, b: ^Poly) -> bool {
	if has_separating_axis(a, b) do return false
	if has_separating_axis(b, a) do return false
	return true
}

@(private = "file")
grid_insert :: proc(world: ^World, eid: Id, mn, mx: raylib.Vector2) {
	x_start := clamp(int(mn.x) / CELL_SIZE, 0, GRID_WIDTH - 1)
	y_start := clamp(int(mn.y) / CELL_SIZE, 0, GRID_HEIGHT - 1)
	x_end := clamp(int(mx.x) / CELL_SIZE, 0, GRID_WIDTH - 1)
	y_end := clamp(int(mx.y) / CELL_SIZE, 0, GRID_HEIGHT - 1)

	for gx in x_start ..= x_end {
		for gy in y_start ..= y_end {
			if len(world.grid.cells[gx][gy]) == 0 {
				append(&world.grid.active_cells, [2]u32{u32(gx), u32(gy)})
			}
			append(&world.grid.cells[gx][gy], eid)
		}
	}
}

update_grid :: proc(world: ^World) {
	// clear only used cells
	for coord in world.grid.active_cells {
		clear(&world.grid.cells[coord[0]][coord[1]])
	}
	clear(&world.grid.active_cells)

	// rectangles
	for i in 0 ..< world.colliders_aabb.count {
		eid := world.colliders_aabb.dense[i]
		t, ok := get(&world.transforms, eid)
		if !ok do continue

		poly := make_rect_poly(t.position, world.colliders_aabb.data[i], t.rotation)
		mn, mx := poly_bounds(&poly)
		grid_insert(world, eid, mn, mx)
	}

	// ellipses
	for i in 0 ..< world.colliders_ellipse.count {
		eid := world.colliders_ellipse.dense[i]
		t, ok := get(&world.transforms, eid)
		if !ok do continue

		poly := make_ellipse_poly(t.position, world.colliders_ellipse.data[i], t.rotation)
		mn, mx := poly_bounds(&poly)
		grid_insert(world, eid, mn, mx)
	}
}

get_entities_in_range :: proc(world: ^World, x, y, w, h: f32) -> [dynamic]Id {
	ids := make([dynamic]Id, context.temp_allocator)

	// bump the stamp so every slot is implicitly "unseen" for this query
	world.grid.seen_tick += 1
	tick := world.grid.seen_tick

	x1 := clamp(int(x) / CELL_SIZE, 0, GRID_WIDTH - 1)
	y1 := clamp(int(y) / CELL_SIZE, 0, GRID_HEIGHT - 1)
	x2 := clamp(int(x + w) / CELL_SIZE, 0, GRID_WIDTH - 1)
	y2 := clamp(int(y + h) / CELL_SIZE, 0, GRID_HEIGHT - 1)

	for gx in x1 ..= x2 {
		for gy in y1 ..= y2 {
			for eid in world.grid.cells[gx][gy] {
				slot := get_idx(eid)
				if world.grid.seen[slot] == tick do continue // already collected
				world.grid.seen[slot] = tick
				append(&ids, eid)
			}
		}
	}
	return ids
}

// layer/mask of an entity's collider (either shape). Returns (0,0) if it has
// no collider — treated as "unfiltered" by layers_collide.
@(private = "file")
collider_filter :: proc(world: ^World, id: Id) -> (layer: u32, mask: u32) {
	if b, ok := get(&world.colliders_aabb, id); ok do return b.layer, b.mask
	if e, ok := get(&world.colliders_ellipse, id); ok do return e.layer, e.mask
	return 0, 0
}

// A mover with `a_mask` collides with a target on `b_layer` when their bits
// overlap. A zero on either side means "unfiltered" → always collide, so the
// default (both 0) preserves collide-with-everything behavior.
@(private = "file")
layers_collide :: #force_inline proc(a_mask, b_layer: u32) -> bool {
	return a_mask == 0 || b_layer == 0 || (a_mask & b_layer) != 0
}

// Would entity `id` (rotated by its current transform) overlap any other
// collider if it were moved to (next_x, next_y)? Works for any rect/ellipse mix,
// and skips pairs excluded by layer/mask before the expensive polygon test.
place_meeting :: proc(world: ^World, id: Id, next_x, next_y: f32) -> bool {
	t, tok := get(&world.transforms, id)
	if !tok do return false

	my_poly, ok := shape_poly_at(world, id, {next_x, next_y}, t.rotation)
	if !ok do return false

	_, my_mask := collider_filter(world, id)

	// broadphase: query the grid with the candidate polygon's bounding box
	mn, mx := poly_bounds(&my_poly)
	nearby := get_entities_in_range(world, mn.x, mn.y, mx.x - mn.x, mx.y - mn.y)

	for other_id in nearby {
		if other_id == id do continue

		// layer filter first — cheap, and skips building the other's polygon
		other_layer, _ := collider_filter(world, other_id)
		if !layers_collide(my_mask, other_layer) do continue

		other_poly, ook := collider_poly(world, other_id)
		if !ook do continue

		if poly_overlap(&my_poly, &other_poly) do return true
	}

	return false
}

@(private = "file")
debug_draw_poly :: proc(p: ^Poly, color: raylib.Color) {
	for i in 0 ..< p.count {
		a := p.verts[i]
		b := p.verts[(i + 1) % p.count]
		raylib.DrawLineV(a, b, color)
	}
}

// Draws every collider's outline using the exact same polygons the SAT test
// uses — so what you see (rotation, ellipse facets, center origin) is what
// actually collides. Call inside the game's render pass (e.g. between
// BeginTextureMode and EndTextureMode, after render_system).
debug_draw_collisions :: proc(world: ^World) {
	for i in 0 ..< world.colliders_aabb.count {
		eid := world.colliders_aabb.dense[i]
		t, ok := get(&world.transforms, eid)
		if !ok do continue

		poly := make_rect_poly(t.position, world.colliders_aabb.data[i], t.rotation)
		debug_draw_poly(&poly, raylib.GREEN)
	}

	for i in 0 ..< world.colliders_ellipse.count {
		eid := world.colliders_ellipse.dense[i]
		t, ok := get(&world.transforms, eid)
		if !ok do continue

		poly := make_ellipse_poly(t.position, world.colliders_ellipse.data[i], t.rotation)
		debug_draw_poly(&poly, raylib.LIME)
	}
}