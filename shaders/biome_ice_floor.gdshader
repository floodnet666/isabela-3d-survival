shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D snow_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_rough : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;

uniform float snow_scale = 0.16;
uniform float crack_scale = 0.24;
uniform vec3 deep_ice_color : source_color = vec3(0.14, 0.36, 0.58);
uniform vec3 shallow_ice_color : source_color = vec3(0.46, 0.72, 0.88);
uniform vec3 snow_tint : source_color = vec3(0.92, 0.96, 1.0);

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
		p = p * 2.04 + vec2(13.3, 27.1);
		a *= 0.5;
	}
	return v;
}

float voronoi_crack(vec2 x) {
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
	vec2 uv_s = p * snow_scale;
	vec3 s_col = texture(snow_albedo, uv_s).rgb * snow_tint;
	vec3 s_nrm = texture(snow_normal, uv_s).rgb;
	float s_rgh = clamp(texture(snow_rough, uv_s).r * 0.65 + 0.35, 0.60, 0.95);

	// Subtle organic hairline glacial fractures (not uniform spiderweb)
	vec2 warp = vec2(fbm(p * 0.18), fbm(p * 0.18 + vec2(9.2, 4.1))) * 0.65;
	float c1 = voronoi_crack(p * crack_scale + warp);
	float c2 = voronoi_crack(p * crack_scale * 2.2 - warp * 0.5);
	float crack_vis = smoothstep(0.35, 0.72, fbm(p * 0.12 + vec2(3.1, 7.4)));
	float crack_line = clamp((smoothstep(0.024, 0.003, c1) + smoothstep(0.018, 0.002, c2) * 0.45) * (0.35 + 0.65 * crack_vis), 0.0, 1.0);

	// Deep reflective glacial ice with Fresnel highlight
	float depth_n = fbm(p * 0.10);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 ice_col = mix(deep_ice_color, shallow_ice_color, clamp(depth_n * 0.60 + fresnel * 0.48, 0.0, 1.0));
	ice_col = mix(ice_col, vec3(0.84, 0.94, 1.0), crack_line * 0.72);

	// Rich sweeping wind-blown snow drifts framing reflective blue ice patches (~52% snow, ~48% glossy ice)
	float r_edge = smoothstep(16.0, 30.0, length(p));
	float drift = fbm(p * 0.085 + vec2(p.y * 0.055, -p.x * 0.02));
	float micro = fbm(p * 0.34);
	float snow_mask = smoothstep(0.42, 0.64, drift * 0.82 + micro * 0.22 + r_edge * 0.42);

	vec3 ice_nrm = texture(rock_normal, p * 0.18).rgb;
	ALBEDO = mix(ice_col, s_col, snow_mask);
	NORMAL_MAP = mix(ice_nrm, s_nrm, snow_mask);
	NORMAL_MAP_DEPTH = mix(0.35 + crack_line * 0.65, 1.30, snow_mask);
	ROUGHNESS = mix(clamp(0.08 + crack_line * 0.32, 0.07, 0.46), s_rgh, snow_mask);
	METALLIC = 0.04;
	SPECULAR = mix(0.88, 0.32, snow_mask);
	EMISSION = vec3(0.03, 0.12, 0.22) * (1.0 - snow_mask) * (0.20 + crack_line * 0.40);
}
