package rat

import "vendor:raylib"

// name collision with raylib
transform_t :: struct {
	position: raylib.Vector2,
	scale:    raylib.Vector2,
	rotation: f32,
}
