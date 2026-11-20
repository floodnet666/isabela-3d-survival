shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_rough : filter_linear_mipmap, repeat_enable;

uniform float rock_scale = 0.28;
uniform float crack_scale = 0.24;
uniform float lava_energy = 3.6;

varying vec3 wpos;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
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
	v += 0.25 * vnoise(rot * p * 2.02 + vec2(7.3, 19.4));
	return v / 0.75;
}

float voronoi_f2_f1(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float md1 = 8.0;
	float md2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md1) {
				md2 = md1;
				md1 = d;
			} else if (d < md2) {
				md2 = d;
			}
		}
	}
	return sqrt(md2) - sqrt(md1);
}

float sample_fissure(vec2 p) {
	vec2 flow_w = vec2(fbm2(p * 0.55), fbm2(p * 0.55 + vec2(11.7, 5.3))) * 1.15;
	vec2 jag_w = vec2(vnoise(p * 1.75 + vec2(3.1, 8.7)), vnoise(p * 1.75 + vec2(14.2, 2.9))) * 0.34;
	return voronoi_f2_f1(p * crack_scale + flow_w + jag_w);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 uv = p * rock_scale;
	vec3 r_col = texture(rock_albedo, uv).rgb * vec3(0.28, 0.23, 0.22);
	vec3 r_nrm = texture(rock_normal, uv).rgb;
	float r_rgh = clamp(texture(rock_rough, uv).r * 0.72 + 0.26, 0.34, 0.90);

	// Single-pass domain-warped fracture network + fast ridged micro-veins
	float e1 = sample_fissure(p);
	float ridge_n = 1.0 - abs(vnoise(p * crack_scale * 2.8 + vec2(vnoise(p * 0.45), vnoise(p * 0.45 + 6.4)) * 0.85) * 2.0 - 1.0);

	// Internal slow magma convection + pinch-and-swell pockets
	float flow = fbm2(p * 0.65 - vec2(TIME * 0.08, TIME * 0.05));
	float pinch = smoothstep(0.30, 0.76, fbm2(p * 0.22 + vec2(9.4, 3.1)));
	float pocket = smoothstep(0.24, 0.76, fbm2(p * 0.14 + vec2(2.4, 8.1)));
	float rim_heat = smoothstep(23.5, 34.5, length(p)) * 0.032;
	float w_scale = 0.25 + 0.95 * pinch;

	float magma_core = smoothstep(0.026 * w_scale + rim_heat * 0.5, 0.004, e1) * (0.40 + 0.60 * pocket);
	float magma_rim = smoothstep(0.072 * w_scale + rim_heat, 0.010, e1) * (0.35 + 0.65 * pocket);
	float cooled_crust = smoothstep(0.120 * w_scale + rim_heat, 0.022, e1) * (1.0 - magma_rim);
	float micro_vein = pow(max(ridge_n, 0.0001), 9.0) * smoothstep(0.46, 0.78, fbm2(p * 0.19)) * 0.55;
	float glow_mask = clamp(max(magma_rim, micro_vein), 0.0, 1.0);

	// Physical blackbody thermal gradient
	float thermal = clamp(magma_core * (0.55 + 0.45 * flow) * pocket + micro_vein * 0.18, 0.0, 1.0);
	vec3 hot_col = mix(vec3(0.45, 0.025, 0.005), vec3(1.0, 0.22, 0.012), clamp(magma_rim * 1.15, 0.0, 1.0));
	hot_col = mix(hot_col, vec3(1.0, 0.85, 0.28), smoothstep(0.32, 0.88, thermal));

	ALBEDO = mix(r_col, vec3(0.04, 0.012, 0.008), clamp(glow_mask + cooled_crust * 0.5, 0.0, 1.0));
	NORMAL_MAP = r_nrm;
	NORMAL_MAP_DEPTH = mix(1.75, 0.18, glow_mask);
	ROUGHNESS = mix(r_rgh, 0.24, glow_mask);
	METALLIC = 0.08;
	SPECULAR = 0.48;
	EMISSION = hot_col * (cooled_crust * 0.20 + magma_rim * 0.72 + magma_core * (1.05 + flow * 0.45) + micro_vein * 0.42) * lava_energy;
}
