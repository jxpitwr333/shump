package rat

import "core:math"
import rl "vendor:raylib"

ParticleShapes :: enum {
	RECTANGLE,
	CIRCLE,
}

Particle :: struct {
	pos:               [2]f32,
	scale:             [2]f32,
	velocity:          [2]f32,
	color:             rl.Color,
	lifetime:          i32, // in frames
	starting_lifetime: i32,
	shape:             ParticleShapes,
	shrink:            bool,
	shrink_factor:     f32,
	color_fade:        bool,
	color_palette:     ^[]rl.Color,
}

ParticleDto :: struct {
	pos:               [2]f32,
	scale:             [2]f32,
	speed:             f32,
	angle:             f32,
	color:             rl.Color,
	lifetime:          i32, // in frames
	starting_lifetime: i32,
	shrink:            bool,
	shrink_factor:     f32,
	shape:             ParticleShapes,
	color_fade:        bool,
	color_palette:     ^[]rl.Color,
}

CreateParticleDeg :: proc(particle_array: ^[dynamic]Particle, template: ParticleDto) {
	particle := Particle {
		pos               = template.pos,
		scale             = template.scale,
		velocity          = FromPolarDeg(template.speed, template.angle),
		color             = template.color,
		lifetime          = template.lifetime,
		starting_lifetime = template.lifetime,
		shrink            = template.shrink,
		shrink_factor     = template.shrink_factor,
		shape             = template.shape,
		color_fade        = template.color_fade,
		color_palette     = template.color_palette,
	}
	append(particle_array, particle)
}

CreateParticleRad :: proc(particle_array: ^[dynamic]Particle, template: ParticleDto) {
	particle := Particle {
		pos               = template.pos,
		scale             = template.scale,
		velocity          = FromPolarRad(template.speed, template.angle),
		color             = template.color,
		lifetime          = template.lifetime,
		starting_lifetime = template.lifetime,
		shrink            = template.shrink,
		shrink_factor     = template.shrink_factor,
		shape             = template.shape,
		color_fade        = template.color_fade,
		color_palette     = template.color_palette,
	}
	append(particle_array, particle)
}

// angle from the passed dto parameter is ignored here because why would it be used.
CreateRadialParticleExplosion :: proc(
	particle_array: ^[dynamic]Particle,
	template: ParticleDto,
	n: int,
	variation: bool,
) {
	angle_step: f32 = f32(math.TAU) / f32(n)
	for i in 0 ..< n {
		angle: f32 = f32(i) * angle_step
		if variation do angle += random_range(-2.0, 2.0)

		particle_dto := template
		particle_dto.angle = angle
		CreateParticleRad(particle_array, particle_dto)
	}
}

UpdateParticles :: proc(particle_array: ^[dynamic]Particle) {
	for i := len(particle_array) - 1; i >= 0; i -= 1 {
		particle := &particle_array[i]

		particle.lifetime -= 1
		if particle.lifetime <= 0 {
			unordered_remove_dynamic_array(particle_array, i)
			continue
		}

		// apply speed
		particle.pos += particle.velocity

		// behaviors:
		// TODO: add more behaviors if desired (fade, grow, etc.)
		if particle.shrink && (particle.scale.x > 0 || particle.scale.y > 0) {
			particle.scale.x -= particle.shrink_factor
			particle.scale.y -= particle.shrink_factor
		}

		if particle.color_fade {
			percentage: f32 = f32(particle.lifetime) / f32(particle.starting_lifetime)
			idx: i32 = i32(math.floor(percentage * f32(len(particle.color_palette))))
			particle.color = particle.color_palette[idx]
		}
	}
}

DrawParticles :: proc(particleArray: ^[dynamic]Particle) {
	for &particle in particleArray {
		switch (particle.shape) {
		case .RECTANGLE:
			rl.DrawRectangleV(particle.pos, particle.scale, particle.color)
		case .CIRCLE:
			rl.DrawEllipse(
				i32(particle.pos.x),
				i32(particle.pos.y),
				particle.scale.x,
				particle.scale.y,
				particle.color,
			)
		}
	}
}
