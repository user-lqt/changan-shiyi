extends "res://scripts/core/canvas.gd"
## 第四章 · 夜行: turn-based stealth across curfew Chang'an, rendered in 3D.
## Every move (or wait) is one turn. 金吾卫 patrol fixed routes; their vision is short in the
## dark and long under lanterns. Canals (~), carts (C) and doorways (D) hide you from sight.
## The ward gate (G) opens and closes with the street drum. Pebbles freeze a nearby guard.
## Tiles: # ward wall, . street, ~ canal, C cart, D doorway, G gate, S start, E goal.

const MAP := [
	"###.####.###..###.####.###",
	"###.####.###..###.####.###",
	"...........D...C..........",
	"###.#~##.###..###.####.###",
	"###.#~##.###..###.####.###",
	"###.#~##.##D..###.####.###",
	"S....~....C...............",
	"###.#~##.###..###.####.###",
	"###.#~##.###..###.####.###",
	"###.#~##.###..###.D####D##",
	".....~~~............C.....",
	"######################G###",
	"######################...E",
	"##########################",
]
const W := 26
const H := 14
const LANTERNS := [Vector2i(12, 6), Vector2i(13, 2), Vector2i(12, 10), Vector2i(22, 6), Vector2i(17, 10), Vector2i(8, 2)]
const GATE_PERIOD := 6
const DAWN := 150                # turns before the fifth watch ends
const STONES := 3
const NightActor = preload("res://scripts/core/night_actor.gd")
const STONE_RANGE := 4
const NOISE_RADIUS := 5
const FREEZE := 3
const DIRS := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "W": Vector2i(-1, 0), "E": Vector2i(1, 0)}
const LABELS := [
	{"t": "西市", "p": Vector2(0.5, 4.6)}, {"t": "永安渠", "p": Vector2(5.0, 1.6)},
	{"t": "朱雀大街", "p": Vector2(12.5, 0.4)}, {"t": "侧栅", "p": Vector2(22.0, 11.0)},
	{"t": "晋昌坊 · 大慈恩寺", "p": Vector2(24.0, 13.0)},
]
const LORE_TILES := {"canal": Vector2i(5, 6), "zhuque": Vector2i(12, 2), "jinwu": Vector2i(8, 6)}

var guards: Array = []           # {kind, path, faces, c, freeze, look, pos, dir, node, vis}
var player := Vector2i(0, 6)
var turn := 0
var stones := STONES
var aiming := false
var caught_count := 0
var phase := "play"              # play | caught | done
var checkpoint := {}
var undo_stack: Array = []
var scout_nodes: Array = []
var shelter_ring: MeshInstance3D
var trail: Array = []            # recent route, retained for corner-aware companion placement
var flash := 0.0
var drum := 0.0
var overview := false
var force_overview := false
var seen_lore := {}
var danger_cache := {}
# 攻略模式: G toggles. The route is re-solved from the current state after every turn.
var guide_route: Array = []      # remaining actions (Vector2i, ZERO = wait)
var guide_nodes: Array = []      # 3D path markers
var guide_arrow: MeshInstance3D
# 3D
var vp: SubViewport
var cam: Camera3D
var world: Node3D
var su_node: Node3D
var ashi_node: Node3D
var gate_doors: Array = []
var vis_pool: Array = []
var aim_node: MeshInstance3D
var cam_focus := Vector3.ZERO
var mats := {}
var actors := []
var su_actor: RefCounted
var lantern_swings := []
var lamp_lights := []
var cart_bays := {}
var stone_fx: MeshInstance3D
var stone_start := Vector3.ZERO
var stone_end := Vector3.ZERO
var stone_time := -1.0
var impact_ring: MeshInstance3D
var art_camera := false # Documentation close-up; normal navigation keeps the full HUD.
var _static_roots := []
var _plane_meshes := {}
var _box_meshes := {}
var _building_static := true
var batch_stats := {}
var temple_node: Node3D
var monk_node: Node3D
var monk_head: Node3D
var monk_lantern: Node3D


# ================================================================== setup
func enter() -> void:
	g.music("ambient")
	guards = [
		{"kind": "path", "path": _line(Vector2i(2, 6), Vector2i(8, 6))},
		{"kind": "path", "path": _line(Vector2i(12, 0), Vector2i(12, 10))},
		{"kind": "turn", "pos": Vector2i(17, 6), "faces": ["W", "W", "N", "N", "E", "E", "S", "S"]},
		{"kind": "path", "path": _line(Vector2i(13, 10), Vector2i(21, 10))},
		{"kind": "path", "path": _line(Vector2i(22, 2), Vector2i(22, 10))},
	]
	state = _fresh_state()
	checkpoint = state.duplicate(true)
	_build_3d()
	_sync_3d(true)
	_refresh_guide()
	g.say("ch4_arrive")


func _line(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var d := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var p := a
	out.append(p)
	while p != b:
		p += d
		out.append(p)
	return out


func _fresh_state() -> Dictionary:
	var gs := []
	for i in range(guards.size()):
		gs.append([0, 0, Vector2i.ZERO])       # step counter, freeze turns, look direction
	return {"p": Vector2i(0, 6), "t": 0, "gs": gs, "stones": STONES}


# ================================================================== pure rules (shared by play and solver)
var state := {}


func tile_at(p: Vector2i, t: int) -> String:
	if p.x < 0 or p.y < 0 or p.x >= W or p.y >= H:
		return "#"
	var c: String = MAP[p.y][p.x]
	if c == "G":
		return "." if gate_open(t) else "#"
	return c


func gate_open(t: int) -> bool:
	return (t / GATE_PERIOD) % 2 == 1


func walkable(p: Vector2i, t: int) -> bool:
	return tile_at(p, t) != "#"


func hidden(p: Vector2i) -> bool:
	return tile_at(p, 0) in ["~", "C", "D"]


func lit(p: Vector2i) -> bool:
	for l in LANTERNS:
		if absi(p.x - l.x) <= 1 and absi(p.y - l.y) <= 1:
			return true
	return false


func _cycle(i: int, c: int) -> int:
	var n: int = guards[i]["path"].size()
	var period := 2 * (n - 1)
	var k := posmod(c, period)
	return k if k < n else period - k


## Returns [position, facing] for guard i, given the list of all guard states.
func pose(i: int, all_gs: Array) -> Array:
	var gd: Dictionary = guards[i]
	var gs: Array = all_gs[i]
	var c: int = gs[0]
	var pos: Vector2i
	var dir: Vector2i
	if gd["kind"] == "path":
		pos = gd["path"][_cycle(i, c)]
		dir = (gd["path"][_cycle(i, c + 1)] as Vector2i) - pos
	else:
		pos = gd["pos"]
		dir = DIRS[gd["faces"][posmod(c, gd["faces"].size())]]
	if gs[1] > 0 and gs[2] != Vector2i.ZERO:
		dir = gs[2]
	return [pos, dir]


func _clear_line(a: Vector2i, b: Vector2i, t: int) -> bool:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in range(1, n):
		var f := float(k) / n
		var p := Vector2i(roundi(lerpf(a.x, b.x, f)), roundi(lerpf(a.y, b.y, f)))
		if not walkable(p, t):
			return false
	return true


## Tiles a guard can see: a cone 1 wide then 3 wide, 3 deep in the dark, 5 deep under lanterns.
var _vision_cache := {}


func vision(pos: Vector2i, dir: Vector2i, t: int) -> Array:
	var ck := Vector4i(pos.x, pos.y, dir.x * 3 + dir.y, 1 if gate_open(t) else 0)
	if _vision_cache.has(ck):
		return _vision_cache[ck]
	var out := []
	var side := Vector2i(-dir.y, dir.x)
	for k in range(1, 6):
		for l in ([0] if k == 1 else [-1, 0, 1]):
			var p: Vector2i = pos + dir * k + side * l
			if not walkable(p, t):
				continue
			if k > 3 and not lit(p):
				continue
			if not _clear_line(pos, p, t):
				continue
			out.append(p)
	_vision_cache[ck] = out
	return out


## Applies one player action to a state. action: Vector2i move (ZERO = wait), or
## {"stone": Vector2i}. Returns {"ok": bool, "caught": bool, "state": Dictionary}.
func simulate(s: Dictionary, action) -> Dictionary:
	var ns: Dictionary = s.duplicate(true)
	var old: Vector2i = s["p"]
	var t: int = s["t"] + 1
	if action is Dictionary:
		var target: Vector2i = action["stone"]
		if ns["stones"] <= 0 or absi(target.x - old.x) + absi(target.y - old.y) > STONE_RANGE or not walkable(target, t):
			return {"ok": false, "caught": false, "state": s}
		ns["stones"] -= 1
		for i in range(guards.size()):
			var gp: Vector2i = pose(i, s["gs"])[0]
			if absi(gp.x - target.x) + absi(gp.y - target.y) <= NOISE_RADIUS:
				var look := target - gp
				look = Vector2i(signi(look.x), 0) if absi(look.x) >= absi(look.y) else Vector2i(0, signi(look.y))
				ns["gs"][i] = [s["gs"][i][0], FREEZE, look]
	else:
		var np: Vector2i = old + (action as Vector2i)
		if not walkable(np, t):
			return {"ok": false, "caught": false, "state": s}
		ns["p"] = np
	ns["t"] = t
	for i in range(guards.size()):
		var gs: Array = ns["gs"][i]
		if action is Dictionary and gs[1] == FREEZE:
			continue                   # just distracted this turn
		if gs[1] > 0:
			gs[1] -= 1
			if gs[1] == 0:
				gs[2] = Vector2i.ZERO
		else:
			gs[0] += 1
	return {"ok": true, "caught": is_caught(ns, s), "state": ns}


func is_caught(ns: Dictionary, old: Dictionary) -> bool:
	var p: Vector2i = ns["p"]
	for i in range(guards.size()):
		var now := pose(i, ns["gs"])
		var before := pose(i, old["gs"])
		if now[0] == p or (now[0] == old["p"] and before[0] == p):
			return true
		if not hidden(p) and vision(now[0], now[1], ns["t"]).has(p):
			return true
	return false


func goal() -> Vector2i:
	return Vector2i(25, 12)


## Breadth-first search over moves only (no stones) — proves the level is solvable,
## and drives 攻略模式 by solving from the player's current state.
func solve(limit := 200, from := {}) -> Array:
	var start: Dictionary = _fresh_state() if from.is_empty() else from
	var horizon: int = limit - start["t"]
	if horizon <= 0 or start["p"] == goal():
		return []
	# No new stones are thrown by the guide. All patrols therefore share one
	# deterministic timeline, including any distraction already in progress.
	# Evaluate that timeline once per turn rather than cloning every state for
	# every candidate move. Integer parent indices also avoid long string keys.
	var area := W * H
	var parent := PackedInt32Array()
	parent.resize((horizon + 1) * area)
	parent.fill(-1)
	var first: int = start["p"].y * W + start["p"].x
	parent[first] = -2
	var frontier := PackedInt32Array([first])
	var gs: Array = start["gs"].duplicate(true)
	var directions := [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for elapsed in range(1, horizon + 1):
		var t: int = start["t"] + elapsed
		var danger := PackedByteArray()
		danger.resize(area)
		var swaps := {}
		for i in range(guards.size()):
			var before: Vector2i = pose(i, gs)[0]
			if gs[i][1] > 0:
				gs[i][1] -= 1
				if gs[i][1] == 0:
					gs[i][2] = Vector2i.ZERO
			else:
				gs[i][0] += 1
			var now := pose(i, gs)
			var at: Vector2i = now[0]
			danger[at.y * W + at.x] = 1
			swaps[(at.y * W + at.x) * area + before.y * W + before.x] = true
			for p in vision(at, now[1], t):
				if not hidden(p):
					danger[p.y * W + p.x] = 1
		var next := PackedInt32Array()
		for here in frontier:
			var tile: int = here % area
			var p := Vector2i(tile % W, tile / W)
			for d in directions:
				var to: Vector2i = p + d
				if not walkable(to, t):
					continue
				var target: int = to.y * W + to.x
				var key: int = elapsed * area + target
				if parent[key] != -1 or danger[target] or swaps.has(tile * area + target):
					continue
				parent[key] = here
				if to == goal():
					var path := []
					while parent[key] >= 0:
						var old: int = parent[key]
						var old_tile := old % area
						var new_tile := key % area
						path.push_front(Vector2i(new_tile % W - old_tile % W, new_tile / W - old_tile / W))
						key = old
					return path
				next.append(key)
		frontier = next
		if frontier.is_empty():
			break
	return []


## Guard counters reduced by each patrol period, freeze timers and the gate phase.
func _state_key(s: Dictionary) -> String:
	var k := "%d,%d,%d" % [s["p"].x, s["p"].y, s["t"] % (GATE_PERIOD * 2)]
	for i in range(guards.size()):
		var gs: Array = s["gs"][i]
		var gd: Dictionary = guards[i]
		var period: int = 2 * (gd["path"].size() - 1) if gd["kind"] == "path" else gd["faces"].size()
		k += "|%d,%d" % [posmod(gs[0], period), gs[1]]
	return k


# ================================================================== play
func do(action) -> void:
	if phase != "play" or g.blocked():
		return
	var r := simulate(state, action)
	if not r["ok"]:
		g.sfx("error", -14)
		return
	undo_stack.append({"state": state.duplicate(true), "trail": trail.duplicate(),
		"seen": seen_lore.duplicate(), "collected": g.collected.duplicate(), "caught": caught_count})
	if undo_stack.size() > DAWN:
		undo_stack.pop_front()
	var before: Vector2i = state["p"]
	state = r["state"]
	if action is Dictionary:
		g.sfx("place")
		flash = 0.6
		_throw_visual(action["stone"])
	elif before != state["p"]:
		trail.push_front(before)
		trail.resize(mini(trail.size(), 4))
		g.sfx("hover", -14)
	if state["t"] % GATE_PERIOD == 0:
		drum = 1.0
		g.sfx("bell", -10)
	aiming = false
	_sync_3d(false)
	if guiding() and not guide_route.is_empty() and action is Vector2i and action == guide_route[0]:
		guide_route.pop_front()        # still on the planned route: no need to re-solve
		_show_guide_path()
	else:
		_refresh_guide()
	if r["caught"]:
		_caught()
		return
	_check_tile()
	if state["p"] == goal():
		_win()
	elif state["t"] >= DAWN:
		phase = "caught"
		g.say("ch4_dawn")


func _check_tile() -> void:
	var p: Vector2i = state["p"]
	if p.x >= 13 and not checkpoint.get("mid", false):
		checkpoint = state.duplicate(true)
		checkpoint["mid"] = true
		undo_stack.clear()
		g.notify("过了朱雀大街。阿拾：「被抓的话，从这里重新来。」", 5)
	for id in LORE_TILES:
		if LORE_TILES[id] == p and not seen_lore.has(id):
			seen_lore[id] = true
			g.show_card("night_" + id)


func _caught() -> void:
	phase = "caught"
	caught_count += 1
	g.stats["caught"] = int(g.stats.get("caught", 0)) + 1
	g.sfx("objection")
	flash = 1.0
	g.say("ch4_caught")


func undo_step() -> bool:
	if phase not in ["play", "caught"] or g.blocked() or undo_stack.is_empty():
		return false
	var saved: Dictionary = undo_stack.pop_back()
	state = saved["state"].duplicate(true)
	trail = saved["trail"].duplicate()
	seen_lore = saved["seen"].duplicate()
	g.collected = saved["collected"].duplicate()
	var removed := caught_count - int(saved["caught"])
	g.stats["caught"] = maxi(0, int(g.stats.get("caught", 0)) - removed)
	caught_count = int(saved["caught"])
	phase = "play"
	aiming = false
	flash = 0.0
	drum = 0.0
	_sync_3d(true)
	_refresh_guide()
	g.sfx("dial", -12)
	return true


func _restart_checkpoint() -> void:
	state = checkpoint.duplicate(true)
	state.erase("mid")
	if checkpoint.get("mid", false):
		state["mid"] = true
	trail = []
	undo_stack.clear()
	aiming = false
	phase = "play"
	_sync_3d(true)
	_refresh_guide()


func _win() -> void:
	phase = "done"
	g.sfx("complete")
	g.say("ch4_done", func() -> void:
		g.clear("ch4")
		g.notify("第四章完成。寺僧已答应留住残片。天明后赴曲江，请人引见。", 8))


# ================================================================== 3D scene
func _load(name: String) -> Node3D:
	var path := "res://assets/models/night_%s.glb" % name
	if ResourceLoader.exists(path):
		return (load(path) as PackedScene).instantiate()
	var mi := MeshInstance3D.new()          # fallback if the kit is missing
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 1.0, 0.6)
	mi.mesh = bm
	mi.position.y = 0.5
	var n := Node3D.new()
	n.add_child(mi)
	return n


func _flat(color: Color, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = 0.9
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _quad(p: Vector2i, y: float, material: Material, size := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not _plane_meshes.has(size):
		var pm := PlaneMesh.new()
		pm.size = Vector2(size, size)
		_plane_meshes[size] = pm
	mi.mesh = _plane_meshes[size]
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(p.x, y, p.y)
	world.add_child(mi)
	if _building_static:
		_static_roots.append(mi)
	return mi


func _place(name: String, p: Vector2i, yaw := 0.0, y := 0.0) -> Node3D:
	var n := _load(name)
	n.position = Vector3(p.x, y, p.y)
	n.rotation.y = yaw
	world.add_child(n)
	if name in ["wall", "house", "cart"]:
		_static_roots.append(n)
	return n


func yaw_of(d: Vector2i) -> float:
	return atan2(-float(d.y), float(d.x))


func _build_3d() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(1440, 900)       # the 3D view fills the window; the HUD floats on top
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("070d14")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("708ba7")
	e.ambient_light_energy = 0.16
	e.fog_enabled = true
	e.fog_light_color = Color("0c1622")
	e.fog_density = 0.012
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("a7c7e1")
	moon.light_energy = 0.21
	moon.rotation_degrees = Vector3(-55, -35, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 38.0
	world.add_child(moon)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("809cad")
	rim.light_energy = 0.045
	rim.rotation_degrees = Vector3(-25, 145, 0)
	world.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 42
	world.add_child(cam)
	mats = {
		"street": _flat(Color("4a4036")), "earth": _flat(Color("2a2420")),
		"water": _flat(Color("1d3a4a")), "hide": _flat(Color("3fbf8f"), 0.0, 0.18),
		"vision": _flat(Color("ff4a2a"), 0.0, 0.32), "vision_lit": _flat(Color("ffb040"), 0.0, 0.38),
		"goal": _flat(Color("ffd27a"), 2.0, 0.55), "aim": _flat(Color("9fd8ff"), 0.0, 0.5),
		"aim_ok": _flat(Color("ffffff"), 0.0, 0.16),
	}
	(mats["water"] as StandardMaterial3D).roughness = 0.15
	(mats["water"] as StandardMaterial3D).metallic = 0.3
	var water := ShaderMaterial.new()
	water.shader = preload("res://scripts/shaders/night_water.gdshader")
	mats["water"] = water
	mats["street"] = _paving_material()
	var ground := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(W + 12, H + 12)
	ground.mesh = gp
	ground.material_override = mats["earth"]
	ground.position = Vector3(W * 0.5 - 0.5, -0.02, H * 0.5 - 0.5)
	world.add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 618
	# Recess carts into shallow parking bays beside the road. The marked hiding
	# tile remains clear for both characters instead of putting them inside cargo.
	for y in range(H):
		for x in range(W):
			if MAP[y][x] != "C":
				continue
			var p := Vector2i(x, y)
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var bay: Vector2i = p + d
				if bay.x >= 0 and bay.y >= 0 and bay.x < W and bay.y < H and MAP[bay.y][bay.x] == "#":
					cart_bays[bay] = d
					break
	for y in range(H):
		for x in range(W):
			var p := Vector2i(x, y)
			var c: String = MAP[y][x]
			match c:
				"#":
					if cart_bays.has(p):
						_quad(p, 0.0, mats["street"])
						var d: Vector2i = cart_bays[p]
						var back := _place("wall", p)
						back.position += Vector3(d.x, 0, d.y) * 0.34
						back.scale = Vector3(1, 1, 0.28) if d.y else Vector3(0.28, 1, 1)
					elif _borders_street(p):
						_place("wall", p)
					elif (x * 7 + y * 3) % 4 == 0:
						_place("house", p, rng.randi_range(0, 3) * PI * 0.5).scale = Vector3(0.68, 0.83, 0.68)
				"~":
					_quad(p, -0.08, mats["water"])
				"G":
					_quad(p, 0.0, mats["street"])
					_place("gate", p)
					var l := _place("door", p + Vector2i.ZERO)
					l.position.x -= 0.5
					var r := _place("door", p)
					r.position.x += 0.5
					r.scale.x = -1
					gate_doors = [l, r]
				_:
					_quad(p, 0.0, mats["street"])
			if c == "C":
				var cart := _place("cart", p)
				cart.scale = Vector3.ONE * 0.76
				for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if cart_bays.get(p + d, Vector2i.ZERO) == d:
						cart.position += Vector3(d.x, 0, d.y) * 0.85
						cart.rotation.y = 0.0 if d.y else PI * 0.5
						break
				_quad(p, 0.01, mats["hide"], 0.9)
			if c == "D":
				_quad(p, 0.01, mats["hide"], 0.9)
			if c == "~":
				_quad(p, 0.01, mats["hide"], 0.9)
				_canal_edges(p)
	for l in LANTERNS:
		var spot := _lantern_spot(l)
		var post := _place("lantern", spot, yaw_of(l - spot))
		var swing := post.find_child("LanternSwing", true, false) as Node3D
		if swing:
			lantern_swings.append(swing)
		var light := OmniLight3D.new()
		light.light_color = Color("ffca88")
		light.light_energy = 0.72
		light.omni_range = 3.1
		light.position = Vector3(l.x, 1.3, l.y)
		world.add_child(light)
		lamp_lights.append(light)
	_quad(goal(), 0.04, mats["goal"], 0.9)
	_building_static = false
	for gd in guards:
		gd["node"] = _place("guard", Vector2i.ZERO)
		gd["node"].scale = Vector3.ONE * 1.16
		var actor := NightActor.new(gd["node"], "guard", actors.size() * 1.7)
		gd["actor"] = actor
		actors.append(actor)
		_ring(gd["node"], Color("ff5a3a"))
	su_node = _place("su", state["p"])
	su_node.scale = Vector3.ONE * 1.10
	_ring(su_node, Color("8fe0ff"))
	su_actor = NightActor.new(su_node, "su")
	actors.append(su_actor)
	ashi_node = _place("ashi", state["p"])
	ashi_node.scale = Vector3.ONE * 1.04
	actors.append(NightActor.new(ashi_node, "ashi", 0.8))
	_build_stone_fx()
	for i in range(60):
		var q := _quad(Vector2i.ZERO, 0.03, mats["vision"], 0.92)
		q.visible = false
		vis_pool.append(q)
	aim_node = _quad(Vector2i.ZERO, 0.05, mats["aim"], 0.8)
	aim_node.visible = false
	_street_dressing()
	_build_temple_approach()
	batch_stats = preload("res://scripts/core/night_batch.gd").combine(world, _static_roots)
	_static_roots.clear()
	# Reuse six lightweight markers; scouting never adds per-frame meshes.
	var scout_mat := _flat(Color("e4d7a1"), 0.0, 0.38)
	for i in range(guards.size()):
		var marker := _quad(Vector2i.ZERO, 0.055, scout_mat, 0.55)
		marker.visible = false
		scout_nodes.append(marker)
	shelter_ring = _quad(Vector2i.ZERO, 0.045, _flat(Color("57d9b0"), 0.0, 0.3), 0.96)
	shelter_ring.visible = false


func _build_temple_approach() -> void:
	# The tower stands beyond the east boundary. Its steps begin after the
	# goal tile, keeping the verified street route on the original ground.
	temple_node = _load("pagoda_base")
	temple_node.name = "CienPagoda"
	temple_node.position = Vector3(28.6, 0, 12.0)
	temple_node.rotation.y = -PI * 0.5
	world.add_child(temple_node)
	var courtyard := _flat(Color("65685b"))
	_detail_box(Vector3(6.0, 0.04, 5.5), Vector3(28.1, -0.035, 12.0), courtyard)
	var paving := _flat(Color("a49c83"))
	for x in [25.15, 25.55]:
		_detail_box(Vector3(0.37, 0.025, 0.85), Vector3(x, 0.012, 12.0), paving)
	var plaque := Label3D.new()
	plaque.name = "TemplePlaque"
	plaque.text = "大慈恩寺"
	plaque.font = g.heading
	plaque.font_size = 80
	plaque.pixel_size = 0.0036
	plaque.outline_size = 1
	plaque.modulate = Color("dfc991")
	plaque.outline_modulate = Color("342b1d")
	plaque.position = Vector3(0, 2.30, 2.09)
	plaque.no_depth_test = false
	temple_node.add_child(plaque)
	for side in [-1.0, 1.0]:
		var lantern := _load("lantern")
		lantern.position = Vector3(26.1, 0, 12.0 + side * 1.35)
		lantern.rotation.y = -PI * 0.5
		world.add_child(lantern)
	var welcome := OmniLight3D.new()
	welcome.name = "TempleEntranceLight"
	welcome.position = Vector3(25.9, 1.65, 12.0)
	welcome.light_color = Color("ffd79b")
	welcome.light_energy = 0.85
	welcome.omni_range = 3.1
	world.add_child(welcome)
	monk_node = _load("monk")
	monk_node.name = "TempleNightMonk"
	monk_node.position = Vector3(26.55, 0.33, 12.52)
	monk_node.rotation.y = PI
	monk_node.scale = Vector3.ONE * 1.08
	monk_node.visible = false
	world.add_child(monk_node)
	monk_head = monk_node.find_child("Head", true, false) as Node3D
	monk_lantern = monk_node.find_child("HandLantern", true, false) as Node3D


func _paving_material() -> StandardMaterial3D:
	# One seamless tile with small staggered stones and fine, low contrast joints.
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(256):
			var row := y / 64
			var shift := 32 if row % 2 == 0 else 0
			var edge := y % 64 < 2 or (x + shift) % 128 < 2
			var cell := posmod((x + shift) / 128 * 17 + row * 23, 7)
			var noise := sin(x * 43.12 + y * 12.78) * 0.012
			var value := (0.27 + cell * 0.007 + noise) if not edge else 0.20
			image.set_pixel(x, y, Color(value * 0.93, value, value * 1.02))
	image.generate_mipmaps()
	var material := _flat(Color.WHITE)
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = 0.89
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material


func _detail_box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	if not _box_meshes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		_box_meshes[size] = mesh
	n.mesh = _box_meshes[size]
	n.material_override = material
	n.position = at
	world.add_child(n)
	_static_roots.append(n)
	return n


func _canal_edges(p: Vector2i) -> void:
	if not mats.has("curb"):
		mats["curb"] = _flat(Color("71776c"))
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if tile_at(p + d, 0) == "~":
			continue
		var size := Vector3(0.055, 0.10, 0.96) if d.x else Vector3(0.96, 0.10, 0.055)
		_detail_box(size, _v3(p, -0.015) + Vector3(d.x, 0, d.y) * 0.47, mats["curb"])


func _street_dressing() -> void:
	# Keep everything beside the logical road, below the readable wall silhouette.
	var timber := _flat(Color("5c4a34"))
	var paper := _flat(Color("ab9974"))
	for p in [Vector2i(2, 5), Vector2i(9, 5), Vector2i(16, 1), Vector2i(20, 9)]:
		for i in range(3):
			_detail_box(Vector3(0.35, 0.07, 0.22), _v3(p, 0.16 + i * 0.075), timber)
		var poster := _detail_box(Vector3(0.23, 0.22, 0.008), _v3(p, 0.34) + Vector3(0, 0, 0.506), paper)
		poster.rotation.z = 0.035
		for i in range(3):
			_detail_box(Vector3(0.13 - i * 0.02, 0.006, 0.003), poster.position + Vector3(0, 0.05 - i * 0.04, 0.006), timber)


func _build_stone_fx() -> void:
	stone_fx = MeshInstance3D.new()
	var pebble := SphereMesh.new()
	pebble.radius = 0.055
	pebble.height = 0.09
	stone_fx.mesh = pebble
	stone_fx.material_override = _flat(Color("c6baa2"))
	stone_fx.visible = false
	world.add_child(stone_fx)
	impact_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.26
	ring.outer_radius = 0.28
	ring.rings = 32
	ring.ring_segments = 6
	impact_ring.mesh = ring
	impact_ring.material_override = _flat(Color("f3d19a"), 0.5, 0.60)
	impact_ring.visible = false
	world.add_child(impact_ring)


func _throw_visual(target: Vector2i) -> void:
	if not su_node:
		return
	stone_start = su_node.position + Vector3(0, 0.9, 0)
	stone_end = _v3(target, 0.04)
	stone_time = 0.0
	su_actor.throw_stone()
	var direction := stone_end - su_node.position
	su_node.rotation.y = atan2(-direction.z, direction.x)


## Glowing ground ring so characters stay readable from the high camera.
func _ring(parent: Node3D, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.20
	tm.outer_radius = 0.245
	tm.rings = 24
	tm.ring_segments = 6
	mi.mesh = tm
	mi.scale = Vector3(1, 0.15, 1)
	mi.position.y = 0.03
	mi.material_override = _flat(color, 1.0)
	parent.add_child(mi)


func _borders_street(p: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H and MAP[q.y][q.x] != "#":
				return true
	return false


## Lanterns hang on a post standing on the nearest wall tile, leaning over the street.
func _lantern_spot(l: Vector2i) -> Vector2i:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if MAP[l.y + d.y][l.x + d.x] == "#":
			return l + d
	return l


func _v3(p: Vector2i, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


## Moves models to the logical state. snap = jump instead of animating.
func _sync_3d(snap: bool) -> void:
	if not world:
		return
	danger_cache = {}
	var t: int = state["t"]
	var used := 0
	for i in range(guards.size()):
		var pz := pose(i, state["gs"])
		var gd: Dictionary = guards[i]
		gd["to"] = _v3(pz[0])
		gd["yaw"] = yaw_of(pz[1])
		if snap:
			(gd["node"] as Node3D).position = gd["to"]
			(gd["node"] as Node3D).rotation.y = gd["yaw"]
		for v in vision(pz[0], pz[1], t):
			if used < vis_pool.size():
				var q: MeshInstance3D = vis_pool[used]
				q.position = _v3(v, 0.03)
				q.material_override = mats["vision_lit"] if lit(v) else mats["vision"]
				q.visible = true
				used += 1
			danger_cache[v] = true
	for k in range(used, vis_pool.size()):
		vis_pool[k].visible = false
	if shelter_ring:
		var sheltered := hidden(state["p"]) and phase == "play"
		shelter_ring.visible = sheltered
		shelter_ring.position = _v3(state["p"], 0.045)
		var forecast: Dictionary = simulate(state, Vector2i.ZERO)["state"]
		for i in range(scout_nodes.size()):
			var next_pose: Array = pose(i, forecast["gs"])
			var near: bool = (next_pose[0] as Vector2i).distance_to(state["p"]) <= 7.0
			scout_nodes[i].visible = sheltered and near
			scout_nodes[i].position = _v3(next_pose[0], 0.055)
			scout_nodes[i].rotation.y = yaw_of(next_pose[1])
	if snap:
		su_node.position = _v3(state["p"])
		ashi_node.position = _companion_target()
		cam_focus = _v3(state["p"])
		for actor in actors:
			actor.snap()
		stone_time = -1.0
		stone_fx.visible = false
		impact_ring.visible = false


func _visual_clear(at: Vector3, radius := 0.22) -> bool:
	for x in [-radius, radius]:
		for z in [-radius, radius]:
			if not walkable(Vector2i(roundi(at.x + x), roundi(at.z + z)), state["t"]):
				return false
	return true


func _companion_target() -> Vector3:
	# Tight single-file spacing fits one-tile alleys. At corners choose a clear
	# neighbouring position instead of letting a rotating side offset enter walls.
	var forward := Vector3.RIGHT.rotated(Vector3.UP, su_node.rotation.y)
	var side := Vector3.BACK.rotated(Vector3.UP, su_node.rotation.y)
	var preferred := -forward * 0.56 + side * 0.06
	var offsets := [preferred, -forward * 0.58 - side * 0.06,
		forward * 0.56, side * 0.56, -side * 0.56,
		Vector3(0.56, 0, 0), Vector3(-0.56, 0, 0),
		Vector3(0, 0, 0.56), Vector3(0, 0, -0.56),
		Vector3(-0.40, 0, -0.40), Vector3(0.40, 0, -0.40),
		Vector3(-0.40, 0, 0.40), Vector3(0.40, 0, 0.40)]
	for offset in offsets:
		var target: Vector3 = su_node.position + offset
		if _visual_clear(target):
			return target
	# During a very tight turn the nearest recent route tile supplies the offset.
	if not trail.is_empty():
		var back := _v3(trail[0]) - su_node.position
		back.y = 0.0
		if back.length() > 0.1:
			return su_node.position + back.normalized() * 0.56
	return su_node.position - forward * 0.50


func _follow_companion(delta: float) -> void:
	var target := _companion_target()
	var next := ashi_node.position.lerp(target, 1.0 - exp(-delta * 20.0))
	# Slide along corners; the companion never cuts through the ward-wall mesh.
	if not _visual_clear(next):
		var slide_x := Vector3(next.x, next.y, ashi_node.position.z)
		var slide_z := Vector3(ashi_node.position.x, next.y, next.z)
		next = slide_x if _visual_clear(slide_x) else (slide_z if _visual_clear(slide_z) else ashi_node.position)
		if not _visual_clear(next):
			next = target # Also handles the side gate closing behind the pair.
	var separation := Vector2(next.x - su_node.position.x, next.z - su_node.position.z).length()
	if separation < 0.46 or separation > 0.72:
		# Re-form immediately on rapid direction changes, without body overlap.
		next = target
	ashi_node.position = next


func _animate(delta: float) -> void:
	if not world:
		return
	if shelter_ring and shelter_ring.visible:
		shelter_ring.scale = Vector3.ONE * (0.97 + 0.03 * sin(age * 2.8))
	var k := 1.0 - exp(-delta * 12.0)
	for gd in guards:
		var n: Node3D = gd["node"]
		n.position = n.position.lerp(gd.get("to", n.position), k)
		n.rotation.y = lerp_angle(n.rotation.y, gd.get("yaw", 0.0), k)
	var target := _v3(state["p"])
	var before := su_node.position
	su_node.position = su_node.position.lerp(target, k)
	var mv := target - before
	if mv.length() > 0.002:
		su_node.rotation.y = lerp_angle(su_node.rotation.y, atan2(-mv.z, mv.x), k)
	su_node.position.y = -0.12 if tile_at(state["p"], 0) == "~" else 0.0
	_follow_companion(delta)
	ashi_node.rotation.y = lerp_angle(ashi_node.rotation.y, su_node.rotation.y, k)
	for i in range(guards.size()):
		guards[i]["actor"].update(delta, false, state["gs"][i][1] > 0, false)
	su_actor.update(delta, hidden(state["p"]), false, false)
	actors.back().update(delta, hidden(state["p"]), false, false)
	_animate_atmosphere(delta)
	if monk_node:
		monk_node.visible = phase == "done"
		if monk_head:
			monk_head.rotation.z = -0.025 + sin(age * 1.2) * 0.012
		if monk_lantern:
			monk_lantern.rotation.x = sin(age * 1.5) * 0.035
	var open := gate_open(state["t"])
	for i in range(gate_doors.size()):
		var d: Node3D = gate_doors[i]
		var want := (PI * 0.55 if open else 0.0) * (-1.0 if i == 0 else 1.0)
		d.rotation.y = lerp_angle(d.rotation.y, want, k * 0.5)
	# Camera: angled overhead, or a full-map view when holding Tab.
	var focus := Vector3(W * 0.5 - 0.5, 0, H * 0.5 - 0.5) if overview else su_node.position + Vector3(0.65, 0, 0)
	var temple_view := smoothstep(22.0, 25.0, su_node.position.x) if su_node.position.z > 11.2 and not overview and not art_camera else 0.0
	focus += Vector3(0.85, 0.35, 0) * temple_view
	cam_focus = cam_focus.lerp(focus, k * 0.6)
	var dist := 25.0 if overview else (5.2 if art_camera else 12.0)
	var angle := Vector3(-0.12, 1.0, 0.42) if overview else Vector3(-0.22, 1.0, 0.72)
	angle = angle.lerp(Vector3(-0.72, 1.1, 0.82), temple_view)
	if art_camera:
		angle = Vector3(1.0, 0.85, 1.1)
	cam.position = cam_focus + angle.normalized() * dist
	cam.look_at(cam_focus + Vector3(0, 0.30 if art_camera else 0.0, 0), Vector3.UP)
	if aiming:
		var tgt := _aim_tile()
		aim_node.visible = true
		aim_node.position = _v3(tgt, 0.06)
		aim_node.material_override = mats["aim"] if _stone_ok(tgt) else mats["aim_ok"]
	else:
		aim_node.visible = false


func _animate_atmosphere(delta: float) -> void:
	for i in range(lantern_swings.size()):
		lantern_swings[i].rotation.z = sin(age * 1.3 + i * 1.7) * 0.035
	for i in range(lamp_lights.size()):
		lamp_lights[i].light_energy = 0.72 + sin(age * 3.5 + i) * 0.025 + sin(age * 8.2 + i) * 0.01
	if stone_time >= 0.0:
		stone_time += delta
		var t := clampf((stone_time - 0.16) / 0.43, 0.0, 1.0)
		stone_fx.visible = stone_time >= 0.16 and t < 1.0
		stone_fx.position = stone_start.lerp(stone_end, t) + Vector3(0, sin(t * PI) * 0.85, 0)
		var impact := stone_time - 0.59
		impact_ring.visible = impact >= 0.0 and impact < 0.65
		impact_ring.position = stone_end
		impact_ring.scale = Vector3.ONE * (0.4 + maxf(impact, 0.0) * 3.0)
		if stone_time > 1.25:
			stone_time = -1.0


func _stone_ok(p: Vector2i) -> bool:
	var me: Vector2i = state["p"]
	return state["stones"] > 0 and absi(p.x - me.x) + absi(p.y - me.y) <= STONE_RANGE and walkable(p, state["t"] + 1)


## Grid tile under the mouse, by intersecting the camera ray with the ground plane.
func _aim_tile() -> Vector2i:
	var m := _mouse()
	if not cam:
		return Vector2i.ZERO
	var o := cam.project_ray_origin(m)
	var d := cam.project_ray_normal(m)
	if absf(d.y) < 0.001:
		return state["p"]
	var hitp := o + d * (-o.y / d.y)
	return Vector2i(roundi(hitp.x), roundi(hitp.z))


# ================================================================== input
func tick(delta: float, _blocked: bool) -> void:
	flash = maxf(0.0, flash - delta * 1.5)
	drum = maxf(0.0, drum - delta * 1.2)
	overview = force_overview or (Input.is_key_pressed(KEY_TAB) and not g.blocked())
	_animate(delta)
	_animate_guide()


func key(event: InputEventKey) -> bool:
	if g.blocked():
		return false
	if event.keycode == KEY_Z:
		undo_step()
		return true
	if phase == "caught" and event.keycode == KEY_R:
		_restart_checkpoint()
		return true
	if phase != "play":
		return false
	match event.keycode:
		KEY_W, KEY_UP:
			do(Vector2i(0, -1))
		KEY_S, KEY_DOWN:
			do(Vector2i(0, 1))
		KEY_A, KEY_LEFT:
			do(Vector2i(-1, 0))
		KEY_D, KEY_RIGHT:
			do(Vector2i(1, 0))
		KEY_SPACE, KEY_PERIOD:
			do(Vector2i.ZERO)
		KEY_Q:
			if state["stones"] > 0:
				aiming = not aiming
		KEY_R:
			_restart_checkpoint()
		KEY_G:
			toggle_guide()
		KEY_TAB:
			pass
		_:
			return false
	return true


func mouse(event: InputEvent) -> bool:
	if phase != "play" or g.blocked() or not aiming:
		return false
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var p := _aim_tile()
			if _stone_ok(p):
				do({"stone": p})
			else:
				g.sfx("error", -12)
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			aiming = false
			return true
	return false


func act(id: String) -> void:
	if _common_act(id):
		return
	match id:
		"undo":
			undo_step()
		"wait":
			do(Vector2i.ZERO)
		"stone":
			if state["stones"] > 0:
				aiming = not aiming
		"retry":
			_restart_checkpoint()
		"guide":
			toggle_guide()
		"to_map":
			g.go("map")


# ================================================================== text
func help_lines() -> Array:
	return ["WASD / 方向键走一步，空格原地等一回合。每走一步，金吾卫也走一步。",
		"红色地块是金吾卫的视线：暗处只看 3 格，灯笼下能看 5 格。墙会挡住视线。",
		"绿色藏身处可避开视线；淡金标记预告附近守卫下一步，不能与守卫同格。",
		"阿拾会自动跟在身后，他不会被金吾卫发现，不用管他的位置。",
		"卡住了？按 G 打开攻略模式：地上的金色脚印是安全路线，右上角告诉你下一步按什么。",
		"Q 进入投石，点击 4 格内的地面：附近的金吾卫会转头看 3 回合。右键取消。",
		"Z 撤回一步；R 回检查点；Tab 看全图。侧栅每 %d 回合开关一次。" % GATE_PERIOD]


func journal_lines() -> Array:
	return ["阿拾：「沿永安渠往下走，过朱雀大街，从送柴的侧栅进晋昌坊。咱们要赶在清扫前到寺门报失。」",
		"金吾卫：掌京城昼夜巡警。夜禁之后无故在街上行走，叫「犯夜」。",
		"剩余石子 %d，已行进 %d 回合（%d 回合时天亮）。" % [state["stones"], state["t"], DAWN]]


func hint() -> String:
	var p: Vector2i = state["p"]
	if p.x < 4:
		return "先往东走到第一个路口，躲进北边巷子，等那名金吾卫走回去。"
	if p.x < 13:
		return "朱雀大街上有灯笼，视线很长。从北边的街绕过去，看准金吾卫背对你的时候走。"
	if p.x < 22:
		return "东边站着一名会转身的金吾卫。数一数他朝向变化的节奏，或者投石让他看别处。"
	if not gate_open(state["t"]):
		return "侧栅关着。站在门洞或暗处等交接的鼓声，栅门开了再进。"
	return "侧栅开了，快进去！"


# ================================================================== drawing
func _draw() -> void:
	hit_regions.clear()
	var goals := [
		{"t": "潜出西市", "d": "离开起点，不被金吾卫看见", "done": state["p"].x > 3 or phase == "done"},
		{"t": "过朱雀大街", "d": "城中轴线，灯火最亮", "done": state["p"].x >= 13 or phase == "done"},
		{"t": "到寺门报失", "d": "穿过侧栅，走到金色地块", "done": phase == "done"},
	]
	var items := [{"id": "stone", "name": "石子 ×%d" % state["stones"], "sub": "Q 投掷"}]
	var obj := "第 %d / %d 回合 · %s" % [state["t"], DAWN, "侧栅已开" if gate_open(state["t"]) else "侧栅紧闭"]
	if phase == "done":
		obj = "寺僧已答应留住残片。天明后赴曲江。"
	_frame("第四章  ·  夜行", "长安街衢  /  宵禁 · 夜行", goals, obj, items, "stone" if aiming else "")
	var full := Rect2(0, 0, 1440, 900)
	if vp:
		draw_texture_rect(vp.get_texture(), full, false)
	if danger_cache.has(state["p"]):
		draw_rect(full, Color(1, 0.2, 0.1, 0.08 + 0.05 * sin(age * 8)))
	if flash > 0:
		draw_rect(full, Color(1, 0.3, 0.2, flash * 0.25) if phase == "caught" else Color(0.7, 0.9, 1, flash * 0.12))
	_hud(_draw_night_hud)


func _draw_night_hud() -> void:
	# Watch bar under the chapter title: five watches until dawn.
	var bar := Rect2(44, 150, 260, 6)
	cv.draw_rect(bar.grow(3), Color(0.02, 0.03, 0.035, 0.7))
	cv.draw_rect(Rect2(bar.position, Vector2(bar.size.x * minf(1.0, float(state["t"]) / DAWN), bar.size.y)), Color("c3a365"))
	for i in range(1, 5):
		var x := bar.position.x + bar.size.x * i / 5.0
		cv.draw_line(Vector2(x, bar.position.y - 3), Vector2(x, bar.end.y + 3), Color(0, 0, 0, 0.7), 2)
	_t(bar.position + Vector2(0, 26), "天亮前到寺门，说明碎片来历", 13, Pal.PAPER)
	_t(bar.position + Vector2(0, 46), "阿拾不会被发现，只需顾好苏晴", 12, Pal.MUTED)
	# Drum and gate state, centre top.
	var left: int = GATE_PERIOD - int(state["t"]) % GATE_PERIOD
	var open := gate_open(state["t"])
	var dr := Rect2(600, 30, 240, 40)
	_box(dr, Color(0.02, 0.03, 0.035, 0.66), 20, Color(1, 0.8, 0.4, 0.25 + drum * 0.7))
	_tc(720, 56, "鼓 · %d 回合后侧栅%s" % [left, "关" if open else "开"], 15, Color(1, 0.84, 0.5, 0.75 + drum * 0.25))
	if hidden(state["p"]):
		_box(Rect2(530, 80, 380, 34), Color(0.1, 0.35, 0.28, 0.85), 15)
		_tc(720, 103, "已隐蔽 · 淡金标记为守卫下一步", 15, Pal.PAPER)
	if aiming:
		_tc(720, 800, "投石：点击 4 格内的地面（右键取消）", 15, Color("9fd8ff"))
	if g.blocked():
		return
	if phase == "caught":
		_box(Rect2(460, 338, 520, 190), Color(0.02, 0.035, 0.04, 0.94), 8, Pal.GOLD)
		_title_center(720, 392, "重新寻一条路", 32, Pal.PAPER)
		if not undo_stack.is_empty():
			_button("undo", Rect2(500, 446, 210, 46), "撤回一步  Z", true, 17)
		_button("retry", Rect2(730, 446, 210, 46), "回检查点  R", false, 17)
		return
	_button("guide", Rect2(1238, 260, 170, 36), "关闭攻略  G" if guiding() else "攻略模式  G", guiding(), 14)
	if guiding():
		_draw_guide()
	_button("wait", Rect2(1098, 744, 150, 42), "等待  空格", false, 14)
	if phase == "play":
		_button("undo", Rect2(938, 744, 150, 42), "撤回一步  Z", false, 14, not undo_stack.is_empty())
	_button("retry", Rect2(1258, 744, 150, 42), "回存档点  R", false, 14)
	if phase == "done":
		_button("to_map", Rect2(1196, 690, 212, 44), "前往曲江  ›", true, 15)


# ================================================================== 攻略模式
const STEP_KEYS := {Vector2i(0, -1): "W ↑", Vector2i(0, 1): "S ↓", Vector2i(-1, 0): "A ←", Vector2i(1, 0): "D →", Vector2i.ZERO: "空格 等待"}


func guiding() -> bool:
	return bool(g.flags.get("guide_ch4", false))


func toggle_guide() -> void:
	g.flags["guide_ch4"] = not guiding()
	g.sfx("dial")
	_refresh_guide()
	g.notify("攻略模式已开启：沿金色脚印走，右上角提示下一步按什么。按 G 关闭。" if guiding() else "攻略模式已关闭。", 5.0)


## Re-solves from the current state so the guide still works after the player strays.
func _refresh_guide() -> void:
	guide_route = []
	if guiding() and phase == "play":
		guide_route = solve(DAWN, state)
	_show_guide_path()


## Positions visited by the remaining route; waits stack on the same tile.
func guide_tiles() -> Array:
	var out := []
	var p: Vector2i = state["p"]
	for d in guide_route:
		p += d as Vector2i
		out.append(p)
	return out


## Next instruction as [action, repeat count].
func guide_next() -> Array:
	if guide_route.is_empty():
		return []
	var first: Vector2i = guide_route[0]
	var n := 0
	while n < guide_route.size() and guide_route[n] == first:
		n += 1
	return [first, n]


## Why the next step is what it is, in plain words.
func guide_reason() -> String:
	var nx := guide_next()
	if nx.is_empty():
		return "从这里已经赶不到寺门了。按 R 回存档点，攻略会重新算路线。" if phase == "play" else ""
	var d: Vector2i = nx[0]
	var to: Vector2i = state["p"] + d
	if d == Vector2i.ZERO:
		if state["p"].x >= 21 and not gate_open(state["t"]):
			return "等侧栅打开（听交接鼓声）。"
		for i in range(guards.size()):
			var pz := pose(i, state["gs"])
			if (pz[0] as Vector2i).distance_to(state["p"]) <= 5:
				return "前面有金吾卫，原地等他走开或转身。"
		return "原地等一等，时机还没到。"
	if hidden(to):
		return "躲进%s，金吾卫看不见你。" % {"~": "水渠", "C": "货车后面", "D": "门洞"}[tile_at(to, 0)]
	if to.x >= 21 and to.y >= 11:
		return "侧栅开着，快进去。"
	return "这一步不在任何人的视线里。"


func _show_guide_path() -> void:
	if not world:
		return
	if guide_nodes.is_empty():
		var m := _flat(Color("ffd27a"), 1.5, 0.75)
		for i in range(DAWN):
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.12
			cm.bottom_radius = 0.12
			cm.height = 0.02
			cm.radial_segments = 10
			mi.mesh = cm
			mi.material_override = m
			mi.visible = false
			world.add_child(mi)
			guide_nodes.append(mi)
		guide_arrow = MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.45, 0.45, 0.06)
		guide_arrow.mesh = pm
		guide_arrow.material_override = _flat(Color("ffd27a"), 2.5)
		world.add_child(guide_arrow)
	var tiles := guide_tiles()
	var shown := {}
	var used := 0
	for i in range(tiles.size()):
		var t: Vector2i = tiles[i]
		if shown.has(t) or used >= guide_nodes.size():
			continue
		shown[t] = true
		var mi: MeshInstance3D = guide_nodes[used]
		mi.position = _v3(t, 0.06)
		# Near steps are big and bright; far ones fade into small dots.
		var k := clampf(1.0 - used / 30.0, 0.25, 1.0)
		mi.scale = Vector3(k, 1, k) * (1.6 if used == 0 else 1.0)
		mi.visible = true
		used += 1
	for i in range(used, guide_nodes.size()):
		guide_nodes[i].visible = false
	guide_arrow.visible = guiding() and not tiles.is_empty()


func _animate_guide() -> void:
	if not guide_arrow or not guide_arrow.visible:
		return
	var nx := guide_next()
	if nx.is_empty():
		return
	var d: Vector2i = nx[0]
	var at := _v3(state["p"] + d)
	guide_arrow.position = at + Vector3(0, 1.3 + sin(age * 5.0) * 0.12, 0)
	guide_arrow.rotation = Vector3(PI, age * 1.5, 0)     # point down, spin slowly
	if d == Vector2i.ZERO:
		guide_arrow.scale = Vector3.ONE * (0.8 + 0.15 * sin(age * 8.0))
	else:
		guide_arrow.scale = Vector3.ONE


func _draw_guide() -> void:
	var box := Rect2(1098, 306, 310, 132)
	_box(box, Color(0.02, 0.035, 0.04, 0.85), 4, Color(Pal.GOLD, 0.7))
	_t(box.position + Vector2(16, 26), "攻略  ·  G 关闭", 13, Pal.GOLD)
	var nx := guide_next()
	if nx.is_empty():
		_wrap(box.position + Vector2(16, 56), guide_reason(), 280, 15, Color("ff8f7a"), 24)
		return
	var label: String = STEP_KEYS[nx[0]]
	var times: int = nx[1]
	_t(box.position + Vector2(16, 64), "下一步", 13, Pal.MUTED)
	_t(box.position + Vector2(76, 66), label + ("  × %d" % times if times > 1 else ""), 24, Color("ffe7b0"))
	_wrap(box.position + Vector2(16, 96), guide_reason(), 280, 13, Pal.SOFT, 20)
	_t(box.position + Vector2(16, 124), "剩余 %d 步到寺门" % guide_route.size(), 12, Pal.MUTED)
