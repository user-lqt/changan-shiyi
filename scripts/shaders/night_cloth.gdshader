shader_type spatial;
render_mode cull_disabled;

uniform vec4 cloth_color : source_color = vec4(1.0);
uniform float cloth_roughness = 0.9;
uniform float cloth_metallic = 0.0;
uniform vec2 thigh_angles = vec2(0.0);
uniform float chest_lean = 0.0;
uniform bool attached_to_chest = false;
uniform float waist_blend = 0.042;
uniform bool split_panels = false;
uniform bool thigh_surface = false;
uniform float thigh_turn = 0.0;
uniform float crouch_amount = 0.0;

void vertex() {
	float below_waist = smoothstep(0.0, waist_blend, -VERTEX.y);
	float side = split_panels ? UV2.x : smoothstep(-0.018, 0.018, VERTEX.z);
	float thigh = mix(thigh_angles.y, thigh_angles.x, side);
	float bend = (thigh - (attached_to_chest ? chest_lean : 0.0)) * below_waist;
	if (thigh_surface) {
		// Keep the top of the trousers at the pelvis while the leg bends.
		// A rigid rotating cap would protrude through the waist of the coat.
		bend = -thigh_turn * (1.0 - smoothstep(0.0, 0.065, -VERTEX.y));
		// The hip is covered by the garment; taper it slightly inside the seam.
		float hip = 1.0 - smoothstep(0.04, 0.13, -VERTEX.y);
		VERTEX.x *= 1.0 - hip * 0.20;
		VERTEX.z *= 1.0 - hip * 0.12;
	} else {
		// Open space for the bent thighs, keeping the belt/waist untouched.
		float allowance = below_waist * (0.004 + crouch_amount * 0.012);
		VERTEX.z += sign(VERTEX.z) * allowance;
		VERTEX.x += sign(VERTEX.x) * below_waist * 0.004;
	}
	float c = cos(bend);
	float s = sin(bend);
	mat2 turn = mat2(vec2(c, s), vec2(-s, c));
	VERTEX.xy = turn * VERTEX.xy;
	NORMAL.xy = turn * NORMAL.xy;
	TANGENT.xy = turn * TANGENT.xy;
	BINORMAL.xy = turn * BINORMAL.xy;
}

void fragment() {
	ALBEDO = cloth_color.rgb;
	ROUGHNESS = cloth_roughness;
	METALLIC = cloth_metallic;
}
