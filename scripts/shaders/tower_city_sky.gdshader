shader_type sky;

// Distant Chang'an is angular scenery, not a rectangular card behind the window.
uniform sampler2D city_view : source_color, filter_linear_mipmap, repeat_disable;

void sky() {
	float yaw = atan(EYEDIR.x, EYEDIR.z);
	float pitch = asin(clamp(EYEDIR.y, -1.0, 1.0));
	vec2 uv = vec2(0.5 + yaw / 2.8, 0.41 - pitch / 1.7);
	vec3 night = mix(vec3(0.016, 0.032, 0.055), vec3(0.035, 0.065, 0.105), clamp(EYEDIR.y, 0.0, 1.0));
	float edge = smoothstep(0.0, 0.09, uv.x) * (1.0 - smoothstep(0.91, 1.0, uv.x));
	edge *= smoothstep(0.0, 0.07, uv.y) * (1.0 - smoothstep(0.93, 1.0, uv.y));
	vec3 city = texture(city_view, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
	COLOR = mix(night, city * vec3(0.79, 0.83, 0.9), edge);
}
