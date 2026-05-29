package rat

import "vendor:raylib"

// Data transfer object for both collisions and primitives, since they share these values.
// Not used specifically outside of passing as a parameter to build the actual types.
Shape :: union {
	[2]f32, // rectangle bounds
	f32, // radius
}

// Primitive (drawing) shapes.
rectangle_t :: struct {
	width, height: f32,
}

Circle :: struct {
	radius: f32,
}

// Collider shapes. These are deliberately DISTINCT types from the primitive
// shapes above (even though Box mirrors rectangle_t's fields) so that every
// component type maps 1:1 to a single sparse set — that's what lets
// fetch(world, id, T) resolve the right set purely from the type.
// Both are centered on the entity's transform and rotated by transform.rotation
// (see collision.odin).
Box :: struct {
	width, height: f32,
}

Ellipse :: struct {
	rx, ry: f32,
}

ColliderShape :: union {
	Box, // {width, height}
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
			transform.position + appearance.offset,
			circle.radius,
			appearance.tint,
		)
	}
}
