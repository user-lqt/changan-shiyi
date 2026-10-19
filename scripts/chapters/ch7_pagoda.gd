extends "res://scripts/core/canvas.gd"
## 第七章 · 大雁塔顶
## Part A: explore the top floor; the stele gives the moon-phase order (朔 → 弦 → 望).
## Part B: a Touhou-style vertical danmaku stage run in four stages:
##   Stage 1 塔檐  wave1   paper cranes, divers and a great wisp; build power and points
##   Stage 2 铃廊  wave2   lanterns with bouncing orbs and amulet fans; 镜魅 glimpsed at the end
##   Stage 3 镜魅·第一形态   non1 通常「镜尘」 → bells 月符「月相三铃」(shoot the bells in stele order)
##   Stage 4 镜魅·第二形态   shatter 通常「碎镜」 → mirror 镜符「镜中镜」(only 山 月 水 is real)
##                         → final 终符「千年月华」(survival card)
## Music: Shanghai Teahouse for the opening waves (at least 94 s), boss7 from stage 3.
## Items: P / 大P raise power 0–4 (changes the shot), 点 scores more when collected high and
## every 25 extends a life, 镜 = bomb, 命 = extra life, F = full power. Flying above the
## collection line pulls in every item on screen.
## Hidden code: type Z U N anywhere for unlimited lives and bombs (g.zun_mode in main.gd).
## Controls: arrows / WASD move, Shift focus, Z shoot, X bomb, Esc pause.

const FIELD := Rect2(400, 30, 640, 840)
const STEP := 1.0 / 60.0
const PHASES := [
	{"kind": "wave1", "stage": 1, "name": "塔檐 · 纸鹤夜飞", "spell": false, "hp": 1.0, "time": 44.0, "line": ""},
	{"kind": "wave2", "stage": 2, "name": "铃廊 · 长明灯", "spell": false, "hp": 1.0, "time": 50.0, "line": ""},
	{"kind": "non1", "stage": 3, "name": "镜术「镜尘」", "spell": false, "hp": 300.0, "time": 28.0, "line": ""},
	{"kind": "bells", "stage": 3, "name": "月阵「月相三铃」", "spell": true, "hp": 240.0, "time": 50.0, "line": "鸣铃之序，铭于塔碑。"},
	{"kind": "shatter", "stage": 4, "name": "镜术「碎镜」", "spell": false, "hp": 320.0, "time": 26.0, "line": ""},
	{"kind": "mirror", "stage": 4, "name": "镜阵「镜中镜」", "spell": true, "hp": 240.0, "time": 45.0, "line": "真身记得工坊石壁上的顺序。"},
	{"kind": "final", "stage": 4, "name": "终阵「千年月华」", "spell": true, "hp": 1.0, "time": 18.0, "line": "撑过这一阵月华！"},
]
const STAGES := {
	1: {"title": "第一境", "name": "塔檐", "sub": "纸鹤乘月，绕塔而飞"},
	2: {"title": "第二境", "name": "铃廊", "sub": "长明灯下，铃声不绝"},
	3: {"title": "第三境", "name": "镜魅 · 第一形态", "sub": "沉睡千年的镜中之灵"},
	4: {"title": "第四境", "name": "镜魅 · 第二形态", "sub": "镜碎之后，月华倾泻"},
}
const WAVES := ["wave1", "wave2"]
const POC_Y := 250.0            # item collection line (absolute y)
const EXTEND_EVERY := 25        # 点 items per extra life
const MAX_POWER := 4.0
const ENDING_DURATION := 5.8
const ITEM_INFO := {
	"p": {"label": "光", "color": Color("ff6f5e"), "size": 9.0},
	"P": {"label": "光", "color": Color("ff4a3a"), "size": 15.0},
	"pt": {"label": "辉", "color": Color("5f9dff"), "size": 10.0},
	"star": {"label": "", "color": Color("fff2b0"), "size": 4.0},
	"bomb": {"label": "月", "color": Color("5fd38a"), "size": 13.0},
	"life": {"label": "灯", "color": Color("ff7fc6"), "size": 13.0},
	"full": {"label": "盈", "color": Color("ffd24a"), "size": 14.0},
}
const BELL_ORDER := [0, 1, 2]                 # 朔, 弦, 望
const PERMS := [[0, 1, 2], [2, 1, 0], [1, 0, 2], [0, 2, 1], [2, 0, 1], [1, 2, 0]]
const SPOT := {
	"stele": {"p": Vector2(88, 300), "label": "顶层石碑", "r": Rect2(40, 300, 115, 190)},
	"window": {"p": Vector2(540, 250), "label": "塔窗", "r": Rect2(420, 230, 240, 250)},
	"bells": {"p": Vector2(180, 230), "label": "檐下风铃", "r": Rect2(140, 180, 90, 140)},
	"disk": {"p": Vector2(538, 590), "label": "三环铜盘", "r": Rect2(400, 560, 300, 110)},
}

var mode := "explore"           # explore | battle | ending | farewell | won
var read_stele := false
var seen := {}
# --- battle state
var acc := 0.0
var bt := 0.0                   # time inside phase
var phase := 0
var boss_hp := 0.0
var boss_pos := Vector2(720, 170)
var boss_flash := 0.0
var player := Vector2(720, 760)
var player_lean := 0.0         # Visual bank only; player remains the collision centre.
var player_focus := 0.0
var player_hurt_t := 0.0
var lives := 3
var bombs := 2
var invuln := 0.0
var bomb_t := 0.0
var shot_cd := 0.0
var score := 0
var graze := 0
var easy := false
var paused := false
var game_over := false
var banner := 0.0
var msg := ""
var msg_t := 0.0
var shield := false
var shield_t := 0.0
var bells: Array = []           # {pos, phase, hit}
var bell_progress := 0
var images: Array = []          # {pos, perm, real, alpha}
var swap_t := 0.0
var spawn := {}
# Bullets in parallel packed arrays for speed.
var bp := PackedVector2Array()
var bv := PackedVector2Array()
var br := PackedFloat32Array()
var bc := PackedInt32Array()
var bg := PackedByteArray()     # already grazed
var bs := PackedByteArray()     # shape: 0 orb 1 rice 2 kunai 3 big orb 4 star 5 amulet
var bb := PackedByteArray()     # behaviour: 0 plain 1 accelerate 2 curve 3 bounce 4 split 5 delayed aim
var ba := PackedFloat32Array()  # age
var bx := PackedFloat32Array()  # behaviour parameter (accel / angular speed / split time / aim speed)
# Player shots: position, velocity, homing flag.
var ps := PackedVector2Array()
var pv := PackedVector2Array()
var ph := PackedByteArray()
var lasers: Array = []          # {o, a, w, warn, life, t}
var enemies: Array = []         # {pos, vel, hp, t, kind, fire}
var items: Array = []           # {pos, vel, kind, home}
var popups: Array = []          # {pos, text, t, color}
var power := 0.0
var points := 0                 # 点 collected this fight
var next_extend := EXTEND_EVERY
var spell_clean := true         # no death / bomb during the current spell card
var bonus_text := ""
var bonus_t := 0.0
var full_flash := 0.0
var sparks: Array[Vector4] = [] # x, y, age, kind
var stars: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var keys := {}                  # injected keys for tests
var clear_t := 0.0              # stage-clear / mirror-shatter interlude before the next phase
var clear_text := ""
var title_t := 0.0              # stage title card
var cutin_t := 0.0              # spell card portrait cut-in
var shatter_t := 0.0            # mirror shatter flash between the boss forms
var ending_t := 0.0             # remaining time in the victory scene
var ending_elapsed := 0.0
var ending_music: Tween
var cameo := false              # 镜魅 glimpsed at the end of stage 2
var stage_points := 0           # 点 collected in the current stage (for the clear bonus)
var backdrop := "ch7_rooftops"
var previous_backdrop := ""
var backdrop_blend := 1.0


func enter() -> void:
	g.music("ambient")
	read_stele = bool(g.flags.get("tower_ascent_done", false)) and bool(g.flags.get("bell_order_known", false))
	rng.seed = 2026
	for i in range(80):
		stars.append(Vector3(rng.randf_range(FIELD.position.x, FIELD.end.x), rng.randf_range(0, 900), rng.randf_range(0.3, 1.0)))
	g.say("ch7_arrive")


func chrome() -> bool:
	return mode == "explore"


func staged() -> bool:
	return mode == "explore"


func bottom_hud() -> bool:
	return mode == "explore"


func help_lines() -> Array:
	if mode == "battle":
		return ["方向键 / WASD 移动；Shift 慢行并显示判定点。",
			"按住 Z 发射镜芒；X 释放护身月华；Esc 暂停。",
			"「光」增强镜力，满级附带追踪灵符；受击会散落微光。",
			"「辉」在高处收取加分更多，每 25 枚续一盏护魂灯。",
			"魂灯尽可重试；贴近流光可得分；越过引光线收取灵物。",
			"三铃按朔→弦→望击响；镜中镜只打「山 月 水」的真身。"]
	return ["点击发光标记调查。先读石碑，再触碰三环铜盘。"]


func journal_lines() -> Array:
	var out := []
	if read_stele:
		out.append("塔碑：塔顶三铃，以月为序：先朔，次弦，后望。（朔＝无月，弦＝半月，望＝满月）")
	out.append("工坊石壁：山 → 月 → 水。")
	return out


func hint() -> String:
	if mode == "explore":
		return "先看看左边的石碑，再点击中间的三环铜盘。" if not read_stele else "点击中间的三环铜盘。"
	match kind():
		"wave1":
			return "纸鹤与光灵散去后留下微光和月辉，收集微光可增强镜力。纸鹤俯冲时，向左右避让。"
		"wave2":
			return "长明灯灵力充盈，会放出反弹的月华珠与追身灵符。月华珠稍后会散成流光，提前避让。"
		"non1":
			return "流光沿弧线回旋，别贴得太近。镜棱会朝你飞来，横向移动即可避开。"
		"bells":
			return "镜障未破时无法伤到镜魅。依次击响无月（朔）→ 半月（弦）→ 满月（望）的风铃。站在铃下发出镜芒。"
		"shatter":
			return "旋转的镜片弹幕有固定的缝隙，跟着转向慢慢移动。花瓣弹会散开，留在外侧更安全。"
		"mirror":
			return "三个镜像里，只有下方纹样排成「山 月 水」的是真身。打错会被反射。"
		"final":
			return "守住最后一阵月华，撑到倒计时结束。月华光束凝成前会显出细线，看到就及时避开。"
	return "按住 Shift 可以低速精确躲避。"


func kind() -> String:
	return str(PHASES[phase]["kind"])


func stage() -> int:
	return int(PHASES[phase]["stage"])


## True while 镜魅 herself is on the field and can be hit.
func boss_active() -> bool:
	return not WAVES.has(kind()) and kind() != "mirror"


func boss_visible() -> bool:
	return boss_active() or cameo


func power_level() -> int:
	return int(floor(power))


# ================================================================== explore
func act(id: String) -> void:
	if _common_act(id):
		return
	match id:
		"continue_story":
			if mode == "won":
				g.go("finale")
		"stele":
			read_stele = true
			g.show_card("stele")
		"window":
			g.show_card("window")
		"bells":
			g.sfx("bell")
			g.notify("檐下挂着三只铜铃。风一吹，声音一沉、一清、一亮。")
		"disk":
			if not read_stele:
				g.notify("铜盘上刻着三圈月相……先看看石碑上写了什么。")
			else:
				g.say("boss_prelude", start_battle)
		"retry":
			_retry(false)
		"retry_easy":
			_retry(true)
		"resume":
			paused = false
		"restart":
			g.restart_current_chapter()
		"leave", "menu_map":
			g.return_from_menu("map")
		"menu_title":
			g.return_from_menu("title")
		"settings":
			g.overlay.open_settings()
		"to_map":
			g.go("map")


func start_battle() -> void:
	mode = "battle"
	lives = 3
	bombs = 2
	score = 0
	graze = 0
	power = 0.0
	points = 0
	next_extend = EXTEND_EVERY
	items = []
	game_over = false
	ending_t = 0.0
	ending_elapsed = 0.0
	g.current_music = ""  # Start the opening song from its beginning for a new battle.
	_start_phase(0)
	if g.zun_mode:
		_say("月华护佑：护魂灯与月华不减。", 3.0)


## fresh = entering the phase normally (title cards, story lines); false when retrying.
func _start_phase(i: int, fresh := true) -> void:
	var new_stage := i == 0 or int(PHASES[i - 1]["stage"]) != int(PHASES[i]["stage"])
	var next_backdrop := "ch7_rooftops" if int(PHASES[i]["stage"]) == 1 else ("ch7_gallery" if int(PHASES[i]["stage"]) == 2 else "ch7_realm")
	if next_backdrop != backdrop:
		previous_backdrop = backdrop
		backdrop = next_backdrop
		backdrop_blend = 0.0
	phase = i
	bt = 0.0
	player_lean = 0.0
	player_focus = 0.0
	player_hurt_t = 0.0
	clear_t = 0.0
	cameo = false
	boss_hp = PHASES[i]["hp"]
	var spell: bool = PHASES[i]["spell"]
	banner = 2.4 if spell else 0.0
	cutin_t = 1.6 if spell else 0.0
	spawn = {}
	shield = kind() == "bells"
	bell_progress = 0
	spell_clean = true
	enemies = []
	lasers = []
	_clear_bullets(false)
	invuln = 1.5
	g.music("boss7" if stage() >= 3 else "stage7", false)
	if new_stage:
		title_t = 3.0
		stage_points = points
		player = Vector2(FIELD.get_center().x, FIELD.end.y - 90)
		# Boss enters from above the field.
		boss_pos = Vector2(FIELD.get_center().x, FIELD.position.y - 120)
	if kind() == "bells":
		_place_bells()
	if kind() == "mirror":
		_place_images()
	if spell:
		g.sfx("reveal", -8)
		_say(str(PHASES[i]["line"]), 3.5)
	if fresh and new_stage and stage() == 3:
		g.say("boss_intro")
	elif fresh and new_stage and stage() == 4:
		g.say("boss_form2")


func _say(t: String, d := 3.0) -> void:
	msg = t
	msg_t = d


func _place_bells() -> void:
	var xs := [FIELD.position.x + 120, FIELD.get_center().x, FIELD.end.x - 120]
	var order: Array = PERMS[rng.randi_range(0, PERMS.size() - 1)]
	bells = []
	for i in range(3):
		bells.append({"pos": Vector2(xs[i], 330 + i % 2 * 70), "phase": order[i], "hit": false, "home": xs[i]})
	bell_progress = 0


func _place_images() -> void:
	var real_slot := rng.randi_range(0, 2)
	var fakes := [[2, 1, 0], [1, 0, 2], [0, 2, 1], [2, 0, 1], [1, 2, 0]]
	fakes.shuffle()
	images = []
	for i in range(3):
		var real := i == real_slot
		images.append({"pos": Vector2(FIELD.position.x + 140 + i * 180, 190), "perm": [0, 1, 2] if real else fakes[i], "real": real, "alpha": 0.0})
	swap_t = 7.5


# ================================================================== input
func key(event: InputEventKey) -> bool:
	if mode != "battle":
		return false
	if event.keycode == KEY_ESCAPE and not game_over:
		paused = not paused
		g.sfx("click")
	elif event.keycode == KEY_X and not paused and not game_over:
		_bomb()
	return true


func _down(names: Array) -> bool:
	for k in names:
		if keys.get(k, false) or Input.is_physical_key_pressed(k):
			return true
	return false


# ================================================================== simulation
func tick(delta: float, blocked: bool) -> void:
	msg_t = maxf(0.0, msg_t - delta)
	if not blocked and not paused:
		backdrop_blend = minf(1.0, backdrop_blend + delta * 0.65)
	if mode == "ending":
		if not blocked:
			_advance_ending(delta)
		return
	if mode != "battle" or blocked or paused or game_over:
		return
	acc = minf(acc + delta, STEP * 4)
	while acc >= STEP:
		acc -= STEP
		step(STEP)


func step(dt: float) -> void:
	if mode == "ending":
		_advance_ending(dt)
		return
	if mode != "battle":
		return
	var interlude := clear_t > 0
	if not interlude:
		bt += dt
	banner = maxf(0.0, banner - dt)
	invuln = maxf(0.0, invuln - dt)
	bomb_t = maxf(0.0, bomb_t - dt)
	boss_flash = maxf(0.0, boss_flash - dt)
	bonus_t = maxf(0.0, bonus_t - dt)
	full_flash = maxf(0.0, full_flash - dt)
	player_hurt_t = maxf(0.0, player_hurt_t - dt)
	_move_player(dt)
	_move_boss(dt)
	if not interlude:
		_patterns(dt)
	_update_enemies(dt)
	_update_shots(dt)
	_update_bullets(dt)
	_update_lasers(dt)
	_update_items(dt)
	_update_puzzles(dt)
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i].z += dt
		if sparks[i].z > 0.5:
			sparks.remove_at(i)
	for i in range(popups.size() - 1, -1, -1):
		popups[i]["t"] += dt
		popups[i]["pos"].y -= 30.0 * dt
		if popups[i]["t"] > 0.9:
			popups.remove_at(i)
	title_t = maxf(0.0, title_t - dt)
	cutin_t = maxf(0.0, cutin_t - dt)
	shatter_t = maxf(0.0, shatter_t - dt)
	if game_over:
		return
	if clear_t > 0:
		clear_t -= dt
		if clear_t <= 0:
			_start_phase(phase + 1)
		return
	# Phase end conditions.
	var limit: float = PHASES[phase]["time"]
	if WAVES.has(kind()):
		# Waves end on the clock once the last enemies have left (or after a short grace).
		if bt >= limit and (enemies.is_empty() or bt >= limit + 4.0):
			_phase_clear(true)
	elif kind() == "final":
		boss_hp = 1.0 - bt / limit
		if bt >= limit:
			_phase_clear(true)
	elif boss_hp <= 0:
		_phase_clear(true)
	elif bt >= limit:
		_say("月华渐散，镜魅收起了这一阵。", 2.5)
		_phase_clear(false)


func _move_player(dt: float) -> void:
	var dir := Vector2.ZERO
	if _down([KEY_LEFT, KEY_A]):
		dir.x -= 1
	if _down([KEY_RIGHT, KEY_D]):
		dir.x += 1
	if _down([KEY_UP, KEY_W]):
		dir.y -= 1
	if _down([KEY_DOWN, KEY_S]):
		dir.y += 1
	var focus := _down([KEY_SHIFT])
	var speed := 170.0 if focus else 360.0
	var follow := 1.0 - exp(-dt * 12.0)
	player_lean = lerpf(player_lean, dir.x * (0.07 if focus else 0.16), follow)
	player_focus = lerpf(player_focus, 1.0 if focus else 0.0, follow)
	player += dir.normalized() * speed * dt
	player.x = clampf(player.x, FIELD.position.x + 14, FIELD.end.x - 14)
	player.y = clampf(player.y, FIELD.position.y + 30, FIELD.end.y - 18)
	shot_cd -= dt
	if _down([KEY_Z, KEY_J]) and shot_cd <= 0:
		shot_cd = 0.066
		fire(focus)
		g.sfx("shoot", -24)


## Upgrades add needles and amulets in a narrow fan; focus further tightens the pattern.
## The bell puzzle uses parallel shots at every level, including the extra amulets.
func fire(focus: bool) -> void:
	var lv := power_level()
	var up := Vector2(0, -900)
	var precise := kind() == "bells"
	var gap := 5.0 if precise else (7.0 if focus else 12.0)
	_pshot(player + Vector2(-gap, -14), up)
	_pshot(player + Vector2(gap, -14), up)
	if lv >= 1:
		_pshot(player + Vector2(0, -20), up)
	if lv >= 2:
		var a := 0.0 if precise else (0.014 if focus else 0.065)
		var side := 9.0 if precise else (11.0 if focus else 16.0)
		_pshot(player + Vector2(-side, -6), up.rotated(-a))
		_pshot(player + Vector2(side, -6), up.rotated(a))
	if lv >= 3:
		var b := 0.0 if precise else (0.028 if focus else 0.11)
		var side := 13.0 if precise else (15.0 if focus else 22.0)
		_pshot(player + Vector2(-side, 0), up.rotated(-b))
		_pshot(player + Vector2(side, 0), up.rotated(b))
	if lv >= 4 and int(bt * 15.0) % 2 == 0:
		var side := 17.0 if precise else (19.0 if focus else 27.0)
		var outward := 0.0 if precise or focus else 65.0
		_pshot(player + Vector2(-side, 6), Vector2(-outward, -740), not precise)
		_pshot(player + Vector2(side, 6), Vector2(outward, -740), not precise)


func _pshot(p: Vector2, v: Vector2, homing := false) -> void:
	ps.append(p)
	pv.append(v)
	ph.append(1 if homing else 0)


func _move_boss(dt: float) -> void:
	var target := Vector2(FIELD.get_center().x + sin(bt * 0.6) * 170.0, 170 + sin(bt * 1.1) * 25.0)
	if WAVES.has(kind()):
		# Off-stage, except for the brief glimpse at the end of stage 2.
		target = Vector2(FIELD.get_center().x, FIELD.position.y - 160)
		if cameo and bt < PHASES[phase]["time"] + 1.4:
			target = Vector2(FIELD.get_center().x, 190)
	elif kind() == "mirror":
		target = Vector2(FIELD.get_center().x, -200)   # boss hides among the images
	elif kind() == "final" or kind() == "shatter":
		target = Vector2(FIELD.get_center().x + sin(bt * 0.4) * 60.0, 160)
	if clear_t > 0 and stage() == 3:
		target = Vector2(FIELD.get_center().x, 200)    # holds still while the mirror cracks
	boss_pos = boss_pos.lerp(target, minf(1.0, dt * 2.0))


func _update_shots(dt: float) -> void:
	var np := PackedVector2Array()
	var nv := PackedVector2Array()
	var nh := PackedByteArray()
	for i in range(ps.size()):
		var s := ps[i]
		var v := pv[i]
		if ph[i] == 1:
			var tgt := _homing_target(s)
			if tgt.x > -9000:
				var want := (tgt - s).normalized() * 700.0
				v = v.lerp(want, minf(1.0, dt * 6.0))
		s += v * dt
		if not FIELD.grow(10).has_point(s):
			continue
		if _shot_hits(s, 0.6 if ph[i] == 1 else 1.0):
			sparks.append(Vector4(s.x, s.y, 0, 0))
			continue
		np.append(s)
		nv.append(v)
		nh.append(ph[i])
	ps = np
	pv = nv
	ph = nh


## Nearest enemy, otherwise the boss (or the real mirror image). x = -9999 when nothing.
func _homing_target(from: Vector2) -> Vector2:
	var best := Vector2(-9999, 0)
	var bd := 1e9
	for e in enemies:
		var d: float = from.distance_squared_to(e["pos"])
		if d < bd:
			bd = d
			best = e["pos"]
	if best.x > -9000 or (not boss_active() and kind() != "mirror"):
		return best
	if kind() == "mirror":
		for im in images:
			if im["real"]:
				return im["pos"]
		return best
	if FIELD.has_point(boss_pos):
		return boss_pos
	return best


## Returns true when the shot is consumed.
func _shot_hits(s: Vector2, dmg := 1.0) -> bool:
	for e in enemies:
		if s.distance_to(e["pos"]) < _enemy_radius(str(e["kind"])):
			e["hp"] -= dmg
			e["flash"] = 0.05
			return true
	if kind() == "bells":
		for i in range(bells.size()):
			var b: Dictionary = bells[i]
			if not b["hit"] and s.distance_to(b["pos"]) < 26:
				_bell_hit(i)
				return true
	if kind() == "mirror":
		for i in range(images.size()):
			if s.distance_to(images[i]["pos"]) < 40 and images[i]["alpha"] > 0.6:
				_image_hit(i, dmg)
				return true
		return false
	if not boss_active() or clear_t > 0 or ending_t > 0:
		return false
	if s.distance_to(boss_pos) < 46:
		if shield:
			sparks.append(Vector4(s.x, s.y, 0, 1))
			return true
		_damage(dmg)
		return true
	return false


func _damage(amount: float) -> void:
	if kind() == "final" or WAVES.has(kind()) or clear_t > 0 or ending_t > 0:
		return
	boss_hp -= amount
	boss_flash = 0.06
	score += int(10 * amount)


func _bell_hit(i: int) -> void:
	var b: Dictionary = bells[i]
	if b["hit"]:
		return
	# After a wrong ring the bells are briefly deaf, so held-down fire can't stack punishments.
	if bt - float(spawn.get("bell_wrong", -999.0)) < 1.2:
		return
	g.sfx("bell", -4)
	if b["phase"] == BELL_ORDER[bell_progress]:
		b["hit"] = true
		bell_progress += 1
		if bell_progress >= 3:
			shield = false
			shield_t = 9.0
			score += 3000
			_say("三铃齐鸣，月光镜障碎了！趁现在攻击！", 3.0)
			g.sfx("unlock", -6)
			for k in range(3):
				_drop(bells[k]["pos"], "pt", false)
				_drop(bells[k]["pos"], "p", false)
	else:
		for bell in bells:
			bell["hit"] = false
		bell_progress = 0
		spawn["bell_wrong"] = bt
		_say("铃声乱了……镜魅发怒了！（顺序：朔 → 弦 → 望）", 3.0)
		g.sfx("error", -6)
		_ring(boss_pos, 28, 170.0, rng.randf() * TAU, 2)


func _image_hit(i: int, dmg := 1.0) -> void:
	var im: Dictionary = images[i]
	if im["real"]:
		_damage(dmg)
		boss_pos = im["pos"]
	else:
		sparks.append(Vector4(im["pos"].x, im["pos"].y, 0, 1))
		if not spawn.has("reflect_%d" % i) or bt - float(spawn["reflect_%d" % i]) > 0.7:
			spawn["reflect_%d" % i] = bt
			_aimed(im["pos"], 5, 0.2, 250.0, 3)
			_say("那是镜像！打它只会被反射回来。", 1.6)


func _update_puzzles(dt: float) -> void:
	if kind() == "bells":
		if not shield:
			shield_t -= dt
			if shield_t <= 0:
				shield = true
				_place_bells()
				_say("镜障重新凝聚了。铃的位置也变了。", 2.5)
		for i in range(bells.size()):
			var b: Dictionary = bells[i]
			b["pos"].x = b["home"] + sin(bt * 0.7 + i * 2.0) * 50.0
	if kind() == "mirror":
		swap_t -= dt
		for im in images:
			im["alpha"] = minf(1.0, im["alpha"] + dt * 2.0)
			im["pos"].y = 190 + sin(bt * 1.3 + im["pos"].x * 0.01) * 18.0
		if swap_t <= 0:
			_place_images()
			_say("镜像换了位置。再找一次真身。", 2.0)


## captured = beaten before the timer ran out (always true for the survival card).
func _phase_clear(captured: bool) -> void:
	score += 10000 + graze * 10
	if PHASES[phase]["spell"]:
		if captured and spell_clean:
			var bonus := 200000 + phase * 50000
			score += bonus
			bonus_text = "破阵奖励  +%d" % bonus
			g.sfx("unlock", -6)
		else:
			bonus_text = "本阵未获额外奖励"
		bonus_t = 3.0
	# Leftover bullets turn into star items that fly to the player.
	for p in bp:
		_drop(p, "star", true)
	_drop(boss_pos, "P", false, 1)
	for i in range(5):
		_drop(boss_pos + Vector2(rng.randf_range(-40, 40), rng.randf_range(-20, 20)), "pt", false)
	if PHASES[phase]["spell"] and captured:
		_drop(boss_pos, "bomb" if kind() == "bells" else "life", false)
	_clear_bullets(true)
	enemies = []
	lasers = []
	if phase + 1 >= PHASES.size():
		_begin_ending()
		return
	if int(PHASES[phase + 1]["stage"]) != stage():
		var bonus := stage() * 100000 + (points - stage_points) * 2000 + power_level() * 10000
		score += bonus
		clear_text = "此境已破  +%d" % bonus
		clear_t = 2.6
		if stage() == 3:
			# The bronze mirror cracks: 镜魅 sheds her first form.
			shatter_t = 2.6
			clear_text = "镜面碎裂……  +%d" % bonus
			g.sfx("bomb", -4)
		else:
			g.sfx("win", -8)
		return
	_start_phase(phase + 1)


## Hold the scene after the last attack: release, quiet, farewell, then a deliberate exit.
func _begin_ending() -> void:
	mode = "ending"
	ending_t = ENDING_DURATION
	ending_elapsed = 0.0
	boss_hp = 0.0
	paused = false
	keys.clear()
	ps.clear()
	pv.clear()
	ph.clear()
	bells.clear()
	images.clear()
	items.clear()
	title_t = 0.0
	cutin_t = 0.0
	banner = 0.0
	shatter_t = 0.0
	bomb_t = 0.0
	_clear_bullets(false)
	g.sfx("bomb", -8)
	if not g.test_mode:
		ending_music = create_tween()
		ending_music.tween_property(g.music_player, "volume_db", -38.0, ENDING_DURATION - 0.5)


func _advance_ending(delta: float) -> void:
	ending_elapsed = minf(ENDING_DURATION, ending_elapsed + delta)
	ending_t = maxf(0.0, ENDING_DURATION - ending_elapsed)
	if ending_t <= 0.0:
		_win()


func _win() -> void:
	if mode == "farewell" or mode == "won":
		return
	mode = "farewell"
	if ending_music and ending_music.is_valid():
		ending_music.kill()
	g.music("ambient", false)
	g.say("boss_defeat", _award_final_shard)


func _award_final_shard() -> void:
	if g.scene != self or mode != "farewell":
		return
	g.get_shard(3)
	g.show_card("shard_d", _finish_victory)


func _finish_victory() -> void:
	if g.scene != self or mode != "farewell":
		return
	g.clear("ch7")
	mode = "won"
	g.sfx("win", -10)


# ================================================================== bullets
const COLORS := [Color("ffd27a"), Color("8fd6ff"), Color("ff8f7a"), Color("d9b3ff"), Color("b8ffcf")]


## Bullet shapes and behaviours (see the bs / bb arrays).
enum Shape { ORB, RICE, KUNAI, BIG, STAR, AMULET }
enum Move { PLAIN, ACCEL, CURVE, BOUNCE, SPLIT, AIMLATER }


func _add(p: Vector2, v: Vector2, r := 6.0, c := 0, shape := Shape.ORB, move := Move.PLAIN, param := 0.0) -> void:
	if bp.size() > 1100:
		return
	bp.append(p)
	bv.append(v)
	br.append(r * (0.85 if easy else 1.0))
	bc.append(c)
	bg.append(0)
	bs.append(shape)
	bb.append(move)
	ba.append(0.0)
	bx.append(param)


func _ring(center: Vector2, n: int, speed: float, offset: float, c := 0, r := 6.0, shape := Shape.ORB, move := Move.PLAIN, param := 0.0) -> void:
	var count := maxi(1, int(n * (0.7 if easy else 1.0)))
	for i in range(count):
		_add(center, Vector2.from_angle(offset + TAU * i / count) * speed, r, c, shape, move, param)


func _aimed(from: Vector2, n: int, spread: float, speed: float, c := 2, shape := Shape.ORB) -> void:
	var base := (player - from).angle()
	for i in range(n):
		var a := base + (i - (n - 1) * 0.5) * spread
		_add(from, Vector2.from_angle(a) * speed, 6.0 if shape != Shape.KUNAI else 4.5, c, shape)


## Thin warning line first, then a damaging beam. o = origin, a = angle.
func _laser(o: Vector2, a: float, w := 14.0, warn := 0.9, life := 1.1, spin := 0.0) -> void:
	lasers.append({"o": o, "a": a, "w": w, "warn": warn, "life": life, "t": 0.0, "spin": spin})


func _enemy_radius(enemy_kind: String) -> float:
	return {"lantern": 26.0, "spirit": 34.0}.get(enemy_kind, 20.0)


func _enemy(pos: Vector2, vel: Vector2, enemy_kind: String, hp := 6.0) -> void:
	enemies.append({"pos": pos, "vel": vel, "hp": hp, "t": 0.0, "kind": enemy_kind, "fire": rng.randf_range(0.4, 1.0), "flash": 0.0})


func _every(key_name: String, interval: float) -> bool:
	var iv := interval * (1.35 if easy else 1.0)
	var last := float(spawn.get(key_name, -999.0))
	if bt - last >= iv:
		spawn[key_name] = bt
		return true
	return false


func _patterns(_dt: float) -> void:
	if banner > 1.6:
		return
	var cx := FIELD.get_center().x
	var limit: float = PHASES[phase]["time"]
	match kind():
		"wave1":
			if bt > limit - 2.0 or title_t > 1.8:
				return
			# Crane flights sweep in from alternating sides.
			if _every("flight", 2.6):
				var left := int(bt / 2.6) % 2 == 0
				for k in range(5):
					var x0 := FIELD.position.x - 20 - k * 34 if left else FIELD.end.x + 20 + k * 34
					_enemy(Vector2(x0, 80 + k * 22), Vector2(170 if left else -170, 30), "crane", 4.0)
			# Divers drop from the top, pause and lunge at the player.
			if bt > 6.0 and _every("divers", 3.4):
				for k in range(3):
					_enemy(Vector2(cx + (k - 1) * 170 + rng.randf_range(-30, 30), FIELD.position.y - 20), Vector2(0, 200), "diver", 5.0)
			if bt > 10.0 and _every("wisps", 4.5):
				for k in range(2):
					_enemy(Vector2(FIELD.position.x + 110 + k * (FIELD.size.x - 220), FIELD.position.y - 10), Vector2(0, 80), "wisp", 9.0)
			# A great wisp closes the stage, the stage's 'midboss'.
			if bt > 18.0 and not spawn.has("spirit"):
				spawn["spirit"] = bt
				_enemy(Vector2(cx, FIELD.position.y - 30), Vector2(0, 90), "spirit", 70.0)
		"wave2":
			if bt > limit - 7.5 or title_t > 1.8:
				# The stage winds down; 镜魅 appears for a moment, then withdraws up the tower.
				if bt > limit - 6.0 and not spawn.has("cameo"):
					spawn["cameo"] = bt
					cameo = true
					_say("镜魅：「……光的味道。到塔刹来，我在月下等你。」", 3.6)
					g.voice("boss", "……光的味道。到塔刹来，我在月下等你。")
					g.sfx("reveal", -8)
				if cameo and bt > limit - 4.4 and not spawn.has("cameo_ring"):
					spawn["cameo_ring"] = bt
					for k in range(3):
						_ring(boss_pos, 30, 120.0 + k * 30.0, k * 0.1, 3 + k % 2, 6.0, Shape.RICE)
				if cameo and bt > limit - 3.2:
					cameo = false
				return
			# Lanterns hover and fire bouncing orbs and amulet fans.
			if _every("lanterns", 5.5):
				for k in range(2):
					var x := cx + (-1 if (int(bt / 5.5) + k) % 2 == 0 else 1) * rng.randf_range(80, 220)
					_enemy(Vector2(x, FIELD.position.y - 30), Vector2(0, 150), "lantern", 26.0)
			if _every("flight2", 2.0):
				var left := int(bt / 2.0) % 2 == 0
				for k in range(6):
					var x0 := FIELD.position.x - 20 - k * 30 if left else FIELD.end.x + 20 + k * 30
					_enemy(Vector2(x0, 120 + k * 18), Vector2(190 if left else -190, 20), "crane", 4.0)
			if bt > 8.0 and _every("divers2", 3.0):
				for k in range(4):
					_enemy(Vector2(FIELD.position.x + 90 + k * 153, FIELD.position.y - 20 - k * 30), Vector2(0, 220), "diver", 5.0)
			if bt > 12.0 and _every("wisps2", 3.6):
				_enemy(Vector2(rng.randf_range(FIELD.position.x + 60, FIELD.end.x - 60), FIELD.position.y - 10), Vector2(0, 80), "wisp", 10.0)
		"non1":
			# Two counter-rotating rings of curving rice bullets and aimed kunai.
			if _every("ring", 1.0):
				_ring(boss_pos, 18, 140.0, bt * 0.7, 0, 5.0, Shape.RICE, Move.CURVE, 0.55)
				_ring(boss_pos, 18, 140.0, -bt * 0.7, 4, 5.0, Shape.RICE, Move.CURVE, -0.55)
			if _every("aim", 1.7):
				_aimed(boss_pos, 5, 0.16, 300.0, 2, Shape.KUNAI)
		"bells":
			# Spiral arms from the boss; bells drip slow star petals.
			if _every("spiral", 0.11):
				for k in range(3):
					_add(boss_pos, Vector2.from_angle(bt * 2.1 + k * TAU / 3) * 170.0, 6.0, 1)
			if _every("petal", 1.4):
				for b in bells:
					if not b["hit"]:
						_ring(b["pos"], 8, 90.0, bt, 4, 5.0, Shape.STAR)
			if _every("wisps", 6.0):
				for k in range(2):
					_enemy(Vector2(FIELD.position.x + 80 + k * (FIELD.size.x - 160), FIELD.position.y - 10), Vector2(0, 70), "wisp", 10.0)
		"shatter":
			# Four rotating arms of mirror-shard kunai that reverse direction every few seconds,
			# five-petal flowers of rice bullets, and slow star rings.
			var dir := 1.0 if int(bt / 5.0) % 2 == 0 else -1.0
			if _every("arms", 0.08):
				var base := fmod(bt, 5.0) * 1.3 * dir
				for k in range(4):
					_add(boss_pos, Vector2.from_angle(base + k * TAU / 4) * 190.0, 5.0, 1, Shape.KUNAI)
			if _every("flower", 2.4):
				var rot := rng.randf() * TAU
				for k in range(40):
					var a := rot + k * TAU / 40.0
					var petal := 0.55 + 0.45 * absf(cos(2.5 * (a - rot)))
					_add(boss_pos, Vector2.from_angle(a) * 170.0 * petal, 5.5, 3 if int(bt / 2.4) % 2 == 0 else 0, Shape.RICE)
			if _every("starring", 3.1):
				_ring(boss_pos, 14, 90.0, bt, 4, 6.0, Shape.STAR, Move.AIMLATER, 260.0)
		"mirror":
			if _every("mirror", 1.1):
				for im in images:
					_ring(im["pos"], 12, 130.0, bt * 0.5, 3, 5.0, Shape.RICE)
			if _every("aim2", 2.0):
				for im in images:
					if im["real"]:
						_aimed(im["pos"], 3, 0.22, 240.0, 2, Shape.KUNAI)
			# Delayed-aim stars: they stop, then dart at where you are.
			if _every("delay", 2.6):
				_ring(Vector2(cx, 330), 10, 160.0, bt, 4, 6.0, Shape.STAR, Move.AIMLATER, 320.0)
		"final":
			# Three movements: moon rain and rings, then rose petals with lasers, then everything.
			var part := 0 if bt < 6.0 else (1 if bt < 12.0 else 2)
			if _every("rain", 0.08 if part < 2 else 0.06):
				_add(Vector2(rng.randf_range(FIELD.position.x, FIELD.end.x), FIELD.position.y), Vector2(rng.randf_range(-30, 30), rng.randf_range(150, 230)), 5.0, 1, Shape.RICE)
			if _every("ring3", 1.3):
				_ring(boss_pos, 24, 120.0, bt, 0, 7.0)
				_ring(boss_pos, 24, 90.0, -bt, 4, 5.0, Shape.STAR)
			if part >= 1 and _every("rose", 1.8):
				# A rose curve: speed follows |cos(3θ)| so the ring opens as six petals.
				var rot := bt * 0.5
				for k in range(48):
					var a := rot + k * TAU / 48.0
					_add(boss_pos, Vector2.from_angle(a) * (70.0 + 130.0 * absf(cos(3.0 * (a - rot)))), 5.0, 3, Shape.RICE)
			if part >= 1 and _every("laser", 3.5):
				var spin := 0.35 if int(bt / 3.5) % 2 == 0 else -0.35
				for k in range(3):
					_laser(boss_pos, PI * 0.5 + (k - 1) * 0.55, 16.0, 1.0, 1.6, spin)
			if part >= 2 and _every("split", 2.2):
				_ring(boss_pos, 6, 110.0, bt * 0.3, 2, 13.0, Shape.BIG, Move.SPLIT, 1.2)


func _update_bullets(dt: float) -> void:
	var hit_r := 3.5
	var graze_r := 22.0
	var spawned: Array = []           # bullets created by splitting, added after the loop
	var i := 0
	while i < bp.size():
		ba[i] += dt
		match bb[i]:
			Move.ACCEL:
				bv[i] += bv[i].normalized() * bx[i] * dt
			Move.CURVE:
				bv[i] = bv[i].rotated(bx[i] * dt)
			Move.BOUNCE:
				var nx := bp[i] + bv[i] * dt
				if nx.x < FIELD.position.x + br[i] or nx.x > FIELD.end.x - br[i]:
					bv[i].x = -bv[i].x
				if nx.y < FIELD.position.y + br[i]:
					bv[i].y = absf(bv[i].y)
				if ba[i] > bx[i]:
					spawned.append([bp[i], bc[i]])
					_remove(i)
					continue
			Move.SPLIT:
				if ba[i] > bx[i]:
					spawned.append([bp[i], bc[i]])
					_remove(i)
					continue
			Move.AIMLATER:
				# Slow to a stop, pause, then fire at the player once.
				if ba[i] < 0.8:
					bv[i] = bv[i] * maxf(0.0, 1.0 - dt * 4.0)
				elif bx[i] > 0:
					bv[i] = (player - bp[i]).normalized() * bx[i]
					bx[i] = 0.0
		bp[i] += bv[i] * dt
		var p := bp[i]
		if not FIELD.grow(30).has_point(p):
			_remove(i)
			continue
		if bomb_t > 0 and p.distance_to(player) < (1.0 - bomb_t / 1.2) * 700.0:
			sparks.append(Vector4(p.x, p.y, 0, 2))
			_remove(i)
			continue
		var d := p.distance_to(player)
		if invuln <= 0 and d < br[i] + hit_r:
			_player_hit()
			return
		if bg[i] == 0 and d < br[i] + graze_r:
			bg[i] = 1
			graze += 1
			score += 50
			if graze % 4 == 0:
				g.sfx("graze", -20)
		i += 1
	for s in spawned:
		_ring(s[0], 10, 120.0, rng.randf() * TAU, int(s[1]), 4.5, Shape.RICE)


func _remove(i: int) -> void:
	var last := bp.size() - 1
	bp[i] = bp[last]
	bv[i] = bv[last]
	br[i] = br[last]
	bc[i] = bc[last]
	bg[i] = bg[last]
	bs[i] = bs[last]
	bb[i] = bb[last]
	ba[i] = ba[last]
	bx[i] = bx[last]
	_resize_bullets(last)


func _clear_bullets(sparkle: bool) -> void:
	if sparkle:
		for p in bp:
			sparks.append(Vector4(p.x, p.y, 0, 2))
	_resize_bullets(0)


## Packed arrays are value types in some contexts, so resize each one explicitly.
func _resize_bullets(n: int) -> void:
	bp.resize(n)
	bv.resize(n)
	br.resize(n)
	bc.resize(n)
	bg.resize(n)
	bs.resize(n)
	bb.resize(n)
	ba.resize(n)
	bx.resize(n)


# ------------------------------------------------------------------ lasers / enemies / items
func _laser_dir(l: Dictionary) -> Vector2:
	return Vector2.from_angle(float(l["a"]))


func _update_lasers(dt: float) -> void:
	for k in range(lasers.size() - 1, -1, -1):
		var l: Dictionary = lasers[k]
		l["t"] += dt
		l["o"] = boss_pos if kind() == "final" else l["o"]
		if l["t"] > l["warn"]:
			l["a"] += float(l["spin"]) * dt
		if l["t"] > l["warn"] + l["life"]:
			lasers.remove_at(k)
			continue
		if l["t"] < l["warn"] or bomb_t > 0:
			continue
		# Distance from the player to the beam (a ray from o).
		var d := _laser_dir(l)
		var rel: Vector2 = player - l["o"]
		var along := rel.dot(d)
		if along < 0:
			continue
		var off := absf(rel.cross(d))
		var half: float = l["w"] * 0.5 * (0.85 if easy else 1.0)
		if invuln <= 0 and off < half * 0.6:
			_player_hit()
			return
		if off < half + 18 and int(l["t"] * 20) % 4 == 0:
			graze += 1
			score += 20


func _update_enemies(dt: float) -> void:
	for k in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[k]
		e["t"] += dt
		e["flash"] = maxf(0.0, e["flash"] - dt)
		var ek := str(e["kind"])
		match ek:
			"crane":
				e["vel"].y = 40.0 + sin(e["t"] * 3.0) * 60.0
			"wisp":
				if e["t"] > 1.4:
					e["vel"] = e["vel"].lerp(Vector2(0, -60), dt)
			"diver":
				# Drop in, hang for a beat, then lunge at where the player was.
				if e["t"] > 0.5 and e["t"] < 1.1:
					e["vel"] = e["vel"].lerp(Vector2.ZERO, dt * 8.0)
				elif e["t"] >= 1.1 and not e.has("lunge"):
					e["lunge"] = true
					e["vel"] = (player - e["pos"]).normalized() * 330.0
			"lantern", "spirit":
				# Glide down, hover and fire, then drift away upward.
				var stay := 7.0 if ek == "lantern" else 11.0
				if e["t"] > 0.9 and e["t"] < stay:
					e["vel"] = e["vel"].lerp(Vector2(sin(e["t"]) * 30.0, 0), dt * 3.0)
				elif e["t"] >= stay:
					e["vel"] = e["vel"].lerp(Vector2(0, -90), dt)
		e["pos"] += e["vel"] * dt
		e["fire"] -= dt
		if e["fire"] <= 0 and FIELD.has_point(e["pos"]):
			match ek:
				"crane":
					e["fire"] = 1.2
					_aimed(e["pos"], 1, 0.0, 200.0, 4, Shape.RICE)
				"diver":
					e["fire"] = 9.0
					_ring(e["pos"], 6, 120.0, rng.randf() * TAU, 2, 4.5, Shape.RICE)
				"lantern":
					e["fire"] = 1.1
					e["shots"] = int(e.get("shots", 0)) + 1
					if int(e["shots"]) % 3 == 0:
						for n in range(2):
							_add(e["pos"], Vector2.from_angle(PI * 0.5 + (n - 0.5) * 1.1) * 150.0, 14.0, 2, Shape.BIG, Move.BOUNCE, 2.4)
					else:
						var base: float = (player - (e["pos"] as Vector2)).angle()
						for n in range(5):
							_add(e["pos"], Vector2.from_angle(base + (n - 2) * 0.22) * 60.0, 5.0, 3, Shape.AMULET, Move.ACCEL, 240.0)
				"spirit":
					e["fire"] = 0.75
					_ring(e["pos"], 16, 115.0, e["t"] * 1.7, 1, 5.0, Shape.RICE, Move.CURVE, 0.4 if int(e["t"]) % 2 == 0 else -0.4)
				_:
					e["fire"] = 0.5
					_ring(e["pos"], 8, 110.0, e["t"] * 2.0, 1, 5.0, Shape.ORB)
		if e["hp"] <= 0:
			sparks.append(Vector4(e["pos"].x, e["pos"].y, 0, 0))
			g.sfx("graze", -14)
			match ek:
				"crane", "diver":
					score += 300
					_drop(e["pos"], "p" if rng.randf() < 0.6 else "pt", false)
				"lantern":
					score += 3000
					_drop(e["pos"], "P", false)
					_drop(e["pos"], "pt", false, 4)
				"spirit":
					score += 10000
					_drop(e["pos"], "P", false, 2)
					_drop(e["pos"], "pt", false, 8)
					_drop(e["pos"], "bomb", false)
					for n in range(4):
						sparks.append(Vector4(e["pos"].x + rng.randf_range(-30, 30), e["pos"].y + rng.randf_range(-30, 30), 0, 2))
				_:
					score += 300
					_drop(e["pos"], "P" if rng.randf() < 0.3 else "p", false)
					_drop(e["pos"] + Vector2(10, 0), "pt", false)
					_drop(e["pos"] - Vector2(10, 0), "pt", false)
			enemies.remove_at(k)
		elif not FIELD.grow(80).has_point(e["pos"]):
			enemies.remove_at(k)


## Spawns an item. home = flies straight to the player (used for bullet cancels and auto-collect).
func _drop(pos: Vector2, item_kind: String, home: bool, count := 1) -> void:
	for n in range(count):
		var v := Vector2(rng.randf_range(-40, 40), rng.randf_range(-180, -120))
		items.append({"pos": pos, "vel": v, "kind": item_kind, "home": home})


func _update_items(dt: float) -> void:
	var focus := _down([KEY_SHIFT])
	var poc := player.y < POC_Y
	for k in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[k]
		if poc and not game_over:
			it["home"] = true
		var p: Vector2 = it["pos"]
		var d := p.distance_to(player)
		if not it["home"] and d < (90.0 if focus else 50.0):
			it["home"] = true
		if it["home"]:
			it["pos"] = p.move_toward(player, 900.0 * dt)
		else:
			it["vel"].y = minf(it["vel"].y + 260.0 * dt, 120.0)
			it["vel"].x *= maxf(0.0, 1.0 - dt * 2.0)
			it["pos"] = p + it["vel"] * dt
		if (it["pos"] as Vector2).distance_to(player) < 22:
			_collect(it)
			items.remove_at(k)
		elif it["pos"].y > FIELD.end.y + 20:
			items.remove_at(k)


func _collect(it: Dictionary) -> void:
	var p: Vector2 = it["pos"]
	match str(it["kind"]):
		"p":
			_add_power(0.05)
			score += 10
		"P":
			_add_power(1.0)
			score += 10
		"full":
			_add_power(MAX_POWER)
		"pt":
			# Value scales with height; full value at or above the collection line.
			var k := clampf(1.0 - (p.y - POC_Y) / (FIELD.end.y - POC_Y), 0.0, 1.0)
			var value: int = int(lerpf(2000.0, 10000.0, k) / 10.0) * 10
			if p.y <= POC_Y or player.y < POC_Y:
				value = 10000
			score += value
			points += 1
			popups.append({"pos": p, "text": str(value), "t": 0.0, "color": Color("9fc4ff") if value >= 10000 else Color("cfd8e8")})
			if points >= next_extend:
				next_extend += EXTEND_EVERY
				_extend()
		"star":
			score += 100 + graze
		"bomb":
			bombs = mini(bombs + 1, 8)
			popups.append({"pos": p, "text": "月华 +1", "t": 0.0, "color": Color("8fe3a9")})
			g.sfx("pickup", -10)
		"life":
			_extend()
	if str(it["kind"]) in ["p", "pt", "star"] and rng.randf() < 0.3:
		g.sfx("dial", -26)


func _add_power(amount: float) -> void:
	var before := power_level()
	power = minf(MAX_POWER, power + amount)
	if power_level() > before:
		g.sfx("unlock", -12)
		if power >= MAX_POWER:
			full_flash = 2.0
			_say("镜力充盈，流光尽散！", 2.0)
			# Touhou rule: hitting max power cancels bullets into stars.
			for p in bp:
				_drop(p, "star", true)
			_clear_bullets(true)


func _extend() -> void:
	lives = mini(lives + 1, 8)
	popups.append({"pos": player + Vector2(0, -30), "text": "续灯 +1", "t": 0.0, "color": Color("ff9fd2")})
	g.sfx("reveal", -6)


func _player_hit() -> void:
	g.sfx("hit")
	player_hurt_t = 0.35
	spell_clean = false
	_clear_bullets(true)
	lasers = []
	invuln = 2.2
	# Lose some power; it scatters as P items above the player.
	var lost := minf(power, 1.0)
	power -= lost
	var big := int(lost)
	for n in range(big):
		_drop(player + Vector2(rng.randf_range(-60, 60), -40), "P", false)
	for n in range(int((lost - big) / 0.05)):
		_drop(player + Vector2(rng.randf_range(-60, 60), -40), "p", false)
	if g.zun_mode:
		popups.append({"pos": player + Vector2(0, -30), "text": "月佑", "t": 0.0, "color": Color("ffd27a")})
		bombs = maxi(bombs, 2)
		return
	lives -= 1
	bombs = maxi(bombs, 2)
	if lives <= 0:
		game_over = true
		g.stats["retries"] = int(g.stats["retries"]) + 1


func _bomb() -> void:
	if bomb_t > 0 or (bombs <= 0 and not g.zun_mode):
		return
	if not g.zun_mode:
		bombs -= 1
	spell_clean = false
	bomb_t = 1.2
	invuln = maxf(invuln, 1.6)
	lasers = []
	g.sfx("bomb")
	_damage(12.0)
	for it in items:
		it["home"] = true


func _retry(want_easy: bool) -> void:
	easy = easy or want_easy
	var keep_phase := phase
	lives = 3
	bombs = 2
	power = maxf(power, 2.0)          # a retry restarts with half power so it stays winnable
	items = []
	game_over = false
	_start_phase(keep_phase, false)
	_say("从「%s」重新开始。" % PHASES[keep_phase]["name"] + ("（简单模式）" if easy else ""), 2.5)


# ================================================================== drawing
func _draw() -> void:
	hit_regions.clear()
	if mode in ["ending", "farewell", "won"]:
		_draw_victory()
		return
	if mode == "battle":
		_draw_battle()
		return
	var goals := [
		{"t": "登塔", "d": "调查塔顶", "done": read_stele},
		{"t": "镜魅", "d": "击败镜魅，取回碎片", "done": false},
	]
	_frame("第七章  ·  月下", "大慈恩寺 · 大雁塔顶层  /  子时 · 月明", goals, "读塔碑，然后触碰三环铜盘。", [])
	if not _img_cover("pagoda", ROOM):
		draw_rect(bleed(), Color("1b1f2a"))
	var glow := 0.5 + 0.5 * sin(age * 2.0)
	if mode == "explore":
		for r in range(6, 0, -1):
			draw_circle(Vector2(575, 590), 18 + r * 6, Color(0.72, 1.0, 0.81, 0.012 + glow * 0.008))
		_shard(Vector2(575, 584), 0.3)
	if g.blocked():
		return
	for id in SPOT:
		_hotspot(id, SPOT[id]["p"], SPOT[id]["label"], SPOT[id]["r"], id == "stele" and read_stele)


func _draw_victory() -> void:
	var t := ending_elapsed
	var reveal := smoothstep(0.35, 2.4, t)
	# Keep the battle composition during the burst; open it out into the moonlit tower.
	_draw_battle()
	_img_cover("pagoda", Rect2(0, 0, 1440, 900), Color(0.48, 0.53, 0.66, reveal))
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.015, 0.025, 0.055, 0.34 * reveal))
	var centre := Vector2(720, 265)
	var scatter := clampf(t / 2.8, 0.0, 1.0)
	for i in range(48):
		var angle := i * 2.39996
		var distance := (55.0 + i * 3.8) * scatter
		var p := centre + Vector2(cos(angle), sin(angle) * 0.65) * distance
		p.y -= t * (10.0 + float(i % 7) * 3.0)
		var alpha := (1.0 - scatter * 0.8) * (0.6 + 0.4 * sin(age * 2.0 + i))
		draw_circle(p, 2.0 + float(i % 3), Color(1.0, 0.88, 0.6, alpha * reveal))
	for i in range(3):
		var radius := 35.0 + scatter * (180.0 + i * 95.0)
		draw_arc(centre, radius, 0, TAU, 96, Color(1.0, 0.91, 0.72, (1.0 - scatter) * 0.5), 2.5, true)
	if t < 2.8 and g.tex.has("boss_2"):
		var portrait: Texture2D = g.tex["boss_2"]
		var h := 210.0
		var size := Vector2(h * portrait.get_width() / portrait.get_height(), h)
		draw_texture_rect(portrait, Rect2(centre - size * 0.5, size), false, Color(1.0, 0.94, 0.85, (1.0 - scatter) * reveal))
	if mode == "ending":
		var a := smoothstep(1.5, 2.5, t)
		_title_center(720, 440, "月华归宁", 50, Color(Pal.PAPER, a))
		_tc(720, 487, "风停了，塔檐只余一声轻铃。", 19, Color(Pal.GOLD, a))
		if t > 3.5:
			_tc(720, 535, "月光沿着碎瓷，落进掌心。", 17, Color(Pal.PAPER, smoothstep(3.5, 4.3, t)))
	elif mode == "won":
		_box(Rect2(410, 290, 620, 390), Color(0.02, 0.04, 0.06, 0.86), 8, Color(Pal.GOLD, 0.42))
		_title_center(720, 360, "月华归宁", 46, Pal.PAPER)
		_tc(720, 404, "第四片碎瓷已寻回", 21, Pal.GOLD)
		_shard_slots(Vector2(640, 438))
		_tc(720, 520, "得分 %d   ·   擦身 %d 次" % [score, graze], 17, Pal.SOFT)
		_tc(720, 559, "四片齐聚，回镜坊完成最后的修复。", 17, Pal.PAPER)
		if not g.blocked():
			_button("continue_story", Rect2(490, 600, 460, 50), "带上碎片 · 回镜坊  ›", true, 20)
	# A brief soft flash signals the final hit, without a hard scene cut.
	draw_rect(Rect2(0, 0, 1440, 900), Color(1.0, 0.96, 0.85, maxf(0.0, 0.65 - t * 1.3)))


## Artwork stays behind the whole simulation; all shots and hitboxes are drawn above it.
func _draw_environment() -> void:
	draw_rect(FIELD, Color("080f20"))
	if backdrop_blend < 1.0 and not previous_backdrop.is_empty():
		_draw_environment_plate(previous_backdrop, 1.0)
	_draw_environment_plate(backdrop, smoothstep(0.0, 1.0, backdrop_blend))
	# Quiet the centre and the player's lower flight lane for bright bullet silhouettes.
	draw_rect(FIELD, Color(0.015, 0.025, 0.06, 0.18))
	for i in range(18):
		var width := FIELD.size.x / 18.0
		var x := FIELD.position.x + i * width
		var edge := absf((float(i) + 0.5) / 9.0 - 1.0)
		draw_rect(Rect2(x, FIELD.position.y, width + 1, FIELD.size.y), Color(0.01, 0.02, 0.04, edge * edge * 0.22))
	for i in range(12):
		var height := 22.0
		draw_rect(Rect2(FIELD.position.x, FIELD.end.y - (i + 1) * height, FIELD.size.x, height + 1), Color(0.01, 0.02, 0.04, (1.0 - float(i) / 12.0) * 0.26))
	# Haze drifts slowly along the edges; it stays below both enemies and bullets.
	for i in range(3):
		var y := FIELD.position.y + fmod(age * (7.0 + i * 3.0) + i * 240.0, FIELD.size.y)
		draw_set_transform(Vector2(FIELD.get_center().x + sin(age * 0.1 + i) * 100, y), 0, Vector2(2.8, 0.22))
		draw_circle(Vector2.ZERO, 100, Color(0.53, 0.66, 0.8, 0.016))
		draw_set_transform(Vector2.ZERO)


func _draw_environment_plate(key: String, opacity: float) -> void:
	if not g.tex.has(key):
		return
	var texture: Texture2D = g.tex[key]
	var crop := _cover_crop(texture.get_size(), FIELD.size)
	# Crop within the image, rather than stretching it, so no seam can enter the field.
	var inset := crop.size * 0.035
	crop.position += inset
	crop.size -= inset * 2.0
	crop.position += Vector2(sin(age * 0.06) * inset.x * 0.65, sin(age * 0.08) * inset.y * 0.65)
	draw_texture_rect_region(texture, FIELD, crop, Color(0.72, 0.77, 0.86, opacity))


func _draw_lunar_disc(centre: Vector2, diameter: float, opacity: float) -> void:
	if diameter <= 0.0:
		return
	for ring in range(4, 0, -1):
		draw_circle(centre, diameter * (0.5 + ring * 0.055), Color(0.86, 0.9, 1.0, opacity * 0.018))
	if g.tex.has("ch7_moon"):
		draw_texture_rect(g.tex["ch7_moon"], Rect2(centre - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter), false, Color(0.96, 0.97, 1.0, opacity))
	else:
		draw_circle(centre, diameter * 0.46, Color(0.95, 0.93, 0.8, opacity * 0.4))


func _draw_battle() -> void:
	draw_rect(Rect2(0, 0, 1440, 900), Color("070a12"))
	# Side panels use the pagoda painting, darkened.
	_img_cover("pagoda", Rect2(0, 0, 1440, 900), Color(0.28, 0.28, 0.36))
	_draw_environment()
	for s in stars:
		var y := fmod(s.y + age * 40.0 * s.z, 900.0)
		if y > FIELD.position.y:
			draw_circle(Vector2(s.x, y), s.z * 1.0, Color(0.8, 0.85, 1.0, 0.14 * s.z))
	if kind() != "final" and stage() != 2:
		_draw_lunar_disc(Vector2(FIELD.end.x - 105, FIELD.position.y + 145), 115.0, 0.48)
	if PHASES[phase]["spell"]:
		_draw_spell_backdrop()
	if banner > 0:
		var a := minf(1.0, banner)
		draw_rect(FIELD, Color(0.3, 0.1, 0.25, 0.2 * a))
	_draw_puzzle_layer()
	if (mode == "battle" or (mode == "ending" and ending_elapsed < 1.5)) and boss_visible() and FIELD.grow(60).has_point(boss_pos):
		_draw_boss()
	_draw_enemies()
	_draw_lasers()
	# Player shots: needles, homing amulets in jade.
	for i in range(ps.size()):
		var s := ps[i]
		if ph[i] == 1:
			draw_set_transform(s, pv[i].angle() + PI * 0.5)
			draw_rect(Rect2(-4, -7, 8, 14), Color(0.55, 0.95, 0.8, 0.85))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_line(s, s - pv[i].normalized() * 14, Color(1, 0.85, 0.5, 0.85), 3)
	_draw_items()
	_draw_player()
	# Bullets.
	for i in range(bp.size()):
		if not FIELD.has_point(bp[i]):
			continue
		_draw_bullet(i)
	for s in sparks:
		var k := s.z / 0.5
		var sc: Color = [Color(1, 0.9, 0.6), Color(0.7, 0.9, 1), Color(1, 1, 1)][int(s.w)]
		draw_circle(Vector2(s.x, s.y), 2 + k * 8, Color(sc, (1.0 - k) * 0.6))
	if bomb_t > 0:
		var rad := (1.0 - bomb_t / 1.2) * 700.0
		draw_arc(player, rad, 0, TAU, 64, Color(1, 0.95, 0.8, bomb_t * 0.6), 10, true)
		draw_circle(player, rad, Color(1, 0.95, 0.8, bomb_t * 0.06))
	# Item collection line: visible while the player is near it.
	var near := clampf(1.0 - (player.y - POC_Y) / 200.0, 0.0, 1.0)
	if near > 0:
		var x := FIELD.position.x
		while x < FIELD.end.x:
			draw_line(Vector2(x, POC_Y), Vector2(minf(x + 12, FIELD.end.x), POC_Y), Color(0.6, 0.8, 1.0, 0.5 * near), 1.5)
			x += 22
		_t(Vector2(FIELD.position.x + 10, POC_Y - 6), "引光线 · 越线收取灵物", 11, Color(0.6, 0.8, 1.0, 0.7 * near))
	for pu in popups:
		var a := 1.0 - float(pu["t"]) / 0.9
		_tc(pu["pos"].x, pu["pos"].y, str(pu["text"]), 12, Color(pu["color"], a))
	_draw_effects()
	_draw_player_hitbox()
	_mask_outside_field()
	_box(FIELD.grow(3), Color(0, 0, 0, 0), 4, Color(0.84, 0.72, 0.48, 0.7), 3)
	if mode != "battle":
		return
	_draw_hud()
	if PHASES[phase]["spell"] and clear_t <= 0 and ending_t <= 0:
		# The declared spell slides from the middle of the field up under the HP bar.
		var k := clampf((2.4 - banner) / 0.6, 0.0, 1.0) if banner > 0 else 1.0
		var y := lerpf(FIELD.position.y + 440, FIELD.position.y + 64, ease(k, 0.5))
		var size := int(lerpf(30, 18, k))
		var name := str(PHASES[phase]["name"])
		var tw := _tw(name, size) + 30
		var x := FIELD.end.x - 14 - tw
		draw_colored_polygon(PackedVector2Array([Vector2(x - 20, y + 8), Vector2(x, y - size - 4), Vector2(FIELD.end.x - 8, y - size - 4), Vector2(FIELD.end.x - 8, y + 8)]), Color(0.2, 0.05, 0.2, 0.7))
		_t(Vector2(x + 10, y), name, size, Color(1, 0.95, 0.9))
		if k < 1.0:
			_tc(FIELD.get_center().x, y - size - 16, "镜阵展开", 14, Color(1, 0.8, 0.9, 1.0 - k))
		var bonus := 200000 + phase * 50000
		_t(Vector2(x + 10, y + 22), "破阵赏分  %d" % bonus if spell_clean else "额外赏分已失", 12, Color(1, 0.9, 0.7, 0.8) if spell_clean else Color(0.6, 0.6, 0.65, 0.8))
	elif bt < 1.5 and not WAVES.has(kind()) and clear_t <= 0:
		_title_center(FIELD.get_center().x, FIELD.position.y + 200, PHASES[phase]["name"], 26, Color(0.85, 0.9, 1.0, 1.0 - bt / 1.5))
	if msg_t > 0:
		var a3 := minf(1.0, msg_t * 2)
		var w := _tw(msg, 16) + 40
		_box(Rect2(FIELD.get_center().x - w * 0.5, FIELD.end.y - 70, w, 38), Color(0.05, 0.08, 0.1, 0.85 * a3), 6, Color(0.84, 0.72, 0.48, a3))
		_tc(FIELD.get_center().x, FIELD.end.y - 45, msg, 16, Color(Pal.PAPER, a3))
	if paused or game_over:
		_draw_pause()


## Compact rear-view Su Qing sprite; all movement here is cosmetic.
func _draw_player() -> void:
	var opacity := 0.38 if invuln > 0 and int(age * 16) % 2 == 0 else 1.0
	var bob := sin(age * 3.0) * 0.6 * (1.0 - player_focus)
	var spread := lerpf(25.0 + power_level() * 0.8, 17.0, player_focus)
	if bomb_t > 0:
		spread += sin(clampf(bomb_t / 1.2, 0.0, 1.0) * PI) * 9.0
	# Two short strokes keep the flight direction readable without a large glow.
	for side in [-1.0, 1.0]:
		var foot := player + Vector2(side * 4.0 - player_lean * 24.0, 27.0 + bob)
		draw_line(foot, foot + Vector2(-player_lean * 9.0, 7.0), Color(0.5, 0.82, 0.76, 0.28 * opacity * (1.0 - player_focus)), 1.4, true)
		var mirror := player + Vector2(side * spread, -7.0 + sin(age * 3.0 + side) * 0.8)
		var radius := 3.5 + power_level() * 0.3
		draw_circle(mirror, radius + 1.2, Color(0.04, 0.07, 0.08, opacity))
		draw_circle(mirror, radius, Color(0.76, 0.64, 0.37, opacity))
		draw_arc(mirror, radius - 1.0, PI, TAU, 12, Color(1.0, 0.89, 0.61, 0.8 * opacity), 1.0, true)
	if g.tex.has("player_su"):
		draw_set_transform(player + Vector2(0, bob), player_lean)
		draw_texture_rect(g.tex["player_su"], Rect2(-14, -28, 28, 56), false, Color(1, 1, 1, opacity))
		draw_set_transform(Vector2.ZERO)
	if player_hurt_t > 0:
		var t := 1.0 - player_hurt_t / 0.35
		for i in range(6):
			var direction := Vector2.from_angle(i * TAU / 6.0 + 0.3)
			var p := player + direction * (15.0 + t * 24.0)
			draw_line(p, p + direction.rotated(0.7) * 4.0, Color(0.88, 0.78, 0.5, 1.0 - t), 1.5, true)


## Draw last so hostile bullets never hide the exact centre during focused movement.
func _draw_player_hitbox() -> void:
	if not _down([KEY_SHIFT]):
		return
	draw_arc(player, 16.0, 0, TAU, 40, Color(0.5, 0.84, 0.77, 0.6), 1.0, true)
	draw_circle(player, 5.5, Color(0.03, 0.06, 0.08, 0.9))
	draw_circle(player, 4.5, Color.WHITE)
	draw_circle(player, 3.0, Color("ff5f5f"))


## Spell cards dim the field to violet and turn a huge mirror-back pattern behind the danmaku.
func _draw_spell_backdrop() -> void:
	var c := FIELD.get_center() + Vector2(0, -60)
	var tone := Color(0.16, 0.06, 0.22, 0.24) if stage() == 4 else Color(0.06, 0.08, 0.2, 0.2)
	draw_rect(FIELD, tone)
	for k in range(5):
		var r := 90.0 + k * 75.0
		var rot := age * (0.12 + k * 0.04) * (1.0 if k % 2 == 0 else -1.0)
		draw_arc(c, r, rot, rot + TAU, 72, Color(0.85, 0.75, 1.0, 0.07 + 0.02 * (k % 2)), 2.0 + (k % 2) * 3.0, true)
		# Moon phases ride the rings, as on the bronze disk.
		for m in range(6 + k * 2):
			var p := c + Vector2.from_angle(rot + m * TAU / (6 + k * 2)) * r
			# Background marks stay faint, without the opaque new-moon discs used by
			# the actual bell puzzle, so they cannot be mistaken for moving hazards.
			draw_arc(p, 6.0 + k, -PI * 0.5, PI * (0.5 + float((m + k) % 3) * 0.5), 20, Color(0.95, 0.9, 1.0, 0.09), 1.0, true)
	if g.tex.has("mirror"):
		draw_set_transform(c, -age * 0.15)
		draw_texture_rect(g.tex["mirror"], Rect2(-260, -260, 520, 520), false, Color(0.7, 0.6, 1.0, 0.07))
		draw_set_transform(Vector2.ZERO)
	if kind() == "final":
		# The thousand-year moon rises behind 镜魅.
		var moon := Vector2(FIELD.get_center().x, FIELD.position.y + 170)
		var grow := clampf(bt / 4.0, 0.0, 1.0)
		_draw_lunar_disc(moon, 270.0 * smoothstep(0.0, 1.0, grow), 0.64)


## 镜魅: a human reflection within the bronze mirror, framed by the existing aura and HP ring.
func _draw_boss() -> void:
	var p := boss_pos
	var hurt := boss_flash > 0
	var tint := Color(1.0, 0.92, 1.0) if stage() == 4 else Color(0.85, 0.92, 1.0)
	for r in range(6, 0, -1):
		draw_circle(p, 34 + r * 9, Color(tint, 0.03))
	for t in range(2):
		var rot := age * (0.8 if t == 0 else -0.6)
		var rad := 70.0 if t == 0 else 58.0
		var pts := PackedVector2Array()
		for k in range(4):
			pts.append(p + Vector2.from_angle(rot + k * TAU / 3.0) * rad)
		draw_polyline(pts, Color(tint, 0.45), 1.6, true)
	draw_arc(p, 78, 0, TAU, 64, Color(tint, 0.35), 1.2, true)
	draw_arc(p, 84, age * 0.5, age * 0.5 + TAU, 64, Color(tint, 0.2), 3.0, true)
	for k in range(12):
		var a := -age * 0.5 + k * TAU / 12.0
		draw_line(p + Vector2.from_angle(a) * 78, p + Vector2.from_angle(a) * 86, Color(tint, 0.5), 1.5)
	var key := "boss_mirror" if g.tex.has("boss_mirror") else ("boss_2" if stage() == 4 else "boss_1")
	if g.tex.has(key):
		var t: Texture2D = g.tex[key]
		var h := 150.0
		var w := t.get_size().x / t.get_size().y * h
		var bob := sin(age * 2.0) * 4.0
		draw_texture_rect(t, Rect2(p + Vector2(-w * 0.5, -h * 0.58 + bob), Vector2(w, h)), false, Color(1, 0.6, 0.6) if hurt else Color.WHITE)
	elif g.tex.has("mirror"):
		draw_set_transform(p, age * 0.9)
		draw_texture_rect(g.tex["mirror"], Rect2(-44, -44, 88, 88), false, Color(1, 0.6, 0.6) if hurt else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	if shield:
		draw_arc(p, 58, 0, TAU, 48, Color(0.7, 0.9, 1.0, 0.6 + 0.3 * sin(age * 6)), 3, true)
		draw_arc(p, 64, age, age + PI, 24, Color(0.7, 0.9, 1.0, 0.4), 2, true)
	# HP ring, Touhou style.
	if boss_active() and clear_t <= 0 and ending_t <= 0:
		var frac := clampf(boss_hp / float(PHASES[phase]["hp"]), 0.0, 1.0) if kind() != "final" else clampf(boss_hp, 0.0, 1.0)
		draw_arc(p, 96, -PI * 0.5, -PI * 0.5 + TAU * frac, 96, Color("ff8f7a") if not shield else Color("8fd6ff"), 4.0, true)
		draw_arc(p, 100, 0, TAU, 96, Color(1, 1, 1, 0.12), 1.0, true)


## Big effects drawn over the field: stage titles, spell cut-ins, the mirror shatter, the finale.
func _draw_effects() -> void:
	var c := FIELD.get_center()
	if title_t > 0 and title_t < 3.0:
		var a := clampf(minf(3.0 - title_t, title_t) * 2.0, 0.0, 1.0)
		var info: Dictionary = STAGES[stage()]
		var y := FIELD.position.y + 300
		draw_rect(Rect2(FIELD.position.x, y - 60, FIELD.size.x, 120), Color(0.02, 0.02, 0.06, 0.55 * a))
		draw_line(Vector2(FIELD.position.x + 60, y - 42), Vector2(FIELD.end.x - 60, y - 42), Color(0.84, 0.72, 0.48, 0.7 * a), 1.0)
		draw_line(Vector2(FIELD.position.x + 60, y + 46), Vector2(FIELD.end.x - 60, y + 46), Color(0.84, 0.72, 0.48, 0.7 * a), 1.0)
		_tc(c.x, y - 18, str(info["title"]), 15, Color(1, 0.85, 0.6, a))
		_title_center(c.x, y + 16, str(info["name"]), 34, Color(1, 0.97, 0.92, a))
		_tc(c.x, y + 38, str(info["sub"]), 13, Color(0.8, 0.85, 0.95, a))
	if cutin_t > 0:
		# Portrait sweeps diagonally across the field while the spell is declared.
		var k := 1.0 - cutin_t / 1.6
		var a2 := clampf(minf(k, 1.0 - k) * 5.0, 0.0, 1.0)
		var band_y := FIELD.position.y + 240
		draw_colored_polygon(PackedVector2Array([Vector2(FIELD.position.x, band_y + 40), Vector2(FIELD.end.x, band_y - 60), Vector2(FIELD.end.x, band_y + 140), Vector2(FIELD.position.x, band_y + 240)]), Color(0.25, 0.08, 0.3, 0.45 * a2))
		var key := "boss_2" if stage() == 4 else "boss_1"
		if g.tex.has(key):
			var t: Texture2D = g.tex[key]
			var h := 560.0
			var w := t.get_size().x / t.get_size().y * h
			var x := lerpf(FIELD.end.x + 40, FIELD.position.x - w * 0.4, ease(k, 0.4))
			draw_texture_rect(t, Rect2(x, band_y - 160, w, h), false, Color(1, 1, 1, a2))
		_t(Vector2(FIELD.position.x + 30, band_y + 200), "镜魅", 22, Color(1, 0.9, 1.0, a2))
	if shatter_t > 0:
		# White flash, then shards of the mirror flying out from 镜魅.
		var dur := 2.6 if ending_t <= 0 else 2.4
		var k2 := 1.0 - shatter_t / dur
		draw_rect(FIELD, Color(1, 1, 1, maxf(0.0, 0.85 - k2 * 3.0)))
		var rr := RandomNumberGenerator.new()
		rr.seed = 77
		for n in range(26):
			var dir := Vector2.from_angle(rr.randf() * TAU)
			var d := k2 * rr.randf_range(200.0, 520.0)
			var sp := boss_pos + dir * d
			var s := rr.randf_range(8.0, 22.0) * (1.0 - k2 * 0.5)
			var rot := k2 * rr.randf_range(-8.0, 8.0)
			var tri := PackedVector2Array([sp + Vector2.from_angle(rot) * s, sp + Vector2.from_angle(rot + 2.3) * s * 0.7, sp + Vector2.from_angle(rot + 4.0) * s])
			draw_colored_polygon(tri, Color(0.85, 0.9, 1.0, 0.8 * (1.0 - k2)))
		for n in range(3):
			draw_arc(boss_pos, k2 * (300.0 + n * 160.0), 0, TAU, 72, Color(1, 0.95, 1.0, 0.6 * (1.0 - k2)), 6.0 - n * 1.5, true)
	if clear_t > 0 and not clear_text.is_empty():
		var a3 := clampf(minf(2.6 - clear_t, clear_t) * 3.0, 0.0, 1.0)
		_title_center(c.x, FIELD.position.y + 360, clear_text.split("  ")[0], 32, Color(1, 0.9, 0.7, a3))
		_tc(c.x, FIELD.position.y + 396, clear_text.split("  ")[1], 18, Color(0.85, 0.9, 1.0, a3))


func _draw_bullet(i: int) -> void:
	var p := bp[i]
	var r := br[i]
	# New bullets bloom out of a bright flash before settling to size.
	if ba[i] < 0.12:
		var k := ba[i] / 0.12
		draw_circle(p, r * (3.0 - k * 2.0), Color(COLORS[bc[i] % COLORS.size()], 0.35 * (1.0 - k)))
		r *= 0.4 + 0.6 * k
	var c: Color = COLORS[bc[i] % COLORS.size()]
	match bs[i]:
		Shape.RICE, Shape.KUNAI:
			# Elongated along the velocity; kunai get a dark core and a point.
			var ang := bv[i].angle()
			draw_set_transform(p, ang, Vector2(1.9 if bs[i] == Shape.RICE else 2.4, 1.0))
			draw_circle(Vector2.ZERO, r + 2.5, Color(c, 0.55))
			draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 0.95))
			if bs[i] == Shape.KUNAI:
				draw_circle(Vector2.ZERO, r * 0.45, Color(c.darkened(0.4), 1))
			draw_set_transform(Vector2.ZERO)
		Shape.BIG:
			draw_circle(p, r + 7.0, Color(c, 0.22))
			draw_circle(p, r + 3.0, Color(c, 0.7))
			draw_circle(p, r, Color(1, 1, 1, 0.9))
			draw_circle(p, r * 0.7, Color(c, 0.9))
			if bb[i] == Move.BOUNCE or bb[i] == Move.SPLIT:
				var k := clampf(ba[i] / maxf(bx[i], 0.01), 0.0, 1.0)
				draw_arc(p, r + 5.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, Color(1, 1, 1, 0.6), 2, true)
		Shape.STAR:
			var pts := PackedVector2Array()
			var spin := ba[i] * 4.0
			for k in range(10):
				var rr := (r + 3.0) if k % 2 == 0 else (r + 3.0) * 0.45
				pts.append(p + Vector2.from_angle(spin + k * TAU / 10.0 - PI * 0.5) * rr)
			draw_colored_polygon(pts, c)
			draw_circle(p, r * 0.45, Color(1, 1, 1, 0.95))
		Shape.AMULET:
			draw_set_transform(p, bv[i].angle() + PI * 0.5)
			draw_rect(Rect2(-r * 0.8, -r * 1.4, r * 1.6, r * 2.8), Color(1, 1, 1, 0.95))
			draw_rect(Rect2(-r * 0.8, -r * 1.4, r * 1.6, r * 2.8), Color(c, 0.9), false, 2.0)
			draw_line(Vector2(0, -r), Vector2(0, r), Color(c.darkened(0.3), 1), 1.5)
			draw_set_transform(Vector2.ZERO)
		_:
			draw_circle(p, r + 4.0, Color(c, 0.35))
			draw_circle(p, r + 2.0, Color(c, 0.8))
			draw_circle(p, r, Color(1, 1, 1, 0.95))
			draw_circle(p, r * 0.6, c)


func _draw_lasers() -> void:
	for l in lasers:
		var o: Vector2 = l["o"]
		var d := _laser_dir(l)
		var e := o + d * 1400.0
		var t: float = l["t"]
		if t < l["warn"]:
			var blink := 0.35 + 0.35 * sin(t * 30.0)
			draw_line(o, e, Color(1, 0.6, 0.85, blink), 1.5)
		else:
			var k := clampf((t - l["warn"]) * 8.0, 0.0, 1.0)
			var fade := clampf((l["warn"] + l["life"] - t) * 5.0, 0.0, 1.0)
			var w: float = l["w"] * k
			draw_line(o, e, Color(1, 0.45, 0.75, 0.35 * fade), w + 12, true)
			draw_line(o, e, Color(1, 0.75, 0.9, 0.8 * fade), w, true)
			draw_line(o, e, Color(1, 1, 1, 0.95 * fade), w * 0.35, true)


func _draw_enemy_art(enemy: Dictionary) -> bool:
	var key := "ch7_" + str(enemy["kind"])
	if not g.tex.has(key):
		return false
	var texture: Texture2D = g.tex[key]
	var limit: Vector2 = {"crane": Vector2(46, 32), "diver": Vector2(30, 44), "lantern": Vector2(50, 76), "spirit": Vector2(88, 88), "wisp": Vector2(34, 42)}.get(str(enemy["kind"]), Vector2(40, 40))
	var scale_factor := minf(limit.x / texture.get_width(), limit.y / texture.get_height())
	var size := texture.get_size() * scale_factor
	var time: float = enemy["t"]
	var angle := sin(time * 2.0) * 0.075
	var stretch := Vector2.ONE
	var p: Vector2 = enemy["pos"]
	var tint := Color(1.0, 0.5, 0.45) if enemy["flash"] > 0 else Color.WHITE
	match str(enemy["kind"]):
		"crane":
			stretch.y = 0.88 + sin(time * 10.0) * 0.12
			angle = sin(time * 3.5) * 0.055
		"diver":
			var velocity: Vector2 = enemy["vel"]
			angle = velocity.angle() - PI * 0.5 if velocity.length() > 10 else 0.0
		"lantern":
			draw_circle(p, 30.0, Color(1.0, 0.45, 0.2, 0.06))
		"spirit":
			stretch = Vector2.ONE * (1.0 + sin(time * 3.0) * 0.035)
			draw_circle(p, 44.0, Color(0.58, 0.76, 1.0, 0.045))
		"wisp":
			stretch = Vector2(1.0 + sin(time * 5.0) * 0.05, 1.0 - sin(time * 5.0) * 0.04)
	draw_set_transform(p, angle, stretch)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, tint)
	draw_set_transform(Vector2.ZERO)
	return true


func _draw_enemies() -> void:
	for e in enemies:
		if _draw_enemy_art(e):
			continue
		var p: Vector2 = e["pos"]
		var hurt: bool = e["flash"] > 0
		if e["kind"] == "crane":
			# Folded paper crane: two wings that flap.
			var flap := sin(float(e["t"]) * 10.0) * 6.0
			var col := Color(1, 0.7, 0.7) if hurt else Color("f2ead6")
			draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -4 + flap), p + Vector2(0, 4), p + Vector2(-4, -6)]), col)
			draw_colored_polygon(PackedVector2Array([p + Vector2(16, -4 + flap), p + Vector2(0, 4), p + Vector2(4, -6)]), col.darkened(0.1))
			draw_line(p + Vector2(0, -8), p + Vector2(0, 10), Color("c4553f"), 2)
		elif e["kind"] == "diver":
			# A folded paper charm: a red-edged diamond that tilts toward its dive.
			var ang: float = (e["vel"] as Vector2).angle() - PI * 0.5 if (e["vel"] as Vector2).length() > 10 else 0.0
			var col2 := Color(1, 0.6, 0.6) if hurt else Color("f4e4c8")
			draw_set_transform(p, ang)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(-10, 0), Vector2(0, 16), Vector2(10, 0)]), col2)
			draw_polyline(PackedVector2Array([Vector2(0, -16), Vector2(-10, 0), Vector2(0, 16), Vector2(10, 0), Vector2(0, -16)]), Color("c4553f"), 2, true)
			draw_set_transform(Vector2.ZERO)
		elif e["kind"] == "lantern":
			# Red paper lantern with gold caps and a swaying tassel.
			var sway := sin(float(e["t"]) * 2.0) * 3.0
			draw_circle(p, 34, Color(1.0, 0.55, 0.3, 0.12))
			var body := Color(1, 0.75, 0.75) if hurt else Color("d0412f")
			draw_set_transform(p, sway * 0.03, Vector2(1.0, 1.25))
			draw_circle(Vector2.ZERO, 18, body)
			draw_circle(Vector2.ZERO, 11, Color(1.0, 0.75, 0.4, 0.5))
			draw_set_transform(Vector2.ZERO)
			draw_rect(Rect2(p + Vector2(-10, -27), Vector2(20, 5)), Color("d8b45a"))
			draw_rect(Rect2(p + Vector2(-10, 22), Vector2(20, 5)), Color("d8b45a"))
			draw_line(p + Vector2(0, 27), p + Vector2(sway, 42), Color("d8b45a"), 2)
		elif e["kind"] == "spirit":
			# The great wisp: layered rings that breathe, with orbiting sparks.
			var pulse2 := 1.0 + sin(float(e["t"]) * 4.0) * 0.12
			for r in range(5, 0, -1):
				draw_circle(p, (18 + r * 8) * pulse2, Color(0.55, 0.8, 1.0, 0.06))
			draw_circle(p, 20 * pulse2, Color(0.75, 0.92, 1.0, 0.7) if not hurt else Color(1, 0.6, 0.6, 0.8))
			draw_circle(p, 10, Color.WHITE)
			for n in range(6):
				draw_circle(p + Vector2.from_angle(float(e["t"]) * 2.0 + n * TAU / 6.0) * 40.0, 4, Color(0.8, 0.95, 1.0, 0.8))
		else:
			var pulse := 1.0 + sin(float(e["t"]) * 6.0) * 0.15
			draw_circle(p, 20 * pulse, Color(0.5, 0.8, 1.0, 0.15))
			draw_circle(p, 12 * pulse, Color(0.7, 0.9, 1.0, 0.5) if not hurt else Color(1, 0.6, 0.6, 0.7))
			draw_circle(p, 6, Color.WHITE)


func _draw_items() -> void:
	for it in items:
		var info: Dictionary = ITEM_INFO[str(it["kind"])]
		var p: Vector2 = it["pos"]
		var s: float = info["size"]
		var c: Color = info["color"]
		if it["kind"] == "star":
			draw_circle(p, s, Color(1, 0.95, 0.7, 0.9))
			continue
		# Off-screen marker when an item is above the field.
		if p.y < FIELD.position.y:
			draw_colored_polygon(PackedVector2Array([Vector2(p.x, FIELD.position.y + 2), Vector2(p.x - 5, FIELD.position.y + 10), Vector2(p.x + 5, FIELD.position.y + 10)]), c)
			continue
		draw_rect(Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), Color(c, 0.9))
		draw_rect(Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), Color(1, 1, 1, 0.7), false, 1.5)
		var label: String = info["label"]
		if not label.is_empty():
			var fs := int(s * 1.25)
			_tc(p.x, p.y + fs * 0.38, label, fs, Color.WHITE)


func _mask_outside_field() -> void:
	var full := Rect2(0, 0, 1440, 900)
	for r in [Rect2(0, 0, FIELD.position.x, 900), Rect2(FIELD.end.x, 0, 1440 - FIELD.end.x, 900), Rect2(FIELD.position.x, 0, FIELD.size.x, FIELD.position.y), Rect2(FIELD.position.x, FIELD.end.y, FIELD.size.x, 900 - FIELD.end.y)]:
		if g.tex.has("pagoda"):
			var t: Texture2D = g.tex["pagoda"]
			var crop := _cover_crop(t.get_size(), full.size)
			var src := Rect2(crop.position + r.position / full.size * crop.size, r.size / full.size * crop.size)
			draw_texture_rect_region(t, r, src, Color(0.28, 0.28, 0.36))
		else:
			draw_rect(r, Color("070a12"))


func _draw_puzzle_layer() -> void:
	if kind() == "bells":
		for i in range(bells.size()):
			var b: Dictionary = bells[i]
			var p: Vector2 = b["pos"]
			draw_line(Vector2(p.x, FIELD.position.y), p + Vector2(0, -22), Color(0.6, 0.55, 0.4, 0.6), 1)
			if g.tex.has("ch7_bell"):
				var bell_texture: Texture2D = g.tex["ch7_bell"]
				var bell_size := bell_texture.get_size() * minf(42.0 / bell_texture.get_width(), 50.0 / bell_texture.get_height())
				draw_texture_rect(bell_texture, Rect2(p - bell_size * 0.5, bell_size), false, Color("a7d6bf") if b["hit"] else Color.WHITE)
			else:
				var bell_pts := PackedVector2Array([p + Vector2(-16, 14), p + Vector2(-12, -14), p + Vector2(12, -14), p + Vector2(16, 14)])
				draw_colored_polygon(bell_pts, Color("b08a3e") if not b["hit"] else Color("6f8f80"))
				draw_arc(p + Vector2(0, -14), 12, PI, TAU, 12, Color("d7b77b"), 2)
			_moon(p + Vector2(0, 45), 16, int(b["phase"]), Color.WHITE)
			if b["hit"]:
				draw_arc(p, 30, 0, TAU, 32, Color(0.7, 1, 0.8, 0.7), 2, true)
		# Order reminder from the stele.
		_t(Vector2(FIELD.position.x + 14, FIELD.position.y + 60), "塔碑：先朔 · 次弦 · 后望", 14, Color(1, 1, 1, 0.6))
		for k in range(3):
			_moon(Vector2(FIELD.position.x + 30 + k * 34, FIELD.position.y + 86), 10, k, Color(0.95, 0.93, 0.8, 1.0 if k < bell_progress else 0.4))
		if not shield:
			_tc(FIELD.get_center().x, FIELD.position.y + 120, "镜障已破  %.0f" % shield_t, 16, Color(0.7, 1, 0.8))
	if kind() == "mirror":
		for im in images:
			var p: Vector2 = im["pos"]
			var a: float = im["alpha"]
			for r in range(4, 0, -1):
				draw_circle(p, 26 + r * 8, Color(0.8, 0.9, 1.0, 0.03 * a))
			if g.tex.has("mirror"):
				draw_set_transform(p, age * 0.9)
				draw_texture_rect(g.tex["mirror"], Rect2(-40, -40, 80, 80), false, Color(1, 1, 1, a * 0.95))
				draw_set_transform(Vector2.ZERO)
			var perm: Array = im["perm"]
			_box(Rect2(p + Vector2(-58, 50), Vector2(116, 34)), Color(0.05, 0.07, 0.1, 0.8 * a), 6, Color(0.84, 0.72, 0.48, 0.6 * a))
			for k in range(3):
				_glyph(p + Vector2(-34 + k * 34, 67), int(perm[k]), 10, Color(0.96, 0.84, 0.6, a))
		_t(Vector2(FIELD.position.x + 14, FIELD.position.y + 60), "工坊石壁：山 → 月 → 水", 14, Color(1, 1, 1, 0.6))


func _draw_hud() -> void:
	var x := FIELD.end.x + 40
	_title(Vector2(x, 80), "第七章  ·  月下之战", 27, Pal.PAPER)
	_t(Vector2(x, 120), "得分  %09d" % score, 16, Pal.GOLD)
	_t(Vector2(x, 150), "掠光  %d" % graze, 15, Pal.MUTED)
	_t(Vector2(x, 200), "护魂灯", 15, Pal.PAPER)
	if g.zun_mode:
		_t(Vector2(x + 50, 206), "∞", 22, Color("ff8f7a"))
	else:
		for i in range(lives):
			var flame := Vector2(x + 61 + i * 26, 196)
			draw_colored_polygon(PackedVector2Array([flame + Vector2(0, -10), flame + Vector2(-5, 0), flame + Vector2(-4, 6), flame + Vector2(4, 6), flame + Vector2(5, 0)]), Color("ffad78"))
			draw_circle(flame + Vector2(0, 2), 2.5, Color("fff1c7"))
			draw_line(flame + Vector2(-7, 9), flame + Vector2(7, 9), Pal.GOLD, 2, true)
	_t(Vector2(x, 236), "月华", 15, Pal.PAPER)
	if g.zun_mode:
		_t(Vector2(x + 50, 242), "∞", 22, Color("8fd6ff"))
	else:
		for i in range(bombs):
			draw_circle(Vector2(x + 62 + i * 26, 230), 8, Color("8fd6ff"))
	# Power gauge 0.00–4.00 with level ticks.
	_t(Vector2(x, 272), "镜力", 15, Pal.PAPER)
	var gauge := Rect2(x + 50, 260, 200, 14)
	draw_rect(gauge, Color(0.15, 0.08, 0.08, 0.9))
	var pc := Color("ffd24a") if power >= MAX_POWER else Color("ff6f5e")
	if full_flash > 0 and int(age * 12) % 2 == 0:
		pc = Color.WHITE
	draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * power / MAX_POWER, gauge.size.y)), pc)
	for k in range(1, 4):
		var tx := gauge.position.x + gauge.size.x * k / MAX_POWER
		draw_line(Vector2(tx, gauge.position.y), Vector2(tx, gauge.end.y), Color(0, 0, 0, 0.6), 1)
	_t(Vector2(gauge.end.x + 8, 272), "盈" if power >= MAX_POWER else "%.2f" % power, 13, pc)
	_t(Vector2(x, 302), "月辉", 15, Pal.PAPER)
	_t(Vector2(x + 50, 302), "%d   （%d 枚续灯）" % [points, next_extend], 13, Color("9fc4ff"))
	_t(Vector2(x, 346), "第 %d / 4 境   ·   %s" % [stage(), STAGES[stage()]["name"]], 15, Pal.GOLD)
	var row := 0
	var last_stage := 0
	for i in range(PHASES.size()):
		var c := Pal.JADE if i < phase else (Pal.GOLD if i == phase else Color("3a4a48"))
		var st := int(PHASES[i]["stage"])
		if st != last_stage and st >= 3:
			_t(Vector2(x, 376 + row * 24), STAGES[st]["name"], 12, Color(c, 0.8))
			row += 1
		last_stage = st
		var indent := 14.0 if st >= 3 else 0.0
		_t(Vector2(x + indent, 376 + row * 24), ("✓ " if i < phase else "· ") + str(PHASES[i]["name"]), 14, c)
		row += 1
	var tag_y := 392.0 + row * 24
	if easy:
		_t(Vector2(x, tag_y), "简单模式", 13, Pal.JADE)
		tag_y += 24
	if g.zun_mode:
		_t(Vector2(x, tag_y), "月华护佑 · 护魂灯与月华不减", 13, Color("ffd27a"))
	# Isolated emblem stays entirely in the lower-right side panel, below all status tags.
	if g.tex.has("ch7_mirror_moon_logo"):
		var logo: Texture2D = g.tex["ch7_mirror_moon_logo"]
		var logo_scale := minf(328.0 / logo.get_width(), 204.0 / logo.get_height())
		var logo_size := logo.get_size() * logo_scale
		var logo_position := Vector2(FIELD.end.x + (400.0 - logo_size.x) * 0.5, 760.0 - logo_size.y * 0.5)
		draw_texture_rect(logo, Rect2(logo_position, logo_size), false)
	if bonus_t > 0:
		var ba2 := minf(1.0, bonus_t * 2.0)
		_tc(FIELD.get_center().x, FIELD.position.y + 160, bonus_text, 20, Color(1, 0.85, 0.5, ba2) if bonus_text.begins_with("破阵奖励") else Color(0.7, 0.7, 0.75, ba2))
	var lx := 40.0
	_t(Vector2(lx, 80), "操作", 16, Pal.GOLD)
	var lines := ["方向键 / WASD  移动", "Shift  凝神 · 低速避让", "Z  镜芒（按住）", "X  月华护身（清屏）", "Esc  暂停"]
	for i in range(lines.size()):
		_t(Vector2(lx, 112 + i * 28), lines[i], 14, Pal.MUTED)
	_t(Vector2(lx, 290), "当前镜阵", 16, Pal.GOLD)
	var rows := _wrap(Vector2(lx, 320), hint(), 320, 14, Pal.SOFT, 24)
	# Item legend.
	var ly := 340.0 + rows * 24
	_t(Vector2(lx, ly), "灵物", 16, Pal.GOLD)
	var legend := [["p", "微光  镜力 +0.05"], ["P", "凝光  镜力 +1"], ["pt", "月辉  高处加分，25 枚续灯"], ["bomb", "护身月华 +1"], ["life", "护魂灯 +1"], ["full", "镜力充盈"]]
	for i in range(legend.size()):
		var info: Dictionary = ITEM_INFO[legend[i][0]]
		var ip := Vector2(lx + 10, ly + 26 + i * 26)
		var s := 8.0
		draw_rect(Rect2(ip - Vector2(s, s), Vector2(s, s) * 2.0), info["color"])
		_tc(ip.x, ip.y + 4, str(info["label"]), 10, Color.WHITE)
		_t(Vector2(lx + 28, ip.y + 5), legend[i][1], 13, Pal.MUTED)
	if not boss_active() and kind() != "mirror":
		_t(Vector2(FIELD.position.x + 10, FIELD.position.y + 24), "%s  ·  %s" % [STAGES[stage()]["title"], PHASES[phase]["name"]], 14, Color(0.85, 0.9, 1.0, 0.7))
		return
	# Boss HP bar.
	var hp_rect := Rect2(FIELD.position.x + 10, FIELD.position.y + 10, FIELD.size.x - 20, 8)
	draw_rect(hp_rect, Color(0.2, 0.1, 0.1, 0.8))
	var frac := clampf(boss_hp / float(PHASES[phase]["hp"]), 0.0, 1.0) if kind() != "final" else clampf(boss_hp, 0.0, 1.0)
	draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * frac, hp_rect.size.y)), Color("ff8f7a") if not shield else Color("8fd6ff"))
	_t(Vector2(FIELD.position.x + 10, FIELD.position.y + 38), "镜魅", 14, Pal.PAPER)
	var left := maxf(0.0, PHASES[phase]["time"] - bt)
	_t(Vector2(FIELD.end.x - 60, FIELD.position.y + 38), "%02d" % int(left), 18, Pal.PAPER if left > 10 else Pal.RED)


func _draw_pause() -> void:
	draw_rect(FIELD, Color(0, 0, 0, 0.6))
	var card := Rect2(FIELD.get_center().x - 220, 330, 440, 320)
	_panel(card)
	if game_over:
		_title_center(card.get_center().x, 380, "魂灯暂熄", 36, Pal.PAPER)
		_tc(card.get_center().x, 412, "从当前阶段重新开始。", 14, Pal.MUTED)
		_button("retry", Rect2(card.position.x + 40, 440, 360, 42), "再试一次", true, 16)
		_button("retry_easy", Rect2(card.position.x + 40, 492, 360, 42), "简单模式重试（弹幕更稀疏）", false, 15)
		_button("menu_title", Rect2(card.position.x + 40, 542, 174, 36), "返回标题", false, 13)
		_button("menu_map", Rect2(card.position.x + 226, 542, 174, 36), "返回舆图", false, 13)
	else:
		_title_center(card.get_center().x, 380, "暂停", 36, Pal.PAPER)
		_button("resume", Rect2(card.position.x + 40, 420, 360, 42), "继续  Esc", true, 16)
		_button("restart", Rect2(card.position.x + 40, 472, 360, 42), "重新开始本关", false, 15)
		_button("menu_title", Rect2(card.position.x + 40, 524, 174, 42), "返回标题", false, 15)
		_button("menu_map", Rect2(card.position.x + 226, 524, 174, 42), "返回舆图", false, 15)
		_button("settings", Rect2(card.position.x + 40, 580, 360, 42), "行旅设置", false, 15)

