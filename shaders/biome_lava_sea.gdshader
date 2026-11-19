shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float flow_speed = 0.12;
uniform float scale = 0.14;
uniform float energy = 4.6;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.05 + vec2(13.1, 29.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale;
	float t = TIME * flow_speed;
	vec2 q = vec2(fbm(p + vec2(t, t * 0.4)), fbm(p + vec2(-t * 0.6, t * 0.8) + vec2(5.2, 1.3)));
	float heat = fbm(p + q * 2.2 + vec2(t * 0.5, -t * 0.3));

	// Crust plates vs blazing incandescent lava rivers
	float river = smoothstep(0.30, 0.72, heat);
	float white_hot = smoothstep(0.64, 0.84, heat);

	vec3 crust = vec3(0.09, 0.03, 0.02);
	vec3 red_lava = vec3(1.0, 0.18, 0.01);
	vec3 yellow_lava = vec3(1.0, 0.78, 0.16);
	vec3 lava_col = mix(red_lava, yellow_lava, white_hot);

	ALBEDO = mix(crust, vec3(0.15, 0.04, 0.01), river);
	ROUGHNESS = mix(0.88, 0.25, river);
	METALLIC = 0.05;
	EMISSION = lava_col * (river * 0.9 + white_hot * 1.4) * energy;
}
