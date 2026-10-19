extends RefCounted
## Connected seven-storey tower with original Tang-inspired architectural meshes.
## Art meshes stay separate from the verified smooth walking collision surfaces.

const HEIGHT := 3.8
var world: Node3D
var game
var materials := {}
var lights: Array[OmniLight3D] = []
var rings: Array[Node3D] = []
var moons: Array[MeshInstance3D] = []
var moon_halos: Array[MeshInstance3D] = []
var motes: Array[MeshInstance3D] = []
var landmarks: Array[Vector3] = []
var guide: Node3D
var guide_core: Node3D
var guide_shards: Node3D
var guide_floor := -1
var guide_state := "hidden"
var guide_time := 0.0
var guide_clock := 0.0
var guide_reveal := 0.0
var guide_depart_requested := false
var guide_path: Array[Vector3] = []
const GUIDE_FLIGHT_TIME := 8.4
const GUIDE_REVEAL := [0.0, 0.0, 0.08, 0.19, 0.39, 0.48, 0.72]
var lanterns: Array[Node3D] = []
var mesh_cache := {}
var detail_materials := {}
var spirit_surface: ShaderMaterial
var ribbon_mesh: ImmediateMesh
var ribbon_node: MeshInstance3D


func build(parent: Node3D, host) -> void:
	world = parent
	game = host
	materials = {
		"brick": _material(Color("dedbd1"), "brick"),
		"wood": _material(Color("dbc3a1"), "wood"),
		"stone": _material(Color("d8d6ca"), "stone"),
		"red": _material(Color("582c25")),
		"gold": _material(Color("8d7043")),
		"dark": _material(Color("201f20")),
		"light": _material(Color("7fa8b2"), "", 0.28),
		"flame": _material(Color("d59047"), "", 0.40),
		"mirror": _material(Color("7ea4ad"), "", 0.3),
		"plaster": _material(Color("a3977e")),
		"ribbon": _material(Color("74a3ad"), "", 0.18),
	}
	materials["gold"].metallic = 0.7
	materials["mirror"].metallic = 0.85
	materials["mirror"].roughness = 0.15
	materials["ribbon"].cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_spirit_material()
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("142330")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8698aa")
	settings.ambient_light_energy = 0.40
	# A restrained sky reflection gives bronze and glass volume in the compatibility renderer.
	var sky := Sky.new()
	var sky_paint := ProceduralSkyMaterial.new()
	sky_paint.sky_top_color = Color("182e45")
	sky_paint.sky_horizon_color = Color("8094a1")
	sky_paint.ground_bottom_color = Color("2c2925")
	sky_paint.ground_horizon_color = Color("6b706d")
	sky_paint.sky_energy_multiplier = 0.55
	sky_paint.ground_energy_multiplier = 0.32
	sky.sky_material = sky_paint
	settings.sky = sky
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.fog_enabled = true
	settings.fog_light_color = Color("17212a")
	settings.fog_density = 0.009
	env.environment = settings
	world.add_child(env)
	var moonlight := DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-28, 165, 0)
	moonlight.light_color = Color("9abddd")
	moonlight.light_energy = 0.65
	moonlight.shadow_enabled = true
	moonlight.directional_shadow_max_distance = 35.0
	world.add_child(moonlight)
	# The side walls and rear enclosure continue across all seven floors.
	_box(Vector3(-5.25, 13.2, 0), Vector3(0.5, 27, 10.6), materials["brick"], true)
	_box(Vector3(5.25, 13.2, 0), Vector3(0.5, 27, 10.6), materials["brick"], true)
	_box(Vector3(0, 13.2, -5.25), Vector3(10.6, 27, 0.5), materials["brick"], true)
	for i in range(7):
		_build_floor(i)
		if i < 6:
			_build_flights(i)
	_build_guide()
	_box(Vector3(0, 26.25, 0), Vector3(10.6, 0.3, 10.6), materials["wood"])
	# The carved summit ceiling closes the open stairwell above the final landing.
	_tang("ceiling_coffer", Vector3(0, HEIGHT * 6 + 3.48, 3.5), Vector3.ONE, Vector3(PI, 0, 0))
	ribbon_mesh = ImmediateMesh.new()
	ribbon_node = MeshInstance3D.new()
	ribbon_node.mesh = ribbon_mesh
	ribbon_node.material_override = materials["ribbon"]
	ribbon_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ribbon_node)
	_build_city()
	for i in range(32):
		var p := Vector3(sin(i * 7.3) * 4.2, fmod(i * 1.71, 25.0) + 0.4, cos(i * 5.1) * 4.1)
		var mote := _sphere(p, 0.012 + (i % 3) * 0.008, materials["light"])
		motes.append(mote)


func _material(color: Color, texture_name := "", emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	if not texture_name.is_empty():
		mat.albedo_texture = load("res://assets/images/tower/%s.png" % texture_name)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 0.65
		var normal_path := "res://assets/images/tower/%s_normal.png" % texture_name
		if ResourceLoader.exists(normal_path):
			mat.normal_enabled = true
			mat.normal_texture = load(normal_path)
			mat.normal_scale = 0.48
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat


func _box(pos: Vector3, size: Vector3, material: Material, solid := false, pitch := 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = pos
	mesh.rotation.x = pitch
	world.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.add_child(collision)
		body.position = pos
		body.rotation.x = pitch
		world.add_child(body)
	return mesh


func _sphere(pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	world.add_child(node)
	return node


func _ring(pos: Vector3, radius: float, parent: Node3D = null, tube := 0.035) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	mesh.rings = 48
	mesh.ring_segments = 8
	node.mesh = mesh
	node.material_override = materials["gold"]
	node.position = pos
	(parent if parent else world).add_child(node)
	return node


func _kit(name: String, pos: Vector3, scale_value := Vector3.ONE, yaw := 0.0) -> Node3D:
	var scene = load("res://assets/models/tower_kaykit/%s.glb" % name) as PackedScene
	var instance := scene.instantiate() as Node3D
	instance.position = pos
	instance.scale = scale_value
	instance.rotation.y = yaw
	world.add_child(instance)
	return instance


func _tang(name: String, pos: Vector3, scale_value := Vector3.ONE, angles := Vector3.ZERO) -> Node3D:
	if not mesh_cache.has(name):
		mesh_cache[name] = load("res://assets/models/tower_tang/%s.glb" % name)
	var instance := (mesh_cache[name] as PackedScene).instantiate() as Node3D
	instance.position = pos
	instance.scale = scale_value
	instance.rotation = angles
	_detail_surfaces(instance, name == "mirror_spirit_core")
	world.add_child(instance)
	return instance


func _detail_surfaces(node: Node, spirit := false) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var original: Material = node.mesh.surface_get_material(i)
			if not original or not original is StandardMaterial3D:
				continue
			var material_name: String = original.resource_name
			if material_name == "spirit_glass" and spirit:
				node.set_surface_override_material(i, spirit_surface)
			elif material_name in ["timber", "lacquer", "stone"]:
				if not detail_materials.has(material_name):
					var refined := original.duplicate() as StandardMaterial3D
					refined.uv1_triplanar = true
					refined.uv1_scale = Vector3.ONE * (1.25 if material_name != "stone" else 0.55)
					refined.albedo_texture = load("res://assets/images/tower/%s_detail.png" % ("stone" if material_name == "stone" else "wood"))
					refined.normal_enabled = true
					refined.normal_texture = load("res://assets/images/tower/%s_normal.png" % ("stone" if material_name == "stone" else "wood"))
					refined.normal_scale = 0.23
					detail_materials[material_name] = refined
				node.set_surface_override_material(i, detail_materials[material_name])
	for child in node.get_children():
		_detail_surfaces(child, spirit)


func _build_spirit_material() -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform float pulse = 0.0;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float arrival : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D reflection_image : source_color, filter_linear_mipmap;
void fragment() {
  vec2 p = UV * 2.0 - vec2(1.0);
  float flow = sin(p.x * 14.0 + sin(p.y * 11.0 + pulse) * 1.7 + pulse * 0.6);
  float veins = pow(max(0.0, flow), 18.0);
  float mist = 0.5 + 0.5 * sin(p.y * 8.0 + sin(p.x * 6.0 + pulse * 0.3));
  vec2 ripple = vec2(sin(p.y * 14.0 + pulse), cos(p.x * 11.0 - pulse)) * 0.004 * (1.0 - reveal);
  vec4 figure = texture(reflection_image, UV + ripple);
  float presence = reveal * figure.a * (0.92 + sin(pulse * 1.3) * 0.08);
  vec3 glass = mix(vec3(0.018, 0.045, 0.060), vec3(0.055, 0.12, 0.14), mist);
  ALBEDO = mix(glass, figure.rgb * vec3(0.70, 0.87, 0.94), presence);
  METALLIC = mix(0.65, 0.18, presence); ROUGHNESS = 0.25;
  EMISSION = vec3(0.08, 0.29, 0.33) * veins * (0.20 + arrival * 0.55)
    + figure.rgb * presence * 0.28;
}"""
	spirit_surface = ShaderMaterial.new()
	spirit_surface.shader = shader
	spirit_surface.set_shader_parameter("reflection_image", load("res://assets/images/tower/spirit_reflection.png"))


func _cylinder(pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 32
	node.mesh = shape
	node.material_override = material
	node.position = pos
	world.add_child(node)
	return node


func _build_floor(index: int) -> void:
	var y := index * HEIGHT
	# The south landing leaves the actual staircase void open on the other three sides.
	_box(Vector3(0, y - 0.1, 3.55), Vector3(9.9, 0.2, 3.3), materials["stone"], true)
	# Window opening in the south brick wall.
	for x in [-3.55, 3.55]:
		_box(Vector3(x, y + 1.9, 5.25), Vector3(3.4, 3.8, 0.5), materials["brick"], true)
	_box(Vector3(0, y + 0.42, 5.25), Vector3(3.7, 0.84, 0.5), materials["brick"], true)
	_box(Vector3(0, y + 3.36, 5.25), Vector3(3.7, 0.88, 0.5), materials["brick"], true)
	_tang("lattice_window", Vector3(0, y + 0.8, 4.96))
	_box(Vector3(0, y + 0.76, 4.93), Vector3(4.15, 0.10, 0.50), materials["stone"])
	for x in [-2.35, 2.35]:
		for z in [1.75, 4.7]:
			_tang("column_dougong", Vector3(x, y, z))
		_box(Vector3(x, y + 3.25, 3.3), Vector3(0.28, 0.25, 3.3), materials["wood"])
	for z in [1.65, 4.8]:
		_box(Vector3(0, y + 3.35, z), Vector3(10, 0.28, 0.27), materials["wood"])
		_box(Vector3(0, y + 3.19, z - 0.02), Vector3(9.9, 0.035, 0.29), materials["gold"])
	# Ceiling joists, wall bases and raised framing remove the bare block appearance.
	for x in range(-9, 10):
		_box(Vector3(x * 0.50, y + 3.60, 3.5), Vector3(0.08, 0.13, 3.25), materials["wood"])
	for x in [-4.96, 4.96]:
		_box(Vector3(x, y + 0.17, 0), Vector3(0.13, 0.34, 10), materials["stone"])
		_box(Vector3(x, y + 3.30, 0), Vector3(0.12, 0.17, 10), materials["wood"])
		for z in [-4.3, -1.3, 1.6]:
			_box(Vector3(x, y + 1.7, z), Vector3(0.16, 3.3, 0.17), materials["wood"])
	_box(Vector3(0, y + 0.18, -4.96), Vector3(10, 0.36, 0.14), materials["stone"])
	_box(Vector3(0, y + 1.90, -4.98), Vector3(10, 0.10, 0.13), materials["wood"])
	_box(Vector3(0, y + 3.25, -4.98), Vector3(10, 0.18, 0.18), materials["wood"])
	# Guard the central void but leave both stair mouths unobstructed.
	_box(Vector3(0, y + 0.45, 1.82), Vector3(4.5, 0.9, 0.10), materials["dark"], true).visible = false
	for x in [-1.59, -0.53, 0.53, 1.59]:
		_tang("rail_panel", Vector3(x, y, 1.82))
	# Warm lamps gradually yield to blue mirror light as the player ascends.
	var warm := Color("ffc47b").lerp(Color("9dc5de"), index / 8.0)
	for x in [-2.0, 2.0]:
		var lamp := _tang("paper_lantern", Vector3(x, y + 1.98, 4.38), Vector3.ONE * 0.88)
		lanterns.append(lamp)
		var light := OmniLight3D.new()
		light.position = Vector3(x, y + 2.30, 3.8)
		light.light_color = warm
		light.light_energy = 2.3
		light.omni_range = 4.8
		world.add_child(light)
		lights.append(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, y + 2.2, -2.7)
	fill.light_color = Color("a5bdd1")
	fill.light_energy = 1.15
	fill.omni_range = 4.5
	world.add_child(fill)
	landmarks.append(Vector3(0, y + 1.45, 4.7))
	_floor_plaque(index, y)
	# The individual floors receive a small, readable focal object.
	if index == 0:
		_kit("crates_stacked", Vector3(-3.8, y, 4.15), Vector3.ONE * 0.58)
		_kit("barrel_small", Vector3(3.85, y, 4.25), Vector3.ONE * 0.7)
	elif index in [2, 3]:
		_mirror(Vector3(0, y + 1.2, 4.4))
	elif index == 5:
		_build_bells(y)
	elif index == 6:
		_tang("lotus_altar", Vector3(0, y, 4.0))
		var shard := MeshInstance3D.new()
		var ceramic := PrismMesh.new()
		ceramic.size = Vector3(0.23, 0.18, 0.04)
		shard.mesh = ceramic
		shard.material_override = _material(Color("a1b9a4"), "", 0.08)
		shard.position = Vector3(0, y + 0.86, 3.97)
		shard.rotation.z = -0.35
		world.add_child(shard)
		for x in [-1.35, 1.35]:
			_tang("bronze_mirror", Vector3(x, y, 4.40), Vector3.ONE * 0.66, Vector3(0, -signf(x) * 0.20, 0))
	else:
		_kit("table_small", Vector3(-3.6, y, 4.0), Vector3(0.85, 0.72, 0.85))
		_kit("candle_triple", Vector3(-3.6, y + 0.72, 4.0), Vector3.ONE * 0.36)
	# Different props mark the transition from inhabited tower to mirror anomaly.
	if index < 4:
		_kit("candle_lit", Vector3(3.8, y, 3.9), Vector3.ONE * 0.58)


func _floor_plaque(index: int, y: float) -> void:
	# Mount the whole plaque in front of the deepest beam face (z = 4.635).
	# The board, frame and lettering must share this standoff, not intersect the beam.
	_box(Vector3(0, y + 3.13, 4.43), Vector3(2.10, 0.48, 0.08), materials["dark"])
	for h in [2.88, 3.38]:
		_box(Vector3(0, y + h, 4.375), Vector3(2.18, 0.026, 0.045), materials["gold"])
	for x in [-1.075, 1.075]:
		_box(Vector3(x, y + 3.13, 4.375), Vector3(0.026, 0.52, 0.045), materials["gold"])
	for x in [-0.84, 0.84]:
		_box(Vector3(x, y + 3.13, 4.59), Vector3(0.08, 0.26, 0.25), materials["wood"])
	var root := Node3D.new()
	root.name = "FloorPlaque%d" % (index + 1)
	root.position = Vector3(0, y + 3.13, 4.34)
	root.rotation.y = PI
	world.add_child(root)
	var words: Array = [["壹", "入", "塔"], ["贰", "灯", "火"], ["叁", "光", "痕"], ["肆", "回", "声"], ["伍", "低", "语"], ["陆", "月", "相"], ["柒", "临", "界"]][index]
	# Independent fixed character cells preserve calligraphic strokes without crowding.
	for i in range(3):
		var label := Label3D.new()
		label.text = words[i]
		label.font = game.heading
		label.font_size = 48
		label.pixel_size = 0.0042
		label.position.x = [-0.57, 0.10, 0.49][i]
		label.modulate = Color("dfcda5")
		label.outline_size = 1
		root.add_child(label)
	var separator := Label3D.new()
	separator.text = "·"
	separator.font = game.prose
	separator.font_size = 32
	separator.pixel_size = 0.004
	separator.position.x = -0.27
	separator.modulate = Color("ae9567")
	separator.outline_size = 0
	root.add_child(separator)


func _build_flights(index: int) -> void:
	var y := index * HEIGHT
	var a := Vector3(3.5, y, 2.0)
	var b := Vector3(3.5, y + HEIGHT * 0.5, -3.8)
	var c := Vector3(-3.5, y + HEIGHT * 0.5, -3.8)
	var d := Vector3(-3.5, y + HEIGHT, 2.0)
	# Beveled treads, nosings, joints and turned posts share the original collision ramps.
	_tang("timber_stairs", a)
	_tang("timber_stairs", c, Vector3.ONE, Vector3(0, PI, 0))
	for ends in [[a, b], [c, d]]:
		var start: Vector3 = ends[0]
		var end: Vector3 = ends[1]
		var pitch := -atan((end.y - start.y) / (end.z - start.z))
		var ramp := _box((start + end) * 0.5 - Vector3(0, 0.08, 0), Vector3(1.82, 0.16, start.distance_to(end)), materials["wood"], true, pitch)
		ramp.visible = false
		for dx in [-1.0, 1.0]:
			var guard := _box((start + end) * 0.5 + Vector3(dx, 0.45, 0), Vector3(0.08, 0.95, start.distance_to(end)), materials["wood"], true, pitch)
			guard.visible = false
	_box(Vector3(0, y + HEIGHT * 0.5 - 0.1, -4.3), Vector3(8.9, 0.2, 0.9), materials["wood"], true)
	for z in [-4.8, -3.82]:
		# Only the rear boundary spans the full bridge; both stair mouths stay open.
		var panel_centers := [-3.71, -2.65, -1.59, -0.53, 0.53, 1.59, 2.65, 3.71] if z < -4.0 else [-1.59, -0.53, 0.53, 1.59]
		for x in panel_centers:
			_tang("rail_panel", Vector3(x, y + HEIGHT * 0.5, z))
		# The inner crosswalk rail stops before both stair openings.
		if z > -4.0:
			var rail := _box(Vector3(0, y + HEIGHT * 0.5 + 0.4, z), Vector3(4.24, 0.85, 0.1), materials["dark"], true)
			rail.visible = false
	# Hang beyond the rear rail: the bridge and both stair turns stay clear at eye height.
	var stair_lamp := _tang("paper_lantern", Vector3(0, y + 3.38, -5.08), Vector3.ONE * 0.54)
	lanterns.append(stair_lamp)
	for i in range(3):
		var point := a.lerp(b, (i + 0.5) / 4.0) + Vector3(-0.67, 0.10, 0)
		_sphere(point, 0.025, materials["light"])


func _mirror(pos: Vector3) -> void:
	_tang("bronze_mirror", pos - Vector3(0, 1.02, 0))
	var disk := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.43
	mesh.bottom_radius = 0.43
	mesh.height = 0.012
	disk.mesh = mesh
	disk.material_override = materials["mirror"]
	disk.position = pos - Vector3(0, 0, 0.05)
	disk.rotation.x = PI * 0.5
	world.add_child(disk)


func _build_guide() -> void:
	# A single copper mirror travels through the existing stairwell, without collision.
	guide = Node3D.new()
	guide.name = "MirrorGuide"
	world.add_child(guide)
	guide_core = _tang("mirror_spirit_core", Vector3.ZERO)
	guide_core.reparent(guide, false)
	guide_shards = _tang("mirror_spirit_shards", Vector3.ZERO)
	guide_shards.reparent(guide, false)
	guide.visible = false


func _guide_anchor(index: int) -> Vector3:
	if index == 5:
		# Leave all three bells and their moon labels readable.
		return Vector3(1.70, index * HEIGHT + 1.95, 3.95)
	return Vector3(0, index * HEIGHT + (1.82 if index == 6 else 1.52), 4.20)


func _guide_scale(index: int) -> float:
	return [0.0, 0.0, 0.72, 0.82, 1.0, 0.74, 1.08][clampi(index, 0, 6)]


func guide_arrive(index: int) -> void:
	guide_floor = index
	guide_time = 0.0
	guide_depart_requested = false
	guide_state = "appear" if index >= 2 else "hidden"
	guide.visible = false
	guide.position = _guide_anchor(index)
	guide_reveal = GUIDE_REVEAL[index]
	guide_path.clear()


func guide_fly_up() -> void:
	if guide_floor >= 2 and guide_floor < 6 and guide_state in ["appear", "hold"]:
		guide_depart_requested = true


func _begin_guide_flight() -> void:
	var y := guide_floor * HEIGHT
	guide_state = "depart"
	guide_time = 0.0
	# Follow the open space above the actual stairs, around the solid south landing.
	guide_path = [guide.position, Vector3(2.75, y + 2.12, 1.85),
		Vector3(3.45, y + 2.85, -2.65), Vector3(2.8, y + 3.15, -3.55),
		Vector3(-2.8, y + 3.20, -3.55), Vector3(-3.45, y + 4.55, 0.85),
		_guide_anchor(guide_floor + 1)]


func _guide_flight_position(progress: float) -> Vector3:
	var at := clampf(progress, 0.0, 1.0) * (guide_path.size() - 1)
	var i := mini(int(at), guide_path.size() - 2)
	return guide_path[i].cubic_interpolate(guide_path[i + 1],
		guide_path[maxi(0, i - 1)], guide_path[mini(guide_path.size() - 1, i + 2)], at - i)


func _animate_guide(delta: float) -> void:
	guide_clock += delta
	guide_time += delta
	if guide_state == "hidden":
		return
	var t := guide_clock
	var scale_value := _guide_scale(guide_floor)
	var arrival_flash := 0.0
	if guide_state == "appear":
		var amount := smoothstep(0.12, 0.82, guide_time)
		guide.visible = amount > 0.0
		scale_value *= lerpf(0.04, 1.0, amount)
		guide_shards.scale = Vector3.ONE * lerpf(1.9, 1.0, amount)
		arrival_flash = sin(amount * PI)
		if guide_time >= 0.95:
			guide_state = "hold"
			guide_time = 0.0
	elif guide_state == "hold":
		guide.visible = true
		guide_shards.scale = Vector3.ONE
		if guide_depart_requested and guide_time > 0.45:
			_begin_guide_flight()
	if guide_state == "depart":
		var progress := minf(1.0, guide_time / GUIDE_FLIGHT_TIME)
		guide.position = _guide_flight_position(progress)
		scale_value *= 1.0 - sin(progress * PI) * 0.24
		guide_shards.scale = Vector3(0.86, 1.12, 0.86)
		if progress >= 1.0:
			guide_state = "waiting"
			guide_time = 0.0
	elif guide_state == "waiting":
		guide.position = _guide_anchor(guide_floor + 1)
		scale_value = _guide_scale(guide_floor + 1)
		guide_shards.scale = Vector3.ONE
	else:
		guide.position = _guide_anchor(guide_floor)
	guide.position.y += sin(t * 0.8) * 0.045
	guide.scale = Vector3.ONE * scale_value
	guide.rotation = Vector3(sin(t * 0.45) * 0.09, sin(t * 0.35) * 0.16, sin(t * 0.3) * 0.06)
	guide_shards.rotation = Vector3(sin(t * 0.23) * 0.18, sin(t * 0.31) * 0.25,
		t * (0.30 if guide_state == "depart" else 0.11))
	spirit_surface.set_shader_parameter("reveal", guide_reveal)
	spirit_surface.set_shader_parameter("arrival", arrival_flash)


func _build_bells(y: float) -> void:
	var moon_shader := load("res://scripts/shaders/tower_moon.gdshader") as Shader
	var halo_shader := load("res://scripts/shaders/tower_moon_halo.gdshader") as Shader
	var lunar_surface := load("res://assets/images/tower/moon_face_ai.png") as Texture2D
	for i in range(3):
		var x := (1 - i) * 0.90
		_box(Vector3(x, y + 2.45, 4.6), Vector3(0.025, 0.7, 0.025), materials["gold"])
		_tang("ritual_bell", Vector3(x, y + 1.80, 4.6))
		var backing := _cylinder(Vector3(x, y + 1.35, 4.54), 0.26, 0.025, materials["dark"])
		backing.rotation.x = PI * 0.5
		for radius in [0.265, 0.285]:
			var rim := _ring(Vector3(x, y + 1.35, 4.51), radius, null, 0.009)
			rim.rotation.x = PI * 0.5
		var moon := MeshInstance3D.new()
		var face := QuadMesh.new()
		face.size = Vector2.ONE * 0.61
		moon.mesh = face
		var moon_material := ShaderMaterial.new()
		moon_material.shader = moon_shader
		moon_material.set_shader_parameter("moon_albedo", lunar_surface)
		moon_material.set_shader_parameter("light_direction", [Vector3(0, 0, -1), Vector3(1, 0, 0.015), Vector3(0.12, 0.06, 1)][i])
		moon.material_override = moon_material
		moon.position = Vector3(x, y + 1.35, 4.5)
		moon.rotation.y = PI
		moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(moon)
		moons.append(moon)
		var halo := MeshInstance3D.new()
		var glow := QuadMesh.new()
		glow.size = Vector2.ONE * 0.82
		halo.mesh = glow
		var halo_material := ShaderMaterial.new()
		halo_material.shader = halo_shader
		halo.material_override = halo_material
		halo.position = Vector3(x, y + 1.35, 4.56)
		halo.rotation.y = PI
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(halo)
		moon_halos.append(halo)
		var text := Label3D.new()
		text.text = ["朔", "弦", "望"][i]
		text.font = game.heading
		text.font_size = 48
		text.pixel_size = 0.004
		text.modulate = Color("d2c095")
		text.outline_size = 2
		text.position = Vector3(x, y + 0.87, 4.4)
		text.rotation.y = PI
		world.add_child(text)
	_tang("lotus_altar", Vector3(0, y, 4.45), Vector3(1.65, 0.55, 0.60))
	for x in [-1.4, 1.4]:
		_tang("column_dougong", Vector3(x, y + 0.4, 4.7), Vector3(0.32, 0.66, 0.32))
	_box(Vector3(0, y + 2.82, 4.6), Vector3(2.95, 0.14, 0.22), materials["wood"])


func _build_city() -> void:
	var city_path := "res://assets/images/tower/changan_rooftops_ai.jpg"
	if ResourceLoader.exists(city_path):
		var panorama := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2(120, 75)
		panorama.mesh = plane
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.albedo_texture = load(city_path)
		panorama.material_override = paint
		panorama.position = Vector3(0, 15, 64)
		panorama.rotation.y = PI
		world.add_child(panorama)
	var city_mat := _material(Color("2c333a"))
	var roof_mat := _material(Color("212c35"))
	for row in range(3):
		for col in range(13):
			var x := (col - 6) * 4.1
			if absf(x) < 17.0:
				continue
			var z := 14.0 + row * 6.0
			var h := 1.3 + fmod(col * 2.7 + row * 1.9, 2.2)
			_box(Vector3(x, h * 0.5 - 3.4, z), Vector3(3.1, h, 3.5), city_mat)
			var roof := MeshInstance3D.new()
			var shape := PrismMesh.new()
			shape.size = Vector3(3.8, 1.1, 4.0)
			roof.mesh = shape
			roof.material_override = roof_mat
			roof.position = Vector3(x, h - 2.85, z)
			world.add_child(roof)


func animate(t: float, floor_index: int, intensity: float, delta := 0.0) -> void:
	for i in range(lights.size()):
		lights[i].light_energy = (1.65 + sin(t * 2.1 + i) * 0.07) * (0.92 if floor_index > 3 else 1.0)
	_animate_guide(delta)
	spirit_surface.set_shader_parameter("pulse", guide_clock * 0.45)
	for i in range(rings.size()):
		rings[i].rotation.z = sin(t * 0.27 + i) * 0.10 + intensity * t * (0.15 + i * 0.035)
	for i in range(lanterns.size()):
		lanterns[i].rotation.z = sin(t * 0.65 + i * 0.8) * 0.016
	_animate_ribbons()
	for i in range(motes.size()):
		motes[i].position.y += 0.002
		if motes[i].position.y > 25.8:
			motes[i].position.y = 0.2
	for i in range(moons.size()):
		moons[i].visible = floor_index == 5
		moon_halos[i].visible = floor_index == 5
		var highlight := 1.0 if int(t / 1.3) % 3 == i else 0.0
		(moons[i].material_override as ShaderMaterial).set_shader_parameter("highlight", highlight)
		(moon_halos[i].material_override as ShaderMaterial).set_shader_parameter("highlight", highlight)


func _animate_ribbons() -> void:
	ribbon_mesh.clear_surfaces()
	if not guide.visible:
		return
	var t := guide_clock
	var center := guide.position
	var size := guide.scale.x
	# Two thin undulating ribbons orbit the bronze core, hinting at a presence in the mirror.
	for arm in range(2):
		ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in range(65):
			var k := i / 64.0
			var a := k * TAU * 1.16 + t * 0.22 + arm * PI
			var radius := (0.73 + sin(k * PI) * 0.32) * size
			var p := center + Vector3(cos(a) * radius, sin(a) * radius * 0.56, sin(a * 1.8 + t * 0.3) * 0.17)
			if guide_state == "depart":
				var progress := guide_time / GUIDE_FLIGHT_TIME
				p = _guide_flight_position(maxf(0.0, progress - k * 0.17))
				p += Vector3(sin(k * TAU + t + arm * PI) * 0.07, arm * 0.06, 0.0)
			var width := sin(k * PI) * 0.022 * size
			ribbon_mesh.surface_set_normal(Vector3(0, 0, -1))
			ribbon_mesh.surface_add_vertex(p - Vector3.UP * width)
			ribbon_mesh.surface_set_normal(Vector3(0, 0, -1))
			ribbon_mesh.surface_add_vertex(p + Vector3.UP * width)
		ribbon_mesh.surface_end()
