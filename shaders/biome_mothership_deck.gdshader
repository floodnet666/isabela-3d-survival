shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D metal_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D metal_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D metal_rough : filter_linear_mipmap, repeat_enable;

uniform float tex_scale = 0.28;
uniform vec3 deck_tint : source_color = vec3(0.36, 0.42, 0.50);
uniform vec3 conduit_color : source_color = vec3(0.14, 0.88, 1.0);
uniform float conduit_energy = 4.2;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 uv = p * tex_scale;
	vec3 m_col = texture(metal_albedo, uv).rgb * deck_tint;
	vec3 m_nrm = texture(metal_normal, uv).rgb;
	float m_rgh = clamp(texture(metal_rough, uv).r * 0.62 + 0.14, 0.14, 0.56);

	// Concentric machined hangar deck rings
	float r = length(p);
	float ang = atan(p.y, p.x);
	float ring_seam = smoothstep(0.08, 0.0, abs(fract(r * 0.14) - 0.5) - 0.45);
	float ring_track = smoothstep(0.06, 0.02, abs(r - 8.5)) + smoothstep(0.08, 0.02, abs(r - 17.0)) + smoothstep(0.09, 0.02, abs(r - 26.0));
	ring_track = clamp(ring_track, 0.0, 1.0);

	// Glowing recessed cyan energy conduits (4 main avenues + dual parallel strips + center reactor ring)
	float ax_x = abs(p.x);
	float ax_z = abs(p.y);
	float strip_x = smoothstep(0.18, 0.05, abs(ax_x - 1.15)) * smoothstep(2.2, 4.0, r) * (1.0 - smoothstep(28.0, 32.0, r));
	float strip_z = smoothstep(0.18, 0.05, abs(ax_z - 1.15)) * smoothstep(2.2, 4.0, r) * (1.0 - smoothstep(28.0, 32.0, r));
	float core_ring = smoothstep(0.24, 0.06, abs(r - 4.2));
	float outer_ring = smoothstep(0.20, 0.05, abs(r - 20.5)) * step(0.15, sin(ang * 16.0));
	float pulse = 0.85 + 0.15 * sin(TIME * 2.4 - r * 0.35);

	float conduit_mask = clamp(max(max(strip_x, strip_z), max(core_ring, outer_ring * 0.75)), 0.0, 1.0);

	// Darken recessed seams & tracks for realistic metallic paneling depth
	vec3 panel_col = m_col * (1.0 - ring_seam * 0.38 - ring_track * 0.42);
	ALBEDO = mix(panel_col, conduit_color * 0.35, conduit_mask);
	NORMAL_MAP = m_nrm;
	NORMAL_MAP_DEPTH = 1.25;
	METALLIC = mix(0.84, 0.15, conduit_mask);
	ROUGHNESS = mix(m_rgh, 0.12, conduit_mask);
	SPECULAR = 0.65;
	EMISSION = conduit_color * conduit_mask * conduit_energy * pulse;
}
