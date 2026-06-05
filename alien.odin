package shump

import "core:math"
import "rat"
import "vendor:raylib"

AlienType :: enum {
	GREEN,
}

Alien :: struct {
	type:  AlienType,
	hp:    f32,
	id:    rat.Id,
	speed: f32,
}

create_alien :: proc(state: ^State, position: [2]f32, type: AlienType) {
	hp: f32 = 0.0
	alien_spr: string = ""
	speed: f32 = 0.0

	switch (type) {
	case .GREEN:
		hp = 3.0
		speed = 0.25
		alien_spr = "alien_green"
	}

	id := rat.create_object(
		&state.world,
		rat.transform_t{position = position, scale = {1, 1}, rotation = 0},
		rat.ImageParams {
			type = .Sprite,
			sprite_name = alien_spr,
			image_index = 0,
			image_speed = 0.1,
			color = raylib.WHITE,
			offset = {0, 0},
			hflip = 1,
			vflip = 1,
			align = .CENTER,
		},
		rat.Box{width = 6, height = 6, layer = LAYER_ENEMY, mask = LAYER_PLAYER},
	)

	alien := Alien {
		type  = type,
		hp    = hp,
		id    = id,
		speed = speed,
	}

	rat.add(state.game.aliens, id, alien)
}

get_alien_color :: proc(type: AlienType) -> raylib.Color {
	switch (type) {
	case .GREEN:
		return raylib.GREEN
	case:
		return raylib.WHITE
	}
}

alien_rotation: f32 = 0.0
alien_rotation_spd: f32 = 5.0

update_aliens :: proc(state: ^State) {
	game := &state.game
	aliens := state.game.aliens

	alien_rotation = math.sin_f32(cast(f32)raylib.GetTime() * alien_rotation_spd) * 15.0

	for eid in rat.entities(aliens) {
		alien := rat.must(aliens, eid)
		transform := rat.fetch(&state.world, eid, rat.transform_t)

		transform.position.y += alien.speed
		transform.rotation = alien_rotation
	}
}

reset_hitflash :: proc(world: ^rat.World, t: ^rat.Timer) {
	app, aok := rat.try_fetch(world, t.entity, rat.Appearance)
	if !aok do return
	app.solid_tint = false
}
