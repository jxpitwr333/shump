package rat
import "vendor:raylib"

World :: struct {
	entity_manager:  EntityManager,
	transforms:      SparseSet(transform_t),
	appearances:     SparseSet(Appearance),
	colliders_aabb:  SparseSet(Box),
	colliders_ellipse: SparseSet(Ellipse),
	sprite_lib:      SpriteLibrary,
	grid:            SpatialGrid,
	primitives_rect: SparseSet(rectangle_t),
	primitives_circ: SparseSet(Circle),
	sprite_data:     SparseSet(SpriteData),
	timers:          [dynamic]Timer,
	particles:       [dynamic]Particle,
	destroy_queue:   [dynamic]Id, // entities queued via queue_destroy, flushed in update_world
	components:      map[typeid]ComponentStore, // user component sets registered via register_component
}

create_world :: proc() -> World {
	return World {
		entity_manager = create_entity_manager(),
		transforms = create_sparse_set(transform_t, MAX_ENTITIES),
		appearances = create_sparse_set(Appearance, MAX_ENTITIES),
		colliders_aabb = create_sparse_set(Box, MAX_ENTITIES),
		colliders_ellipse = create_sparse_set(Ellipse, MAX_ENTITIES),
		sprite_lib = init_sprite_lib(),
		grid = create_spatial_grid(),
		primitives_rect = create_sparse_set(rectangle_t, MAX_ENTITIES),
		primitives_circ = create_sparse_set(Circle, MAX_ENTITIES),
		sprite_data = create_sparse_set(SpriteData, MAX_ENTITIES),
		timers = make([dynamic]Timer, 0, 32),
		particles = make([dynamic]Particle, 0, 64),
		destroy_queue = make([dynamic]Id, 0, 32),
		components = make(map[typeid]ComponentStore),
	}
}

create_object :: proc(
	world: ^World,
	transform: transform_t,
	image: ImageParams,
	bbox: ColliderShape,
) -> Id {
	id, ok := entity_create(&world.entity_manager)
	assert(ok, "Failed to create entity, EntityManager is out of capacity.")

	add(&world.transforms, id, transform)

	add(
		&world.appearances,
		id,
		Appearance {
			tint = image.color,
			offset = image.offset,
			hflip = image.hflip,
			vflip = image.vflip,
			align = image.align,
		},
	)

	if (image.type == .Sprite) {
		add(
			&world.sprite_data,
			id,
			SpriteData {
				sprite_id = resolve_sprite_id(&world.sprite_lib, image.sprite_name),
				image_index = image.image_index,
				frame_counter = 0,
				image_speed = image.image_speed,
			},
		)
	} else {
		switch val in image.shape {
		case [2]f32:
			add(&world.primitives_rect, id, rectangle_t{width = val.x, height = val.y})
		case f32:
			add(&world.primitives_circ, id, Circle{radius = val})
		}
	}

	switch val in bbox {
	case Box:
		add(&world.colliders_aabb, id, val)
	case Ellipse:
		add(&world.colliders_ellipse, id, val)
	}

	return id
}

// Removes an entity and all of its components, then recycles the id.
// Idempotent: calling it on an already-destroyed id is a no-op (every live
// entity has a transform, so its presence is used as the liveness check).
// The spatial grid is rebuilt from colliders each frame, so dropping the
// collider components here is enough — no manual grid cleanup required.
destroy_object :: proc(world: ^World, id: Id) {
	if _, alive := get(&world.transforms, id); !alive do return

	remove(&world.transforms, id)
	remove(&world.appearances, id)
	remove(&world.colliders_aabb, id)
	remove(&world.colliders_ellipse, id)
	remove(&world.primitives_rect, id)
	remove(&world.primitives_circ, id)
	remove(&world.sprite_data, id)

	// user-registered component sets (engine doesn't know their type, so it
	// goes through the erased remove proc stored at registration)
	for _, store in world.components {
		store.remove(store.set, id)
	}

	entity_destroy(&world.entity_manager, id)
}

// Queues an entity for destruction at the next update_world flush. Safe to call
// while iterating — nothing is mutated until the flush, so you can loop forward
// over entities() and queue removals without worrying about swap-remove order.
queue_destroy :: proc(world: ^World, id: Id) {
	append(&world.destroy_queue, id)
}

@(private = "file")
flush_destroys :: proc(world: ^World) {
	for id in world.destroy_queue do destroy_object(world, id)
	clear(&world.destroy_queue)
}

// Runs the engine's built-in systems in the correct order. Call once per frame
// after your game-specific update logic and before rendering. Centralizes the
// ordering: queued destroys are applied first, then timers tick, then the grid
// rebuilds to reflect this frame's moves and removals.
update_world :: proc(world: ^World) {
	flush_destroys(world)
	update_timers(world)
	update_grid(world)
	update_particles(&world.particles)
}

// Frees everything create_world allocated, including GPU sprite textures.
// Call before raylib.CloseWindow() so the GL context is still valid.
delete_world :: proc(world: ^World) {
	delete_sparse_set(&world.transforms)
	delete_sparse_set(&world.appearances)
	delete_sparse_set(&world.colliders_aabb)
	delete_sparse_set(&world.colliders_ellipse)
	delete_sparse_set(&world.primitives_rect)
	delete_sparse_set(&world.primitives_circ)
	delete_sparse_set(&world.sprite_data)

	delete_spatial_grid(&world.grid)
	unload_sprite_lib(&world.sprite_lib)
	free_entity_manager(&world.entity_manager)

	delete(world.timers)
	delete(world.particles)
	delete(world.destroy_queue)

	// free each registered user component set, then the registry itself
	for _, store in world.components {
		store.destroy(store.set)
	}
	delete(world.components)
}
