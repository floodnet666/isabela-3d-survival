shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 space_bg : source_color = vec3(0.012, 0.018, 0.045);
uniform vec3 nebula_a : source_color = vec3(0.08, 0.22, 0.46);
uniform vec3 nebula_b : source_color = vec3(0.18, 0.12, 0.38);

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
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
		p = p * 2.02 + vec2(7.1, 13.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// Deep-space parallax direction from view vector
	vec2 uv = UV * vec2(3.5, 1.6);
	float n1 = fbm(uv * 1.8 + vec2(0.02 * TIME, 0.0));
	float n2 = fbm(uv * 3.4 - vec2(0.01 * TIME, 2.5));
	vec3 col = space_bg + nebula_a * smoothstep(0.35, 0.85, n1) * 0.65 + nebula_b * smoothstep(0.45, 0.90, n2) * 0.45;

	// Crisp multi-layer twinkling starfield
	for (int layer = 0; layer < 2; layer++) {
		float sc = (layer == 0) ? 55.0 : 120.0;
		vec2 gv = fract(uv * sc) - 0.5;
		vec2 id = floor(uv * sc);
		float rnd = hash21(id + float(layer) * 91.7);
		if (rnd > 0.86) {
			vec2 off = vec2(hash21(id * 1.3), hash21(id * 2.7)) - 0.5;
			float d = length(gv - off * 0.55);
			float twinkle = 0.65 + 0.35 * sin(TIME * (2.0 + rnd * 5.0) + rnd * 40.0);
			float star = smoothstep(0.11, 0.01, d) * twinkle * (layer == 0 ? 2.4 : 1.3);
			vec3 scol = mix(vec3(0.75, 0.88, 1.0), vec3(1.0, 0.92, 0.78), fract(rnd * 17.3));
			col += scol * star;
		}
	}

	ALBEDO = col;
	EMISSION = col * 1.15;
}
