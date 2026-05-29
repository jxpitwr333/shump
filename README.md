# rat

A small, data-oriented 2D game engine built on [Odin](https://odin-lang.org/) + [raylib](https://www.raylib.com/). Entities are plain integer ids; their data lives in sparse-set component arrays on a central `World`. You write *game code*; `rat` handles storage, iteration, collision, timers, and particles.

```
your game (package shump)        rat (the engine)
  update_ship()        ─uses→     World, components, fetch(), update_world(),
  update_projectiles()            collisions, timers, particles, rendering
```

---

## The one rule

Entities are referenced by a stable **`Id`**. Components are reached through pointers.

> **Hold ids. Fetch component pointers locally each frame. Never cache a component pointer across frames.**

Removing an entity may relocate another's data in memory, so a stashed pointer can silently go stale. Fetching is just an array lookup — cheap enough to redo every frame.

---

## Quick start

```odin
package shump

import "rat"
import rl "vendor:raylib"

main :: proc() {
	world := rat.create_world()
	defer rl.CloseWindow()
	defer rat.delete_world(&world)   // declared after CloseWindow → runs before it

	rat.load_sprite_manifest(&world.sprite_lib, "assets/sprites/sprites.json")

	rl.InitWindow(512, 512, "game")
	rl.SetTargetFPS(60)

	// spawn an entity: transform + how it looks + its collider
	ship := rat.create_object(
		&world,
		rat.transform_t{position = {64, 64}, rotation = 0, scale = {1, 1}},
		rat.ImageParams{type = .Sprite, sprite_name = "ship", align = .CENTER, color = rl.WHITE, hflip = 1, vflip = 1},
		rat.Box{width = 8, height = 8},
	)

	for !rl.WindowShouldClose() {
		// 1. your game logic
		t := rat.fetch(&world, ship, rat.transform_t)
		t.position.x += rl.IsKeyDown(.RIGHT) ? 1 : 0

		// 2. engine systems (timers → grid → particles, in the right order)
		rat.update_world(&world)

		// 3. render
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rat.render_system(&world)
		rl.EndDrawing()

		// 4. free this frame's scratch allocations
		free_all(context.temp_allocator)
	}
}
```

---

## Creating entities

`create_object` builds an entity from three pieces and returns its `Id`:

| Argument        | What it is                                                            |
|-----------------|-----------------------------------------------------------------------|
| `transform_t`   | `position`, `rotation` (degrees), `scale`                             |
| `ImageParams`   | how it draws — a `.Sprite` (by `sprite_name`) or a `.Primitive` shape |
| `ColliderShape` | its hitbox — `Box{width, height}` or `Ellipse{rx, ry}`                |

Sprites can be anchored with `align`:

- `.TOP_LEFT` — `position` is the top-left corner (default).
- `.CENTER` — `position` is the middle; the sprite also **rotates about its center**, matching how colliders are centered. No manual half-size offset needed.

Attach your own gameplay data in a separate component set (see below).

---

## Accessing components

Every component type maps to exactly one set, so you can fetch by **type** instead of naming the set:

```odin
transform  := rat.fetch(&world, id, rat.transform_t)   // asserts it exists, returns ^transform_t
appearance := rat.fetch(&world, id, rat.Appearance)
bbox       := rat.fetch(&world, id, rat.Box)

// maybe-present? use try_fetch
if spr, ok := rat.try_fetch(&world, id, rat.SpriteData); ok {
	spr.image_speed = 0
}
```

Built-in component types: `transform_t`, `Appearance`, `SpriteData`, `Box`, `Ellipse` (colliders), `rectangle_t`, `Circle` (draw primitives).

---

## Your own component sets

`fetch` covers engine components. For game-specific data, keep your own `SparseSet` keyed by the same `Id`:

```odin
Game :: struct {
	projectiles: rat.SparseSet(Projectile),
}
game.projectiles = rat.create_sparse_set(Projectile, rat.MAX_ENTITIES)

rat.add(&game.projectiles, id, Projectile{velocity = {0, -5}})   // attach
p := rat.must(&game.projectiles, id)                              // get (asserts)
ok := rat.has(&game.projectiles, id)                             // test
```

`must` is the assert-it-exists getter; `get` returns `(ptr, ok)` for the maybe-present case.

---

## Iterating & removing

Loop **forward** over a set with `entities`, and **queue** removals — never mutate a set mid-iteration:

```odin
for eid in rat.entities(&game.projectiles) {
	p := rat.must(&game.projectiles, eid)
	t := rat.fetch(&world, eid, rat.transform_t)
	t.position += p.velocity

	if t.position.y < 0 {
		rat.queue_remove(&game.projectiles, eid)   // drop your component
		rat.queue_destroy(&world, eid)             // destroy the engine entity
	}
}
rat.flush_removes(&game.projectiles)               // apply queued removals
```

`queue_destroy` is flushed automatically at the start of the next `update_world`; `queue_remove` is flushed by your `flush_removes` call. Because nothing is removed inline, order never matters — no swap-remove gotchas.

---

## Timers

Schedule a callback N frames out. The common "do something to an entity" case carries the id inline; use `data` for anything else.

```odin
on_done :: proc(world: ^rat.World, t: ^rat.Timer) {
	if sd, ok := rat.try_fetch(world, t.entity, rat.SpriteData); ok do sd.image_speed = 0
}

rat.add_timer(&world.timers, rat.Timer{frame_target = 15, entity = id, on_complete = on_done})
```

---

## Particles

Spawn into `world.particles`; they update and draw as part of the normal loop.

```odin
rat.create_particle_rad(&world.particles, rat.ParticleDto{
	pos = pos, color = rl.ORANGE, lifetime = 16, scale = {2.5, 2.5},
	shape = .CIRCLE, shrink = true, shrink_factor = 0.1,
	color_fade = true, color_palette = &palette,
})

rat.create_radial_particle_explosion(&world.particles, dto, 16, true)   // burst of N
```

---

## Collision

Colliders are convex polygons tested with SAT, so **rotation and ellipses work out of the box**. Query whether an entity would overlap anything at a candidate position:

```odin
if rat.place_meeting(&world, id, next_x, next_y) {
	// blocked
}
```

`rat.debug_draw_collisions(&world)` (call inside the render pass) outlines every collider exactly as the SAT test sees it.

---

## The frame, end to end

```
your update logic          // move, shoot, queue_destroy, ...
rat.update_world(&world)   // flush destroys → timers → spatial grid → particles
rat.render_system(&world)  // particles, sprites, primitives
free_all(context.temp_allocator)
```

That's the whole loop. `rat.delete_world(&world)` frees everything (including GPU textures) at shutdown.

---

## Naming conventions

- **Procedures**: `snake_case` — `create_object`, `update_world`, `add_timer`, `from_polar_deg`.
- **Types**: `PascalCase` — `World`, `SparseSet`, `Appearance`, `Box`. (A few legacy `_t` aliases remain: `transform_t`, `rectangle_t`.)
- **Optional vs required access**: `get`/`try_fetch`/`has` return a flag; `must`/`fetch` assert.
