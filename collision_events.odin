package shump

import "core:time"
import "rat"

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
	alien_appearance := rat.must(&world.appearances, other)

	alien_appearance.solid_tint = true

	time.sleep(2 * time.Millisecond)

	rat.add_timer(
		&world.timers,
		rat.Timer{counter = 0, entity = other, frame_target = 3, on_complete = reset_hitflash},
	)

	if alien.hp <= 0 {
		if t, ok := rat.try_fetch(world, other, rat.transform_t); ok {
			add_screenshake(4)
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
