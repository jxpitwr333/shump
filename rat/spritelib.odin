package rat

MAX_SPRITES :: 256 //idk

SpriteLibrary :: struct {
	sprites:    []Sprite,
	count:      i32,
	path_to_id: map[string]i32,
}

init_sprite_lib :: proc() -> SpriteLibrary {
	return SpriteLibrary {
		sprites = make([]Sprite, MAX_SPRITES),
		count = 0,
		path_to_id = make(map[string]i32),
	}
}
