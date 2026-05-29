package shump

import "rat"
import "vendor:raylib"

ProjectileType :: enum {
	BULLET,
}

Projectile :: struct {
	id:       rat.Id,
	velocity: [2]f32,
	type:     ProjectileType,
}

ProjectileDto :: struct {
	position: [2]f32,
	type:     ProjectileType,
	angle:    f32,
	speed:    f32,
}

StateIdHelper :: struct {
	state: ^State,
	id:    rat.Id,
}

SetFrame :: proc(raw: rawptr) {
	data := (^StateIdHelper)(raw)
	defer free(data)

	sprite_data, ok := rat.get(&data.state.world.sprite_data, data.id)
	if ok {
		sprite_data.image_index = 1
		sprite_data.image_speed = 0
	}
}

create_projectile :: proc(state: ^State, template: ProjectileDto) {
	sprite_name: string = ""
	bbox: [2]f32 = {8, 8}

	switch (template.type) {
	case .BULLET:
		sprite_name = "bullet"
	}

	image := rat.ImageParams {
		type        = .Sprite,
		color       = raylib.WHITE,
		hflip       = 1,
		vflip       = 1,
		image_index = 1,
		image_speed = 1,
		offset      = {-4, -4}, /*hardcoded*/
		sprite_name = sprite_name,
	}

	id := rat.create_object(
		&state.world,
		rat.transform_t {
			position = template.position,
			rotation = template.angle, // this is probably deg to rad mismatch
			scale    = {1, 1},
		},
		image,
		bbox,
	)

	rat.add(
		&state.game.projectiles,
		id,
		Projectile {
			id = id,
			type = template.type,
			velocity = rat.FromPolarDeg(template.speed, template.angle),
		},
	)

	data := new(StateIdHelper)
	data.state = state
	data.id = id

	rat.AddTimer(
		&state.world.timers,
		rat.Timer{counter = 0, data = data, frame_target = 1, onComplete = SetFrame},
	)
}

update_projectiles :: proc(state: ^State) {
	for i in 0 ..< state.game.projectiles.count {
		eid := state.game.projectiles.dense[i]

		projectile, pok := rat.get(&state.game.projectiles, eid)
		transform, tok := rat.get(&state.world.transforms, eid)
		// are colliders being rotated?
		bbox, bok := rat.get(&state.world.colliders_aabb, eid)

		if transform.position.y > -bbox.height {
			// need to delete.
		}

		if tok && pok {
			transform.position += projectile.velocity
		}
	}
}
