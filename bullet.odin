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

set_frame :: proc(world: ^rat.World, t: ^rat.Timer) {
	sprite_data, ok := rat.get(&world.sprite_data, t.entity)
	if ok {
		sprite_data.image_index = 1
		sprite_data.image_speed = 0
	}
}

// Example collision handler, registered in main for (LAYER_BULLET, LAYER_ENEMY).
// Fires once per bullet↔enemy overlap with self=bullet, other=enemy. (Dormant
// until enemy entities exist.) To reach game-wide state inside a handler:
//   state := (^State)(world.user_data)
on_bullet_hits_enemy :: proc(world: ^rat.World, self, other: rat.Id) {
	if t, ok := rat.try_fetch(world, self, rat.transform_t); ok {
		rat.create_radial_particle_explosion(
			&world.particles,
			rat.ParticleDto {
				pos = t.position,
				color = raylib.YELLOW,
				lifetime = 12,
				scale = {1.5, 1.5},
				shape = .CIRCLE,
				shrink = true,
				shrink_factor = 0.12,
			},
			8,
			true,
		)
	}

	// queue (don't mutate inline): both are gone at the next update_world flush
	rat.queue_destroy(world, self) // the bullet
	rat.queue_destroy(world, other) // the enemy
}

create_projectile :: proc(state: ^State, template: ProjectileDto) {
	sprite_name: string = ""
	bbox: rat.ColliderShape = rat.Box {
		width  = 8,
		height = 8,
		layer  = LAYER_BULLET,
		mask   = LAYER_ENEMY,
	}

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
		align       = .CENTER,
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
		state.game.projectiles,
		id,
		Projectile {
			id = id,
			type = template.type,
			velocity = rat.from_polar_deg(template.speed, template.angle),
		},
	)
}

update_projectiles :: proc(state: ^State) {
	world := &state.world
	projectiles := state.game.projectiles

	// Forward iteration: queue_destroy is deferred, so the set isn't mutated
	// mid-loop — no swap-remove gotcha, and the Projectile component is removed
	// automatically (the set is registered) when the entity is destroyed.
	for eid in rat.entities(projectiles) {
		projectile := rat.must(projectiles, eid)
		transform := rat.fetch(world, eid, rat.transform_t)
		bbox := rat.fetch(world, eid, rat.Box)
		sprite_data := rat.fetch(world, eid, rat.SpriteData)

		transform.position += projectile.velocity

		// muzzle-flash one-shot: once it has advanced to frame 1, stop animating
		if sprite_data.image_index == 1 {
			sprite_data.image_speed = 0
		}

		// Bullets travel up the screen; despawn once fully past the top edge.
		if transform.position.y < -bbox.height {
			rat.queue_destroy(world, eid)
		}
	}
}
