package rat

import "core:math"
import "vendor:raylib"

DEFAULT_CELL_SIZE :: 32

// The broadphase grid is sized at world creation to cover the game's world
// dimensions, so cells aren't wasted on empty space (see create_world).
SpatialGrid :: struct {
	cells:        [][dynamic]Id, // flat grid_w * grid_h
	grid_w:       int,
	grid_h:       int,
	cell_size:    f32,
	active_cells: [dynamic]int, // flat indices of cells touched this frame
	// per-entity-slot stamp for O(1) dedup during a range query (see
	// get_entities_in_range). A slot was already collected this query iff
	// seen[slot] == seen_tick; bumping the tick invalidates all stamps at once.
	seen:         []u32,
	seen_tick:    u32,
}

// world_w/world_h are the game's world size; cell_size tunes granularity
// (smaller = more, finer cells = fewer entities per cell). max_entities sizes
// the dedup stamp array.
create_spatial_grid :: proc(world_w, world_h, cell_size: f32, max_entities: u32) -> SpatialGrid {
	grid: SpatialGrid
	grid.cell_size = cell_size
	grid.grid_w = max(1, int(math.ceil(world_w / cell_size)))
	grid.grid_h = max(1, int(math.ceil(world_h / cell_size)))

	grid.cells = make([][dynamic]Id, grid.grid_w * grid.grid_h)
	for i in 0 ..< len(grid.cells) {
		grid.cells[i] = make([dynamic]Id, 0, 8)
	}
	grid.active_cells = make([dynamic]int, 0, 64)
	grid.seen = make([]u32, max_entities) // zero-filled; first tick is 1
	return grid
}

delete_spatial_grid :: proc(grid: ^SpatialGrid) {
	for i in 0 ..< len(grid.cells) do delete(grid.cells[i])
	delete(grid.cells)
	delete(grid.active_cells)
	delete(grid.seen)
}

@(private = "file")
cell_at :: #force_inline proc(grid: ^SpatialGrid, gx, gy: int) -> int {
	return gy * grid.grid_w + gx
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
	g := &world.grid
	x_start := clamp(int(mn.x / g.cell_size), 0, g.grid_w - 1)
	y_start := clamp(int(mn.y / g.cell_size), 0, g.grid_h - 1)
	x_end := clamp(int(mx.x / g.cell_size), 0, g.grid_w - 1)
	y_end := clamp(int(mx.y / g.cell_size), 0, g.grid_h - 1)

	for gy in y_start ..= y_end {
		for gx in x_start ..= x_end {
			ci := cell_at(g, gx, gy)
			if len(g.cells[ci]) == 0 do append(&g.active_cells, ci)
			append(&g.cells[ci], eid)
		}
	}
}

update_grid :: proc(world: ^World) {
	// clear only used cells
	for ci in world.grid.active_cells {
		clear(&world.grid.cells[ci])
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
	g := &world.grid
	ids := make([dynamic]Id, context.temp_allocator)

	// bump the stamp so every slot is implicitly "unseen" for this query
	g.seen_tick += 1
	tick := g.seen_tick

	x1 := clamp(int(x / g.cell_size), 0, g.grid_w - 1)
	y1 := clamp(int(y / g.cell_size), 0, g.grid_h - 1)
	x2 := clamp(int((x + w) / g.cell_size), 0, g.grid_w - 1)
	y2 := clamp(int((y + h) / g.cell_size), 0, g.grid_h - 1)

	for gy in y1 ..= y2 {
		for gx in x1 ..= x2 {
			for eid in g.cells[cell_at(g, gx, gy)] {
				slot := get_idx(eid)
				if g.seen[slot] == tick do continue // already collected
				g.seen[slot] = tick
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

// -----------------------------------------------------------------------------
// Collision events (GameMaker-style)
//
// Register a handler for an ordered layer pair; it fires once per overlapping
// pair, per registered perspective, with `self` = the entity on the first layer.
// Handlers speak only (world, self, other) — recover your own typed data inside
// via the component registry or by casting world.user_data to your game state.
//
// IMPORTANT: handlers must NOT mutate component sets inline. Queue changes
// (queue_destroy / queue_remove); they are applied at the next update_world.
//
// For dispatch, treat an entity's collider `layer` as a single category bit
// (an exact u32 match against the registered key).
// -----------------------------------------------------------------------------

CollisionHandler :: proc(world: ^World, self: Id, other: Id)

// Registers (or replaces) the handler fired when a `self_layer` collider
// overlaps an `other_layer` collider. Register the reverse pair too if both
// sides should react.
on_collision :: proc(world: ^World, self_layer, other_layer: u32, handler: CollisionHandler) {
	world.collision_handlers[{self_layer, other_layer}] = handler
}

// Fires registered handlers for every overlapping collider pair. Called once
// per frame by update_world; a no-op when no handlers are registered.
process_collisions :: proc(world: ^World) {
	if len(world.collision_handlers) == 0 do return

	for i in 0 ..< world.colliders_aabb.count do collide_entity(world, world.colliders_aabb.dense[i])
	for i in 0 ..< world.colliders_ellipse.count do collide_entity(world, world.colliders_ellipse.dense[i])
}

@(private = "file")
collide_entity :: proc(world: ^World, a: Id) {
	a_poly, ok := collider_poly(world, a)
	if !ok do return
	a_layer, _ := collider_filter(world, a)

	mn, mx := poly_bounds(&a_poly)
	nearby := get_entities_in_range(world, mn.x, mn.y, mx.x - mn.x, mx.y - mn.y)

	for b in nearby {
		// each unordered pair is handled once, by the lower-id entity
		if a >= b do continue

		b_layer, _ := collider_filter(world, b)
		h_ab := world.collision_handlers[{a_layer, b_layer}]
		h_ba := world.collision_handlers[{b_layer, a_layer}]
		if h_ab == nil && h_ba == nil do continue // neither side cares → skip SAT

		b_poly, bok := collider_poly(world, b)
		if !bok do continue
		if !poly_overlap(&a_poly, &b_poly) do continue

		if h_ab != nil do h_ab(world, a, b)
		if h_ba != nil do h_ba(world, b, a)
	}
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