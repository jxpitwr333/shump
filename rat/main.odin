package rat
import "core:fmt"
import "vendor:raylib"

main :: proc() {
	// init
	world := create_world(512, 512)

	if (load_sprite_manifest(&world.sprite_lib, "assets/sprites.json")) {
		fmt.println("Loaded sprite metadata.")
	}

	// create here
	create_object(
		&world,
		transform_t{position = {20, 20}, scale = {1, 1}, rotation = 0},
		ImageParams{type = .Primitive, shape = [2]f32{20, 20}, color = raylib.RED},
		Box{width = 20, height = 20},
	)
	// end creation

	raylib.InitWindow(512, 512, "Hi!")
	raylib.SetTargetFPS(60)
	defer raylib.CloseWindow()

	for !raylib.WindowShouldClose() {

		update_grid(&world)

		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.RAYWHITE)

		render_system(&world)

		raylib.EndDrawing()
	}
}
