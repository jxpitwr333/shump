package shump

import "rat"

// here goes all game related data

// Collision layers — single-bit categories used both for filtering and for
// collision-event dispatch (rat.on_collision keys on these).
LAYER_PLAYER :: u32(1 << 0)
LAYER_ENEMY :: u32(1 << 1)
LAYER_BULLET :: u32(1 << 2)

Game :: struct {
	// Registered with the world, so it's freed by delete_world and entities are
	// auto-removed from it on destroy. We just hold the handle.
	projectiles: ^rat.SparseSet(Projectile),
}

create_game :: proc(world: ^rat.World) -> Game {
	return Game{projectiles = rat.register_component(world, Projectile)}
}

delete_game :: proc(game: ^Game) {
	// projectiles is owned by the world (registered); delete_world frees it.
}
