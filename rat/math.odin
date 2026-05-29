package rat

vec2_add :: proc(v1: [2]f32, v2: [2]f32) -> [2]f32 {
	return [2]f32{v1[0] + v2[0], v1[1] + v2[1]}
}
