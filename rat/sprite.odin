package rat

import "core:fmt"
import "vendor:raylib"

Sprite :: struct {
	frames:       []raylib.Texture2D,
	total_frames: i32,
	path:         string,
}

ImageParamType :: enum {
	Sprite,
	Primitive,
}

// Temporary transfer object for the merger of sprite and sprite_data.ble data.
// Not to be used anywhere else than the create_object API function.
ImageParams :: struct {
	type:        ImageParamType,
	// if Sprite
	sprite_name: string,
	image_index: i32,
	image_speed: f32,
	// if Primitive
	shape:       Shape,
	// general/appearance
	color:       raylib.Color,
	offset:      [2]f32,
	hflip:       i32,
	vflip:       i32,
}

get_sprite :: proc(lib: ^SpriteLibrary, name: string) -> ^Sprite {
	id, exists := lib.path_to_id[name]
	assert(exists, "Sprite name not found in library manifest!")

	spr := &lib.sprites[id]

	if len(spr.frames) == 0 {
		spr.frames = make([]raylib.Texture2D, spr.total_frames)

		for i in 0 ..< spr.total_frames {
			path: string
			if spr.total_frames > 1 {
				path = fmt.tprintf("assets/%s_%d.png", spr.path, i)
			} else {
				path = fmt.tprintf("assets/%s.png", spr.path)
			}

			spr.frames[i] = raylib.LoadTexture(fmt.ctprintf(path))
		}
	}

	return spr
}

render_sprites :: proc(world: ^World) {
	for i in 0 ..< world.sprite_data.count {
		eid := world.sprite_data.dense[i]

		sprite_data, _ := get(&world.sprite_data, eid)
		appearance, _ := get(&world.appearances, eid)
		transform, _ := get(&world.transforms, eid)

		sprite := get_sprite(&world.sprite_lib, sprite_data.sprite_name)

		sprite_data.frame_counter += sprite_data.image_speed
		//update animation
		if (sprite_data.frame_counter >= 1.0) {
			sprite_data.frame_counter -= 1.0
			sprite_data.image_index += 1

			if (sprite_data.image_index >= sprite.total_frames) {
				sprite_data.image_index = 0
			}
		}

		// draw
		/*raylib.DrawTextureEx(
			sprite.frames[sprite_data.image_index],
			vec2_add(transform.position, appearance.offset),
			transform.rotation,
			transform.scale.x, // FIXME: use scale vector properly
			raylib.WHITE,
		)*/

		position := vec2_add(transform.position, appearance.offset)
		frame := sprite.frames[sprite_data.image_index]

		dims := [2]f32{f32(frame.width), f32(frame.height)}

		raylib.DrawTexturePro(
			frame,
			raylib.Rectangle{0, 0, dims.x * f32(appearance.hflip), dims.y * f32(appearance.vflip)},
			raylib.Rectangle {
				position.x,
				position.y,
				dims.x * transform.scale.x,
				dims.y * transform.scale.y,
			},
			{0, 0},
			transform.rotation,
			appearance.tint,
		)
	}
}
