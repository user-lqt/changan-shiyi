extends "res://scripts/core/canvas.gd"
## 第二章 · 西市
## Part A (调查): inspect the stall to collect 物证 (evidence). One of them is a red herring.
## Part B (当面对质): Kang's testimony cycles automatically. Pick a 物证 and click the gold
## weak phrase to fire it. 追问 makes him elaborate. Wrong shots cost 耐心; at zero you are
## thrown out and the round restarts.

const Story = preload("res://scripts/data/story.gd")
const KANG_FOOT := Vector2(1010, 772)
const SPOTS := {
	"ledger": {"p": Vector2(500, 578), "label": "摊开的账簿", "r": Rect2(440, 555, 130, 50)},
	"bundle": {"p": Vector2(790, 572), "label": "锦缎包袱", "r": Rect2(730, 548, 120, 50)},
	"gong": {"p": Vector2(222, 275), "label": "檐下铜钲", "r": Rect2(170, 220, 110, 110)},
	"camel": {"p": Vector2(818, 290), "label": "三彩马与骆驼", "r": Rect2(760, 240, 120, 100)},
}
const LINE_TIME := 5.0
const BAND := Rect2(60, 400, 1320, 150)
const ROUND_LABELS := ["残片来历", "残片保管", "昨夜行踪"]
const EVIDENCE_CAPTIONS := {
	"shard": "釉色与纹样", "ledger": "昨日收支", "bundle": "雨痕与残粉", "gong": "闭市钲声",
}
const STAMP_TIME := 3.2
const RETORT_TIME := 2.7
const CUTIN_VOICES := ["不对！", "你露出马脚了！", "我有异议！"]

var evidence: Array = ["shard"]
var inspected := {}
var phase := "investigate"      # investigate | debate | done
var round_i := 0
var line_i := 0
var line_t := 0.0
var credit := 5
var credit_max := 5
var bullet := 0
var shot := {}                  # flying bullet: from, to, t, hit_line, ok
var stamp := 0.0
var retort := ""
var retort_t := 0.0
var shake := 0.0
var pressed := {}
var paused := false             # stop auto-advance while a press dialogue plays
var hint_level := 0
var card_lift: Array[float] = [0.0, 0.0, 0.0, 0.0]
var feedback_kind := ""
var feedback_evidence := "shard"
var feedback_weak := ""
var impact := Vector2.ZERO
var credit_loss_t := 0.0
var kick_pending := false
var capture_verdict_time := -1.0   # Deterministic screenshot time; disabled in normal play.


func _input_locked() -> bool:
	return paused or stamp > 0 or retort_t > 0 or not shot.is_empty()


func _select_evidence(index: int) -> void:
	if index >= 0 and index < evidence.size() and not _input_locked():
		bullet = index
		g.sfx("dial")


func _evidence_rect(index: int) -> Rect2:
	return Rect2(68 + index * 222, 693 - card_lift[index], 204, 166)


func enter() -> void:
	g.music("ambient")
	g.say("ch2_arrive")


## The stall painting fills the window; the debate is already a full-screen layout.
func staged() -> bool:
	return phase != "debate"


func chrome() -> bool:
	return not _cutin_active()


func _cutin_active() -> bool:
	return phase == "debate" and (stamp > 0 or (retort_t > 0 and feedback_kind == "wrong"))


func help_lines() -> Array:
	if phase == "debate":
		return ["证言会自动轮换，也可以用 ◀ ▶ 或 ← → 手动切换。", "1–4 或滚轮选择物证，然后点击句中金色的「破绽」出示。", "「追问」让康掌柜多说几句，有时能套出新话。", "出示错了会磨掉他的耐心，耐心耗尽会被赶出铺子，本轮重来。"]
	return ["点击摊位上的发光标记调查，收集物证。", "收集齐全后点击康掌柜开始对质。", "不是每一枚物证都有用。"]


func journal_lines() -> Array:
	var out := []
	for id in evidence:
		out.append("物证「%s」：%s" % [Story.EVIDENCE[id]["name"], Story.EVIDENCE[id]["desc"]])
	return out


func hint() -> String:
	hint_level += 1
	if phase == "investigate":
		var left := []
		for id in ["ledger", "bundle", "gong"]:
			if not inspected.has(id):
				left.append(SPOTS[id]["label"])
		if left.is_empty():
			return "物证已经齐了，点击康掌柜开始对质。"
		return "还没调查：" + "、".join(left) + "。"
	if phase == "debate":
		var lines: Array = Story.TESTIMONY[round_i]["lines"]
		for i in range(lines.size()):
			if not lines[i]["answer"].is_empty():
				var ev: String = lines[i]["answer"][0]
				if hint_level > 2:
					return "第 %d 句的「%s」，用物证「%s」。" % [i + 1, lines[i]["weak"], Story.EVIDENCE[ev]["name"]]
				return "哪一句和你手里的证据对不上？试试「%s」。" % Story.EVIDENCE[ev]["name"]
	return "碎片已经拿到了。"


func _ready_for_debate() -> bool:
	return inspected.has("ledger") and inspected.has("bundle") and inspected.has("gong")


# ------------------------------------------------------------------ update / input
func tick(delta: float, blocked: bool) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	for i in range(card_lift.size()):
		card_lift[i] = move_toward(card_lift[i], 9.0 if i == bullet else 0.0, delta * 90.0)
	if phase != "debate" or blocked or capture_verdict_time >= 0:
		return
	credit_loss_t = maxf(0.0, credit_loss_t - delta)
	if stamp > 0:
		stamp = maxf(0.0, stamp - delta)
		if stamp <= 0 and not g.test_mode:
			_finish_break_round(round_i)
		return
	if retort_t > 0:
		retort_t = maxf(0.0, retort_t - delta)
		if retort_t <= 0 and kick_pending:
			_restart_debate_round()
		return
	if paused:
		return
	if not shot.is_empty():
		shot["t"] += delta * 4.0
		if shot["t"] >= 1.0:
			_resolve_shot()
		return
	if stamp > 0 or retort_t > 0:
		return
	line_t += delta
	if line_t >= LINE_TIME:
		_next_line(1)


func _next_line(step: int) -> void:
	var n: int = Story.TESTIMONY[round_i]["lines"].size()
	line_i = posmod(line_i + step, n)
	line_t = 0.0


func key(event: InputEventKey) -> bool:
	if phase != "debate" or g.blocked():
		return false
	if _input_locked():
		if _cutin_active() and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			var elapsed := STAMP_TIME - stamp if stamp > 0 else RETORT_TIME - retort_t
			if elapsed > 0.8:
				if stamp > 0:
					_finish_break_round(round_i)
				else:
					retort_t = 0.0
					if kick_pending:
						_restart_debate_round()
		return true
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			var i: int = event.keycode - KEY_1
			_select_evidence(i)
			return true
		KEY_LEFT, KEY_A:
			_next_line(-1)
			return true
		KEY_RIGHT, KEY_D:
			_next_line(1)
			return true
		KEY_P:
			act("press")
			return true
	return false


func mouse(event: InputEvent) -> bool:
	if phase == "debate" and event is InputEventMouseButton and event.pressed and not g.blocked():
		if _input_locked():
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_evidence(posmod(bullet - 1, evidence.size()))
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_evidence(posmod(bullet + 1, evidence.size()))
			return true
		if event.button_index == MOUSE_BUTTON_LEFT and shot.is_empty() and stamp <= 0 and BAND.has_point(event.position) and hit(event.position).is_empty():
			_fire(event.position, false)
			return true
	return false


func act(id: String) -> void:
	if _common_act(id):
		return
	if phase == "debate" and _input_locked():
		return
	if SPOTS.has(id):
		_inspect(id)
		return
	match id:
		"kang":
			if phase == "investigate":
				if _ready_for_debate():
					g.say("kang_meet", _start_debate)
				else:
					g.say("kang_brush")
		"weak":
			if shot.is_empty() and stamp <= 0:
				_fire(_mouse(), true)
		"press":
			_press()
		"prev":
			_next_line(-1)
		"next":
			_next_line(1)
		"to_map":
			g.go("map")
		_:
			if id.begins_with("ev_"):
				_select_evidence(int(id.trim_prefix("ev_")))


func _inspect(id: String) -> void:
	inspected[id] = true
	if id in ["ledger", "bundle", "gong"] and not evidence.has(id):
		evidence.append(id)
		g.notify("获得物证「%s」。" % Story.EVIDENCE[id]["name"])
	g.show_card(id)


func _start_debate() -> void:
	phase = "debate"
	round_i = 0
	credit_max = 6 if bool(g.flags.get("polite", false)) else 5
	credit = credit_max
	_reset_round()
	g.music("battle", false)


func _reset_round() -> void:
	line_i = 0
	line_t = 0.0
	pressed = {}
	shot = {}
	stamp = 0.0
	retort_t = 0.0
	credit_loss_t = 0.0
	feedback_kind = ""
	kick_pending = false


func _press() -> void:
	if phase != "debate" or not shot.is_empty():
		return
	var line: Dictionary = Story.TESTIMONY[round_i]["lines"][line_i]
	pressed["%d_%d" % [round_i, line_i]] = true
	paused = true
	g.dlg.start_lines([{"w": "su", "t": "等一下！「%s」——这是什么意思？" % line["weak"]}, {"w": "kang", "t": line["press"]}], func() -> void:
		paused = false
		line_t = 0.0)


func _weak_rect(line: Dictionary) -> Rect2:
	var text: String = line["t"]
	var weak: String = line["weak"]
	var size := 30
	var x0 := BAND.get_center().x - _tw(text, size) * 0.5
	x0 += (1.0 - ease(clampf(line_t * 4.0, 0.0, 1.0), -2.0)) * 80.0
	var at := text.find(weak)
	var x := x0 + _tw(text.substr(0, at), size)
	return Rect2(x - 6, BAND.position.y + 50, _tw(weak, size) + 12, 50)


func _fire(target: Vector2, on_weak: bool) -> void:
	var card := _evidence_rect(bullet)
	shot = {"from": card.get_center() - Vector2(0, 24), "to": target, "t": 0.0, "weak": on_weak, "line": line_i, "evidence": str(evidence[bullet])}
	feedback_kind = ""
	retort_t = 0.0
	g.sfx("shoot")


func _resolve_shot() -> void:
	var s := shot
	shot = {}
	impact = s["to"]
	feedback_evidence = str(s["evidence"])
	if not s["weak"]:
		feedback_kind = "miss"
		retort = "先找出证言中的破绽，再出示证据。"
		retort_t = RETORT_TIME
		g.sfx("hit", -12)
		return
	var line: Dictionary = Story.TESTIMONY[round_i]["lines"][int(s["line"])]
	feedback_weak = str(line["weak"])
	var ev: String = str(s["evidence"])
	if line["answer"].has(ev):
		feedback_kind = "success"
		_break_round()
	else:
		credit -= 1
		g.stats["credit_lost"] = int(g.stats["credit_lost"]) + 1
		shake = 1.0
		feedback_kind = "wrong"
		credit_loss_t = RETORT_TIME
		retort = Story.RETORTS[randi() % Story.RETORTS.size()]
		retort_t = RETORT_TIME
		g.sfx("error")
		if credit <= 0:
			paused = true
			kick_pending = true
			if g.test_mode:
				_restart_debate_round()


func _restart_debate_round() -> void:
	if g.scene != self or phase != "debate":
		return
	kick_pending = false
	retort_t = 0.0
	g.say("kang_angry", func() -> void:
		paused = false
		credit = credit_max
		_reset_round())


func _break_round() -> void:
	stamp = STAMP_TIME
	g.sfx("objection")
	g.voice("su", CUTIN_VOICES[round_i], 3.0)
	shake = 0.6
	paused = true
	if g.test_mode:
		get_tree().create_timer(0.01).timeout.connect(_finish_break_round.bind(round_i))


func _finish_break_round(finished: int) -> void:
	if g.scene != self or phase != "debate" or round_i != finished or not paused:
		return
	stamp = 0.0
	var after := func() -> void:
		paused = false
		if finished + 1 < Story.TESTIMONY.size():
			round_i = finished + 1
			_reset_round()
		else:
			_win()
	g.say("r%d_break" % (finished + 1), after)


func _win() -> void:
	phase = "done"
	g.music("ambient")
	g.get_shard(2)
	g.show_card("shard_c", func() -> void:
		g.clear("ch2")
		g.notify("第二章完成，已取回第三片。去后巷酒肆找阿拾，核实塔顶的线索。", 8))


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	hit_regions.clear()
	if phase == "debate":
		_draw_debate()
		return
	var goals := [
		{"t": "调查", "d": "检查摊位，收集物证", "done": _ready_for_debate()},
		{"t": "对质", "d": "找出康掌柜证言里的破绽", "done": phase == "done"},
		{"t": "讨回", "d": "拿回第三片碎瓷", "done": phase == "done"},
	]
	var items := []
	for id in evidence:
		items.append({"id": id, "name": Story.EVIDENCE[id]["name"], "icon": "shard" if id == "shard" else "", "sub": "物证"})
	var obj := "调查摊位上的可疑之处，收集物证。"
	if _ready_for_debate() and phase == "investigate":
		obj = "物证已齐。点击康掌柜，开始对质。"
	elif phase == "done":
		obj = "第三片碎瓷到手。最后一片在大雁塔。"
	_frame("第二章  ·  对质", "长安西市  /  闭市前 · 雨歇", goals, obj, items)
	if not _img_cover("market", ROOM):
		draw_rect(bleed(), Color("2a2420"))
	draw_rect(bleed(), Color(0.02, 0.03, 0.04, 0.12))
	var talking: bool = g.dlg.active and g.dlg.entry().get("w", "") == "kang"
	if not talking:
		_figure("npc_kang", KANG_FOOT, 380)
	if phase == "done":
		_next_button("to_map", "回长安舆图  ›")
	if g.blocked():
		return
	for id in SPOTS:
		_hotspot(id, SPOTS[id]["p"], SPOTS[id]["label"], SPOTS[id]["r"], inspected.has(id))
	if phase == "investigate":
		_hotspot("kang", KANG_FOOT + Vector2(0, -400), "康掌柜" + ("  · 对质" if _ready_for_debate() else ""), Rect2(KANG_FOOT + Vector2(-80, -380), Vector2(160, 380)))


func _draw_debate() -> void:
	var jolt := Vector2(sin(shake * 50.0) * shake * 12.0, 0)
	draw_set_transform(jolt)
	if not _img_cover("market", Rect2(0, 0, 1440, 900), Color(0.45, 0.4, 0.45)):
		draw_rect(Rect2(0, 0, 1440, 900), Color("1d1820"))
	# Speed lines give the debate its tension.
	for i in range(24):
		var y := fmod(i * 41.0 + age * 260.0, 900.0)
		draw_line(Vector2(0, y), Vector2(1440, y - 120), Color(0.9, 0.7, 0.4, 0.035), 2)
	_figure("npc_kang", Vector2(1140, 900), 640, Color(1, 1, 1, 0.95))
	draw_set_transform(Vector2.ZERO)
	_draw_debate_header()
	var round_data: Dictionary = Story.TESTIMONY[round_i]
	draw_set_transform(jolt)
	# Statement band.
	var lines: Array = round_data["lines"]
	var line: Dictionary = lines[line_i]
	var slide := clampf(line_t * 4.0, 0.0, 1.0)
	_box(BAND, Color(0.04, 0.06, 0.07, 0.88), 10, Color(0.84, 0.72, 0.48, 0.6))
	_t(BAND.position + Vector2(24, 30), "康掌柜 · 当面陈词", 14, Pal.GOLD)
	_t(BAND.position + Vector2(BAND.size.x - 128, 30), "第 %d / %d 句" % [line_i + 1, lines.size()], 13, Pal.MUTED)
	for i in range(lines.size()):
		var p := BAND.position + Vector2(173 + i * 16, 25)
		var d := 3.0 if i == line_i else 2.0
		draw_circle(p, d, Pal.GOLD if i == line_i else Color(0.65, 0.63, 0.52, 0.4))
	var text: String = line["t"]
	var weak: String = line["weak"]
	var size := 30
	var x0 := BAND.get_center().x - _tw(text, size) * 0.5 + (1.0 - ease(slide, -2.0)) * 80.0
	var at := text.find(weak)
	var y := BAND.position.y + 88
	var a := slide
	_t(Vector2(x0, y), text.substr(0, at), size, Color(0.93, 0.89, 0.8, a))
	var wx := x0 + _tw(text.substr(0, at), size)
	var wr := _weak_rect(line)
	var hover := wr.has_point(_mouse())
	var glow := 0.6 + 0.4 * sin(age * 6.0)
	_t(Vector2(wx, y), weak, size, Color(1.0, 0.78 + 0.1 * glow, 0.3, a))
	draw_line(Vector2(wx, y + 8), Vector2(wx + _tw(weak, size), y + 8), Color(1, 0.8, 0.35, a * (1.0 if hover else 0.5)), 2)
	_t(Vector2(wx + _tw(weak, size), y), text.substr(at + weak.length()), size, Color(0.93, 0.89, 0.8, a))
	# Line timer.
	draw_rect(Rect2(BAND.position.x + 20, BAND.end.y - 18, (BAND.size.x - 40) * (1.0 - line_t / LINE_TIME), 4), Color(0.84, 0.72, 0.48, 0.6))
	if pressed.has("%d_%d" % [round_i, line_i]):
		_t(BAND.position + Vector2(BAND.size.x - 230, 30), "已追问", 13, Pal.JADE)
	draw_set_transform(Vector2.ZERO)
	var enabled: bool = not g.blocked() and not _input_locked()
	if enabled:
		_register("weak", wr)
	_button("prev", Rect2(BAND.position.x + 20, BAND.end.y + 16, 70, 40), "◀", false, 18, enabled)
	_button("next", Rect2(BAND.end.x - 90, BAND.end.y + 16, 70, 40), "▶", false, 18, enabled)
	_button("press", Rect2(BAND.get_center().x - 90, BAND.end.y + 16, 180, 40), "追问  P", false, 16, enabled)
	_draw_evidence_tray(enabled)
	var m := _mouse()
	if enabled and BAND.has_point(m):
		_draw_evidence_reticle(m, hover)
	_draw_evidence_flight()
	_draw_debate_feedback()


## Eight-petal bronze-mirror sight: the open centre keeps the statement legible.
func _draw_evidence_reticle(p: Vector2, locked: bool) -> void:
	var ink := Color(0.015, 0.025, 0.03, 0.92)
	var gold := Color("ffe0a0") if locked else Color("d7b77b")
	var radius := 23.0 if locked else 27.0
	for i in range(8):
		var a := i * TAU / 8.0 + age * 0.12
		var points := PackedVector2Array()
		for j in range(9):
			var t := a - 0.21 + j * 0.0525
			points.append(p + Vector2.from_angle(t) * (radius + sin(j * PI / 8.0) * 3.0))
		draw_polyline(points, ink, 5.0, true)
		draw_polyline(points, gold, 1.5, true)
	for i in range(4):
		var axis := Vector2.from_angle(i * PI * 0.5)
		var tangent := axis.orthogonal()
		var centre := p + axis * (radius + 7.0)
		draw_line(p + axis * 12.0, p + axis * 19.0, ink, 4.5, true)
		draw_line(p + axis * 12.0, p + axis * 19.0, gold, 1.5, true)
		draw_colored_polygon(PackedVector2Array([centre - axis * 3, centre + tangent * 2, centre + axis * 3, centre - tangent * 2]), gold)
	if locked:
		draw_arc(p, 15.0 + sin(age * 7.0), -0.65, 0.65, 12, Color(Pal.JADE, 0.9), 1.4, true)
		draw_arc(p, 15.0 + sin(age * 7.0), PI - 0.65, PI + 0.65, 12, Color(Pal.JADE, 0.9), 1.4, true)
	draw_circle(p, 3.5, ink)
	draw_circle(p, 1.5, gold)


func _draw_debate_header() -> void:
	_title(Vector2(60, 56), "西市  /  当面对质", 28, Pal.PAPER)
	_t(Vector2(60, 79), "以物为证，循言寻隙", 12, Pal.GOLD)
	_t(Vector2(625, 78), "三轮证言", 12, Pal.MUTED)
	for i in range(Story.TESTIMONY.size()):
		var r := Rect2(60 + i * 222, 98, 210, 61)
		var active := i == round_i
		var completed := i < round_i or (active and stamp > 0)
		var c := Pal.JADE if completed else (Pal.GOLD if active else Color("777567"))
		_box(r, Color(0.035, 0.07, 0.07, 0.95), 3, Color(c, 0.85 if active else 0.4))
		if active:
			draw_rect(Rect2(r.position, Vector2(3, r.size.y)), c)
		var seal := Rect2(r.position + Vector2(13, 16), Vector2(30, 30))
		_box(seal, Color(c, 0.14), 1, Color(c, 0.65))
		_title_center(seal.get_center().x, seal.position.y + 23, ["壹", "贰", "叁"][i], 24, c)
		_serif(r.position + Vector2(55, 27), ROUND_LABELS[i], 18, Pal.PAPER if active else c)
		_t(r.position + Vector2(55, 46), "已识破" if completed else ("正在对质" if active else "待质询"), 11, c)
	var r := Rect2(790, 98, 400, 61)
	var low := credit <= 2
	_box(r, Color(0.035, 0.065, 0.065, 0.95), 3, Color(Pal.RED if low else Pal.GOLD, 0.6))
	_t(r.position + Vector2(17, 26), "耐心", 16, Pal.PAPER)
	_t(r.position + Vector2(17, 47), "误判扣一枚", 10, Pal.MUTED)
	for i in range(credit_max):
		var p := r.position + Vector2(110 + i * 35, 30)
		_draw_credit_coin(p, i < credit, 1.0)
		if credit_loss_t > 0 and i == credit:
			var t := (RETORT_TIME - credit_loss_t) / RETORT_TIME
			var a := maxf(0.0, 1.0 - t * 1.9)
			_draw_credit_coin(p + Vector2(18 * t, -36 * t), false, a)
			_tc(p.x + 12, p.y - 20 - t * 20, "−1", 18, Color(Pal.RED, a))
	_tc(r.end.x - 35, r.position.y + 30, "%d/%d" % [credit, credit_max], 16, Pal.RED if low else Pal.GOLD)
	_tc(r.end.x - 35, r.position.y + 47, "告急" if low else "尚余", 10, Pal.RED if low else Pal.MUTED)


func _draw_credit_coin(p: Vector2, live: bool, alpha: float) -> void:
	var c := Color("c8a15b") if live else Color("4d5146")
	draw_circle(p + Vector2(0, 2), 13, Color(0, 0, 0, 0.4 * alpha))
	draw_circle(p, 12, Color(c, alpha))
	draw_arc(p, 12, 0, TAU, 36, Color(Color("f2d896") if live else Color("767366"), alpha), 1.2, true)
	draw_arc(p, 9, 0, TAU, 36, Color(0.23, 0.22, 0.13, 0.55 * alpha), 1, true)
	draw_rect(Rect2(p - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0.04, 0.07, 0.065, alpha))
	if not live:
		draw_line(p + Vector2(-7, -8), p + Vector2(7, 8), Color(0.77, 0.31, 0.23, 0.7 * alpha), 1.5, true)


func _draw_evidence_art(id: String, r: Rect2, alpha := 1.0) -> void:
	_box(r, Color(0.035, 0.07, 0.075, alpha), 2)
	var key := "evidence_" + id
	if g.tex.has(key):
		var texture: Texture2D = g.tex[key]
		var s := texture.get_size() * minf(r.size.x / texture.get_width(), r.size.y / texture.get_height())
		draw_texture_rect(texture, Rect2(r.get_center() - s * 0.5, s), false, Color(1, 1, 1, alpha))
	elif id == "shard":
		_shard(r.get_center(), minf(r.size.x, r.size.y) / 120.0, Color(1, 1, 1, alpha))
	draw_rect(r, Color(0.84, 0.72, 0.48, 0.18 * alpha), false, 1)


func _draw_evidence_tray(enabled: bool) -> void:
	var tray := Rect2(52, 616, 920, 264)
	_box(tray, Color(0.025, 0.05, 0.055, 0.95), 4, Color(0.7, 0.62, 0.41, 0.52))
	draw_line(tray.position + Vector2(16, 36), Vector2(tray.end.x - 16, tray.position.y + 36), Color(0.84, 0.72, 0.48, 0.2), 1, true)
	_t(Vector2(70, 641), "随身证据", 16, Pal.GOLD)
	_t(Vector2(194, 640), "1–4 / 滚轮选择  ·  点击金色词句出示", 12, Pal.MUTED)
	_t(Vector2(841, 640), "物证  /  %02d" % evidence.size(), 11, Pal.GOLD)
	var ev: String = evidence[bullet]
	_wrap(Vector2(70, 673), str(Story.EVIDENCE[ev]["desc"]), 884, 13, Pal.SOFT, 19)
	for i in range(evidence.size()):
		var r := _evidence_rect(i)
		var id: String = evidence[i]
		var selected := i == bullet
		var hover := enabled and r.has_point(_mouse())
		var edge := Pal.GOLD if selected else Color(0.44, 0.53, 0.46, 0.85 if hover else 0.48)
		_box(Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.24), 3)
		_box(r, Color("253c37") if selected else Color("122322"), 3, edge, 2 if selected else 1)
		_draw_evidence_art(id, Rect2(r.position + Vector2(8, 8), Vector2(188, 101)))
		_box(Rect2(r.position + Vector2(12, 12), Vector2(24, 24)), Color(0.02, 0.04, 0.045, 0.92), 2, Color(edge, 0.6))
		_tc(r.position.x + 24, r.position.y + 30, str(i + 1), 13, Pal.GOLD if selected else Pal.SOFT)
		_serif(r.position + Vector2(14, 133), str(Story.EVIDENCE[id]["name"]), 19, Pal.PAPER)
		_t(r.position + Vector2(14, 154), EVIDENCE_CAPTIONS[id], 11, Pal.GOLD if selected else Pal.MUTED)
		if selected:
			var seal := Rect2(r.end.x - 40, r.position.y + 121, 25, 29)
			_box(seal, Color(0.36, 0.14, 0.12, 0.9), 1, Color(0.9, 0.55, 0.36, 0.6))
			_tc(seal.get_center().x, seal.position.y + 21, "呈", 16, Color("f1d7ac"))
		if enabled:
			_register("ev_%d" % i, r)


func _flight_point(t: float) -> Vector2:
	var p: Vector2 = (shot["from"] as Vector2).lerp(shot["to"], t)
	return p + Vector2(sin(t * PI) * 28, -sin(t * PI) * 60)


func _draw_evidence_flight() -> void:
	if not shot.is_empty():
		var t := clampf(float(shot["t"]), 0.0, 1.0)
		var path := PackedVector2Array()
		for i in range(12):
			path.append(_flight_point(maxf(0.0, t - i * 0.018)))
		draw_polyline(path, Color(0.9, 0.75, 0.42, 0.2), 12, true)
		draw_polyline(path, Color(1, 0.87, 0.58, 0.9), 2, true)
		var p := _flight_point(t)
		var id: String = shot["evidence"]
		var r := Rect2(p - Vector2(54, 42), Vector2(108, 84))
		_box(r.grow(3), Color("bc9c60"), 3, Color("f0d59b"))
		_draw_evidence_art(id, Rect2(r.position, Vector2(108, 60)))
		_tc(p.x, r.end.y - 7, str(Story.EVIDENCE[id]["name"]), 13, Pal.INK)


func _ink_cut(start: Vector2, finish: Vector2, width: float, color: Color) -> void:
	var direction := (finish - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array()
	for i in range(16):
		var t := i / 15.0
		var w := sin(t * PI) * width * (0.72 + sin(i * 2.3) * 0.22)
		points.append(start.lerp(finish, t) + normal * w)
	for i in range(15, -1, -1):
		var t := i / 15.0
		var w := sin(t * PI) * width * (0.75 + cos(i * 1.7) * 0.2)
		points.append(start.lerp(finish, t) - normal * w)
	draw_colored_polygon(points, color)


func _draw_debate_feedback() -> void:
	if _cutin_active():
		_draw_fullscreen_cutin(stamp > 0)
	elif retort_t > 0:
		var wrong := feedback_kind == "wrong"
		var c := Pal.RED if wrong else Pal.GOLD
		var a := minf(1.0, retort_t * 3.0)
		var elapsed := RETORT_TIME - retort_t
		var r := Rect2(430, 229 + maxf(0.0, 1.0 - elapsed * 7.0) * 16, 580, 132)
		_box(r, Color(0.07, 0.045, 0.04, 0.97 * a), 4, Color(c, 0.7 * a))
		draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Color(c, a))
		_t(r.position + Vector2(22, 28), "康掌柜 · 反驳" if wrong else "未指向破绽", 14, Color(c, a))
		_t(r.position + Vector2(22, 68), retort if wrong else "先找准证言中的金色词句", 23, Color(Pal.PAPER, a))
		_t(r.position + Vector2(22, 105), "「%s」未能推翻这句证言" % Story.EVIDENCE[feedback_evidence]["name"] if wrong else "耐心不变 · 选好证据后，再向破绽出示", 14, Color(Pal.MUTED, a))
		_box(Rect2(r.end.x - 122, r.position.y + 12, 100, 24), Color(c, 0.16 * a), 2, Color(c, 0.4 * a))
		_tc(r.end.x - 72, r.position.y + 30, "耐心 −1" if wrong else "耐心不变", 12, Color(c, a))
		if wrong:
			var radius := 16.0 + minf(elapsed, 0.5) * 84
			var ia := maxf(0, 0.8 - elapsed * 1.7)
			draw_arc(impact, radius, 0, TAU, 40, Color(Pal.RED, ia), 2, true)
			draw_line(impact - Vector2(11, 11), impact + Vector2(11, 11), Color(Pal.RED, ia), 3, true)
			draw_line(impact + Vector2(-11, 11), impact + Vector2(11, -11), Color(Pal.RED, ia), 3, true)


func _draw_fullscreen_cutin(success: bool) -> void:
	var duration := STAMP_TIME if success else RETORT_TIME
	var remaining := stamp if success else retort_t
	var elapsed := duration - remaining if capture_verdict_time < 0 else capture_verdict_time
	var enter := ease(clampf(elapsed / 0.22, 0.0, 1.0), 0.3)
	var leave := ease(clampf((elapsed - duration + 0.38) / 0.38, 0.0, 1.0), 2.0)
	var alpha := (1.0 - leave) * minf(1.0, elapsed / 0.065)
	var accent := Pal.GOLD if success else Pal.RED
	# The backdrop and moving brush lines fill the complete viewport.
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.015, 0.035, 0.04, alpha))
	var drift := Vector2(-22 + sin(elapsed * 0.65) * 12, -20)
	var modulation := Color(1.0, 1.0 if success else 0.66, 1.0 if success else 0.59, alpha)
	_img_cover("ch2_cutin_background", Rect2(drift, Vector2(1490, 940)), modulation)
	var screen_jolt := Vector2(sin(elapsed * 94) * maxf(0, 1.0 - elapsed / 0.45) * 12, 0)
	draw_set_transform(screen_jolt)
	for i in range(23):
		var y := fmod(i * 67.0 + elapsed * 180.0, 1050.0) - 70
		var x := fmod(i * 151.0 + elapsed * 800.0, 1800.0) - 230
		var start := Vector2(x, y)
		var end := start + Vector2(80 + (i % 5) * 33, -18 - (i % 4) * 8)
		draw_line(start, end, Color(accent, 0.13 * alpha), 1.0 + i % 2, true)
	# A brief eye close-up slides across before the full action pose lands.
	if elapsed < 0.31:
		_draw_eye_slash(success, elapsed, alpha)
	var actor_enter := ease(clampf((elapsed - 0.06) / 0.28, 0.0, 1.0), 0.25)
	var height := 760.0 + minf(elapsed, 2.4) * 8.0
	var actor_x := 475.0 - (1.0 - actor_enter) * 690.0 - leave * 210.0 if success else 990.0 + (1.0 - actor_enter) * 690.0 + leave * 210.0
	var key := "ch2_cutin_su" if success else "ch2_cutin_kang"
	var foot := Vector2(actor_x, 875)
	_figure(key, foot + Vector2(-9 if success else 9, 9), height, Color(0.01, 0.025, 0.025, 0.65 * alpha))
	_figure(key, foot, height, Color(1, 1, 1, alpha))
	# Lettering is generated artwork, kept independent of the character for parallax.
	var title_enter := ease(clampf((elapsed - 0.16) / 0.22, 0.0, 1.0), 0.3)
	var title_scale := lerpf(1.55, 1.0, title_enter)
	var title_center := Vector2(1100 if success else 340, 231)
	title_center += Vector2((1.0 - title_enter) * (170 if success else -170), -leave * 100)
	var title_width := 620.0 * title_scale
	var title_alpha := alpha * clampf((elapsed - 0.15) * 14, 0.0, 1.0)
	_draw_cutin_title("ch2_cutin_title" if success else "ch2_cutin_retort_title", title_center, title_width, title_alpha, "识破！" if success else "驳回！")
	draw_set_transform(Vector2.ZERO)
	var info := ease(clampf((elapsed - 0.74) / 0.28, 0.0, 1.0), 0.4)
	if info > 0:
		_draw_verdict_evidence(success, info * alpha, (1.0 - info) * 30)
	# Cinematic matte and restrained opening flash. No repeating flashes.
	var bars := 52.0 + (1.0 - enter) * 398.0
	draw_rect(Rect2(0, 0, 1440, bars), Color(0.01, 0.02, 0.025, alpha))
	draw_rect(Rect2(0, 900 - bars, 1440, bars), Color(0.01, 0.02, 0.025, alpha))
	draw_line(Vector2(0, bars), Vector2(1440, bars), Color(accent, 0.55 * alpha), 1, true)
	draw_line(Vector2(0, 900 - bars), Vector2(1440, 900 - bars), Color(accent, 0.55 * alpha), 1, true)
	_t(Vector2(48, 33), "长安拾遗   /   西市对质", 13, Color(Pal.GOLD, alpha))
	_t(Vector2(1090, 33), "证言 %02d   /   %s" % [round_i + 1, "识破" if success else "反驳"], 13, Color(Pal.GOLD if success else Pal.RED, alpha))
	_t(Vector2(48, 882), "苏晴  ·  以物为证" if success else "康掌柜  ·  据理反驳", 13, Color(Pal.PAPER, alpha))
	if elapsed > 0.8:
		_t(Vector2(1170, 882), "空格 / Enter 跳过", 12, Color(Pal.MUTED, alpha))
	if elapsed < 0.12:
		var flash := sin(clampf(elapsed / 0.12, 0.0, 1.0) * PI) * 0.28
		draw_rect(Rect2(0, 0, 1440, 900), Color(1, 0.89, 0.66, flash))


func _draw_cutin_title(key: String, center: Vector2, width: float, alpha: float, fallback: String) -> void:
	if g.tex.has(key):
		var texture: Texture2D = g.tex[key]
		var size := Vector2(width, width * texture.get_height() / texture.get_width())
		draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, Color(1, 1, 1, alpha))
	else:
		_title_center(center.x, center.y + 45, fallback, 106, Color(Pal.PAPER, alpha))


func _draw_eye_slash(success: bool, elapsed: float, alpha: float) -> void:
	var key := "ch2_cutin_su" if success else "ch2_cutin_kang"
	if not g.tex.has(key):
		return
	var texture: Texture2D = g.tex[key]
	var dimensions := texture.get_size()
	var region := Rect2(dimensions * (Vector2(0.15, 0.13) if success else Vector2(0.54, 0.16)), dimensions * Vector2(0.35, 0.19))
	var x := (1.0 - ease(clampf(elapsed / 0.15, 0.0, 1.0), 0.3)) * (900 if success else -900)
	var r := Rect2(x, 282, 1440, 230)
	draw_rect(r.grow(6), Color(0.02, 0.04, 0.04, alpha))
	draw_texture_rect_region(texture, r, region, Color(1, 1, 1, alpha * maxf(0, 1.0 - elapsed / 0.31)))


func _draw_verdict_evidence(success: bool, alpha: float, offset: float) -> void:
	var r := Rect2(748 if success else 62, 634 + offset, 628, 178)
	var accent := Pal.JADE if success else Pal.RED
	_box(r, Color(0.025, 0.05, 0.05, 0.95 * alpha), 3, Color(accent, 0.75 * alpha), 1)
	draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Color(accent, alpha))
	_draw_evidence_art(feedback_evidence, Rect2(r.position + Vector2(16, 25), Vector2(150, 126)), alpha)
	var x := r.position.x + 186
	_t(Vector2(x, r.position.y + 30), "物证与证言相悖" if success else "这份证据不足以推翻证言", 14, Color(accent, alpha))
	_t(Vector2(x, r.position.y + 66), str(Story.EVIDENCE[feedback_evidence]["name"]), 25, Color(Pal.PAPER, alpha))
	if success:
		_t(Vector2(x, r.position.y + 98), "推翻「%s」" % feedback_weak, 17, Color(Pal.GOLD, alpha))
		_wrap(Vector2(x, r.position.y + 128), str(Story.EVIDENCE[feedback_evidence]["desc"]), 420, 14, Color(Pal.SOFT, alpha), 22)
	else:
		_t(Vector2(x, r.position.y + 101), retort, 18, Color(Pal.PAPER, alpha))
		_t(Vector2(x, r.position.y + 139), "耐心 −1    /    尚余 %d 分" % credit, 16, Color(Pal.RED, alpha))
