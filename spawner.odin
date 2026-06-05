package shump

import "core:math/rand"
import "rat"

Formation :: enum i32 {
	V_FORMATION,
	THREE_WALL,
	FOUR_WALL,
	FORMATION_COUNT,
}

Spawner :: struct {
	counter: i32,
}

/*
	lets begin by spawning enemies every 3 seconds in a random formation:
*/

seconds :: #force_inline proc(n: i32) -> i32 {
	return n * 60
}

tile_size: i32 : 8

update_spawner :: proc(spawner: ^Spawner, state: ^State) {
	spawner.counter += 1

	if spawner.counter >= seconds(1) {
		spawner.counter = 0
		//chosen_formation: Formation = Formation(
		//	rand.int32_range(0, i32(Formation.FORMATION_COUNT) - i32(1)),
		//)
		chosen_formation := Formation.THREE_WALL

		#partial switch chosen_formation {
		case .THREE_WALL:
			// here we need to determine where to spawn it based on the dimensions.
			// if we count the three wall as starting from the leftmost alien, then it can be
			// spawned in the range [0, 13) (game world: 128/ sprite size: 8 = 16 tiles horizontally)
			// however that is boring, but can be easily fixed when we know that we have landed in those
			// 3 spaces.
			spawn_x := rand.int32_range(0, 15)

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
		case .V_FORMATION:
		}
	}
}
