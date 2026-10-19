extends RefCounted
## 终章 · the modern restoration lab: a simple low-poly room built from boxes, with the two
## detailed artifact models (lab_bowl.glb, lab_mirror.glb from tools/blender/build_lab_kit.py).
## Room: x -4..4, z -3..3, ceiling 3 m. The window (north wall, z = -3) looks out on Xi'an.

var world: Node3D
var game
var materials := {}
var spots := {}                 # id -> {"pos": look-at point, "stand": where the walker stops}
var screen_mesh: MeshInstance3D
var screen_label: Label3D
var turntable: Node3D
var mirror_node: Node3D
var mirror_glow: OmniLight3D
var bowl_glow: OmniLight3D
var moon_light: OmniLight3D
var scan_view: SubViewport
var scan_model: Node3D
var exterior_sky: Sky
var obstacles: Array[Rect2] = []
var navigator: AStarGrid2D
const GRID_ORIGIN := Vector2(-3.6, -2.6)
const GRID_STEP := 0.2
const WINDOW_VIEW := Vector3(0, 12.0, -120.0)


func build(parent: Node3D, host) -> void:
	world = parent
	game = host
	materials = {
		"floor": _material(Color("5f6a70")),
		"wall": _material(Color("c9ccc8")),
		"trim": _material(Color("8f9693")),
		"desk": _material(Color("e4e4df")),
		"steel": _material(Color("8a9095")),
		"dark": _material(Color("23272b")),
		"cabinet": _material(Color("7c8a86")),
		"glass": _material(Color(0.75, 0.88, 0.92, 0.18)),
		"panel": _material(Color("f2f4f0"), 0.9),
		"screen": _material(Color("12202a"), 0.6),
		"paper": _material(Color("efe9da")),
		"box": _material(Color("b39c74")),
		"accent": _material(Color("5e8f86")),
	}
	materials["glass"].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials["glass"].roughness = 0.05
	materials["steel"].metallic = 0.6
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("0b1218")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("7d8c99")
	settings.ambient_light_energy = 0.38
	var sky := Sky.new()
	var paint := ProceduralSkyMaterial.new()
	paint.sky_top_color = Color("182d42")
	paint.sky_horizon_color = Color("78909b")
	paint.ground_bottom_color = Color("313b3e")
	paint.ground_horizon_color = Color("7b857e")
	sky.sky_material = paint
	if game.tex.has("lab_window"):
		var city := ShaderMaterial.new()
		city.shader = preload("res://scripts/shaders/lab_night_sky.gdshader")
		city.set_shader_parameter("city_view", game.tex["lab_window"])
		sky.sky_material = city
		settings.background_mode = Environment.BG_SKY
	exterior_sky = sky
	settings.sky = sky
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	world.add_child(env)
	_build_room()
	_build_window()
	_build_scan_bench()
	_build_desk()
	_build_display()
	_build_shelves()
	_build_wall_details()
	_build_lab_details()
	_build_navigation()


func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat


func _box(pos: Vector3, size: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = pos
	world.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.add_child(collision)
		body.position = pos
		world.add_child(body)
		if pos.y + size.y * 0.5 > 0.3:
			obstacles.append(Rect2(Vector2(pos.x - size.x * 0.5, pos.z - size.z * 0.5), Vector2(size.x, size.z)).grow(0.29))
	return mesh


func _cylinder(pos: Vector3, radius: float, height: float, material: Material, segments := 24) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = segments
	node.mesh = shape
	node.material_override = material
	node.position = pos
	world.add_child(node)
	return node


func _label(text: String, pos: Vector3, size := 0.05, color := Color("e8e2d0"), yaw := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = game.face
	label.font_size = 64
	label.pixel_size = size / 64.0
	label.modulate = color
	label.outline_size = 0
	label.position = pos
	label.rotation.y = yaw
	label.double_sided = false
	world.add_child(label)
	return label


func _model(name: String, pos: Vector3, scale_value := 1.0, yaw := 0.0) -> Node3D:
	var scene := load("res://assets/models/%s.glb" % name) as PackedScene
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.scale = Vector3.ONE * scale_value
	node.rotation.y = yaw
	world.add_child(node)
	return node


func _light(pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	world.add_child(light)
	return light


func _art_panel(key: String, pos: Vector3, size: Vector2, yaw := 0.0) -> MeshInstance3D:
	if not game.tex.has(key):
		return null
	var panel := MeshInstance3D.new()
	var face := QuadMesh.new()
	face.size = size
	panel.mesh = face
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = game.tex[key]
	mat.roughness = 0.75
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_texture = game.tex[key]
	mat.emission_energy_multiplier = 0.15
	panel.material_override = mat
	panel.position = pos
	panel.rotation.y = yaw
	world.add_child(panel)
	return panel


func _build_room() -> void:
	_box(Vector3(0, -0.05, 0), Vector3(8.4, 0.1, 6.4), materials["floor"], true)
	_box(Vector3(0, 3.05, 0), Vector3(8.4, 0.1, 6.4), materials["wall"])
	_box(Vector3(-4.1, 1.5, 0), Vector3(0.2, 3.0, 6.4), materials["wall"], true)
	_box(Vector3(4.1, 1.5, 0), Vector3(0.2, 3.0, 6.4), materials["wall"], true)
	_box(Vector3(0, 1.5, 3.1), Vector3(8.4, 3.0, 0.2), materials["wall"], true)
	# North wall with a wide window opening (x -1.6..1.6, y 0.9..2.5).
	_box(Vector3(-2.85, 1.5, -3.1), Vector3(2.5, 3.0, 0.2), materials["wall"], true)
	_box(Vector3(2.85, 1.5, -3.1), Vector3(2.5, 3.0, 0.2), materials["wall"], true)
	_box(Vector3(0, 0.45, -3.1), Vector3(3.2, 0.9, 0.2), materials["wall"], true)
	_box(Vector3(0, 2.75, -3.1), Vector3(3.2, 0.5, 0.2), materials["wall"], true)
	_box(Vector3(0, 0.004, 0), Vector3(8.0, 0.008, 6.0), materials["floor"])
	# Ceiling light panels.
	for x in [-2.2, 0.0, 2.2]:
		_box(Vector3(x, 2.98, 0.4), Vector3(1.2, 0.03, 0.6), materials["panel"])
	var key_light := _light(Vector3(0, 2.6, 0.6), Color("dfe8f0"), 0.9, 8.0)
	key_light.shadow_enabled = true
	_light(Vector3(-2.5, 2.6, 1.6), Color("dfe8f0"), 0.5, 6.0)


func _build_window() -> void:
	# The skyline lives in the sky, at infinity. The recessed reveal and exterior
	# ledge supply near parallax without covering the city with a dark picture frame.
	_box(Vector3(0, 0.86, -3.38), Vector3(3.5, 0.1, 0.72), materials["trim"])
	for x in [-1.65, 1.65]:
		_box(Vector3(x, 1.7, -3.18), Vector3(0.08, 1.64, 0.34), materials["wall"])
	_box(Vector3(0, 2.55, -3.18), Vector3(3.4, 0.08, 0.34), materials["wall"])
	# Slim metal frame and sill; no central mullion obscures the closing shot.
	_box(Vector3(0, 0.92, -2.98), Vector3(3.3, 0.06, 0.3), materials["trim"])
	for x in [-1.59, 1.59]:
		_box(Vector3(x, 1.7, -3.02), Vector3(0.04, 1.6, 0.05), materials["trim"])
	_box(Vector3(0, 2.49, -3.02), Vector3(3.2, 0.04, 0.05), materials["trim"])
	_box(Vector3(0, 1.7, -3.03), Vector3(3.2, 1.6, 0.01), materials["glass"])
	moon_light = _light(Vector3(0, 2.2, -2.6), Color("a9c3e6"), 0.6, 5.0)
	spots["window"] = {"pos": Vector3(0, 1.75, -3.1), "stand": Vector3(0, 0, -2.1), "label": "窗外"}


## Centre bench: the scanning turntable with the mirror, a ring scanner on an arm.
func _build_scan_bench() -> void:
	_box(Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 1.0), materials["desk"], true)
	_box(Vector3(0, 0.915, 0), Vector3(2.04, 0.03, 1.04), materials["steel"])
	turntable = Node3D.new()
	turntable.position = Vector3(0.1, 0.93, 0)
	world.add_child(turntable)
	var base := _cylinder(Vector3.ZERO, 0.24, 0.05, materials["dark"], 40)
	base.reparent(turntable, false)
	var plate := _cylinder(Vector3(0, 0.035, 0), 0.2, 0.02, materials["steel"], 40)
	plate.reparent(turntable, false)
	mirror_node = _model("lab_mirror", Vector3(0, 0.045, 0), 1.6)
	mirror_node.reparent(turntable, false)
	# Scanner: a post and an arm holding a ring head over the turntable.
	_box(Vector3(-0.75, 1.45, -0.3), Vector3(0.08, 1.05, 0.08), materials["steel"])
	_box(Vector3(-0.38, 1.95, -0.3), Vector3(0.82, 0.06, 0.06), materials["steel"])
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.21
	ring.mesh = torus
	ring.material_override = materials["dark"]
	ring.position = Vector3(0.05, 1.7, -0.15)
	ring.rotation.x = 0.35
	world.add_child(ring)
	_box(Vector3(0.05, 1.83, -0.22), Vector3(0.05, 0.25, 0.05), materials["steel"])
	mirror_glow = _light(Vector3(0.1, 1.25, 0), Color("bfe3ea"), 0.35, 1.8)
	spots["mirror"] = {"pos": Vector3(0.1, 0.98, 0), "stand": Vector3(0.1, 0, 1.15), "label": "海兽葡萄纹铜镜"}


## Side desk with the scan workstation monitor.
func _build_desk() -> void:
	_box(Vector3(-3.0, 0.38, -1.2), Vector3(1.6, 0.76, 0.8), materials["desk"], true)
	_box(Vector3(-3.0, 1.02, -1.54), Vector3(0.06, 0.5, 0.06), materials["dark"])
	_box(Vector3(-3.0, 0.78, -1.42), Vector3(0.3, 0.03, 0.2), materials["dark"])
	_box(Vector3(-3.0, 1.32, -1.46), Vector3(1.06, 0.62, 0.04), materials["dark"])
	screen_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 0.56)
	screen_mesh.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("16303a")
	_build_scan_view()
	mat.albedo_texture = scan_view.get_texture()
	mat.albedo_color = Color.WHITE
	screen_mesh.material_override = mat
	screen_mesh.position = Vector3(-3.0, 1.32, -1.435)
	world.add_child(screen_mesh)
	screen_label = _label("文物三维档案 / 扫描已完成", Vector3(-3.0, 0.91, -1.43), 0.032, Color("9fe0d0"))
	_box(Vector3(-3.0, 0.775, -0.95), Vector3(0.5, 0.02, 0.16), materials["dark"])
	_box(Vector3(-2.55, 0.78, -0.95), Vector3(0.07, 0.02, 0.11), materials["dark"])
	# Chair.
	_box(Vector3(-3.0, 0.46, -0.45), Vector3(0.5, 0.06, 0.5), materials["accent"])
	_box(Vector3(-3.0, 0.75, -0.22), Vector3(0.5, 0.55, 0.06), materials["accent"])
	_cylinder(Vector3(-3.0, 0.22, -0.45), 0.03, 0.44, materials["steel"], 8)
	_light(Vector3(-3.0, 1.35, -1.1), Color("8fd8e6"), 0.35, 2.0)
	spots["screen"] = {"pos": Vector3(-3.0, 1.32, -1.44), "stand": Vector3(-3.0, 0, 0.15), "label": "扫描屏幕"}


func _build_scan_view() -> void:
	scan_view = SubViewport.new()
	scan_view.size = Vector2i(768, 432)
	scan_view.own_world_3d = true
	scan_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.add_child(scan_view)
	var scan_world := Node3D.new()
	scan_view.add_child(scan_world)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("10242c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("cfe5d9")
	settings.ambient_light_energy = 0.85
	env.environment = settings
	scan_world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.4
	scan_world.add_child(light)
	scan_model = (load("res://assets/models/lab_bowl.glb") as PackedScene).instantiate()
	scan_world.add_child(scan_model)
	var camera := Camera3D.new()
	camera.position = Vector3(0.21, 0.20, 0.26)
	camera.fov = 38
	scan_world.add_child(camera)
	camera.look_at(Vector3(0, 0.035, 0))
	camera.current = true
	var title := Label.new()
	title.text = "三维档案 / 越窑莲纹碗"
	title.add_theme_font_override("font", game.face)
	title.add_theme_font_size_override("font_size", 25)
	title.position = Vector2(24, 15)
	scan_view.add_child(title)
	var status := Label.new()
	status.text = "采集完成  01:07\n四处接缝已记录"
	status.add_theme_font_override("font", game.face)
	status.add_theme_font_size_override("font_size", 21)
	status.modulate = Color("9fe0d0")
	status.position = Vector2(24, 347)
	scan_view.add_child(status)


## Glass display case on a plinth holding the restored bowl.
func _build_display() -> void:
	_box(Vector3(3.0, 0.5, -1.0), Vector3(0.7, 1.0, 0.7), materials["desk"], true)
	_box(Vector3(3.0, 1.01, -1.0), Vector3(0.72, 0.02, 0.72), materials["steel"])
	_cylinder(Vector3(3.0, 1.03, -1.0), 0.16, 0.02, materials["dark"], 32)
	_model("lab_bowl", Vector3(3.0, 1.04, -1.0), 1.5, 0.6)
	_box(Vector3(3.0, 1.33, -1.0), Vector3(0.64, 0.6, 0.64), materials["glass"])
	_label("唐 · 越窑青瓷刻莲纹碗", Vector3(3.0, 0.75, -0.64), 0.03, Color("3a3f40"))
	bowl_glow = _light(Vector3(3.0, 1.6, -0.8), Color("ffe9c4"), 0.6, 1.6)
	spots["bowl"] = {"pos": Vector3(3.0, 1.1, -1.0), "stand": Vector3(2.9, 0, 0.35), "label": "莲纹碗展柜"}


## Archive shelves along the back wall: plain boxes with labels.
func _build_shelves() -> void:
	for side in [-1.0, 1.0]:
		var x: float = 2.6 * side
		_box(Vector3(x, 1.0, 2.8), Vector3(1.6, 2.0, 0.4), materials["cabinet"], true)
		_art_panel("lab_archive", Vector3(x, 1.0, 2.585), Vector2(1.58, 1.98), PI)
	_label("文物档案柜", Vector3(-2.6, 2.1, 2.58), 0.05, Color("2e3534"), PI)


func _build_wall_details() -> void:
	# Wall clock on the west wall.
	_cylinder(Vector3(-3.99, 2.15, 1.2), 0.22, 0.04, materials["paper"], 32).rotation.z = PI * 0.5
	var hour := _box(Vector3(-3.96, 2.19, 1.2), Vector3(0.01, 0.09, 0.015), materials["dark"])
	hour.rotation.x = 0.0
	var minute := _box(Vector3(-3.96, 2.15, 1.25), Vector3(0.01, 0.015, 0.14), materials["dark"])
	minute.rotation.x = -0.6
	spots["clock"] = {"pos": Vector3(-3.99, 2.15, 1.2), "stand": Vector3(-2.9, 0, 1.2), "label": "挂钟"}
	# Whiteboard on the east wall.
	_box(Vector3(3.98, 1.6, 1.4), Vector3(0.04, 1.0, 1.6), materials["paper"])
	var notes := _label("今日扫描\n1. 莲纹碗　核对缺损 ✓\n2. 海兽葡萄纹铜镜　扫描……\n\n※ 不可凭想象补全纹样", Vector3(3.95, 1.65, 1.4), 0.045, Color("33415a"), -PI * 0.5)
	notes.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	spots["board"] = {"pos": Vector3(3.98, 1.6, 1.4), "stand": Vector3(2.9, 0, 1.4), "label": "白板"}


func _build_lab_details() -> void:
	# These AI panels belong to physical equipment; navigation still uses the real room.
	_art_panel("lab_scanner", Vector3(0, 0.45, 0.514), Vector2(1.87, 0.73))
	_art_panel("lab_scanner", Vector3(0, 0.45, -0.514), Vector2(1.87, 0.73), PI)
	_box(Vector3(-2.85, 1.98, -2.965), Vector3(2.06, 1.37, 0.045), materials["dark"])
	_art_panel("lab_research", Vector3(-2.85, 1.98, -2.935), Vector2(1.98, 1.29))
	_label("器物与修复 / 观察记录", Vector3(-2.85, 2.78, -2.94), 0.045, Color("415754"))
	spots["research"] = {"pos": Vector3(-2.85, 1.98, -2.94), "stand": Vector3(-1.8, 0, -2.0), "label": "文物研究展板"}
	# Recessed tile joints and wall skirting ground the room and give scale to the walk.
	for x in range(-4, 5):
		_box(Vector3(float(x), 0.009, 0), Vector3(0.006, 0.002, 6.0), materials["trim"])
	for z in range(-3, 4):
		_box(Vector3(0, 0.009, float(z)), Vector3(8.0, 0.002, 0.006), materials["trim"])
	for x in [-3.98, 3.98]:
		_box(Vector3(x, 0.08, 0), Vector3(0.025, 0.16, 6.0), materials["dark"])
	_box(Vector3(0, 0.08, 2.98), Vector3(8, 0.16, 0.025), materials["dark"])
	# Padded tray, sample jars, books and a small task lamp on the workstation.
	_box(Vector3(-3.57, 0.79, -1.1), Vector3(0.35, 0.025, 0.32), materials["dark"])
	for i in range(3):
		_cylinder(Vector3(-3.64 + i * 0.1, 0.86, -1.1), 0.035, 0.12, materials["glass"], 16)
		_cylinder(Vector3(-3.64 + i * 0.1, 0.925, -1.1), 0.036, 0.015, materials["accent"], 16)
	_box(Vector3(-2.52, 0.8, -1.35), Vector3(0.28, 0.035, 0.2), materials["paper"])
	_box(Vector3(-2.52, 0.83, -1.35), Vector3(0.27, 0.025, 0.2), materials["accent"])
	_cylinder(Vector3(3.45, 1.08, -1.15), 0.06, 0.08, materials["dark"], 16)
	_box(Vector3(3.45, 1.38, -1.15), Vector3(0.025, 0.58, 0.025), materials["steel"])
	_box(Vector3(3.27, 1.68, -1.15), Vector3(0.4, 0.035, 0.08), materials["steel"])


func _build_navigation() -> void:
	navigator = AStarGrid2D.new()
	navigator.region = Rect2i(0, 0, 37, 27)
	navigator.cell_size = Vector2.ONE * GRID_STEP
	navigator.offset = GRID_ORIGIN
	navigator.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigator.update()
	for x in range(37):
		for y in range(27):
			var p := GRID_ORIGIN + Vector2(x, y) * GRID_STEP
			for obstacle in obstacles:
				if obstacle.has_point(p):
					navigator.set_point_solid(Vector2i(x, y))
					break


func _free_cell(point: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var distance := INF
	for x in range(37):
		for y in range(27):
			var cell := Vector2i(x, y)
			if navigator.is_point_solid(cell):
				continue
			var d := navigator.get_point_position(cell).distance_squared_to(point)
			if d < distance:
				best = cell
				distance = d
	return best


func route_to(from: Vector3, id: String) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var stand: Vector3 = spots[id]["stand"]
	var start := _free_cell(Vector2(from.x, from.z))
	var finish := _free_cell(Vector2(stand.x, stand.z))
	if start == Vector2i(-1, -1) or finish == Vector2i(-1, -1):
		return result
	for p in navigator.get_point_path(start, finish):
		result.append(Vector3(p.x, 0, p.y))
	if not result.is_empty():
		result.append(stand)
	return result


## Turntable drifts slowly; the mirror and bowl lights breathe.
func animate(t: float, mirror_awake: float) -> void:
	if scan_model:
		scan_model.rotation.y = t * 0.3
	if turntable:
		turntable.rotation.y = t * 0.12
	if mirror_glow:
		mirror_glow.light_energy = 0.3 + 0.25 * mirror_awake + 0.05 * sin(t * 1.4)
	if bowl_glow:
		bowl_glow.light_energy = 0.55 + 0.05 * sin(t * 0.9)
