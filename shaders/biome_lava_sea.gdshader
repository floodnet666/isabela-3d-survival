shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D crust_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D crust_rough : filter_linear_mipmap, repeat_enable;
uniform float flow_speed = 0.12;
uniform float scale = 0.14;
uniform float energy = 4.4;

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
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm2(vec2 p) {
	float v = 0.5 * vnoise(p);
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	v += 0.25 * vnoise(rot * p * 2.05 + vec2(13.1, 29.7));
	return v / 0.75;
}

float fbm3(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = rot * p * 2.05 + vec2(13.1, 29.7);
		a *= 0.5;
	}
	return v / 0.875;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(wp.x * 0.14 + TIME * 0.55) * cos(wp.z * 0.12 - TIME * 0.42)) * 0.16;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale;
	float t = TIME * flow_speed;
	vec2 q = vec2(fbm2(p + vec2(t, t * 0.4)), fbm2(p + vec2(-t * 0.6, t * 0.8) + vec2(5.2, 1.3)));
	float rope_phase = (p.x + p.y) * 2.2 + (q.x + q.y) * 4.5;
	float rope = sin(rope_phase) * 0.12;
	float heat = clamp(fbm3(p + q * 2.1 + vec2(t * 0.45, -t * 0.28)) + rope, 0.0, 1.0);

	float crust_mask = 1.0 - smoothstep(0.34, 0.52, heat);
	float river = smoothstep(0.34, 0.72, heat);
	float white_hot = smoothstep(0.66, 0.86, heat);

	// Analytic ropy pahoehoe fold normal (avoids 2 extra full domain-warped FBM evaluations per pixel)
	float d_rope = cos(rope_phase) * 0.22 * crust_mask;
	vec3 fold_world_n = normalize(vec3(-d_rope, 1.0, -d_rope));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(fold_world_n, 0.0)).xyz, 0.55));

	vec3 crust = vec3(0.06, 0.025, 0.02);
	vec3 red_lava = vec3(0.98, 0.16, 0.01);
	vec3 yellow_lava = vec3(1.0, 0.82, 0.20);
	vec3 lava_col = mix(red_lava, yellow_lava, white_hot);

	float c_rgh = clamp(texture(crust_rough, wpos.xz * 0.22).r * 0.45 + 0.26, 0.28, 0.65);
	ALBEDO = mix(crust, vec3(0.14, 0.035, 0.01), river);
	NORMAL_MAP = texture(crust_normal, wpos.xz * 0.22).rgb;
	NORMAL_MAP_DEPTH = mix(0.18, 1.55, crust_mask);
	ROUGHNESS = mix(c_rgh, 0.24, river);
	METALLIC = 0.06;
	EMISSION = lava_col * (river * 0.85 + white_hot * 1.35) * energy;
}
