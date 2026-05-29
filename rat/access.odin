package rat

// Type-directed component access.
//
// Because every component type maps 1:1 to a single sparse set in World, the
// set can be resolved from the type alone. This lets gameplay write
//
//     t := fetch(world, id, transform_t)
//
// instead of naming the internal set (`get(&world.transforms, id)`). Pass the
// component type as the third argument.
//
// fetch     -> asserts the component exists, returns just the pointer.
// try_fetch -> returns (ptr, ok) for maybe-present components.
//
// Adding a new World component? Add one `else when` arm below.

fetch :: proc(world: ^World, id: Id, $T: typeid) -> ^T {
	ptr, ok := try_fetch(world, id, T)
	assert(ok, "fetch: entity is missing this component")
	return ptr
}

try_fetch :: proc(world: ^World, id: Id, $T: typeid) -> (^T, bool) {
	when T == transform_t {
		return get(&world.transforms, id)
	} else when T == Appearance {
		return get(&world.appearances, id)
	} else when T == SpriteData {
		return get(&world.sprite_data, id)
	} else when T == Box {
		return get(&world.colliders_aabb, id)
	} else when T == Ellipse {
		return get(&world.colliders_ellipse, id)
	} else when T == rectangle_t {
		return get(&world.primitives_rect, id)
	} else when T == Circle {
		return get(&world.primitives_circ, id)
	} else {
		#panic("fetch: type is not a registered World component")
	}
}
