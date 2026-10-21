extends Control
## 长安拾遗 game host: global state, scene switching, overlays, audio, save and test entry points.
## Each screen (title, map, chapters) is a Node2D script in scripts/chapters/ built on core/canvas.gd.

const Pal = preload("res://scripts/core/pal.gd")
const Story = preload("res://scripts/data/story.gd")
const Dialogue = preload("res://scripts/core/dialogue.gd")
const Overlay = preload("res://scripts/core/overlay.gd")
const Tests = preload("res://scripts/core/tests.gd")
const SessionState = preload("res://scripts/core/session_state.gd")
const SCENES := {
	"title": preload("res://scripts/chapters/title.gd"),
	"codex": preload("res://scripts/chapters/codex.gd"),
	"prologue": preload("res://scripts/chapters/prologue.gd"),
	"map": preload("res://scripts/chapters/map.gd"),
	"ch1": preload("res://scripts/chapters/ch1_workshop.gd"),
	"ch2": preload("res://scripts/chapters/ch2_market.gd"),
	"ch3": preload("res://scripts/chapters/ch3_huxuan.gd"),
	"ch4": preload("res://scripts/chapters/ch4_night.gd"),
	"ch5": preload("res://scripts/chapters/ch5_qujiang.gd"),
	"ch6": preload("res://scripts/chapters/ch6_tower.gd"),
	"ch7": preload("res://scripts/chapters/ch7_pagoda.gd"),
	"finale": preload("res://scripts/chapters/finale.gd"),
	"epilogue": preload("res://scripts/chapters/epilogue.gd"),
}
const SAVE_PATH := "user://changan_save.json"
const SAVE_VERSION := 5
const MANUAL_SAVE_PATH := "user://changan_manual.json"
const SETTINGS_PATH := "user://changan_settings.cfg"
const SETTINGS_VERSION := 2
const DEFAULT_SETTINGS := {"voice": 0.5, "music": 0.5, "effects": 0.5, "fullscreen": false, "text_speed": 1.0}
const CHAPTERS := ["prologue", "ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7", "finale", "epilogue"]
const TEXTURES := {
	"workshop": "workshop.png", "title": "title.jpg", "paper": "paper.jpg", "mirror": "mirror.png",
	"shard": "shard.png", "lab": "lab.jpg", "lab_damaged": "lab_damaged.png", "bowl_damaged": "bowl_damaged.png", "market": "market.jpg", "pagoda": "pagoda.jpg",
	"npc_wen": "npc_wen.png", "npc_kang": "npc_kang.png", "npc_ashi": "npc_ashi.png", "npc_mi": "npc_mi.png", "npc_seng": "npc_seng.png", "tavern": "tavern.jpg", "su_portrait": "su_portrait.png",
	"npc_wen_explain": "npc_wen_explain.png", "npc_wen_recall": "npc_wen_recall.png", "npc_wen_offer": "npc_wen_offer.png",
	"qujiang": "qujiang.png", "feast": "feast.jpg", "npc_bai": "npc_bai.png", "npc_zheng": "npc_zheng.png",
	"boss_1": "boss_1.png", "boss_2": "boss_2.png", "boss_mirror": "boss_mirror.png",
	"player_su": "player_su.png",
	"ch7_mirror_moon_logo": "ch7_mirror_moon_logo.png",
	"ch7_rooftops": "ch7_battle/rooftop-night.jpg", "ch7_gallery": "ch7_battle/bell-gallery-night.jpg",
	"ch7_realm": "ch7_battle/mirror-realm-night.jpg", "ch7_moon": "ch7_battle/moon.png",
	"ch7_crane": "ch7_battle/crane.png", "ch7_diver": "ch7_battle/diver.png",
	"ch7_lantern": "ch7_battle/lantern.png", "ch7_spirit": "ch7_battle/spirit.png",
	"ch7_wisp": "ch7_battle/wisp.png", "ch7_bell": "ch7_battle/bell.png",
	"lab_window": "lab/window-night.jpg", "lab_archive": "lab/archive-cabinet.jpg",
	"lab_scanner": "lab/scanner-fascia.jpg", "lab_research": "lab/conservation-board.jpg",
	"bowl": "bowl.png", "bowl_broken": "bowl_broken.png", "bowl_seams": "bowl_seams.png",
	"frag_0": "frag_0.png", "frag_1": "frag_1.png", "frag_2": "frag_2.png", "frag_3": "frag_3.png",
	"evidence_shard": "evidence_shard.png", "evidence_ledger": "evidence_ledger.png",
	"evidence_bundle": "evidence_bundle.png", "evidence_gong": "evidence_gong.png",
	"ch2_cutin_su": "ch2_cutin_su.png", "ch2_cutin_kang": "ch2_cutin_kang.png",
	"ch2_cutin_background": "ch2_cutin_background.png", "ch2_cutin_title": "ch2_cutin_title.png",
	"ch2_cutin_retort_title": "ch2_cutin_retort_title.png",
	"ch1_casket_front": "ch1_casket_front.png", "ch1_casket_lid": "ch1_casket_lid.png",
	"ch1_handbook": "ch1_workshop/wen-handbook.png", "ch1_mirror_face": "ch1_workshop/mirror-face.png",
	"ch1_workshop_open": "ch1_workshop/workshop-open-background.png",
	"hand_lamp": "ch1_workshop/bronze-oil-lamp.png", "hand_flame": "ch1_workshop/oil-flame.png",
	"npc_jiujia": "npc_jiujia.png", "poetry_card": "ui/poetry-card.png",
	"map_ch1": "map/ch1.png", "map_ch2": "map/ch2.png", "map_ch3": "map/ch3.png", "map_ch4": "map/ch4.png",
	"map_ch5": "map/ch5.png", "map_ch6": "map/ch6.png", "map_ch7": "map/ch7.png", "map_finale": "map/finale.png",
	"mi_dance_0": "mi_dance_0.png", "mi_dance_1": "mi_dance_1.png", "mi_dance_2": "mi_dance_2.png", "mi_dance_3": "mi_dance_3.png",
	"mi_dance_4": "mi_dance_4.png", "mi_dance_5": "mi_dance_5.png", "mi_dance_6": "mi_dance_6.png", "mi_dance_7": "mi_dance_7.png",
	"ui_corner_tl": "ui/corner_tl.png", "ui_corner_tr": "ui/corner_tr.png",
	"ui_corner_bl": "ui/corner_bl.png", "ui_corner_br": "ui/corner_br.png",
	"ui_mirror_seal": "ui/mirror_seal.png", "ui_grape_flourish": "ui/grape_flourish.png",
	"ui_cloud_rule": "ui/cloud_rule.png", "ui_jade_tassel": "ui/jade_tassel.png",
	"ui_moon_lotus": "ui/moon_lotus.png",
	"moon_phase_0": "ch7_battle/phase-new.png", "moon_phase_1": "ch7_battle/phase-half.png",
	"moon_phase_2": "ch7_battle/phase-full.png",
}
const MUSIC_VOLUME := {"ambient": -13.0, "battle": -9.0, "stage7": -9.0, "boss7": -8.0}
const VOICE_DEFAULT_DB := 3.0
const VOICE_VOLUME := {"boss": 10.0}

var face: Font
var heading: Font
var prose: Font
var tex := {}
var tracks := {}
# Persistent progress.
var flags := {}
var shards := [false, false, false, false]
var cleared := {}
var collected: Array = []
var hints_used := 0
var play_time := 0.0
var stats := {"retries": 0, "credit_lost": 0, "lamp_refills": 0, "caught": 0}
# Runtime.
var screen := ""
var scene
var overlay
var dlg
var sound_on := true
var test_mode := false
var fast_dialogue := false
var transient_save := false
var pending := ""
var fade := 0.0
var ff_timer := 0.0
var music_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var speech: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var current_music := ""
var old_hover := ""
var capture_path := ""
var capture_stage := ""
var preview_chapter := ""
var tester
var playtest_runner
var zun_mode := false
var cheat_buffer := ""
var cheat_time := 0.0
var chapter_start := {}
var restarting_chapter := false
var settings := DEFAULT_SETTINGS.duplicate()
var resume_point := {}
var pending_resume := {}
var restoring_run := false
var snapshot_clock := 0.0
var autosave_clock := 0.0
var progress_path := SAVE_PATH
var manual_path := MANUAL_SAVE_PATH


func _ready() -> void:
	get_tree().auto_accept_quit = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	face = load("res://assets/fonts/body-sc.ttf") as Font
	prose = load("res://assets/fonts/display-sc.ttf") as Font
	heading = load("res://assets/fonts/brush-sc.ttf") as Font
	prose.fallbacks = [face]
	heading.fallbacks = [prose]
	for key in TEXTURES:
		var path: String = "res://assets/images/" + TEXTURES[key]
		if ResourceLoader.exists(path):
			tex[key] = load(path)
	var args := OS.get_cmdline_user_args()
	test_mode = args.has("--self-test") or args.has("--self-test-playtest") or args.has("--ui-test") or args.has("--ui-test-prologue") or args.has("--ui-test-tower") or args.has("--ui-test-epilogue") or args.has("--ui-test-navigation")
	fast_dialogue = test_mode
	transient_save = test_mode or args.has("--fresh")
	for arg in args:
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--stage="):
			capture_stage = arg.trim_prefix("--stage=")
		if arg in ["--preview=prologue", "--preview=ch1", "--preview=ch2", "--preview=ch3", "--preview=ch4", "--preview=ch5", "--preview=ch6", "--preview=epilogue"]:
			preview_chapter = arg.trim_prefix("--preview=")
			transient_save = true
	if not capture_path.is_empty():
		transient_save = true
	_load_settings()
	_prepare_audio()
	_apply_settings()
	overlay = Overlay.new()
	overlay.setup(self)
	add_child(overlay)
	dlg = Dialogue.new(self, overlay)
	if not transient_save:
		_load_progress()
	_switch("title")
	if not preview_chapter.is_empty() and not test_mode and capture_path.is_empty():
		if preview_chapter in ["ch2", "ch3", "ch4", "ch5", "ch6"]:
			cleared = {"ch1": true, "ch2": true, "ch3": true, "ch4": true}
			shards = [true, true, true, false]
			flags["ashi_joined"] = true
		if preview_chapter == "ch6":
			cleared["ch5"] = true
			flags["bai_introduction"] = true
		if preview_chapter == "epilogue":
			for id in ["ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7", "finale"]:
				cleared[id] = true
			shards = [true, true, true, true]
			collected = ["mirror", "shard", "shard_b", "shard_c", "shard_d", "bowl", "coin"]
		_switch(preview_chapter)
	if test_mode or not capture_path.is_empty():
		tester = Tests.new(self)      # keep a reference: RefCounted would be freed before the deferred call
	if args.has("--self-test-playtest"):
		playtest_runner = preload("res://scripts/core/playtest_checks.gd").new(tester)
		playtest_runner.run_and_finish.call_deferred()
	elif args.has("--ui-test-navigation"):
		tester.run_navigation_ui.call_deferred()
	elif args.has("--ui-test-epilogue"):
		tester.run_epilogue_ui.call_deferred()
	elif args.has("--ui-test-tower"):
		tester.run_tower_ui.call_deferred()
	elif args.has("--ui-test-prologue"):
		tester.run_ui.call_deferred(true)
	elif args.has("--ui-test"):
		tester.run_ui.call_deferred()
	elif args.has("--self-test"):
		tester.run_logic.call_deferred()
	elif not capture_path.is_empty():
		tester.capture.call_deferred(capture_path, capture_stage)


# ================================================================== scenes
func go(name: String) -> void:
	if test_mode or not capture_path.is_empty():
		_switch(name)
	elif pending.is_empty():
		pending = name


## Menu navigation preserves earned progress and discards the departing scene's callbacks.
func return_from_menu(destination: String) -> void:
	if destination not in ["title", "map"] or not pending.is_empty():
		return
	_save_progress()
	_prepare_chapter_exit()
	go(destination)


func can_restart_chapter() -> bool:
	return screen in CHAPTERS and pending.is_empty()


## Restore the entry checkpoint, keeping progress earned before this visit.
func restart_current_chapter() -> bool:
	if not can_restart_chapter() or chapter_start.is_empty():
		return false
	var destination := screen
	flags = chapter_start["flags"].duplicate(true)
	shards = chapter_start["shards"].duplicate()
	cleared = chapter_start["cleared"].duplicate(true)
	collected = chapter_start["collected"].duplicate()
	if destination == "epilogue":
		flags.erase("epilogue_seen")
		flags.erase("epilogue_arrived")
	_prepare_chapter_exit()
	restarting_chapter = true
	_save_progress()
	go(destination)
	return true


## Apply the same story rewards as completing a chapter, without opening reward panels.
func skip_current_chapter() -> bool:
	if not can_restart_chapter():
		return false
	var completed := screen
	var destination := "map"
	var cards: Array = []
	match completed:
		"prologue":
			flags["lab_bowl_seen"] = true
			destination = "ch1"
		"ch1":
			shards[0] = true
			shards[1] = true
			cards = ["mirror", "shard", "shard_b"]
		"ch2":
			shards[2] = true
			cards = ["shard_c"]
		"ch3":
			flags["ashi_joined"] = true
			cards = ["huxuan"]
		"ch5":
			flags["bai_introduction"] = true
		"ch6":
			flags["tower_echo_seen"] = true
			flags["tower_ascent_done"] = true
			flags["bell_order_known"] = true
			cards = ["stele"]
			destination = "ch7"
		"ch7":
			shards[3] = true
			cards = ["shard_d"]
		"finale":
			cards = ["bowl"]
			destination = "epilogue"
		"epilogue":
			flags["epilogue_arrived"] = true
			flags["epilogue_seen"] = {"screen": true, "bowl": true, "mirror": true}
			destination = "title"
	for card in cards:
		if not collected.has(card):
			collected.append(card)
	cleared[completed] = true
	_prepare_chapter_exit()
	_save_progress()
	go(destination)
	notify("已通关本关，进度已记录。")
	return true


func _prepare_chapter_exit() -> void:
	dlg.cancel()
	overlay.reset()
	speech.stop()
	music_player.stream_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cheat_buffer = ""
	if scene:
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		for node in scene.find_children("*", "", true, false):
			if node is AudioStreamPlayer or node is VideoStreamPlayer:
				node.stop()


func _switch(name: String) -> void:
	var restore_point: Dictionary = pending_resume.duplicate(true)
	pending_resume = {}
	if not restore_point.is_empty():
		apply_progress(restore_point["progress"])
	elif scene and not restoring_run:
		remember_current()
	dlg.cancel()
	if scene:
		remove_child(scene)
		scene.queue_free()
	overlay.reset()
	scene = SCENES[name].new()
	scene.setup(self)
	add_child(scene)
	move_child(scene, 0)
	scene.transform = scene.stage_transform()
	screen = name
	old_hover = ""
	cheat_buffer = ""
	chapter_start = {"flags": flags.duplicate(true), "shards": shards.duplicate(), "cleared": cleared.duplicate(true), "collected": collected.duplicate()} if name in CHAPTERS else {}
	restoring_run = not restore_point.is_empty() and not restore_point.get("entry", false)
	if name in CHAPTERS or name == "map":
		resume_point = {"chapter": name, "state": {}, "progress": progress_data(), "entry_progress": chapter_start.duplicate(true),
			"saved_at": Time.get_unix_time_from_system(), "entry": true}
	scene.enter()
	if restoring_run:
		dlg.cancel()
		SessionState.restore(self, restore_point)
		resume_point = restore_point
	restoring_run = false
	restarting_chapter = false
	if name in CHAPTERS or name == "map":
		_save_progress()


func story_event(name: String) -> void:
	if scene and scene.has_method("story_event"):
		scene.story_event(name)


func say(id: String, done := Callable()) -> void:
	if restoring_run:
		return
	dlg.start(id, done)


func show_card(id: String, done := Callable()) -> void:
	if not collected.has(id):
		collected.append(id)
		_save_progress()
	overlay.open_card(id, done)


func notify(message: String, duration := 4.0) -> void:
	overlay.toast = message
	overlay.toast_time = duration


func get_shard(i: int) -> void:
	shards[i] = true
	_save_progress()


func clear(chapter: String) -> void:
	cleared[chapter] = true
	_save_progress()


func shard_count() -> int:
	var n := 0
	for s in shards:
		if s:
			n += 1
	return n


func hint() -> void:
	if scene:
		hints_used += 1
		notify(scene.hint(), 6.0)


func blocked() -> bool:
	return overlay.modal_active() or not pending.is_empty()


# ================================================================== loop and input
func _process(delta: float) -> void:
	if screen.begins_with("ch") or screen == "finale" or (screen == "epilogue" and scene and not scene.done):
		play_time += delta
	var cinematic: bool = scene != null and scene.cinematic_active()
	if not cinematic and overlay.panel.is_empty():
		dlg.process(delta)
	if dlg.active and not dlg.history_open and not cinematic and overlay.panel.is_empty() and Input.is_key_pressed(KEY_CTRL):
		ff_timer -= delta
		if ff_timer <= 0:
			ff_timer = 0.06
			if dlg.is_complete() and not dlg.entry().has("choice"):
				dlg.advance()
			else:
				dlg.shown = 9999.0
	if not pending.is_empty():
		fade = minf(1.0, fade + delta * 3.2)
		if fade >= 1.0:
			_switch(pending)
			pending = ""
	else:
		fade = maxf(0.0, fade - delta * 2.0)
	var is_blocked := blocked()
	if scene:
		if pending.is_empty():
			scene.age += delta
			scene.tick(delta, is_blocked)
			scene.transform = scene.stage_transform()
		scene.queue_redraw()
	overlay.age += delta
	overlay.tick(delta, is_blocked)
	overlay.queue_redraw()
	if not transient_save:
		snapshot_clock += delta
		autosave_clock += delta
		if snapshot_clock >= 0.5:
			snapshot_clock = 0.0
			remember_current()
		if autosave_clock >= 5.0:
			autosave_clock = 0.0
			_save_progress()


func _top_hit(pos: Vector2) -> String:
	var id: String = overlay.hit(pos)
	if id.is_empty() and not overlay.modal_active() and scene:
		id = scene.hit_screen(pos)
	return id


func _gui_input(event: InputEvent) -> void:
	if not pending.is_empty():
		return
	if scene and scene.cinematic_active():
		scene.mouse(scene.localize(event))
		accept_event()
		return
	if event is InputEventMouseMotion:
		var id := _top_hit(event.position)
		if id != old_hover and not id.is_empty() and id != "dlg_next":
			sfx("hover")
		old_hover = id
		var pointer := not id.is_empty() and id != "dlg_next"
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if pointer else Control.CURSOR_ARROW
		if not overlay.modal_active() and scene:
			scene.mouse(scene.localize(event))
		return
	if not event is InputEventMouseButton:
		return
	if overlay.modal_active():
		if dlg.history_open and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			dlg.scroll_history(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var oid: String = overlay.hit(event.position)
			if not oid.is_empty():
				overlay.ripple(event.position)
				overlay.act(oid)
		accept_event()
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cid: String = overlay.hit(event.position)
		if not cid.is_empty():
			sfx("click")
			overlay.act(cid)
			accept_event()
			return
	if scene:
		var local_event: InputEvent = scene.localize(event)
		var handled: bool = scene.mouse(local_event) if scene.hud_hit(event.position).is_empty() else scene.hud_mouse(local_event)
		if handled:
			accept_event()
			return
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and scene:
		var id: String = scene.hit_screen(event.position)
		if not id.is_empty():
			overlay.ripple(event.position)
			sfx("click")
			scene.act(id)
			accept_event()


## Hidden codes: ZUN toggles chapter 7 assistance; SKIP completes the current chapter.
## Consecutive letters must be within 1.5 seconds. Other keys retain their normal actions.
func feed_cheat(keycode: int) -> bool:
	var letter := ""
	if keycode >= KEY_A and keycode <= KEY_Z:
		letter = String.chr(keycode).to_lower()
	var now := Time.get_ticks_msec() / 1000.0
	if letter.is_empty() or now - cheat_time > 1.5:
		cheat_buffer = ""
	if letter.is_empty():
		return false
	cheat_time = now
	cheat_buffer = (cheat_buffer + letter).right(4)
	if cheat_buffer.ends_with("skip"):
		cheat_buffer = ""
		return skip_current_chapter()
	if cheat_buffer.ends_with("zun"):
		cheat_buffer = ""
		zun_mode = not zun_mode
		_save_progress()
		sfx("objection" if zun_mode else "error", -6)
		notify("月华护佑已开启：第七章护魂灯与月华不减。" if zun_mode else "月华护佑已关闭。", 4.0)
		return true
	return false


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not pending.is_empty():
		return
	if overlay.panel == "settings":
		overlay.key(event)
		return
	if not overlay.panel.is_empty() and overlay.key(event):
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F11:
		set_setting("fullscreen", not bool(settings["fullscreen"]))
		get_viewport().set_input_as_handled()
		return
	if dlg.history_key(event):
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		cheat_buffer = ""
	elif feed_cheat(event.keycode):
		get_viewport().set_input_as_handled()
		return
	if scene and scene.cinematic_active():
		scene.key(event)
		return
	if dlg.active:
		match event.keycode:
			KEY_ESCAPE:
				overlay.open_help()
			KEY_H:
				dlg.toggle_history()
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z:
				dlg.advance()
			KEY_1, KEY_2, KEY_3:
				dlg.choose(event.keycode - KEY_1)
		return
	if overlay.key(event):
		return
	if scene and scene.key(event):
		return
	match event.keycode:
		KEY_ESCAPE:
			overlay.open_help()
		KEY_J:
			overlay.open_journal()
		KEY_H:
			hint()


# ================================================================== audio
func _prepare_audio() -> void:
	for bus_name in ["Music", "Voice", "Effects"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var bus := AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus, bus_name)
			AudioServer.set_bus_send(bus, "Master")
	for track in ["ambient", "battle", "rain", "click", "hover", "pickup", "place", "rotate", "dial", "note", "error", "reveal", "unlock", "win", "intro", "revealed", "complete", "shoot", "hit", "graze", "bomb", "objection", "bell", "huxuan", "hux_don", "hux_ka", "hux_cheer", "wind"]:
		var file := "res://assets/audio/%s.wav" % track
		if ResourceLoader.exists(file):
			tracks[track] = load(file)
	# Chapter 7: user-provided Shanghai Teahouse recording, then the existing boss theme.
	for track in ["stage7", "boss7"]:
		var file := "res://assets/audio/%s.ogg" % track
		if ResourceLoader.exists(file):
			var stream: AudioStreamOggVorbis = load(file)
			stream.loop = true
			tracks[track] = stream
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	add_child(music_player)
	music_player.finished.connect(func() -> void:
		if sound_on:
			music_player.play())
	rain_player = AudioStreamPlayer.new()
	rain_player.bus = &"Effects"
	rain_player.volume_db = -20
	add_child(rain_player)
	if tracks.has("rain"):
		rain_player.stream = tracks["rain"]
		rain_player.finished.connect(func() -> void:
			if sound_on:
				rain_player.play())
	speech = AudioStreamPlayer.new()
	speech.bus = &"Voice"
	speech.volume_db = VOICE_DEFAULT_DB
	add_child(speech)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = &"Effects"
		player.volume_db = -6
		add_child(player)
		sfx_players.append(player)


func music(name: String, with_rain := true) -> void:
	if test_mode:
		return
	if with_rain and not rain_player.playing and rain_player.stream:
		rain_player.play()
	elif not with_rain:
		rain_player.stop()
	if current_music == name:
		return
	current_music = name
	if not tracks.has(name):
		music_player.stop()
		return
	music_player.stream = tracks[name]
	music_player.volume_db = MUSIC_VOLUME.get(name, -12.0)
	music_player.play()


func sfx(name: String, volume := -6.0) -> void:
	if not sound_on or not tracks.has(name) or test_mode:
		return
	for player in sfx_players:
		if not player.playing:
			player.stream = tracks[name]
			player.volume_db = volume
			player.play()
			return


func narrate(name: String) -> void:
	if sound_on and tracks.has(name) and not test_mode:
		speech.volume_db = VOICE_DEFAULT_DB
		speech.stream = tracks[name]
		speech.play()


## Character voice lines (assets/voice/<md5 of "speaker|text">.mp3, built by tools/build_voices.py).
## Narration and missing lines are silent; a new line cuts off the previous one.
func voice_path(speaker: String, text: String) -> String:
	return "res://assets/voice/%s.mp3" % ("%s|%s" % [speaker, text]).md5_text()


func has_voice(speaker: String, text: String) -> bool:
	return speaker not in ["narr", "event", ""] and ResourceLoader.exists(voice_path(speaker, text))


func voice(speaker: String, text: String, gain_db := 0.0) -> bool:
	if speaker in ["narr", "event", ""] or test_mode:
		return false
	var path := voice_path(speaker, text)
	if not sound_on or not ResourceLoader.exists(path):
		speech.stop()
		return false
	# Lift all speech by 6 dB; the Master bus retains 5 dB of output headroom.
	# Mirror clips have lower source peaks and keep their existing relative boost.
	speech.volume_db = VOICE_VOLUME.get(speaker, VOICE_DEFAULT_DB) + gain_db
	speech.stream = load(path)
	speech.play()
	return true


func stop_voice() -> void:
	if speech:
		speech.stop()


func toggle_sound() -> void:
	sound_on = not sound_on
	AudioServer.set_bus_mute(0, not sound_on)
	if sound_on:
		if music_player.stream and not music_player.playing:
			music_player.play()


# Settings have their own file and survive both a new game and chapter replay.
func set_setting(id: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(id):
		return
	if id == "fullscreen":
		settings[id] = bool(value)
	else:
		settings[id] = clampf(float(value), 0.5 if id == "text_speed" else 0.0, 2.0 if id == "text_speed" else 1.0)
	_apply_settings()
	_save_settings()


func reset_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	_apply_settings()
	_save_settings()


func _apply_settings() -> void:
	for pair in [["Voice", "voice"], ["Music", "music"], ["Effects", "effects"]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus >= 0:
			var level: float = float(settings[pair[1]])
			# The midpoint retains the original mix; the upper half adds up to 6 dB.
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(level * 2.0, 0.0001)))
			AudioServer.set_bus_mute(bus, level <= 0.0)
	if not test_mode and capture_path.is_empty():
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


func _load_settings(path := SETTINGS_PATH) -> void:
	if path == SETTINGS_PATH and (test_mode or not capture_path.is_empty()):
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var version := int(cfg.get_value("meta", "version", 1))
	for id in DEFAULT_SETTINGS:
		var value: Variant = cfg.get_value("settings", id, DEFAULT_SETTINGS[id])
		if id == "fullscreen":
			settings[id] = value if value is bool else DEFAULT_SETTINGS[id]
		elif value is float or value is int:
			# Preserve the audible level of existing settings when moving unity to 50%.
			if version < 2 and id in ["voice", "music", "effects"] and cfg.has_section_key("settings", id):
				value = clampf(float(value), 0.0, 1.0) * 0.5
			settings[id] = clampf(float(value), 0.5 if id == "text_speed" else 0.0, 2.0 if id == "text_speed" else 1.0)
	if version < SETTINGS_VERSION:
		_save_settings(path)


func _save_settings(path := SETTINGS_PATH) -> void:
	if path == SETTINGS_PATH and (test_mode or not capture_path.is_empty()):
		return
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SETTINGS_VERSION)
	for id in settings:
		cfg.set_value("settings", id, settings[id])
	cfg.save(path)


# ================================================================== save
func progress_data() -> Dictionary:
	return {"version": SAVE_VERSION, "flags": flags.duplicate(true), "shards": shards.duplicate(), "cleared": cleared.duplicate(true), "collected": collected.duplicate(),
		"hints": hints_used, "time": play_time, "stats": stats.duplicate(true), "zun": zun_mode}


func remember_current() -> void:
	if restoring_run or not scene or scene.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var point: Dictionary = SessionState.capture(self)
	if not point.is_empty():
		resume_point = point
	elif screen == "map":
		resume_point = {"chapter": "map", "state": {}, "progress": progress_data(), "saved_at": Time.get_unix_time_from_system(), "entry": true}


func _save_progress() -> void:
	if transient_save or restoring_run:
		return
	remember_current()
	write_save(progress_path)


func write_save(path: String) -> bool:
	var data := progress_data()
	data["resume"] = Marshalls.raw_to_base64(var_to_bytes(resume_point))
	data["saved_at"] = Time.get_unix_time_from_system()
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var absolute := ProjectSettings.globalize_path(path)
	var backup := absolute + ".bak"
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(absolute, backup) != OK:
			return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), absolute) == OK


func read_save(path: String) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if data is Dictionary and int(data.get("version", 0)) in [3, 4, SAVE_VERSION] and data.get("flags") is Dictionary and data.get("cleared") is Dictionary:
			return data
	return {}


func unpack_resume(data: Dictionary) -> Dictionary:
	if not data.get("resume", "") is String or str(data.get("resume", "")).is_empty():
		return {}
	var bytes := Marshalls.base64_to_raw(str(data["resume"]))
	if bytes.size() < 4:
		return {}
	var point = bytes_to_var(bytes)
	if point is Dictionary and point.get("chapter", "") in SCENES and point.get("progress") is Dictionary and point.get("state") is Dictionary:
		return point
	return {}


func _load_progress() -> void:
	var data := read_save(progress_path)
	if data.is_empty():
		return
	apply_progress(data)
	resume_point = unpack_resume(data)


func apply_progress(data: Dictionary) -> void:
	flags = data.get("flags", {}).duplicate(true)
	cleared = data.get("cleared", {}).duplicate(true)
	if int(data.get("version", SAVE_VERSION)) == 3 and cleared.has("ch3"):
		cleared.erase("ch3")         # v0.3 battle chapter is chapter 7 now
		cleared["ch7"] = true
	collected = data.get("collected", []).duplicate()
	hints_used = int(data.get("hints", 0))
	play_time = float(data.get("time", 0.0))
	zun_mode = bool(data.get("zun", false))
	var s = data.get("shards", [])
	if s is Array and s.size() == 4:
		for i in range(4):
			shards[i] = bool(s[i])
	var st = data.get("stats", {})
	stats = {"retries": 0, "credit_lost": 0, "lamp_refills": 0, "caught": 0}
	if st is Dictionary:
		for k in st:
			stats[k] = st[k]


func reset_progress() -> void:
	dlg.cancel(true)
	flags = {}
	shards = [false, false, false, false]
	cleared = {}
	collected = []
	hints_used = 0
	play_time = 0.0
	stats = {"retries": 0, "credit_lost": 0, "lamp_refills": 0, "caught": 0}
	zun_mode = false
	resume_point = {}
	pending_resume = {}
	speech.stop()
	if not transient_save:
		write_save(progress_path)


func continue_saved_game(point: Dictionary = {}) -> bool:
	if point.is_empty():
		point = resume_point
	if point.is_empty():
		return false
	pending_resume = point.duplicate(true)
	go(str(point["chapter"]))
	return true


func save_manual() -> bool:
	if transient_save or screen not in CHAPTERS:
		notify("请在正式旅程的关卡中保存。")
		return false
	remember_current()
	var ok := write_save(manual_path)
	notify("手动存档已保存。" if ok else "保存失败，请检查存档目录。")
	return ok


func load_manual() -> bool:
	var data := read_save(manual_path)
	var point := unpack_resume(data)
	if point.is_empty():
		notify("暂无可读取的手动存档。")
		return false
	if not pending.is_empty():
		return false
	_prepare_chapter_exit()
	return continue_saved_game(point)


func quit_game() -> void:
	_save_progress()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func has_progress() -> bool:
	return not cleared.is_empty() or shard_count() > 0


func codex_unlocked() -> bool:
	return cleared.has("epilogue")
