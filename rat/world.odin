package rat
import "vendor:raylib"

World :: struct {
	entity_manager:  EntityManager,
	transforms:      SparseSet(transform_t),
	appearances:     SparseSet(Appearance),
	colliders_aabb:  SparseSet(rectangle_t),
	colliders_circ:  SparseSet(Circle),
	sprite_lib:      SpriteLibrary,
	grid:            SpatialGrid,
	primitives_rect: SparseSet(rectangle_t),
	primitives_circ: SparseSet(Circle),
	sprite_data:     SparseSet(SpriteData),
	timers:          [dynamic]Timer,
	particles:       [dynamic]Particle,
}

create_world :: proc() -> World {
	return World {
		entity_manager = create_entity_manager(),
		transforms = create_sparse_set(transform_t, MAX_ENTITIES),
		appearances = create_sparse_set(Appearance, MAX_ENTITIES),
		colliders_aabb = create_sparse_set(rectangle_t, MAX_ENTITIES),
		colliders_circ = create_sparse_set(Circle, MAX_ENTITIES),
		sprite_lib = init_sprite_lib(),
		grid = create_spatial_grid(),
		primitives_rect = create_sparse_set(rectangle_t, MAX_ENTITIES),
		primitives_circ = create_sparse_set(Circle, MAX_ENTITIES),
		sprite_data = create_sparse_set(SpriteData, MAX_ENTITIES),
		timers = make([dynamic]Timer, 0, 32),
		particles = make([dynamic]Particle, 0, 64),
	}
}

create_object :: proc(
	world: ^World,
	transform: transform_t,
	image: ImageParams,
	bbox: Shape,
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
		},
	)

	if (image.type == .Sprite) {
		add(
			&world.sprite_data,
			id,
			SpriteData {
				sprite_name = image.sprite_name,
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
	case [2]f32:
		add(&world.colliders_aabb, id, rectangle_t{width = val.x, height = val.y})
		break
	case f32:
		add(&world.colliders_circ, id, Circle{radius = val})
		break
	}

	return id
}
