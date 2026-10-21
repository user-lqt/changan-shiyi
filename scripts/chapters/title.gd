extends "res://scripts/core/canvas.gd"
## Title screen with the AI-painted Chang'an night view.

var rain: Array[Vector3] = []


func enter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(140):
		rain.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4)))
	g.music("ambient")


func chrome() -> bool:
	return true


func help_lines() -> Array:
	return ["点击「开始」进入故事；「继续旅程」接续最近自动存档。", "行旅存档可读取手动进度；舆图中的已完成章节可以重玩。", "借光解谜 → 西市对质 → 胡旋击鼓 → 3D 夜行 → 曲江诗牌 → 塔顶弹幕 → 拼合修复。"]


func key(event: InputEventKey) -> bool:
	if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
		act("start")
		return true
	return false


func act(id: String) -> void:
	match id:
		"start":
			if g.continue_saved_game():
				return
			if g.cleared.has("finale") and not g.cleared.has("epilogue"):
				g.go("epilogue")
			else:
				g.go("map" if g.has_progress() else "prologue")
		"new":
			g.overlay.open_confirm_new()
		"codex":
			if g.codex_unlocked():
				g.go("codex")
		"settings":
			g.overlay.open_settings()
		"saves":
			g.overlay.open_saves()
		"quit":
			g.quit_game()


func _draw() -> void:
	hit_regions.clear()
	var full := Rect2(0, 0, 1440, 900)
	if g.tex.has("title"):
		var t: Texture2D = g.tex["title"]
		var crop := _cover_crop(t.get_size(), full.size)
		var zoom := 1.0 - 0.05 * (0.5 + 0.5 * sin(age * 0.05))
		var c := Rect2(crop.position + crop.size * (1.0 - zoom) * Vector2(0.3, 0.5), crop.size * zoom)
		draw_texture_rect_region(t, full, c)
		for i in range(30):
			draw_rect(Rect2(0, 0, 1440 - i * 30, 900), Color(0.01, 0.025, 0.03, 0.022))
	else:
		draw_rect(full, Pal.BG)
	for d in rain:
		var y := fmod(d.y + age * 1.1 * d.z, 1.0) * 900.0
		var x := fmod(d.x * 1440.0 + d.z * 300.0, 1440.0)
		draw_line(Vector2(x, y), Vector2(x - 4, y + 18 * d.z), Color(0.75, 0.85, 0.9, 0.09 * d.z), 1.0, true)
	cv.draw_rect(Rect2(110, 214, 3, 196), Pal.GOLD)
	_t(Vector2(132, 236), "CHANG’AN SHIYI  /  THE LOST ARCHIVE", 13, Pal.GOLD)
	_title(Vector2(124, 330), "长安拾遗", 96, Pal.PAPER)
	_serif(Vector2(132, 390), "借一束光，找回长安。", 28, Color(Pal.PAPER, 0.95))
	_serif_wrap(Vector2(132, 438), "数字修复师苏晴在扫描一面唐代铜镜时，被镜光带回了千年前的长安。一只碎成四片的越窑莲纹碗，是她回家的唯一线索。", 600, 18, Pal.SOFT, 32)
	var cont: bool = g.has_progress() or not g.resume_point.is_empty()
	_button("start", Rect2(132, 566, 240, 51), "继续旅程" if cont else "开始", true, 19)
	if cont:
		_button("new", Rect2(392, 566, 160, 51), "重新开始", false, 16)
	_button("settings", Rect2(132, 784, 200, 46), "行旅设置", false, 18)
	_button("saves", Rect2(348, 784, 180, 46), "行旅存档", false, 18)
	_button("quit", Rect2(544, 784, 180, 46), "退出游戏", false, 18)
	if g.codex_unlocked():
		_button("codex", Rect2(132, 642, 420, 64), "长安拾遗录  ·  人物与文化图鉴", false, 19)
		_serif(Vector2(147, 733), "人间风物，留在这一卷长安。", 17, Pal.GOLD)
