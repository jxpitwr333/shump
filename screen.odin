package shump

import "core:math/rand"
import raylib "vendor:raylib"

game_camera: raylib.Camera2D

screenshake: f32 = 0
center: [2]f32 = {GAME_WIDTH / 2.0, GAME_HEIGHT / 2.0}

add_screenshake :: #force_inline proc(amount: f32) {
	screenshake += amount
}

update_screenshake :: proc(cam: ^raylib.Camera2D) {
	if screenshake >= 10.0 do screenshake *= 0.8
	if screenshake > 0.0 do screenshake -= 1.0
	else do screenshake = 0.0

	shake_offset := [2]f32{0, 0}
	if screenshake > 0.0 {
		shake_offset = {
			rand.float32() * screenshake - screenshake / 2.0,
			rand.float32() * screenshake - screenshake / 2.0,
		}
	}

	cam.offset = center + shake_offset
}
