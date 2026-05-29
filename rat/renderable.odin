package rat

import "vendor:raylib"

// i prefer this.
/*Alignment :: enum {
	TOP_LEFT,
	CENTER,
}*/

Appearance :: struct {
	tint:   raylib.Color,
	offset: [2]f32,
	hflip:  i32, // (-1, 1)
	vflip:  i32, // (-1, 1)
	scale:  [2]f32, //visual scale, does not affect collisions.
}

SpriteData :: struct {
	sprite_name:   string,
	image_index:   i32,
	frame_counter: f32,
	image_speed:   f32,
}
