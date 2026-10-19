shader_type sky;

// The city is a distant angular backdrop: walking toward the window never reveals
// the edges of a rectangular card. Nearby architectural details remain real geometry.
uniform sampler2D city_view : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 view_span = vec2(2.443461, 1.628974); // 140 x 93.3 degrees

void sky() {
	float yaw = atan(EYEDIR.x, -EYEDIR.z);
	float pitch = asin(clamp(EYEDIR.y, -1.0, 1.0));
	vec2 uv = vec2(0.5 + yaw / view_span.x, 0.5 - pitch / view_span.y);
	vec3 night = mix(vec3(0.025, 0.045, 0.07), vec3(0.06, 0.1, 0.16), clamp(EYEDIR.y, 0.0, 1.0));
	float edge = smoothstep(0.0, 0.04, uv.x) * (1.0 - smoothstep(0.96, 1.0, uv.x));
	edge *= smoothstep(0.0, 0.04, uv.y) * (1.0 - smoothstep(0.96, 1.0, uv.y));
	COLOR = mix(night, texture(city_view, clamp(uv, vec2(0.001), vec2(0.999))).rgb, edge);
}
