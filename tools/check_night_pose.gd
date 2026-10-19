extends SceneTree
## Verifies foot contact, natural knee direction, blending and cloth reset.
const Actor = preload("res://scripts/core/night_actor.gd")
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	failed = failed or not ok

func _run() -> void:
	for role in ["su", "ashi", "guard"]:
		var model = load("res://assets/models/night_%s.glb" % role).instantiate()
		root.add_child(model)
		var actor = Actor.new(model, role)
		var feet := [actor.joints["Foot_L"].global_position.y, actor.joints["Foot_R"].global_position.y]
		var stand_head: float = actor.joints["Head"].global_position.y
		var planted := true
		var forward_knees := true
		var level_feet := true
		var smooth := true
		for fps in [30.0, 60.0, 144.0]:
			actor.snap()
			var previous_head: float = actor.joints["Head"].global_position.y
			for i in range(int(fps * 2.0)):
				actor.update(1.0 / fps, true, false, false)
				var head: float = actor.joints["Head"].global_position.y
				smooth = smooth and absf(head - previous_head) < 0.04
				previous_head = head
				for side in ["L", "R"]:
					var index := 0 if side == "L" else 1
					var foot: Node3D = actor.joints["Foot_" + side]
					planted = planted and absf(foot.global_position.y - feet[index]) < 0.002
					forward_knees = forward_knees and actor.joints["Shin_" + side].rotation.z <= 0.001
					level_feet = level_feet and absf(foot.global_basis.x.y) < 0.002
			_check(actor.joints["Head"].global_position.y < stand_head - 0.09, role + " lowers its head in cover at " + str(int(fps)) + " fps")
			for i in range(int(fps)):
				actor.update(1.0 / fps, false, false, false)
			_check(absf(actor.joints["Head"].global_position.y - stand_head) < 0.008, role + " rises back to standing")
		_check(planted and level_feet, role + " keeps both feet flat on the ground through crouch transitions")
		_check(forward_knees and smooth, role + " bends knees forwards with a continuous height transition")
		var walk_contact := true
		for hiding in [false, true]:
			actor.snap()
			for i in range(180):
				model.position.x += 0.018
				actor.update(1.0 / 60.0, hiding, false, false)
				for side in ["L", "R"]:
					var index := 0 if side == "L" else 1
					var foot: Node3D = actor.joints["Foot_" + side]
					walk_contact = walk_contact and foot.global_position.y >= feet[index] - 0.002 and foot.global_position.y <= feet[index] + 0.05
		_check(walk_contact, role + " walking and crouch walking do not push feet through the ground")
		actor.snap()
		var reset := true
		for material in actor.cloth:
			reset = reset and (material.get_shader_parameter("thigh_angles") as Vector2).is_zero_approx()
		_check(reset, role + " checkpoint reset restores the garment deformation")
		model.queue_free()
		await process_frame
	print("NIGHT_POSE_OK" if not failed else "NIGHT_POSE_FAILED")
	quit(1 if failed else 0)
