extends RefCounted
## Dialogue runner: typewriter text, speaker portraits, branching choices and story events.
## Drawing happens on the host Control (main.gd) so it shares fonts and helpers.

const Story = preload("res://scripts/data/story.gd")
const Pal = preload("res://scripts/core/pal.gd")
const CPS := 34.0          # characters revealed per second

var g                      # main.gd (game state)
var c                      # overlay canvas used for drawing
var queue: Array = []
var index := 0
var shown := 0.0
var active := false
var on_done := Callable()
var current_id := ""
var appear := 0.0          # box pop-in
var history: Array[Dictionary] = []
var history_open := false
var history_end := 0
var history_start := 0
var history_record := -1
var history_playing := -1
var run_serial := 0
var event_epoch := 0


func _init(game, canvas) -> void:
	g = game
	c = canvas


func start(id: String, done := Callable()) -> void:
	start_lines(Story.DIALOGUE.get(id, []), done, id)


func start_lines(lines: Array, done := Callable(), id := "") -> void:
	run_serial += 1
	close_history()
	queue = lines.duplicate(true)
	index = 0
	active = true
	appear = 0.0
	on_done = done
	current_id = id
	_enter()
	if g.fast_dialogue:
		_fast_forward()


func entry() -> Dictionary:
	return queue[index] if active and index < queue.size() else {}


func choosing() -> bool:
	return active and entry().has("choice") and is_complete()


func is_complete() -> bool:
	return shown >= float(str(entry().get("t", "")).length())


func process(delta: float) -> void:
	if active and not history_open:
		shown += delta * CPS * float(g.settings["text_speed"])
		appear = minf(1.0, appear + delta * 6.0)


func advance() -> void:
	if not active or history_open:
		return
	if not is_complete():
		shown = 9999.0
		return
	if entry().has("choice"):
		return
	index += 1
	_enter()


func choose(i: int) -> void:
	if not choosing() or history_open:
		return
	var options: Array = entry()["choice"]
	if i < 0 or i >= options.size():
		return
	var c: Dictionary = options[i]
	if history_record >= 0:
		history[history_record]["selected"] = i
	g.flags[c["flag"]] = c["v"]
	var then: Array = c.get("then", [])
	for j in range(then.size()):
		queue.insert(index + 1 + j, then[j])
	index += 1
	_enter()


func _enter() -> void:
	while index < queue.size():
		var e: Dictionary = queue[index]
		if e.has("if") and not bool(g.flags.get(e["if"], false)):
			index += 1
			continue
		if e.has("ifnot") and bool(g.flags.get(e["ifnot"], false)):
			index += 1
			continue
		if e.get("w", "") == "event":
			# A scene event may change gameplay state; earlier choices become read-only.
			event_epoch += 1
			g.story_event(str(e["event"]))
			index += 1
			continue
		shown = 0.0
		var record := {"w": e.get("w", "narr"), "t": e.get("t", ""), "selected": -1}
		if e.has("choice"):
			record["options"] = e["choice"].map(func(option): return str(option["t"]))
			record["checkpoint"] = {"run": run_serial, "epoch": event_epoch,
				"queue": queue.duplicate(true), "index": index, "flags": g.flags.duplicate(true)}
		history.append(record)
		history_record = history.size() - 1
		g.sfx("hover")
		g.voice(str(e.get("w", "narr")), str(e.get("t", "")))
		return
	_finish()


func _finish() -> void:
	active = false
	close_history()
	g.stop_voice()
	var cb := on_done
	on_done = Callable()
	if cb.is_valid():
		cb.call()


## History belongs to this play session; scene changes preserve the text, not checkpoints.
func cancel(clear_history := false) -> void:
	active = false
	close_history()
	on_done = Callable()
	queue.clear()
	run_serial += 1
	if clear_history:
		history.clear()
		history_record = -1


func toggle_history() -> void:
	if not active:
		return
	if history_open:
		close_history()
	else:
		history_open = true
		history_end = history.size()
		g.stop_voice()


func close_history() -> void:
	history_open = false
	if history_playing >= 0:
		g.stop_voice()
	history_playing = -1


func history_has_voice(record_index: int) -> bool:
	if record_index < 0 or record_index >= history.size():
		return false
	if record_index == history_record and active and not is_complete():
		return false
	var record: Dictionary = history[record_index]
	return g.has_voice(str(record["w"]), str(record["t"]))


func replay_history(record_index: int) -> void:
	if not history_open or not history_has_voice(record_index):
		return
	if history_playing == record_index and g.speech.playing:
		g.stop_voice()
		history_playing = -1
		return
	if not g.sound_on:
		return
	var record: Dictionary = history[record_index]
	history_playing = record_index if g.voice(str(record["w"]), str(record["t"])) else -1


func scroll_history(amount: int) -> void:
	if history_open:
		history_end = clampi(history_end + amount, 1, history.size())


func can_rewind(record_index: int) -> bool:
	if not active or record_index < 0 or record_index >= history.size():
		return false
	var record: Dictionary = history[record_index]
	var checkpoint: Dictionary = record.get("checkpoint", {})
	return record.get("selected", -1) >= 0 and not checkpoint.is_empty() and checkpoint["run"] == run_serial and checkpoint["epoch"] == event_epoch


func rewind_choice(record_index: int) -> bool:
	if not can_rewind(record_index):
		return false
	var checkpoint: Dictionary = history[record_index]["checkpoint"]
	queue = checkpoint["queue"].duplicate(true)
	index = checkpoint["index"]
	g.flags = checkpoint["flags"].duplicate(true)
	# Remove the abandoned branch, including its selected answer and any later checkpoints.
	history.resize(record_index + 1)
	history[record_index]["selected"] = -1
	history_record = record_index
	close_history()
	shown = 9999.0
	appear = 1.0
	g.stop_voice()
	g.sfx("note")
	return true


func history_key(event: InputEventKey) -> bool:
	if not history_open:
		return false
	match event.keycode:
		KEY_H, KEY_ESCAPE:
			close_history()
		KEY_UP, KEY_PAGEUP:
			scroll_history(-1 if event.keycode == KEY_UP else -4)
		KEY_DOWN, KEY_PAGEDOWN:
			scroll_history(1 if event.keycode == KEY_DOWN else 4)
		KEY_HOME:
			history_end = 1
		KEY_END:
			history_end = history.size()
	return true


func history_act(id: String) -> void:
	if id == "dlg_history":
		toggle_history()
	elif id == "history_close":
		close_history()
	elif id.begins_with("history_play_"):
		replay_history(int(id.trim_prefix("history_play_")))
	elif id == "history_older":
		scroll_history(-maxi(1, history_end - history_start))
	elif id == "history_newer":
		scroll_history(maxi(1, history_end - history_start))
	elif id.begins_with("history_rewind_"):
		rewind_choice(int(id.trim_prefix("history_rewind_")))


func portrait_key() -> String:
	var e := entry()
	var cast: Dictionary = Story.CAST.get(e.get("w", "narr"), Story.CAST["narr"])
	var base: String = cast.get("tex", "")
	var posed := base + "_" + str(e.get("pose", ""))
	return posed if e.has("pose") and g.tex.has(posed) else base


func _history_text(record_index: int) -> String:
	var text: String = history[record_index]["t"]
	return text.substr(0, int(shown)) if active and record_index == history_record else text


func _history_lines(text: String, width: float, size: int) -> int:
	var rows := 1
	var line := ""
	for character in text:
		if character == "\n" or g.prose.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			rows += 1
			line = "" if character == "\n" else character
		else:
			line += character
	return rows


func _history_height(record_index: int) -> float:
	var record: Dictionary = history[record_index]
	var height := 53.0 + _history_lines(_history_text(record_index), 870, 19) * 27.0
	if record.has("options") and (record.get("selected", -1) >= 0 or record_index != history_record or is_complete()):
		for option in record["options"]:
			height += _history_lines(str(option), 815, 16) * 24.0
	return height


func draw_history() -> void:
	if not history_open:
		return
	c.hit_regions.clear()
	c.draw_rect(Rect2(0, 0, 1440, 900), Color(0.005, 0.012, 0.018, 0.84))
	c._box(Rect2(150, 80, 1140, 738), Color("101e23"), 5, Color("6f6651"))
	c._title(Vector2(194, 143), "对话回录", 34, Pal.PAPER)
	c._t(Vector2(390, 140), "点击播放重听台词 · 选择处可返回重选", 15, Pal.MUTED)
	c._button("history_close", Rect2(1126, 106, 118, 38), "返回  H / Esc", false, 14)
	c.draw_line(Vector2(194, 167), Vector2(1244, 167), Color("554f42"))
	var height := 0.0
	history_start = history_end
	while history_start > 0:
		var row_height := _history_height(history_start - 1)
		if height + row_height > 550.0:
			break
		height += row_height
		history_start -= 1
	var y := 186.0
	for i in range(history_start, history_end):
		var record: Dictionary = history[i]
		var cast: Dictionary = Story.CAST.get(record["w"], Story.CAST["narr"])
		var name: String = cast.get("name", "")
		c._t(Vector2(200, y + 20), "旁白" if name.is_empty() else name, 16, Pal.GOLD)
		var available := history_has_voice(i)
		var playing: bool = history_playing == i and g.speech.playing
		var label := "■ 停止" if playing else ("▶ 播放" if available else "无配音")
		if i == history_record and not is_complete() and str(record["w"]) != "narr":
			label = "待读完"
		c._button("history_play_%d" % i, Rect2(970, y + 2, 110, 32), label if g.sound_on else "声音已关", playing, 14, available and g.sound_on)
		if can_rewind(i):
			c._button("history_rewind_%d" % i, Rect2(1100, y + 4, 138, 33), "回到这个选择", false, 14)
		var rows: int = c._serif_wrap(Vector2(200, y + 49), _history_text(i), 870, 19, Pal.PAPER, 27)
		var option_y := y + 49 + rows * 27
		if record.has("options") and (record.get("selected", -1) >= 0 or i != history_record or is_complete()):
			for j in range(record["options"].size()):
				var selected: bool = record.get("selected", -1) == j
				var prefix := "已选  " if selected else "　　　"
				var lines: int = c._serif_wrap(Vector2(220, option_y), prefix + record["options"][j], 860, 16, Pal.GOLD if selected else Pal.MUTED, 24)
				option_y += lines * 24
		y += _history_height(i)
		c.draw_line(Vector2(200, y - 7), Vector2(1240, y - 7), Color(0.70, 0.61, 0.41, 0.13))
	c._button("history_older", Rect2(194, 760, 120, 34), "↑ 更早", false, 14, history_start > 0)
	c._button("history_newer", Rect2(326, 760, 120, 34), "↓ 较新", false, 14, history_end < history.size())
	c._t(Vector2(474, 782), "滚轮翻阅", 14, Pal.MUTED)
	c._t(Vector2(1120, 782), "%d / %d" % [history_end, history.size()], 14, Pal.MUTED)


func _fast_forward() -> void:
	var guard := 0
	while active and guard < 500:
		guard += 1
		shown = 9999.0
		if entry().has("choice"):
			choose(0)
		else:
			advance()


# ------------------------------------------------------------------ drawing
func draw() -> void:
	if not active:
		return
	var e := entry()
	if e.is_empty():
		return
	c.hit_regions.clear()
	c._register("dlg_next", Rect2(0, 0, 1440, 900))
	var speaker: String = e.get("w", "narr")
	var cast: Dictionary = Story.CAST.get(speaker, Story.CAST["narr"])
	var k := ease(appear, -2.0)
	# Cinematic shade rising from the bottom instead of a flat dim.
	for i in range(24):
		var f := float(i) / 24.0
		c.draw_rect(Rect2(0, 900 - (i + 1) * 18, 1440, 18), Color(0.01, 0.015, 0.02, 0.62 * (1.0 - f) * (1.0 - f) * k))
	# Portrait: the speaker stands beside the box; Su on the left, everyone else on the right.
	var tex_key := portrait_key()
	if not tex_key.is_empty() and g.tex.has(tex_key):
		var t: Texture2D = g.tex[tex_key]
		var h := 560.0 if tex_key != "su_portrait" else 430.0
		var w := t.get_size().x / t.get_size().y * h
		var left: bool = cast.get("side", "right") == "left"
		var x := 150.0 if left else 1290.0 - w
		var bob := sin(c.age * 1.6) * 3.0
		var y := 860.0 - h + (1.0 - k) * 40.0 + bob
		c.draw_texture_rect(t, Rect2(x, y, w, h), false, Color(1, 1, 1, k))
	var box := Rect2(160, 676, 1120, 176)
	c._dialogue_frame(box, k)
	var name: String = cast.get("name", "")
	var text: String = e.get("t", "")
	var visible := text.substr(0, int(shown))
	if name.is_empty():
		# Narration: centred, slightly cooler, no name plate.
		c._serif_wrap(Vector2(214, 742), visible, 1010, 22, Color(0.90, 0.90, 0.85, k), 38)
	else:
		# A separate name plate sits wholly above the dialogue border.
		var name_size := 28
		var name_width: float = c._heading_font().get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
		var plate := Rect2(box.position + Vector2(30, -53), Vector2(name_width + 46, 43))
		c._box(plate, Color(0.02, 0.035, 0.04, 0.94 * k), 3, Color(0.84, 0.72, 0.48, 0.42 * k))
		c._img("ui_jade_tassel", Rect2(plate.position + Vector2(6, 7), Vector2(5, 32)), Color(1, 1, 1, k))
		var name_baseline: float = plate.get_center().y + (c._heading_font().get_ascent(name_size) - c._heading_font().get_descent(name_size)) * 0.5
		c._title(Vector2(plate.position.x + 23, name_baseline), name, name_size, Color(0.95, 0.88, 0.7, k))
		c._serif_wrap(Vector2(214, 736), visible, 1010, 22, Color(0.95, 0.91, 0.82, k), 38)
	if is_complete() and not e.has("choice"):
		var blink := 0.5 + 0.5 * sin(c.age * 5.0)
		var tip := Vector2(1250, 828 + blink * 3)
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, -5), tip + Vector2(7, -5), tip + Vector2(0, 3)]), Color(0.84, 0.72, 0.48, 0.4 + blink * 0.6))
	c._t(Vector2(989, 881), "点击 / 空格 继续 · Ctrl 快进", 13, Color(0.72, 0.76, 0.71, 0.9 * k))
	if choosing():
		c.hit_regions.clear()
		var options: Array = e["choice"]
		for i in range(options.size()):
			var r := Rect2(370, 360 + i * 76, 700, 58)
			c._dialogue_choice("dlg_choice_%d" % i, r, "%d   %s" % [i + 1, options[i]["t"]])
	c._button("dlg_history", Rect2(175, 860, 142, 30), "对话历史  H", false, 13)
	draw_history()
