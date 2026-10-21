extends RefCounted
## Only gameplay values are serialized. Nodes, audio streams and callbacks are rebuilt.
const FIELDS := {
	"prologue": "phase inspected alignment alignment_vis stable_time calibrated",
	"ch1": "note_read mirror_found mirror_placed selected angle_step angle_vis revealed dials dial_previous cabinet_open lid_t shard_taken dark dark_t lamp_pos oil hidden_at found search_done hint_level",
	"ch2": "evidence inspected phase round_i line_i line_t credit credit_max bullet pressed hint_level",
	"ch3": "phase asked easy autoplay auto_used result score counts combo best_combo",
	"ch4": "state checkpoint trail phase seen_lore caught_count undo_stack",
	"ch5": "phase round_i score plays discards money charms deck_w deck_f pile_w pile_f hand_w hand_f sel prev_line last score_t lines_played offers best_total",
	"ch6": "phase floor_index visited auto_mode route route_index bell_step",
	"ch7": "mode read_stele seen phase easy lives bombs score graze power points next_extend stage_points",
	"finale": "pieces selected done seam_t tries",
	"epilogue": "phase seen mirror_awake done ending_time",
}
const LABELS := {"prologue": "序章 · 数字修复室", "ch1": "第一章 · 温记镜坊", "ch2": "第二章 · 西市对质",
	"ch3": "第三章 · 胡旋击鼓", "ch4": "第四章 · 长安夜行", "ch5": "第五章 · 曲江诗牌",
	"ch6": "第六章 · 慈恩登塔", "ch7": "第七章 · 镜月之战", "finale": "终章 · 金缮", "epilogue": "尾声 · 实验室", "map": "长安舆图"}


static func capture(g) -> Dictionary:
	if not FIELDS.has(g.screen) or g.dlg.active or g.overlay.panel == "card" or not g.pending.is_empty() or g.scene.cinematic_active():
		return {}
	var c = g.scene
	if g.screen == "ch1" and c.refilling > 0.0:
		return {}
	if g.screen == "ch2" and c._input_locked():
		return {}
	if g.screen == "ch4" and c.phase == "caught":
		return {}
	if g.screen == "ch6" and c.phase not in ["walk", "summit"]:
		return {}
	if g.screen == "epilogue" and c.phase not in ["walk", "done"]:
		return {}
	if g.screen == "finale" and c.drag >= 0:
		return {}
	var values := {}
	for field in str(FIELDS[g.screen]).split(" "):
		var value = c.get(field)
		values[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	if g.screen == "prologue" and c.phase not in [1, 2]:
		return {}
	if g.screen == "ch3" and c.phase == "play":
		values["phase"] = "ready"
	if g.screen == "ch5":
		if c.phase == "intro":
			return {}
		values["rng_seed"] = c.rng.seed
		values["rng_state"] = c.rng.state
	if g.screen in ["ch6", "epilogue"]:
		values["walker_position"] = c.walker.position
		values["walker_yaw"] = c.walker.rotation.y
		values["walker_pitch"] = c.walker.pitch
	if g.screen == "ch7":
		if c.mode in ["ending", "farewell"]:
			return {}
		values["rng_seed"] = c.rng.seed
		values["rng_state"] = c.rng.state
		if c.mode == "battle":
			values.merge(c.resume_battle, true)
	return {"chapter": g.screen, "state": values, "progress": g.progress_data(),
		"entry_progress": g.chapter_start.duplicate(true), "saved_at": Time.get_unix_time_from_system(), "entry": false}


static func restore(g, point: Dictionary) -> void:
	var c = g.scene
	var values: Dictionary = point.get("state", {})
	for field in str(FIELDS.get(g.screen, "")).split(" ", false):
		if values.has(field):
			c.set(field, values[field])
	if g.screen == "ch4":
		c.aiming = false
		c._sync_3d(true)
		c._refresh_guide()
	if g.screen == "ch1":
		c.dial_flip = [0.0, 0.0, 0.0]
	if g.screen == "ch5":
		c.rng.seed = int(values["rng_seed"])
		c.rng.state = int(values["rng_state"])
		c._sync_tiles()
	if g.screen in ["ch6", "epilogue"]:
		if is_instance_valid(c.film_player):
			c.film_player.stop()
			c.film_player.visible = false
		c.film_voice.stop()
		c.film_real = false
		g.music_player.stream_paused = false
		c.walker.position = values["walker_position"]
		c.walker.rotation.y = float(values["walker_yaw"])
		c.walker.pitch = float(values["walker_pitch"])
		c.walker.camera.rotation.x = c.walker.pitch
		c.walker.velocity = Vector3.ZERO
		c.mouse_locked = false
		if g.screen == "ch6":
			c.environment.guide_arrive(c.floor_index)
			if c.phase == "walk":
				c.environment.guide_fly_up()
	if g.screen == "ch7" and c.mode == "battle":
		c.rng.seed = int(values["rng_seed"])
		c.rng.state = int(values["rng_state"])
		c._start_phase(int(values["phase"]), false)
		c.lives = maxi(1, c.lives)
		c.game_over = false
		c.paused = true
		c._say("已回到本阶段起点，按 Esc 继续。", 4.0)
	if point.has("entry_progress"):
		g.chapter_start = point["entry_progress"].duplicate(true)
	c.transform = c.stage_transform()


static func description(point: Dictionary) -> String:
	if point.is_empty():
		return "暂无存档"
	var chapter: String = point.get("chapter", "map")
	var label: String = LABELS.get(chapter, "长安旅程")
	var values: Dictionary = point.get("state", {})
	if chapter == "ch4" and values.has("state"):
		label += " · 第 %d 回合" % int(values["state"]["t"])
	elif chapter == "ch5" and values.has("round_i"):
		label += " · 第 %d 巡" % (int(values["round_i"]) + 1)
	elif chapter == "ch6" and values.has("floor_index"):
		label += " · 第 %d 层" % (int(values["floor_index"]) + 1)
	return label
