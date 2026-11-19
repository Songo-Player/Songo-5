shader_type canvas_item;
// The room behind every page: dark, with streetlight falling through venetian
// blinds in slanted bars across the wall. A neon sign outside tints the
// light and now and then stutters. Rain runs down in front, and the whole
// frame carries a little film grain. One pass, no textures.

uniform vec4 base_color : source_color = vec4(0.035, 0.035, 0.039, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.92, 0.85, 1.0);
uniform vec2 rect_size = vec2(640.0, 480.0);
uniform float light_strength = 0.13;
uniform float slats = 11.0;
uniform float rain_amount = 1.0;
uniform float grain_amount = 0.05;
uniform float animate = 1.0;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float t = TIME * animate;
	vec2 px = UV * rect_size;
	float aspect = rect_size.x / rect_size.y;
	vec2 p = vec2(UV.x * aspect, UV.y);

	// The window's light, thrown across the wall at an angle from the top
	// right. The blinds sway a touch.
	float angle = -0.5 + sin(t * 0.21) * 0.012;
	mat2 rot = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	vec2 q = rot * (p - vec2(aspect * 0.78, 0.18));
	// Skew so the projected window widens away from the source.
	q.x *= 1.0 - q.y * 0.35;
	float window = smoothstep(-0.62, -0.5, q.x) * smoothstep(0.62, 0.5, q.x)
		* smoothstep(-0.48, -0.36, q.y) * smoothstep(0.82, 0.62, q.y);
	float band = fract(q.y * slats);
	float slat = smoothstep(0.18, 0.3, band) * smoothstep(0.92, 0.8, band);
	float falloff = clamp(1.15 - length(q) * 0.9, 0.0, 1.0);

	// The neon: a slow breath and the odd stutter.
	float tick = floor(t * 7.0);
	float stutter = step(0.965, hash(tick)) * 0.6;
	float neon = (0.9 + 0.1 * sin(t * 1.7)) * (1.0 - stutter);

	vec3 c = base_color.rgb + light_color.rgb * light_strength * window * slat * falloff * neon;

	// Rain: sparse slanted streaks in a few columns, falling at their own pace.
	if (rain_amount > 0.0) {
		vec2 r = vec2(px.x + px.y * 0.16, px.y);
		float col = floor(r.x / 9.0);
		float h = hash(col);
		float on_column = step(0.6, h);
		float speed = 420.0 + h * 260.0;
		float span = 160.0 + h * 140.0;
		float y = fract((r.y - t * speed) / span + h * 13.0);
		float streak = smoothstep(0.86, 1.0, y) * (1.0 - smoothstep(0.995, 1.0, y));
		float thin = 1.0 - smoothstep(0.0, 0.7, abs(fract(r.x / 9.0) * 9.0 - 4.5));
		// Brighter where it crosses the light.
		float lit = 0.35 + 0.65 * window * slat;
		c += vec3(0.75, 0.78, 0.82) * streak * thin * on_column * 0.09 * lit * rain_amount;
	}

	// Corners fall away into the dark.
	float vignette = smoothstep(1.05, 0.3, distance(UV, vec2(0.5)) * 1.25);
	c *= mix(0.45, 1.0, vignette);

	// Grain, refreshed at film speed.
	float grain = hash2(floor(px) + floor(t * 24.0) * 17.0) - 0.5;
	c += grain * grain_amount;

	COLOR = vec4(c, 1.0);
}
