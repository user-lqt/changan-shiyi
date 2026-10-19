extends "res://scripts/core/canvas.gd"
## 终章 · 金缮: drag the four shards onto the broken bowl, rotate them (wheel / Q E) to the right
## angle, and they snap in. When all four are placed, gold seams light up.

const Frag = preload("res://scripts/data/fragments_data.gd")
const BOWL_RECT := Rect2(380, 300, 640, 326)
const SNAP_DIST := 34.0
const SNAP_ANGLE := 20.0
const TRAY := [Vector2(170, 330), Vector2(170, 560), Vector2(1250, 330), Vector2(1250, 560)]
const START_ROT := [90.0, -45.0, 135.0, -90.0]

var pieces: Array = []     # {pos, rot, placed, flash}
var drag := -1
var drag_off := Vector2.ZERO
var selected := 0
var done := false
var seam_t := 0.0
var tries := 0


func enter() -> void:
	g.music("ambient")
	for i in range(4):
		pieces.append({"pos": TRAY[i], "rot": START_ROT[i], "placed": false, "flash": 0.0})
	g.say("finale_intro")


func help_lines() -> Array:
	return ["按住鼠标拖动碎片；拖动时或选中后用滚轮 / Q E 旋转 45°。", "碎片靠近缺口、角度正确时会自动嵌入。", "按 1–4 选中碎片。"]


func hint() -> String:
	for i in range(4):
		if not pieces[i]["placed"]:
			var r := int(posmod(int(round(pieces[i]["rot"])), 360))
			return "第 %d 片现在转了 %d°，要转回 0° 才能嵌进去。看碎片边缘的形状和缺口对一对。" % [i + 1, r]
	return "四片都已归位。"


func target(i: int) -> Vector2:
	return BOWL_RECT.position + Frag.FRAGMENTS[i]["center"]


func _piece_at(p: Vector2) -> int:
	for i in range(3, -1, -1):
		if pieces[i]["placed"]:
			continue
		var s: Vector2 = Frag.FRAGMENTS[i]["size"]
		if p.distance_to(pieces[i]["pos"]) < maxf(s.x, s.y) * 0.45:
			return i
	return -1


func tick(delta: float, _blocked: bool) -> void:
	for pc in pieces:
		pc["flash"] = maxf(0.0, pc["flash"] - delta)
	if done:
		seam_t = minf(1.0, seam_t + delta * 0.5)


func mouse(event: InputEvent) -> bool:
	if done or g.blocked():
		return false
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var i := _piece_at(event.position)
			if i >= 0:
				drag = i
				selected = i
				drag_off = pieces[i]["pos"] - event.position
				g.sfx("click")
				return true
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and drag >= 0:
			var i := drag
			drag = -1
			_try_snap(i)
			return true
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			rotate_piece(selected, 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			return true
	elif event is InputEventMouseMotion and drag >= 0:
		pieces[drag]["pos"] = event.position + drag_off
		return true
	return false


func key(event: InputEventKey) -> bool:
	if done:
		return false
	match event.keycode:
		KEY_Q:
			rotate_piece(selected, -1)
			return true
		KEY_E:
			rotate_piece(selected, 1)
			return true
		KEY_1, KEY_2, KEY_3, KEY_4:
			selected = event.keycode - KEY_1
			return true
	return false


func rotate_piece(i: int, direction: int) -> void:
	if i < 0 or pieces[i]["placed"]:
		return
	pieces[i]["rot"] = fposmod(pieces[i]["rot"] + direction * 45.0, 360.0)
	g.sfx("rotate", -10)
	if drag != i:
		_try_snap(i)


## Moves a piece to a position (used by drag release and tests) and attempts to snap.
func drop(i: int, p: Vector2) -> bool:
	pieces[i]["pos"] = p
	return _try_snap(i)


func _try_snap(i: int) -> bool:
	var pc: Dictionary = pieces[i]
	if pc["placed"]:
		return true
	var dist: float = (pc["pos"] as Vector2).distance_to(target(i))
	var ang := absf(wrapf(pc["rot"], -180.0, 180.0))
	if dist < SNAP_DIST and ang < SNAP_ANGLE:
		pc["placed"] = true
		pc["pos"] = target(i)
		pc["rot"] = 0.0
		pc["flash"] = 0.8
		g.sfx("place")
		_check_done()
		return true
	if dist < SNAP_DIST * 2.5:
		tries += 1
		if ang >= SNAP_ANGLE:
			g.notify("位置对了，但角度不对。用滚轮或 Q / E 旋转。", 3)
		g.sfx("error", -14)
	return false


func _check_done() -> void:
	for pc in pieces:
		if not pc["placed"]:
			return
	done = true
	g.sfx("win")
	get_tree().create_timer(0.01 if g.test_mode else 1.6).timeout.connect(_finish_story)


func _finish_story() -> void:
	if g.scene != self or not g.pending.is_empty():
		return
	g.say("finale_done", func() -> void:
		g.clear("finale")
		g.show_card("bowl", func() -> void: g.go("epilogue")))


func act(id: String) -> void:
	_common_act(id)


func _draw() -> void:
	hit_regions.clear()
	if not _img_cover("workshop", Rect2(0, 0, 1440, 900), Color(0.32, 0.3, 0.3)):
		draw_rect(Rect2(0, 0, 1440, 900), Pal.BG)
	_title(Vector2(40, 60), "终章  ·  金缮", 36, Pal.PAPER)
	_t(Vector2(42, 92), "温记镜坊  /  拂晓", 14, Pal.MUTED)
	# Work mat.
	var mat := Rect2(330, 230, 740, 470)
	_box(mat, Color(0.08, 0.12, 0.12, 0.92), 16, Color("7f7859"))
	_corner_ornaments(mat)
	for r in range(6, 0, -1):
		draw_circle(BOWL_RECT.get_center(), 230 + r * 12, Color(1, 0.85, 0.5, 0.008))
	if done:
		_img("bowl", BOWL_RECT)
		_gold_seams(BOWL_RECT, seam_t)
	else:
		_img("bowl_broken", BOWL_RECT)
		# Faint outline of where the selected piece belongs.
		if selected >= 0 and not pieces[selected]["placed"]:
			draw_arc(target(selected), 22, 0, TAU, 32, Color(1, 0.85, 0.5, 0.25 + 0.15 * sin(age * 4)), 2, true)
	for i in range(4):
		var pc: Dictionary = pieces[i]
		if done:
			break
		var key := "frag_%d" % i
		if not g.tex.has(key):
			continue
		var t: Texture2D = g.tex[key]
		var s := t.get_size()
		var lift := 1.06 if drag == i else 1.0
		draw_set_transform(pc["pos"], deg_to_rad(pc["rot"]), Vector2(lift, lift))
		if drag == i:
			draw_texture_rect(t, Rect2(-s * 0.5 + Vector2(6, 8), s), false, Color(0, 0, 0, 0.35))
		draw_texture_rect(t, Rect2(-s * 0.5, s), false)
		if pc["flash"] > 0:
			draw_texture_rect(t, Rect2(-s * 0.5, s), false, Color(1, 0.9, 0.6, pc["flash"]))
		draw_set_transform(Vector2.ZERO)
		if not pc["placed"]:
			var lp: Vector2 = pc["pos"] + Vector2(0, maxf(s.x, s.y) * 0.5 + 18)
			_tc(lp.x, lp.y, "%d%s" % [i + 1, "  ·  选中" if selected == i else ""], 13, Pal.GOLD if selected == i else Pal.MUTED)
	var placed := 0
	for pc in pieces:
		if pc["placed"]:
			placed += 1
	_box(Rect2(330, 720, 740, 60), Color(0.06, 0.1, 0.1, 0.9), 10, Pal.PANEL_EDGE)
	_t(Vector2(356, 757), "已归位  %d / 4" % placed, 17, Pal.PAPER)
	_t(Vector2(520, 757), "拖动碎片 · 滚轮或 Q / E 旋转 · 1–4 选择" if not done else "裂痕成了最好看的纹。", 14, Pal.MUTED)
	_button("hint", Rect2(930, 732, 120, 36), "提示  H", false, 13)
