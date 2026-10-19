extends "res://scripts/core/canvas.gd"
## Post-story illustrated reading room. Text is paginated before drawing, never clipped.
const Book = preload("res://scripts/data/codex.gd")
const BODY_WIDTH := 862.0
const BODY_HEIGHT := 276.0
const BODY_SIZE := 21
const LINE_HEIGHT := 29.0

var category := 0
var selected := 0
var detail_page := 0
var pages: Array = []
var sources_open := false


func enter() -> void:
	if not g.codex_unlocked():
		g.go("title")
		return
	g.music("ambient")
	select_entry(0)


func chrome() -> bool:
	return false


func bottom_hud() -> bool:
	return false


func _body_font() -> Font:
	return g.prose


func items() -> Array:
	return Book.ENTRIES.filter(func(item: Dictionary) -> bool: return item["category"] == category)


func entry() -> Dictionary:
	return items()[selected]


func _lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	var closing := "，。！？；：、）》」』】…”’"
	var opening := "（《「『【“‘"
	for i in range(text.length()):
		var ch := text[i]
		var lookahead := ""
		var cursor := i + 1
		if opening.contains(ch) and cursor < text.length() and text[cursor] != "\n":
			lookahead += text[cursor]
			cursor += 1
		while cursor < text.length() and closing.contains(text[cursor]):
			lookahead += text[cursor]
			cursor += 1
		if ch == "\n" or (not line.is_empty() and g.prose.get_string_size(line + ch + lookahead, HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_SIZE).x > BODY_WIDTH):
			lines.append(line)
			line = "" if ch == "\n" else ch
		else:
			line += ch
	lines.append(line)
	return lines


func paginate(item: Dictionary) -> Array:
	var result: Array = []
	var page: Array = []
	var used := 0.0
	for section in item["sections"]:
		var rows := _lines(str(section[1]))
		var height := 46.0 + rows.size() * LINE_HEIGHT
		if used + height > BODY_HEIGHT and not page.is_empty():
			result.append(page)
			page = []
			used = 0.0
		# Long future articles can continue on another page without overflowing.
		while not rows.is_empty():
			var capacity := maxi(1, int((BODY_HEIGHT - used - 46.0) / LINE_HEIGHT))
			var count := mini(capacity, rows.size())
			page.append({"title": str(section[0]), "lines": rows.slice(0, count), "height": 46.0 + count * LINE_HEIGHT})
			used += 46.0 + count * LINE_HEIGHT
			rows = rows.slice(count)
			if not rows.is_empty():
				result.append(page)
				page = []
				used = 0.0
	if not page.is_empty():
		result.append(page)
	return result


func select_entry(index: int) -> void:
	selected = clampi(index, 0, items().size() - 1)
	detail_page = 0
	sources_open = false
	pages = paginate(entry())


func act(id: String) -> void:
	if sources_open:
		if id == "sources_close":
			sources_open = false
		elif id.begins_with("source_"):
			var source: Dictionary = Book.SOURCES.get(id.trim_prefix("source_"), {})
			var url := str(source.get("url", ""))
			if url.begins_with("https://"):
				OS.shell_open(url)
		return
	if id == "back":
		g.go("title")
	elif id.begins_with("category_"):
		category = clampi(int(id.trim_prefix("category_")), 0, Book.CATEGORIES.size() - 1)
		select_entry(0)
	elif id.begins_with("entry_"):
		select_entry(int(id.trim_prefix("entry_")))
	elif id == "previous_page":
		detail_page = maxi(0, detail_page - 1)
	elif id == "next_page":
		detail_page = mini(pages.size() - 1, detail_page + 1)
	elif id == "sources":
		sources_open = true


func key(event: InputEventKey) -> bool:
	if sources_open:
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
			sources_open = false
		return true
	match event.keycode:
		KEY_ESCAPE:
			act("back")
		KEY_UP:
			select_entry(posmod(selected - 1, items().size()))
		KEY_DOWN:
			select_entry(posmod(selected + 1, items().size()))
		KEY_LEFT, KEY_PAGEUP:
			act("previous_page")
		KEY_RIGHT, KEY_PAGEDOWN, KEY_SPACE:
			act("next_page")
		KEY_TAB:
			category = posmod(category + (-1 if event.shift_pressed else 1), Book.CATEGORIES.size())
			select_entry(0)
		_:
			return false
	return true


func mouse(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if not sources_open:
			var step := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			if event.position.x < 400:
				select_entry(clampi(selected + step, 0, items().size() - 1))
			else:
				detail_page = clampi(detail_page + step, 0, pages.size() - 1)
		return true
	return false


func _draw_art(item: Dictionary) -> void:
	var r := Rect2(446, 214, 270, 267)
	_box(r, Color("142c2e"), 4, Color("746547"))
	var art := str(item["art"])
	if g.tex.has(art):
		if bool(item.get("portrait", false)) or art in ["mirror", "bowl", "bowl_seams", "evidence_ledger", "ch7_moon"]:
			_img("paper", r.grow(-4), Color(0.13, 0.20, 0.20, 0.6))
			var texture: Texture2D = g.tex[art]
			var area := r.grow(-14)
			var fit := minf(area.size.x / texture.get_width(), area.size.y / texture.get_height())
			var size := texture.get_size() * fit
			draw_texture_rect(texture, Rect2(area.get_center() - size * 0.5, size), false)
		else:
			_img_cover(art, r.grow(-4))
	_ornate_corners(r, 28.0, 0.75)
	_t(Vector2(458, 500), "游戏美术示意", 12, Pal.MUTED)


func _draw() -> void:
	hit_regions.clear()
	draw_rect(Rect2(0, 0, 1440, 900), Color("0b181c"))
	_img_cover("title", Rect2(0, 0, 1440, 900), Color(0.28, 0.35, 0.35, 0.16))
	_img("ui_grape_flourish", Rect2(1065, 56, 240, 96), Color(1, 1, 1, 0.24))
	_img("ui_mirror_seal", Rect2(48, 37, 65, 65), Color(1, 1, 1, 0.85))
	_title(Vector2(129, 88), "长安拾遗录", 48, Pal.PAPER)
	_serif(Vector2(444, 83), "从一场旅程，读懂一城风物。", 21, Pal.GOLD)
	_button("back", Rect2(1230, 51, 154, 44), "返回标题  Esc", false, 16)
	for i in range(Book.CATEGORIES.size()):
		_button("category_%d" % i, Rect2(54 + i * 188, 125, 172, 46), Book.CATEGORIES[i], i == category, 21)
	_t(Vector2(1100, 154), "全卷收录  %02d  项" % Book.ENTRIES.size(), 17, Pal.GOLD)
	var list := items()
	_serif(Vector2(62, 207), "%s篇  /  %02d 项" % [Book.CATEGORIES[category], list.size()], 17, Pal.GOLD)
	# Rows shrink when a category is long, so the list never runs into the key hints below.
	var step := minf(66.0, (836.0 - 226.0) / maxf(1.0, list.size()))
	for i in range(list.size()):
		var r := Rect2(54, 226 + i * step, 338, step - 9.0)
		var chosen := i == selected
		var hover := r.has_point(_mouse())
		_box(r, Color("203a3a") if chosen else Color(0.02, 0.05, 0.06, 0.66 if hover else 0.38), 3, Color(Pal.GOLD, 0.75 if chosen else 0.19))
		var baseline := r.get_center().y + 7.0
		_serif(Vector2(69, baseline), "%02d" % (i + 1), 17, Pal.GOLD if chosen else Pal.MUTED)
		var size := _fit_size(g.prose, str(list[i]["title"]), 21, 265)
		_serif(Vector2(112, baseline), str(list[i]["title"]), size, Pal.PAPER)
		_register("entry_%d" % i, r)
	_box(Rect2(420, 193, 965, 647), Color(0.035, 0.075, 0.085, 0.96), 5, Color("6b6049"))
	_ornate_corners(Rect2(420, 193, 965, 647), 40, 0.60)
	if not pages.is_empty():
		var item := entry()
		_draw_art(item)
		_serif(Vector2(748, 250), str(item["tag"]), 17, Pal.GOLD)
		var title_size := _fit_size(g.heading, str(item["title"]), 43, 585)
		_title(Vector2(744, 315), str(item["title"]), title_size, Pal.PAPER)
		draw_line(Vector2(748, 342), Vector2(1338, 342), Color(Pal.GOLD, 0.32))
		# The key line reads as an epigraph: a thin gold rule beside it, no label.
		draw_rect(Rect2(748, 372, 3, 74), Color(Pal.GOLD, 0.55))
		_serif_wrap(Vector2(766, 400), str(item["key"]), 566, 24, Pal.SOFT, 36)
		draw_line(Vector2(458, 514), Vector2(1340, 514), Color(Pal.GOLD, 0.23))
		var y := 525.0
		for part in pages[detail_page]:
			_serif(Vector2(458, y + 20), str(part["title"]), 20, Pal.GOLD)
			for line_i in range(part["lines"].size()):
				_serif(Vector2(458, y + 50 + line_i * LINE_HEIGHT), part["lines"][line_i], BODY_SIZE, Pal.PAPER)
			y += float(part["height"])
		_button("sources", Rect2(458, 800, 210, 29), "史料与阅读出处  ↗", false, 14)
		if pages.size() > 1:
			_button("previous_page", Rect2(1040, 800, 85, 29), "上一页", false, 14, detail_page > 0)
			_serif_center(1164, 821, "%d / %d" % [detail_page + 1, pages.size()], 16, Pal.GOLD)
			_button("next_page", Rect2(1205, 800, 85, 29), "下一页", false, 14, detail_page < pages.size() - 1)
	_t(Vector2(60, 867), "↑ ↓ 选择条目    Tab 切换分类    ← → 翻页", 14, Pal.MUTED)
	_t(Vector2(864, 867), "人物标注虚实 · 知识核对史料 · 图像沿用游戏美术", 14, Pal.MUTED)
	if sources_open:
		_draw_sources()


func _draw_sources() -> void:
	hit_regions.clear()
	draw_rect(Rect2(0, 0, 1440, 900), Color(0, 0.01, 0.02, 0.87))
	_box(Rect2(270, 156, 900, 588), Color("12272b"), 5, Color("a18b60"))
	_ornate_corners(Rect2(270, 156, 900, 588), 38, 0.8)
	_title(Vector2(312, 220), "史料与阅读出处", 35, Pal.PAPER)
	_serif(Vector2(312, 265), "条目：" + str(entry()["title"]), 22, Pal.GOLD)
	var y := 310.0
	for id in entry()["sources"]:
		var source: Dictionary = Book.SOURCES[id]
		var has_link := not str(source["url"]).is_empty()
		_serif_wrap(Vector2(313, y + 25), str(source["title"]), 640, 19, Pal.PAPER, 27)
		if has_link:
			_button("source_" + str(id), Rect2(986, y + 1, 130, 36), "打开原文  ↗", false, 14)
		y += 68
	_serif_wrap(Vector2(313, 632), "历史说明为依据所列资料撰写的概述；人物经历与机关规则另按游戏设定标注。古籍链接为公开文本，现代书目可按书名查阅。", 805, 17, Pal.MUTED, 27)
	_button("sources_close", Rect2(981, 689, 135, 35), "返回  Esc", false, 14)
