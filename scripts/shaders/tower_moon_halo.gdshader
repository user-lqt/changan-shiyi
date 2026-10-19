shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float highlight = 0.0;
void fragment() {
	float r = length(UV - vec2(0.5));
	float halo = exp(-pow((r - 0.335) / 0.048, 2.0));
	ALBEDO = vec3(0.37, 0.57, 0.72);
	ALPHA = halo * (0.055 + 0.10 * highlight);
}
