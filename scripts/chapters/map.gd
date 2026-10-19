extends "res://scripts/core/city_map.gd"
## Illustrated travel map. Chapter gates and saves are shared with the story.

const NODES := [
	{"id": "ch1", "name": "温记镜坊", "sub": "第一章 · 借光", "pos": Vector2(420, 470), "play": "解谜探索 · 手灯寻片", "tex": "workshop", "desc": "借一盏灯，照见旧物上的纹样。从铜镜与旧匣之间，找回第一条线索。"},
	{"id": "ch2", "name": "西市", "sub": "第二章 · 对质", "pos": Vector2(285, 375), "play": "当面对质 · 以物为证", "tex": "market", "desc": "人声与货声交织的西市。以手中的物证，辨清掌柜言语里的破绽。"},
	{"id": "ch3", "name": "胡姬酒肆", "sub": "第三章 · 胡旋", "pos": Vector2(225, 565), "play": "节奏 · 胡旋舞", "tex": "tavern", "desc": "闭市之后，灯下鼓声渐起。为米娜击鼓伴舞，寻找卖瓷片的少年。"},
	{"id": "ch4", "name": "长安街衢", "sub": "第四章 · 夜行", "pos": Vector2(571, 646), "play": "3D 潜行 · 宵禁穿城", "tex": "title", "desc": "晨起清扫前，须将失物来历告知寺僧。随阿拾避开巡夜，在天亮前赶到慈恩寺。"},
	{"id": "ch5", "name": "曲江池", "sub": "第五章 · 诗牌", "pos": Vector2(938, 646), "play": "诗牌构筑 · 平仄押韵", "tex": "qujiang", "desc": "曲水流觞，诗友同席。选词、合律、押韵，以一行诗句叩开新的旅程。"},
	{"id": "ch6", "name": "大雁塔", "sub": "第六章 · 登塔", "pos": Vector2(775, 590), "play": "第一人称 3D · 七层演出", "tex": "pagoda", "desc": "循木阶穿过七层塔影，在长安灯火、扫描回声与镜中低语之间，走近最后一片。"},
	{"id": "ch7", "name": "塔顶", "sub": "第七章 · 月下", "pos": Vector2(870, 432), "play": "弹幕战斗 · 月相机关", "tex": "pagoda", "desc": "月色照过塔檐。以一路积累的见闻，在镜光交错之间面对最后的阻拦。"},
	{"id": "finale", "name": "回镜坊", "sub": "终章 · 金缮", "pos": Vector2(610, 470), "play": "拖拽旋转 · 拼合碎片", "tex": "workshop", "desc": "走过一城灯火，再回到镜坊。将四片青瓷拼合，让裂痕成为新的纹路。"},
]
const TRAVEL_CARD := Rect2(1110, 150, 278, 658)
var focus_i := 0


func enter() -> void:
	g.music("ambient")
	focus_i = next_index()


func next_index() -> int:
	for i in range(NODES.size()):
		if built(NODES[i]) and not g.cleared.has(NODES[i]["id"]):
			return i
	return NODES.size() - 1


func hint() -> String:
	return "下一站：" + str(NODES[next_index()]["name"]) + "。点击地点或右侧「启程」。"


func help_lines() -> Array:
	return ["鼠标移到地点可查看右侧风景与玩法；点击已开启的地点即可前往。", "方向键切换目的地，Enter 启程；完成章节后解锁下一站，已完成的章节可以重游。"]


func key(event: InputEventKey) -> bool:
	if event.keycode == KEY_F9:
		for n in NODES:
			if n["id"] != "finale":
				g.cleared[n["id"]] = true
		g.shards = [true, true, true, true]
		g.notify("验收模式：已解锁全部章节。")
		return true
	if event.keycode in [KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN]:
		focus_i = posmod(focus_i + (-1 if event.keycode in [KEY_LEFT, KEY_UP] else 1), NODES.size())
		return true
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		act("travel")
		return true
	return false


func mouse(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		for i in range(NODES.size()):
			if marker_rect(i).has_point(event.position) or label_rect(i).has_point(event.position):
				focus_i = i
				break
	return false


func built(n: Dictionary) -> bool:
	return g.SCENES.has(n["id"])


func unlocked(n: Dictionary) -> bool:
	if not built(n):
		return false
	var i := NODES.find(n)
	for j in range(i - 1, -1, -1):
		if built(NODES[j]):
			return g.cleared.has(NODES[j]["id"])
	return true


func act(id: String) -> void:
	if id == "back":
		g.go("title")
		return
	if id == "travel":
		id = str(NODES[focus_i]["id"])
	for n in NODES:
		if n["id"] == id and unlocked(n):
			g.go(id)


func label_rect(i: int) -> Rect2:
	return Rect2(NODES[i]["pos"] + Vector2(-87, 18), Vector2(174, 55))


func marker_rect(i: int) -> Rect2:
	return Rect2(NODES[i]["pos"] + Vector2(-54, -90), Vector2(108, 108))


func _draw() -> void:
	hit_regions.clear()
	if not _img_cover("paper", Rect2(0, 0, 1440, 900), Color(0.95, 0.91, 0.80)):
		draw_rect(Rect2(0, 0, 1440, 900), Color("d8c8a2"))
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.95, 0.91, 0.80, 0.32))
	for i in range(12):
		var a := 0.045 * pow(1.0 - i / 12.0, 2)
		draw_rect(Rect2(i * 6, i * 5, 1440 - i * 12, 900 - i * 10), Color(0.2, 0.12, 0.05, a), false, 10)
	draw_rect(Rect2(30, 26, 1380, 848), Color(MAP_INK, 0.25), false, 1)
	draw_rect(Rect2(36, 32, 1368, 836), Color(MAP_INK, 0.13), false, 1)
	_map_scenery()
	_draw_routes()
	for i in range(NODES.size()):
		_draw_destination(i)
	_draw_heading()
	_draw_destination_card()
	_button("back", Rect2(58, 830, 142, 38), "返回标题", false, 14)
	_draw_legend()


func _draw_heading() -> void:
	draw_rect(Rect2(58, 57, 3, 62), MAP_RED)
	_title(Vector2(78, 99), "长安舆图", 46, Color("423322"))
	_serif(Vector2(294, 96), "一城灯火，一路拾遗。", 21, MAP_INK)
	_t(Vector2(80, 127), "苏晴的行旅手记  /  循镜光，寻青瓷", 13, Color(MAP_INK, 0.8))
	draw_line(Vector2(80, 144), Vector2(1050, 144), Color(MAP_INK, 0.2), 1)
	var done := 0
	var total := 0
	for n in NODES:
		if built(n):
			total += 1
			if g.cleared.has(n["id"]):
				done += 1
	_t(Vector2(812, 96), "已访 %02d / %02d 处" % [done, total], 15, MAP_RED)
	var seal := Rect2(990, 65, 51, 51)
	draw_rect(seal, Color(MAP_RED, 0.9))
	draw_rect(seal.grow(-4), Color(0.95, 0.87, 0.65, 0.7), false, 1)
	_title_center(1016, 101, "行", 32, Color("eee0bd"))


func _draw_routes() -> void:
	var previous := -1
	for i in range(NODES.size()):
		if not built(NODES[i]):
			continue
		if previous >= 0:
			var a: Vector2 = NODES[previous]["pos"] + Vector2(0, 3)
			var b: Vector2 = NODES[i]["pos"] + Vector2(0, 3)
			var bend := Vector2(0, 48 if i in [3, 4] else -28)
			var c1 := a.lerp(b, 0.33) + bend
			var c2 := a.lerp(b, 0.67) + bend
			var traveled: bool = g.cleared.has(NODES[i]["id"])
			var available: bool = unlocked(NODES[i])
			var col := Color("637e69") if traveled else (MAP_RED if available else Color("8b7f68"))
			col.a = 0.78 if available else 0.30
			for step in range(64):
				if traveled or step % 4 < 2:
					var p := a.bezier_interpolate(c1, c2, b, step / 64.0)
					var q := a.bezier_interpolate(c1, c2, b, (step + 1) / 64.0)
					draw_line(p, q, Color(0.95, 0.88, 0.69, 0.60 if available else 0.12), 5, true)
					draw_line(p, q, col, 2.5, true)
			if available and not traveled:
				var p := a.bezier_interpolate(c1, c2, b, fposmod(age * 0.15, 1.0))
				draw_circle(p, 4, Color(MAP_RED, 0.8))
		previous = i


func _draw_destination(i: int) -> void:
	var n: Dictionary = NODES[i]
	var p: Vector2 = n["pos"]
	var ready := unlocked(n)
	var done: bool = g.cleared.has(n["id"])
	var current := i == next_index() and not done
	var focused := i == focus_i
	var alpha := 1.0 if ready else 0.50
	if current or focused:
		_map_ellipse(p + Vector2(0, -8), Vector2(68, 39), Color(0.92, 0.73, 0.39, 0.17 if ready else 0.08))
	if current:
		draw_arc(p + Vector2(0, -18), 49 + sin(age * 2) * 3, 0.15, TAU - 0.15, 64, Color(MAP_RED, 0.28), 1.4, true)
	_map_landmark(p, str(n["id"]), alpha)
	var r := label_rect(i)
	_box(r, Color(0.94, 0.88, 0.73, 0.95 if focused else 0.88), 2, Color(MAP_RED if ready else MAP_INK, 0.65 if focused else 0.24))
	draw_rect(Rect2(r.position, Vector2(3, r.size.y)), MAP_RED if current else Color(MAP_JADE if done else MAP_INK, 0.4))
	_title_center(r.get_center().x, r.position.y + 26, str(n["name"]), 25, Color("443421") if ready else Color("827764"))
	_t(r.position + Vector2(15, 45), str(n["sub"]), 12, MAP_RED if ready else Color("857a65"))
	var status := "已访" if done else ("此行" if current else ("待启" if built(n) else "未开放"))
	_t(Vector2(r.end.x - _tw(status, 11) - 10, r.position.y + 45), status, 11, MAP_JADE if done else MAP_RED if current else Color("897e6b"))
	if ready:
		_register(str(n["id"]), marker_rect(i))
		_register(str(n["id"]), r)


func _draw_destination_card() -> void:
	var n: Dictionary = NODES[focus_i]
	var ready := unlocked(n)
	var done: bool = g.cleared.has(n["id"])
	_panel(TRAVEL_CARD)
	var pic := Rect2(TRAVEL_CARD.position + Vector2(13, 13), Vector2(252, 157))
	_img_cover(str(n["tex"]), pic, Color.WHITE if ready else Color(0.7, 0.72, 0.65))
	draw_rect(pic, Color(0.01, 0.03, 0.03, 0.15))
	draw_rect(pic, Color(Pal.GOLD, 0.5), false, 1)
	_t(Vector2(1140, 347), "目的地  /  %02d" % (focus_i + 1), 12, Pal.GOLD)
	_title(Vector2(1138, 392), str(n["name"]), 37, Pal.PAPER)
	_serif(Vector2(1140, 423), str(n["sub"]), 18, Pal.GOLD)
	draw_line(Vector2(1140, 444), Vector2(1358, 444), Color(Pal.GOLD, 0.3), 1)
	_serif_wrap(Vector2(1140, 477), str(n["desc"]), 216, 18, Pal.PAPER, 31)
	_t(Vector2(1140, 605), "此处玩法", 13, Pal.GOLD)
	_wrap(Vector2(1140, 630), str(n["play"]), 216, 15, Pal.SOFT, 25)
	var caption := "重游此地  ›" if done else "启程  ›"
	if not ready:
		caption = "待前章完成" if built(n) else "尚未开放"
	_button("travel", Rect2(1138, 681, 222, 45), caption, true, 17, ready)
	_t(Vector2(1140, 753), "青瓷残片  %d / 4" % g.shard_count(), 14, Pal.GOLD)
	_shard_slots(Vector2(1140, 765), 25)


func _draw_legend() -> void:
	var labels := ["已访 · 可重游", "此行 · 可前往", "待启 · 循序解锁"]
	var colors := [MAP_JADE, MAP_RED, Color("928773")]
	for i in range(3):
		var p := Vector2(310 + i * 205, 848)
		draw_circle(p, 4, colors[i])
		_t(p + Vector2(14, 5), labels[i], 13, MAP_INK)
	_t(Vector2(1125, 850), "移至地点预览 · 点击启程", 12, MAP_INK)


