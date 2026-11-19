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
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(9.1, 17.3);
		a *= 0.5;
	}
	return v;
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

	// 5 jagged incandescent lava channels carving down from the erupting caldera rim
	vec2 rel = wpos.xz - volcano_center.xz;
	float ang = atan(rel.y, rel.x);
	float h_norm = clamp(wpos.y / max(1.0, summit_y), 0.0, 1.0);
	float meander = (fbm(vec2(ang * 3.8, h_norm * 5.2)) - 0.5) * 0.95;
	float r1 = smoothstep(0.18, 0.018, abs(sin((ang + meander) * 4.5)));
	float r2 = smoothstep(0.14, 0.015, abs(sin((ang * 1.7 - meander * 0.8) * 3.5))) * 0.7;
	float flow_var = smoothstep(0.22, 0.68, fbm(vec2(ang * 2.2, h_norm * 3.2 - TIME * 0.10)));
	float river_mask = clamp(max(r1, r2), 0.0, 1.0) * smoothstep(0.18, 0.42, h_norm) * flow_var;

	// Subtle fiery crater rim glow right at summit lip (no blown-out white bulb)
	float summit_glow = smoothstep(0.90, 0.995, h_norm) * 0.85;
	float heat = clamp(max(river_mask, summit_glow), 0.0, 1.0);
	vec3 lava_col = mix(vec3(1.0, 0.18, 0.01), vec3(1.0, 0.72, 0.16), clamp(river_mask * 0.85 + summit_glow * 0.6, 0.0, 1.0));

	ALBEDO = mix(r_col, vec3(0.08, 0.02, 0.01), heat);
	NORMAL_MAP = r_nrm;
	NORMAL_MAP_DEPTH = 1.5;
	ROUGHNESS = mix(r_rgh, 0.28, heat);
	METALLIC = 0.05;
	EMISSION = lava_col * heat * lava_energy;
}
