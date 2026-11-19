shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_rough : filter_linear_mipmap, repeat_enable;

uniform sampler2D cliff_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_rough : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv_s = wpos.xz * 0.14;
	vec2 uv_c = vec2(wpos.x + wpos.z, wpos.y) * 0.11;

	vec3 s_col = texture(sand_albedo, uv_s).rgb * vec3(1.10, 0.88, 0.58);
	vec3 s_nrm = texture(sand_normal, uv_s).rgb;
	float s_rgh = clamp(texture(sand_rough, uv_s).r * 0.90 + 0.10, 0.55, 0.96);

	vec3 c_col = texture(cliff_albedo, uv_c).rgb * vec3(0.90, 0.68, 0.44);
	vec3 c_nrm = texture(cliff_normal, uv_c).rgb;
	float c_rgh = clamp(texture(cliff_rough, uv_c).r * 0.92 + 0.08, 0.50, 0.95);

	float rock_mask = 1.0 - smoothstep(0.68, 0.88, clamp(wnrm.y, 0.0, 1.0));
	ALBEDO = mix(s_col, c_col, rock_mask);
	NORMAL_MAP = mix(s_nrm, c_nrm, rock_mask);
	NORMAL_MAP_DEPTH = 1.3;
	ROUGHNESS = mix(s_rgh, c_rgh, rock_mask);
	METALLIC = 0.02;
	SPECULAR = 0.40;
}
