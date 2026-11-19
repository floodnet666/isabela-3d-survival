shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 aurora_green : source_color = vec3(0.12, 0.96, 0.66);
uniform vec3 aurora_violet : source_color = vec3(0.38, 0.36, 0.98);
uniform float intensity = 1.15;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	float t = TIME * 0.18;
	float wave = sin(UV.x * 16.0 + t * 2.2) * 0.5 + 0.5;
	float curtain = vnoise(vec2(UV.x * 12.0 + t, UV.y * 2.0 - t * 0.4));
	float streaks = vnoise(vec2(UV.x * 42.0 - t * 0.6, UV.y * 1.4));
	float v_fade = smoothstep(0.0, 0.30, UV.y) * smoothstep(1.0, 0.22, UV.y);
	float h_fade = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	float a = clamp(curtain * (0.40 + 0.60 * streaks) * (0.60 + 0.40 * wave) * v_fade * h_fade, 0.0, 1.0);
	vec3 col = mix(aurora_green, aurora_violet, smoothstep(0.30, 0.92, UV.y));
	ALBEDO = col;
	ALPHA = a * intensity;
}
