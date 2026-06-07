package shump

import "core:math/rand"
import "rat"

Formation :: enum i32 {
	V_FORMATION,
	THREE_WALL,
	FOUR_WALL,
}

Spawner :: struct {
	counter: i32,
}

seconds :: #force_inline proc(n: i32) -> i32 {
	return n * 60
}

tile_size: i32 : 8

update_spawner :: proc(spawner: ^Spawner, state: ^State) {
	spawner.counter += 1

	if spawner.counter >= seconds(3) {
		spawner.counter = 0
		//chosen_formation: Formation = rand.choice_enum(Formation)
		chosen_formation := Formation.V_FORMATION

		#partial switch chosen_formation {
		case .THREE_WALL:
			// here we need to determine where to spawn it based on the dimensions.
			// if we count the three wall as starting from the leftmost alien, then it can be
			// spawned in the range [0, 13) (game world: 128/ sprite size: 8 = 16 tiles horizontally)
			// however that is boring, but can be easily fixed when we know that we have landed in those
			// 3 spaces.
			spawn_x := rand.int32_range(0, 16)

			if spawn_x <= 13 {
				for i in 0 ..< 3 {
					create_alien(
						state,
						[2]f32 {
							f32(((spawn_x + i32(i)) * tile_size) + (tile_size / 2)),
							f32(-tile_size),
						},
						.GREEN,
					)
				}
			} else { 	// 14 & 15
				// start spawning from the right
				for i in 0 ..< 3 {
					create_alien(
						state,
						[2]f32 {
							f32(((spawn_x - i32(i)) * tile_size) + (tile_size / 2)),
							f32(-tile_size),
						},
						.GREEN,
					)
				}
			}

		case .FOUR_WALL:
			// same as the three wall
			spawn_x := rand.int32_range(0, 16)

			if spawn_x <= 12 {
				for i in 0 ..< 4 {
					create_alien(
						state,
						[2]f32 {
							f32(((spawn_x + i32(i)) * tile_size) + (tile_size / 2)),
							f32(-tile_size),
						},
						.GREEN,
					)
				}
			} else { 	// 13, 14, 15
				// start spawning from the right
				for i in 0 ..< 4 {
					create_alien(
						state,
						[2]f32 {
							f32(((spawn_x - i32(i)) * tile_size) + (tile_size / 2)),
							f32(-tile_size),
						},
						.GREEN,
					)
				}
			}


		case .V_FORMATION:
			v_center := rand.int32_range(2, 14)

			offsets := [5][2]i32{{0, 0}, {-1, -1}, {1, -1}, {-2, -2}, {2, -2}}

			for offset in offsets {
				alien_x := v_center + offset.x
				alien_y := f32(-tile_size) + f32(offset.y * tile_size)

				create_alien(
					state,
					[2]f32{f32(alien_x * tile_size + (tile_size / 2)), alien_y},
					.GREEN,
				)
			}
		}
	}
}
