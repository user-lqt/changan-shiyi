extends RefCounted
## Regression coverage for undo, score inspection and on-disk resume.
var t
var g


func _init(tester) -> void:
	t = tester
	g = t.g


func check(ok: bool, label: String) -> void:
	t._expect(ok, label)


func run_and_finish() -> void:
	await run()
	t._finish("PLAYTEST")


func restore(point: Dictionary) -> void:
	g.pending_resume = point.duplicate(true)
	g._switch(str(point["chapter"]))
	g.overlay.reset()


func run() -> void:
	g.reset_progress()
	g._switch("ch1")
	check(g.scene.dials == [5, 5, 5], "the lock begins with three clouds")
	g.scene.note_read = true
	g.scene.mirror_found = true
	g.scene.dials = [1, 3, 2]
	g.remember_current()
	var workshop: Dictionary = g.resume_point.duplicate(true)
	restore(workshop)
	check(g.scene.note_read and g.scene.mirror_found and g.scene.dials == [1, 3, 2] and not g.dlg.active, "workshop resume restores the lock and observations without replaying arrival")
	g._switch("ch4")
	g.overlay.reset()
	var c = g.scene
	var initial: Dictionary = c.state.duplicate(true)
	c.do(Vector2i(1, 0))
	check(c.undo_stack.size() == 1 and c.undo_step() and c.state == initial, "undo restores position, turn and all patrol counters")
	c.do(Vector2i(0, -1))
	check(c.undo_stack.is_empty(), "bumping a wall adds no undo entry")
	c.do({"stone": Vector2i(3, 6)})
	check(c.state["stones"] == c.STONES - 1 and c.undo_step() and c.state == initial and c.stone_time < 0, "undoing a throw returns the stone and clears the flight animation")
	c.state["p"] = Vector2i(5, 6)
	c._sync_3d(true)
	var markers := 0
	for node in c.scout_nodes:
		if node.visible:
			markers += 1
	check(c.shelter_ring.visible and markers > 0 and c.state["t"] == 0, "hiding previews nearby guards without consuming a turn")
	c.state = initial.duplicate(true)
	c._sync_3d(true)
	c.do(Vector2i(1, 0))
	c.do(Vector2i(1, 0))
	var before: Dictionary = c.state.duplicate(true)
	g.remember_current()
	var night: Dictionary = g.resume_point.duplicate(true)
	restore(night)
	c = g.scene
	check(c.state == before and c.undo_stack.size() == 2 and c.undo_step() and c.state["t"] == 1, "night resume preserves turn state and undo history")
	c.phase = "caught"
	check(c.undo_step() and c.phase == "play" and c.state["t"] == 0, "a failed move can be undone after its dialogue closes")
	c.state["p"] = Vector2i(13, 2)
	c._check_tile()
	check(c.checkpoint.get("mid", false) and c.undo_stack.is_empty(), "crossing the checkpoint starts a new undo history")
	g._switch("ch5")
	g.overlay.reset()
	c = g.scene
	c.choose(0)
	c.suggest()
	c.play_line()
	c.phase = "scoring"
	c.score_t = 0.0
	c.tick(60.0, false)
	check(c.phase == "scoring" and c.score_t == c.scoring_duration(), "the complete score breakdown stays visible indefinitely")
	c.score_t = 0.0
	c.confirm_scoring()
	check(c.phase == "scoring" and c.score_t == c.scoring_duration(), "first confirmation only reveals the complete breakdown")
	c.confirm_scoring()
	check(c.phase != "scoring", "a second confirmation leaves the score breakdown")
	c.start_round(1)
	c.toggle("w", 0)
	g.remember_current()
	var poetry: Dictionary = g.resume_point.duplicate(true)
	var hand: Array = c.hand_w.duplicate()
	var remaining: Array = c.pile_w.duplicate()
	var rng_state: int = c.rng.state
	var selected: Array = c.sel.duplicate(true)
	var test_path := "user://oct21_save_verification.json"
	check(g.write_save(test_path), "a complete save is written atomically to disk")
	var disk: Dictionary = g.unpack_resume(g.read_save(test_path))
	restore(disk)
	c = g.scene
	check(c.round_i == 1 and c.hand_w == hand and c.pile_w == remaining and c.sel == selected and c.rng.state == rng_state, "on-disk resume preserves the exact hand, draw pile, selection and RNG state")
	c.discard()
	var draw_a: Array = c.hand_w.duplicate()
	restore(poetry)
	g.scene.discard()
	check(g.scene.hand_w == draw_a, "the next draw after loading is identical")
	# A second write produces a backup; a truncated primary recovers from it.
	check(g.write_save(test_path), "overwriting a save retains a backup")
	var bad := FileAccess.open(test_path, FileAccess.WRITE)
	bad.store_string("{}")
	bad.close()
	check(not g.unpack_resume(g.read_save(test_path)).is_empty(), "a damaged primary save recovers from its backup")
	for suffix in ["", ".bak", ".tmp"]:
		var path := ProjectSettings.globalize_path(test_path + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	g._switch("ch6")
	g.scene._land(2)
	g.remember_current()
	var tower: Dictionary = g.resume_point.duplicate(true)
	var position: Vector3 = g.scene.walker.position
	restore(tower)
	check(g.scene.floor_index == 2 and g.scene.phase == "walk" and g.scene.walker.position == position and not g.dlg.active, "tower resume keeps the current landing and completed story")
	g._switch("ch3")
	g.scene.phase = "play"
	g.remember_current()
	var drum: Dictionary = g.resume_point.duplicate(true)
	restore(drum)
	check(g.scene.phase == "ready", "a rhythm performance resumes from its preparation screen")
	g._switch("ch7")
	g.scene.start_battle()
	var checkpoint_score: int = g.scene.score
	g.scene.score += 400
	g.scene.bt = 15.0
	g.remember_current()
	var battle: Dictionary = g.resume_point.duplicate(true)
	restore(battle)
	check(g.scene.mode == "battle" and g.scene.bt == 0 and g.scene.paused and g.scene.score == checkpoint_score, "battle loads paused at the phase checkpoint without duplicating mid-phase rewards")
	# Exercise actual menu writes against isolated paths, never the player's files.
	var real_auto: String = g.progress_path
	var real_manual: String = g.manual_path
	g.progress_path = "user://oct21_auto_verification.json"
	g.manual_path = "user://oct21_manual_verification.json"
	g.transient_save = false
	g._switch("ch5")
	g.scene.choose(0)
	g.scene.start_round(1)
	g.scene.sel = [["w", 0]]
	var manual_hand: Array = g.scene.hand_w.duplicate()
	g.overlay.open_help()
	g.overlay.open_saves()
	g.overlay.act("save_manual")
	check(not g.overlay.manual_point.is_empty(), "pause-menu save writes the manual slot")
	g.overlay.close_panel()
	g.overlay.close_panel()
	g.scene.money = 99
	g.return_from_menu("title")
	check(g.screen == "title" and g.resume_point["state"]["money"] == 99, "returning to title saves the latest automatic checkpoint")
	g.resume_point.clear()
	g._load_progress()
	g.scene.act("start")
	check(g.screen == "ch5" and g.scene.money == 99 and g.scene.hand_w == manual_hand, "title continue restores the automatic save read from disk")
	g.overlay.open_saves()
	g.overlay.act("load_manual")
	check(g.screen == "ch5" and g.scene.money == 0 and g.scene.hand_w == manual_hand and g.scene.sel == [["w", 0]], "manual loading restores its earlier checkpoint independently of automatic progress")
	g.overlay.open_help()
	g.overlay.open_saves()
	g.overlay.close_panel()
	check(g.overlay.panel == "help", "closing save management returns to the pause menu")
	g.overlay.close_panel()
	g._switch("epilogue")
	g.scene._finish_film()
	g.scene.phase = "walk"
	g.scene.seen = {"screen": true}
	g.scene.walker.position = Vector3(-1.5, 0.05, 0.5)
	g.remember_current()
	var lab: Dictionary = g.resume_point.duplicate(true)
	restore(lab)
	check(g.scene.phase == "walk" and g.scene.seen.has("screen") and not g.scene.film_real and g.scene.walker.position == Vector3(-1.5, 0.05, 0.5), "laboratory resume retains observations and position without replaying the arrival film")
	g.transient_save = true
	for path in [g.progress_path, g.manual_path]:
		for suffix in ["", ".bak", ".tmp"]:
			var absolute := ProjectSettings.globalize_path(path + suffix)
			if FileAccess.file_exists(absolute):
				DirAccess.remove_absolute(absolute)
	g.progress_path = real_auto
	g.manual_path = real_manual
	g._switch("title")
	g.overlay.open_confirm_new()
	check(g.overlay.panel == "confirm_new", "new game requires confirmation")
	g.overlay.close_panel()
	g.overlay.open_saves()
	check(g.overlay.panel == "saves", "title and pause menus can open save management")
	await t._frames(2)
