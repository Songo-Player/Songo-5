shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.8, 1.0);

uniform float glow_size : hint_range(1.0, 40.0) = 6.0;
uniform float glow_intensity : hint_range(0.0, 8.0) = 2.5;
uniform float glow_sharpness : hint_range(0.0, 1.0) = 0.3;

uniform float outer_glow_multiplier : hint_range(0.5, 3.0) = 1.8;
uniform float core_boost : hint_range(0.0, 5.0) = 1.5;

uniform bool animate_pulse = false;
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.5;
uniform float time_value = 0.0;

void fragment() {
	vec4 icon = texture(TEXTURE, UV);

	float glow_mask = 0.0;
	float total_weight = 0.0;

	int steps = 12;

	for (int i = 0; i < steps; i++) {
		float angle = float(i) * (6.28318 / float(steps));
		for (float r = 1.0; r <= glow_size; r += 1.0) {
			vec2 offset = vec2(cos(angle), sin(angle)) * r * TEXTURE_PIXEL_SIZE;
			float a = texture(TEXTURE, UV + offset).a;

			float weight = 1.0 - (r / (glow_size + 1.0));
			glow_mask += a * weight;
			total_weight += weight;
		}
	}

	glow_mask = clamp(glow_mask / (total_weight * 0.5), 0.0, 1.0);

	// Split into inner + outer glow
	float inner_glow = pow(glow_mask, mix(0.2, 1.2, glow_sharpness));
	float outer_glow = pow(glow_mask, 2.5) * outer_glow_multiplier;

	float glow_area_inner = inner_glow * (1.0 - icon.a);
	float glow_area_outer = outer_glow * (1.0 - icon.a);

	float intensity = glow_intensity;

	if (animate_pulse) {
		float pulse = 0.5 + 0.5 * sin(time_value * pulse_speed * 6.28318);
		intensity *= mix(0.6, 1.2, pulse);
	}

	// --- Neon color behavior ---
	vec3 neon_color = glow_color.rgb;

	// Outer soft bloom
	vec3 outer = neon_color * glow_area_outer * (intensity * 0.6);

	// Inner stronger glow
	vec3 inner = neon_color * glow_area_inner * intensity;

	// Core: push toward white + overbright
	vec3 core_color = mix(neon_color, vec3(1.0), 0.4);
	vec3 core = core_color * icon.a * (1.0 + core_boost);

	// Subtle edge boost (makes it feel like a tube)
	float edge = smoothstep(0.0, 0.2, icon.a) * (1.0 - smoothstep(0.2, 1.0, icon.a));
	core += neon_color * edge * 0.5;

	// Combine additively
	vec3 final_rgb = outer + inner + core;

	float final_alpha = max(icon.a, glow_area_inner * intensity);

	COLOR = vec4(final_rgb, final_alpha);
}