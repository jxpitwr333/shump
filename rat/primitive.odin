package rat

import "vendor:raylib"

// Data transfer object for both collisions and primitives, since they share these values.
// Not used specifically outside of passing as a parameter to build the actual types.
Shape :: union {
	[2]f32, // rectangle bounds
	f32, // radius
}

// structs for both primitives and collisions.
rectangle_t :: struct {
	width, height: f32,
}

Circle :: struct {
	radius: f32,
}

// Collider shape passed to create_object. Distinct from `Shape` because a
// rectangle and an ellipse both carry two floats — a typed union keeps them
// unambiguous. Both are treated as centered on the entity's transform and
// rotated by transform.rotation (see collision.odin).
Ellipse :: struct {
	rx, ry: f32,
}

ColliderShape :: union {
	rectangle_t, // {width, height}
	Ellipse, // {rx, ry}
}

// specific render calls

render_primitive_rects :: proc(world: ^World) {
	for i in 0 ..< world.primitives_rect.count {
		eid := world.primitives_rect.dense[i]

		rect := &world.primitives_rect.data[i]
		transform, tok := get(&world.transforms, eid)
		appearance, aok := get(&world.appearances, eid)
		if !tok || !aok do continue

		raylib.DrawRectanglePro(
			raylib.Rectangle(
				{
					transform.position.x,
					transform.position.y,
					rect.width * transform.scale.x,
					rect.height * transform.scale.y,
				},
			),
			appearance.offset,
			transform.rotation,
			appearance.tint,
		)
	}
}

render_primitive_circs :: proc(world: ^World) {
	for i in 0 ..< world.primitives_circ.count {
		eid := world.primitives_circ.dense[i]

		circle := &world.primitives_circ.data[i]
		transform, tok := get(&world.transforms, eid)
		appearance, aok := get(&world.appearances, eid)
		if !tok || !aok do continue

		raylib.DrawCircleV(
			vec2_add(transform.position, appearance.offset),
			circle.radius,
			appearance.tint,
		)
	}
}
