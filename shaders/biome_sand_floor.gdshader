shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_rough : filter_linear_mipmap, repeat_enable;

uniform sampler2D stone_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_rough : filter_linear_mipmap, repeat_enable;

uniform float sand_scale = 0.24;
uniform float stone_scale = 0.22;
uniform float plaza_radius = 24.5;
uniform vec3 sand_tint : source_color = vec3(1.12, 0.86, 0.52);
uniform vec3 stone_tint : source_color = vec3(1.06, 0.84, 0.56);

varying vec3 wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 31.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_sand = wpos.xz * sand_scale;
	vec2 uv_stone = wpos.xz * stone_scale;

	vec3 s_col = texture(sand_albedo, uv_sand).rgb * sand_tint;
	vec3 s_nrm = texture(sand_normal, uv_sand).rgb;
	float s_rgh = clamp(texture(sand_rough, uv_sand).r * 0.85 + 0.14, 0.55, 0.96);

	vec3 p_col = texture(stone_albedo, uv_stone).rgb * stone_tint;
	vec3 p_nrm = texture(stone_normal, uv_stone).rgb;
	float p_rgh = clamp(texture(stone_rough, uv_stone).r * 0.85 + 0.10, 0.45, 0.92);

	// Sunken ancient temple sandstone flagstones in center with wind-blown golden sand drifts in crevices & edges
	float dist = length(wpos.xz);
	float edge_mask = smoothstep(plaza_radius - 5.5, plaza_radius + 4.0, dist);
	float drift_noise = fbm(wpos.xz * 0.095 + vec2(0.45 * sin(wpos.z * 0.12), 0.0));
	float drift_patches = smoothstep(0.54, 0.76, drift_noise) * 0.82;
	float sand_mask = clamp(max(edge_mask, drift_patches), 0.0, 1.0);

	// Subtle macro sun-baked variation + wind ripples in sand areas
	float ripple = sin(wpos.x * 2.6 + wpos.z * 1.1 + fbm(wpos.xz * 0.5) * 3.0) * 0.04;
	float macro_var = mix(0.84, 1.14, fbm(wpos.xz * 0.055));

	ALBEDO = mix(p_col, s_col * (1.0 + ripple), sand_mask) * macro_var;
	NORMAL_MAP = mix(p_nrm, s_nrm, sand_mask);
	NORMAL_MAP_DEPTH = mix(1.65, 1.20, sand_mask);
	ROUGHNESS = mix(p_rgh, s_rgh, sand_mask);
	METALLIC = 0.02;
	SPECULAR = 0.38;
}
