extends "res://scripts/core/canvas.gd"
## Reusable ink-and-colour city scenery, drawn below the interactive travel markers.

const MAP_INK := Color("594a36")
const MAP_RED := Color("994b38")
const MAP_JADE := Color("6b8471")


func _map_ellipse(p: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(40):
		var a := i * TAU / 40.0
		points.append(p + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(points, color)


func _map_roof(p: Vector2, width: float, height: float, color: Color) -> void:
	var points := PackedVector2Array([
		p + Vector2(-width * 0.62, 2), p + Vector2(-width * 0.43, -height * 0.28),
		p + Vector2(-width * 0.26, -height), p + Vector2(width * 0.26, -height),
		p + Vector2(width * 0.43, -height * 0.28), p + Vector2(width * 0.62, 2),
		p + Vector2(width * 0.39, height * 0.12), p + Vector2(-width * 0.39, height * 0.12),
	])
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Color(MAP_INK, color.a * 0.75), 1.0, true)
	for i in range(-3, 4):
		draw_line(p + Vector2(i * width * 0.075, -height * 0.85), p + Vector2(i * width * 0.13, 0), Color(0.95, 0.89, 0.71, color.a * 0.35), 1.0, true)
	draw_line(p + Vector2(-width * 0.29, -height - 2), p + Vector2(width * 0.29, -height - 2), Color(MAP_INK, color.a), 2.0, true)


func _map_house(p: Vector2, width: float, height: float, roof: Color, alpha := 1.0) -> void:
	_map_ellipse(p + Vector2(3, 5), Vector2(width * 0.65, 6), Color(MAP_INK, alpha * 0.12))
	var body := Rect2(p + Vector2(-width * 0.43, -height), Vector2(width * 0.86, height))
	draw_rect(body, Color(0.81, 0.69, 0.49, alpha))
	draw_rect(body, Color(MAP_INK, alpha * 0.65), false, 1.0)
	for side in [-1, 1]:
		draw_line(p + Vector2(side * width * 0.30, -height), p + Vector2(side * width * 0.30, 0), Color(MAP_RED, alpha * 0.9), maxf(1.0, width * 0.035))
	draw_rect(Rect2(p + Vector2(-width * 0.09, -height * 0.67), Vector2(width * 0.18, height * 0.67)), Color(MAP_INK, alpha * 0.8))
	_map_roof(p + Vector2(0, -height), width, height * 0.68, Color(roof, alpha))


func _map_tree(p: Vector2, size: float, alpha := 0.5) -> void:
	draw_line(p, p + Vector2(0, -size * 1.5), Color(MAP_INK, alpha), 1.5)
	for i in range(4):
		var a := i * 2.4
		draw_circle(p + Vector2(cos(a) * size * 0.5, -size + sin(a) * size * 0.4), size * 0.66, Color(MAP_JADE, alpha * 0.5))
		draw_arc(p + Vector2(cos(a) * size * 0.5, -size + sin(a) * size * 0.4), size * 0.66, 0.2, 2.5, 8, Color(MAP_INK, alpha * 0.25), 0.7, true)


func _map_scenery() -> void:
	# The city is read as north/south avenues, enclosed wards, gardens and water.
	_map_ellipse(Vector2(584, 490), Vector2(522, 298), Color(0.60, 0.52, 0.35, 0.05))
	var city := Rect2(104, 234, 938, 540)
	draw_rect(city, Color(0.79, 0.73, 0.56, 0.16))
	for row in range(4):
		for col in range(7):
			var r := Rect2(120 + col * 130, 306 + row * 112, 111, 94)
			if (row >= 2 and col >= 5) or col == 3:
				continue
			draw_rect(r, Color(0.55, 0.58, 0.42, 0.055 if (row + col) % 2 else 0.10))
			draw_rect(r.grow(-3), Color(MAP_INK, 0.18), false, 0.8)
			for j in range(3):
				var at := r.position + Vector2(24 + j * 29, 30 + (col * 7 + row * 11 + j * 13) % 35)
				_map_house(at, 23 + j % 2 * 6, 8, Color("858879"), 0.28)
			_map_tree(r.position + Vector2(88, 80), 8, 0.35)
	# Ceremonial avenues and the northern palace.
	draw_rect(Rect2(550, 289, 31, 490), Color("c9b68d"))
	draw_line(Vector2(550, 290), Vector2(550, 780), Color(MAP_INK, 0.30), 1)
	draw_line(Vector2(581, 290), Vector2(581, 780), Color(MAP_INK, 0.30), 1)
	for y in [300, 438, 551, 664]:
		draw_line(Vector2(106, y), Vector2(1038, y), Color(0.73, 0.64, 0.46, 0.48), 12)
		draw_line(Vector2(106, y - 7), Vector2(1038, y - 7), Color(MAP_INK, 0.16), 1)
	var palace := Rect2(411, 218, 310, 79)
	draw_rect(palace, Color(0.69, 0.47, 0.32, 0.15))
	draw_rect(palace, Color(MAP_RED, 0.55), false, 2)
	_map_house(Vector2(566, 257), 98, 25, Color("8f5942"), 0.85)
	_map_house(Vector2(454, 276), 43, 15, Color("88745c"), 0.65)
	_map_house(Vector2(677, 276), 43, 15, Color("88745c"), 0.65)
	_serif_center(566, 202, "宫 城", 18, MAP_INK)
	# Outer wall, crenellations and three gate houses.
	draw_rect(city.grow(5), Color(MAP_INK, 0.55), false, 6)
	draw_rect(city.grow(12), Color(MAP_INK, 0.23), false, 1)
	for x in range(112, 1035, 16):
		draw_line(Vector2(x, 225), Vector2(x + 7, 225), Color(MAP_INK, 0.58), 3)
		draw_line(Vector2(x, 782), Vector2(x + 7, 782), Color(MAP_INK, 0.58), 3)
	for y in range(243, 770, 16):
		draw_line(Vector2(95, y), Vector2(95, y + 7), Color(MAP_INK, 0.58), 3)
		draw_line(Vector2(1051, y), Vector2(1051, y + 7), Color(MAP_INK, 0.58), 3)
	_map_house(Vector2(566, 790), 66, 17, Color("8b7860"), 0.9)
	_map_house(Vector2(104, 440), 39, 18, Color("8b7860"), 0.75)
	_map_house(Vector2(1042, 440), 39, 18, Color("8b7860"), 0.75)
	_serif_center(566, 814, "明德门", 14, MAP_INK)
	for i in range(4):
		_serif_center(565, 366 + i * 26, "朱雀大街"[i], 16, Color(MAP_RED, 0.7))
	_serif(Vector2(712, 337), "东 市", 15, Color(MAP_INK, 0.55))
	_serif(Vector2(363, 703), "安 仁 坊", 13, Color(MAP_INK, 0.4))
	_serif(Vector2(655, 596), "晋 昌 坊", 13, Color(MAP_INK, 0.4))
	_map_water()
	for i in range(17):
		_map_tree(Vector2(755 + i * 17, 715 + sin(i * 1.4) * 37), 10 + i % 3 * 2, 0.46)
	for i in range(8):
		_map_tree(Vector2(158 + i * 23, 738 + sin(i * 2.0) * 9), 12, 0.35)
	# Low mountain contours outside the city; they stay behind navigation labels.
	for line in range(3):
		var points := PackedVector2Array()
		for i in range(52):
			points.append(Vector2(102 + i * 19, 170 + line * 9 - sin(i * 0.22) * 12 - sin(i * 0.7) * 5))
		draw_polyline(points, Color(MAP_INK, 0.09), 1, true)
	_map_compass(Vector2(1032, 184))


func _map_water() -> void:
	var bank := PackedVector2Array()
	for i in range(64):
		var a := i * TAU / 64.0
		var radius := 1.0 + sin(a * 3.0) * 0.08 + cos(a * 5.0) * 0.045
		bank.append(Vector2(931, 653) + Vector2(cos(a) * 135, sin(a) * 91) * radius)
	draw_colored_polygon(bank, Color("a3b2a0"))
	bank.append(bank[0])
	draw_polyline(bank, Color(MAP_JADE, 0.65), 2, true)
	for i in range(13):
		var y := 597 + i * 9.0
		var points := PackedVector2Array()
		for j in range(22):
			points.append(Vector2(868 + j * 6, y + sin(j * 0.35 + i) * 2))
		draw_polyline(points, Color(0.91, 0.88, 0.71, 0.55), 1, true)
	# A garden island and a moored boat.
	_map_ellipse(Vector2(997, 643), Vector2(33, 17), Color("bfc2a0"))
	_map_tree(Vector2(998, 640), 17, 0.65)
	var boat := PackedVector2Array([Vector2(847, 646), Vector2(874, 653), Vector2(895, 644), Vector2(865, 648)])
	draw_colored_polygon(boat, Color(MAP_INK, 0.60))
	draw_line(Vector2(870, 650), Vector2(870, 627), Color(MAP_INK, 0.7), 1.3)
	draw_colored_polygon(PackedVector2Array([Vector2(870, 628), Vector2(870, 644), Vector2(884, 642)]), Color(0.9, 0.82, 0.62, 0.9))


func _map_compass(p: Vector2) -> void:
	draw_arc(p, 22, 0, TAU, 40, Color(MAP_INK, 0.35), 1, true)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -20), p + Vector2(-6, 9), p, p + Vector2(6, 9)]), Color(MAP_RED, 0.8))
	_serif_center(p.x, p.y - 30, "北", 14, MAP_INK)


func _map_landmark(p: Vector2, kind: String, alpha: float) -> void:
	var key := "map_" + kind
	if g.tex.has(key):
		var t: Texture2D = g.tex[key]
		var height := 145.0 if kind == "ch6" else (96.0 if kind == "ch7" else 90.0)
		var dimensions := t.get_size() * minf(height / t.get_height(), 130.0 / t.get_width())
		draw_texture_rect(t, Rect2(p - Vector2(dimensions.x * 0.5, dimensions.y - 7), dimensions), false, Color(1, 1, 1, alpha))
		return
	match kind:
		"ch1":
			_map_house(p, 71, 34, Color("697f70"), alpha)
			draw_circle(p + Vector2(43, -35), 15, Color(0.80, 0.65, 0.35, alpha))
			draw_circle(p + Vector2(43, -35), 11, Color(0.73, 0.81, 0.69, alpha))
			draw_arc(p + Vector2(43, -35), 8, -2.8, -1.0, 16, Color(1, 0.94, 0.73, alpha), 2, true)
		"ch2":
			for i in range(3):
				var at := p + Vector2((i - 1) * 31, -7 - (12 if i == 1 else 0))
				_map_house(at, 29, 22, Color("9e6c4d") if i % 2 else Color("768777"), alpha)
				for j in range(3):
					draw_circle(at + Vector2((j - 1) * 7, -5), 3, Color(0.75, 0.41, 0.27, alpha))
		"ch3":
			_map_house(p, 65, 37, Color("966a4b"), alpha)
			_map_house(p + Vector2(0, -45), 48, 17, Color("787b67"), alpha)
			for side in [-1, 1]:
				var at := p + Vector2(side * 36, -25)
				draw_line(at + Vector2(0, -15), at + Vector2(0, 20), Color(MAP_INK, alpha), 1)
				_map_ellipse(at, Vector2(7, 10), Color(0.71, 0.30, 0.20, alpha))
				draw_line(at + Vector2(0, 10), at + Vector2(0, 17), Color(MAP_RED, alpha), 1)
		"ch4":
			for side in [-1, 1]:
				draw_rect(Rect2(p + Vector2(side * 27 - 7, -43), Vector2(14, 43)), Color(0.60, 0.49, 0.34, alpha))
			_map_roof(p + Vector2(0, -44), 85, 23, Color(0.42, 0.48, 0.43, alpha))
			draw_rect(Rect2(p + Vector2(-25, -36), Vector2(50, 7)), Color(MAP_RED, alpha))
			draw_line(p + Vector2(-7, -28), p + Vector2(-7, -2), Color(MAP_INK, alpha * 0.7), 1)
			draw_line(p + Vector2(7, -28), p + Vector2(7, -2), Color(MAP_INK, alpha * 0.7), 1)
		"ch5":
			draw_line(p + Vector2(-43, 4), p + Vector2(42, 4), Color(0.70, 0.57, 0.38, alpha), 8)
			_map_house(p + Vector2(0, -1), 50, 27, Color("728270"), alpha)
			for i in range(5):
				draw_line(p + Vector2(-40 + i * 20, 4), p + Vector2(-40 + i * 20, 16), Color(MAP_INK, alpha * 0.7), 2)
		"ch6":
			for i in range(7):
				var at := p + Vector2(0, -i * 17)
				var width := 49.0 - i * 4.0
				draw_rect(Rect2(at + Vector2(-width * 0.5, -17), Vector2(width, 17)), Color(0.77, 0.63, 0.43, alpha))
				draw_rect(Rect2(at + Vector2(-3, -13), Vector2(6, 9)), Color(MAP_INK, alpha * 0.65))
				_map_roof(at + Vector2(0, -17), width, 7, Color(0.48, 0.48, 0.39, alpha))
			draw_line(p + Vector2(0, -126), p + Vector2(0, -140), Color(MAP_INK, alpha), 2)
		"ch7":
			draw_circle(p + Vector2(0, -35), 25, Color(0.85, 0.68, 0.36, alpha * 0.8))
			draw_circle(p + Vector2(9, -42), 22, Color(0.82, 0.77, 0.62, alpha))
			for i in range(3):
				draw_arc(p + Vector2(i * 15 - 15, -10 + i % 2 * 4), 16, -PI, 0, 16, Color(MAP_INK, alpha * 0.5), 1.4, true)
		"finale":
			_map_house(p + Vector2(0, -10), 60, 31, Color("697f70"), alpha * 0.7)
			_map_ellipse(p + Vector2(0, -8), Vector2(24, 13), Color(0.43, 0.67, 0.59, alpha))
			draw_arc(p + Vector2(0, -14), 25, 0.1, PI - 0.1, 24, Color(MAP_INK, alpha * 0.8), 1.5, true)
			draw_polyline(PackedVector2Array([p + Vector2(-8, -19), p + Vector2(0, -12), p + Vector2(-3, 0)]), Color(0.92, 0.73, 0.36, alpha), 2, true)
