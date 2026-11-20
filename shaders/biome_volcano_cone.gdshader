shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_rough : filter_linear_mipmap, repeat_enable;

uniform vec3 volcano_center = vec3(16.0, 0.0, -96.0);
uniform float summit_y = 58.0;
uniform float lava_energy = 4.2;

varying vec3 wpos;
varying vec3 wnrm;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.2);
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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = rot * p * 2.03 + vec2(9.1, 17.3);
		a *= 0.5;
	}
	return v / 0.875;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = wpos.xz * 0.06 + vec2(0.0, wpos.y * 0.06);
	vec3 r_col = texture(rock_albedo, uv).rgb * vec3(0.24, 0.19, 0.18);
	vec3 r_nrm = texture(rock_normal, uv).rgb;
	float r_rgh = clamp(texture(rock_rough, uv).r * 0.8 + 0.2, 0.45, 0.96);

	// Organic sharp winding FBM-contour lava gullies (~10% of mountain slopes, dark charred basalt elsewhere)
	vec2 rel = wpos.xz - volcano_center.xz;
	float ang = atan(rel.y, rel.x);
	float h_norm = clamp(wpos.y / max(1.0, summit_y), 0.0, 1.0);
	float downhill_adv = h_norm * 4.2 + TIME * 0.08;
	vec2 dir_uv = vec2(cos(ang), sin(ang));
	float warp = (fbm(dir_uv * 2.4 + vec2(downhill_adv * 0.55, 1.7)) - 0.5) * 1.35;

	float d1 = abs(fbm(vec2(ang * 2.8 + warp, downhill_adv * 0.45)) - 0.5);
	float d2 = abs(fbm(vec2(ang * 5.2 - warp * 1.1, downhill_adv * 0.85 + 4.2)) - 0.5);
	float stream_main = smoothstep(0.036, 0.004, d1);
	float stream_branch = smoothstep(0.026, 0.003, d2) * 0.72;
	float gully_gate = smoothstep(0.32, 0.68, fbm(dir_uv * 3.1 + vec2(h_norm * 1.6, 4.3)));
	float river_mask = clamp(max(stream_main, stream_branch) * gully_gate, 0.0, 1.0) * smoothstep(0.24, 0.52, h_norm);

	// Glowing caldera lip at summit edge + subtle ash crater fade
	float summit_glow = smoothstep(0.92, 0.995, h_norm) * 0.88;
	float heat = clamp(max(river_mask, summit_glow), 0.0, 1.0);
	float temp = clamp(river_mask * (0.40 + 0.60 * h_norm) + summit_glow * 0.85, 0.0, 1.0);
	vec3 lava_col = mix(vec3(0.75, 0.09, 0.008), vec3(1.0, 0.28, 0.02), smoothstep(0.15, 0.60, temp));
	lava_col = mix(lava_col, vec3(1.0, 0.78, 0.20), smoothstep(0.58, 0.95, temp));

	ALBEDO = mix(r_col, vec3(0.08, 0.02, 0.01), heat);
	NORMAL_MAP = r_nrm;
	NORMAL_MAP_DEPTH = 1.5;
	ROUGHNESS = mix(r_rgh, 0.28, heat);
	METALLIC = 0.05;
	EMISSION = lava_col * heat * lava_energy;
}
