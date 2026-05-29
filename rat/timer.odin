package rat

CallbackAction :: proc(_: rawptr)

Timer :: struct {
	frame_target: i32,
	counter:      i32,
	data:         rawptr,
	onComplete:   CallbackAction,
}

AddTimer :: proc(timers: ^[dynamic]Timer, timer: Timer) {
	append(timers, timer)
}

UpdateTimers :: proc(timers: ^[dynamic]Timer) {
	for i := len(timers) - 1; i >= 0; i -= 1 {
		timer := &timers[i]

		if timer.counter < timer.frame_target {
			timer.counter += 1
		}

		if timer.counter >= timer.frame_target {
			if timer.onComplete != nil do timer.onComplete(timer.data)
			unordered_remove_dynamic_array(timers, i)
		}
	}
}
