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
	damage : f32,
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
// Fires once per bullet↔enemy overlap with self=bullet, other=enemy.
// To reach game-wide state inside a handler:
// state := (^State)(world.user_data)
// when deleting, queue (don't mutate inline): both are gone at the next update_world flush
on_bullet_hits_enemy :: proc(world: ^rat.World, self, other: rat.Id) {
	state := (^State)(world.user_data)
	projectiles := state.game.projectiles
	aliens := state.game.aliens

	alien := rat.must(aliens, other)
	projectile := rat.must(projectiles, self)

	alien.hp -= projectile.damage

	if alien.hp <= 0 {
		if t, ok := rat.try_fetch(world, other, rat.transform_t); ok {
			rat.create_radial_particle_explosion(
				&world.particles,
				rat.ParticleDto {
					pos = t.position + [2]f32{rat.random_range(-2, 2), rat.random_range(-2, 2)},
					angle = 0,
					color = get_alien_color(alien.type),
					lifetime = 12,
					scale = {2.5, 2.5},
					shape = .CIRCLE,
					shrink = true,
					shrink_factor = 0.1,
					speed = 1.5,
				},
				8,
				true,
			)
		}
		rat.queue_destroy(world, other) // the enemy
	}
	
	rat.queue_destroy(world, self) // the bullet
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
			damage = 1.0,
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
