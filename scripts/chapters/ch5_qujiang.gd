extends "res://scripts/core/canvas.gd"
## 第五章 · 曲江诗牌: a deck-building poetry contest at the Qujiang banquet (cf. Balatro).
## Each turn the player composes one line from word cards (two syllables) and one foot card
## (the final syllable): 2+2+1 = 五言 or 2+2+2+1 = 七言. Score = 墨 × 韵 (see poem_rules.gd):
## 合律 (tone pattern), 押韵 (round rhyme), 对仗 (mirrors the previous line) and 意象 (shared
## images) raise it; 诗友 charms bought between rounds push it further. Three rounds; reach the
## target within the allowed lines. Winning earns Bai Juyi's introduction to Ci'en Temple.
## The table, cup, tally tube and played tiles are 3D (SubViewport over the AI-painted pavilion).

const Cards = preload("res://scripts/data/poem_cards.gd")
const Rules = preload("res://scripts/core/poem_rules.gd")
const CARD := Vector2(100, 140)
const HAND_Y := 730.0
const MAX_CHARMS := 5
const MAX_SELECTED := 5
const STEP_TIME := 0.22

var phase := "intro"            # intro | pick | play | scoring | won_round | shop | lost | done
var round_i := 0
var score := 0
var plays := 0
var discards := 0
var money := 0
var charms: Array = []
var deck_w: Array = []
var deck_f: Array = []
var pile_w: Array = []
var pile_f: Array = []
var hand_w: Array = []
var hand_f: Array = []
var sel: Array = []             # [["w", i] | ["f", i]] in click order
var prev_line: Array = []
var last := {}
var score_t := 0.0
var lines_played: Array = []
var offers: Array = []          # pick / shop items: {kind: charm|word|foot, id, cost, sold}
var best_total := 0
var rng := RandomNumberGenerator.new()
# 3D
var vp: SubViewport
var world: Node3D
var cam: Camera3D
var cup: Node3D
var tiles_now: Array = []
var tile_mats := {}
var glow := 0.0


func enter() -> void:
	g.music("ambient", false)
	rng.seed = 2026 if g.test_mode else int(Time.get_ticks_usec())
	_build_3d()
	_new_run()
	g.say("ch5_arrive", func() -> void: _open_pick())


func chrome() -> bool:
	return phase != "scoring"


func bottom_hud() -> bool:
	return phase == "done"


func _new_run() -> void:
	charms = []
	money = 0
	round_i = 0
	deck_w = Cards.START_WORDS.duplicate()
	deck_f = Cards.START_FEET.duplicate()
	lines_played = []
	best_total = 0


func help_lines() -> Array:
	return ["点选 2–3 张词牌（按点击顺序成句），再点 1 张韵脚，组成五言或七言，按「吟诗」计分。",
		"得分 = 墨 × 韵。合律 +3 韵：第二、四、六字平仄交替，句尾不连三平、三仄。",
		"押韵 +3 韵：韵脚是平声，并属于本巡限韵。对仗 +4 韵：与上一句词性相同、平仄相反。",
		"同一意象出现两次以上加墨。词牌、韵脚可混选最多 5 张，按「换字」或 X 一起替换，只消耗 1 次换字。",
		"再次点击可取消单张选择，右键取消全部。巡与巡之间可在诗友铺添诗友与新牌。",
		"卡住了按「荐句」：会替你选出当前手牌里得分最高的一句。"]


func journal_lines() -> Array:
	var out := ["平仄：唐音里平声为「平」，上、去、入声为「仄」。入声字如 月 白 曲 落，今读平声，唐时却是仄声。",
		"二四六分明：律句里第二、四、六字平仄交替；第一、三、五字可以宽松。"]
	for l in lines_played.slice(maxi(0, lines_played.size() - 3)):
		out.append("已吟：" + str(l))
	return out


func hint() -> String:
	match phase:
		"pick":
			return "先选一位诗友。酒仙、曲江流饮、杏园探花都是开局好用的加成。"
		"shop":
			return "乘法类诗友（×韵）最后才计算，越晚买越值。钱不够就先买新牌。"
		"play":
			var b := best_line()
			if b.is_empty():
				return "手里凑不出一句。选几张不要的牌按「换字」。"
			return "试试「%s」，可得 %d 分。按「荐句」会直接帮你选好。" % [Rules.text(_cards_of(b)), int(_preview(b)["total"])]
	return "白居易已答应引见。回舆图前往慈恩寺。"


# ================================================================== rounds and deck
func rnd() -> Dictionary:
	return Cards.ROUNDS[round_i]


func start_round(i: int) -> void:
	round_i = i
	score = 0
	plays = int(rnd()["plays"]) + _charm_n("extra_play")
	discards = int(rnd()["discards"]) + _charm_n("extra_discard")
	prev_line = []
	last = {}
	sel = []
	pile_w = deck_w.duplicate()
	pile_f = deck_f.duplicate()
	_shuffle(pile_w)
	_shuffle(pile_f)
	hand_w = []
	hand_f = []
	_draw_up()
	phase = "play"
	_sync_tiles()
	g.notify(str(rnd()["rule"]), 6.0)


func _charm_n(kind: String) -> int:
	var n := 0
	for id in charms:
		if Cards.CHARMS[id]["kind"] == kind:
			n += int(Cards.CHARMS[id]["n"])
	return n


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _draw_up() -> void:
	while hand_w.size() < Cards.HAND_WORDS and not pile_w.is_empty():
		hand_w.append(pile_w.pop_back())
	while hand_f.size() < Cards.HAND_FEET and not pile_f.is_empty():
		hand_f.append(pile_f.pop_back())


func _card(entry: Array) -> Dictionary:
	return Rules.word(hand_w[entry[1]]) if entry[0] == "w" else Rules.foot(hand_f[entry[1]])


## Selection in reading order: the chosen words (click order) then the chosen foot.
func _cards_of(selection: Array) -> Array:
	var ws := []
	var fs := []
	for e in selection:
		if e[0] == "w":
			ws.append(_card(e))
		else:
			fs.append(_card(e))
	return ws + fs


func _preview(selection: Array) -> Dictionary:
	return Rules.score_line(_cards_of(selection), prev_line, charms, rnd())


func toggle(kind: String, i: int) -> void:
	if phase != "play":
		return
	var e := [kind, i]
	var at := -1
	for k in range(sel.size()):
		if sel[k] == e:
			at = k
	if at >= 0:
		sel.remove_at(at)
	else:
		if sel.size() >= MAX_SELECTED:
			g.notify("最多选择 5 张牌。")
			return
		sel.append(e)
	g.sfx("dial", -12)
	_sync_tiles()


## Scores the selection, removes the cards and starts the step-by-step reveal.
func play_line() -> bool:
	if phase != "play" or plays <= 0:
		return false
	var cards := _cards_of(sel)
	var r := Rules.score_line(cards, prev_line, charms, rnd())
	if not r["ok"]:
		g.notify("一句要 2–3 张词牌，最后接 1 张韵脚。")
		g.sfx("error", -8)
		return false
	plays -= 1
	last = r
	last["cards"] = cards
	last["text"] = Rules.text(cards)
	score += int(r["total"])
	best_total = maxi(best_total, int(r["total"]))
	lines_played.append(last["text"])
	prev_line = cards
	_remove_selected()
	score_t = 0.0
	phase = "scoring"
	glow = 1.0
	g.sfx("note")
	_sync_tiles()
	if g.test_mode:
		_after_scoring()
	return true


func _remove_selected() -> void:
	var wi := []
	var fi := []
	for e in sel:
		(wi if e[0] == "w" else fi).append(e[1])
	wi.sort()
	fi.sort()
	for k in range(wi.size() - 1, -1, -1):
		hand_w.remove_at(wi[k])
	for k in range(fi.size() - 1, -1, -1):
		hand_f.remove_at(fi[k])
	sel = []
	_draw_up()


func discard() -> bool:
	if phase != "play" or discards <= 0 or sel.is_empty():
		return false
	var count := sel.size()
	discards -= 1
	_remove_selected()
	g.sfx("rotate", -10)
	_sync_tiles()
	g.notify("已换 %d 张牌。" % count, 2.0)
	return true


func _after_scoring() -> void:
	if score >= int(rnd()["target"]):
		money += 4 + plays * 2 + (2 if round_i == 2 else 0)
		phase = "won_round"
		g.sfx("complete")
		if round_i == Cards.ROUNDS.size() - 1:
			_finish()
		return
	if plays <= 0:
		phase = "lost"
		g.sfx("error")
		return
	phase = "play"


func continue_after_round() -> void:
	if phase != "won_round":
		return
	if round_i + 1 < Cards.ROUNDS.size():
		_open_shop()


func _finish() -> void:
	g.flags["bai_introduction"] = true
	g.stats["poem_best"] = maxi(int(g.stats.get("poem_best", 0)), best_total)
	g.say("ch5_done", func() -> void:
		phase = "done"
		g.clear("ch5")
		g.show_card("qujiang"))


func retry_round() -> void:
	start_round(round_i)


## Exhaustive search over the hand for the highest-scoring legal line (荐句).
func best_line() -> Array:
	var best: Array = []
	var top := -1
	var n := hand_w.size()
	for f in range(hand_f.size()):
		for a in range(n):
			for b in range(n):
				if b == a:
					continue
				var s2 := [["w", a], ["w", b], ["f", f]]
				var v2 := int(_preview(s2)["total"])
				if v2 > top:
					top = v2
					best = s2
				for c in range(n):
					if c == a or c == b:
						continue
					var s3 := [["w", a], ["w", b], ["w", c], ["f", f]]
					var v3 := int(_preview(s3)["total"])
					if v3 > top:
						top = v3
						best = s3
	return best


func suggest() -> void:
	if phase != "play":
		return
	sel = best_line()
	g.hints_used += 1
	_sync_tiles()


# ================================================================== pick / shop
func _open_pick() -> void:
	phase = "pick"
	_sync_tiles()
	var ids := Cards.CHARMS.keys()
	_shuffle(ids)
	offers = []
	for id in ids.slice(0, 3):
		offers.append({"kind": "charm", "id": id, "cost": 0, "sold": false})


func choose(i: int) -> void:
	if i < 0 or i >= offers.size():
		return
	var o: Dictionary = offers[i]
	if o["sold"]:
		return
	if phase == "pick":
		charms.append(o["id"])
		g.sfx("pickup")
		start_round(0)
		return
	if phase != "shop":
		return
	if money < int(o["cost"]):
		g.notify("钱不够。")
		g.sfx("error", -10)
		return
	if o["kind"] == "charm":
		if charms.size() >= MAX_CHARMS:
			g.notify("诗友已满 %d 位。" % MAX_CHARMS)
			return
		charms.append(o["id"])
	elif o["kind"] == "word":
		deck_w.append(o["id"])
	else:
		deck_f.append(o["id"])
	money -= int(o["cost"])
	o["sold"] = true
	g.sfx("pickup", -6)


func _open_shop() -> void:
	phase = "shop"
	_sync_tiles()
	offers = []
	var ids := []
	for id in Cards.CHARMS:
		if not charms.has(id):
			ids.append(id)
	_shuffle(ids)
	for id in ids.slice(0, 2):
		offers.append({"kind": "charm", "id": id, "cost": int(Cards.CHARMS[id]["cost"]), "sold": false})
	# Feet in the next round's rhyme, and strong words, are what the player usually lacks.
	var next_rhyme: String = Cards.ROUNDS[round_i + 1]["rhyme"]
	var feet := []
	for f in Cards.FEET:
		if f["r"] == next_rhyme:
			feet.append(f["w"])
	_shuffle(feet)
	offers.append({"kind": "foot", "id": feet[0], "cost": 2, "sold": false})
	var words := []
	for w in Cards.WORDS:
		if not deck_w.has(w["w"]):
			words.append(w["w"])
	_shuffle(words)
	for w in words.slice(0, 2):
		offers.append({"kind": "word", "id": w, "cost": 3, "sold": false})


func leave_shop() -> void:
	if phase == "shop":
		start_round(round_i + 1)


# ================================================================== 3D table
## The lacquered table, a celadon cup and the tally tube are Blender models; the selected
## line appears as standing jade tiles on the table and flips up during scoring.
func _build_3d() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(1440, 900)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b89a7a")
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffd6a0")
	key.light_energy = 0.75
	key.rotation_degrees = Vector3(-50, -25, 0)
	key.shadow_enabled = true
	world.add_child(key)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffb35a")
	lamp.light_energy = 1.6
	lamp.omni_range = 4.0
	lamp.position = Vector3(1.3, 1.2, -0.4)
	world.add_child(lamp)
	cam = Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(0, 1.6, 2.35)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.05, -0.4), Vector3.UP)
	var table := _put("table", Vector3(0, 0, -0.3))
	_tint(table, Color(0.55, 0.42, 0.4))
	var runner := _put("runner", Vector3(0, 0.465, -0.3))
	_tint(runner, Color("755448"))
	cup = _put("cup", Vector3(1.15, 0.465, 0.0))
	_put("tube", Vector3(-1.3, 0.465, -0.65))
	_put("inkstone", Vector3(-1.1, 0.465, 0.05), 0.4)
	for k in ["jade", "jade_sel", "ink", "gold"]:
		var m := StandardMaterial3D.new()
		m.roughness = 0.25
		match k:
			"jade":
				m.albedo_color = Color("d9e6d6")
			"jade_sel":
				m.albedo_color = Color("f3e2b4")
				m.emission_enabled = true
				m.emission = Color("ffcf73")
				m.emission_energy_multiplier = 0.5
			"ink":
				m.albedo_color = Color("1a1410")
			"gold":
				m.albedo_color = Color("c9a24f")
				m.metallic = 0.8
		tile_mats[k] = m


## Multiplies the albedo of every surface below n (used to darken the lacquer).
func _tint(n: Node, c: Color) -> void:
	for child in n.get_children():
		_tint(child, c)
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		for i in range(mi.mesh.get_surface_count()):
			var m = mi.get_active_material(i)
			if m is BaseMaterial3D:
				var copy: BaseMaterial3D = m.duplicate()
				copy.albedo_color = copy.albedo_color * c
				mi.set_surface_override_material(i, copy)


func _put(name: String, p: Vector3, yaw := 0.0) -> Node3D:
	var path := "res://assets/models/poem_%s.glb" % name
	var n: Node3D = (load(path) as PackedScene).instantiate() if ResourceLoader.exists(path) else Node3D.new()
	n.position = p
	n.rotation.y = yaw
	world.add_child(n)
	return n


## One standing tile per syllable of the current selection (or of the line being scored).
func _sync_tiles() -> void:
	if not world:
		return
	for t in tiles_now:
		t.queue_free()
	tiles_now = []
	var cards: Array = []
	if phase == "scoring":
		cards = last.get("cards", [])
	elif phase == "play":
		cards = _cards_of(sel)
	var chars := Rules.text(cards)
	var n := chars.length()
	for i in range(n):
		var tile := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.15, 0.2, 0.04)
		body.mesh = bm
		body.material_override = tile_mats["jade_sel"] if phase == "scoring" else tile_mats["jade"]
		body.position.y = 0.1
		tile.add_child(body)
		var lab := Label3D.new()
		lab.text = chars[i]
		lab.font = g.heading
		lab.font_size = 96
		lab.pixel_size = 0.0012
		lab.modulate = Color("1a1410")
		lab.outline_size = 0
		lab.position = Vector3(0, 0.1, 0.022)
		tile.add_child(lab)
		tile.position = Vector3((i - (n - 1) * 0.5) * 0.18, 0.47, -0.3)
		tile.set_meta("i", i)
		world.add_child(tile)
		tiles_now.append(tile)


func _animate_3d(delta: float) -> void:
	if not world:
		return
	glow = maxf(0.0, glow - delta * 0.6)
	for t in tiles_now:
		var i: int = t.get_meta("i")
		var target_rot := 0.0
		var lift := 0.0
		if phase == "scoring":
			var k := clampf((score_t - i * 0.08) * 3.0, 0.0, 1.0)
			target_rot = -0.35 * (1.0 - k)
			lift = sin(k * PI) * 0.06
		t.rotation.x = lerpf(t.rotation.x, target_rot, delta * 10.0)
		t.position.y = 0.47 + lift + sin(age * 2.0 + i) * 0.004
	if cup:
		cup.rotation.y += delta * 0.25
		cup.position.y = 0.465 + glow * 0.03 * sin(age * 9.0)


# ================================================================== loop and input
func tick(delta: float, blocked: bool) -> void:
	_animate_3d(delta)
	if phase == "scoring" and not blocked:
		score_t += delta
		if score_t >= STEP_TIME * (last.get("steps", []).size() + 2):
			_after_scoring()


func key(event: InputEventKey) -> bool:
	if g.blocked():
		return false
	match phase:
		"play":
			match event.keycode:
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					play_line()
				KEY_BACKSPACE, KEY_X:
					discard()
				KEY_T:
					suggest()
				KEY_ESCAPE:
					if sel.is_empty():
						return false
					sel = []
					_sync_tiles()
				_:
					return false
			return true
		"scoring":
			if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
				score_t = 999.0
				return true
	return false


func mouse(event: InputEvent) -> bool:
	if phase == "play" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		sel = []
		_sync_tiles()
		return true
	return false


func act(id: String) -> void:
	if _common_act(id):
		return
	if id.begins_with("w_"):
		toggle("w", int(id.trim_prefix("w_")))
	elif id.begins_with("f_"):
		toggle("f", int(id.trim_prefix("f_")))
	elif id.begins_with("offer_"):
		choose(int(id.trim_prefix("offer_")))
	else:
		match id:
			"play":
				play_line()
			"discard":
				discard()
			"suggest":
				suggest()
			"next":
				continue_after_round()
			"leave_shop":
				leave_shop()
			"retry":
				retry_round()
			"to_map":
				g.go("ch6")


# ================================================================== drawing
func _draw() -> void:
	hit_regions.clear()
	var full := Rect2(0, 0, 1440, 900)
	if not _img_cover("feast", full):
		draw_rect(full, Color("2a1c18"))
	draw_rect(full, Color(0.02, 0.015, 0.01, 0.18))
	# The painting's own foreground table would show under the 3D one: fade it to dark wood.
	for i in range(40):
		var y := 330.0 + i * 12.0
		var k := clampf(float(i) / 14.0, 0.0, 1.0)
		draw_rect(Rect2(0, y, 1440, 12), Color(0.07, 0.04, 0.03, 0.97 * k))
	draw_rect(Rect2(0, 810, 1440, 90), Color(0.07, 0.04, 0.03, 0.97))
	if vp:
		draw_texture_rect(vp.get_texture(), full, false)
	var r := rnd()
	var goals := []
	for i in range(Cards.ROUNDS.size()):
		goals.append({"t": Cards.ROUNDS[i]["name"].split(" · ")[1], "d": "目标 %d 分" % Cards.ROUNDS[i]["target"], "done": i < round_i or phase == "done" or (i == round_i and phase == "won_round")})
	var obj := ""
	match phase:
		"play":
			obj = "2–3 张词牌 + 1 张韵脚可吟诗；按 X 换牌。"
		"scoring":
			obj = "吟诵中……"
		"done":
			obj = "白居易答应引见。去慈恩寺。"
	_frame("第五章  ·  曲江诗牌", "曲江 · 进士宴  /  贞元十六年 · 春", goals, obj, [])
	_hud(_draw_table_hud)


func _draw_table_hud() -> void:
	if phase in ["play", "scoring", "won_round", "lost"]:
		_draw_round_panel()
		_draw_charms(Vector2(40, 214))
	match phase:
		"play":
			_draw_hand()
			_draw_preview()
			_draw_actions()
		"scoring":
			_draw_scoring()
		"won_round":
			_draw_result(true)
		"lost":
			_draw_result(false)
		"pick", "shop":
			_draw_offers()
		"done":
			_draw_done()


## Round, rhyme, score / target, lines and swaps left, money.
func _draw_round_panel() -> void:
	var r := rnd()
	var box := Rect2(40, 150, 300, 52)
	_box(box, Color(0.02, 0.035, 0.04, 0.78), 4, Color(Pal.GOLD, 0.35))
	_t(box.position + Vector2(14, 22), str(r["name"]), 15, Pal.PAPER)
	_t(box.position + Vector2(14, 42), "限韵「%s」%s" % [r["rhyme"], ("  ·  禁「%s」" % r["ban"]) if r.has("ban") else ""], 12, Pal.GOLD)
	var sc := Rect2(560, 30, 320, 64)
	_box(sc, Color(0.02, 0.035, 0.04, 0.78), 4, Color(Pal.GOLD, 0.5))
	_tc(720, 62, "%d / %d" % [score, int(r["target"])], 26, Pal.PAPER if score < int(r["target"]) else Color("ffe7b0"))
	var k := clampf(float(score) / float(r["target"]), 0.0, 1.0)
	cv.draw_rect(Rect2(sc.position + Vector2(14, 48), Vector2(sc.size.x - 28, 5)), Color(0, 0, 0, 0.5))
	cv.draw_rect(Rect2(sc.position + Vector2(14, 48), Vector2((sc.size.x - 28) * k, 5)), Pal.GOLD)
	_tc(720, 116, "吟诗 %d  ·  换字 %d  ·  钱 %d" % [plays, discards, money], 14, Pal.SOFT)


func _draw_charms(at: Vector2) -> void:
	_t(at + Vector2(0, 16), "诗友", 13, Pal.GOLD)
	for i in range(charms.size()):
		var ch: Dictionary = Cards.CHARMS[charms[i]]
		var r := Rect2(at + Vector2(0, 28 + i * 62), Vector2(300, 56))
		var hover := r.has_point(_mouse())
		_box(r, Color(0.02, 0.035, 0.04, 0.82 if hover else 0.68), 4, Color(Pal.GOLD, 0.7 if hover else 0.3))
		_t(r.position + Vector2(12, 22), "%s · %s" % [ch["who"], ch["name"]], 15, Pal.PAPER)
		_t(r.position + Vector2(12, 43), str(ch["desc"]), 12, Pal.MUTED)
		if hover:
			var tip := Rect2(r.end.x + 10, r.position.y, 360, 56)
			_box(tip, Color(0.02, 0.035, 0.04, 0.92), 4, Color(Pal.GOLD, 0.4))
			_wrap(tip.position + Vector2(12, 22), str(ch["lore"]), 336, 12, Pal.SOFT, 18)


## One card face: tone marks at the top, the word, image tags at the bottom.
func _card_face(r: Rect2, c: Dictionary, is_foot: bool, chosen: bool, order: int) -> void:
	var hover := r.has_point(_mouse())
	var lift := -18.0 if chosen else (-6.0 if hover else 0.0)
	r.position.y += lift
	cv.draw_rect(Rect2(r.position + Vector2(4, 8), r.size), Color(0, 0, 0, 0.35))
	var face := Color("efe3c6") if not is_foot else Color("e8d6ae")
	if g.tex.has("poetry_card"):
		_img("poetry_card", r, Color("fff4d3") if chosen else (Color("f1e7d4") if is_foot else Color.WHITE))
		if chosen:
			_box(r.grow(2), Color(0, 0, 0, 0), 4, Pal.GOLD, 2)
	else:
		_box(r, face, 4, Pal.GOLD if chosen else Color(0.35, 0.25, 0.14, 0.8), 2 if chosen else 1)
	var tones: String = c["p"]
	for k in range(tones.length()):
		var p := r.position + Vector2(r.size.x * 0.5 + (k - (tones.length() - 1) * 0.5) * 18, 32)
		if tones[k] == "P":
			cv.draw_arc(p, 6, 0, TAU, 20, Color("2b5d52"), 2, true)
		else:
			cv.draw_circle(p, 6, Color("8f2f22"))
	var word: String = c["w"]
	var word_size := _fit_size(g.heading, word, 50 if is_foot else 40, r.size.x - 18)
	_title_center(r.get_center().x, r.position.y + (86 if is_foot else 86), word, word_size, Color("1d1712"))
	if is_foot:
		_tc(r.get_center().x, r.position.y + 108, "%s韵" % c["r"] if c["p"] == "P" else "仄声", 11, Color("8f2f22") if c["r"] == rnd()["rhyme"] and c["p"] == "P" else Color("6a5636"))
	var tags: Array = c["tag"]
	if not tags.is_empty():
		_tc(r.get_center().x, r.end.y - 19, "·".join(tags), 10, Color("6a5636"))
	if order > 0:
		cv.draw_circle(r.position + Vector2(14, 14), 10, Pal.GOLD)
		_tc(r.position.x + 14, r.position.y + 19, str(order), 12, Pal.INK)


func _draw_hand() -> void:
	var gap := 8.0
	var x := 40.0
	for i in range(hand_w.size()):
		var r := Rect2(Vector2(x, HAND_Y), CARD)
		var order := 0
		for k in range(sel.size()):
			if sel[k] == ["w", i]:
				order = k + 1
		_card_face(r, Rules.word(hand_w[i]), false, order > 0, order)
		_register("w_%d" % i, r.grow_individual(0, 20, 0, 0))
		x += CARD.x + gap
	x += 30
	for i in range(hand_f.size()):
		var r := Rect2(Vector2(x, HAND_Y), CARD)
		var chosen := sel.has(["f", i])
		_card_face(r, Rules.foot(hand_f[i]), true, chosen, 0)
		_register("f_%d" % i, r.grow_individual(0, 20, 0, 0))
		x += CARD.x + gap
	_t(Vector2(40, HAND_Y - 28), "词牌  ·  牌堆 %d" % pile_w.size(), 12, Pal.GOLD)
	_t(Vector2(40 + 6 * (CARD.x + gap) + 30, HAND_Y - 28), "韵脚  ·  牌堆 %d" % pile_f.size(), 12, Pal.GOLD)


## Live preview of the selected line: tone pattern, the hands it makes and the score.
func _draw_preview() -> void:
	if sel.is_empty():
		_tc(720, 660, "点选词牌与韵脚。 ○ 平   ● 仄", 15, Color(Pal.PAPER, 0.8))
		return
	var cards := _cards_of(sel)
	var r := Rules.score_line(cards, prev_line, charms, rnd())
	var box := Rect2(420, 610, 600, 80)
	_box(box, Color(0.02, 0.035, 0.04, 0.82), 4, Color(Pal.GOLD, 0.45))
	if not r["ok"]:
		_tc(720, 638, "按 X 换牌", 15, Pal.GOLD)
		_title_center(720, 666, Rules.text(cards), 26, Pal.PAPER)
		_tc(720, 688, "吟诗需 2–3 张词牌 + 1 张韵脚", 12, Pal.MUTED)
		return
	var tags := []
	tags.append("合律" if r["lu"] else "失律")
	tags.append("押韵" if r["rhyme"] else "未押韵")
	if r["pair"]:
		tags.append("对仗")
	_title_center(650, 643, Rules.text(cards), 27, Pal.PAPER)
	_t(Vector2(856, 641), "  ".join(tags), 12, Pal.GOLD)
	_tc(720, 675, "%d 墨  ×  %s 韵  =  %d" % [int(r["chips"]), _fmt(float(r["mult"])), int(r["total"])], 18, Color("ffe7b0"))


func _fmt(x: float) -> String:
	return str(int(x)) if absf(x - round(x)) < 0.01 else "%.1f" % x


func _draw_actions() -> void:
	_button("play", Rect2(1198, 730, 210, 64), "吟诗  Enter", true, 18, plays > 0 and Rules.is_line(_cards_of(sel)))
	_button("discard", Rect2(1198, 802, 102, 40), "换牌  X", false, 13, discards > 0 and not sel.is_empty())
	_button("suggest", Rect2(1306, 802, 102, 40), "荐句  T", false, 13)
	_t(Vector2(1198, 866), "已选 %d / %d" % [sel.size(), MAX_SELECTED], 12, Pal.MUTED)
	_round_button("journal", Vector2(1236, 676), "札", "")
	_round_button("hint", Vector2(1296, 676), "？", "")
	if not prev_line.is_empty():
		var s := "上句：" + Rules.text(prev_line)
		_t(Vector2(1180 - _tw(s, 12), 718), s, 12, Pal.MUTED)


## Scoring reveal: the steps light up one by one, then 墨 × 韵 = total.
func _draw_scoring() -> void:
	var steps: Array = last.get("steps", [])
	var shown := int(score_t / STEP_TIME)
	_title_center(720, 386, str(last["text"]), 46, Color("ffe7b0"))
	var box := Rect2(546, 420 + 0.0, 348, 40 + steps.size() * 30)
	box.position.y = 690 - box.size.y
	_box(box, Color(0.02, 0.035, 0.04, 0.85), 4, Color(Pal.GOLD, 0.5))
	for i in range(mini(shown, steps.size())):
		var y := box.position.y + 30 + i * 30
		_t(Vector2(box.position.x + 16, y), str(steps[i][0]), 14, Pal.PAPER)
		var v: String = steps[i][1]
		_t(Vector2(box.end.x - 16 - _tw(v, 14), y), v, 14, Pal.GOLD if v.contains("韵") else Color("9fd8ff"))
	if shown > steps.size():
		_tc(720, 746, "%d 墨  ×  %s 韵  =  %d" % [int(last["chips"]), _fmt(float(last["mult"])), int(last["total"])], 28, Pal.PAPER)
	_tc(720, 870, "Enter 跳过", 11, Pal.MUTED)


func _draw_result(won: bool) -> void:
	_modal_back(0.55)
	var card := Rect2(460, 260, 520, 320)
	_panel(card)
	var r := rnd()
	_title_center(720, 320, (str(r["name"]) + " · 过关") if won else "酒令未成", 34, Pal.PAPER if won else Color("ffb0a0"))
	_tc(720, 362, "得分 %d / %d" % [score, int(r["target"])], 18, Pal.GOLD)
	if not last.is_empty():
		_tc(720, 400, "末句「%s」  %d 分" % [last["text"], int(last["total"])], 15, Pal.SOFT)
	if won:
		_tc(720, 436, "赏钱 %d  ·  剩余吟诗 %d 次各 +2" % [money, plays], 14, Pal.MUTED)
		if round_i + 1 < Cards.ROUNDS.size():
			_button("next", Rect2(580, 490, 280, 50), "去诗友铺", true, 18)
	else:
		_tc(720, 436, "提示：按「荐句」看看手里最好的一句。", 14, Pal.MUTED)
		_button("retry", Rect2(580, 490, 280, 50), "重来这一巡", true, 18)


## Charm pick (start) and the shop between rounds.
func _draw_offers() -> void:
	_modal_back(0.5)
	var shop := phase == "shop"
	_img("ui_cloud_rule", Rect2(420, 157, 600, 16), Color(1, 1, 1, 0.7))
	_title_center(720, 216, "诗友铺" if shop else "择一位诗友同席", 40, Pal.PAPER)
	_tc(720, 250, "钱 %d  ·  诗友 %d / %d" % [money, charms.size(), MAX_CHARMS] if shop else "诗友会在每次吟诗时给出加成。", 15, Pal.GOLD)
	var n := offers.size()
	var w := 230.0
	var x0 := 720.0 - (n * (w + 16) - 16) * 0.5
	for i in range(n):
		var o: Dictionary = offers[i]
		var r := Rect2(x0 + i * (w + 16), 280, w, 300)
		var hover: bool = r.has_point(_mouse()) and not o["sold"]
		_box(r, Color(0.025, 0.052, 0.047, 0.97), 8, Color(Pal.GOLD, 0.9 if hover else 0.4))
		_img("ui_corner_tl", Rect2(r.position + Vector2(4, 4), Vector2(35, 35)), Color(1, 1, 1, 0.65))
		_img("ui_corner_br", Rect2(r.end - Vector2(39, 39), Vector2(35, 35)), Color(1, 1, 1, 0.65))
		if o["sold"]:
			_tc(r.get_center().x, r.get_center().y, "已购", 22, Pal.MUTED)
			continue
		match o["kind"]:
			"charm":
				var ch: Dictionary = Cards.CHARMS[o["id"]]
				_serif_center(r.get_center().x, r.position.y + 40, str(ch["who"]), 17, Pal.GOLD)
				_title_center(r.get_center().x, r.position.y + 80, str(ch["name"]), 29, Pal.PAPER)
				cv.draw_line(r.position + Vector2(28, 97), r.position + Vector2(w - 28, 97), Color(Pal.GOLD, 0.35), 1.0)
				_wrap(r.position + Vector2(18, 120), str(ch["desc"]), w - 36, 15, Pal.SOFT, 24)
				_serif_wrap(r.position + Vector2(18, 196), str(ch["lore"]), w - 36, 14, Pal.SOFT, 22)
			_:
				var c: Dictionary = Rules.word(o["id"]) if o["kind"] == "word" else Rules.foot(o["id"])
				_tc(r.get_center().x, r.position.y + 40, "新词牌" if o["kind"] == "word" else "新韵脚", 14, Pal.GOLD)
				_card_face(Rect2(r.get_center().x - CARD.x * 0.5, r.position.y + 70, CARD.x, CARD.y), c, o["kind"] == "foot", false, 0)
		if shop:
			_tc(r.get_center().x, r.end.y - 18, "%d 钱" % int(o["cost"]), 16, Pal.PAPER if money >= int(o["cost"]) else Pal.RED)
		_register("offer_%d" % i, r)
	if shop:
		_button("leave_shop", Rect2(600, 620, 240, 48), "入席 · " + str(Cards.ROUNDS[round_i + 1]["name"]), true, 15)


func _draw_done() -> void:
	_figure("npc_bai", Vector2(1180, 900), 640)
	var box := Rect2(80, 560, 560, 160)
	_box(box, Color(0.02, 0.035, 0.04, 0.85), 4, Color(Pal.GOLD, 0.5))
	_title(box.position + Vector2(24, 44), "满座传诵", 34, Pal.PAPER)
	_serif_wrap(box.position + Vector2(24, 80), "白居易答应在慈恩寺塔下题名之后，替苏晴与阿拾向寺僧引见。本章最佳一句 %d 分。" % int(g.stats.get("poem_best", best_total)), 510, 16, Pal.SOFT, 26)
	_button("to_map", Rect2(1196, 756, 212, 44), "前往慈恩寺  ›", true, 15)
