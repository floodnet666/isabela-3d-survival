shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D snow_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_rough : filter_linear_mipmap, repeat_enable;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_rough : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 45.3);
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
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.1 + vec2(7.3, 19.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = vec2(wpos.x + wpos.z, wpos.y) * 0.085;
	vec3 s_col = texture(snow_albedo, uv).rgb * vec3(0.95, 0.98, 1.0);
	vec3 s_nrm = texture(snow_normal, uv).rgb;
	float s_rgh = clamp(texture(snow_rough, uv).r * 0.65 + 0.30, 0.52, 0.94);

	// Crisp dark arctic slate-blue cliff rock (high alpine contrast matching Ref 4!)
	vec3 r_col = texture(rock_albedo, uv * 1.5).rgb * vec3(0.24, 0.36, 0.52);
	vec3 r_nrm = texture(rock_normal, uv * 1.5).rgb;
	float r_rgh = clamp(texture(rock_rough, uv * 1.5).r * 0.65 + 0.25, 0.30, 0.85);

	// Steep jagged rock faces expose dark alpine slate; ledges & ridges collect crisp white snow
	float up = clamp(wnrm.y, 0.0, 1.0);
	float n = fbm(wpos.xz * 0.08 + vec2(wpos.y * 0.06));
	float snow_mask = smoothstep(0.48, 0.76, up + (n - 0.45) * 0.42);

	ALBEDO = mix(r_col, s_col, snow_mask);
	NORMAL_MAP = mix(r_nrm, s_nrm, snow_mask);
	NORMAL_MAP_DEPTH = 1.55;
	ROUGHNESS = mix(r_rgh, s_rgh, snow_mask);
	METALLIC = 0.04;
	SPECULAR = mix(0.55, 0.32, snow_mask);
}
