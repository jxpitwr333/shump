package shump

import "core:fmt"
import "rat"
import "vendor:raylib"

WINDOW_WIDTH: f32 : 512
WINDOW_HEIGHT: f32 : 512

GAME_WIDTH: f32 : 128
GAME_HEIGHT: f32 : 128

dest_rect := raylib.Rectangle{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}
src_rect := raylib.Rectangle{0.0, 0.0, GAME_WIDTH, -GAME_HEIGHT}

State :: struct {
	world: rat.World,
	game:  Game,
}

// init
main :: proc() {
	state := State {
		world = rat.create_world(),
		game  = create_game(),
	}

	// defer delete_world(state)
	// defer delete_game(game)

	if (rat.load_sprite_manifest(&state.world.sprite_lib, "assets/sprites/sprites.json")) {
		fmt.println("Loaded sprite metadata.")
	}

	raylib.InitWindow(i32(WINDOW_WIDTH), i32(WINDOW_HEIGHT), "Hi!")
	defer raylib.CloseWindow()
	raylib.SetTargetFPS(60)

	// create here
	ship := Ship {
		id        = rat.create_object(
			&state.world,
			rat.transform_t {
				position = {GAME_WIDTH / 2.0, GAME_HEIGHT / 2.0},
				rotation = 0.0,
				scale = {1.0, 1.0},
			},
			rat.ImageParams {
				color = raylib.WHITE,
				hflip = 1,
				image_index = 0,
				image_speed = 0,
				offset = {-4, -4},
				sprite_name = "ship",
				type = .Sprite,
				vflip = 1,
			},
			rat.rectangle_t{width = 8, height = 8},
		),
		can_shoot = true,
	}
	// end creation

	// window scaling
	target: raylib.RenderTexture2D = raylib.LoadRenderTexture(i32(GAME_WIDTH), i32(GAME_HEIGHT))
	defer raylib.UnloadRenderTexture(target)

	for !raylib.WindowShouldClose() {

		UpdateShip(&state, &ship)
		update_projectiles(&state)
		rat.UpdateTimers(&state.world)
		rat.update_grid(&state.world)
		rat.UpdateParticles(&state.world.particles)

		raylib.BeginTextureMode(target)
		raylib.ClearBackground(raylib.BLACK)
		rat.render_system(&state.world)
		raylib.EndTextureMode()

		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)

		raylib.SetTextureFilter(target.texture, .POINT)
		raylib.DrawTexturePro(target.texture, src_rect, dest_rect, {0, 0}, 0.0, raylib.WHITE)

		raylib.EndDrawing()
	}
}
