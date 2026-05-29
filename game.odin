package shump

import "rat"

// here goes all game related data

Game :: struct {
	projectiles: rat.SparseSet(Projectile),
}

create_game :: proc() -> Game {
	return Game{projectiles = rat.create_sparse_set(Projectile, rat.MAX_ENTITIES)}
}

delete_game :: proc(game: ^Game) {
	rat.delete_sparse_set(&game.projectiles)
}
