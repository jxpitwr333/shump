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
	align:       Alignment,
}

// Resolve a sprite name to its library index once, so hot loops can hold the
// integer handle instead of re-hashing the name string every frame.
resolve_sprite_id :: proc(lib: ^SpriteLibrary, name: string) -> i32 {
	id, exists := lib.path_to_id[name]
	assert(exists, "Sprite name not found in library manifest!")
	return id
}

// Returns the sprite for a resolved id, lazily loading its frame textures on
// first use.
get_sprite_by_id :: proc(lib: ^SpriteLibrary, id: i32) -> ^Sprite {
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

			spr.frames[i] = raylib.LoadTexture(fmt.ctprintf("%s", path))
		}
	}

	return spr
}

get_sprite :: proc(lib: ^SpriteLibrary, name: string) -> ^Sprite {
	return get_sprite_by_id(lib, resolve_sprite_id(lib, name))
}

// Unloads all loaded frame textures and frees the library's backing storage.
// Must run while the GL context is still alive (i.e. before CloseWindow).
unload_sprite_lib :: proc(lib: ^SpriteLibrary) {
	for i in 0 ..< lib.count {
		spr := &lib.sprites[i]
		for frame in spr.frames {
			raylib.UnloadTexture(frame)
		}
		delete(spr.frames)
	}
	delete(lib.sprites)
	delete(lib.path_to_id)
}

// Point a SpriteData at a different sprite by name. No-op if unchanged, so it's
// safe to call every frame; on an actual change the animation is reset to the
// new sprite's first frame (avoids a stale image_index landing out of range).
set_sprite :: proc(sd: ^SpriteData, lib: ^SpriteLibrary, name: string) {
	id := resolve_sprite_id(lib, name)
	if id == sd.sprite_id do return
	sd.sprite_id = id
	sd.image_index = 0
	sd.frame_counter = 0
}

render_sprites :: proc(world: ^World) {
	for i in 0 ..< world.sprite_data.count {
		eid := world.sprite_data.dense[i]

		// data[i] is this iteration's component directly — no redundant lookup
		sprite_data := &world.sprite_data.data[i]
		appearance, aok := get(&world.appearances, eid)
		transform, tok := get(&world.transforms, eid)
		if !aok || !tok do continue

		sprite := get_sprite_by_id(&world.sprite_lib, sprite_data.sprite_id)

		position := vec2_add(transform.position, appearance.offset)
		frame := sprite.frames[sprite_data.image_index]

		dims := [2]f32{f32(frame.width), f32(frame.height)}
		scaled := [2]f32{dims.x * transform.scale.x, dims.y * transform.scale.y}

		// CENTER pivots the dest rect on its middle, so the sprite is centered
		// on transform.position and rotates about that center (no -half_size
		// offset needed at the call site).
		origin := [2]f32{0, 0}
		if appearance.align == .CENTER {
			// truncate to whole pixels: an odd-sized sprite would otherwise pivot
			// on a half-pixel and smear a column under POINT filtering. Matches
			// the old integer offset behavior.
			origin = {f32(i32(scaled.x * 0.5)), f32(i32(scaled.y * 0.5))}
		}

		raylib.DrawTexturePro(
			frame,
			raylib.Rectangle{0, 0, dims.x * f32(appearance.hflip), dims.y * f32(appearance.vflip)},
			raylib.Rectangle{position.x, position.y, scaled.x, scaled.y},
			origin,
			transform.rotation,
			appearance.tint,
		)

		sprite_data.frame_counter += sprite_data.image_speed
		//update animation
		if (sprite_data.frame_counter >= 1.0) {
			sprite_data.frame_counter -= 1.0
			sprite_data.image_index += 1

			if (sprite_data.image_index >= sprite.total_frames) {
				sprite_data.image_index = 0
			}
		}
	}
}
