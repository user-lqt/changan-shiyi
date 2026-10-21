extends "res://scripts/core/canvas.gd"
## 第一章 · 温记镜坊
## Part A: note → mirror → stand → rotate beam → wall glyphs → three-glyph lock → shard 1.
## Part B (手灯寻片): the lights go out; search the dark room with a hand lamp whose flame
## leans toward the hidden shard. Oil drains faster when the lamp moves quickly.

const SYMBOLS := ["山", "月", "水", "日", "木", "云"]
const CasketAnimation = preload("res://scripts/data/casket_animation.gd")
const WorkshopLight = preload("res://scripts/core/workshop_light.gd")
const ANSWER := [0, 1, 2]
const MIRROR := Vector2(603, 486)
const MIRROR_SEAT := Vector2(603, 506)
const CASKET_CENTER := Vector2(1013, 479)
const CASKET_SCALE := 0.34
const TARGET := Vector2(704, 379)
const LAMP := Vector2(286, 505)
const WEN_FOOT := Vector2(800, 772)
const SPOTS := [Vector2(150, 712), Vector2(420, 700), Vector2(1010, 715), Vector2(770, 640), Vector2(240, 470), Vector2(905, 600)]
const OIL_MAX := 100.0
const MIRROR_PICKUP := Vector2(322, 543)
const MIRROR_PICKUP_AREA := Rect2(285, 518, 90, 63)
const STAND_DROP := Rect2(537, 427, 133, 190)
const CINE_LENGTH := {"place": 1.15, "return": 0.42, "reveal": 2.8, "unlock": 4.2, "wind": 3.1, "shard": 1.65}

var note_read := false
var mirror_found := false
var mirror_placed := false
var selected := ""
var angle_step := 0
var angle_vis := 0.0
var revealed := false
var beam_flash := 0.0
var dials := [5, 5, 5]
var dial_flip := [0.0, 0.0, 0.0]
var dial_previous := [5, 5, 5]
var dial_direction := [1, 1, 1]
var seal_open := false
var seal_t := 1.0
var shake := 0.0
var cabinet_open := false
var lid_t := 0.0
var shard_taken := false
var dark := false
var dark_t := 0.0
var lamp_pos := Vector2(575, 560)
var lamp_speed := 0.0
var oil := OIL_MAX
var refilling := 0.0
var hidden_at := {}           # kind -> position
var found := {}
var search_done := false
var hint_level := 0
var motes: Array[Vector3] = []
var rain: Array[Vector3] = []
var light_tex: Texture2D
var cinematic := ""
var cinematic_t := 0.0
var cinematic_marks := {}
var dragging_mirror := false
var drag_moved := false
var drag_origin := Vector2.ZERO
var drag_pos := Vector2.ZERO
var drag_from_inventory := false
var place_from := Vector2.ZERO
var return_to := Vector2.ZERO
var mirror_settle := 0.0
var pending_shard := ""
var capture_cinematic_time := -1.0
var casket_atlas: Texture2D
var casket_meta := {}
var workshop_light: Node2D


func cinematic_active() -> bool:
	return not cinematic.is_empty() or dragging_mirror


func chrome() -> bool:
	return not cinematic_active() and not seal_open


func stage_transform() -> Transform2D:
	var base := super.stage_transform()
	if cinematic.is_empty():
		return base
	var duration: float = CINE_LENGTH[cinematic]
	var envelope := smoothstep(0.0, 0.4, cinematic_t) * (1.0 - smoothstep(duration - 0.5, duration, cinematic_t))
	var zoom := 1.0
	var focus := Vector2(720, 450)
	if cinematic == "reveal":
		zoom += envelope * 1.05
		focus = focus.lerp(base * TARGET, envelope)
	elif cinematic == "place":
		zoom += envelope * 0.18
		focus = focus.lerp(base * MIRROR, envelope * 0.75)
	elif cinematic == "wind":
		zoom += envelope * 0.035
		focus += Vector2(sin(cinematic_t * 37.0), cos(cinematic_t * 29.0)) * envelope * 2.0
	focus.x = clampf(focus.x, 720.0 / zoom, 1440.0 - 720.0 / zoom)
	focus.y = clampf(focus.y, 450.0 / zoom, 900.0 - 450.0 / zoom)
	return Transform2D(0.0, Vector2(zoom, zoom), 0.0, Vector2(720, 450) - focus * zoom) * base


func _start_cinematic(kind: String) -> void:
	cinematic = kind
	cinematic_t = 0.0
	cinematic_marks.clear()
	g.overlay.toast_time = 0.0
	dragging_mirror = false
	seal_open = false


func _finish_cinematic() -> void:
	var kind := cinematic
	if kind == "place" and not cinematic_marks.has("seat"):
		g.sfx("place")
	elif kind == "unlock" and not cinematic_marks.has("unlock"):
		g.sfx("unlock")
	cinematic = ""
	cinematic_t = 0.0
	match kind:
		"place":
			mirror_placed = true
			selected = ""
			mirror_settle = 1.0
			g.notify("铜镜已落入镜台。用 A / D 或滚轮调整光线。")
		"return":
			selected = "mirror" if mirror_found else ""
		"reveal":
			beam_flash = 0.0
			g.notify("石壁三纹：山 → 月 → 水。线索已记入手札。", 6)
		"unlock":
			cabinet_open = true
			lid_t = 1.0
			g.notify("卡扣已退开。点击匣中的青瓷残片。", 5)
		"wind":
			dark = true
			dark_t = 1.0
			lamp_speed = 0.0
		"shard":
			var card := pending_shard
			pending_shard = ""
			if card == "shard":
				g.show_card("shard", func() -> void: g.say("wen_casket"))
			else:
				g.show_card("shard_b", func() -> void:
					g.say("wen_found", func() -> void:
						g.clear("ch1")
						g.notify("第一章完成。点击右下「前往西市」或打开舆图。", 8)))


func _cinematic_cue(id: String, at: float, sound: String, volume := -8.0) -> void:
	if cinematic_t >= at and not cinematic_marks.has(id):
		cinematic_marks[id] = true
		g.sfx(sound, volume)


func _tick_cinematic(delta: float) -> void:
	if cinematic.is_empty():
		return
	if capture_cinematic_time >= 0:
		cinematic_t = capture_cinematic_time
	else:
		cinematic_t += delta
	match cinematic:
		"place":
			_cinematic_cue("seat", 0.78, "place")
		"reveal":
			beam_flash = 2.0 * (1.0 - clampf(cinematic_t / 2.3, 0.0, 1.0))
			for i in range(3):
				_cinematic_cue("glyph%d" % i, 0.45 + i * 0.48, "bell", -18.0 + i * 2.0)
		"unlock":
			_cinematic_cue("align", 0.3, "dial")
			_cinematic_cue("latch_left", 0.85, "place", -11)
			_cinematic_cue("latch_right", 1.14, "dial", -10)
			_cinematic_cue("unlock", 1.45, "unlock")
			_cinematic_cue("lid", 2.1, "rotate", -9)
			_cinematic_cue("treasure", 2.85, "reveal", -13)
			lid_t = smoothstep(1.5, 3.2, cinematic_t)
		"wind":
			_cinematic_cue("gust", 0.12, "wind", -10)
			_cinematic_cue("out", 1.1, "error", -17)
			_cinematic_cue("roll", 1.7, "dial", -15)
			dark_t = smoothstep(0.6, 1.7, cinematic_t)
			dark = cinematic_t >= 1.2
	if capture_cinematic_time < 0 and cinematic_t >= float(CINE_LENGTH[cinematic]):
		_finish_cinematic()


func enter() -> void:
	casket_atlas = load("res://assets/images/ch1_casket/opening-atlas.png") as Texture2D
	casket_meta = CasketAnimation.DATA
	workshop_light = WorkshopLight.new()
	add_child(workshop_light)
	g.music("ambient")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	for i in range(42):
		motes.append(Vector3(rng.randf_range(0, 1074), rng.randf_range(0, 604), rng.randf_range(0.4, 1.6)))
	for i in range(140):
		rain.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4)))
	light_tex = _make_light()
	_place_hidden(int(Time.get_ticks_usec()) if not g.test_mode else 7)
	if g.cleared.has("ch1"):
		g.notify("重玩第一章：碎片已在行囊中，可以随意探索。")
	g.say("wen_meet")


func _place_hidden(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var order: Array = range(SPOTS.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	hidden_at = {"shard": SPOTS[order[0]], "coin": SPOTS[order[1]], "cat": SPOTS[order[2]]}


## Radial light mask: transparent centre fading to opaque black at the rim.
func _make_light() -> Texture2D:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length() / (size * 0.5)
			var a := clampf((d - 0.35) / 0.65, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.01, 0.015, 0.02, a * a * (3.0 - 2.0 * a)))
	return ImageTexture.create_from_image(img)


func staged() -> bool:
	return true


func story_event(name: String) -> void:
	if name == "lights_out":
		_start_cinematic("wind")


func help_lines() -> Array:
	if dark:
		return ["移动鼠标照亮四周，火苗会朝碎片的方向偏。", "只有被灯照亮的东西才能点击。", "移动越快，灯油消耗越快；灯油耗尽时温师傅会帮你添油。"]
	return ["点击发光标记：调查、拾取或操作物件；点击温师傅可以交谈。", "按住桌边铜镜或行囊铜镜，拖到镜台后松手；也可点选后点击镜台。", "铜镜安放后，用 A / D、滚轮或按钮旋转。", "三纹锁：点击纹样或按 1 2 3 切换，Enter 尝试开启。", "剧情演出开始后，可按空格或 Enter 跳过；拖动时 Esc 取消。"]


func journal_lines() -> Array:
	var out := []
	if note_read:
		out.append("温师傅手记：灯不移，镜可转。引光照石上三纹，循其先后，旧匣自开。")
	if revealed:
		out.append("石壁纹样：山 → 月 → 水。")
	if dark:
		out.append("灯火熄灭。第二片碎瓷滚进了暗处，火苗会指向它。")
	if out.is_empty():
		out.append("先和温师傅谈谈，再看看案上的手记。")
	return out


func hint() -> String:
	hint_level += 1
	if dark and not search_done:
		return "看火苗偏向哪边，就往哪边移动。靠得越近，偏得越厉害。" + ("碎片在 %s。" % _area_name(hidden_at["shard"]) if hint_level > 3 else "")
	if not note_read:
		return "看看左侧案上的手记。"
	if not mirror_found:
		return "桌边那面小铜镜在闪光，拾起它。"
	if not mirror_placed:
		return "把桌边或行囊里的铜镜拖到画面中央的空镜台，松手安放。"
	if not revealed:
		return "光应落在右上方圆盘。" + ("从最初角度向右转四次。" if hint_level > 2 else "试着慢慢向右转动镜片。")
	if not cabinet_open:
		return "按从左到右的顺序：山 → 月 → 水，调整旧匣上的三枚纹样。"
	return "旧匣已经打开。点击匣中的青瓷残片。"


func _area_name(p: Vector2) -> String:
	if p.x < 330:
		return "左侧工作台附近"
	if p.x < 640:
		return "画面中间偏左的地上"
	if p.x < 880:
		return "镜台右边"
	return "右侧旧匣附近"


# ------------------------------------------------------------------ update
func tick(delta: float, blocked: bool) -> void:
	var was_cinematic := not cinematic.is_empty()
	_tick_cinematic(delta)
	mirror_settle = maxf(0.0, mirror_settle - delta * 1.8)
	beam_flash = maxf(0.0, beam_flash - delta)
	seal_t = minf(1.0, seal_t + delta * 5.0)
	shake = maxf(0.0, shake - delta * 2.5)
	if cinematic != "unlock":
		lid_t = move_toward(lid_t, 1.0 if cabinet_open else 0.0, delta * 1.4)
	angle_vis = lerpf(angle_vis, float(angle_step), minf(1.0, delta * 12.0))
	for i in range(3):
		dial_flip[i] = maxf(0.0, float(dial_flip[i]) - delta * 4.0)
	if dark and cinematic != "wind":
		dark_t = minf(1.0, dark_t + delta * 1.5)
	if dark and not search_done and not blocked and not cinematic_active() and not was_cinematic:
		if refilling > 0:
			refilling -= delta
			if refilling <= 0:
				oil = OIL_MAX
				g.notify("温师傅给手灯添了油。慢一点移动，省着用。")
		else:
			oil -= delta * (2.2 + lamp_speed * 0.012)
			if oil <= 0:
				oil = 0
				refilling = 2.5
				g.stats["lamp_refills"] = int(g.stats["lamp_refills"]) + 1
				g.notify("灯油耗尽了……温师傅：「别急，老朽给你添上。」")
	lamp_speed = lerpf(lamp_speed, 0.0, minf(1.0, delta * 6.0))


func light_radius() -> float:
	if refilling > 0:
		return 26.0
	return lerpf(55.0, 135.0, clampf(oil / OIL_MAX, 0.0, 1.0)) + sin(age * 9.0) * 2.5


func mouse(event: InputEvent) -> bool:
	if not cinematic.is_empty():
		return true
	if dragging_mirror:
		if event is InputEventMouseMotion:
			drag_pos = event.position
			drag_moved = drag_moved or drag_pos.distance_to(drag_origin) > 8.0
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			drag_pos = event.position
			dragging_mirror = false
			g.mouse_default_cursor_shape = Control.CURSOR_ARROW
			if STAND_DROP.has_point(drag_pos):
				_begin_place(drag_pos)
			elif not drag_moved:
				if drag_from_inventory:
					selected = "" if selected == "mirror" else "mirror"
				else:
					act("pickup")
			else:
				_return_mirror()
		return true
	if not seal_open and not dark and not mirror_found and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and MIRROR_PICKUP_AREA.has_point(event.position) and screen_ready():
		_begin_drag(event.position, false)
		return true
	if event is InputEventMouseMotion:
		var p: Vector2 = event.position
		if bleed().has_point(p):
			lamp_speed = maxf(lamp_speed, event.relative.length() / maxf(get_process_delta_time(), 0.001) if event.relative.length() > 0 else 0.0)
			lamp_pos = p
		return false
	if event is InputEventMouseButton and event.pressed and not seal_open and screen_ready():
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and mirror_placed and not revealed and not dark:
			_turn(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			return true
	return false


func hud_mouse(event: InputEvent) -> bool:
	if dragging_mirror or not cinematic.is_empty():
		return mouse(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and mirror_found and not mirror_placed and not seal_open and screen_ready():
		if hud_hit(to_screen(event.position)) == "inv_mirror":
			_begin_drag(event.position, true)
			return true
	return false


func _begin_drag(p: Vector2, from_inventory: bool) -> void:
	dragging_mirror = true
	drag_moved = false
	drag_origin = p
	drag_pos = p
	drag_from_inventory = from_inventory
	g.mouse_default_cursor_shape = Control.CURSOR_DRAG
	g.sfx("rotate", -14)


func _begin_place(from: Vector2) -> void:
	mirror_found = true
	if not g.collected.has("mirror"):
		g.collected.append("mirror")
		g._save_progress()
	place_from = from
	angle_vis = float(angle_step)
	_start_cinematic("place")


func _return_mirror() -> void:
	g.mouse_default_cursor_shape = Control.CURSOR_ARROW
	place_from = drag_pos
	return_to = to_stage(Vector2(70, 836)) if drag_from_inventory else MIRROR_PICKUP
	_start_cinematic("return")


func screen_ready() -> bool:
	return not g.blocked() and not cinematic_active()


func key(event: InputEventKey) -> bool:
	if dragging_mirror:
		if event.keycode == KEY_ESCAPE:
			_return_mirror()
		return true
	if not cinematic.is_empty():
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and cinematic_t > 0.45:
			_finish_cinematic()
		return true
	if seal_open:
		match event.keycode:
			KEY_1, KEY_2, KEY_3:
				act("dial_%d" % (event.keycode - KEY_1))
			KEY_ENTER, KEY_SPACE, KEY_KP_ENTER:
				act("check")
			KEY_ESCAPE:
				act("seal_close")
		return true
	if event.keycode in [KEY_A, KEY_LEFT] and mirror_placed and not dark:
		_turn(-1)
		return true
	if event.keycode in [KEY_D, KEY_RIGHT] and mirror_placed and not dark:
		_turn(1)
		return true
	return false


# ------------------------------------------------------------------ actions
func act(id: String) -> void:
	if cinematic_active():
		return
	if _common_act(id):
		return
	match id:
		"wen":
			_talk_wen()
		"note":
			note_read = true
			g.sfx("note")
			g.dlg.start_lines([
				{"w": "narr", "t": "手记上是温师傅工整的小楷：\n「灯不移，镜可转。引一线明光，照石上三纹；循其先后，旧匣自开。」"},
			])
		"pickup":
			if not mirror_found:
				mirror_found = true
				selected = "mirror"
				g.show_card("mirror")
		"inv_mirror":
			selected = "" if selected == "mirror" else "mirror"
		"inv_lamp":
			g.notify("手灯会跟着鼠标移动。火苗偏向哪里，碎片就在哪里。")
		"stand":
			if not mirror_found:
				g.notify("镜台空着。也许附近能找到合适的铜镜。")
			elif selected != "mirror":
				g.notify("先点击行囊中的铜镜，再将它安放在这里。")
			else:
				_begin_place(to_stage(Vector2(70, 836)))
		"turn_left":
			_turn(-1)
		"turn_right":
			_turn(1)
		"mural":
			if revealed:
				g.overlay.open_journal()
			else:
				g.notify("石壁上有浅浅刻痕。也许需要更准确的一束光。")
		"chest":
			if cabinet_open and not shard_taken:
				_take_casket_shard()
			elif not cabinet_open:
				seal_open = true
				seal_t = 0.0
		"seal_close":
			seal_open = false
		"check":
			_check_seal()
		"found_shard", "found_coin", "found_cat":
			_found(id.trim_prefix("found_"))
		"to_map":
			g.go("map")
		_:
			if id.begins_with("dial_"):
				var i := int(id.trim_prefix("dial_"))
				_cycle_dial(i, 1)
			elif id.begins_with("back_"):
				var i := int(id.trim_prefix("back_"))
				_cycle_dial(i, -1)


func _cycle_dial(i: int, direction: int) -> void:
	if i < 0 or i >= 3:
		return
	dial_previous[i] = int(dials[i])
	dial_direction[i] = direction
	dials[i] = posmod(int(dials[i]) + direction, 6)
	dial_flip[i] = 1.0
	g.sfx("dial")


func _talk_wen() -> void:
	var line := "你走近些，让老朽看看。"
	if dark and not search_done:
		line = "老朽眼睛不行，就靠你了。看火苗，它比人机灵。"
	elif search_done:
		line = "去西市吧。小心那个康掌柜，他话里十句有三句是虚的。"
	elif cabinet_open:
		line = "匣里那片碎瓷，快取出来看看。"
	elif revealed:
		line = "石上三纹……先师总说，山月水，是他一辈子走过的路。"
	elif mirror_placed:
		line = "镜子要慢慢转。光是有脾气的，急不得。"
	elif mirror_found:
		line = "那面小镜子，就安在中间的空镜台上。"
	g.dlg.start_lines([{"w": "wen", "t": line}])


func _turn(direction: int) -> void:
	if not mirror_placed or revealed or cinematic_active():
		return
	angle_step = posmod(angle_step + direction, 11)
	g.sfx("rotate")
	var ray := _outgoing()
	var along := (TARGET - MIRROR).dot(ray)
	var closest := MIRROR + ray * maxf(0, along)
	if along > 0 and closest.distance_to(TARGET) < 29:
		revealed = true
		beam_flash = 2.0
		_start_cinematic("reveal")
		g.sfx("reveal")
		g.narrate("revealed")


func _check_seal() -> void:
	if cinematic_active() or cabinet_open:
		return
	if not revealed:
		g.notify("先让石壁纹样显现，找到开启旧匣的依据。")
		g.sfx("error")
		shake = 1.0
		return
	if dials == ANSWER:
		lid_t = 0.0
		_start_cinematic("unlock")
	else:
		g.notify("纹样尚未吻合。按石壁从左到右的顺序再试一次。")
		g.sfx("error")
		shake = 1.0


func _take_casket_shard() -> void:
	shard_taken = true
	g.get_shard(0)
	g.sfx("win")
	pending_shard = "shard"
	_start_cinematic("shard")


func _found(kind: String) -> void:
	if found.has(kind):
		return
	found[kind] = true
	match kind:
		"shard":
			search_done = true
			g.get_shard(1)
			g.sfx("reveal")
			pending_shard = "shard_b"
			_start_cinematic("shard")
		"coin":
			g.sfx("pickup")
			g.show_card("coin")
		"cat":
			g.sfx("error", -12)
			g.show_card("cat")


func _outgoing(step: float = -1.0) -> Vector2:
	var s := float(angle_step) if step < 0.0 else step
	return Vector2.from_angle(deg_to_rad(-110.0 + s * 15.0))


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	hit_regions.clear()
	var goals := [
		{"t": "寻镜", "d": "读手记，找到铜镜", "done": mirror_found and note_read},
		{"t": "借光", "d": "安放铜镜，照亮石壁", "done": revealed},
		{"t": "解匣", "d": "按纹样顺序打开旧匣", "done": shard_taken},
		{"t": "寻片", "d": "在黑暗中找到第二片", "done": search_done},
	]
	var items := []
	if mirror_found and not mirror_placed:
		items.append({"id": "mirror", "name": "铜镜", "icon": "mirror", "sub": "按住拖到镜台"})
	if dark and not search_done:
		items.append({"id": "lamp", "name": "手灯", "icon": "lamp", "sub": "灯油 %d%%" % int(oil)})
	_frame("第一章  ·  借光", "温记镜坊  /  戌时 · 微雨", goals, _objective(), items, selected)
	_draw_room()
	if cinematic == "wind":
		_draw_wind()
	if dark or cinematic == "wind":
		_draw_darkness()
	if dragging_mirror or cinematic in ["place", "return"]:
		_draw_moving_mirror()
	if seal_open:
		_hud(_draw_seal)
	if g.cleared.has("ch1") and search_done:
		_next_button("to_map", "前往西市  ›")


func _objective() -> String:
	if dark and not search_done:
		return "移动手灯，跟着火苗的方向找到第二片碎瓷。"
	if search_done:
		return "第一章完成。两片碎瓷已收入行囊。"
	if not note_read:
		return "点击场景标记，先看看温师傅的手记。"
	if not mirror_found:
		return "找到桌边的小铜镜。"
	if not mirror_placed:
		return "把铜镜拖到中央镜台，松手安放；也可点选后点击镜台。"
	if not revealed:
		return "A / D 或滚轮转镜，将光束引向石壁圆盘。"
	if not cabinet_open:
		return "记住石壁纹样，解开右侧旧匣。"
	return "旧匣已开启，点击取出青瓷残片。"


func _draw_room() -> void:
	if not _img_cover("ch1_workshop_open" if lid_t > 0.0 else "workshop", ROOM):
		draw_rect(bleed(), Color("293c3a"))
	for i in range(15):
		draw_rect(Rect2(bleed().position + Vector2(0, i * 9), Vector2(bleed().size.x, 9)), Color(0.02, 0.05, 0.05, 0.014 + i * 0.001))
	var win := Rect2(132, 214, 130, 186)
	for d in rain:
		var y := fmod(d.y + age * 0.9 * d.z, 1.0)
		var top := win.position + Vector2(d.x * win.size.x, y * win.size.y)
		var bottom := top + Vector2(-2.5, 11.0 * d.z)
		if bottom.y < win.end.y:
			draw_line(top, bottom, Color(0.75, 0.86, 0.9, 0.16 * d.z), 1.0, true)
	if dark_t < 1.0:
		for i in range(2):
			var lp: Vector2 = [Vector2(420, 238), Vector2(1057, 439)][i]
			var flick := 0.5 + 0.5 * sin(age * (3.1 + i) + i * 2.0) * sin(age * 7.3 + i)
			for r in range(6, 0, -1):
				draw_circle(lp, r * 9, Color(1, 0.7, 0.3, (0.005 + flick * 0.004) * (1.0 - dark_t)))
		for r in range(9, 0, -1):
			draw_circle(LAMP, r * 7, Color(1, 0.66, 0.24, 0.006))
		draw_circle(LAMP, 7 + sin(age * 5) * 0.8, Color("ffe7a3"))
	for m in motes:
		var p := bleed().position + Vector2(fmod(m.x + age * 5.0 * m.z, bleed().size.x), fmod(m.y - age * 4.0 * m.z + 2000.0, bleed().size.y))
		draw_circle(p, m.z * 0.9, Color(1, 0.84, 0.57, 0.11 + sin(age * 0.4 + m.x) * 0.06))
	_draw_stand()
	_draw_mural()
	_draw_casket()
	_draw_handbook()
	if mirror_placed and not dark:
		_draw_beam()
	else:
		workshop_light.visible = false
	if not mirror_found and not dragging_mirror and cinematic not in ["place", "return"]:
		var a := MIRROR_PICKUP
		# A low ellipse and contact shadow make the loose mirror lie on the table.
		draw_set_transform(a + Vector2(1, 4), -0.12, Vector2(1.0, 0.34))
		draw_circle(Vector2.ZERO, 25, Color(0.07, 0.04, 0.02, 0.56))
		draw_set_transform(a, -0.12, Vector2(1.0, 0.39))
		_img("mirror", Rect2(-25, -25, 50, 50), Color(0.94, 0.86, 0.71))
		draw_arc(Vector2.ZERO, 24, -2.9, -0.5, 32, Color(1.0, 0.80, 0.42, 0.48), 1.0, true)
		draw_set_transform(Vector2.ZERO)
	# Hidden objects are always drawn; darkness hides them until the lamp reaches them.
	if dark:
		if not found.has("shard"):
			_shard(hidden_at["shard"], 0.32 + sin(age * 3) * 0.01)
		if not found.has("coin"):
			draw_circle(hidden_at["coin"], 9, Color("b08a3e"))
			draw_rect(Rect2(hidden_at["coin"] - Vector2(3, 3), Vector2(6, 6)), Color("3a2a12"))
		if not found.has("cat"):
			for s in [-9, 9]:
				draw_circle(hidden_at["cat"] + Vector2(s, 0), 4, Color(0.9, 1.0, 0.5, 0.9))
	# While Wen speaks his portrait is shown by the dialogue box, so the in-scene figure steps back.
	var talking: bool = g.dlg.active and g.dlg.entry().get("w", "") == "wen"
	if not talking:
		_figure("npc_wen", WEN_FOOT, 330, Color(1, 1, 1, 1.0 - dark_t * 0.75))
	if g.blocked() or seal_open or cinematic_active():
		return
	_hotspot("wen", WEN_FOOT + Vector2(0, -350), "温师傅", Rect2(WEN_FOOT + Vector2(-60, -330), Vector2(120, 330)))
	if dark:
		for kind in hidden_at:
			if not found.has(kind) and lamp_pos.distance_to(hidden_at[kind]) < light_radius() * 0.75:
				_register("found_" + kind, Rect2(hidden_at[kind] - Vector2(34, 34), Vector2(68, 68)))
		return
	_hotspot("note", Vector2(219, 549), "案上手记", Rect2(170, 532, 113, 90), note_read)
	if not mirror_found:
		_hotspot("pickup", MIRROR_PICKUP + Vector2(0, -19), "拾起铜镜", MIRROR_PICKUP_AREA)
	if not mirror_placed:
		_hotspot("stand", MIRROR + Vector2(0, 20), "空镜台", Rect2(552, 465, 100, 176))
	elif not revealed:
		_hud(_draw_turn_controls)
	_hotspot("mural", TARGET + Vector2(0, -70), "显影石壁" if not revealed else "纹样 · 山 月 水", Rect2(TARGET - Vector2(81, 76), Vector2(163, 155)))
	if not shard_taken:
		_hotspot("chest", Vector2(984, 475), "开启旧匣" if not cabinet_open else "取得残片", Rect2(888, 464, 178, 183))


func _draw_turn_controls() -> void:
	var r := Rect2(560, 742, 320, 64)
	_box(r, Color(0.02, 0.03, 0.035, 0.7), 32)
	_button("turn_left", Rect2(r.position + Vector2(10, 12), Vector2(92, 40)), "‹  A", false, 15)
	_button("turn_right", Rect2(r.end - Vector2(102, 52), Vector2(92, 40)), "D  ›", false, 15)
	_tc(r.get_center().x, r.position.y + 30, "转动铜镜", 13, Pal.MUTED)
	_tc(r.get_center().x, r.position.y + 52, "%d°" % ((angle_step - 4) * 15), 17, Pal.GOLD)


func _draw_darkness() -> void:
	if cinematic == "wind" and cinematic_t < 2.15:
		draw_rect(bleed(), Color(0.01, 0.015, 0.02, 0.97 * dark_t))
		return
	var r := light_radius() * 1.6
	if cinematic == "wind":
		r *= lerpf(0.1, 1.0, smoothstep(2.15, 2.9, cinematic_t))
	var a := dark_t
	var lp := lamp_pos
	var light := Rect2(lp - Vector2(r, r), Vector2(r, r) * 2.0)
	var B := bleed()
	var clip := light.intersection(B)
	var shade := Color(0.01, 0.015, 0.02, 0.97 * a)
	# Four rectangles around the light square, then the radial mask inside it.
	draw_rect(Rect2(B.position, Vector2(B.size.x, maxf(0, clip.position.y - B.position.y))), shade)
	draw_rect(Rect2(Vector2(B.position.x, clip.end.y), Vector2(B.size.x, maxf(0, B.end.y - clip.end.y))), shade)
	draw_rect(Rect2(Vector2(B.position.x, clip.position.y), Vector2(maxf(0, clip.position.x - B.position.x), clip.size.y)), shade)
	draw_rect(Rect2(Vector2(clip.end.x, clip.position.y), Vector2(maxf(0, B.end.x - clip.end.x), clip.size.y)), shade)
	if clip.size.x > 0 and clip.size.y > 0:
		var ts := light_tex.get_size()
		var src := Rect2((clip.position - light.position) / light.size * ts, clip.size / light.size * ts)
		draw_texture_rect_region(light_tex, clip, src, Color(1, 1, 1, 0.97 * a))
		for i in range(4):
			draw_circle(lp, light_radius() * (0.25 + i * 0.12), Color(1, 0.7, 0.3, 0.02 * a))
	if search_done:
		return
	# Hand lamp with a flame that leans toward the shard.
	var to_shard: Vector2 = hidden_at["shard"] - lp
	var dist := to_shard.length()
	var lean := clampf(1.0 - dist / 700.0, 0.15, 1.0)
	var dir := to_shard.normalized() if dist > 1 else Vector2.UP
	var base := lp + Vector2(0, 15)
	_img("hand_lamp", Rect2(base + Vector2(-26, -3), Vector2(52, 33)))
	var wick := base + Vector2(-22, -2)
	var flame_height := 24.0 * (1.0 + sin(age * 13.0) * 0.06)
	var bend := Vector2.UP.lerp((Vector2.UP * 0.7 + dir * lean).normalized(), 0.65)
	draw_set_transform(wick, Vector2.UP.angle_to(bend))
	_img("hand_flame", Rect2(-4, -flame_height, 8, flame_height))
	draw_set_transform(Vector2.ZERO)
	_hud(_draw_oil)
	if dist < light_radius() * 0.75:
		_tc(lp.x, lp.y - light_radius() * 0.8, "有东西在闪光", 13, Pal.GOLD)


func _draw_oil() -> void:
	var gauge := Rect2(40, 150, 220, 8)
	_box(gauge.grow(4), Color(0.02, 0.03, 0.035, 0.75), 6)
	cv.draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * oil / OIL_MAX, gauge.size.y)), Color("d7a350") if oil > 25 else Pal.RED)
	_t(gauge.position + Vector2(232, 9), "灯油" if refilling <= 0 else "添油中…", 13, Pal.PAPER)


func _draw_stand() -> void:
	if mirror_placed:
		var incoming := (MIRROR - LAMP).normalized()
		var normal := (incoming - _outgoing(angle_vis)).normalized()
		var tangent := Vector2(-normal.y, normal.x)
		# The fork is anchored to the painted tray; its arms meet the mirror rim.
		draw_set_transform(MIRROR_SEAT + Vector2(0, 1), 0, Vector2(1, 0.23))
		draw_circle(Vector2.ZERO, 21, Color(0.05, 0.04, 0.02, 0.42))
		draw_set_transform(Vector2.ZERO)
		draw_line(MIRROR_SEAT, MIRROR + Vector2(0, 5), Color("57462c"), 5.0, true)
		draw_line(MIRROR_SEAT + Vector2(-10, -1), MIRROR + Vector2(-11, 9), Color("aa9055"), 2.6, true)
		draw_line(MIRROR_SEAT + Vector2(10, -1), MIRROR + Vector2(11, 9), Color("aa9055"), 2.6, true)
		_draw_mirror_sprite(MIRROR, 62.0, tangent.angle() + PI * 0.5, 0.40, true)
		if mirror_settle > 0:
			draw_arc(MIRROR, 34 + (1.0 - mirror_settle) * 30, 0, TAU, 56, Color(Pal.GOLD, mirror_settle * 0.65), 1.5, true)
	else:
		var active := dragging_mirror or selected == "mirror"
		var near := dragging_mirror and STAND_DROP.has_point(drag_pos)
		var pulse := 0.6 + sin(age * 4.0) * 0.15
		if active:
			for i in range(5, 0, -1):
				draw_circle(MIRROR, 30 + i * 7, Color(Pal.JADE if near else Pal.GOLD, pulse * 0.025))
		draw_arc(MIRROR, 29, 0, TAU, 48, Color(Pal.JADE if near else Pal.GOLD, 0.9 if active else 0.35), 2, true)
		if active:
			_tc(MIRROR.x, MIRROR.y + 57, "松手安放" if near else "拖到此处", 14, Pal.JADE if near else Pal.GOLD)


func _draw_mural() -> void:
	draw_circle(TARGET, 65, Color(0.06, 0.09, 0.08, 0.2 if revealed else 0.08))
	draw_arc(TARGET, 58, 0, TAU, 64, Color(0.8, 0.7, 0.45, 0.6 if revealed else 0.18), 1.5, true)
	if revealed:
		var k := 1.0 - beam_flash / 2.0 if beam_flash > 0 else 1.0
		for i in range(3):
			var a := clampf(k * 3.0 - i * 0.8, 0.0, 1.0)
			_glyph(TARGET + Vector2((i - 1) * 35, (1.0 - a) * 6), i, 13, Color(0.96, 0.84, 0.6, a))
	else:
		_glyph(TARGET, 1, 24, Color(0.85, 0.8, 0.62, 0.16))


func _draw_casket() -> void:
	if lid_t > 0.0:
		_draw_casket_art(CASKET_CENTER, CASKET_SCALE, lid_t, 1.0, not shard_taken)
	else:
		# Cut into the front board, with dark recesses and slim worn brass edges.
		draw_set_transform_matrix(Transform2D(Vector2(1.0, -0.035), Vector2(0, 1), Vector2(958, 491)))
		var channel := Rect2(-2, -2, 73, 37)
		draw_rect(channel, Color(0.12, 0.075, 0.035, 0.85))
		draw_line(channel.position, Vector2(channel.end.x, channel.position.y), Color(0.025, 0.018, 0.012, 0.9), 1.8, true)
		draw_line(Vector2(channel.position.x, channel.end.y), channel.end, Color(0.66, 0.49, 0.24, 0.30), 0.7, true)
		for i in range(3):
			var flip := float(dial_flip[i])
			var x := 11.0 + i * 23
			_box(Rect2(x - 9.5, 1, 19, 30), Color("191b13"), 1, Color("655331"), 0.7)
			draw_rect(Rect2(x - 7.8, 3, 15.6, 26), Color("3e3a25"))
			draw_line(Vector2(x - 7.8, 3), Vector2(x + 7.8, 3), Color(0, 0, 0, 0.7), 2.4, true)
			draw_line(Vector2(x - 7.8, 4), Vector2(x - 7.8, 27), Color(0, 0, 0, 0.48), 1.4, true)
			draw_line(Vector2(x - 7.0, 29), Vector2(x + 7.0, 29), Color(0.72, 0.58, 0.32, 0.38), 0.7, true)
			if flip < 0.5:
				_glyph(Vector2(x + 0.6, 16.6), int(dials[i]), 5.3, Color(0.04, 0.035, 0.02, 0.95))
				_glyph(Vector2(x, 16), int(dials[i]), 5.3, Color("b19a62"))
		draw_set_transform(Vector2.ZERO)


func _draw_handbook(lift := 0.0) -> void:
	# A page's four corners follow the table's perspective rather than a flat UI card.
	var corners := PackedVector2Array([Vector2(163, 551), Vector2(230, 536), Vector2(279, 553 - lift), Vector2(195, 576)])
	var shadow := PackedVector2Array()
	for point in corners:
		shadow.append(point + Vector2(1.5, 3.0))
	draw_colored_polygon(shadow, Color(0.07, 0.04, 0.02, 0.48))
	if g.tex.has("ch1_handbook"):
		draw_polygon(corners, PackedColorArray([Color(0.92, 0.83, 0.65)]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), g.tex["ch1_handbook"])


## Blender-baked poses keep the hinge, lid thickness and cavity in real perspective.
## The same final frame remains in the workshop after the close-up returns.
func _draw_casket_art(center: Vector2, size: float, opening: float, _latch: float, show_shard: bool) -> void:
	if casket_atlas == null or casket_meta.is_empty():
		return
	var frame_count: int = int(casket_meta["frame_count"])
	var duration: float = float(casket_meta["duration"])
	var pose_time := cinematic_t if cinematic == "unlock" else duration * opening
	var frame := clampi(roundi(pose_time / duration * (frame_count - 1)), 0, frame_count - 1)
	var columns: int = int(casket_meta["columns"])
	var cell := Vector2(float(casket_meta["cell"][0]), float(casket_meta["cell"][1]))
	var crop := Vector2(float(casket_meta["crop"][0]), float(casket_meta["crop"][1]))
	var origin := Vector2(float(casket_meta["origin"][0]), float(casket_meta["origin"][1]))
	var source := Rect2(Vector2(frame % columns, floori(float(frame) / columns)) * cell, cell)
	cv.draw_set_transform(center, 0.0, Vector2(size, size))
	cv.draw_texture_rect_region(casket_atlas, Rect2(crop - origin, cell), source, Color(0.87, 0.80, 0.66))
	if show_shard and opening > 0.45:
		var glow := smoothstep(0.45, 0.97, opening)
		var anchor := Vector2(float(casket_meta["shard_anchor"][0]), float(casket_meta["shard_anchor"][1])) - origin
		anchor.y -= glow * 40.0
		anchor.y += sin(age * 1.5) * 2.0 * glow
		for i in range(9, 0, -1):
			cv.draw_circle(anchor, 12 + i * 8, Color(0.55, 0.9, 0.72, 0.014 * glow))
		_shard(anchor, 0.94 * glow, Color(1, 1, 1, glow))
		for i in range(10):
			var phase := fmod(age * 0.28 + i * 0.1, 1.0)
			cv.draw_circle(anchor + Vector2(sin(i * 2.7) * 58, 30 - phase * 90), 1.4, Color(0.75, 1, 0.87, sin(phase * PI) * glow * 0.5))
	cv.draw_set_transform(Vector2.ZERO)


func _draw_beam() -> void:
	var dir := _outgoing(angle_vis)
	var end := TARGET if revealed else _ray_end(MIRROR, dir)
	workshop_light.illuminate(LAMP, MIRROR, end, 0.96 * (1.0 - dark_t), age, revealed)
	if not revealed:
		var along := (TARGET - MIRROR).dot(dir)
		var miss := (MIRROR + dir * maxf(0, along)).distance_to(TARGET)
		if along > 0 and miss < 105:
			# A diffuse response in the stone replaces the bright target-outline ring.
			var halo: Texture2D = WorkshopLight.HALO
			draw_texture_rect(halo, Rect2(TARGET - Vector2(53, 66), Vector2(106, 132)), false, Color(1.0, 0.75, 0.38, (1.0 - miss / 105.0) * 0.10))
	if beam_flash > 0:
		var halo: Texture2D = WorkshopLight.HALO
		var radius := 60 + (2.0 - beam_flash) * 18
		draw_texture_rect(halo, Rect2(TARGET - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color(1, 0.85, 0.50, beam_flash * 0.10))


func _ray_end(start: Vector2, direction: Vector2) -> Vector2:
	var distance := 2000.0
	if direction.x > 0.001:
		distance = minf(distance, (bleed().end.x - 3 - start.x) / direction.x)
	elif direction.x < -0.001:
		distance = minf(distance, (bleed().position.x + 3 - start.x) / direction.x)
	if direction.y > 0.001:
		distance = minf(distance, (bleed().end.y - 3 - start.y) / direction.y)
	elif direction.y < -0.001:
		distance = minf(distance, (bleed().position.y + 3 - start.y) / direction.y)
	return start + direction * distance


func _draw_mirror_sprite(p: Vector2, diameter: float, rotation: float, squash := 1.0, polished := false) -> void:
	draw_set_transform(p + Vector2(0, diameter * 0.46), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, diameter * 0.46, Color(0, 0, 0, 0.22))
	draw_set_transform(p, rotation, Vector2(squash, 1.0))
	_img("ch1_mirror_face" if polished else "mirror", Rect2(-diameter * 0.5, -diameter * 0.5, diameter, diameter))
	draw_arc(Vector2.ZERO, diameter * 0.48, -2.9, -0.6, 36, Color(1.0, 0.88, 0.55, 0.65), 1.8, true)
	draw_set_transform(Vector2.ZERO)


func _moving_mirror_position() -> Vector2:
	if dragging_mirror:
		return drag_pos
	if cinematic == "return":
		return place_from.lerp(return_to, smoothstep(0.0, 0.42, cinematic_t))
	var approach := smoothstep(0.0, 0.64, cinematic_t)
	var seat := smoothstep(0.64, 0.9, cinematic_t)
	var p := place_from.lerp(MIRROR + Vector2(0, -24), approach)
	p.y -= sin(approach * PI) * 32.0
	p.y += seat * 24.0
	p.y += sin(maxf(0.0, cinematic_t - 0.83) * 32) * exp(-maxf(0.0, cinematic_t - 0.83) * 16) * 3.5 * seat
	return p


func _draw_moving_mirror() -> void:
	var p := _moving_mirror_position()
	if dragging_mirror:
		var ray := MIRROR - p
		for i in range(14):
			var k := i / 14.0
			var a := p.lerp(MIRROR, k) - Vector2(0, sin(k * PI) * 28)
			var b := p.lerp(MIRROR, k + 0.035) - Vector2(0, sin((k + 0.035) * PI) * 28)
			if ray.length() > 85:
				draw_line(a, b, Color(Pal.GOLD, 0.36), 1.3, true)
	var align := smoothstep(0.35, 0.88, cinematic_t) if cinematic == "place" else 0.0
	var incoming := (MIRROR - LAMP).normalized()
	var normal := (incoming - _outgoing()).normalized()
	var tangent := Vector2(-normal.y, normal.x)
	var tilt := lerp_angle(-0.2, tangent.angle() + PI * 0.5, align)
	if not dragging_mirror:
		_draw_mirror_sprite(p, lerpf(60.0, 62.0, align), tilt, lerpf(1.0, 0.40, align), align > 0.5)
	if cinematic == "place" and cinematic_t > 0.78:
		var pulse := clampf((cinematic_t - 0.78) / 0.37, 0, 1)
		draw_arc(MIRROR, 30 + pulse * 38, 0, TAU, 64, Color(Pal.GOLD, (1.0 - pulse) * 0.85), 1.6, true)


func _draw_wind() -> void:
	var strength := smoothstep(0.0, 0.45, cinematic_t) * (1.0 - smoothstep(1.45, 2.2, cinematic_t))
	for i in range(17):
		var path := PackedVector2Array()
		var x := fmod(cinematic_t * (620 + i * 17) + i * 83, 1470) - 180
		var y := 240.0 + i * 24.0
		for j in range(18):
			path.append(Vector2(x + j * 9, y + sin(j * 0.2 + i) * (8 + i % 3 * 4)))
		draw_polyline(path, Color(0.8, 0.86, 0.79, strength * (0.035 + i % 3 * 0.018)), 1.3, true)
	# A loose paper corner lifts and settles as the gust crosses the worktable.
	var lift := sin(clampf(cinematic_t / 1.65, 0.0, 1.0) * PI) * 21
	_draw_handbook(lift * 0.30)


func draw_hud(target: CanvasItem) -> void:
	if not cinematic_active():
		super.draw_hud(target)
		return
	hud_regions.clear()
	if dragging_mirror:
		super.draw_hud(target)
		# Screen-space copy keeps the held object visible even above the inventory strip.
		cv = target
		var p := to_screen(drag_pos)
		_img("mirror", Rect2(p - Vector2(40, 40), Vector2(80, 80)))
		cv = self
		return
	cv = target
	hud_mode = true
	var t := cinematic_t
	var duration: float = CINE_LENGTH[cinematic]
	var envelope := smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(duration - 0.28, duration, t))
	if cinematic in ["return", "place"]:
		if cinematic == "place":
			_box(Rect2(570, 760, 300, 43), Color(0.02, 0.035, 0.03, 0.8 * envelope), 22)
			_title_center(720, 789, "安镜入座 · 借灯引光", 24, Color(Pal.GOLD, envelope))
	else:
		cv.draw_rect(Rect2(0, 0, 1440, 70 * envelope), Color(0.005, 0.012, 0.014, 0.96))
		cv.draw_rect(Rect2(0, 900 - 100 * envelope, 1440, 100 * envelope), Color(0.005, 0.012, 0.014, 0.96))
		if cinematic == "unlock":
			_draw_unlock_cinematic(envelope)
		elif cinematic == "reveal":
			_title_center(720, 49, "借 光 显 纹", 30, Color(Pal.GOLD, envelope))
			for i in range(3):
				var a := smoothstep(0.45 + i * 0.48, 0.9 + i * 0.48, t) * envelope
				_title_center(600 + i * 120, 852, SYMBOLS[i], 36, Color(Pal.PAPER, a))
		elif cinematic == "wind":
			_title_center(720, 49, "风 起 · 灯 灭", 30, Color(Pal.GOLD, envelope))
			var caption := "穿堂风掠过，灯影骤然一晃……" if t < 1.45 else "暗处传来碎瓷滚落的轻响。"
			if t > 2.2:
				caption = "一盏手灯，在黑暗中重新亮起。"
			_serif_center(720, 851, caption, 22, Color(Pal.PAPER, envelope))
		elif cinematic == "shard":
			_draw_shard_cinematic(envelope)
		if t > 0.45:
			_t(Vector2(1186, 876), "空格 / Enter 跳过", 12, Color(0.8, 0.78, 0.68, envelope * 0.7))
	hud_mode = false
	cv = self


func _draw_unlock_cinematic(alpha: float) -> void:
	cv.draw_rect(Rect2(0, 70, 1440, 730), Color(0.015, 0.026, 0.023, 0.91 * alpha))
	_title_center(720, 49, "三 纹 归 位 · 旧 匣 初 开", 30, Color(Pal.GOLD, alpha))
	var latch := smoothstep(0.65, 1.48, cinematic_t)
	var focus := smoothstep(0.0, 0.42, cinematic_t) * (1.0 - smoothstep(3.65, 4.2, cinematic_t))
	var center := to_screen(CASKET_CENTER).lerp(Vector2(720, 470), focus)
	_draw_casket_art(center, lerpf(CASKET_SCALE * stage_k(), 1.18, focus), lid_t, latch, true)
	var caption := "山、月、水，三纹依次归位。"
	if cinematic_t >= 0.85:
		caption = "铜扣轻响，两侧锁舌缓缓退开。"
	if cinematic_t >= 1.6:
		caption = "匣盖沿着铜铰链抬起。"
	if cinematic_t >= 2.85:
		caption = "旧匣深处，一片青瓷泛起微光。"
	_serif_center(720, 850, caption, 22, Color(Pal.PAPER, alpha))
	# Sequence indicators follow the actual latch and hinge timing.
	for i in range(3):
		var active: bool = cinematic_t >= [0.0, 0.85, 1.6][i]
		var p := Vector2(598 + i * 122, 744)
		cv.draw_circle(p, 3.5, Color(Pal.JADE if active else Pal.MUTED, alpha * (1.0 if active else 0.3)))
		_t(p + Vector2(11, 5), ["纹样归位", "卡扣退开", "匣盖抬起"][i], 13, Color(Pal.PAPER if active else Pal.MUTED, alpha))


func _draw_shard_cinematic(alpha: float) -> void:
	var t := cinematic_t
	cv.draw_rect(Rect2(0, 70, 1440, 730), Color(0.012, 0.027, 0.026, 0.72 * alpha))
	_title_center(720, 49, "拾 得 · 青 瓷 残 片", 30, Color(Pal.GOLD, alpha))
	var p := Vector2(720, 430)
	var scale_factor := 1.7 + smoothstep(0, 0.8, t) * 0.5
	if t > 1.1:
		var k := smoothstep(1.1, 1.65, t)
		p = p.lerp(Vector2(1260, 838), k)
		scale_factor = lerpf(scale_factor, 0.3, k)
	for i in range(12, 0, -1):
		cv.draw_circle(p, (25 + i * 13) * scale_factor * 0.6, Color(0.5, 0.84, 0.72, 0.014 * alpha))
	for i in range(3):
		var r := 85 + i * 20 + t * 9
		cv.draw_arc(p, r * scale_factor * 0.7, -PI + t * 0.2 + i, PI * 0.5 + t * 0.2 + i, 70, Color(Pal.GOLD, alpha * 0.17), 1, true)
	_shard(p, scale_factor, Color(1, 1, 1, alpha))
	_serif_center(720, 851, "碗沿的第一片，已找回。" if pending_shard == "shard" else "灯火所指，第二片归于行囊。", 22, Color(Pal.PAPER, alpha))


## A rotating brass drum: the old glyph rolls out while the next comes over the rim.
func _draw_seal_drum(i: int, r: Rect2, jolt: Vector2) -> void:
	var hover := r.has_point(_mouse())
	_box(r, Color("342f21"), 9, Pal.GOLD if hover else Color("827047"), 2)
	var window := Rect2(r.position + Vector2(14, 37), Vector2(r.size.x - 28, 89))
	_box(window.grow(4), Color("191e17"), 5, Color("b69a5e"), 2)
	for band in range(30):
		var f := band / 29.0
		var light := sin(f * PI)
		cv.draw_rect(Rect2(window.position + Vector2(0, band * window.size.y / 30), Vector2(window.size.x, window.size.y / 30 + 1)), Color(0.26 + light * 0.24, 0.24 + light * 0.20, 0.15 + light * 0.13))
	var c := window.get_center()
	var progress := 1.0 - float(dial_flip[i])
	var rotation := smoothstep(0, 1, progress) * PI * 0.5
	var direction := float(dial_direction[i])
	var new_scale := maxf(0.04, sin(rotation))
	var old_scale := maxf(0.04, cos(rotation))
	if progress < 0.98:
		var old_y := c.y + direction * sin(rotation) * 38
		cv.draw_set_transform(jolt + Vector2(c.x, old_y), 0, Vector2(1, old_scale))
		_glyph(Vector2.ZERO, int(dial_previous[i]), 26, Color(0.91, 0.81, 0.55, old_scale))
	var new_y := c.y - direction * cos(rotation) * 38
	cv.draw_set_transform(jolt + Vector2(c.x, new_y), 0, Vector2(1, new_scale))
	_glyph(Vector2.ZERO, int(dials[i]), 26, Color(0.98, 0.89, 0.64, new_scale))
	cv.draw_set_transform(jolt)
	for s in [-1, 1]:
		var p := Vector2(r.get_center().x + s * (r.size.x * 0.5 - 8), window.get_center().y)
		cv.draw_circle(p, 5, Color("bca26b"))
		cv.draw_line(p + Vector2(-2, -2), p + Vector2(2, 2), Color("504627"), 1.3, true)
	_t(r.position + Vector2(62, 26), "0%d" % (i + 1), 13, Pal.MUTED)
	_tc(r.get_center().x, r.position.y + 151, SYMBOLS[int(dials[i])], 18, Pal.PAPER)
	_register("dial_%d" % i, r)


func _draw_seal() -> void:
	var e := ease(seal_t, -2.0)
	_modal_back(e)
	var jolt := Vector2(sin(shake * 40.0) * shake * 14.0, 0)
	cv.draw_set_transform(jolt)
	var card := Rect2(325, 185, 790, 550)
	_panel(card)
	_button("seal_close", Rect2(1036, 205, 56, 33), "关闭", false, 12)
	_t(Vector2(372, 244), "PUZZLE  /  三纹锁", 14, Pal.GOLD)
	_title(Vector2(372, 303), "依次入纹，方启旧匣。", 34, Pal.PAPER)
	_t(Vector2(374, 342), "点击纹样（或按 1 2 3）切换，按石壁上从左到右的顺序排列。", 16, Pal.MUTED)
	for i in range(3):
		var r := Rect2(421 + i * 191, 384, 157, 171)
		_draw_seal_drum(i, r, jolt)
		_button("back_%d" % i, Rect2(r.position + Vector2(0, 184), Vector2(157, 32)), "‹ 上一纹样", false, 12)
	_button("check", Rect2(550, 643, 340, 51), "尝试开启", true, 18)
	if revealed:
		_t(Vector2(374, 616), "手札记载：山 → 月 → 水", 14, Pal.JADE)
	cv.draw_set_transform(Vector2.ZERO)
