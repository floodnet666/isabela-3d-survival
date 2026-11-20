shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.08, 0.11, 0.14);
uniform vec3 deep_color : source_color = vec3(0.03, 0.05, 0.07);
uniform float base_roughness : hint_range(0.01, 0.25) = 0.038;
uniform float water_specular : hint_range(0.0, 1.0) = 0.58;

uniform float micro_wave_amp : hint_range(0.0, 0.1) = 0.014;
uniform float micro_wave_speed : hint_range(0.0, 2.0) = 0.12;

uniform vec2 ripple_center_0 = vec2(0.02, 0.20);   // Isabela front foot
uniform vec2 ripple_center_1 = vec2(-0.06, -0.22); // Isabela rear foot
uniform vec2 ripple_center_2 = vec2(-1.55, -2.40); // SK_Droid_Small
uniform vec2 ripple_center_3 = vec2(1.75, -2.85);  // SK_Droid_Tall
uniform float ripple_amp : hint_range(0.0, 0.2) = 0.045;
uniform float ripple_freq : hint_range(1.0, 40.0) = 18.0;
uniform float ripple_speed : hint_range(0.0, 10.0) = 2.6;
uniform float ripple_radius : hint_range(0.2, 6.0) = 1.65;

uniform float organic_wave_strength : hint_range(0.0, 0.2) = 0.048;
uniform float swell_height : hint_range(0.0, 0.08) = 0.016;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.26;
uniform vec3 subsurface_teal : source_color = vec3(0.04, 0.16, 0.21);

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 43.17);
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
	v += 0.25 * vnoise(rot * p * 2.04 + vec2(7.3, 19.1));
	return v / 0.75;
}

float fbm3(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = rot * p * 2.04 + vec2(7.3, 19.1);
		a *= 0.5;
	}
	return v / 0.875;
}

float water_height_q(vec2 q, float t) {
	float h = fbm3(q * 0.85 + vec2(t * 0.42, t * 0.26)) * 0.65;
	h += vnoise(q * 2.35 + vec2(-t * 0.58, t * 0.36)) * 0.35;
	return h;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sw = (sin(wp.x * 0.42 + wp.z * 0.27 + TIME * 0.85) * 0.6
		+ cos(wp.x * -0.31 + wp.z * 0.51 - TIME * 0.65) * 0.4) * swell_height;
	VERTEX.y += sw;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 concentric_grad(vec2 p, vec2 center, float t) {
	vec2 d = p - center;
	float dist = length(d);
	if (dist < 0.04 || dist > ripple_radius) {
		return vec2(0.0);
	}
	float atten = (1.0 - smoothstep(0.15, ripple_radius, dist)) * smoothstep(0.04, 0.12, dist);
	float phase = dist * ripple_freq - t * ripple_speed;
	float deriv = cos(phase) * ripple_freq * ripple_amp * atten;
	return (d / dist) * deriv;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME * max(micro_wave_speed * 6.0, 0.35);

	// Macro wind-gust modulation so mirror slicks alternate organically with wind-rippled water
	float gust = smoothstep(0.28, 0.78, fbm2(p * 0.09 + vec2(TIME * 0.06, -TIME * 0.04)));
	float amp = (organic_wave_strength + micro_wave_amp * 2.2) * mix(0.32, 1.35, gust);

	// Shared domain warp evaluated once per fragment + 3-tap forward difference normal
	vec2 w1 = vec2(fbm2(p * 0.22 + vec2(t * 0.16, -t * 0.11)), fbm2(p * 0.22 + vec2(-t * 0.13, t * 0.15) + vec2(5.2, 1.3)));
	vec2 q = p + (w1 - 0.5) * 1.45;
	float eps = 0.06;
	float h0 = water_height_q(q, t);
	float hx = water_height_q(q + vec2(eps, 0.0), t);
	float hz = water_height_q(q + vec2(0.0, eps), t);
	vec2 grad = vec2(hx - h0, hz - h0) / eps * amp * 0.55;

	// Concentric radial ripples around Isabela's feet and both droids
	grad += concentric_grad(p, ripple_center_0, TIME);
	grad += concentric_grad(p, ripple_center_1, TIME + 0.35);
	grad += concentric_grad(p, ripple_center_2, TIME + 0.80);
	grad += concentric_grad(p, ripple_center_3, TIME + 1.25);

	vec3 world_n = normalize(vec3(-grad.x, 1.0, -grad.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);

	float fresnel = pow(max(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 0.0001), 4.5);

	// Subtle animated underwater solar caustics visible primarily when looking downward
	float c_a = 1.0 - abs(vnoise(p * 0.78 + grad * 1.8 + vec2(TIME * 0.24, -TIME * 0.16)) * 2.0 - 1.0);
	float c_b = 1.0 - abs(vnoise(p * 0.94 - grad * 1.4 + vec2(-TIME * 0.19, TIME * 0.27)) * 2.0 - 1.0);
	float caustics = pow(max(clamp(c_a * c_b, 0.0, 1.0), 0.0001), 2.4) * (1.0 - fresnel) * caustic_strength;

	// Subtle crest micro-sheen on steepest ripple crests
	float crest_sheen = smoothstep(0.11, 0.24, length(grad)) * 0.14;

	vec3 base_water = mix(deep_color + subsurface_teal * 0.45, shallow_color, fresnel);
	base_water += vec3(0.24, 0.42, 0.46) * caustics + vec3(0.45, 0.58, 0.65) * crest_sheen;

	ALBEDO = base_water;
	METALLIC = 0.0;
	SPECULAR = max(water_specular, 0.68);
	ROUGHNESS = clamp(base_roughness + gust * 0.065 + length(grad) * 0.22, 0.022, 0.16);
}
