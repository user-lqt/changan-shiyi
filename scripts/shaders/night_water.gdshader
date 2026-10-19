shader_type spatial;
render_mode cull_disabled;

void fragment() {
	vec2 uv = UV * 8.0;
	float ripples = sin(uv.y * 11.0 + TIME * 1.7 + sin(uv.x * 6.0) * 0.4);
	float sheen = pow(max(0.0, ripples), 16.0) * 0.10;
	ALBEDO = mix(vec3(0.035, 0.085, 0.11), vec3(0.10, 0.22, 0.25), ripples * 0.5 + 0.5);
	ROUGHNESS = 0.34;
	METALLIC = 0.25;
	EMISSION = vec3(0.15, 0.25, 0.28) * sheen;
	NORMAL_MAP = vec3(0.5 + cos(uv.x * 4.0 + TIME) * 0.025,
		0.5 + cos(uv.y * 11.0 + TIME * 1.7) * 0.055, 1.0);
}
