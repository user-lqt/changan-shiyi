extends RefCounted
## Visual posing only; chapter rules still use the logical grid.
## +X is forward. Feet follow a ground-space gait; knees bend forwards.

const CLOTH_SHADER = preload("res://scripts/shaders/night_cloth.gdshader")

var model: Node3D
var kind := "su"
var joints := {}
var rest := {}
var gait := 0.0
var motion := 0.0
var crouch := 0.0
var throw_time := 0.0
var clock := 0.0
var previous := Vector3.ZERO
var leg_lengths := {}
var cloth: Array[ShaderMaterial] = []


func _init(node: Node3D, role: String, offset := 0.0) -> void:
	model = node
	kind = role
	clock = offset
	gait = offset
	for label in ["Body", "Chest", "Head", "Arm_L", "Arm_R", "Fore_L", "Fore_R",
		"Leg_L", "Leg_R", "Shin_L", "Shin_R", "Foot_L", "Foot_R", "Hem_L", "Hem_R",
		"CoatHem", "Cape", "Satchel", "Tasset_L", "Tasset_R"]:
		var joint := model.find_child(label, true, false) as Node3D
		if joint:
			joints[label] = joint
			rest[label] = joint.transform
	for side in ["L", "R"]:
		if rest.has("Shin_" + side) and rest.has("Foot_" + side):
			leg_lengths[side] = Vector2(-rest["Shin_" + side].origin.y, -rest["Foot_" + side].origin.y)
	if kind == "su":
		_prepare_cloth("CoatHem", false)
	if kind != "guard":
		_prepare_cloth("Chest", true)
	if kind != "guard":
		_prepare_cloth("Leg_L", false, "L")
		_prepare_cloth("Leg_R", false, "R")
	previous = model.position


func _prepare_cloth(label: String, follows_chest: bool, thigh_side := "") -> void:
	var mesh := joints.get(label) as MeshInstance3D
	if not mesh or not mesh.mesh:
		return
	# Bend the existing garment surfaces on the GPU, without cloth simulation.
	mesh.extra_cull_margin = 0.30
	for surface in range(mesh.mesh.get_surface_count()):
		var source := mesh.get_active_material(surface) as StandardMaterial3D
		if not source:
			continue
		var material := ShaderMaterial.new()
		material.shader = CLOTH_SHADER
		material.set_shader_parameter("cloth_color", source.albedo_color)
		material.set_shader_parameter("cloth_roughness", source.roughness)
		material.set_shader_parameter("cloth_metallic", source.metallic)
		material.set_shader_parameter("attached_to_chest", follows_chest)
		material.set_shader_parameter("waist_blend", 0.042 if kind == "su" else 0.032)
		material.set_shader_parameter("split_panels", bool(mesh.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_TEX_UV2))
		material.set_shader_parameter("thigh_surface", not thigh_side.is_empty())
		material.set_meta("thigh_side", thigh_side)
		mesh.set_surface_override_material(surface, material)
		cloth.append(material)


func snap() -> void:
	previous = model.position
	motion = 0.0
	crouch = 0.0
	throw_time = 0.0
	for label in joints:
		(joints[label] as Node3D).transform = rest[label]
	_cloth_pose(Vector2.ZERO, 0.0)


func throw_stone() -> void:
	throw_time = 0.72


func _pose(label: String, angles: Vector3, offset := Vector3.ZERO) -> void:
	if not joints.has(label):
		return
	var joint: Node3D = joints[label]
	joint.transform = rest[label]
	joint.rotation += angles
	joint.position += offset


func _foot_pose(side: String, foot: Vector2, spread: float) -> float:
	if not leg_lengths.has(side):
		return 0.0
	var lengths: Vector2 = leg_lengths[side]
	var reach := clampf(foot.length(), absf(lengths.x - lengths.y) + 0.0001, lengths.x + lengths.y - 0.00001)
	var along := atan2(foot.x, -foot.y)
	var hip := along + acos(clampf((lengths.x * lengths.x + reach * reach - lengths.y * lengths.y) / (2.0 * lengths.x * reach), -1.0, 1.0))
	var knee := acos(clampf((lengths.x * lengths.x + lengths.y * lengths.y - reach * reach) / (2.0 * lengths.x * lengths.y), -1.0, 1.0)) - PI
	_pose("Leg_" + side, Vector3(0, 0, hip), Vector3(0, 0, spread))
	_pose("Shin_" + side, Vector3(0, 0, knee))
	_pose("Foot_" + side, Vector3(0, 0, -hip - knee))
	return hip


func _cloth_pose(hips: Vector2, chest_lean: float) -> void:
	for material in cloth:
		material.set_shader_parameter("thigh_angles", hips)
		material.set_shader_parameter("chest_lean", chest_lean)
		var side: String = material.get_meta("thigh_side", "")
		material.set_shader_parameter("thigh_turn", 0.0 if side.is_empty() else (hips.x if side == "L" else hips.y))
		material.set_shader_parameter("crouch_amount", smoothstep(0.0, 1.0, crouch))


func update(delta: float, hiding: bool, alert: bool, paused: bool) -> void:
	var displacement := model.position - previous
	previous = model.position
	if paused:
		return
	clock += delta
	throw_time = maxf(0.0, throw_time - delta)
	var distance := Vector2(displacement.x, displacement.z).length()
	var k := 1.0 - exp(-delta * 15.0)
	motion = lerpf(motion, clampf(distance / maxf(delta, 0.001) / 3.8, 0.0, 1.0), k)
	crouch = lerpf(crouch, 1.0 if hiding else 0.0, 1.0 - exp(-delta * (7.0 if hiding else 8.5)))
	var duck := smoothstep(0.0, 1.0, crouch)
	gait += distance * (13.0 if kind == "ashi" else 10.5)
	var lengths: Vector2 = leg_lengths.get("L", Vector2(0.24, 0.24))
	var length := lengths.x + lengths.y
	var stride_scale := motion * (1.0 - duck * 0.48)
	var settle := length * (0.002 + 0.029 * motion + 0.27 * duck)
	var back := length * 0.11 * duck
	var hip_shift := Vector3(-back, -settle, sin(clock * 0.85) * 0.003 * duck)
	var chest_lean := -0.045 * motion - 0.29 * duck
	if kind == "guard":
		chest_lean *= 0.4
	_pose("Body", Vector3(0, sin(gait) * motion * 0.018, 0), hip_shift)
	_pose("Chest", Vector3(0, sin(gait) * motion * 0.025 + sin(clock * 0.7) * duck * 0.015, chest_lean),
		Vector3(0, sin(clock * 2.3) * 0.0025, 0))
	_pose("Head", Vector3(0, sin(clock * 0.80) * (0.15 if alert else 0.045), -chest_lean * 0.70))
	var hips := Vector2.ZERO
	for side in [-1.0, 1.0]:
		var label := "L" if side < 0.0 else "R"
		var phase := gait + (0.0 if side < 0.0 else PI)
		var travel := sin(phase) * length * 0.17 * stride_scale
		# Rising feet travel forwards; their return is the planted stance.
		var lift := maxf(0.0, cos(phase)) * length * 0.07 * stride_scale
		var stagger: float = length * 0.035 * duck * (-side)
		var foot := Vector2(travel + stagger + back, -length + settle + lift)
		var hip := _foot_pose(label, foot, -side * length * 0.025 * duck)
		if label == "L":
			hips.x = hip
		else:
			hips.y = hip
		var swing := sin(phase) * motion
		# Relaxed elbows bring the hands in front of the thighs while hiding.
		var arm := -swing * 0.28 * (1.0 - duck * 0.70) + duck * (0.18 if label == "L" else 0.10)
		var fore := 0.10 + duck * (0.38 if label == "L" else 0.52) + maxf(0.0, -swing) * 0.16
		if kind == "guard" and label == "R":
			arm = -0.10 + swing * 0.045
			fore = -0.12
		if label == "R" and throw_time > 0.0:
			var t := 1.0 - throw_time / 0.72
			arm = lerpf(-1.5, 1.20, smoothstep(0.18, 0.65, t)) * sin(PI * minf(1.0, t * 1.35))
			fore = 0.72 - sin(t * PI) * 0.45
		_pose("Arm_" + label, Vector3(side * 0.045 - side * duck * 0.035, 0, arm))
		_pose("Fore_" + label, Vector3(0, 0, fore))
		_pose("Hem_" + label, Vector3(0, 0, hip * 0.65))
		_pose("Tasset_" + label, Vector3(0, 0, maxf(0.0, hip) * 0.6))
	_pose("Cape", Vector3(sin(clock * 1.5) * 0.025, sin(clock * 1.1) * 0.025,
		0.05 + motion * 0.14 + sin(gait - 0.8) * motion * 0.035))
	# The waist seam stays fixed; each side of the garment follows its thigh.
	_pose("CoatHem", Vector3.ZERO)
	_pose("Satchel", Vector3(0, 0, hips.y * 0.22), Vector3(0, 0, -duck * 0.012))
	_cloth_pose(hips, chest_lean)
