extends RefCounted
## Automated checks.  --self-test : logic of every chapter.   --ui-test : real viewport clicks.
## --capture=path --stage=name : renders one screen to a PNG for documentation.

const Story = preload("res://scripts/data/story.gd")
var g
var _count := 0
var _failed := 0


func _init(game) -> void:
	g = game


func _expect(condition: bool, label: String) -> void:
	if not condition:
		print("FAIL: " + label)
		_failed += 1
		return
	print("PASS: " + label)
	_count += 1


func _frames(n := 2) -> void:
	for i in range(n):
		await g.get_tree().process_frame


## Chapter 7: finish the current phase (on the clock / HP) and step through any interlude.
func _ch7_next(c) -> void:
	var start: int = c.phase
	c.bt = maxf(c.bt, float(c.PHASES[start]["time"]) + 5.0) if c.WAVES.has(c.kind()) else c.bt
	c.boss_hp = 0
	for i in range(400):
		c.invuln = 9.0
		c.step(1.0 / 60.0)
		if c.phase != start:
			return


# ================================================================== logic test
func run_logic() -> void:
	g.reset_progress()
	_expect(g.shard_count() == 0 and g.cleared.is_empty(), "new game has clean progress")
	# ---- prologue
	g._switch("prologue")
	var opening = g.scene
	_expect(opening.phase == 1, "prologue dialogue finishes and asks for the damaged bowl record")
	opening.act("scan")
	_expect(opening.phase == 1, "scan is gated by inspecting the bowl")
	opening.act("archive")
	opening.act("archive_confirm")
	_expect(opening.inspected and opening.phase == 2 and g.flags.get("lab_bowl_seen", false), "the four missing pieces are recorded before calibration")
	opening.act("scan")
	_expect(opening.phase == 2, "an unaligned mirror cannot start scanning")
	opening._adjust(0.0)
	opening.tick(0.6, true)
	_expect(not opening.calibrated, "a modal pause cannot complete calibration")
	opening.tick(0.3, false)
	_expect(not opening.calibrated, "alignment needs a brief stable hold")
	opening.tick(0.3, false)
	_expect(opening.calibrated, "holding the target alignment enables scanning")
	opening._adjust(8.0)
	_expect(not opening.calibrated, "changing the angle invalidates the previous calibration")
	opening._adjust(0.0)
	opening.tick(0.6, false)
	opening.act("scan")
	opening.tick(1.1, false)
	opening.act("scan")
	_expect(opening.phase == 3 and is_equal_approx(opening.scan_time, 1.1), "repeated clicks cannot restart the scan")
	opening.tick(2.0, true)
	_expect(is_equal_approx(opening.scan_time, 1.1), "scan progress pauses while an overlay is open")
	opening._adjust(48.0)
	_expect(opening.alignment == 0.0, "the turntable is locked during acquisition")
	opening.tick(4.0, false)
	_expect(opening.phase == 5 and g.screen == "prologue", "the anomaly dialogue completes before the white-out transition")
	if opening.film_real:
		var skip := InputEventKey.new()
		skip.keycode = KEY_SPACE
		opening.key(skip)
	else:
		opening.tick(1.4, false)
	_expect(g.screen == "ch1", "the completed opening leads to the workshop")
	# ---- chapter 1
	var c1 = g.scene
	_expect(g.flags.has("told_truth"), "meeting Wen records the dialogue choice")
	c1.act("stand")
	_expect(not c1.mirror_placed, "empty inventory cannot place mirror")
	c1.dials = [0, 1, 2]
	c1._check_seal()
	_expect(not c1.cabinet_open, "seal needs the wall clue even with correct symbols")
	c1.act("note")
	c1.act("pickup")
	g.overlay.close_panel()
	_expect(c1.mirror_found and c1.selected == "mirror", "mirror goes to inventory selected")
	c1.act("stand")
	_expect(c1.cinematic == "place" and not c1.mirror_placed, "mirror placement waits for the seating animation")
	c1.tick(1.2, false)
	_expect(c1.mirror_placed, "mirror placed on stand")
	c1._turn(1)
	_expect(not c1.revealed, "wrong beam angle does not reveal")
	for i in range(3):
		c1._turn(1)
	_expect(c1.revealed, "reflected beam reveals glyphs")
	c1.tick(2.9, false)
	c1.dials = [2, 1, 0]
	c1._check_seal()
	_expect(not c1.cabinet_open, "wrong glyph order rejected")
	c1.dials = [0, 1, 2]
	c1._check_seal()
	_expect(c1.cinematic == "unlock" and not c1.cabinet_open, "correct symbols start the latch sequence before the chest is usable")
	c1.tick(1.2, false)
	_expect(c1.lid_t == 0.0, "the lid stays shut until both bolts have retracted")
	c1.act("chest")
	_expect(not g.shards[0], "the shard cannot be picked through the opening animation")
	c1.tick(1.1, false)
	_expect(c1.lid_t > 0.0 and c1.lid_t < 1.0, "the lid is hinged halfway through the opening")
	c1.tick(2.0, false)
	_expect(c1.cabinet_open, "correct order opens casket")
	c1.act("chest")
	_expect(c1.cinematic == "shard" and g.overlay.panel.is_empty(), "the shard reveal plays before its artifact card")
	c1.tick(1.7, false)
	g.overlay.close_panel()
	_expect(c1.cinematic == "wind", "Wen's reaction leads into the gust transition")
	var transition_oil: float = c1.oil
	c1.tick(3.2, false)
	_expect(c1.oil == transition_oil, "the hand lamp consumes no oil during the wind transition")
	_expect(g.shards[0] and c1.dark, "first shard collected, lights go out")
	c1.lamp_pos = c1.hidden_at["coin"]
	c1.act("found_coin")
	g.overlay.close_panel()
	_expect(not c1.search_done and g.collected.has("coin"), "decoy object found but search continues")
	var before_oil: float = c1.oil
	c1.lamp_speed = 2000.0
	c1.tick(1.0, false)
	_expect(c1.oil < before_oil - 20.0, "moving the lamp fast burns more oil")
	c1.oil = 0.5
	c1.tick(1.0, false)
	_expect(c1.refilling > 0, "empty lamp triggers a refill pause")
	c1.act("found_shard")
	c1.tick(1.7, false)
	g.overlay.close_panel()
	_expect(g.shards[1] and g.cleared.has("ch1"), "second shard clears chapter 1")
	# ---- map gating
	g._switch("map")
	g.scene.act("ch4")
	_expect(g.screen == "map", "locked chapter cannot be entered")
	g.scene.act("ch2")
	_expect(g.screen == "ch2", "chapter 2 unlocked after chapter 1")
	# ---- chapter 2
	var c2 = g.scene
	c2.act("kang")
	_expect(c2.phase == "investigate", "debate needs evidence first")
	for id in ["ledger", "bundle", "gong", "camel"]:
		c2.act(id)
		g.overlay.close_panel()
	_expect(c2.evidence.size() == 4 and not c2.evidence.has("camel"), "inspection yields three 物证 plus the shard; lore spots give none")
	c2.act("kang")
	_expect(c2.phase == "debate", "talking to Kang starts the debate")
	var credit0: int = c2.credit
	c2.line_i = 0
	c2.bullet = c2.evidence.find("shard")
	c2._fire(Vector2.ZERO, true)
	c2._resolve_shot()
	_expect(c2.credit == credit0 - 1 and c2.round_i == 0, "wrong statement costs credit")
	c2.line_i = 1
	c2.bullet = c2.evidence.find("gong")
	c2._fire(Vector2.ZERO, true)
	c2._resolve_shot()
	_expect(c2.credit == credit0 - 2, "wrong evidence on the right statement costs credit")
	c2.credit = 1
	c2.line_i = 3
	c2._fire(Vector2.ZERO, true)
	c2._resolve_shot()
	await _frames()
	_expect(c2.credit == c2.credit_max and c2.line_i == 0, "running out of credit restarts the round")
	for r in range(3):
		var lines: Array = Story.TESTIMONY[r]["lines"]
		for i in range(lines.size()):
			if not lines[i]["answer"].is_empty():
				c2.line_i = i
				c2.bullet = c2.evidence.find(lines[i]["answer"][0])
				break
		c2._fire(Vector2.ZERO, true)
		c2._resolve_shot()
		await _frames(3)
		if r < 2:
			_expect(c2.round_i == r + 1, "breaking testimony %d advances the debate" % (r + 1))
	g.overlay.close_panel()
	_expect(g.shards[2] and g.cleared.has("ch2"), "winning the debate returns the third shard")
	# ---- chapter 3 (胡旋)
	g._switch("map")
	g.scene.act("ch4")
	_expect(g.screen == "map", "night chapter stays locked until the tavern is cleared")
	g.scene.act("ch3")
	_expect(g.screen == "ch3", "tavern chapter unlocks after chapter 2")
	var h = g.scene
	_expect(h.get_script().resource_path == "res://scripts/chapters/ch3_huxuan.gd" and h.has_method("dance_state"), "the main chapter registry loads the optimized dance presentation")
	if h.has_method("dance_state"):
		h.song_t = 10.6
		var opening_pose: Dictionary = h.dance_state()
		h.song_t = 55.25
		var finale_pose: Dictionary = h.dance_state()
		var used_poses := {}
		for sample in range(32):
			h.song_t = 54.0 + sample * 0.09
			used_poses[h.dance_state()["frame"]] = true
		_expect(opening_pose["strength"] < finale_pose["strength"] and used_poses.size() == 8, "the live dancer uses eight poses and increasing ribbon motion across sections")
	var Chart = preload("res://scripts/data/huxuan_chart.gd")
	var sorted_ok := true
	for i in range(1, Chart.NOTES.size()):
		if Chart.NOTES[i]["t"] < Chart.NOTES[i - 1]["t"]:
			sorted_ok = false
	_expect(sorted_ok and Chart.SECTIONS.size() == 3 and Chart.SECTIONS[2]["bpm"] > Chart.SECTIONS[0]["bpm"], "chart is time-ordered and speeds up through 散序 · 中序 · 入破")
	var song: AudioStream = g.tracks.get("huxuan")
	_expect(song != null and absf(song.get_length() - Chart.LENGTH) < 0.3, "generated music length matches the chart")
	h.act("mi")
	_expect(h.phase == "explore", "the dancer wants you to ask around first")
	for id in ["barkeep", "stairs", "drum", "jar"]:
		h.act(id)
		g.overlay.close_panel()
	h.act("mi")
	_expect(h.phase == "ready", "after asking around, the dancer offers the drum challenge")
	h.start_song(false)
	var clk0: float = h.clock()
	await g.get_tree().create_timer(0.3).timeout
	var clk1: float = h.clock()
	_expect(clk0 < -1.5 and clk1 > clk0 + 0.1, "the real song clock counts down from -2 s and keeps running")
	var n_normal: int = h.notes.size()
	var first: Dictionary = h.notes[0]
	_expect(h.press(first["k"], first["t"] + 0.02) == "great", "a hit within 45 ms is 良")
	var second: Dictionary = h.notes[1]
	_expect(h.press(second["k"], second["t"] - 0.08) == "good", "a hit within 100 ms is 可")
	var third: Dictionary = h.notes[2]
	_expect(h.press("ka" if third["k"] == "don" else "don", third["t"]) == "wrong" and h.combo == 0, "the wrong drum breaks the combo")
	h.sweep(9999.0)
	h.finish_song()
	_expect(not h.result["pass"] and h.phase == "result", "missing most notes fails the dance")
	h.start_song(true)
	_expect(h.notes.size() < n_normal, "easy mode drops some notes")
	h.start_song(false)
	var rolls := 0
	for n in h.notes:
		if n["k"] == "roll":
			for k in range(4):
				if h.press("don", n["t"] + 0.15 + k * 0.05) == "roll":
					rolls += 1
		else:
			h.press(n["k"], n["t"])
	h.finish_song()
	_expect(h.result["pass"] and h.accuracy() == 1.0 and rolls > 0, "hitting every note passes with 100% and rolls count")
	# Autoplay must survive uneven render intervals and unlock the actual next chapter.
	g.stats["dance_acc"] = 0.63
	h.set_autoplay(true)
	h.start_song(false)
	var demo_clock := -2.0
	var demo_steps := [0.033, 0.17, 0.83, 2.7]
	var demo_i := 0
	while h.phase == "play" and demo_i < 300:
		demo_clock += demo_steps[demo_i % demo_steps.size()]
		h.test_clock = demo_clock
		h.tick(0.016, false)
		demo_i += 1
	_expect(h.phase == "result" and h.result["pass"] and h.result["auto"] and h.accuracy() == 1.0, "autoplay completes the full chart without misses across uneven frames")
	_expect(h.roll_hits > 0 and float(g.stats["dance_acc"]) == 0.63, "automatic rolls count and the marked demo result preserves manual accuracy")
	h.start_song(false)
	h.set_autoplay(false)
	h.test_clock = 8.5
	h.tick(0.016, false)
	var missed: int = h.counts["miss"]
	h.set_autoplay(true)
	h.test_clock = 11.0
	h.tick(0.016, false)
	_expect(missed > 0 and h.counts["miss"] == missed and h.counts["great"] > 0, "enabling autoplay mid-song plays future notes without rewriting earlier misses")
	h.start_song(false)
	_expect(h.test_clock == -INF and h.auto_used, "restarting resets the preview clock and retains the chosen automatic mode")
	h.test_clock = 99.0
	h.tick(0.016, false)
	var all_poses := true
	for i in range(8):
		all_poses = all_poses and g.tex.has("mi_dance_%d" % i)
	_expect(all_poses and g.heading.has_char("旋".unicode_at(0)) and g.face.has_char("羯".unicode_at(0)), "dance assets and bundled Chinese title/body glyphs load")
	h.act("claim")
	g.overlay.close_panel()
	_expect(g.cleared.has("ch3") and g.flags.get("ashi_joined", false), "passing with autoplay clears chapter 3 and 阿拾 joins")
	# ---- chapter 4 (夜行)
	g._switch("map")
	g.scene.act("ch4")
	_expect(g.screen == "ch4", "night chapter unlocks after chapter 3")
	var c4 = g.scene
	_expect(c4.actors.size() == 7 and c4.su_actor.joints.has("Shin_L") and c4.actors[0].joints.has("Cape"), "night characters retain leg/arm joints and guard capes")
	_expect(c4.su_actor.joints.has("CoatHem") and c4.su_node.find_child("Hand_L", true, false) != null,
		"approved A coat and solid-hand meshes load in the playable chapter")
	_expect(c4.su_node.position.distance_to(c4.ashi_node.position) <= 0.72, "Ashi starts close behind Su rather than a full grid tile away")
	var still_leg: Transform3D = c4.su_actor.rest["Leg_L"]
	var still_arm: Transform3D = c4.su_actor.rest["Arm_R"]
	var still_head: float = c4.su_actor.joints["Head"].global_position.y
	var still_position: Vector3 = c4.su_node.position
	c4.su_node.position += Vector3(0.16, 0, 0)
	c4.su_actor.update(0.05, false, false, false)
	_expect(not c4.su_actor.joints["Leg_L"].transform.is_equal_approx(still_leg), "adapted A thigh pivots respond to walking displacement")
	c4.su_actor.throw_stone()
	c4.su_actor.update(0.15, false, false, false)
	_expect(not c4.su_actor.joints["Arm_R"].transform.is_equal_approx(still_arm), "adapted A right arm performs the stone throw")
	for frame in range(60):
		c4.su_actor.update(1.0 / 60.0, true, false, false)
	_expect(c4.su_actor.joints["Head"].global_position.y < still_head - 0.08, "A hiding pose bends the articulated body below its standing height")
	c4.su_node.position = still_position
	c4.su_actor.snap()
	_expect(c4.su_actor.crouch == 0.0 and c4.su_actor.joints["Leg_L"].transform.is_equal_approx(still_leg),
		"checkpoint reset restores A's standing joints and clears the hiding blend")
	var pose_state: Dictionary = c4.state.duplicate(true)
	c4.state["p"] = Vector2i(10, 2)
	c4._animate(0.016)
	var follower_distance: float = c4.su_node.position.distance_to(c4.ashi_node.position)
	_expect(follower_distance >= 0.46 and follower_distance <= 0.721, "Ashi stays close without body overlap when several moves arrive before a frame")
	c4._throw_visual(Vector2i(12, 3))
	c4.state = pose_state
	c4._sync_3d(true)
	_expect(c4.stone_time < 0.0 and not c4.stone_fx.visible and c4.su_actor.throw_time == 0.0, "checkpoint snap clears flight and character throw poses")
	var route: Array = c4.solve()
	_expect(not route.is_empty() and route.size() < c4.DAWN, "the night map is solvable before dawn (%d moves)" % route.size())
	var gate_closed: bool = not c4.walkable(Vector2i(22, 11), 0)
	_expect(gate_closed and c4.walkable(Vector2i(22, 11), c4.GATE_PERIOD), "the ward gate opens and closes with the drum")
	var vz: Array = c4.vision(Vector2i(8, 6), Vector2i(1, 0), 0)
	_expect(vz.has(Vector2i(13, 6)), "vision reaches 5 tiles under lanterns")
	var vdark: Array = c4.vision(Vector2i(15, 2), Vector2i(1, 0), 0)
	_expect(vdark.has(Vector2i(18, 2)) and not vdark.has(Vector2i(19, 2)), "vision is only 3 tiles in the dark")
	_expect(not c4.vision(Vector2i(3, 6), Vector2i(0, -1), 0).has(Vector2i(3, 9)), "walls and facing limit vision")
	var s0: Dictionary = c4._fresh_state()
	s0["p"] = Vector2i(5, 6)
	var seen_open: bool = c4.is_caught(s0, s0)
	_expect(not seen_open, "hiding in the canal keeps you unseen in a guard's line")
	var bad: Dictionary = c4.simulate(c4.state, Vector2i(0, -1))
	_expect(not bad["ok"], "walls block movement")
	var st: Dictionary = c4._fresh_state()
	st["p"] = Vector2i(10, 2)
	var r: Dictionary = c4.simulate(st, {"stone": Vector2i(12, 3)})
	var look: Vector2i = c4.pose(1, r["state"]["gs"])[1]
	_expect(r["ok"] and r["state"]["stones"] == c4.STONES - 1 and look.x == 0 and r["state"]["gs"][1][1] > 0, "a pebble makes nearby guards stop and look")
	_expect(not c4.simulate(st, {"stone": Vector2i(20, 2)})["ok"], "pebbles have limited range")
	var distracted: Dictionary = r["state"].duplicate(true)
	var source_snapshot := JSON.stringify(distracted)
	var after_throw: Array = c4.solve(c4.DAWN, distracted)
	_expect(JSON.stringify(distracted) == source_snapshot, "guide calculation preserves the live patrol and distraction state")
	var safe_after_throw := not after_throw.is_empty()
	for move in after_throw:
		var predicted: Dictionary = c4.simulate(distracted, move)
		safe_after_throw = safe_after_throw and predicted["ok"] and not predicted["caught"]
		distracted = predicted["state"]
	_expect(safe_after_throw and distracted["p"] == c4.goal(), "fast guide safely replans through distraction expiry and the changing gate")
	_expect(c4.solve(1).is_empty(), "guide respects a deadline too short to reach the temple")
	var caught_at := -1
	for i in range(c4.DAWN):
		var probe: Dictionary = c4.simulate(c4.state, Vector2i(1, 0) if c4.walkable(c4.state["p"] + Vector2i(1, 0), 0) else Vector2i.ZERO)
		if probe["caught"]:
			caught_at = i
			break
		c4.state = probe["state"]
	_expect(caught_at >= 0, "walking straight down the street gets you caught")
	# ---- 攻略模式
	c4.state = c4._fresh_state()
	c4.toggle_guide()
	_expect(c4.guiding() and c4.guide_route.size() == route.size(), "G turns on the guide with a full route")
	c4.do(Vector2i(1, 0))
	c4.do(Vector2i(1, 0))
	_expect(c4.phase == "play" and not c4.guide_route.is_empty(), "guide re-plans after the player strays from its route")
	var follow_guard := 0
	while c4.phase == "play" and not c4.guide_route.is_empty() and follow_guard < 300:
		follow_guard += 1
		c4.do(c4.guide_route[0])
		g.overlay.close_panel()
	_expect(c4.phase == "done", "following the guide step by step reaches the gate")
	g.cleared.erase("ch4")
	c4.toggle_guide()
	_expect(not c4.guiding(), "G turns the guide off")
	c4.phase = "play"
	c4.state = c4._fresh_state()
	c4._sync_3d(true)
	var companion_clear := true
	var companion_close := true
	for d in route:
		c4.do(d)
		g.overlay.close_panel()
		for frame in range(35):
			c4._animate(1.0 / 60.0)
			companion_clear = companion_clear and c4._visual_clear(c4.ashi_node.position)
			var gap: float = c4.ashi_node.position.distance_to(c4.su_node.position)
			companion_close = companion_close and gap >= 0.459 and gap <= 0.721
		if c4.phase != "play":
			break
	g.overlay.close_panel()
	_expect(c4.phase == "done" and g.cleared.has("ch4"), "following the solved route clears the night chapter")
	_expect(companion_clear and companion_close, "companion clears alley corners and maintains body separation throughout the solved route")
	# ---- chapter 5: 曲江诗牌 (deck-building poetry)
	g._switch("map")
	g.scene.act("ch7")
	_expect(g.screen == "map", "chapter 5 must be cleared before the tower battle unlocks")
	var R = preload("res://scripts/core/poem_rules.gd")
	var PC = preload("res://scripts/data/poem_cards.gd")
	var rnd0: Dictionary = PC.ROUNDS[0]
	var good := [R.word("曲江"), R.word("流水"), R.foot("花")]          # 仄平 平仄 平 : 2nd 平, 4th 仄
	_expect(R.tones(good) == "ZPPZP" and R.tone_ok(good), "二四六分明: 曲江流水花 alternates tones on syllables 2 and 4")
	_expect(not R.tone_ok([R.word("春风"), R.word("清光"), R.foot("家")]), "a line with 平 on both 2 and 4 breaks the tone rule")
	_expect(not R.tone_ok([R.word("曲江"), R.word("题名"), R.foot("花")]), "three level tones at the end (三平尾) are rejected")
	_expect(R.tone_ok([R.word("春风"), R.word("得意"), R.word("马蹄"), R.foot("春")]), "七言 春风得意马蹄春 keeps 2/4/6 alternating")
	_expect(R.rhymes(good, "麻") and not R.rhymes([R.word("曲江"), R.word("流水"), R.foot("月")], "麻"), "a 仄 foot such as 月 never counts as rhyme")
	_expect(not R.is_line([R.word("春风"), R.foot("花")]) and not R.is_line([R.foot("花"), R.word("春风"), R.word("杏花")]), "a line needs 2–3 words with the foot last")
	var base: Dictionary = R.score_line(good, [], [], rnd0)
	_expect(base["lu"] and base["rhyme"] and base["mult"] == 7.0, "合律 and 押韵 each add 3 韵 to the base 1")
	var pair: Dictionary = R.score_line([R.word("落日"), R.word("白云"), R.foot("家")], good, [], rnd0)
	_expect(pair["pair"] and not R.paired([R.word("曲江"), R.word("流水"), R.foot("家")], good), "对仗 needs matching parts of speech, different words and opposite tones")
	var with_charm: Dictionary = R.score_line(good, [], ["qujiang"], rnd0)
	_expect(with_charm["chips"] == base["chips"] + 24, "曲江流饮 adds 12 墨 for each 水 card")
	var xm: Dictionary = R.score_line([R.word("春风"), R.word("得意"), R.word("马蹄"), R.foot("花")], [], ["mengjiao"], rnd0)
	var xm0: Dictionary = R.score_line([R.word("春风"), R.word("得意"), R.word("马蹄"), R.foot("花")], [], [], rnd0)
	_expect(is_equal_approx(xm["mult"], xm0["mult"] * 2.0), "春风得意 doubles 韵 when 春 and 功名 meet")
	var banned: Dictionary = R.score_line(good, [], [], PC.ROUNDS[2])
	var banned_spring: Dictionary = R.score_line([R.word("春风"), R.word("流水"), R.foot("天")], [], [], PC.ROUNDS[2])
	_expect(banned_spring["chips"] == 7 + 4 and banned["chips"] > 0, "郑公子's rule removes the 墨 of 春 cards")
	g.scene.act("ch5")
	var q = g.scene
	_expect(g.screen == "ch5" and q.phase == "pick" and q.offers.size() == 3, "chapter 5 opens with a choice of three poet charms")
	q.choose(0)
	_expect(q.phase == "play" and q.hand_w.size() == PC.HAND_WORDS and q.hand_f.size() == PC.HAND_FEET and q.charms.size() == 1, "picking a charm deals a hand of words and feet")
	q.toggle("w", 0)
	q.toggle("f", 0)
	q.toggle("f", 1)
	_expect(q.sel.size() == 3 and q.sel.has(["f", 0]) and q.sel.has(["f", 1]), "multiple rhyme cards can be selected for a batch swap")
	_expect(not q.play_line(), "multiple rhyme cards cannot be played as a poem")
	var plays0: int = q.plays
	q.sel = []
	var d0: int = q.discards
	var words0: Array = q.hand_w.duplicate()
	var feet0: Array = q.hand_f.duplicate()
	var pile_w0: int = q.pile_w.size()
	var pile_f0: int = q.pile_f.size()
	for i in [4, 0, 2]:
		q.toggle("w", i)
	q.toggle("f", 2)
	q.toggle("f", 0)
	q.toggle("w", 1)
	_expect(q.sel.size() == 5, "batch selection allows five mixed cards and rejects the sixth")
	_expect(not q.play_line() and q.plays == plays0, "a swap selection cannot consume a poem attempt")
	_expect(q.discard() and q.discards == d0 - 1 and q.sel.is_empty(), "five selected cards use exactly one swap and clear selection")
	_expect(q.hand_w.size() == PC.HAND_WORDS and q.hand_f.size() == PC.HAND_FEET and q.pile_w.size() == pile_w0 - 3 and q.pile_f.size() == pile_f0 - 2, "batch swap draws the correct number from both decks")
	_expect(q.hand_w.slice(0, 3) == [words0[1], words0[3], words0[5]] and q.hand_f[0] == feet0[1], "batch swap preserves unselected cards in order")
	_expect(not q.discard() and q.discards == d0 - 1, "empty selection cannot consume a swap")
	q.toggle("w", 0)
	q.toggle("w", 0)
	_expect(q.sel.is_empty(), "clicking a selected card deselects it")
	q.toggle("f", 0)
	q.discards = 0
	var unchanged: Array = q.hand_f.duplicate()
	_expect(not q.discard() and q.hand_f == unchanged and q.sel.size() == 1, "no swap budget leaves the hand and selection unchanged")
	q.sel = []
	q.discards = d0 - 1
	var best: Array = q.best_line()
	var best_v: int = q._preview(best)["total"]
	var other_v: int = q._preview([["w", 0], ["w", 1], ["f", 0]])["total"]
	_expect(not best.is_empty() and best_v >= other_v, "荐句 finds the highest-scoring line in the hand")
	# Play the whole contest with 荐句 and the shop; it must be winnable.
	var guard := 0
	var shop_seen := false
	while q.phase != "done" and guard < 60:
		guard += 1
		match q.phase:
			"play":
				q.suggest()
				q.play_line()
			"lost":
				q.retry_round()
			"won_round":
				if q.round_i == 2:
					await _frames(2)
					g.overlay.close_panel()
					await _frames(2)
				else:
					q.continue_after_round()
			"shop":
				shop_seen = true
				for i in range(q.offers.size()):
					q.choose(i)
				q.leave_shop()
		await _frames(1)
	_expect(q.phase == "done" and g.cleared.has("ch5") and g.flags.get("bai_introduction", false), "three rounds of poetry earn Bai Juyi's introduction (%d turns)" % guard)
	_expect(shop_seen and q.plays >= 0, "the shop opens between rounds")
	_expect(g.shard_count() == 3, "chapter 5 preserves the existing four-fragment story arc")
	g._switch("map")
	g.scene.act("ch7")
	_expect(g.screen == "map", "the tower battle remains locked until the ascent is complete")
	await _tower_walk()
	g._switch("map")
	g.scene.act("ch7")
	_expect(g.screen == "ch7", "the tower battle unlocks after the seven-floor ascent")
	_expect(g.scene.read_stele, "the recorded moon sequence carries into the boss chapter")
	# ---- chapter 7
	g._switch("ch7")
	var c3 = g.scene
	c3.read_stele = false             # standalone entry must still require the stele
	c3.act("disk")
	_expect(c3.mode == "explore", "battle requires reading the stele first")
	c3.act("stele")
	g.overlay.close_panel()
	c3.act("disk")
	_expect(c3.mode == "battle" and c3.phase == 0 and c3.power == 0.0, "touching the disk starts the boss fight at power 0")
	# ---- power / point items
	c3.fire(false)
	var shots0: int = c3.ps.size()
	c3.ps.resize(0)
	c3.pv.resize(0)
	c3.ph.resize(0)
	c3._collect({"pos": c3.player, "kind": "P", "home": false})
	c3._collect({"pos": c3.player, "kind": "P", "home": false})
	c3.fire(false)
	_expect(c3.power_level() == 2 and c3.ps.size() > shots0, "big P items raise power and widen the shot")
	c3._collect({"pos": c3.player, "kind": "full", "home": false})
	_expect(c3.power == c3.MAX_POWER, "F item fills power to max")
	var s_low: int = c3.score
	c3._collect({"pos": Vector2(c3.player.x, c3.FIELD.end.y - 20), "kind": "pt", "home": false})
	var low_value: int = c3.score - s_low
	c3.player.y = c3.POC_Y - 20
	var s_high: int = c3.score
	c3._collect({"pos": Vector2(c3.player.x, c3.POC_Y - 20), "kind": "pt", "home": false})
	_expect(c3.score - s_high == 10000 and low_value < 10000, "point items are worth more when collected high")
	c3.player.y = c3.FIELD.end.y - 90
	var lives0: int = c3.lives
	c3.points = c3.next_extend - 1
	c3._collect({"pos": c3.player, "kind": "pt", "home": false})
	_expect(c3.lives == lives0 + 1, "every 25 point items extend a life")
	c3._drop(Vector2(c3.FIELD.get_center().x, 400), "p", false)
	c3.player.y = c3.POC_Y - 10
	c3._update_items(1.0 / 60.0)
	_expect(c3.items[0]["home"], "flying above the collection line pulls items in")
	c3.player.y = c3.FIELD.end.y - 90
	c3.items = []
	c3.invuln = 0
	var pw: float = c3.power
	c3._player_hit()
	_expect(c3.power < pw and c3.items.size() > 0, "getting hit drops power as P items")
	c3.lives = 3
	c3.invuln = 0
	c3.items = []
	# ---- bullet variety
	c3._clear_bullets(false)
	c3._add(Vector2(c3.FIELD.position.x + 30, 500), Vector2(-200, 0), 14.0, 2, c3.Shape.BIG, c3.Move.BOUNCE, 0.5)
	for i in range(10):
		c3._update_bullets(1.0 / 60.0)
	_expect(c3.bp.size() == 1 and c3.bv[0].x > 0, "bouncing orbs reflect off the side wall")
	var n_before: int = c3.bp.size()
	for i in range(40):
		c3._update_bullets(1.0 / 60.0)
	_expect(c3.bp.size() > n_before, "bouncing orbs burst into rice bullets")
	c3._clear_bullets(false)
	c3._add(Vector2(720, 400), Vector2(100, 0), 5.0, 0, c3.Shape.RICE, c3.Move.CURVE, 1.0)
	for i in range(30):
		c3._update_bullets(1.0 / 60.0)
	_expect(c3.bv[0].y > 20.0, "curving bullets turn over time")
	c3._clear_bullets(false)
	c3._laser(c3.player - Vector2(0, 300), PI * 0.5, 16.0, 0.5, 1.0)
	c3._update_lasers(0.2)
	_expect(c3.lives == 3, "a laser in its warning phase does no damage")
	c3._update_lasers(0.5)
	_expect(c3.lives == 2, "an active laser hits the player")
	c3.lasers = []
	c3.lives = 3
	c3.invuln = 0
	c3._enemy(Vector2(720, 300), Vector2.ZERO, "wisp", 1.0)
	c3._shot_hits(Vector2(720, 300))
	c3._update_enemies(1.0 / 60.0)
	_expect(c3.enemies.is_empty() and c3.items.size() >= 2, "destroyed enemies drop items")
	c3.items = []
	# ---- hidden code
	_expect(not g.zun_mode, "ZUN mode starts off")
	g.feed_cheat(KEY_Z)
	g.feed_cheat(KEY_A)
	g.feed_cheat(KEY_N)
	_expect(not g.zun_mode, "a wrong sequence does not trigger ZUN")
	for k in [KEY_Z, KEY_U, KEY_N]:
		g.feed_cheat(k)
	_expect(g.zun_mode, "typing Z U N enables ZUN mode")
	var l0: int = c3.lives
	c3._player_hit()
	c3.invuln = 0
	c3.bomb_t = 0
	c3.bombs = 0
	c3._bomb()
	_expect(c3.lives == l0 and c3.bomb_t > 0 and not c3.game_over, "ZUN mode: hits cost no life and bombs are unlimited")
	for k in [KEY_Z, KEY_U, KEY_N]:
		g.feed_cheat(k)
	_expect(not g.zun_mode, "typing it again turns ZUN mode off")
	c3.bomb_t = 0
	c3.bombs = 2
	c3.lives = 3
	c3._clear_bullets(false)
	# ---- stages 1–2: fairy waves only
	_expect(float(c3.PHASES[0]["time"]) + float(c3.PHASES[1]["time"]) >= 90.0 and g.tracks["stage7"].get_length() >= 90.0, "opening music and wave timing both reach at least ninety seconds before the boss track")
	_expect(c3.kind() == "wave1" and not c3.boss_active(), "stage 1 is a wave stage without the boss")
	c3.boss_hp = 0
	c3.step(1.0 / 60.0)
	_expect(c3.kind() == "wave1", "a wave stage does not end on boss HP")
	for i in range(240):
		c3.step(1.0 / 60.0)
		c3.invuln = 9.0
	_expect(c3.enemies.size() > 0, "wave 1 spawns enemies over time")
	_ch7_next(c3)
	_expect(c3.kind() == "wave2" and c3.stage() == 2 and c3.score > 100000, "stage 1 clears on the clock with a stage bonus")
	c3.bt = c3.PHASES[c3.phase]["time"] - 5.5
	c3.invuln = 9.0
	c3.step(1.0 / 60.0)
	_expect(c3.cameo and c3.boss_visible() and not c3.boss_active(), "镜魅 is glimpsed but cannot be hit at the end of stage 2")
	_ch7_next(c3)
	_expect(c3.kind() == "non1" and c3.stage() == 3 and c3.boss_active(), "stage 3 brings in 镜魅's first form")
	c3.boss_hp = 0
	c3.step(1.0 / 60.0)
	_expect(c3.kind() == "bells" and c3.shield, "bell spell card raises a shield")
	c3._damage(50.0)
	var hp1: float = c3.boss_hp
	c3._shot_hits(c3.boss_pos)
	_expect(c3.boss_hp == hp1, "shielded boss ignores shots")
	var wrong := -1
	for i in range(3):
		if c3.bells[i]["phase"] == 2:
			wrong = i
	c3._bell_hit(wrong)
	_expect(c3.bell_progress == 0 and c3.shield, "ringing 望 first resets the bell puzzle")
	c3._bell_hit((wrong + 1) % 3)
	_expect(c3.bell_progress == 0, "bells ignore hits for a moment after a wrong ring")
	c3.bt += 1.5
	for ph in [0, 1, 2]:
		for i in range(3):
			if c3.bells[i]["phase"] == ph:
				c3._bell_hit(i)
	_expect(not c3.shield, "朔→弦→望 order breaks the shield")
	c3.spell_clean = true
	c3.boss_hp = 0
	c3.step(1.0 / 60.0)
	_expect(c3.bonus_text.begins_with("破阵奖励") and c3.clear_t > 0 and c3.shatter_t > 0, "capturing a spell without dying gives the spell bonus and shatters the mirror")
	_expect(c3.items.size() > 0, "phase clear turns bullets into items")
	var hp_shatter: float = c3.boss_hp
	c3._damage(10.0)
	_expect(c3.boss_hp == hp_shatter, "镜魅 cannot be damaged while the mirror shatters")
	_ch7_next(c3)
	_expect(c3.kind() == "shatter" and c3.stage() == 4, "the second form opens with the shattered-mirror pattern")
	for i in range(120):
		c3.step(1.0 / 60.0)
		c3.invuln = 9.0
	_expect(c3.bp.size() > 20, "the shattered-mirror pattern fills the screen")
	c3.boss_hp = 0
	c3.step(1.0 / 60.0)
	_expect(c3.kind() == "mirror" and c3.images.size() == 3, "mirror spell card spawns three mirror images")
	var fake := -1
	var real := -1
	for i in range(3):
		if c3.images[i]["real"]:
			real = i
		else:
			fake = i
	var hp2: float = c3.boss_hp
	c3._image_hit(fake)
	_expect(c3.boss_hp == hp2 and c3.bp.size() > 0, "shooting a fake image reflects bullets instead of damage")
	c3._image_hit(real)
	_expect(c3.boss_hp < hp2, "the image showing 山 月 水 takes damage")
	c3.boss_hp = 0
	c3.step(1.0 / 60.0)
	_expect(c3.kind() == "final", "final survival spell card starts")
	c3.lives = 1
	c3.invuln = 0
	c3._add(c3.player, Vector2.ZERO, 8.0)
	c3.step(1.0 / 60.0)
	_expect(c3.game_over, "being hit with the last life ends the attempt")
	c3._retry(true)
	_expect(c3.easy and c3.kind() == "final" and c3.lives == 3, "retry keeps the current spell card and can switch to easy")
	c3.bt = 99.0
	c3.step(1.0 / 60.0)
	_expect(c3.ending_t > 0 and c3.mode == "ending", "the last card opens a dedicated victory scene before the farewell")
	var ending_lives: int = c3.lives
	c3.keys[KEY_Z] = true
	for i in range(120):
		c3.step(1.0 / 60.0)
	_expect(c3.mode == "ending" and c3.ps.is_empty() and c3.bp.is_empty() and c3.lives == ending_lives, "holding fire after victory cannot spawn shots or cause another hit")
	var ending_before: float = c3.ending_elapsed
	c3.tick(1.0, true)
	_expect(is_equal_approx(c3.ending_elapsed, ending_before), "opening a menu suspends the victory sequence")
	g.fast_dialogue = false
	for i in range(240):
		c3.step(1.0 / 60.0)
	_expect(c3.mode == "farewell" and g.dlg.active and not g.shards[3], "the farewell dialogue stays on the victory scene before awarding the fragment")
	g.dlg._fast_forward()
	_expect(g.overlay.panel == "card" and c3.mode == "farewell", "the final fragment is shown before the continuation button")
	g.overlay.close_panel()
	_expect(g.shards[3] and g.cleared.has("ch7") and c3.mode == "won" and g.screen == "ch7", "the result waits for the player after recording victory and the fourth shard")
	c3._win()
	_expect(not g.dlg.active and g.overlay.panel.is_empty(), "victory cannot replay the farewell or award a second fragment")
	g.fast_dialogue = true
	# ---- finale
	c3.act("continue_story")
	_expect(g.screen == "finale", "the victory continuation leads into restoration at the workshop")
	var f = g.scene
	_expect(not f.drop(0, f.target(0)), "a rotated shard does not snap in")
	f.pieces[0]["rot"] = 0.0
	_expect(not f.drop(0, f.target(1)), "a shard does not fit another gap")
	_expect(f.drop(0, f.target(0)), "correct angle and position snaps the shard")
	for i in range(1, 4):
		f.pieces[i]["rot"] = 0.0
		f.drop(i, f.target(i) + Vector2(10, -8))
	_expect(f.done, "four shards complete the bowl")
	await _frames(3)
	g.overlay.close_panel()
	await _frames(4)
	_expect(g.cleared.has("finale"), "finale dialogue marks the chapter cleared")
	_expect(g.screen == "epilogue", "finale leads to the epilogue")
	_finish("SELF_TEST")


func _finish(kind: String) -> void:
	if _failed == 0:
		print("%s_OK: %d checks passed" % [kind, _count])
	else:
		print("%s_FAILED: %d failed, %d passed" % [kind, _failed, _count])
	g.get_tree().quit(0 if _failed == 0 else 1)


# ================================================================== ui test (real clicks)
func _click(p: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.position = p
	press.global_position = p
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	g.get_viewport().push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	g.get_viewport().push_input(release, true)
	await g.get_tree().process_frame
	await RenderingServer.frame_post_draw


## Clicks a point given in the current scene's own coordinates.
func _tap(p: Vector2) -> void:
	await _click(g.scene.to_screen(p))


func _move(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	g.get_viewport().push_input(m, true)
	await g.get_tree().process_frame


func _press_key(code: int) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.pressed = true
	g.get_viewport().push_input(press, true)
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	g.get_viewport().push_input(release, true)
	await _frames(2)


## Clicks through any open dialogue (first click completes the typewriter, second advances).
func _drain() -> void:
	var guard := 0
	while g.dlg.active and guard < 80:
		guard += 1
		if g.scene.cinematic_active():
			await g.get_tree().create_timer(0.12).timeout
			continue
		if g.dlg.choosing():
			await _click(Vector2(720, 389))
		else:
			await _click(Vector2(720, 760))


func run_ui(only_prologue := false) -> void:
	g.reset_progress()
	g.fast_dialogue = false
	await g.get_tree().create_timer(0.3).timeout
	await _click(Vector2(1360, 39))
	_expect(g.overlay.panel == "help", "title help button opens overlay")
	await _click(Vector2(1064, 221))
	_expect(g.overlay.panel.is_empty(), "help close button works")
	await _click(Vector2(230, 585))
	await g.get_tree().create_timer(0.8).timeout
	_expect(g.screen == "prologue" and g.dlg.active, "start button opens the prologue dialogue")
	var guard := 0
	while g.dlg.active and guard < 40:
		guard += 1
		await _click(Vector2(720, 760))
	_expect(not g.dlg.active, "clicking advances and finishes dialogue")
	await _click(Vector2(394, 225))
	_expect(g.scene.phase == 1, "the scanner cannot bypass the missing-piece record")
	await _click(Vector2(1005, 574))
	_expect(g.scene.dossier_open, "clicking the damaged bowl opens the four-piece dossier")
	await _press_key(KEY_ENTER)
	await _drain()
	_expect(g.scene.phase == 2 and not g.scene.dossier_open, "confirming the record opens scanner calibration")
	await _drag(Vector2(1062, 367), Vector2(1246, 367))
	await _click(Vector2(1154, 457))
	_expect(g.scene.phase == 2 and not g.scene.calibrated, "an incorrect drag cannot enable the scan button")
	await _drag(Vector2(1246, 367), Vector2(1154, 367))
	await g.get_tree().create_timer(0.65).timeout
	_expect(g.scene.calibrated, "dragging the slider to zero and releasing calibrates the scanner")
	await _press_key(KEY_A)
	_expect(not g.scene.calibrated, "keyboard adjustment releases the scanner lock")
	await _press_key(KEY_D)
	await g.get_tree().create_timer(0.65).timeout
	await _click(Vector2(1154, 457))
	_expect(g.scene.phase == 3, "the calibrated scan button starts visible acquisition")
	await g.get_tree().create_timer(g.scene.SCAN_SECONDS + 0.1).timeout
	_expect(g.dlg.active and g.scene.phase == 4 and g.scene.flash == 0.0, "anomaly dialogue stays readable before the white flash")
	await _drain()
	if g.screen == "prologue" and g.scene.film_real:
		await _press_key(KEY_SPACE)
	await g.get_tree().create_timer(1.5).timeout
	_expect(g.screen == "ch1", "the full interactive prologue leads to chapter 1")
	if only_prologue:
		_finish("PROLOGUE_UI_TEST")
		return
	guard = 0
	while g.dlg.active and guard < 60:
		guard += 1
		if g.dlg.choosing():
			await _click(Vector2(720, 389))
		else:
			await _click(Vector2(720, 760))
	_expect(g.flags.has("told_truth"), "choice button records the answer")
	await _tap(Vector2(219, 549))
	_expect(g.dlg.active, "note hotspot opens text")
	await _drain()
	await _tap(g.scene.MIRROR_PICKUP)
	_expect(g.overlay.panel == "card", "mirror pickup shows artifact card")
	await _click(Vector2(956, 678))
	var c1 = g.scene
	await _drag(Vector2(70, 836), Vector2(340, 330))
	_expect(c1.cinematic == "return" and not c1.mirror_placed, "dropping the mirror away from the stand returns it")
	await g.get_tree().create_timer(0.5).timeout
	_expect(c1.mirror_found and not c1.mirror_placed and c1.selected == "mirror", "an invalid drop keeps the mirror in the inventory")
	await _drag(Vector2(70, 836), c1.to_screen(c1.MIRROR))
	_expect(c1.cinematic == "place" and not c1.mirror_placed, "dragging from the inventory starts the stand seating animation")
	await g.get_tree().create_timer(1.25).timeout
	_expect(c1.mirror_placed, "the dragged mirror seats on the stand")
	for i in range(4):
		await _click(Vector2(838, 774))
	_expect(g.scene.revealed, "rotation buttons reveal the wall")
	await g.get_tree().create_timer(2.9).timeout
	await _tap(Vector2(984, 475))
	_expect(g.scene.seal_open, "casket opens the glyph lock")
	for i in range(3):
		for j in range(3):
			await _click(Vector2(500 + i * 191, 460))
	await _click(Vector2(720, 669))
	_expect(c1.cinematic == "unlock" and not c1.cabinet_open, "clicking the solved lock starts the bolt and hinge animation")
	await _tap(Vector2(984, 475))
	_expect(not g.shards[0], "clicks cannot collect the shard during the chest cutscene")
	await g.get_tree().create_timer(4.3).timeout
	_expect(g.scene.cabinet_open, "lock opens with clicks")
	await g.get_tree().create_timer(0.3).timeout
	await _tap(Vector2(984, 475))
	await g.get_tree().create_timer(1.75).timeout
	await _click(Vector2(956, 678))
	await _drain()
	_expect(g.scene.dark, "lights go out after the first shard")
	var spot: Vector2 = g.scene.hidden_at["shard"]
	await _move(g.scene.to_screen(spot))
	await _frames(2)
	await _click(g.scene.to_screen(spot))
	_expect(g.shards[1], "clicking the lit shard picks it up")
	# A fresh workshop also supports dragging straight from the tabletop, without a card.
	g.fast_dialogue = true
	g._switch("ch1")
	await _frames(3)
	var direct = g.scene
	await _drag(direct.to_screen(direct.MIRROR_PICKUP), direct.to_screen(direct.MIRROR))
	_expect(direct.cinematic == "place" and g.collected.has("mirror"), "dragging directly from the tabletop records the mirror and starts seating")
	await g.get_tree().create_timer(1.25).timeout
	_expect(direct.mirror_placed and g.overlay.panel.is_empty(), "direct tabletop placement leaves no pickup card blocking the puzzle")
	for i in range(4):
		direct._turn(1)
	await g.get_tree().create_timer(0.6).timeout
	await _press_key(KEY_J)
	_expect(g.overlay.panel.is_empty() and direct.cinematic == "reveal", "the journal shortcut cannot interrupt the wall reveal")
	await _press_key(KEY_SPACE)
	_expect(direct.revealed and direct.cinematic.is_empty(), "skipping the wall reveal preserves the clue")
	direct.dials = [0, 1, 2]
	direct._check_seal()
	await g.get_tree().create_timer(0.6).timeout
	await _press_key(KEY_ENTER)
	_expect(direct.cabinet_open and direct.lid_t == 1.0 and not g.overlay.modal_active(), "skipping the chest sequence leaves the lid open and the puzzle usable")
	direct._take_casket_shard()
	await g.get_tree().create_timer(0.6).timeout
	await _press_key(KEY_SPACE)
	_expect(g.overlay.panel == "card" and direct.cinematic.is_empty(), "skipping the shard reveal opens its card once")
	g.overlay.close_panel()
	var wind_oil: float = direct.oil
	await g.get_tree().create_timer(0.6).timeout
	_expect(direct.oil == wind_oil, "the wind cutscene freezes oil consumption before the lamp search")
	await _press_key(KEY_SPACE)
	_expect(direct.dark and direct.cinematic.is_empty() and direct.oil > wind_oil - 1.0, "skipping the wind scene starts the lamp search without an oil penalty")
	# Chapter 2: evidence cards, locked flight, and verdict feedback via viewport input.
	g.fast_dialogue = true
	g._switch("ch2")
	var c2 = g.scene
	c2.evidence = ["shard", "ledger", "bundle", "gong"]
	c2._start_debate()
	c2.line_i = 1
	c2.line_t = 1.0
	await _frames(3)
	await _click(c2._evidence_rect(1).get_center())
	_expect(c2.bullet == 1, "clicking the illustrated ledger selects that evidence")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = Vector2(400, 750)
	g.get_viewport().push_input(wheel, true)
	await _frames(2)
	_expect(c2.bullet == 2, "mouse wheel selects the next evidence card")
	var pick := InputEventKey.new()
	pick.keycode = KEY_1
	pick.pressed = true
	c2.key(pick)
	_expect(c2.bullet == 0, "number shortcut selects the shard card")
	await _click(c2._evidence_rect(3).get_center())
	await _click(c2._weak_rect(Story.TESTIMONY[0]["lines"][1]).get_center())
	_expect(not c2.shot.is_empty() and c2.shot.get("evidence") == "gong", "a click on the weak phrase launches the selected evidence")
	c2.key(pick)
	_expect(c2.bullet == 3 and c2.shot.get("evidence") == "gong", "evidence selection stays fixed while it is in flight")
	await g.get_tree().create_timer(0.45).timeout
	_expect(c2.credit == 4 and c2.feedback_kind == "wrong" and c2.retort_t > 0, "wrong evidence shows a rebuttal and loses exactly one coin")
	var held_line: int = c2.line_i
	c2.act("next")
	_expect(c2.line_i == held_line, "the rebuttal keeps the disputed sentence on screen")
	await g.get_tree().create_timer(c2.RETORT_TIME + 0.05).timeout
	c2.line_i = 1
	c2.line_t = 1.0
	await _frames(2)
	await _click(c2._evidence_rect(0).get_center())
	await _click(c2._weak_rect(Story.TESTIMONY[0]["lines"][1]).get_center())
	c2._resolve_shot()
	_expect(c2.stamp > 0 and c2.feedback_kind == "success" and c2.feedback_evidence == "shard", "matching evidence triggers the recognition seal with the correct art")
	await _frames(5)
	_expect(c2.round_i == 1 and c2.credit == 4, "recognition advances the round without losing credit")
	for polite in [false, true]:
		g.flags["polite"] = polite
		c2._start_debate()
		_expect(c2.credit_max == (6 if polite else 5), "the coin display preserves the courtesy bonus: %s" % polite)
	# The neutral miss feedback must not take away a coin.
	c2._fire(Vector2(80, 430), false)
	c2._resolve_shot()
	_expect(c2.feedback_kind == "miss" and c2.credit == c2.credit_max, "missing the weak phrase gives guidance without a credit penalty")
	# Use the real cinematic clock to ensure dialogue waits until the full cut-in ends.
	c2._start_debate()
	c2.line_i = 1
	c2.line_t = 1.0
	c2.bullet = 0
	g.test_mode = false
	c2._fire(c2._weak_rect(Story.TESTIMONY[0]["lines"][1]).get_center(), true)
	c2._resolve_shot()
	await g.get_tree().create_timer(1.0).timeout
	_expect(c2.stamp > 0 and not g.dlg.active and c2.round_i == 0 and not c2.chrome(), "the full-screen action portrait plays before dialogue and hides global buttons")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	c2.key(escape)
	_expect(g.overlay.panel.is_empty(), "cinematic input blocks the help shortcut")
	var skip := InputEventKey.new()
	skip.keycode = KEY_SPACE
	skip.pressed = true
	c2.key(skip)
	await _frames(3)
	_expect(c2.round_i == 1 and c2.stamp == 0, "Space skips a settled cut-in and advances the testimony once")
	c2._start_debate()
	c2.line_i = 1
	c2.bullet = 0
	c2._fire(Vector2(670, 470), true)
	c2._resolve_shot()
	await g.get_tree().create_timer(c2.STAMP_TIME + 0.15).timeout
	_expect(c2.round_i == 1 and c2.stamp == 0, "an unskipped full-screen cut-in finishes and advances the testimony once")
	c2._start_debate()
	c2.line_i = 1
	c2.line_t = 1.0
	c2.credit = 1
	c2.bullet = 3
	c2._fire(Vector2(670, 470), true)
	c2._resolve_shot()
	_expect(c2.credit == 0 and c2.kick_pending and not g.dlg.active, "losing the final coin plays the merchant cut-in before the dismissal")
	await g.get_tree().create_timer(c2.RETORT_TIME + 0.15).timeout
	_expect(c2.credit == c2.credit_max and c2.line_i == 0 and not c2.paused, "merchant cut-in and dismissal restore credit and restart the round")
	g.test_mode = true
	# Chapter 3: automatic mode is reachable through both actual buttons and keyboard input.
	g.fast_dialogue = true
	g._switch("ch3")
	g.scene.phase = "ready"
	await _frames(3)
	_expect(g.scene.hit_screen(Vector2(720, 465)) == "toggle_auto", "the loaded preparation screen renders the automatic performance control")
	await _click(Vector2(720, 465))
	_expect(g.scene.autoplay, "the preparation screen button enables autoplay")
	await _click(Vector2(580, 566))
	_expect(g.scene.phase == "play" and g.scene.autoplay, "the start button launches an automatic performance")
	await _press_key(KEY_P)
	_expect(not g.scene.autoplay, "P switches from automatic performance to manual play")
	await _click(Vector2(1235, 858))
	_expect(g.scene.autoplay, "the in-song button re-enables autoplay without hitting a note")
	g.scene.test_clock = 99.0
	await g.get_tree().create_timer(0.85).timeout
	if not g.scene.result.has("pass"):
		_expect(false, "the automatic performance must reach a result before reading its grade")
		_finish("UI_TEST")
		return
	_expect(g.scene.result["pass"] and g.scene.result["auto"], "the automatic performance reaches the marked victory screen")
	await _click(Vector2(720, 520))
	g.overlay.close_panel()
	_expect(g.cleared.has("ch3") and g.flags.get("ashi_joined", false), "the result button completes chapter 3 after autoplay")
	# Chapter 5: real clicks on the poem cards.
	g.fast_dialogue = true
	g._switch("ch5")
	await _frames(3)
	await _drain()
	await _click(Vector2(720, 430))
	_expect(g.scene.phase == "play", "clicking a charm in the pick screen starts the first round")
	await _frames(2)
	await _click(Vector2(40 + 50, 800))
	await _click(Vector2(40 + 108 + 50, 800))
	await _click(Vector2(40 + 6 * 108 + 30 + 50, 800))
	_expect(g.scene.sel.size() == 3, "clicking two word cards and a foot builds a line")
	var before: int = g.scene.plays
	await _click(Vector2(1303, 762))
	_expect(g.scene.plays == before - 1, "the 吟诗 button plays the selected line")
	# Travel map: hover previews remain separate from chapter unlock gates.
	g.reset_progress()
	g.cleared = {"ch1": true}
	g._switch("map")
	await _frames(3)
	var travel = g.scene
	await _move(travel.label_rect(4).get_center())
	_expect(travel.focus_i == 4, "hovering a map label previews its destination")
	await _click(Vector2(1249, 703))
	_expect(g.screen == "map", "a preview of a locked chapter cannot bypass its gate")
	if g.screen != "map":
		_finish("UI_TEST")
		return
	await _move(travel.marker_rect(1).get_center())
	_expect(travel.focus_i == 1, "hovering a landmark previews the same destination as its label")
	await _press_key(KEY_LEFT)
	await _frames(3)
	_expect(travel.focus_i == 0, "keyboard map selection persists with a stationary pointer")
	await _press_key(KEY_RIGHT)
	await _click(Vector2(1249, 703))
	_expect(g.screen == "ch2", "the sidebar travel button opens the unlocked next chapter")
	g._switch("map")
	await _frames(3)
	await _click(g.scene.label_rect(0).get_center())
	_expect(g.screen == "ch1", "a completed chapter can be revisited through its map label")
	_finish("UI_TEST")


func _drag(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.position = from
	press.global_position = from
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	g.get_viewport().push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.global_position = to
	motion.relative = to - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	g.get_viewport().push_input(motion, true)
	await _frames(1)
	var release := press.duplicate() as InputEventMouseButton
	release.position = to
	release.global_position = to
	release.pressed = false
	g.get_viewport().push_input(release, true)
	await _frames(3)
	await RenderingServer.frame_post_draw


func run_tower_ui() -> void:
	g.reset_progress()
	g.fast_dialogue = true
	g._switch("ch6")
	await _frames(4)
	var tower = g.scene
	_expect(tower.phase == "walk", "the first landing becomes interactive after its dialogue")
	await _click(Vector2(1290, 45))
	_expect(tower.auto_mode, "clicking the tower HUD enables automatic walking")
	await _press_key(KEY_TAB)
	_expect(not tower.auto_mode, "Tab restores manual first-person controls")
	await _click(Vector2(720, 430))
	await _frames(3)
	_expect(tower.mouse_locked and tower.walker.enabled, "clicking the scene enables first-person movement")
	var yaw: float = tower.walker.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(780, 410)
	motion.relative = Vector2(60, -20)
	g.get_viewport().push_input(motion, true)
	await _frames(3)
	_expect(absf(tower.walker.rotation.y - yaw) > 0.05, "mouse motion actually turns the 3D camera")
	var walk_distance := await _tower_stride(tower, false)
	var run_distance := await _tower_stride(tower, true)
	_expect(walk_distance > 0.55 and run_distance > walk_distance * 1.35, "holding physical Shift increases actual movement distance (walk %.2fm, run %.2fm)" % [walk_distance, run_distance])
	_expect(not tower.walker.sprinting and not Input.is_physical_key_pressed(KEY_SHIFT), "releasing Shift restores the normal movement state")
	# Inspect the rendered geometry, since an open collision ramp alone cannot catch this bug.
	var open_mouths := true
	var checked_panels := 0
	for mesh in tower.world.find_children("*", "MeshInstance3D", true, false):
		if not mesh.name.begins_with("rail_panel") and not mesh.get_parent().name.begins_with("rail_panel"):
			continue
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		if absf(bounds.get_center().z + 3.82) > 0.15:
			continue
		checked_panels += 1
		for mouth_x in [-3.5, 3.5]:
			if bounds.position.x < mouth_x + 0.88 and bounds.end.x > mouth_x - 0.88:
				open_mouths = false
	_expect(open_mouths and checked_panels >= 24, "all six crosswalks leave both staircase openings clear of visible rails (%d panels checked)" % checked_panels)
	await _press_key(KEY_ESCAPE)
	_expect(not tower.mouse_locked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases the pointer")
	_expect(g.overlay.panel == "help", "Escape also opens the global navigation menu")
	await _press_key(KEY_ESCAPE)
	await _press_key(KEY_E)
	_expect(tower.note_time > 0.0, "E opens the current landing observation")
	tower._start_film("echo")
	await _frames(3)
	await _click(Vector2(1320, 36))
	_expect(tower.phase == "walk" and g.flags.get("tower_echo_seen", false), "the placeholder skip button resumes exploration")
	tower._land(6)
	await _frames(4)
	await _press_key(KEY_SPACE)
	await _frames(3)
	_expect(tower.phase == "summit", "Space exits the summit placeholder into the final interaction")
	await _click(Vector2(720, 827))
	_expect(g.screen == "ch7", "the summit button opens the boss chapter")
	# Exercise all physical ramps again after replacing the visible stair meshes.
	g.cleared = {"ch1": true, "ch2": true, "ch3": true, "ch4": true, "ch5": true}
	g.shards = [true, true, true, false]
	g.flags["bai_introduction"] = true
	await _tower_walk()
	_finish("TOWER_UI_TEST")


func _tower_stride(tower, sprint: bool) -> float:
	tower.walker.position = Vector3(1.5, 0.08, 3.15)
	tower.walker.velocity = Vector3.ZERO
	tower.walker.rotation.y = PI * 0.5
	var before: Vector3 = tower.walker.position
	for code in ([KEY_SHIFT, KEY_W] if sprint else [KEY_W]):
		var down := InputEventKey.new()
		down.keycode = code
		down.physical_keycode = code
		down.pressed = true
		Input.parse_input_event(down)
	for i in range(30):
		await g.get_tree().physics_frame
	var distance := Vector2(tower.walker.position.x - before.x, tower.walker.position.z - before.z).length()
	for code in [KEY_W, KEY_SHIFT]:
		var up := InputEventKey.new()
		up.keycode = code
		up.physical_keycode = code
		up.pressed = false
		Input.parse_input_event(up)
	await g.get_tree().physics_frame
	await g.get_tree().physics_frame
	return distance


func _tower_walk() -> void:
	g._switch("map")
	g.scene.act("ch6")
	var tower = g.scene
	_expect(g.screen == "ch6" and tower.walker is CharacterBody3D and tower.vp.own_world_3d, "the tower opens in a real first-person 3D world")
	tower.act("to_boss")
	_expect(g.screen == "ch6" and not g.cleared.has("ch6"), "the summit cannot be entered from the first landing")
	tower.toggle_auto()
	g.overlay.open_help()
	var held: Vector3 = tower.walker.position
	await _frames(8)
	_expect(Vector2(held.x, held.z).distance_to(Vector2(tower.walker.position.x, tower.walker.position.z)) < 0.02, "opening help pauses automatic movement")
	g.overlay.close_panel()
	var film_seen := {}
	var last_floor := -1
	var frames := 0
	while tower.phase != "summit" and frames < 6500:
		frames += 1
		if tower.floor_index != last_floor:
			last_floor = tower.floor_index
			print("TOWER: floor %d reached at %s" % [last_floor + 1, tower.walker.position])
		if tower.phase == "vision":
			film_seen[tower.film_id] = true
			var skip := InputEventKey.new()
			skip.keycode = KEY_SPACE
			tower.key(skip)
		if frames % 900 == 0:
			print("TOWER: frame %d floor=%d route=%d position=%s" % [frames, tower.floor_index + 1, tower.route_index, tower.walker.position])
		await g.get_tree().physics_frame
	_expect(tower.visited.size() == 7 and tower.phase == "summit", "automatic walking traverses every staircase and reaches all seven landings (%d frames)" % frames)
	_expect(film_seen.has("echo") and film_seen.has("reveal"), "both film placeholders run and can be skipped without blocking the chapter")
	_expect(g.cleared.has("ch6") and g.flags.get("tower_ascent_done", false) and g.flags.get("bell_order_known", false), "finishing the ascent saves the chapter and moon-sequence knowledge")
	_expect(g.shard_count() == 3, "the ascent preserves the final shard for the boss encounter")
	tower.act("to_boss")
	_expect(g.screen == "ch7" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the summit hands off to chapter seven and releases the mouse")


# ================================================================== laboratory epilogue (real movement and input)
func _lab_guide(lab, id: String) -> void:
	await _press_key(KEY_TAB)
	var frames := 0
	while lab.auto_mode and frames < 2400:
		frames += 1
		await g.get_tree().physics_frame
	await _frames(3)
	_expect(not lab.auto_mode and lab.focus_id == id, "laboratory guide reaches %s around furniture (%d frames)" % [id, frames])
	_expect(lab.walker.position.y > -0.1 and lab.walker.position.y < 0.2, "laboratory route stays on the floor at " + id)


func run_epilogue_ui() -> void:
	g.reset_progress()
	g.cleared["finale"] = true
	g.shards = [true, true, true, true]
	g.collected.append("coin")
	g.fast_dialogue = true
	g._switch("epilogue")
	await _frames(5)
	var lab = g.scene
	_expect(lab.phase == "vision" and lab.film_id == "return", "the return-to-lab film has a working placeholder")
	await _press_key(KEY_SPACE)
	_expect(lab.phase == "walk" and lab.walker is CharacterBody3D, "returning to the laboratory opens first-person exploration")
	_expect(lab.environment.scan_model != null and lab.environment.scan_view.own_world_3d, "the workstation renders an actual rotating 3D bowl")
	lab.inspect("window")
	_expect(lab.phase == "walk" and not g.cleared.has("epilogue"), "the closing window scene waits for all three observations")
	await _click(Vector2(720, 430))
	await _frames(3)
	_expect(lab.mouse_locked and lab.walker.enabled, "clicking the laboratory enables first-person movement")
	await _press_key(KEY_ESCAPE)
	_expect(g.overlay.panel == "help" and not lab.mouse_locked, "Escape opens the laboratory menu and releases the pointer")
	await _click(Vector2(950, 679))
	_expect(g.overlay.panel.is_empty() and g.screen == "epilogue", "continue resumes the laboratory")
	await _lab_guide(lab, "screen")
	await _press_key(KEY_E)
	_expect(lab.seen.has("screen") and lab.phase == "walk", "E completes the scan-data observation")
	await _lab_guide(lab, "bowl")
	await _press_key(KEY_E)
	_expect(lab.seen.has("bowl") and not lab.window_open(), "the restored bowl is recorded without prematurely unlocking the ending")
	await _lab_guide(lab, "mirror")
	await _press_key(KEY_E)
	_expect(lab.phase == "vision" and not lab.seen.has("mirror"), "the mirror plays its memory before being marked complete")
	await _press_key(KEY_SPACE)
	_expect(lab.phase == "walk" and lab.window_open() and not g.music_player.stream_paused, "skipping the memory resumes exploration and restores background music")
	await _press_key(KEY_E)
	_expect(lab.phase == "walk", "revisiting the mirror does not replay the film")
	g.return_from_menu("title")
	await _frames(3)
	g.scene.act("start")
	await _frames(4)
	lab = g.scene
	_expect(g.screen == "epilogue" and lab.seen.size() == 3 and lab.window_open(), "continue resumes unfinished laboratory observations")
	_expect(not g.cleared.has("epilogue"), "leaving the laboratory does not complete the ending")
	await _lab_guide(lab, "window")
	await _press_key(KEY_E)
	_expect(lab.done and g.cleared.has("epilogue"), "the window dialogue completes the epilogue")
	await g.get_tree().create_timer(3.2).timeout
	await _click(Vector2(590, 780))
	_expect(g.screen == "map" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the closing screen returns to the map with a usable pointer")
	# Mirror-first order and the branch without the optional coin.
	g.flags.erase("epilogue_seen")
	g.collected.erase("coin")
	g._switch("epilogue")
	lab = g.scene
	lab.inspect("mirror")
	_expect(lab.phase == "vision", "the mirror can be the first observation")
	g.fast_dialogue = false
	lab._finish_film()
	var coin_line := false
	for line in g.dlg.queue:
		coin_line = coin_line or str(line.get("t", "")).contains("开元通宝")
	_expect(not coin_line, "the optional coin is mentioned only when actually collected")
	g.dlg._fast_forward()
	g.fast_dialogue = true
	_expect(lab.phase == "walk" and lab.seen.has("mirror") and not lab.window_open(), "mirror-first order still requires both remaining observations")
	_finish("EPILOGUE_UI_TEST")


# ================================================================== restart and chapter-skip input
func _type_skip() -> void:
	for code in [KEY_S, KEY_K, KEY_I, KEY_P]:
		await _press_key(code)
	await _frames(3)


func run_navigation_ui() -> void:
	g.reset_progress()
	g.fast_dialogue = true
	g._switch("title")
	await _frames(3)
	await _click(Vector2(230, 806))
	await _frames(3)
	_expect(g.overlay.panel == "settings" and g.blocked(), "the title settings button opens a modal settings page")
	_expect(is_equal_approx(float(g.settings["voice"]), 0.5) and is_equal_approx(float(g.settings["music"]), 0.5) and is_equal_approx(float(g.settings["effects"]), 0.5), "all three volume sliders default to fifty percent")
	_expect(is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voice"))) and is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))) and is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Effects"))), "fifty percent retains the original mix on all audio buses")
	# Real slider clicks change their dedicated audio buses immediately.
	await _click(Vector2(870, 285))
	await _frames(2)
	var voice_level: float = g.settings["voice"]
	_expect(voice_level > 0.65 and voice_level < 0.85, "the voice slider can increase from its midpoint through viewport input")
	_expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voice"))), voice_level * 2.0) and is_equal_approx(float(g.settings["music"]), 0.5), "increasing voice adds gain without changing the music setting")
	g.set_setting("voice", 1.0)
	_expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voice"))), 2.0), "maximum volume amplifies the original level by two")
	g.set_setting("voice", voice_level)
	g.set_setting("music", 0.0)
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Voice")), "zero background music mutes music alone")
	g.set_setting("text_speed", 1.6)
	var test_settings := "user://changan_settings_verification.cfg"
	g._save_settings(test_settings)
	g.reset_settings()
	g._load_settings(test_settings)
	g._apply_settings()
	_expect(is_equal_approx(float(g.settings["voice"]), voice_level) and is_equal_approx(float(g.settings["music"]), 0.0) and is_equal_approx(float(g.settings["text_speed"]), 1.6), "settings survive saving and reloading independently of story progress")
	var legacy := ConfigFile.new()
	legacy.set_value("settings", "voice", 1.0)
	legacy.set_value("settings", "music", 0.6)
	legacy.set_value("settings", "effects", 0.0)
	legacy.save(test_settings)
	g._load_settings(test_settings)
	_expect(is_equal_approx(float(g.settings["voice"]), 0.5) and is_equal_approx(float(g.settings["music"]), 0.3) and is_zero_approx(float(g.settings["effects"])), "legacy volume preferences migrate without changing their audible level")
	g._load_settings(test_settings)
	_expect(is_equal_approx(float(g.settings["voice"]), 0.5) and is_equal_approx(float(g.settings["music"]), 0.3), "migrated preferences are not scaled again on the next load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_settings))
	g.reset_settings()
	_expect(is_equal_approx(float(g.settings["voice"]), 0.5) and is_equal_approx(float(g.settings["music"]), 0.5) and is_equal_approx(float(g.settings["effects"]), 0.5), "restoring defaults returns all volume controls to fifty percent")
	g.overlay.settings_ui.refresh()
	await _press_key(KEY_ESCAPE)
	await _frames(3)
	_expect(g.overlay.panel.is_empty(), "Escape closes settings and returns to the title")
	await _type_skip()
	_expect(g.screen == "title" and g.cleared.is_empty(), "SKIP does not complete a chapter on the title screen")
	_expect(not g.restart_current_chapter(), "chapter restart is unavailable on the title screen")
	g._switch("prologue")
	for code in [KEY_S, KEY_K, KEY_A, KEY_P]:
		await _press_key(code)
	_expect(g.screen == "prologue", "a mistyped SKIP leaves the current chapter running")
	for code in [KEY_S, KEY_K, KEY_I]:
		await _press_key(code)
	g.cheat_time -= 2.0
	await _press_key(KEY_P)
	_expect(g.screen == "prologue", "an expired SKIP sequence is discarded")
	g.fast_dialogue = false
	g.say("prologue_a")
	await _press_key(KEY_ESCAPE)
	var paused_text: float = g.dlg.shown
	await _frames(6)
	_expect(g.overlay.panel == "help" and is_equal_approx(g.dlg.shown, paused_text), "opening the pause menu suspends the dialogue typewriter")
	await _click(Vector2(980, 304))
	await _frames(3)
	_expect(g.overlay.panel == "settings" and g.dlg.active, "settings can open from the pause menu during dialogue")
	await _press_key(KEY_ESCAPE)
	_expect(g.overlay.panel == "help", "closing settings returns to the pause menu")
	await _click(Vector2(980, 679))
	_expect(g.overlay.panel.is_empty() and g.dlg.active, "continuing from the pause menu restores the current dialogue")
	g.dlg.on_done = func() -> void: g.flags["stale_callback"] = true
	await _type_skip()
	_expect(g.screen == "ch1" and g.cleared.has("prologue") and g.flags.get("lab_bowl_seen", false), "typing SKIP during dialogue completes the prologue and opens chapter one")
	_expect(not g.flags.has("stale_callback"), "skipping cancels the departing dialogue callback")
	g.fast_dialogue = true
	g.dlg._fast_forward()
	var prior_scene: int = g.scene.get_instance_id()
	g.scene.mirror_found = true
	g.get_shard(0)
	g.collected.append("shard")
	g.overlay.open_help()
	await _frames(5)
	_expect(g.overlay.hit(Vector2(805, 679)) == "menu_restart", "the pause menu exposes a clickable restart-current-chapter button")
	await _click(Vector2(805, 679))
	await _frames(3)
	_expect(g.screen == "ch1" and g.scene.get_instance_id() != prior_scene and not g.scene.mirror_found, "the pause-menu button rebuilds chapter one from its beginning")
	_expect(not g.shards[0] and not g.collected.has("shard") and g.cleared.has("prologue"), "restart restores chapter-entry rewards while retaining earlier chapter progress")
	await _type_skip()
	_expect(g.screen == "map" and g.cleared.has("ch1") and g.shard_count() == 2 and g.collected.has("mirror") and g.collected.has("shard_b"), "chapter-one SKIP grants both fragments and unlocks the market")
	await _type_skip()
	_expect(g.screen == "map" and not g.cleared.has("ch2"), "SKIP on the map cannot clear the next chapter")
	g._switch("ch2")
	await _type_skip()
	_expect(g.screen == "map" and g.cleared.has("ch2") and g.shards[2] and g.collected.has("shard_c"), "market SKIP records the third fragment")
	g._switch("ch3")
	g.scene.start_song(false)
	var song_ref = weakref(g.scene.player)
	await _type_skip()
	_expect(g.screen == "map" and g.cleared.has("ch3") and g.flags.get("ashi_joined", false) and g.collected.has("huxuan"), "SKIP works during rhythm play and records the companion")
	_expect(song_ref.get_ref() == null, "leaving the rhythm chapter frees its audio player")
	g._switch("ch4")
	await _type_skip()
	_expect(g.screen == "map" and g.cleared.has("ch4"), "SKIP completes the night chapter")
	g.cleared["ch5"] = true
	g._switch("ch5")
	_expect(g.scene.phase == "pick" and g.scene.round_i == 0 and g.scene.lines_played.is_empty() and g.cleared.has("ch5"), "revisiting a completed poetry chapter starts a fresh run while keeping the chapter unlock")
	g.overlay.open_help()
	await _frames(5)
	await _click(Vector2(805, 679))
	await _frames(3)
	_expect(g.scene.phase == "pick" and g.cleared.has("ch5"), "restart reopens the poetry challenge even when its unlock was previously earned")
	await _type_skip()
	_expect(g.screen == "map" and g.flags.get("bai_introduction", false), "poetry SKIP records Bai Juyi's introduction")
	g._switch("ch6")
	g.scene._start_film("echo")
	g.music_player.stream_paused = true
	await _type_skip()
	_expect(g.screen == "ch7" and g.cleared.has("ch6") and g.scene.read_stele and g.collected.has("stele"), "SKIP during a tower film carries the bell sequence into the boss chapter")
	_expect(not g.shards[3] and not g.music_player.stream_paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "tower SKIP releases the mouse and music while leaving the final fragment for the boss")
	# Exercise actual playback: wave two must continue the same song, then the boss changes it.
	g.test_mode = false
	g.scene.start_battle()
	await _frames(3)
	_expect(g.current_music == "stage7" and g.music_player.playing and g.music_player.stream == g.tracks["stage7"], "the battle starts with the replacement opening recording")
	g.music_player.seek(2.0)
	await _frames(3)
	g.scene._start_phase(1)
	await _frames(3)
	_expect(g.current_music == "stage7" and g.music_player.get_playback_position() >= 2.0, "the second wave continues the opening song without restarting it")
	g.scene._start_phase(2)
	_expect(g.current_music == "boss7" and g.music_player.stream == g.tracks["boss7"], "the boss theme starts only when the boss stages begin")
	g.test_mode = true
	g.scene._start_phase(3)
	g.scene.lives = 1
	await _press_key(KEY_ESCAPE)
	await _frames(4)
	_expect(g.scene.paused and g.scene.hit_screen(Vector2(720, 490)) == "restart", "the battle pause panel also has a restart-current-chapter button")
	await _click(Vector2(720, 601))
	await _frames(3)
	_expect(g.overlay.panel == "settings" and g.scene.paused, "battle settings open without resuming combat")
	await _press_key(KEY_ESCAPE)
	_expect(g.overlay.panel.is_empty() and g.scene.paused, "closing battle settings restores the paused battle")
	await _click(Vector2(720, 490))
	await _frames(3)
	_expect(g.screen == "ch7" and g.scene.mode == "explore" and g.scene.read_stele, "battle restart returns to chapter entry and retains the tower clue")
	g.scene.start_battle()
	await _type_skip()
	_expect(g.screen == "map" and g.cleared.has("ch7") and g.shard_count() == 4 and g.collected.has("shard_d"), "battle SKIP grants the final fragment and unlocks restoration")
	g._switch("finale")
	g.test_mode = false
	for piece in g.scene.pieces:
		piece["placed"] = true
	g.scene._check_done()
	g.test_mode = true
	g.restart_current_chapter()
	await g.get_tree().create_timer(1.7).timeout
	_expect(g.screen == "finale" and not g.scene.done and not g.dlg.active and g.shard_count() == 4, "restart cancels the old restoration timer and retains the four collected fragments")
	await _type_skip()
	_expect(g.screen == "epilogue" and g.cleared.has("finale") and g.collected.has("bowl"), "restoration SKIP records the repaired bowl and opens the laboratory")
	g.scene._finish_film()
	g.scene.seen["screen"] = true
	g.flags["epilogue_seen"] = {"screen": true}
	g.overlay.open_help()
	await _frames(5)
	await _click(Vector2(805, 679))
	await _frames(3)
	_expect(g.screen == "epilogue" and g.scene.phase == "vision" and g.scene.film_id == "return" and g.scene.seen.is_empty(), "laboratory restart replays the arrival and resets only this chapter's observations")
	await _type_skip()
	_expect(g.screen == "title" and g.cleared.has("epilogue") and g.flags["epilogue_seen"].size() == 3, "laboratory SKIP records all observations and finishes the story")
	_expect(not g.dlg.active and g.overlay.panel.is_empty() and not g.music_player.stream_paused, "the completed skip chain leaves no dialogue, modal or paused music behind")
	# Also use the player's actual fade path, rather than only the immediate test transition.
	g.test_mode = false
	g._switch("ch1")
	prior_scene = g.scene.get_instance_id()
	g.scene.mirror_found = true
	g.overlay.open_help()
	await _frames(5)
	await _click(Vector2(805, 679))
	await g.get_tree().create_timer(0.8).timeout
	_expect(g.screen == "ch1" and g.pending.is_empty() and g.scene.get_instance_id() != prior_scene and not g.scene.mirror_found, "restart also works through the normal player fade transition")
	g.fast_dialogue = false
	g.say("wen_meet")
	await _type_skip()
	await g.get_tree().create_timer(0.8).timeout
	_expect(g.screen == "map" and g.pending.is_empty() and not g.dlg.active and g.shard_count() == 4, "SKIP through the normal player fade leaves a usable map and intact earlier progress")
	g.test_mode = true
	_finish("NAVIGATION_UI_TEST")


# ================================================================== captures
func capture(path: String, stage: String) -> void:
	g.reset_progress()
	g.fast_dialogue = true
	var capture_delay := 1.5
	match stage:
		"title":
			pass
		"settings", "settings_pause":
			if stage == "settings_pause":
				g._switch("ch4")
				g.overlay.open_help()
			g.overlay.open_settings()
		"menu_restart":
			g._switch("ch1")
			g.overlay.open_help()
		"map":
			g.cleared = {"ch1": true}
			g.shards = [true, true, false, false]
			g._switch("map")
			await _move(Vector2(1090, 820))
		"font_card":
			g._switch("map")
			g.show_card("mirror")
		"font_journal":
			g._switch("ch1")
			g.collected = ["mirror", "shard", "jiegu", "huxuan", "grape_wine", "night_canal"]
			g.overlay.open_journal()
		"prologue":
			g.fast_dialogue = false
			g._switch("prologue")
		"prologue_room", "prologue_dossier", "prologue_calibrate", "prologue_scan", "prologue_anomaly":
			g._switch("prologue")
			if stage != "prologue_room":
				g.scene.act("archive")
			if stage not in ["prologue_room", "prologue_dossier"]:
				g.scene.act("archive_confirm")
			if stage == "prologue_scan":
				g.scene._adjust(0.0)
				g.scene.tick(0.6, false)
				g.scene.act("scan")
			if stage == "prologue_anomaly":
				g.scene._adjust(0.0)
				g.scene.tick(0.6, false)
				g.scene.act("scan")
				g.fast_dialogue = false
				g.scene.tick(g.scene.SCAN_SECONDS, false)
				g.dlg.shown = 9999.0
		"ch1", "ch1_dialogue":
			g.fast_dialogue = stage == "ch1"
			g._switch("ch1")
		"ch1_dark":
			g._switch("ch1")
			g.scene.dark = true
			g.scene.dark_t = 1.0
			g.scene.lamp_pos = g.scene.hidden_at["shard"] + Vector2(150, -40)
			g.shards[0] = true
		"ch1_drag", "ch1_place", "ch1_reveal", "ch1_beam", "ch1_open", "ch1_lock", "ch1_unlock", "ch1_unlock_latch", "ch1_wind", "ch1_shard", "ch1_unlock_record", "ch1_wind_record", "ch1_place_record":
			g._switch("ch1")
			var c1 = g.scene
			c1.note_read = true
			c1.mirror_found = true
			c1.selected = "mirror"
			g.overlay.toast_time = 0.0
			capture_delay = 0.2
			if stage == "ch1_drag":
				c1._begin_drag(Vector2(70, 836), true)
				c1.drag_pos = Vector2(510, 470)
			elif stage in ["ch1_place", "ch1_place_record"]:
				c1._begin_place(c1.MIRROR_PICKUP)
				if not stage.ends_with("_record"):
					c1.capture_cinematic_time = 0.43
			else:
				c1.mirror_placed = true
				c1.angle_step = 4
				c1.angle_vis = 4
				c1.revealed = true
				c1.dials = [0, 1, 2]
				if stage == "ch1_beam":
					pass
				elif stage == "ch1_open":
					c1.cabinet_open = true
					c1.lid_t = 1
				elif stage == "ch1_lock":
					c1.seal_open = true
				elif stage == "ch1_reveal":
					c1._start_cinematic("reveal")
					c1.capture_cinematic_time = 1.6
				elif stage.begins_with("ch1_unlock"):
					c1._check_seal()
					if not stage.ends_with("_record"):
						c1.capture_cinematic_time = 1.15 if stage.ends_with("latch") else 3.25
				elif stage.begins_with("ch1_wind"):
					c1.cabinet_open = true
					c1.lid_t = 1
					c1.shard_taken = true
					c1.lamp_pos = Vector2(575, 560)
					c1.story_event("lights_out")
					if not stage.ends_with("_record"):
						c1.capture_cinematic_time = 1.55
				else:
					c1.cabinet_open = true
					c1.lid_t = 1
					c1._take_casket_shard()
					c1.capture_cinematic_time = 0.85
		"ch2":
			g._switch("ch2")
		"ch2_debate", "ch2_round2", "ch2_low_credit", "ch2_error", "ch2_stamp", "ch2_flight", "ch2_cutin_intro", "ch2_cutin_outro", "ch2_cutin_record", "ch2_retort_record":
			g._switch("ch2")
			g.scene.evidence = ["shard", "ledger", "bundle", "gong"]
			g.flags["polite"] = stage == "ch2_round2"
			g.scene._start_debate()
			g.scene.line_i = 1
			g.scene.line_t = 1.2
			g.scene.bullet = 0
			if stage == "ch2_round2":
				g.scene.round_i = 1
				g.scene.line_i = 2
				g.scene.bullet = 2
				g.scene.credit = 4
			if stage == "ch2_low_credit":
				g.scene.round_i = 2
				g.scene.line_i = 2
				g.scene.bullet = 1
				g.scene.credit = 2
			if stage in ["ch2_stamp", "ch2_error", "ch2_flight", "ch2_cutin_intro", "ch2_cutin_outro", "ch2_cutin_record", "ch2_retort_record"]:
				capture_delay = 0.35
				if stage in ["ch2_error", "ch2_retort_record"]:
					g.scene.bullet = 3
				g.scene._fire(g.scene._weak_rect(Story.TESTIMONY[0]["lines"][1]).get_center(), true)
				if stage == "ch2_flight":
					g.scene.shot["t"] = 0.48
					g.scene.paused = true
				else:
					g.scene._resolve_shot()
					if not stage.ends_with("_record"):
						g.scene.capture_verdict_time = 1.1
						if stage == "ch2_cutin_intro":
							g.scene.capture_verdict_time = 0.14
						elif stage == "ch2_cutin_outro":
							g.scene.capture_verdict_time = 2.98
		"ch3":
			g._switch("ch3")
		"ch3_barkeep":
			g._switch("ch3")
			g.fast_dialogue = false
			g.say("hux_barkeep")
			g.dlg.index = 2
			g.dlg._enter()
			g.dlg.shown = 9999.0
		"ch3_play", "ch3_sanxu", "ch3_zhongxu", "ch3_rupo", "ch3_auto_result", "ch3_ready", "ch3_dance_record":
			g._switch("ch3")
			g.scene.set_autoplay(true)
			if stage == "ch3_ready":
				g.scene.phase = "ready"
			else:
				g.scene.start_song(false)
				var at := 55.25
				if stage == "ch3_sanxu":
					at = 10.6
				elif stage == "ch3_zhongxu":
					at = 32.15
				elif stage == "ch3_auto_result":
					at = 99.0
				g.scene.test_clock = at
				g.scene.tick(0.016, false)
				g.scene.section_mix = float(g.scene.section_at(at))
				g.scene.section_banner = 0.0
		"ch3_live":
			# Real-time run (audio on, real clock): proves the song starts and notes arrive.
			g.test_mode = false
			g._switch("ch3")
			g.dlg.active = false
			g.scene.start_song(false)
			for i in range(5):
				await g.get_tree().create_timer(1.0).timeout
				var sc = g.scene
				print("LIVE t=%.2f playing=%s pos=%.2f misses=%d" % [sc.song_t, sc.player.playing if sc.player else false, sc.player.get_playback_position() if sc.player else -1.0, sc.counts["miss"]])
		"ch4_intro":
			g.fast_dialogue = false
			g._switch("ch4")
			for i in range(5):
				g.dlg.shown = 9999.0
				g.dlg.advance()
			g.dlg.shown = 9999.0
		"ch4_art_close", "ch4_art_walk", "ch4_art_throw", "ch4_art_record", "ch4_art_crouch":
			g._switch("ch4")
			g.overlay.close_panel()
			g.overlay.toast_time = 0.0
			var night = g.scene
			night.state["p"] = Vector2i(5, 6) if stage == "ch4_art_crouch" else Vector2i(10, 2)
			night._sync_3d(true)
			night.art_camera = true
			if stage == "ch4_art_throw":
				night.do({"stone": Vector2i(12, 3)})
				capture_delay = 0.40
			elif stage == "ch4_art_walk":
				night.do(Vector2i.LEFT)
				capture_delay = 0.12
		"ch4_temple", "ch4_temple_approach", "ch4_monk_dialogue", "ch4_monk_close":
			g._switch("ch4")
			g.overlay.close_panel()
			var night = g.scene
			var route: Array = night.solve()
			for i in range(route.size() - (1 if stage == "ch4_temple_approach" else 0)):
				night.do(route[i])
				g.overlay.close_panel()
			night._sync_3d(true)
			g.overlay.toast_time = 0.0
			if stage == "ch4_monk_dialogue":
				g.fast_dialogue = false
				g.say("ch4_done")
				for i in range(4):
					g.dlg.shown = 9999.0
					g.dlg.advance()
				g.dlg.shown = 9999.0
			if stage == "ch4_monk_close":
				var close_cam := Camera3D.new()
				close_cam.fov = 38.0
				night.world.add_child(close_cam)
				close_cam.position = Vector3(23.0, 2.7, 15.0)
				close_cam.look_at(Vector3(26.6, 1.2, 12.2), Vector3.UP)
				close_cam.make_current()
			capture_delay = 1.2
		"ch4", "ch4_mid", "ch4_over", "ch4_guide":
			g._switch("ch4")
			if stage == "ch4_guide":
				g.scene.toggle_guide()
				for i in range(18):
					g.scene.do(g.scene.guide_route[0])
					g.overlay.close_panel()
				g.overlay.toast_time = 0.0
			elif stage != "ch4":
				var route: Array = g.scene.solve()
				for i in range(28 if stage == "ch4_mid" else 0):
					g.scene.do(route[i])
					g.overlay.close_panel()
				g.scene.force_overview = stage == "ch4_over"
		"ch5", "ch5_play", "ch5_score", "ch5_shop":
			g._switch("ch5")
			g.overlay.close_panel()
			if stage != "ch5":
				g.scene.choose(0)
				g.scene.sel = g.scene.best_line()
				g.scene._sync_tiles()
				if stage == "ch5_score":
					g.test_mode = false
					g.scene.play_line()
					g.scene.score_t = -0.65         # the capture waits 1.5 s, landing mid-reveal
					g.test_mode = true
				if stage == "ch5_shop":
					g.scene.money = 12
					g.scene._open_shop()
			g.overlay.toast_time = 0.0
		"ch6", "ch6_hall", "ch6_stairs", "ch6_turn", "ch6_moons", "ch6_echo", "ch6_spirit", "ch6_summit":
			g._switch("ch6")
			g.overlay.toast_time = 0.0
			var tower = g.scene
			if stage == "ch6_hall":
				tower.walker.position = Vector3(-1.2, 0.05, 2.1)
				tower.walker.face(Vector3(0.5, 1.95, 4.7))
			elif stage == "ch6_stairs":
				tower.walker.position = Vector3(3.5, 0.12, 1.8)
				tower.walker.face(Vector3(3.5, 3.2, -3.0))
			elif stage == "ch6_turn":
				tower.walker.position = Vector3(3.5, 1.90, -3.6)
				tower.walker.face(Vector3(-3.5, 2.30, -3.7))
			elif stage == "ch6_moons":
				tower.walker.position = Vector3(0, 5 * tower.FLOOR_HEIGHT + 0.05, 3.0)
				tower._land(5)
				tower.walker.face(tower.environment.landmarks[5])
			elif stage == "ch6_echo":
				tower.walker.position = Vector3(0, 3 * tower.FLOOR_HEIGHT + 0.05, 3.0)
				tower._land(3)
				tower.film_time = 1.8
			elif stage == "ch6_spirit":
				tower.walker.position = Vector3(0.8, 4 * tower.FLOOR_HEIGHT + 0.05, 2.1)
				tower._land(4)
				tower.walker.face(tower.environment.landmarks[4])
			elif stage == "ch6_summit":
				tower.walker.position = Vector3(0, 6 * tower.FLOOR_HEIGHT + 0.05, 2.8)
				tower._land(6)
				tower._finish_film()
				tower.walker.face(tower.environment.landmarks[6])
			g.dlg.active = false
		"ch7_art_rooftops", "ch7_art_gallery", "ch7_art_guardian", "ch7_art_bells", "ch7_art_final":
			g._switch("ch7")
			g.zun_mode = true
			g.scene.start_battle()
			var art_phase: int = {"ch7_art_rooftops": 0, "ch7_art_gallery": 1, "ch7_art_guardian": 0, "ch7_art_bells": 3, "ch7_art_final": 6}[stage]
			g.scene._start_phase(art_phase)
			g.scene.title_t = 0.0
			g.scene.banner = 0.0
			g.scene.cutin_t = 0.0
			g.scene.backdrop_blend = 1.0
			g.scene.power = 2.6
			g.scene.bt = 8.0
			if stage in ["ch7_art_rooftops", "ch7_art_gallery", "ch7_art_guardian"]:
				g.scene.bt = 15.0
				if stage == "ch7_art_guardian":
					g.scene._enemy(Vector2(720, 210), Vector2.ZERO, "spirit", 70.0)
					g.scene.spawn["spirit"] = 15.0
				for i in range(2):
					g.scene._enemy(Vector2(560 + i * 290, 300 + i * 50), Vector2(0, 70), "lantern" if art_phase == 1 else "wisp", 26.0)
				for i in range(3):
					g.scene._enemy(Vector2(540 + i * 160, 110), Vector2(60, 20), "crane", 4.0)
					g.scene._enemy(Vector2(570 + i * 160, 140), Vector2(0, 80), "diver", 5.0)
			g.scene.keys[KEY_Z] = true
			g.scene.invuln = 30.0
			capture_delay = 2.0
		"ch7_ending", "ch7_farewell", "ch7_won":
			g.shards = [true, true, true, false]
			g._switch("ch7")
			g.scene.start_battle()
			g.scene._start_phase(6)
			g.scene.bt = 18.0
			g.scene.boss_pos = Vector2(720, 200)
			g.scene._phase_clear(true)
			if stage == "ch7_ending":
				g.scene._advance_ending(2.5)
				capture_delay = 0.1
			else:
				g.fast_dialogue = stage != "ch7_farewell"
				g.scene._advance_ending(g.scene.ENDING_DURATION)
				if stage == "ch7_won":
					g.overlay.close_panel()
		"ch7", "ch7_b1", "ch7_b2", "ch7_b3", "ch7_b4", "ch7_b5", "ch7_b6", "ch7_b7":
			g._switch("ch7")
			if stage != "ch7":
				g.zun_mode = true
				g.scene.read_stele = true
				g.scene.start_battle()
				g.scene.power = 2.6
				g.scene._start_phase(int(stage.right(1)) - 1)
				g.scene.banner = 0.0
				g.scene.keys[KEY_Z] = true
				for i in range(170):
					g.scene.step(1.0 / 60.0)
					g.scene.invuln = 9.0
				g.scene._drop(Vector2(640, 520), "P", false)
				g.scene._drop(Vector2(700, 540), "pt", false)
				g.scene._drop(Vector2(760, 520), "bomb", false)
		"finale":
			g.shards = [true, true, true, true]
			g._switch("finale")
			g.scene.pieces[2]["rot"] = 0.0
			g.scene.drop(2, g.scene.target(2))
		"epilogue_window", "epilogue_window_close", "epilogue_window_left", "epilogue_window_right", "epilogue_window_end":
			g.flags["epilogue_arrived"] = true
			g.flags["epilogue_seen"] = {"screen": true, "bowl": true, "mirror": true}
			g._switch("epilogue")
			var lab = g.scene
			lab.walker.position = Vector3(0, 0.05, -2.1)
			if stage == "epilogue_window_close":
				lab.walker.position.z = -2.58
			elif stage == "epilogue_window_left":
				lab.walker.position = Vector3(-1.1, 0.05, -2.4)
			elif stage == "epilogue_window_right":
				lab.walker.position = Vector3(1.1, 0.05, -2.4)
			lab.walker.face(lab.environment.spots["window"]["pos"])
			if stage == "epilogue_window_end":
				lab.inspect("window")
				lab.ending_time = 4.0
				capture_delay = 0.5
		"epilogue":
			g._switch("epilogue")
	if stage in ["ch2_cutin_record", "ch2_retort_record", "ch1_unlock_record", "ch1_wind_record", "ch1_place_record", "ch3_dance_record", "ch4_art_record"]:
		var folder := path.get_basename() + "-frames"
		DirAccess.make_dir_recursive_absolute(folder)
		var frame_times: Array[int] = []
		var recorded_frames: Array[Image] = []
		var frame_count := 108 if stage == "ch3_dance_record" else (120 if stage == "ch1_unlock_record" else (36 if stage == "ch1_place_record" else 90))
		for i in range(frame_count):
			if stage == "ch4_art_record":
				if i in [0, 18, 36]:
					g.scene.do(Vector2i.LEFT)
				elif i == 56:
					g.scene.do({"stone": Vector2i(9, 2)})
				g.overlay.close_panel()
				g.overlay.toast_time = 0.0
			if stage == "ch3_dance_record":
				var section := i / 36
				if i % 36 == 0:
					g.scene.start_song(false)
				g.scene.test_clock = [8.0, 28.0, 55.0][section] + (i % 36) / 15.0
				g.scene.section_mix = float(section)
				g.scene.tick(1.0 / 15.0, false)
				g.scene.section_banner = 0.0
				g.scene.queue_redraw()
			await RenderingServer.frame_post_draw
			frame_times.append(Time.get_ticks_msec())
			recorded_frames.append(g.get_viewport().get_texture().get_image())
			if stage.begins_with("ch1_") and g.scene.cinematic.is_empty():
				break
			await g.get_tree().create_timer(1.0 / 30.0).timeout
		# Compress after recording; PNG encoding must not slow the animation clock.
		for i in range(recorded_frames.size()):
			recorded_frames[i].resize(960, 600, Image.INTERPOLATE_LANCZOS)
			var frame_result: int = recorded_frames[i].save_png(folder.path_join("%03d.png" % i))
			if frame_result != OK:
				print("CAPTURE_FRAME_ERROR: ", frame_result)
				g.get_tree().quit(1)
				return
		var timing := FileAccess.open(folder.path_join("timing.json"), FileAccess.WRITE)
		timing.store_string(JSON.stringify({"frame_times_ms": frame_times}))
	else:
		await g.get_tree().create_timer(capture_delay).timeout
	await RenderingServer.frame_post_draw
	var result: int = g.get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE_RESULT: ", result)
	g.get_tree().quit(0 if result == OK else 1)
