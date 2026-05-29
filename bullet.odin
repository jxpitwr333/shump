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

SetFrame :: proc(world: ^rat.World, t: ^rat.Timer) {
	sprite_data, ok := rat.get(&world.sprite_data, t.entity)
	if ok {
		sprite_data.image_index = 1
		sprite_data.image_speed = 0
	}
}

create_projectile :: proc(state: ^State, template: ProjectileDto) {
	sprite_name: string = ""
	bbox: rat.ColliderShape = rat.rectangle_t{width = 8, height = 8}

	switch (template.type) {
	case .BULLET:
		sprite_name = "bullet"
	}

	image := rat.ImageParams {
		type        = .Sprite,
		color       = raylib.WHITE,
		hflip       = 1,
		vflip       = 1,
		image_index = 0,
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
}

update_projectiles :: proc(state: ^State) {
	projectiles := &state.game.projectiles

	// Iterate backwards: despawning swap-removes the last element into the
	// current slot, so going high→low never skips or revisits an entity.
	for i := int(projectiles.count) - 1; i >= 0; i -= 1 {
		eid := projectiles.dense[i]

		projectile, pok := rat.get(projectiles, eid)
		transform, tok := rat.get(&state.world.transforms, eid)
		// are colliders being rotated?
		bbox, bok := rat.get(&state.world.colliders_aabb, eid)
		sprite_data, sok := rat.get(&state.world.sprite_data, eid)

		if !pok || !tok do continue

		transform.position += projectile.velocity

		if sok {
			if sprite_data.image_index == 1 {
				sprite_data.image_speed = 0
				sprite_data.image_index = 1
			}
		}

		// Bullets travel up the screen; despawn once fully past the top edge.
		if bok && transform.position.y < -bbox.height {
			rat.remove(projectiles, eid) // game-side set
			rat.destroy_object(&state.world, eid) // engine components + id
		}
	}
}
