extends "res://scripts/core/canvas.gd"
## First-person tower walk, seven narrative landings and two replaceable film slots.
const TowerEnvironment = preload("res://scripts/core/tower_environment.gd")
const Walker = preload("res://scripts/core/tower_walker.gd")
const FilmVoice = preload("res://scripts/core/film_voice.gd")
const FLOOR_HEIGHT := 3.8
const FLOOR_NAMES := ["入塔", "长安灯火", "镜光留痕", "事故回声", "镜中低语", "月相三铃", "最后一片"]
const STORY_IDS := ["ch6_enter", "ch6_lights", "ch6_trace", "ch6_echo", "ch6_phantom", "ch6_bells", "ch6_summit"]
const FILMS := {
	"echo": {"path": "res://assets/videos/ch6/echo.ogv", "duration": 10.08, "title": "镜中回声"},
	"reveal": {"path": "res://assets/videos/ch6/reveal.ogv", "duration": 12.064, "title": "镜光凝形"},
}
var vp: SubViewport
var world: Node3D
var walker: CharacterBody3D
var environment
var phase := "story"
var floor_index := 0
var visited := {}
var auto_mode := false
var mouse_locked := false
var route: Array[Vector3] = []
var route_index := 0
var film_id := ""
var film_time := 0.0
var film_player: VideoStreamPlayer
var film_real := false
var film_voice := FilmVoice.new()
var fade_in := 1.0
var landmark_note := ""
var note_time := 0.0
var bell_step := -1


func enter() -> void:
	g.music("ambient", false)
	vp = SubViewport.new()
	vp.size = Vector2i(1440, 900)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	environment = TowerEnvironment.new()
	environment.build(world, g)
	walker = Walker.new()
	walker.chapter = self
	world.add_child(walker)
	walker.position = Vector3(-0.7, 0.06, 2.3)
	walker.face(Vector3(0.3, 2.1, 4.9))
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
	_land(0)


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


func tick(delta: float, blocked: bool) -> void:
	fade_in = maxf(0.0, fade_in - delta * 0.8)
	note_time = maxf(0.0, note_time - delta)
	if not film_real:
		var guide_delta := 0.0 if g.dlg.history_open or not g.overlay.panel.is_empty() else delta
		environment.animate(age, floor_index, film_time / float(FILMS[film_id]["duration"]) if phase == "vision" else 0.0, guide_delta)
	var focus: bool = get_window().has_focus() or g.test_mode
	var walking: bool = phase == "walk" and not blocked and focus
	walker.enabled = walking and (mouse_locked or auto_mode)
	walker.scripted = auto_mode
	var capture: bool = walking and mouse_locked and not auto_mode and not g.test_mode and g.capture_path.is_empty()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	if phase == "vision":
		film_time = film_player.stream_position if film_real else film_time + delta
		film_voice.update(film_time)
		walker.face(environment.landmarks[floor_index], delta)
		if not film_real and film_time >= float(FILMS[film_id]["duration"]):
			_finish_film()
		return
	if phase == "story":
		var story_focus: Vector3 = environment.landmarks[floor_index] if floor_index > 0 else Vector3(0.3, 2.1, 4.9)
		walker.face(story_focus, delta * 0.6)
		return
	if not walking:
		return
	if auto_mode:
		_follow_route(delta)
	if floor_index < 6:
		var next_landing := Vector3(0, (floor_index + 1) * FLOOR_HEIGHT, 3.15)
		if absf(walker.position.y - next_landing.y) < 0.4 and Vector2(walker.position.x, walker.position.z).distance_to(Vector2(0, 3.15)) < 1.0:
			_land(floor_index + 1)
	if floor_index == 5:
		var step := int(age / 1.3) % 3
		if step != bell_step:
			bell_step = step
			g.sfx("bell", -19.0 + step * 2)


func _land(index: int) -> void:
	floor_index = index
	visited[index] = true
	phase = "story"
	walker.enabled = false
	walker.wish = Vector3.ZERO
	route_index = 0
	route = _route_for(index)
	environment.guide_arrive(index)
	g.say(STORY_IDS[index], _after_story)


func _after_story() -> void:
	if floor_index == 3:
		_start_film("echo")
	elif floor_index == 6:
		_start_film("reveal")
	else:
		phase = "walk"
		if floor_index == 5:
			g.flags["bell_order_known"] = true
			if not g.collected.has("stele"):
				g.collected.append("stele")
			g._save_progress()
		environment.guide_fly_up()


func _route_for(index: int) -> Array[Vector3]:
	if index >= 6:
		return []
	var y := index * FLOOR_HEIGHT
	return [Vector3(3.5, y, 2.85), Vector3(3.5, y, 2.0),
		Vector3(3.5, y + 1.9, -4.25), Vector3(-3.5, y + 1.9, -4.25),
		Vector3(-3.5, y + 3.8, 2.05), Vector3(-3.5, y + 3.8, 3.15),
		Vector3(0, y + 3.8, 3.15)]


func _follow_route(delta: float) -> void:
	if route_index >= route.size():
		walker.wish = Vector3.ZERO
		return
	var target: Vector3 = route[route_index]
	var flat := Vector3(target.x - walker.position.x, 0, target.z - walker.position.z)
	if flat.length() < 0.22 and absf(target.y - walker.position.y) < 0.45:
		route_index += 1
		return
	walker.wish = flat.normalized()
	walker.face(target + Vector3.UP * 1.5, delta)


func toggle_auto() -> void:
	auto_mode = not auto_mode
	if auto_mode and phase == "walk" and not route.is_empty():
		var points: Array[Vector3] = [Vector3(0, floor_index * FLOOR_HEIGHT, 3.15)]
		points.append_array(route)
		var closest := INF
		for i in range(points.size() - 1):
			var point := Geometry3D.get_closest_point_to_segment(walker.position, points[i], points[i + 1])
			var dist := walker.position.distance_to(point)
			if dist < closest:
				closest = dist
				route_index = i
	if not auto_mode:
		walker.wish = Vector3.ZERO


func restore_landing() -> void:
	walker.position = Vector3(0, floor_index * FLOOR_HEIGHT + 0.08, 3.15)
	walker.velocity = Vector3.ZERO
	route_index = 0
	walker.rotation.y = PI
	walker.pitch = 0.0
	g.notify("回到本层平台。", 2.0)


func _start_film(id: String) -> void:
	film_id = id
	film_time = 0.0
	phase = "vision"
	walker.enabled = false
	walker.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	film_real = false
	film_voice.start(g, id)
	var file: String = FILMS[id]["path"]
	if ResourceLoader.exists(file):
		var stream = load(file) as VideoStream
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
	if film_id == "reveal":
		g.flags["tower_ascent_done"] = true
		g.flags["bell_order_known"] = true
		g.clear("ch6")
		phase = "summit"
	else:
		phase = "walk"
		g.flags["tower_echo_seen"] = true
		g._save_progress()
		environment.guide_fly_up()


func observe() -> void:
	landmark_note = [
		"寺僧已核实失物来历，准许两人登塔。昨夜的奔波终于有了着落。",
		"窗外灯火仍亮着。镜坊、西市、酒肆……那些帮助过你的人，都在这座城里。",
		"光纹有规律地扫过镜面，与实验室扫描时的光带相似。",
		"这不是召唤你的安排，而是那场意外留下的回声。",
		"残破铜镜悬在半空，碎片护着中心的光，仿佛不愿让任何人触碰。",
		"月相三铃：无月的朔 → 半月的弦 → 满月的望。顺序已记入手札。",
		"最后一片留着镜光。取回之前，先听清镜中传出的声音。",
	][floor_index]
	note_time = 6.0
	g.sfx("note", -15.0)


func key(event: InputEventKey) -> bool:
	if phase == "vision":
		if event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			_finish_film()
		return true
	match event.keycode:
		KEY_TAB:
			toggle_auto()
			return true
		KEY_E:
			if phase == "summit":
				act("to_boss")
			else:
				observe()
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
		elif phase == "walk" and hit_screen(event.position).is_empty():
			mouse_locked = true
			return true
	return false


func act(id: String) -> void:
	match id:
		"auto":
			toggle_auto()
		"observe":
			observe()
		"skip":
			_finish_film()
		"to_boss":
			if phase == "summit":
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				g.go("ch7")


func hint() -> String:
	return "沿平台右侧的木阶上行，在对面转回下一层。Tab 可自动登塔，E 查看本层见闻，R 回到平台。"


func help_lines() -> Array:
	return ["点击进入第一人称；WASD 行走，Shift 快跑，鼠标转头，Esc 打开菜单。",
		"每层平台停留片刻，听完对话后继续上楼。无需跳跃，也没有失败惩罚。",
		"Tab 开关自动登塔；E 查看本层见闻；R 回到当前层平台。",
		"第四层与第七层有短暂演出，空格 / Enter / Esc 可以跳过。到顶后按 E 进入下一章。"]


func journal_lines() -> Array:
	return ["登塔：第 %d / 7 层 · %s。" % [floor_index + 1, FLOOR_NAMES[floor_index]],
		"镜光将扫描事故与塔顶连接起来；悬空的残镜似乎害怕失去碎片里的光。",
		"三铃之序：朔 → 弦 → 望。" if g.flags.get("bell_order_known", false) else "沿塔阶上行，寻找最后一片的去向。"]


func _draw() -> void:
	hit_regions.clear()
	if vp:
		draw_texture_rect(vp.get_texture(), Rect2(0, 0, 1440, 900), false)
	for i in range(18):
		var alpha := (1.0 - i / 18.0) * 0.055
		draw_rect(Rect2(i * 10, 0, 10, 900), Color(0.02, 0.025, 0.03, alpha))
		draw_rect(Rect2(1430 - i * 10, 0, 10, 900), Color(0.02, 0.025, 0.03, alpha))
	if phase == "vision" and not film_real:
		_draw_film_placeholder()
	if phase == "walk" and mouse_locked and not auto_mode:
		draw_circle(Vector2(720, 450), 2.0, Color(0.9, 0.85, 0.71, 0.65))
	if fade_in > 0.0:
		draw_rect(Rect2(0, 0, 1440, 900), Color(0.01, 0.02, 0.03, fade_in))
	if film_real:
		draw_rect(Rect2(0, 0, 1440, 900), Color.BLACK)
	_hud(_draw_tower_hud)


func _draw_film_placeholder() -> void:
	var duration: float = FILMS[film_id]["duration"]
	var k := clampf(film_time / duration, 0.0, 1.0)
	if film_id == "echo":
		var opacity := sin(k * PI) * 0.82
		if g.tex.has("lab"):
			draw_texture_rect(g.tex["lab"], Rect2(-25 * k, -15 * k, 1440 + 50 * k, 900 + 30 * k), false, Color(0.75, 0.89, 1.0, opacity))
		for i in range(12):
			var y := fmod(film_time * 90 + i * 78, 900.0)
			draw_line(Vector2(0, y), Vector2(1440, y), Color(0.6, 0.9, 1.0, 0.12 * sin(k * PI)), 2)
		var flash := maxf(0.0, 1.0 - absf(k - 0.54) * 18.0) * 0.7
		draw_rect(Rect2(0, 0, 1440, 900), Color(0.84, 0.96, 1.0, flash))
	else:
		for i in range(25):
			var a := i * 2.4 + film_time * 0.35
			var r := (1.0 - k) * 520 + 70
			var p := Vector2(720, 425) + Vector2(cos(a), sin(a)) * r
			var pts := PackedVector2Array([p + Vector2(-8, 20), p + Vector2(5, -26), p + Vector2(12, 15)])
			draw_colored_polygon(pts, Color(0.58, 0.83, 0.91, 0.18 + k * 0.25))
		var flash := maxf(0.0, 1.0 - absf(k - 0.87) * 16.0) * 0.5
		draw_rect(Rect2(0, 0, 1440, 900), Color(0.72, 0.88, 1.0, flash))


func _draw_tower_hud() -> void:
	if phase == "vision":
		if not film_real:
			cv.draw_rect(Rect2(0, 0, 1440, 72), Color(0.01, 0.015, 0.025, 0.96))
		cv.draw_rect(Rect2(0, 758, 1440, 142), Color(0.01, 0.015, 0.025, 0.96))
		_title_center(720, 808, FILMS[film_id]["title"], 28, Pal.GOLD)
		var lines := ["镜面映出不属于此刻的光。", "扫描、白光、碎瓷……那场意外仍在这里回响。", "有个声音在光中醒来，守住了最后一片。"] if film_id == "echo" else ["碎镜缓缓转动，光纹从塔壁剥离。", "残破铜镜悬在月光里，碎片围住盘中的青瓷。", "「……别把那束光带走。」"]
		var n := mini(2, int(film_time / (float(FILMS[film_id]["duration"]) / 3.0)))
		var spoken := film_voice.caption()
		_tc(720, 847, spoken if not spoken.is_empty() else lines[n], 20, Pal.PAPER)
		_button("skip", Rect2(1246, 22, 154, 30), "跳过 · 空格", false, 13)
		return
	_box(Rect2(32, 26, 300, 91), Color(0.025, 0.035, 0.045, 0.73), 3, Color(0.7, 0.6, 0.4, 0.3))
	_t(Vector2(50, 50), "大慈恩寺  /  第六章 · 登塔", 13, Pal.GOLD)
	_title(Vector2(49, 88), "%s  ·  %s" % [["一", "二", "三", "四", "五", "六", "七"][floor_index], FLOOR_NAMES[floor_index]], 26, Pal.PAPER)
	for i in range(7):
		cv.draw_circle(Vector2(53 + i * 22, 104), 2.5, Pal.GOLD if i <= floor_index else Color("566068"))
	if g.dlg.active:
		return
	_button("auto", Rect2(1186, 28, 218, 34), "自动登塔 · 开  Tab" if auto_mode else "自动登塔 · 关  Tab", auto_mode, 13)
	if phase == "summit":
		_box(Rect2(420, 760, 600, 98), Color(0.025, 0.035, 0.045, 0.85), 3, Color(0.7, 0.6, 0.4, 0.5))
		_tc(720, 791, "最后一片就在眼前。先听清镜中的声音。", 17, Pal.PAPER)
		_button("to_boss", Rect2(584, 808, 272, 37), "走向铜盘 · E", true, 16)
	else:
		var text := "自动循阶上行  ·  Tab 恢复自由行走" if auto_mode else ("WASD 行走   Shift 快跑   鼠标观察   E 查看   Tab 自动登塔   Esc 菜单" if mouse_locked else "点击画面进入漫游   ·   按住 Shift 快跑   ·   Tab 自动登塔")
		_box(Rect2(365, 835, 710, 36), Color(0.025, 0.035, 0.045, 0.68), 3)
		_tc(720, 859, text, 13, Pal.SOFT)
		_button("observe", Rect2(1190, 834, 214, 36), "查看本层见闻 · E", false, 13)
	if note_time > 0.0:
		_box(Rect2(360, 672, 720, 106), Color(0.025, 0.035, 0.045, 0.89), 3, Color(0.7, 0.6, 0.4, 0.35))
		_wrap(Vector2(385, 711), landmark_note, 670, 19, Pal.PAPER, 30)
