extends Node2D
## Base class for every screen layer. Provides shared drawing helpers and click regions.
## Scenes override: enter(), tick(delta, blocked), act(id), key(event) -> bool,
## mouse(event) -> bool, help_lines() -> Array, chrome() -> bool.

const Pal = preload("res://scripts/core/pal.gd")

var g                                   # main.gd (game host)
var hit_regions: Array[Dictionary] = []
var age := 0.0
# Helpers draw on cv. It is self for the scene, and the overlay while the HUD is drawn
# (the HUD has to sit above the scene, in screen coordinates).
var cv: CanvasItem = self
var hud_mode := false
var hud_regions: Array[Dictionary] = []
var hud_calls: Array[Callable] = []
var frame_args := {}
var frame_stamp := -10
var hud_stamp := -10


func setup(game) -> void:
	g = game


# ---------------------------------------------------------------- overridables
func enter() -> void:
	pass


func tick(_delta: float, _blocked: bool) -> void:
	pass


func act(_id: String) -> void:
	pass


func key(_event: InputEventKey) -> bool:
	return false


func mouse(_event: InputEvent) -> bool:
	return false


## Optional drag handling for inventory controls drawn above the scene.
func hud_mouse(_event: InputEvent) -> bool:
	return false


## A chapter may temporarily own input and suspend the dialogue during a cutscene.
func cinematic_active() -> bool:
	return false


func help_lines() -> Array:
	return ["鼠标点击发光标记：调查、拾取或操作物件。", "J 打开手札；H 获取提示；Esc 关闭面板。"]


func chrome() -> bool:
	return true          # show the global sound / help buttons


## True while the scene shows a ROOM-space painting. The host then scales ROOM up so the
## painting fills the window (see stage_transform), and the HUD floats on top.
func staged() -> bool:
	return false


## False when the chapter draws its own bottom row (hides objective, inventory, shards,
## journal and hint buttons of the shared HUD).
func bottom_hud() -> bool:
	return true


func hint() -> String:
	return "仔细观察画面中发光的地方。"


# ---------------------------------------------------------------- stage mapping
## The scene's picture area (in its own coordinates) is scaled to the full window width and
## centred vertically, so the 3:2 paintings cover the whole 1440 × 900 window.
func stage_rect() -> Rect2:
	return ROOM


func stage_k() -> float:
	return 1440.0 / stage_rect().size.x


func stage_transform() -> Transform2D:
	if not staged():
		return Transform2D.IDENTITY
	var r := stage_rect()
	var k := stage_k()
	var top := (900.0 - r.size.y * k) * 0.5
	return Transform2D(0.0, Vector2(k, k), 0.0, Vector2(-r.position.x * k, top - r.position.y * k))


## The whole window expressed in the scene's coordinates.
func bleed() -> Rect2:
	var r := stage_rect()
	var k := stage_k()
	var top := (900.0 - r.size.y * k) * 0.5
	return Rect2(r.position.x, r.position.y - top / k, r.size.x, 900.0 / k)


func to_stage(screen: Vector2) -> Vector2:
	return transform.affine_inverse() * screen


func to_screen(local: Vector2) -> Vector2:
	return transform * local


## Copy of a mouse event with its position in this scene's local coordinates.
func localize(event: InputEvent) -> InputEvent:
	if not event is InputEventMouse or transform == Transform2D.IDENTITY:
		return event
	var e: InputEventMouse = event.duplicate()
	e.position = to_stage(event.position)
	if e is InputEventMouseMotion:
		e.relative = e.relative / transform.get_scale().x
	return e


# ---------------------------------------------------------------- hit testing
## Screen-space lookup used by the host: HUD controls first, then the scene itself.
func hit_screen(pos: Vector2) -> String:
	var id := hud_hit(pos)
	return id if not id.is_empty() else hit(to_stage(pos))


func hud_hit(pos: Vector2) -> String:
	for i in range(hud_regions.size() - 1, -1, -1):
		if (hud_regions[i]["rect"] as Rect2).has_point(pos):
			return str(hud_regions[i]["id"])
	return ""


func hit(pos: Vector2) -> String:
	for i in range(hit_regions.size() - 1, -1, -1):
		if (hit_regions[i]["rect"] as Rect2).has_point(pos):
			return str(hit_regions[i]["id"])
	return ""


func _register(id: String, rect: Rect2) -> void:
	if hud_mode:
		hud_regions.append({"id": id, "rect": rect})
	else:
		hit_regions.append({"id": id, "rect": rect})


func _mouse() -> Vector2:
	return g.get_local_mouse_position() if hud_mode else get_local_mouse_position()


# ---------------------------------------------------------------- drawing helpers
## Battle text, including its overlay and menus, uses the bundled Song serif throughout.
func _body_font() -> Font:
	return g.prose if g.screen == "ch7" else g.face


func _heading_font() -> Font:
	return g.prose if g.screen == "ch7" else g.heading


func _t(p: Vector2, text: String, size: int, color: Color) -> void:
	cv.draw_string(_body_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _tw(text: String, size: int) -> float:
	return _body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _tc(cx: float, y: float, text: String, size: int, color: Color) -> void:
	_t(Vector2(cx - _tw(text, size) * 0.5, y), text, size, color)


## Brush calligraphy for display text; smaller instructions retain the clear sans face.
func _title(p: Vector2, text: String, size: int, color: Color) -> void:
	# Pale lettering needs separation from paintings; dark ink stays crisp on paper.
	if color.get_luminance() > 0.35:
		cv.draw_string_outline(_heading_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(1, int(size / 24.0)), Color(0.025, 0.02, 0.015, color.a * 0.65))
	cv.draw_string(_heading_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _title_center(cx: float, y: float, text: String, size: int, color: Color) -> void:
	var w := _title_width(text, size)
	_title(Vector2(cx - w * 0.5, y), text, size, color)


func _title_width(text: String, size: int) -> float:
	return _heading_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _serif(p: Vector2, text: String, size: int, color: Color) -> void:
	cv.draw_string(g.prose, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _serif_width(text: String, size: int) -> float:
	return g.prose.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _serif_center(cx: float, y: float, text: String, size: int, color: Color) -> void:
	_serif(Vector2(cx - _serif_width(text, size) * 0.5, y), text, size, color)


func _fit_size(font: Font, text: String, size: int, width: float) -> int:
	var fitted := size
	while fitted > 11 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
		fitted -= 1
	return fitted


func _wrap(p: Vector2, text: String, width: float, size: int, color: Color, line_height: float) -> int:
	return _wrap_font(_body_font(), p, text, width, size, color, line_height)


func _serif_wrap(p: Vector2, text: String, width: float, size: int, color: Color, line_height: float) -> int:
	return _wrap_font(g.prose, p, text, width, size, color, line_height)


func _wrap_font(font: Font, p: Vector2, text: String, width: float, size: int, color: Color, line_height: float) -> int:
	var line := ""
	var row := 0
	for character in text:
		if character == "\n" or font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			cv.draw_string(font, p + Vector2(0, row * line_height), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
			row += 1
			line = "" if character == "\n" else character
		else:
			line += character
	cv.draw_string(font, p + Vector2(0, row * line_height), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return row + 1


func _box(rect: Rect2, fill: Color, radius: int = 8, outline: Color = Color.TRANSPARENT, border := 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	if outline.a > 0:
		style.border_color = outline
		style.set_border_width_all(border)
	cv.draw_style_box(style, rect)


func _button(id: String, rect: Rect2, caption: String, primary := false, size := 16, enabled := true) -> void:
	var hover := enabled and rect.has_point(_mouse())
	var fill: Color
	var edge: Color
	var tc: Color
	if not enabled:
		fill = Color(0.03, 0.04, 0.045, 0.55)
		edge = Color(0.6, 0.58, 0.5, 0.22)
		tc = Color(0.55, 0.58, 0.55, 0.7)
	elif primary:
		fill = Color("d4b06a") if hover else Color("c4a160")
		edge = Color("f3dca2")
		tc = Pal.INK
	else:
		fill = Color(0.08, 0.11, 0.11, 0.9) if hover else Color(0.03, 0.05, 0.055, 0.78)
		edge = Color(0.84, 0.72, 0.48, 0.8 if hover else 0.38)
		tc = Pal.PAPER
	_box(rect, fill, 3, edge)
	if primary and enabled:
		cv.draw_rect(rect.grow(-4), Color(1, 0.95, 0.8, 0.35), false, 1.0)
	if rect.size.x >= 150 and rect.size.y >= 40:
		_img("ui_corner_tl", Rect2(rect.position + Vector2(4, 4), Vector2(22, 24)), Color(1, 1, 1, 0.6 if hover else 0.38))
		_img("ui_corner_br", Rect2(rect.end - Vector2(26, 28), Vector2(22, 24)), Color(1, 1, 1, 0.6 if hover else 0.38))
	var fitted := _fit_size(_body_font(), caption, maxi(size, 13), rect.size.x - 16)
	var baseline: float = rect.get_center().y + (_body_font().get_ascent(fitted) - _body_font().get_descent(fitted)) * 0.5
	_tc(rect.get_center().x, baseline, caption, fitted, tc)
	if enabled:
		_register(id, rect)


## Dialogue choices keep ornament and lettering in separate, stable columns.
func _dialogue_choice(id: String, rect: Rect2, caption: String) -> void:
	var hover := rect.has_point(_mouse())
	_box(rect.grow(3), Color(0.015, 0.025, 0.03, 0.5), 6)
	_box(rect, Color("173235") if hover else Color(0.025, 0.05, 0.055, 0.96), 4, Color(0.84, 0.72, 0.48, 0.9 if hover else 0.58))
	cv.draw_rect(rect.grow(-5), Color(0.84, 0.72, 0.48, 0.25 if hover else 0.12), false)
	_img("ui_mirror_seal", Rect2(rect.position + Vector2(17, 11), Vector2(36, 36)), Color(1, 1, 1, 1.0 if hover else 0.7))
	_img("ui_grape_flourish", Rect2(rect.end.x - 83, rect.position.y + 16, 67, 26), Color(1, 1, 1, 0.85 if hover else 0.45))
	var size := _fit_size(g.prose, caption, 20, rect.size.x - 176)
	var baseline: float = rect.get_center().y + (g.prose.get_ascent(size) - g.prose.get_descent(size)) * 0.5
	_serif_center(rect.get_center().x - 6, baseline, caption, size, Color("fff0c8") if hover else Pal.PAPER)
	_register(id, rect)


func _dialogue_frame(rect: Rect2, opacity: float) -> void:
	_box(rect.grow(5), Color(0, 0, 0, 0.22 * opacity), 6)
	_box(rect, Color(0.02, 0.035, 0.04, 0.94 * opacity), 4, Color(0.84, 0.72, 0.48, 0.48 * opacity))
	cv.draw_rect(rect.grow(-7), Color(0.84, 0.72, 0.48, 0.16 * opacity), false)
	_ornate_corners(rect, 46.0, opacity)
	_img("ui_grape_flourish", Rect2(rect.get_center().x - 68, rect.position.y - 17, 136, 54), Color(1, 1, 1, 0.9 * opacity))
	_img("ui_cloud_rule", Rect2(rect.get_center().x - 64, rect.end.y - 17, 128, 20), Color(1, 1, 1, 0.6 * opacity))


func _ornate_corners(rect: Rect2, size: float, opacity: float) -> void:
	var tint := Color(1, 1, 1, opacity)
	_img("ui_corner_tl", Rect2(rect.position + Vector2(5, 5), Vector2(size, size)), tint)
	_img("ui_corner_tr", Rect2(rect.end.x - size - 5, rect.position.y + 5, size, size), tint)
	_img("ui_corner_bl", Rect2(rect.position.x + 5, rect.end.y - size - 5, size, size), tint)
	_img("ui_corner_br", Rect2(rect.end - Vector2.ONE * (size + 5), Vector2(size, size)), tint)


## Round icon button used by the HUD (journal, hint).
func _round_button(id: String, c: Vector2, glyph: String, label: String) -> void:
	var r := Rect2(c - Vector2(26, 26), Vector2(52, 52))
	var hover := r.has_point(_mouse())
	cv.draw_circle(c, 25, Color(0.03, 0.05, 0.055, 0.85 if hover else 0.72))
	cv.draw_arc(c, 25, 0, TAU, 40, Color(0.84, 0.72, 0.48, 0.95 if hover else 0.5), 1.5, true)
	cv.draw_arc(c, 21, 0, TAU, 40, Color(0.84, 0.72, 0.48, 0.22), 1.0, true)
	_title_center(c.x, c.y + 9, glyph, 23, Pal.PAPER if not hover else Color("ffe7b0"))
	_tc(c.x + 1, c.y + 45, label, 13, Color(0, 0, 0, 0.7))
	_tc(c.x, c.y + 44, label, 13, Pal.GOLD)
	_register(id, r)


func _hotspot(id: String, p: Vector2, label: String, rect: Rect2, seen := false) -> void:
	var hover := rect.has_point(_mouse())
	var pulse := 0.5 + 0.5 * sin(age * 2.2 + p.x * 0.01)
	var c := Pal.GOLD if not seen else Color(0.72, 0.78, 0.74)
	for r in range(4, 0, -1):
		cv.draw_circle(p, 8 + r * 5 + pulse * 3, Color(c, (0.03 if not seen else 0.015) * (1.4 if hover else 1.0)))
	cv.draw_arc(p, 12 + pulse * 2, 0, TAU, 36, Color(c, 0.9 if hover else 0.6), 1.3, true)
	var d := 4.5 if not hover else 6.0
	cv.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]), Color(c, 0.95))
	if hover:
		var w := _tw(label, 15) + 30
		var tag := Rect2(p + Vector2(-w * .5, -50), Vector2(w, 32))
		_box(tag, Color(0.02, 0.035, 0.04, 0.88), 3)
		cv.draw_rect(Rect2(tag.position, Vector2(3, tag.size.y)), Pal.GOLD)
		_t(tag.position + Vector2(16, 22), label, 15, Pal.PAPER)
	_register(id, rect)


## Shared modal panel: deep ink lacquer, a double gold hairline and corner ornaments.
func _panel(r: Rect2) -> void:
	cv.draw_rect(r.grow(10), Color(0, 0, 0, 0.18))
	_box(r, Color(0.035, 0.055, 0.06, 0.97), 4, Color(0.84, 0.72, 0.48, 0.75), 1)
	cv.draw_rect(r.grow(-7), Color(0.84, 0.72, 0.48, 0.22), false, 1.0)
	_corner_ornaments(r)


func _corner_ornaments(r: Rect2, alpha := 0.55) -> void:
	if g.tex.has("ui_corner_tl") and r.size.x >= 300 and r.size.y >= 120:
		_ornate_corners(r, minf(56.0, r.size.y * 0.25), alpha)
		return
	var c := Color(0.84, 0.72, 0.48, alpha)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if corner.x < r.get_center().x else -1.0
		var sy := 1.0 if corner.y < r.get_center().y else -1.0
		var o: Vector2 = corner + Vector2(10 * sx, 10 * sy)
		cv.draw_line(o, o + Vector2(26 * sx, 0), c, 1.5, true)
		cv.draw_line(o, o + Vector2(0, 26 * sy), c, 1.5, true)
		cv.draw_line(o + Vector2(5 * sx, 5 * sy), o + Vector2(14 * sx, 5 * sy), c, 1.0, true)
		cv.draw_line(o + Vector2(5 * sx, 5 * sy), o + Vector2(5 * sx, 14 * sy), c, 1.0, true)


func _cover_crop(size: Vector2, target: Vector2) -> Rect2:
	var scale_factor := maxf(target.x / size.x, target.y / size.y)
	var use := target / scale_factor
	return Rect2((size - use) * 0.5, use)


func _img(key: String, rect: Rect2, modulate := Color.WHITE) -> bool:
	if not g.tex.has(key):
		return false
	cv.draw_texture_rect(g.tex[key], rect, false, modulate)
	return true


func _img_cover(key: String, rect: Rect2, modulate := Color.WHITE) -> bool:
	if not g.tex.has(key):
		return false
	var t: Texture2D = g.tex[key]
	var crop := _cover_crop(t.get_size(), rect.size)
	if rect == stage_rect() and staged():
		# Keep the painting exactly where it was inside the picture area (hotspots are
		# authored against it) and reveal more of the same image around it.
		var px := crop.size.x / rect.size.x
		var want := bleed()
		var src := Rect2(crop.position + (want.position - rect.position) * px, want.size * px)
		var inside := src.intersection(Rect2(Vector2.ZERO, t.get_size()))
		var dest := Rect2(want.position + (inside.position - src.position) / px, inside.size / px)
		cv.draw_rect(want, Pal.BG)
		cv.draw_texture_rect_region(t, dest, inside, modulate)
		return true
	cv.draw_texture_rect_region(t, rect, crop, modulate)
	return true


## Draws a texture fitted to a height, anchored at its bottom-centre.
func _figure(key: String, foot: Vector2, height: float, modulate := Color.WHITE) -> Rect2:
	if not g.tex.has(key):
		return Rect2()
	var t: Texture2D = g.tex[key]
	var w := t.get_size().x / t.get_size().y * height
	var r := Rect2(foot.x - w * 0.5, foot.y - height, w, height)
	cv.draw_texture_rect(t, r, false, modulate)
	return r


func _shard(p: Vector2, scale_factor: float, modulate := Color.WHITE) -> void:
	if g.tex.has("shard"):
		var t: Texture2D = g.tex["shard"]
		var s := t.get_size() / t.get_size().x * 92.0 * scale_factor
		cv.draw_texture_rect(t, Rect2(p - s * 0.5, s), false, modulate)
		return
	var points := PackedVector2Array([Vector2(-37, -36), Vector2(13, -43), Vector2(44, -8), Vector2(20, 43), Vector2(-22, 30)])
	for i in range(points.size()):
		points[i] = p + points[i] * scale_factor
	cv.draw_colored_polygon(points, Color("82bdaf"))


## Shard counter shown in several HUDs.
func _shard_slots(origin: Vector2, size := 34.0) -> void:
	for i in range(4):
		var c := origin + Vector2(i * (size + 8), 0) + Vector2(size, size) * 0.5
		cv.draw_circle(c, size * 0.5, Color(0.03, 0.05, 0.055, 0.75))
		cv.draw_arc(c, size * 0.5, 0, TAU, 32, Pal.JADE if g.shards[i] else Color(0.84, 0.72, 0.48, 0.35), 1.4, true)
		if g.shards[i]:
			_shard(c, size / 120.0)
		else:
			cv.draw_circle(c, 2.5, Color(0.84, 0.72, 0.48, 0.45))


func _glyph(p: Vector2, symbol: int, size: float, color: Color) -> void:
	var points := PackedVector2Array()
	match symbol:
		0:
			points = PackedVector2Array([Vector2(-1, 0.7), Vector2(-1, -0.3), Vector2(-0.8, 0.7), Vector2(0, 0.7), Vector2(0, -0.9), Vector2(0, 0.7), Vector2(1, 0.7), Vector2(1, -0.3)])
		1:
			for i in range(24):
				var a := -PI * 0.53 + float(i) / 23.0 * PI * 1.45
				points.append(Vector2(cos(a), sin(a)))
			points.append(Vector2(0.05, -0.1))
			points.append(points[0])
		2:
			for j in range(3):
				var wave := PackedVector2Array()
				for i in range(18):
					wave.append(p + Vector2(-1.0 + i / 17.0 * 2, (j - 1) * 0.58 + sin(i / 17.0 * TAU) * 0.14) * size)
				cv.draw_polyline(wave, color, maxf(1.2, size * 0.09), true)
			return
		3:
			cv.draw_arc(p, size * 0.8, 0, TAU, 32, color, maxf(1.2, size * 0.1), true)
			for i in range(8):
				var dir := Vector2.from_angle(float(i) * TAU / 8)
				cv.draw_line(p + dir * size, p + dir * size * 1.25, color, maxf(1.2, size * 0.08), true)
			return
		4:
			points = PackedVector2Array([Vector2(0, 1), Vector2(0, -1), Vector2(-.9, .3), Vector2(0, -.5), Vector2(.9, .3), Vector2(0, -.5)])
		5:
			for i in range(3):
				cv.draw_arc(p + Vector2((i - 1) * size * .6, 0), size * .6, PI, TAU, 20, color, maxf(1.2, size * .1), true)
			cv.draw_line(p + Vector2(-1.6, .3) * size, p + Vector2(1.6, .3) * size, color, maxf(1.2, size * .1), true)
			return
	for i in range(points.size()):
		points[i] = p + points[i] * size
	if points.size() > 1:
		cv.draw_polyline(points, color, maxf(1.2, size * 0.09), true)


## Moon phase icon: 0 = 朔 (new), 1 = 弦 (half), 2 = 望 (full).
func _moon(p: Vector2, r: float, phase: int, color: Color) -> void:
	var key := "moon_phase_%d" % phase
	if g.tex.has(key):
		var diameter := r * 2.28
		cv.draw_texture_rect(g.tex[key], Rect2(p - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter), false, color)
		return
	cv.draw_arc(p, r, 0, TAU, 40, color, 1.6, true)
	match phase:
		0:
			cv.draw_circle(p, r * 0.92, Color(0.02, 0.03, 0.05, 0.9))
		1:
			var pts := PackedVector2Array()
			for i in range(21):
				var a := -PI * 0.5 + PI * float(i) / 20.0
				pts.append(p + Vector2(cos(a), sin(a)) * r * 0.92)
			cv.draw_colored_polygon(pts, color)
		2:
			cv.draw_circle(p, r * 0.92, color)


## Kintsugi gold seams (baked from the fragment masks by tools/build_fragments.py).
func _gold_seams(rect: Rect2, strength: float) -> void:
	if not g.tex.has("bowl_seams"):
		return
	var shimmer := 0.8 + 0.2 * sin(age * 2.0)
	cv.draw_texture_rect(g.tex["bowl_seams"], rect.grow(1.5), false, Color(1.0, 0.72, 0.28, 0.45 * strength))
	cv.draw_texture_rect(g.tex["bowl_seams"], rect, false, Color(1.0, 0.86, 0.45, strength * shimmer))


# ---------------------------------------------------------------- shared chapter frame
const ROOM := Rect2(38, 170, 1074, 604)
const SIDE := Rect2(1136, 170, 266, 700)
const BAR := Rect2(38, 794, 1074, 76)


## Floating HUD over a full-bleed scene. goals: [{t, d, done}], items: [{id, name, icon, sub}].
## Nothing is drawn here: the call is recorded and the overlay draws it in screen space
## after the scene, so the HUD always sits above the painting (see draw_hud).
func _frame(chapter: String, place: String, goals: Array, objective: String, items: Array, selected := "") -> void:
	frame_args = {"chapter": chapter, "place": place, "goals": goals, "objective": objective, "items": items, "selected": selected}
	frame_stamp = Engine.get_process_frames()
	if staged():
		cv.draw_rect(bleed(), Pal.BG)


## Defers drawing of a screen-space HUD element (buttons that used to sit in the bars).
func _hud(c: Callable) -> void:
	var now := Engine.get_process_frames()
	if hud_stamp != now:
		hud_calls.clear()
		hud_stamp = now
	hud_calls.append(c)


## Called by the overlay with cv = overlay. Draws the recorded frame and HUD calls.
func draw_hud(target: CanvasItem) -> void:
	cv = target
	hud_mode = true
	hud_regions.clear()
	var now := Engine.get_process_frames()
	if now - frame_stamp <= 1 and not frame_args.is_empty():
		_draw_frame_hud()
	if now - hud_stamp <= 1 and not g.dlg.active:
		for c in hud_calls:
			c.call()
	hud_mode = false
	cv = self


func _draw_frame_hud() -> void:
	var a: Dictionary = frame_args
	# Top and bottom vignettes keep text readable without boxing the picture in.
	for i in range(18):
		var k := 1.0 - i / 18.0
		cv.draw_rect(Rect2(0, i * 8, 1440, 8), Color(0.01, 0.015, 0.02, 0.05 * k * k * 4))
		cv.draw_rect(Rect2(0, 900 - (i + 1) * 9, 1440, 9), Color(0.01, 0.015, 0.02, 0.055 * k * k * 4))
	title_block(str(a["chapter"]), str(a["place"]))
	_goal_scroll(a["goals"])
	if g.dlg.active or not bottom_hud():
		return                  # the dialogue box (or the chapter) owns the bottom of the screen
	# Objective line, centred above the bottom edge.
	var obj: String = a["objective"]
	if not obj.is_empty():
		var w := _tw(obj, 16) + 56
		var r := Rect2(720 - w * 0.5, 820, w, 38)
		_box(r, Color(0.02, 0.03, 0.035, 0.62), 19)
		cv.draw_circle(r.position + Vector2(20, 19), 3, Pal.GOLD)
		_t(r.position + Vector2(34, 25), obj, 16, Pal.PAPER)
	_inventory(a["items"], a["selected"])
	_shard_slots(Vector2(1242, 822), 32)
	_round_button("journal", Vector2(1128, 836), "札", "手札 J")
	_round_button("hint", Vector2(1190, 836), "？", "提示 H")


## Chapter title at the top left: a soft ink wash behind it, a vertical gold rule,
## the chapter name and the place / time.
func title_block(chapter: String, place: String) -> void:
	var w := maxf(_title_width(chapter, 30), _tw(place, 14)) + 90
	for i in range(10):
		var k := 1.0 - i / 10.0
		cv.draw_rect(Rect2(0, 20, w + i * 22, 104), Color(0.01, 0.015, 0.02, 0.06 * k))
	cv.draw_rect(Rect2(40, 34, 3, 58), Pal.GOLD)
	_t(Vector2(58, 52), "长安拾遗", 13, Color(Pal.GOLD, 0.95))
	_title(Vector2(56, 86), chapter, 30, Pal.PAPER)
	_shadow_text(Vector2(58, 112), place, 14, Color(Pal.PAPER, 0.88))


func _goal_height(goals: Array) -> float:
	return 14.0 + goals.size() * 40.0


## Goals on a translucent strip at the top right: done goals fade, the current one glows.
func _goal_scroll(goals: Array) -> void:
	var h := _goal_height(goals)
	var r := Rect2(1168, 70, 240, h)
	_box(r, Color(0.02, 0.035, 0.04, 0.6), 4)
	cv.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Pal.GOLD, 0.7))
	var active_found := false
	for i in range(goals.size()):
		var y := r.position.y + 28 + i * 40
		var done: bool = goals[i].get("done", false)
		var active := not done and not active_found
		if active:
			active_found = true
		var c: Color = Pal.JADE if done else (Pal.GOLD if active else Color(0.62, 0.66, 0.62, 0.7))
		var dp := Vector2(r.position.x + 22, y - 5)
		cv.draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -6), dp + Vector2(6, 0), dp + Vector2(0, 6), dp + Vector2(-6, 0)]), c if done or active else Color(c, 0.4))
		_t(Vector2(r.position.x + 40, y), str(goals[i]["t"]), 16, Pal.PAPER if active else (Color(Pal.PAPER, 0.55) if done else Pal.MUTED))
		if done:
			cv.draw_line(Vector2(r.position.x + 40, y - 6), Vector2(r.position.x + 40 + _tw(str(goals[i]["t"]), 16), y - 6), Color(Pal.JADE, 0.6), 1)
		if active:
			_t(Vector2(r.position.x + 40, y + 17), str(goals[i].get("d", "")), 12, Pal.SOFT)


## Inventory as small lacquered plates at the bottom left.
func _inventory(items: Array, selected: String) -> void:
	var x := 40.0
	for it in items:
		var slot := Rect2(x, 806, 168, 60)
		var sel: bool = it["id"] == selected
		var hover := slot.has_point(_mouse())
		_box(slot, Color(0.03, 0.05, 0.055, 0.86 if sel or hover else 0.7), 4, Color(Pal.GOLD, 0.95 if sel else (0.6 if hover else 0.3)))
		var ic := slot.position + Vector2(30, 30 + (sin(age * 3.0) * 1.5 if sel else 0.0))
		cv.draw_circle(ic, 22, Color(0, 0, 0, 0.3))
		match it.get("icon", ""):
			"mirror":
				_img("mirror", Rect2(ic - Vector2(20, 20), Vector2(40, 40)))
			"shard":
				_shard(ic, 0.36)
			"lamp":
				_img("hand_lamp", Rect2(ic + Vector2(-20, -4), Vector2(40, 25)))
				_img("hand_flame", Rect2(ic + Vector2(-19, -23), Vector2(7, 20)))
			_:
				cv.draw_colored_polygon(PackedVector2Array([ic + Vector2(0, -9), ic + Vector2(9, 0), ic + Vector2(0, 9), ic + Vector2(-9, 0)]), Pal.GOLD)
		_serif(slot.position + Vector2(60, 27), it["name"], 17, Pal.PAPER)
		_t(slot.position + Vector2(60, 46), "已选中" if sel else it.get("sub", ""), 12, Pal.GOLD if sel else Pal.SOFT)
		_register("inv_" + str(it["id"]), slot)
		x += 178


func _shadow_text(p: Vector2, text: String, size: int, c: Color) -> void:
	_t(p + Vector2(1, 2), text, size, Color(0, 0, 0, 0.6))
	_t(p, text, size, c)


## Gold "continue" button at the bottom right of the HUD (chapter done → next stop).
func _next_button(id: String, caption: String) -> void:
	_hud(func() -> void: _button(id, Rect2(1196, 756, 212, 44), caption, true, 15))


## Screen-space modal backdrop for a scene's own panel (drawn through _hud). Registers a
## full-screen region first so clicks outside the panel never reach the scene below.
func _modal_back(k: float) -> void:
	cv.draw_rect(Rect2(0, 0, 1440, 900), Color(0.01, 0.015, 0.02, 0.72 * k))
	_register("modal_back", Rect2(0, 0, 1440, 900))


## Handles ids shared by every framed chapter. Returns true when consumed.
func _common_act(id: String) -> bool:
	match id:
		"modal_back":
			return true
		"journal":
			g.overlay.open_journal()
			return true
		"hint":
			g.hint()
			return true
	return false
