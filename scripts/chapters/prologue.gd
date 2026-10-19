extends "res://scripts/core/canvas.gd"
## Inspect the missing pieces, align the scanner, then witness the time slip.

enum Phase { INTRO, INSPECT, CALIBRATE, SCANNING, ANOMALY, TRANSITION }
const MIRROR_CENTER := Vector2(490, 536)
const CONSOLE := Rect2(916, 185, 476, 328)
const SLIDER := Rect2(970, 351, 368, 32)
const SCAN_SECONDS := 2.6
const TRANSITION_VIDEO := "res://assets/videos/prologue/arrival.ogv"

var phase := Phase.INTRO
var inspected := false
var dossier_open := false
var alignment := -32.0
var alignment_vis := -32.0
var stable_time := 0.0
var calibrated := false
var dragging := false
var scan_time := 0.0
var flash := 0.0
var film_player: VideoStreamPlayer
var film_real := false
var transition_done := false


func enter() -> void:
	g.music("ambient", false)
	g.say("prologue_a", func() -> void: phase = Phase.INSPECT)


func _exit_tree() -> void:
	if is_instance_valid(film_player):
		film_player.stop()
	if is_instance_valid(g.music_player):
		g.music_player.stream_paused = false


func _start_transition(video_path := TRANSITION_VIDEO) -> void:
	phase = Phase.TRANSITION
	flash = 0.0
	transition_done = false
	film_real = false
	g.overlay.toast_time = 0.0
	if ResourceLoader.exists(video_path):
		var stream = load(video_path) as VideoStream
		if stream:
			film_player = VideoStreamPlayer.new()
			film_player.bus = &"Effects"
			film_player.position = Vector2(0, 45)
			film_player.size = Vector2(1440, 810)
			film_player.expand = true
			film_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
			film_player.stream = stream
			film_player.volume_db = 0.0 if g.sound_on else -80.0
			film_player.finished.connect(_finish_transition)
			add_child(film_player)
			film_real = true
			g.stop_voice()
			g.music_player.stream_paused = true
			film_player.play()
	if not film_real:
		g.sfx("wind", -17.0)


func _finish_transition() -> void:
	if phase != Phase.TRANSITION or transition_done:
		return
	transition_done = true
	if is_instance_valid(film_player):
		film_player.stop()
		film_player.visible = false
	film_real = false
	g.music_player.stream_paused = false
	g.go("ch1")


func chrome() -> bool:
	return phase in [Phase.INSPECT, Phase.CALIBRATE] and not dossier_open


func bottom_hud() -> bool:
	return false


func cinematic_active() -> bool:
	return dossier_open or phase == Phase.TRANSITION


func hint() -> String:
	if dossier_open or not inspected:
		return "点击右侧莲纹碗或电脑，查看四处缺损，再确认档案。"
	if not calibrated:
		return "拖动右侧刻度滑块，或用 A / D、左右键、滚轮，将扫描偏角调到 0°；停稳片刻即可。"
	return "校准已完成。点击「启动扫描」，或按回车。"


func help_lines() -> Array:
	return ["先点击莲纹碗或电脑，确认四处缺损的档案。", "拖动刻度滑块，或用 A / D、左右键、滚轮校准铜镜。", "偏角接近 0° 并停稳后，点击「启动扫描」或按回车。"]


func journal_lines() -> Array:
	return ["现代实验室里的越窑莲纹碗缺失四片，原始残片下落不明。", "本次待扫描的器物是唐代海兽葡萄纹铜镜。"]


func tick(delta: float, blocked: bool) -> void:
	alignment_vis = lerpf(alignment_vis, alignment, minf(1.0, delta * 12.0))
	if blocked:
		dragging = false
		return
	if phase == Phase.CALIBRATE and not dossier_open:
		if absf(alignment) <= 3.0 and not dragging:
			stable_time += delta
			if stable_time >= 0.55 and not calibrated:
				calibrated = true
				alignment = 0.0
				g.sfx("unlock", -13.0)
				g.notify("扫描光已对齐铜镜。可以启动扫描。", 3.0)
		else:
			stable_time = 0.0
	elif phase == Phase.SCANNING:
		scan_time = minf(SCAN_SECONDS, scan_time + delta)
		if scan_time >= SCAN_SECONDS:
			phase = Phase.ANOMALY
			g.sfx("reveal", -13.0)
			g.say("prologue_b", _start_transition)
	elif phase == Phase.TRANSITION:
		flash += delta
		if not film_real and flash >= 1.35:
			_finish_transition()


func _adjust(value: float) -> void:
	if phase != Phase.CALIBRATE or dossier_open:
		return
	alignment = clampf(value, -64.0, 64.0)
	stable_time = 0.0
	calibrated = false


func _slider_at(pos: Vector2) -> void:
	_adjust((clampf((pos.x - SLIDER.position.x) / SLIDER.size.x, 0.0, 1.0) - 0.5) * 128.0)


func mouse(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if dragging:
			# Releasing outside the window must not leave the dial stuck to the cursor.
			if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				dragging = false
			else:
				_slider_at(event.position)
		return dragging
	if not event is InputEventMouseButton:
		return false
	if phase == Phase.TRANSITION:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_finish_transition()
		return true
	if dossier_open:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			act(hit(event.position))
		return true
	if phase != Phase.CALIBRATE:
		return false
	if event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and dragging:
			_slider_at(event.position)
			dragging = false
			return true
		if event.pressed and SLIDER.grow(12).has_point(event.position):
			dragging = true
			_slider_at(event.position)
			return true
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_adjust(alignment + (4.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -4.0))
		return true
	return false


func key(event: InputEventKey) -> bool:
	if dossier_open:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			act("archive_confirm")
		return true
	if phase == Phase.TRANSITION:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			_finish_transition()
		return true
	if phase in [Phase.SCANNING, Phase.ANOMALY]:
		return true
	if phase == Phase.CALIBRATE:
		if event.keycode in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
			_adjust(alignment + (-4.0 if event.keycode in [KEY_A, KEY_LEFT] else 4.0))
			g.sfx("dial", -20.0)
			return true
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			act("scan")
			return true
	return false


func act(id: String) -> void:
	if g.blocked():
		return
	if id == "archive" and phase in [Phase.INSPECT, Phase.CALIBRATE]:
		dossier_open = true
		dragging = false
		g.sfx("note", -13.0)
	elif id == "archive_confirm" and dossier_open:
		dossier_open = false
		if not inspected:
			inspected = true
			g.flags["lab_bowl_seen"] = true
			phase = Phase.CALIBRATE
			g.say("prologue_record")
	elif id == "turn_left":
		_adjust(alignment - 8.0)
		g.sfx("dial", -20.0)
	elif id == "turn_right":
		_adjust(alignment + 8.0)
		g.sfx("dial", -20.0)
	elif id == "scan" and phase in [Phase.INSPECT, Phase.CALIBRATE]:
		if not inspected:
			g.notify("先核对莲纹碗的缺损档案，再开始今天最后一次扫描。", 4.0)
		elif not calibrated:
			g.notify("光线还没有对齐。先将右侧偏角调到 0°，并停稳片刻。", 4.0)
		else:
			phase = Phase.SCANNING
			scan_time = 0.0
			dragging = false
			g.overlay.toast_time = 0.0
			g.sfx("intro", -18.0)


func _draw() -> void:
	hit_regions.clear()
	if phase == Phase.TRANSITION and film_real:
		draw_rect(Rect2(0, 0, 1440, 900), Color.BLACK)
		_hud(_draw_transition_hud)
		return
	if not _img_cover("lab_damaged", Rect2(0, 0, 1440, 900)):
		_img_cover("lab", Rect2(0, 0, 1440, 900))
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.0, 0.025, 0.045, 0.17))
	_box(Rect2(32, 26, 420, 34), Color(0.025, 0.055, 0.07, 0.86), 4)
	_t(Vector2(48, 49), "序章  /  现代西安 · 文物数字修复实验室 · 01:12", 14, Pal.PAPER)
	if phase in [Phase.INSPECT, Phase.CALIBRATE] and not g.dlg.active:
		_title(Vector2(48, 118), "午夜，最后一件藏品", 36, Pal.PAPER)
		_t(Vector2(50, 148), "一次寻常的扫描，始于四处无法补齐的缺损。", 16, Color("bdd2d6"))
	_draw_light()
	if phase in [Phase.INSPECT, Phase.CALIBRATE] and not g.dlg.active and not dossier_open:
		_hotspot("archive", Vector2(1005, 574), "查看四处缺损", Rect2(851, 521, 320, 151), inspected)
		if phase == Phase.INSPECT:
			_register("archive", Rect2(989, 276, 304, 143))
		_hotspot("scan", Vector2(394, 225), "启动扫描" if calibrated else "扫描仪 · 等待准备", Rect2(291, 150, 190, 137))
		if phase == Phase.CALIBRATE:
			_draw_console()
	if phase == Phase.SCANNING or phase == Phase.ANOMALY:
		_draw_scan_readout()
	if phase in [Phase.INSPECT, Phase.CALIBRATE, Phase.SCANNING] and not g.dlg.active and not dossier_open:
		_draw_steps()
	if dossier_open:
		_draw_dossier()
	if phase == Phase.TRANSITION:
		_draw_transition()


func _ellipse(center: Vector2, radii: Vector2, color: Color, width := 1.0) -> void:
	var points := PackedVector2Array()
	for i in range(97):
		var theta := float(i) / 96.0 * TAU
		points.append(center + Vector2(cos(theta), sin(theta)) * radii)
	draw_polyline(points, color, width, true)


func _draw_light() -> void:
	if phase < Phase.CALIBRATE:
		return
	var power := 0.045 if phase == Phase.CALIBRATE else 0.12
	var tip := Vector2(397, 236)
	var aimed := MIRROR_CENTER + Vector2(alignment_vis * 2.3, 0)
	draw_colored_polygon(PackedVector2Array([tip, aimed + Vector2(-147, 8), aimed + Vector2(147, 8)]), Color(0.49, 0.84, 1.0, power))
	for i in range(13):
		var endpoint := aimed + Vector2(-140 + i * 23, 8)
		draw_line(tip, endpoint, Color(0.48, 0.87, 1.0, power * 1.5), 1.0, true)
	_ellipse(MIRROR_CENTER, Vector2(180, 58), Color(0.5, 0.84, 0.88, 0.6), 1.5)
	var aim_color := Color("8ce4d1") if calibrated else Color("e3ba72")
	_ellipse(aimed, Vector2(28, 10), aim_color, 1.7)
	draw_line(aimed + Vector2(-38, 0), aimed + Vector2(38, 0), Color(aim_color, 0.7), 1.0, true)
	if phase in [Phase.SCANNING, Phase.ANOMALY, Phase.TRANSITION]:
		var progress := clampf(scan_time / SCAN_SECONDS, 0.0, 1.0)
		var sweep_y := -48 + fmod(age * 42.0, 96.0)
		var half_width := sqrt(maxf(0.0, 1.0 - pow(sweep_y / 58.0, 2))) * 170
		draw_line(MIRROR_CENTER + Vector2(-half_width, sweep_y), MIRROR_CENTER + Vector2(half_width, sweep_y), Color(0.65, 0.97, 1, 0.85), 2.0, true)
		for i in range(70):
			var theta := float(i) * 2.39996 + age * 0.25
			var radius := sqrt(float(i) / 70.0)
			var point := MIRROR_CENTER + Vector2(cos(theta) * 165, sin(theta) * 51) * radius
			draw_circle(point, 1.3, Color(0.6, 0.91, 1.0, (0.25 + progress * 0.6) * (0.7 + 0.3 * sin(age * 4.0 + i))))
		if phase >= Phase.ANOMALY:
			for i in range(4):
				var ripple := fmod(age * 0.6 + i * 0.25, 1.0)
				_ellipse(MIRROR_CENTER, Vector2(80, 30) + Vector2(480, 260) * ripple, Color(0.82, 0.95, 1, (1.0 - ripple) * 0.3), 2.0)
			# The missing places answer the mirror's light, matching Su's observation.
			var missing := [Vector2(908, 549), Vector2(1122, 550), Vector2(946, 620), Vector2(1010, 584)]
			for point in missing:
				for radius in range(5, 0, -1):
					draw_circle(point, radius * 6.0, Color(0.48, 0.88, 1.0, 0.035 + 0.015 * sin(age * 3.0)))
				draw_arc(point, 18 + sin(age * 3.0) * 2, 0, TAU, 32, Color(0.61, 0.94, 1.0, 0.7), 1.4, true)


func _draw_console() -> void:
	_box(CONSOLE, Color(0.025, 0.065, 0.082, 0.95), 8, Color(0.5, 0.78, 0.83, 0.58))
	_t(Vector2(942, 216), "STRUCTURED LIGHT  /  结构光校准", 14, Color("97c6d2"))
	_t(Vector2(942, 254), "扫描对象：唐代海兽葡萄纹铜镜", 19, Pal.PAPER)
	_t(Vector2(942, 288), "光线已对齐 · 就绪" if calibrated else "让光圈与铜镜中心重合", 17, Pal.JADE if calibrated else Pal.GOLD)
	var offset_text := "0°" if calibrated else "%+d°" % int(round(alignment))
	_tc(1154, 333, "扫描偏角  " + offset_text, 24, Pal.JADE if calibrated else Pal.PAPER)
	draw_line(Vector2(970, 367), Vector2(1338, 367), Color(0.5, 0.72, 0.76, 0.55), 3, true)
	for i in range(17):
		var x := 970.0 + float(i) * 23.0
		draw_line(Vector2(x, 361), Vector2(x, 375 if i % 4 == 0 else 370), Color(0.65, 0.8, 0.82, 0.55), 1, true)
	draw_rect(Rect2(1144, 352, 20, 31), Color(0.5, 0.88, 0.76, 0.15))
	var knob := Vector2(970 + (alignment / 128.0 + 0.5) * 368, 367)
	draw_circle(knob, 9, Pal.JADE if calibrated else Pal.GOLD)
	draw_circle(knob, 3, Color("11303a"))
	_register("alignment", SLIDER.grow(12))
	_t(Vector2(976, 403), "拖动滑块 / A D / 左右键 / 滚轮", 14, Color("a6bfc4"))
	_button("turn_left", Rect2(942, 434, 66, 46), "−", false, 23)
	_button("scan", Rect2(1022, 434, 264, 46), "启动扫描  ↵" if calibrated else "等待校准", calibrated, 18, calibrated)
	_button("turn_right", Rect2(1300, 434, 66, 46), "+", false, 23)
	if absf(alignment) <= 3.0 and not calibrated:
		draw_rect(Rect2(942, 496, 424 * minf(stable_time / 0.55, 1.0), 3), Pal.JADE)


func _draw_steps() -> void:
	_box(Rect2(48, 750, 1344, 110), Color(0.025, 0.055, 0.067, 0.9), 8, Color(0.53, 0.71, 0.72, 0.35))
	var labels := ["核对缺损档案", "校准铜镜光线", "启动结构光扫描"]
	var done := [inspected, calibrated, phase >= Phase.SCANNING]
	for i in range(3):
		var x := 82.0 + i * 270.0
		var color := Pal.JADE if done[i] else Pal.GOLD if i == (0 if not inspected else 1 if not calibrated else 2) else Pal.MUTED
		draw_arc(Vector2(x + 13, 783), 13, 0, TAU, 32, color, 1.3, true)
		_tc(x + 13, 789, "✓" if done[i] else str(i + 1), 15, color)
		_t(Vector2(x + 38, 790), labels[i], 18, color)
		if i < 2:
			draw_line(Vector2(x + 191, 783), Vector2(x + 234, 783), Color(0.6, 0.78, 0.8, 0.28), 1, true)
	var instruction := "先点击右侧莲纹碗或电脑，核对四处缺口。"
	if inspected:
		instruction = "拖动右侧刻度，让扫描偏角回到 0°，再停稳片刻。" if not calibrated else "准备完成。点击「启动扫描」，或按回车。"
	if phase == Phase.SCANNING:
		instruction = "扫描进行中……正在记录铜镜表面纹样。"
	_t(Vector2(84, 833), instruction, 16, Color("c8d8d9"))
	_t(Vector2(1072, 789), "今日最后一件藏品", 17, Pal.PAPER)
	_t(Vector2(1072, 829), "档案记录 · 缺失残片 4", 15, Color("a5bdc0"))


func _draw_dossier() -> void:
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.0, 0.015, 0.025, 0.68))
	_panel(Rect2(230, 155, 980, 536))
	_t(Vector2(270, 200), "CONSERVATION RECORD  /  修复档案", 14, Pal.GOLD)
	_title(Vector2(270, 248), "越窑莲纹碗 · 四处缺损", 34, Pal.PAPER)
	draw_line(Vector2(270, 267), Vector2(1170, 267), Color(Pal.GOLD, 0.25), 1, true)
	_box(Rect2(270, 292, 518, 300), Color(0.02, 0.045, 0.052, 0.9), 4, Color(Pal.JADE, 0.25))
	_img("bowl_damaged", Rect2(290, 324, 480, 242))
	var markers := [Vector2(372, 358), Vector2(702, 365), Vector2(425, 474), Vector2(550, 426)]
	for i in range(markers.size()):
		draw_circle(markers[i], 15, Color(0.03, 0.06, 0.06, 0.92))
		draw_arc(markers[i], 15, 0, TAU, 32, Pal.GOLD, 1.2, true)
		_tc(markers[i].x, markers[i].y + 6, str(i + 1), 16, Pal.GOLD)
	_t(Vector2(820, 321), "已记录缺损  4 / 4", 21, Pal.GOLD)
	var parts := ["左侧碗沿", "右侧碗沿", "碗腹残片", "莲纹中心"]
	for i in range(parts.size()):
		_t(Vector2(822, 367 + i * 38), "%02d   %s" % [i + 1, parts[i]], 18, Pal.PAPER)
	_wrap(Vector2(820, 540), "原始残片下落不明。现有数据不足，暂不能补齐模型。", 340, 16, Pal.MUTED, 26)
	_t(Vector2(274, 630), "记住这些断口与莲纹，之后或许能辨认出它们。", 16, Pal.MUTED)
	_button("archive_confirm", Rect2(862, 612, 304, 46), "确认档案，准备扫描", true, 17)


func _draw_scan_readout() -> void:
	_box(Rect2(916, 185, 476, 267), Color(0.025, 0.065, 0.082, 0.95), 8, Color(0.5, 0.78, 0.83, 0.58))
	var anomaly := phase >= Phase.ANOMALY
	var color := Color("ffd4a0") if anomaly else Pal.JADE
	_t(Vector2(942, 219), "回波异常 · 光线失控" if anomaly else "正在采集 · 铜镜表面纹样", 21, color)
	_t(Vector2(942, 263), "反射强度持续升高，扫描仪已停止响应。" if anomaly else "转台锁定    结构光采样    数据重建", 16, Pal.PAPER)
	var progress := scan_time / SCAN_SECONDS
	_box(Rect2(942, 291, 424, 8), Color(0.25, 0.4, 0.44, 0.5), 3)
	_box(Rect2(942, 291, 424 * progress, 8), color, 3)
	_t(Vector2(942, 333), "采集进度   %03d%%" % int(progress * 100), 22, color)
	_t(Vector2(942, 373), "莲纹碗缺损档案出现同步回波。" if anomaly else "光线稳定 · 请等待采集完成", 16, color)
	_t(Vector2(942, 417), "记录中断  /  来源未知" if anomaly else "采样中  /  请勿移动器物", 14, Pal.MUTED)


func _draw_transition() -> void:
	var amount := smoothstep(0.0, 1.1, flash)
	for i in range(20):
		var theta := float(i) / 20.0 * TAU + flash * 0.12
		var end := MIRROR_CENTER + Vector2(cos(theta), sin(theta)) * 1500
		draw_line(MIRROR_CENTER, end, Color(0.85, 0.94, 1.0, amount * 0.13), 2 + amount * 35, true)
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.96, 0.985, 1.0, amount))


func _draw_transition_hud() -> void:
	_button("skip", Rect2(1246, 8, 154, 30), "跳过 · 空格", false, 13)
