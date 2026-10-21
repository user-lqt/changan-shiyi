extends "res://scripts/core/canvas.gd"
## 尾声 · 实验室: a first-person walk through the modern lab after the return.
## Look at the scan screen, the restored bowl and the mirror (any order). The mirror plays
## the memory film (assets/videos/epilogue/memory.ogv, or a built-in placeholder), after
## which the window opens up: the moon over the Big Wild Goose Pagoda ends the story.
const LabEnvironment = preload("res://scripts/core/lab_environment.gd")
const Walker = preload("res://scripts/core/tower_walker.gd")
const FilmVoice = preload("res://scripts/core/film_voice.gd")
const Story = preload("res://scripts/data/story.gd")
const REQUIRED := ["screen", "bowl", "mirror"]
const FILMS := {
	"return": {"path": "res://assets/videos/epilogue/return.ogv", "duration": 8.064, "title": "镜光归来"},
	"memory": {"path": "res://assets/videos/epilogue/memory.ogv", "duration": 15.072, "title": "镜中长安"},
}
const FOCUS_RANGE := 2.3
const NOTES := {
	"clock": "一点零七分。秒针还在走，像什么都没有发生过。",
	"board": "白板上是今天的扫描清单。最后一行是她自己写的：「不可凭想象补全纹样。」",
	"research": "照片、纹样与断口一一对照。修复记录要保留来处，也要说明每一次修补。",
}

var vp: SubViewport
var world: Node3D
var walker: CharacterBody3D
var environment
var phase := "story"            # story | walk | vision | done
var seen := {}
var focus_id := ""
var mouse_locked := false
var auto_mode := false
var film_time := 0.0
var film_id := "memory"
var film_player: VideoStreamPlayer
var film_real := false
var film_voice := FilmVoice.new()
var fade_in := 1.0
var note := ""
var note_time := 0.0
var mirror_awake := 0.0
var done := false
var inspection := ""
var story_target := Vector3.ZERO
var route: Array[Vector3] = []
var route_index := 0
var ending_time := 0.0


func enter() -> void:
	g.music("ambient", false)
	var saved = g.flags.get("epilogue_seen", {})
	if saved is Dictionary:
		for id in REQUIRED:
			if saved.get(id, false):
				seen[id] = true
	vp = SubViewport.new()
	vp.size = Vector2i(1440, 900)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	environment = LabEnvironment.new()
	environment.build(world, g)
	walker = Walker.new()
	walker.chapter = self
	world.add_child(walker)
	walker.position = Vector3(0.6, 0.05, 1.6)
	walker.face(Vector3(0.1, 1.0, 0))
	story_target = Vector3(0.1, 1.0, 0)
	film_player = VideoStreamPlayer.new()
	film_player.bus = &"Effects"
	# Keep the complete 16:9 frame above the subtitle panel, without stretching.
	film_player.position = Vector2(48, 1)
	film_player.size = Vector2(1344, 756)
	film_player.expand = true
	film_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film_player.visible = false
	film_player.finished.connect(_finish_film)
	add_child(film_player)
	if g.restoring_run:
		phase = "walk"
	elif g.flags.get("epilogue_arrived", false) or not seen.is_empty():
		g.say("epilogue_wake", _to_walk)
	else:
		_start_film("return")


func _exit_tree() -> void:
	film_voice.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(film_player):
		film_player.stop()
	if is_instance_valid(g.music_player):
		g.music_player.stream_paused = false


func chrome() -> bool:
	return false


func bottom_hud() -> bool:
	return false


func cinematic_active() -> bool:
	return phase == "vision"


func window_open() -> bool:
	for id in REQUIRED:
		if not seen.has(id):
			return false
	return true


func _to_walk() -> void:
	if phase != "done":
		phase = "walk"


func restore_landing() -> void:
	_stop_walking()
	walker.position = Vector3(0.6, 0.05, 1.6)
	walker.velocity = Vector3.ZERO
	walker.face(Vector3(0.1, 1.0, 0))


# ------------------------------------------------------------------ loop
func tick(delta: float, blocked: bool) -> void:
	fade_in = maxf(0.0, fade_in - delta * 0.7)
	note_time = maxf(0.0, note_time - delta)
	mirror_awake = maxf(0.0, mirror_awake - delta * 0.3)
	if not film_real:
		environment.animate(age, mirror_awake)
	var focus: bool = get_window().has_focus() or g.test_mode
	var walking: bool = phase == "walk" and not blocked and focus
	walker.enabled = walking and (mouse_locked or auto_mode)
	walker.scripted = auto_mode
	var capture: bool = walking and mouse_locked and not auto_mode and not g.test_mode and g.capture_path.is_empty()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	if phase == "vision":
		film_time = film_player.stream_position if film_real else film_time + delta
		film_voice.update(film_time)
		mirror_awake = 1.0
		if not film_real and film_time >= float(FILMS[film_id]["duration"]):
			_finish_film()
		return
	if phase == "done":
		ending_time += delta
		walker.face(environment.WINDOW_VIEW, delta * 0.55)
		walker.camera.fov = move_toward(walker.camera.fov, 46.0, delta * 8.0)
		return
	if phase == "story":
		walker.face(story_target, delta * 0.65)
		var fov := 40.0 if not inspection.is_empty() else 65.0
		walker.camera.fov = move_toward(walker.camera.fov, fov, delta * 22.0)
		focus_id = ""
		return
	walker.camera.fov = move_toward(walker.camera.fov, 72.0, delta * 30.0)
	focus_id = _find_focus()
	if walking and auto_mode:
		_auto_walk(delta)


## The spot the player is looking at within reach; nearby items behind the player do not activate.
func _find_focus() -> String:
	var cam: Camera3D = walker.camera
	var forward := -cam.global_transform.basis.z
	var best := ""
	var best_score := -1.0
	for id in environment.spots:
		if id == "window" and not window_open():
			continue
		var p: Vector3 = environment.spots[id]["pos"]
		var d := p - cam.global_position
		var dist := Vector2(d.x, d.z).length()
		if dist > FOCUS_RANGE:
			continue
		var facing := forward.dot(d.normalized())
		var score := facing - dist * 0.08
		if facing > 0.82 and score > best_score:
			best_score = score
			best = id
	return best


func next_target() -> String:
	for id in REQUIRED:
		if not seen.has(id):
			return id
	return "window" if phase != "done" else ""


## Tab guide follows a collision-aware route around the bench, chair and display case.
func _auto_walk(delta: float) -> void:
	var id := next_target()
	if id.is_empty():
		walker.wish = Vector3.ZERO
		return
	var p: Vector3 = walker.position
	if route_index >= route.size():
		walker.wish = Vector3.ZERO
		walker.face(environment.spots[id]["pos"], delta * 1.5)
		if focus_id == id:
			_stop_walking()
			g.notify("已到「%s」，按 E 查看。" % environment.spots[id]["label"], 3.0)
		return
	var target: Vector3 = route[route_index]
	var flat := Vector3(target.x - p.x, 0, target.z - p.z)
	if flat.length() < 0.12:
		route_index += 1
		return
	# Slow down at cell corners so the body cannot cut through the bench.
	walker.wish = flat.normalized() * minf(0.72, flat.length() * 3.0)
	walker.face(environment.spots[id]["pos"], delta * 0.7)


func _stop_walking() -> void:
	auto_mode = false
	route.clear()
	route_index = 0
	if walker:
		walker.enabled = false
		walker.wish = Vector3.ZERO
		walker.velocity = Vector3.ZERO


# ------------------------------------------------------------------ interactions
func act(id: String) -> void:
	match id:
		"inspect":
			if not focus_id.is_empty():
				inspect(focus_id)
		"auto":
			if phase != "walk":
				return
			if auto_mode:
				_stop_walking()
			else:
				route = environment.route_to(walker.position, next_target())
				route_index = 0
				auto_mode = not route.is_empty()
				mouse_locked = false
		"menu":
			mouse_locked = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			g.overlay.open_help()
		"skip":
			_finish_film()
		"title":
			g.return_from_menu("title")
		"map":
			g.return_from_menu("map")


func inspect(id: String) -> void:
	if phase != "walk" or not environment.spots.has(id) or g.blocked():
		return
	if id == "window" and not window_open():
		g.notify("窗外好像很亮……先看看屏幕、碗和铜镜。", 3.0)
		return
	_stop_walking()
	mouse_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	story_target = environment.spots[id]["pos"]
	inspection = id
	g.sfx("note", -14.0)
	match id:
		"screen", "bowl":
			phase = "story"
			g.say("epilogue_" + id, _after_inspect)
		"mirror":
			phase = "story"
			if seen.has("mirror"):
				g.say("epilogue_mirror_again", _after_inspect)
			else:
				g.say("epilogue_mirror", _start_film)
		"window":
			phase = "story"
			story_target = environment.WINDOW_VIEW
			g.say("epilogue_window", _finish)
		_:
			note = NOTES.get(id, "")
			note_time = 5.0


func _after_inspect() -> void:
	if REQUIRED.has(inspection):
		seen[inspection] = true
		g.flags["epilogue_seen"] = seen.duplicate()
		g._save_progress()
	inspection = ""
	phase = "walk"
	if window_open():
		g.notify("三处线索已核对。去窗边，看看千年以后的月亮。", 5.0)


func _start_film(id := "memory") -> void:
	film_voice.start(g, id)
	phase = "vision"
	film_id = id
	film_time = 0.0
	walker.enabled = false
	walker.velocity = Vector3.ZERO
	mouse_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	film_real = false
	if ResourceLoader.exists(FILMS[film_id]["path"]):
		var stream = load(FILMS[film_id]["path"]) as VideoStream
		if stream:
			film_real = true
			film_player.stream = stream
			film_player.visible = true
			film_player.volume_db = 0.0 if g.sound_on else -80.0
			g.stop_voice()
			g.music_player.stream_paused = true
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			film_player.play()


func _finish_film() -> void:
	if phase != "vision":
		return
	film_voice.stop()
	film_player.stop()
	film_player.visible = false
	g.music_player.stream_paused = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	film_real = false
	phase = "story"
	if film_id == "return":
		g.flags["epilogue_arrived"] = true
		g._save_progress()
		fade_in = 0.65
		g.say("epilogue_wake", _to_walk)
		return
	var lines: Array = []
	if g.collected.has("coin"):
		lines.append_array(Story.DIALOGUE["epilogue_coin"])
	lines.append_array(Story.DIALOGUE["epilogue_memory"])
	if seen.has("screen") and seen.has("bowl"):
		lines.append_array(Story.DIALOGUE["epilogue_memory_ready"])
	else:
		lines.append_array(Story.DIALOGUE["epilogue_memory_remaining"])
	g.dlg.start_lines(lines, _after_inspect)


func _finish() -> void:
	phase = "done"
	done = true
	ending_time = 0.0
	inspection = ""
	_stop_walking()
	mouse_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	g.clear("epilogue")


# ------------------------------------------------------------------ input
func key(event: InputEventKey) -> bool:
	if phase == "vision":
		if event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			_finish_film()
		return true
	match event.keycode:
		KEY_E:
			act("inspect")
			return true
		KEY_TAB:
			act("auto")
			return true
		KEY_R:
			if phase == "walk":
				restore_landing()
			return true
		KEY_ESCAPE:
			if mouse_locked:
				mouse_locked = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				g.overlay.open_help()
				return true
	return false


func mouse(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and mouse_locked and phase == "walk" and not auto_mode:
		walker.look(event.relative)
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if phase == "vision":
			_finish_film()
			return true
		if phase == "walk" and hit_screen(event.position).is_empty():
			if mouse_locked and not focus_id.is_empty():
				inspect(focus_id)
			else:
				mouse_locked = true
			return true
	return false


func hint() -> String:
	var id := next_target()
	if id.is_empty():
		return "故事结束了。"
	return "去看看「%s」。走近并对准它按 E；Tab 会自动带你过去。" % environment.spots[id]["label"]


func help_lines() -> Array:
	return ["点击画面进入第一人称；WASD 行走，Shift 快跑，鼠标环顾，Esc 打开菜单。",
		"靠近物品、让准星对准它，按 E 或左键查看。Tab 自动走向下一处。",
		"屏幕、莲纹碗、铜镜三处看完后，再去窗边。中间的回忆片段可按空格跳过。"]


func journal_lines() -> Array:
	var out := ["回到实验室：一点零七分。长安三日，此地七分钟。"]
	for id in REQUIRED:
		out.append(("✓ " if seen.has(id) else "· ") + str(environment.spots[id]["label"]))
	if window_open():
		out.append("去窗边看看，镜魅托你看的那轮月亮。")
	return out


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	hit_regions.clear()
	if vp:
		draw_texture_rect(vp.get_texture(), Rect2(0, 0, 1440, 900), false)
	for i in range(18):
		var alpha := (1.0 - i / 18.0) * 0.06
		draw_rect(Rect2(i * 10, 0, 10, 900), Color(0.02, 0.025, 0.03, alpha))
		draw_rect(Rect2(1430 - i * 10, 0, 10, 900), Color(0.02, 0.025, 0.03, alpha))
	if phase == "vision" and not film_real:
		_draw_film_placeholder()
	if phase == "walk" and mouse_locked and not auto_mode:
		draw_circle(Vector2(720, 450), 2.5 if focus_id.is_empty() else 4.0, Color(0.9, 0.85, 0.71, 0.75))
	if fade_in > 0.0:
		draw_rect(Rect2(0, 0, 1440, 900), Color(0.95, 0.97, 1.0, fade_in))
	if film_real:
		draw_rect(Rect2(0, 0, 1440, 900), Color.BLACK)
	_hud(_draw_lab_hud)


## Placeholder for the memory film: the people of Chang'an drift past in the mirror's light.
func _draw_film_placeholder() -> void:
	var k := clampf(film_time / float(FILMS[film_id]["duration"]), 0.0, 1.0)
	if film_id == "return":
		# A replaceable return shot: mirror-light ebbs away to reveal the actual lab.
		var veil := pow(1.0 - k, 1.6)
		draw_rect(Rect2(0, 0, 1440, 900), Color(0.91, 0.96, 1.0, veil))
		for i in range(22):
			var p := Vector2(720 + sin(float(i) * 7.3) * (100 + k * 620), 420 + cos(float(i) * 4.7) * (50 + k * 350))
			draw_circle(p, 1.5 + i % 3, Color(1.0, 0.89, 0.64, (1.0 - k) * 0.55))
		return
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.02, 0.04, 0.06, 0.92))
	var faces := ["npc_wen", "npc_kang", "npc_mi", "npc_ashi", "npc_bai", "boss_1"]
	var slot := float(FILMS[film_id]["duration"]) / faces.size()
	for i in range(faces.size()):
		var local := (film_time - i * slot) / slot
		if local < -0.2 or local > 1.3 or not g.tex.has(faces[i]):
			continue
		var t: Texture2D = g.tex[faces[i]]
		var a := clampf(minf(local + 0.2, 1.3 - local) * 2.5, 0.0, 1.0)
		var h := 640.0
		var w := t.get_size().x / t.get_size().y * h
		var x := 720.0 - w * 0.5 + (local - 0.5) * 120.0 * (1 if i % 2 == 0 else -1)
		draw_texture_rect(t, Rect2(x, 120, w, h), false, Color(0.85, 0.95, 1.0, a * 0.85))
	for i in range(14):
		var y := fmod(film_time * 70 + i * 66, 900.0)
		draw_line(Vector2(0, y), Vector2(1440, y), Color(0.6, 0.9, 1.0, 0.06), 2)
	for r in range(8, 0, -1):
		draw_arc(Vector2(720, 450), 380 + r * 12, 0, TAU, 96, Color(0.75, 0.9, 1.0, 0.025 * sin(k * PI)), 10, true)
	var flash := maxf(0.0, 1.0 - absf(k - 0.95) * 14.0) * 0.8
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.9, 0.97, 1.0, flash))
	_tc(720, 70, "一城灯火，仍在镜中。", 18, Color(0.7, 0.8, 0.85, 0.8))


func _draw_lab_hud() -> void:
	if phase == "vision":
		cv.draw_rect(Rect2(0, 758, 1440, 142), Color(0.01, 0.015, 0.025, 0.96))
		_title_center(720, 808, FILMS[film_id]["title"], 28, Pal.GOLD)
		var lines := ["白光散去，铜镜沉寂。", "熟悉的嗡鸣声里，操作台渐渐清晰。", "手掌还记着瓷片的温度。"] if film_id == "return" else ["铜镜深处，灯火一盏盏亮起。", "镜坊、西市、酒肆、曲江……那些人都还在。", "月光落在塔顶，又落回掌心。"]
		var n := mini(2, int(film_time / (float(FILMS[film_id]["duration"]) / 3.0)))
		var spoken := film_voice.caption()
		_tc(720, 847, spoken if not spoken.is_empty() else lines[n], 20, Pal.PAPER)
		_button("skip", Rect2(1246, 22, 154, 30), "跳过 · 空格", false, 13)
		return
	if done:
		var a := clampf((ending_time - 1.8) / 1.3, 0.0, 1.0)
		_title_center(720, 100, "月亮还在，长安也还在。", 35, Color(Pal.PAPER, minf(1.0, ending_time * 0.8)))
		if a <= 0.0:
			return
		var box := Rect2(420, 600, 600, 230)
		_box(box, Color(0.04, 0.07, 0.09, 0.9 * a), 14, Color("7f7859"))
		_corner_ornaments(box)
		_title_center(720, 648, "《长安拾遗》 · 通关", 34, Pal.PAPER)
		_tc(720, 688, "用时 %d 分 %02d 秒  ·  提示 %d 次  ·  图鉴 %d 张" % [int(g.play_time) / 60, int(g.play_time) % 60, g.hints_used, g.collected.size()], 15, Pal.GOLD)
		_tc(720, 720, "战斗重试 %d 次  ·  对质失信 %d 次" % [int(g.stats["retries"]), int(g.stats["credit_lost"])], 14, Pal.MUTED)
		_button("map", Rect2(470, 756, 240, 48), "回到长安舆图", false, 16)
		_button("title", Rect2(730, 756, 240, 48), "返回标题", true, 16)
		return
	_box(Rect2(32, 26, 300, 91), Color(0.025, 0.035, 0.045, 0.73), 3, Color(0.7, 0.6, 0.4, 0.3))
	_t(Vector2(50, 50), "文物数字修复实验室  /  尾声", 13, Pal.GOLD)
	_title(Vector2(49, 88), "一点零七分", 26, Pal.PAPER)
	for i in range(REQUIRED.size()):
		cv.draw_circle(Vector2(53 + i * 22, 104), 3.0, Pal.GOLD if seen.has(REQUIRED[i]) else Color("566068"))
	if g.dlg.active:
		return
	_button("auto", Rect2(1100, 28, 200, 34), "停止引导 · Tab" if auto_mode else "引导前往 · Tab", auto_mode, 13)
	_button("menu", Rect2(1312, 28, 96, 34), "菜单 Esc", false, 12)
	var current := next_target()
	if not current.is_empty():
		_box(Rect2(38, 137, 270, 40), Color(0.025, 0.035, 0.045, 0.75), 3)
		_t(Vector2(53, 163), "下一处 · " + str(environment.spots[current]["label"]), 14, Pal.PAPER)
	if not focus_id.is_empty():
		_box(Rect2(560, 520, 320, 46), Color(0.025, 0.035, 0.045, 0.8), 3, Color(0.7, 0.6, 0.4, 0.5))
		_tc(720, 550, "E  查看 · %s" % environment.spots[focus_id]["label"], 17, Pal.PAPER)
	var text := "自动前往下一处  ·  Tab 恢复自由行走" if auto_mode else ("WASD 行走   鼠标环顾   E 查看   Tab 自动前往   Esc 菜单" if mouse_locked else "点击画面进入漫游   ·   Tab 自动前往")
	_box(Rect2(365, 835, 710, 36), Color(0.025, 0.035, 0.045, 0.68), 3)
	_tc(720, 859, text, 13, Pal.SOFT)
	if note_time > 0.0:
		_box(Rect2(360, 672, 720, 106), Color(0.025, 0.035, 0.045, 0.89), 3, Color(0.7, 0.6, 0.4, 0.35))
		_wrap(Vector2(385, 711), note, 670, 19, Pal.PAPER, 30)
