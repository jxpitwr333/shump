package shump

import "core:math"
import "rat"
import "vendor:raylib"

SHIP_SPEED :: 2.0
palette := []raylib.Color{raylib.GRAY, raylib.ORANGE, raylib.YELLOW, raylib.WHITE}

Ship :: struct {
	id:        rat.Id,
	can_shoot: bool,
}

reset_shoot :: proc(world: ^rat.World, t: ^rat.Timer) {
	ship := (^Ship)(t.data)
	ship.can_shoot = true
}

update_ship :: proc(state: ^State, ship: ^Ship) {
	world := &state.world

	// get components
	transform, _ := rat.get(&world.transforms, ship.id)
	sprite, _ := rat.get(&world.sprite_data, ship.id)
	appearance, _ := rat.get(&world.appearances, ship.id)
	bbox, _ := rat.get(&world.colliders_aabb, ship.id)

	// movement
	right_key: i32 = raylib.IsKeyDown(.RIGHT) ? 1 : 0
	left_key: i32 = raylib.IsKeyDown(.LEFT) ? 1 : 0
	up_key: i32 = raylib.IsKeyDown(.UP) ? 1 : 0
	down_key: i32 = raylib.IsKeyDown(.DOWN) ? 1 : 0
	shoot_key: bool = raylib.IsKeyDown(.SPACE)
	move_x: i32 = right_key - left_key
	move_y: i32 = down_key - up_key

	if move_x != 0 {
		rat.set_sprite(sprite, &world.sprite_lib, "ship_side")
		appearance.hflip = move_x
	} else {
		rat.set_sprite(sprite, &world.sprite_lib, "ship")
		appearance.hflip = 1
	}

	if shoot_key && ship.can_shoot {
		ship.can_shoot = false

		rat.add_timer(
			&world.timers,
			rat.Timer{data = ship, frame_target = 15, on_complete = reset_shoot},
		)

		create_projectile(
			state,
			ProjectileDto {
				type = .BULLET,
				position = {transform.position.x, transform.position.y + 4},
				angle = 270,
				speed = 5,
			},
		)
	}

	if move_x != 0 || move_y != 0 {
		rat.create_particle_rad(
			&world.particles,
			rat.ParticleDto {
				pos = transform.position +
				[2]f32{rat.random_range(-2, 2), rat.random_range(-2, 2)},
				angle = 0,
				color = raylib.ORANGE,
				lifetime = 16,
				scale = {2.5, 2.5},
				shape = .CIRCLE,
				shrink = true,
				shrink_factor = 0.1,
				speed = 0,
				color_fade = true,
				color_palette = &palette
			},
		)

		transform.position.x += f32(move_x) * SHIP_SPEED
		transform.position.y += f32(move_y) * SHIP_SPEED
	}

	half_bbox := [2]f32{bbox.width / 2, bbox.height / 2}
	transform.position.x = math.clamp(
		transform.position.x,
		0 + half_bbox.x,
		GAME_WIDTH - half_bbox.x,
	)
	transform.position.y = math.clamp(
		transform.position.y,
		0 + half_bbox.y,
		GAME_HEIGHT - half_bbox.y,
	)
}
