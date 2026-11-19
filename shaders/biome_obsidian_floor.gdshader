shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_rough : filter_linear_mipmap, repeat_enable;

uniform float rock_scale = 0.28;
uniform float crack_scale = 0.38;
uniform float lava_energy = 3.4;

varying vec3 wpos;

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.02 + vec2(7.3, 19.4);
		a *= 0.5;
	}
	return v;
}

float voronoi_edge(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg, mr;
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + o - f;
			if (dot(mr - r, mr - r) > 0.0001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return md;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 uv = p * rock_scale;
	// Scorched dark charcoal-obsidian rock slabs (~85% of floor, Ref 5!)
	vec3 r_col = texture(rock_albedo, uv).rgb * vec3(0.30, 0.25, 0.24);
	vec3 r_nrm = texture(rock_normal, uv).rgb;
	float r_rgh = clamp(texture(rock_rough, uv).r * 0.72 + 0.26, 0.34, 0.90);

	// Razor-thin organic fractured magma cracks
	vec2 warp = vec2(fbm(p * 0.24), fbm(p * 0.24 + vec2(11.7, 5.3))) * 0.62;
	float e1 = voronoi_edge(p * crack_scale + warp);
	float e2 = voronoi_edge(p * crack_scale * 2.0 - warp * 0.5);

	// Natural heat intensity pockets so some rock plates stay dark cooled basalt
	float pocket = smoothstep(0.24, 0.74, fbm(p * 0.13 + vec2(2.4, 8.1)));
	float rim_heat = smoothstep(23.0, 34.0, length(p)) * 0.022;
	float pulse = 0.85 + 0.15 * sin(TIME * 1.8 + fbm(p * 0.18) * 6.28);

	float magma_core = smoothstep(0.015 + rim_heat * 0.5, 0.002, e1) * (0.45 + 0.55 * pocket);
	float magma_rim = smoothstep(0.042 + rim_heat, 0.007, e1) * (0.35 + 0.65 * pocket);
	float micro_vein = smoothstep(0.014, 0.002, e2) * smoothstep(0.48, 0.80, fbm(p * 0.18)) * 0.65;
	float glow_mask = clamp(max(magma_rim, micro_vein), 0.0, 1.0);

	// Deep fiery crimson-orange magma with thin yellow-hot center (no blinding white washout)
	vec3 hot_col = mix(vec3(0.95, 0.14, 0.01), vec3(1.0, 0.66, 0.12), clamp(magma_core * 1.2 + micro_vein * 0.25, 0.0, 1.0));

	ALBEDO = mix(r_col, vec3(0.05, 0.015, 0.01), glow_mask);
	NORMAL_MAP = r_nrm;
	NORMAL_MAP_DEPTH = mix(1.65, 0.20, glow_mask);
	ROUGHNESS = mix(r_rgh, 0.22, glow_mask);
	METALLIC = 0.08;
	SPECULAR = 0.45;
	EMISSION = hot_col * (magma_rim * 0.65 + magma_core * 1.25 + micro_vein * 0.45) * lava_energy * pulse;
}
