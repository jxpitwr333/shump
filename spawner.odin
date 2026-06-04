package shump

import "rat"

EncounterType :: enum {
	V_FORMATION,
	THREE_WALL,
	FOUR_WALL,
}

Encounter :: struct {
	type : EncounterType,
	
}

Spawner :: struct {
	
}

update_spawner :: proc(world: ^rat.World) {

}
