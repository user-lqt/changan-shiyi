extends Control
## Native controls provide mouse dragging, keyboard focus and immediate audio feedback.

var g
var rows := {}
var fullscreen_toggle: CheckButton
var updating := false


func setup(game) -> void:
	g = game


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(1440, 900)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	theme.default_font = g.prose
	theme.default_font_size = 19
	self.theme = theme
	var track := StyleBoxFlat.new()
	track.bg_color = Color("263b36")
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = Color("bba16b")
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.012, 0.015, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(360, 100)
	panel.size = Vector2(720, 700)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101f20")
	style.border_color = Color("9d8652")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_label("行旅设置", Vector2(414, 132), 34, Color("ead8af"), true)
	_label("声音 · 画面 · 阅读", Vector2(416, 184), 16, Color("a99b7b"))
	_slider("voice", "人物语音", 245, 0.0, 1.0, 0.01)
	_slider("music", "背景音乐", 325, 0.0, 1.0, 0.01)
	_slider("effects", "环境与音效", 405, 0.0, 1.0, 0.01)
	_slider("text_speed", "文字速度", 485, 0.5, 2.0, 0.1)
	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "全屏显示"
	fullscreen_toggle.position = Vector2(414, 572)
	fullscreen_toggle.size = Vector2(610, 48)
	fullscreen_toggle.toggled.connect(func(on: bool) -> void:
		if not updating:
			g.set_setting("fullscreen", on))
	add_child(fullscreen_toggle)
	_label("调整立即生效，关闭后自动保存。", Vector2(416, 642), 16, Color("a99b7b"))
	_button("试听语音", Vector2(414, 713), Vector2(150, 44), func() -> void:
		g.voice("su", "最后一件了——转台上的海兽葡萄纹铜镜。扫完它，今晚就能收工。"))
	_button("恢复默认", Vector2(579, 713), Vector2(150, 44), func() -> void:
		g.reset_settings()
		refresh())
	var back := _button("返回  Esc", Vector2(834, 713), Vector2(190, 44), func() -> void: g.overlay.close_panel())
	refresh()
	back.grab_focus()


func _label(text: String, at: Vector2, font_size: int, colour: Color, brush := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font", g.heading if brush else g.prose)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	add_child(label)
	return label


func _slider(id: String, title: String, y: float, lo: float, hi: float, step: float) -> void:
	_label(title, Vector2(416, y), 20, Color("ead8af"))
	var value := _label("", Vector2(960, y), 18, Color("d6bc7e"))
	var slider := HSlider.new()
	slider.position = Vector2(416, y + 32)
	slider.size = Vector2(608, 24)
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%.1f 倍" % v if id == "text_speed" else "%d %%" % roundi(v * 100)
		if not updating:
			g.set_setting(id, v))
	add_child(slider)
	rows[id] = {"slider": slider, "value": value}


func _button(text: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("263936")
	normal.border_color = Color("8d7a4b")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("3b5047")
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(action)
	add_child(button)
	return button


func refresh() -> void:
	updating = true
	for id in rows:
		var v: float = float(g.settings[id])
		rows[id]["slider"].value = v
		rows[id]["value"].text = "%.1f 倍" % v if id == "text_speed" else "%d %%" % roundi(v * 100)
	fullscreen_toggle.button_pressed = bool(g.settings["fullscreen"])
	updating = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		g.overlay.close_panel()
		get_viewport().set_input_as_handled()
