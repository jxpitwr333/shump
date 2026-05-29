package rat

import "vendor:raylib"

CELL_SIZE :: 32
GRID_WIDTH :: 16
GRID_HEIGHT :: 16

SpatialGrid :: struct {
	cells:        [GRID_WIDTH][GRID_HEIGHT][dynamic]Id,
	active_cells: [dynamic][2]u32,
}

create_spatial_grid :: proc() -> SpatialGrid {
	grid: SpatialGrid
	grid.active_cells = make([dynamic][2]u32, 0, 64)

	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_HEIGHT {
			grid.cells[x][y] = make([dynamic]u32, 0, 8)
		}
	}
	return grid
}

update_grid :: proc(world: ^World) {
	// clear only used cells
	for coord in world.grid.active_cells {
		clear(&world.grid.cells[coord[0]][coord[1]])
	}
	clear(&world.grid.active_cells)

	// log aabbs
	for i in 0 ..< world.colliders_aabb.count {
		eid := world.colliders_aabb.dense[i]
		col := world.colliders_aabb.data[i]
		t, ok := get(&world.transforms, eid)
		if !ok do continue

		x_start := clamp(int(t.position.x) / CELL_SIZE, 0, GRID_WIDTH - 1)
		y_start := clamp(int(t.position.y) / CELL_SIZE, 0, GRID_HEIGHT - 1)
		x_end := clamp(int(t.position.x + col.width) / CELL_SIZE, 0, GRID_WIDTH - 1)
		y_end := clamp(int(t.position.y + col.height) / CELL_SIZE, 0, GRID_HEIGHT - 1)

		for gx in x_start ..= x_end {
			for gy in y_start ..= y_end {
				if len(world.grid.cells[gx][gy]) == 0 {
					append(&world.grid.active_cells, [2]u32{u32(gx), u32(gy)})
				}
				append(&world.grid.cells[gx][gy], eid)
			}
		}
	}

	// log circs
	for i in 0 ..< world.colliders_circ.count {
		eid := world.colliders_circ.dense[i]
		col := world.colliders_circ.data[i]
		t, ok := get(&world.transforms, eid)
		if !ok do continue

		x_start := clamp(int(t.position.x - col.radius) / CELL_SIZE, 0, GRID_WIDTH - 1)
		y_start := clamp(int(t.position.y - col.radius) / CELL_SIZE, 0, GRID_HEIGHT - 1)
		x_end := clamp(int(t.position.x + col.radius) / CELL_SIZE, 0, GRID_WIDTH - 1)
		y_end := clamp(int(t.position.y + col.radius) / CELL_SIZE, 0, GRID_HEIGHT - 1)

		for gx in x_start ..= x_end {
			for gy in y_start ..= y_end {
				if len(world.grid.cells[gx][gy]) == 0 {
					append(&world.grid.active_cells, [2]u32{u32(gx), u32(gy)})
				}
				append(&world.grid.cells[gx][gy], eid)
			}
		}
	}
}

get_entities_in_range :: proc(world: ^World, x, y, w, h: f32) -> [dynamic]Id {
	ids := make([dynamic]Id, context.temp_allocator)

	x1 := clamp(int(x) / CELL_SIZE, 0, GRID_WIDTH - 1)
	y1 := clamp(int(y) / CELL_SIZE, 0, GRID_HEIGHT - 1)
	x2 := clamp(int(x + w) / CELL_SIZE, 0, GRID_WIDTH - 1)
	y2 := clamp(int(y + h) / CELL_SIZE, 0, GRID_HEIGHT - 1)

	for gx in x1 ..= x2 {
		for gy in y1 ..= y2 {
			for eid in world.grid.cells[gx][gy] {
				found := false
				for existing in ids {
					if existing == eid {found = true; break}
				}
				if !found do append(&ids, eid)
			}
		}
	}
	return ids
}

place_meeting :: proc(world: ^World, id: Id, next_x, next_y: f32) -> bool {
	// get which shape is the caller
	my_rect, is_rect := get(&world.colliders_aabb, id)
	my_circ, is_circ := get(&world.colliders_circ, id)

	if !is_rect && !is_circ do return false

	// query area based on shape
	qw, qh: f32
	if is_rect {
		qw, qh = my_rect.width, my_rect.height
	} else {
		qw, qh = my_circ.radius * 2, my_circ.radius * 2
	}

	// grid coords for the hypothetical position
	query_x := is_rect ? next_x : next_x - my_circ.radius
	query_y := is_rect ? next_y : next_y - my_circ.radius

	nearby := get_entities_in_range(world, query_x, query_y, qw, qh)

	for other_id in nearby {
		if other_id == id do continue

		other_t, t_ok := get(&world.transforms, other_id)
		if !t_ok do continue

		// check against rect neighbors
		if target_rect, ok := get(&world.colliders_aabb, other_id); ok {
			r2 := raylib.Rectangle {
				other_t.position.x,
				other_t.position.y,
				target_rect.width,
				target_rect.height,
			}

			if is_rect {
				r1 := raylib.Rectangle{next_x, next_y, my_rect.width, my_rect.height}
				if raylib.CheckCollisionRecs(r1, r2) do return true
			} else {
				center := raylib.Vector2{next_x, next_y} // Assuming circ origin is center
				if raylib.CheckCollisionCircleRec(center, my_circ.radius, r2) do return true
			}
		}

		// check against circle neighbors
		if target_circ, ok := get(&world.colliders_circ, other_id); ok {
			c2_center := raylib.Vector2{other_t.position.x, other_t.position.y}

			if is_rect {
				r1 := raylib.Rectangle{next_x, next_y, my_rect.width, my_rect.height}
				if raylib.CheckCollisionCircleRec(c2_center, target_circ.radius, r1) do return true
			} else {
				c1_center := raylib.Vector2{next_x, next_y}
				if raylib.CheckCollisionCircles(c1_center, my_circ.radius, c2_center, target_circ.radius) do return true
			}
		}
	}

	return false
}
