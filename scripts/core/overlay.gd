extends "res://scripts/core/canvas.gd"
## Top layer drawn above every scene: global buttons, dialogue, artifact cards, journal,
## help, toast, click ripples and the scene-change fade.

const Story = preload("res://scripts/data/story.gd")
const SettingsPanel = preload("res://scripts/core/settings.gd")

var panel := ""            # "", "card", "journal", "help"
var panel_t := 1.0
var card_id := ""
var card_done := Callable()
var toast := ""
var toast_time := 0.0
var ripples: Array[Vector3] = []
var settings_ui: Control
var settings_return := ""
var manual_point := {}
var saves_return := ""


func reset() -> void:
	_remove_settings()
	panel = ""
	card_done = Callable()
	toast_time = 0.0


func modal_active() -> bool:
	return g.dlg.active or not panel.is_empty()


func open_card(id: String, done := Callable()) -> void:
	card_id = id
	card_done = done
	_open("card")
	g.sfx("pickup")


func open_journal() -> void:
	_open("journal")
	g.sfx("note")


func open_help() -> void:
	_open("help")
	g.remember_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func open_saves() -> void:
	saves_return = panel
	g.remember_current()
	manual_point = g.unpack_resume(g.read_save(g.manual_path))
	_open("saves")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func open_confirm_new() -> void:
	_open("confirm_new")


func open_settings() -> void:
	if panel == "settings":
		return
	settings_return = panel
	_open("settings")
	settings_ui = SettingsPanel.new()
	settings_ui.setup(g)
	add_child(settings_ui)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _remove_settings() -> void:
	if is_instance_valid(settings_ui):
		settings_ui.queue_free()
	settings_ui = null


func _open(name: String) -> void:
	panel = name
	panel_t = 0.0


func close_panel() -> void:
	var was := panel
	panel = ""
	if was == "saves":
		panel = saves_return
		saves_return = ""
	if was == "settings":
		_remove_settings()
		g.stop_voice()
		if not settings_return.is_empty():
			_open(settings_return)
		settings_return = ""
	if was == "card":
		var cb := card_done
		card_done = Callable()
		if cb.is_valid():
			cb.call()


func ripple(p: Vector2) -> void:
	ripples.append(Vector3(p.x, p.y, 0.0))


func tick(delta: float, _blocked: bool) -> void:
	panel_t = minf(1.0, panel_t + delta * 5.0)
	toast_time = maxf(0.0, toast_time - delta)
	for i in range(ripples.size() - 1, -1, -1):
		ripples[i].z += delta
		if ripples[i].z > 0.6:
			ripples.remove_at(i)


func key(event: InputEventKey) -> bool:
	if panel.is_empty():
		return false
	if panel == "settings":
		if event.keycode == KEY_ESCAPE:
			close_panel()
		return true
	if panel in ["saves", "confirm_new"]:
		if event.keycode == KEY_ESCAPE:
			close_panel()
		return true
	if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_J, KEY_KP_ENTER]:
		g.sfx("click")
		close_panel()
	return true


func act(id: String) -> void:
	if id == "dlg_history" or id.begins_with("history_"):
		g.dlg.history_act(id)
	elif id == "dlg_next":
		g.dlg.advance()
	elif id.begins_with("dlg_choice_"):
		g.sfx("click")
		g.dlg.choose(int(id.trim_prefix("dlg_choice_")))
	elif id == "panel_close":
		g.sfx("click")
		close_panel()
	elif id == "menu_title":
		g.sfx("click")
		g.return_from_menu("title")
	elif id == "menu_map":
		g.sfx("click")
		g.return_from_menu("map")
	elif id == "menu_restart":
		g.sfx("click")
		g.restart_current_chapter()
	elif id == "menu_settings":
		open_settings()
	elif id == "menu_saves":
		open_saves()
	elif id == "save_manual":
		if g.save_manual():
			manual_point = g.unpack_resume(g.read_save(g.manual_path))
	elif id == "load_manual":
		g.load_manual()
	elif id == "load_auto":
		var point: Dictionary = g.resume_point.duplicate(true)
		if not point.is_empty():
			g._prepare_chapter_exit()
			g.continue_saved_game(point)
	elif id == "confirm_new":
		g.reset_progress()
		g._prepare_chapter_exit()
		g.go("prologue")
	elif id == "g_sound":
		g.toggle_sound()
	elif id == "g_help":
		open_help()
	elif id == "g_journal":
		open_journal()


func _draw() -> void:
	hit_regions.clear()
	if g.scene:
		g.scene.draw_hud(self)
	if g.scene and g.scene.cinematic_active():
		if g.fade > 0:
			draw_rect(Rect2(0, 0, 1440, 900), Color(0.01, 0.02, 0.025, g.fade))
		return
	if g.scene and g.scene.chrome() and not g.dlg.active and panel.is_empty():
		_button("g_sound", Rect2(1222, 24, 86, 30), "声 · 开" if g.sound_on else "声 · 关", false, 12)
		_button("g_help", Rect2(1318, 24, 90, 30), "菜单  Esc", false, 12)
	if not toast.is_empty() and toast_time > 0 and not g.dlg.active:
		var w := minf(1100, maxf(380, _tw(toast, 16) + 48))
		var r := Rect2((1440 - w) * 0.5, 126, w, 42)
		var a := minf(1.0, toast_time * 3.0)
		_box(r, Color(0.02, 0.035, 0.04, 0.88 * a), 4, Color(0.84, 0.72, 0.48, 0.55 * a))
		cv.draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color(Pal.GOLD, a))
		_t(r.position + Vector2(24, 28), toast, 16, Color(Pal.PAPER, a))
	if not panel.is_empty() and panel != "settings":
		_draw_panel()
	if panel.is_empty():
		g.dlg.draw()
	for rp in ripples:
		var k := rp.z / 0.6
		draw_arc(Vector2(rp.x, rp.y), 6 + k * 26, 0, TAU, 32, Color(0.95, 0.85, 0.6, (1.0 - k) * 0.55), 1.5, true)
	if g.fade > 0:
		draw_rect(Rect2(0, 0, 1440, 900), Color(0.01, 0.02, 0.025, g.fade))


func _draw_panel() -> void:
	hit_regions.clear()
	var e := ease(panel_t, -2.0)
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.01, 0.015, 0.02, 0.76 * e))
	var sc := 0.94 + 0.06 * e
	var center := Vector2(720, 460)
	draw_set_transform(center * (1.0 - sc), 0.0, Vector2(sc, sc))
	var card := Rect2(325, 185, 790, 550)
	_panel(card)
	_button("panel_close", Rect2(1036, 205, 56, 33), "关闭", false, 12)
	match panel:
		"confirm_new":
			_t(Vector2(374, 244), "重新启程", 14, Pal.GOLD)
			_title(Vector2(374, 318), "从故事开头重新开始？", 32, Pal.PAPER)
			_serif_wrap(Vector2(375, 382), "本次自动进度将被覆盖，手动存档会保留。", 640, 19, Pal.SOFT, 32)
			_button("panel_close", Rect2(375, 596, 320, 48), "取消", false, 18)
			_button("confirm_new", Rect2(725, 596, 340, 48), "确认重新开始", true, 18)
		"saves":
			_draw_saves()
		"card":
			_draw_card()
		"journal":
			_draw_journal()
		"help":
			_t(Vector2(374, 244), "行旅菜单  /  操作说明", 14, Pal.GOLD)
			_title(Vector2(374, 303), "慢一点，观察每一处联系。", 32, Pal.PAPER)
			_button("menu_settings", Rect2(895, 283, 170, 34), "行旅设置", false, 15)
			_button("menu_saves", Rect2(895, 325, 170, 34), "保存 / 读取", false, 15)
			var lines: Array = g.scene.help_lines() if g.scene else []
			lines = lines + ["J 打开手札；H 获取提示（对话中查看历史）；Ctrl 快进。", "独立试玩：本次进度不写入主线存档。" if not g.preview_chapter.is_empty() else "进度自动保存在本机，可在标题页「重新开始」。"]
			for i in range(lines.size()):
				_t(Vector2(375, 387 + i * minf(28.0, 236.0 / maxf(1, lines.size()))), str(lines[i]), 15, Pal.MUTED)
			if g.can_restart_chapter():
				_button("menu_title", Rect2(375, 657, 160, 43), "返回标题", false, 15)
				_button("menu_map", Rect2(550, 657, 160, 43), "返回舆图", false, 15)
				_button("menu_restart", Rect2(725, 657, 165, 43), "重新开始本关", false, 15)
				_button("panel_close", Rect2(905, 657, 160, 43), "继续", true, 16)
			else:
				_button("menu_title", Rect2(375, 657, 210, 43), "返回标题", false, 16)
				_button("menu_map", Rect2(610, 657, 210, 43), "返回舆图", false, 16)
				_button("panel_close", Rect2(848, 657, 217, 43), "继续", true, 16)
	draw_set_transform(Vector2.ZERO)


func _draw_saves() -> void:
	_t(Vector2(374, 244), "行旅存档  /  本机保存", 14, Pal.GOLD)
	_title(Vector2(374, 303), "把旅程留在这里", 32, Pal.PAPER)
	var points := [g.resume_point, manual_point]
	for i in range(2):
		var point: Dictionary = points[i]
		var y := 336.0 + i * 137.0
		_box(Rect2(375, y, 690, 121), Color(0.05, 0.075, 0.08, 0.88), 6, Color(Pal.GOLD, 0.32))
		_t(Vector2(395, y + 28), "自动存档" if i == 0 else "手动存档", 16, Pal.GOLD)
		_serif(Vector2(395, y + 58), g.SessionState.description(point), 19, Pal.PAPER)
		if not point.is_empty():
			var local_time := int(point.get("saved_at", 0)) + int(Time.get_time_zone_from_system()["bias"]) * 60
			_t(Vector2(395, y + 89), Time.get_datetime_string_from_unix_time(local_time).replace("T", "  "), 13, Pal.MUTED)
			_button("load_auto" if i == 0 else "load_manual", Rect2(914, y + 20, 130, 38), "读取", false, 16)
		if i == 1 and g.screen in g.CHAPTERS and not g.transient_save:
			_button("save_manual", Rect2(914, y + 68, 130, 38), "保存到此", true, 15)
	_serif_wrap(Vector2(375, 639), "对话和演出从最近的操作节点接续；击鼓与战斗从准备阶段或本阶段起点继续。", 690, 15, Pal.MUTED, 23)


func _draw_card() -> void:
	var c: Dictionary = Story.CARDS.get(card_id, {})
	_t(Vector2(372, 242), c.get("tag", ""), 14, Pal.GOLD)
	_title(Vector2(372, 301), c.get("title", ""), 36, Pal.PAPER)
	var key: String = c.get("tex", "")
	var tx := 372.0
	if not key.is_empty() and g.tex.has(key):
		var mc := Vector2(520, 480)
		for r in range(6, 0, -1):
			draw_circle(mc, 100 + r * 7, Color(1, 0.85, 0.5, 0.012))
		var t: Texture2D = g.tex[key]
		var s := t.get_size() / maxf(t.get_size().x, t.get_size().y) * 250.0
		draw_texture_rect(t, Rect2(mc - s * 0.5 + Vector2(0, sin(age * 1.4) * 3), s), false)
		tx = 680.0
	var width := 380.0 if tx > 400 else 690.0
	var rows := _serif_wrap(Vector2(tx, 360), c.get("text", ""), width, 18, Pal.PAPER, 32)
	_serif_wrap(Vector2(tx, 380 + rows * 32), c.get("more", ""), width, 16, Pal.SOFT, 28)
	_button("panel_close", Rect2(848, 657, 217, 43), "收下", true, 15)


func _draw_journal() -> void:
	_t(Vector2(372, 244), "FIELD NOTES  /  行旅手札", 14, Pal.GOLD)
	_title(Vector2(372, 304), "行旅手札", 36, Pal.PAPER)
	_t(Vector2(750, 296), "碎片 %d / 4" % g.shard_count(), 17, Pal.GOLD)
	_shard_slots(Vector2(858, 270), 34)
	_serif(Vector2(374, 352), "已收录的图鉴", 17, Pal.GOLD)
	var x := 374.0
	var y := 372.0
	for id in g.collected:
		var c: Dictionary = Story.CARDS.get(id, {})
		var title: String = c.get("title", id)
		var w := _serif_width(title, 15) + 26
		if x + w > 1060:
			x = 374.0
			y += 40
		_box(Rect2(x, y, w, 30), Color(0.05, 0.08, 0.085, 0.9), 3, Color(0.84, 0.72, 0.48, 0.35))
		_serif(Vector2(x + 13, y + 21), title, 15, Pal.PAPER)
		x += w + 10
	if g.collected.is_empty():
		_t(Vector2(374, 392), "还没有收录任何图鉴。", 14, Pal.MUTED)
	var tips: Array = []
	if g.scene and g.scene.has_method("journal_lines"):
		tips = g.scene.journal_lines()
	_serif(Vector2(374, 540), "本章线索", 17, Pal.GOLD)
	for i in range(tips.size()):
		_wrap(Vector2(374, 572 + i * 28), "· " + str(tips[i]), 680, 14, Pal.MUTED, 24)
	_button("panel_close", Rect2(849, 655, 216, 43), "回去", true, 15)
