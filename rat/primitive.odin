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

// specific render calls

render_primitive_rects :: proc(world: ^World) {
	for i in 0 ..< world.primitives_rect.count {
		eid := world.primitives_rect.dense[i]

		rect, _ := get(&world.primitives_rect, eid)
		transform, _ := get(&world.transforms, eid)
		appearance, _ := get(&world.appearances, eid)

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
		circle, _ := get(&world.primitives_circ, eid)

		transform, _ := get(&world.transforms, eid)
		appearance, _ := get(&world.appearances, eid)
		raylib.DrawCircleV(
			vec2_add(transform.position, appearance.offset),
			circle.radius,
			appearance.tint,
		)
	}
}
