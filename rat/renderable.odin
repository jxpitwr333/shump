package rat

import "vendor:raylib"

// How a sprite is positioned/pivoted relative to its transform.position.
// TOP_LEFT (the zero value) keeps the legacy behavior; CENTER places the
// sprite's middle on the transform and rotates about that center — matching
// how colliders are centered, so sprite and hitbox stay aligned.
Alignment :: enum {
	TOP_LEFT,
	CENTER,
}

Appearance :: struct {
	tint:   raylib.Color,
	offset: [2]f32,
	hflip:  i32, // (-1, 1)
	vflip:  i32, // (-1, 1)
	align:  Alignment,
}

SpriteData :: struct {
	sprite_id:     i32, // resolved index into SpriteLibrary (set via set_sprite)
	image_index:   i32,
	frame_counter: f32,
	image_speed:   f32,
}
