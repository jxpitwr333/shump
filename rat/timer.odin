package rat

// Called when a Timer reaches its frame_target.
// Use `t.entity` for the common "act on an entity" case, or `t.data` as a
// typed escape hatch when the callback needs extra state.
CallbackAction :: proc(world: ^World, t: ^Timer)

Timer :: struct {
	frame_target: i32,
	counter:      i32,
	entity:       Id, // common payload: the entity this timer acts on
	data:         rawptr, // escape hatch for callbacks needing extra/typed state
	on_complete:   CallbackAction,
}

/*
EXAMPLE OF USAGE :

set_frame :: proc(world: ^rat.World, t: ^rat.Timer) {
	sprite_data, ok := rat.get(&world.sprite_data, t.entity)
	if ok {
		sprite_data.image_index = 1
		sprite_data.image_speed = 0
	}
}

rat.add_timer(
	&state.world.timers,
	rat.Timer{frame_target = 1, entity = id, on_complete = set_frame},
)
*/

add_timer :: proc(timers: ^[dynamic]Timer, timer: Timer) {
	append(timers, timer)
}

update_timers :: proc(world: ^World) {
	timers := &world.timers
	for i := len(timers) - 1; i >= 0; i -= 1 {
		timer := &timers[i]

		if timer.counter < timer.frame_target {
			timer.counter += 1
		}

		if timer.counter >= timer.frame_target {
			// Copy off the array, then remove, then fire — so a callback that
			// schedules another timer (and may realloc this array) can't dangle.
			t := timer^
			unordered_remove_dynamic_array(timers, i)
			if t.on_complete != nil do t.on_complete(world, &t)
		}
	}
}
