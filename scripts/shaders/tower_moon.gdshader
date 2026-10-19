shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D moon_albedo : source_color, filter_linear_mipmap;
uniform vec3 light_direction = vec3(0.0, 0.0, 1.0);
uniform float highlight = 0.0;
uniform float disc_radius = 0.43;

void fragment() {
	vec2 p = (UV - vec2(0.5)) / disc_radius;
	float radius_squared = dot(p, p);
	if (radius_squared > 1.0) { discard; }
	// A spherical lighting normal creates a curved terminator over the AI lunar albedo.
	vec3 lunar_normal = vec3(p.x, -p.y, sqrt(max(0.0, 1.0 - radius_squared)));
	float incidence = dot(lunar_normal, normalize(light_direction));
	float day = smoothstep(-0.025, 0.055, incidence) * pow(max(0.0, incidence), 0.32);
	vec3 surface = texture(moon_albedo, UV).rgb;
	vec3 moonlight = vec3(0.92, 0.96, 1.0);
	ALBEDO = surface * moonlight * (0.028 + day * (0.85 + highlight * 0.30));
}
