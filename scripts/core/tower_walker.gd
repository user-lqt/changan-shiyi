extends CharacterBody3D
## A quiet first-person walk. Visible stair meshes use smooth collision ramps.

var camera: Camera3D
var enabled := false
var scripted := false
var wish := Vector3.ZERO
var speed := 2.65
var sprint_speed := 4.6
var sprinting := false
var pitch := 0.0
var footsteps := 0.0
var chapter


func _ready() -> void:
	name = "FirstPersonWalker"
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(48.0)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.23
	shape.height = 1.65
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.84
	add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 1.56
	camera.fov = 72.0
	camera.near = 0.06
	camera.far = 120.0
	add_child(camera)
	camera.current = true


func look(relative: Vector2) -> void:
	if not enabled:
		return
	rotation.y -= relative.x * 0.0022
	pitch = clampf(pitch - relative.y * 0.0022, -1.15, 1.15)
	camera.rotation.x = pitch


func face(point: Vector3, delta: float = 1.0) -> void:
	var d := point - camera.global_position
	if Vector2(d.x, d.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 3.5))
	pitch = lerpf(pitch, clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.0, 1.0), minf(1.0, delta * 3.5))
	camera.rotation.x = pitch


func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if enabled:
		if scripted:
			direction = wish
		else:
			var axes := Vector2(
				float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
				float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
			direction = basis * Vector3(axes.x, 0, axes.y).normalized()
	sprinting = enabled and not scripted and direction.length_squared() > 0.01 and Input.is_physical_key_pressed(KEY_SHIFT)
	var movement_speed := sprint_speed if sprinting else speed
	velocity.x = move_toward(velocity.x, direction.x * movement_speed, delta * 14.0)
	velocity.z = move_toward(velocity.z, direction.z * movement_speed, delta * 14.0)
	if not is_on_floor():
		velocity.y -= 14.0 * delta
	else:
		velocity.y = -0.3
	move_and_slide()
	if enabled and Vector2(velocity.x, velocity.z).length() > 0.5 and is_on_floor():
		footsteps += delta
		if footsteps > (0.30 if sprinting else 0.48):
			footsteps = 0.0
			if chapter:
				chapter.g.sfx("hover", -27.0)
	if position.y < -2.0 and chapter:
		chapter.restore_landing()
