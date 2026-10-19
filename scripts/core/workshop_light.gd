extends Node2D
## Cached soft ribbons blend as light, with drifting dust rather than moving dotted lines.

const RIBBON = preload("res://assets/images/ch1_workshop/light-ribbon.png")
const HALO = preload("res://assets/images/ch1_workshop/light-halo.png")

var source := Vector2.ZERO
var mirror := Vector2.ZERO
var landing := Vector2.ZERO
var energy := 0.0
var clock := 0.0
var focused := false


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	visible = false


func illuminate(a: Vector2, b: Vector2, c: Vector2, brightness: float, time: float, aligned: bool) -> void:
	source = a
	mirror = b
	landing = c
	energy = brightness
	clock = time
	focused = aligned
	visible = energy > 0.001
	queue_redraw()


func _halo(p: Vector2, radius: Vector2, color: Color, tilt := 0.0) -> void:
	draw_set_transform(p, tilt)
	draw_texture_rect(HALO, Rect2(-radius, radius * 2.0), false, color)
	draw_set_transform(Vector2.ZERO)


func _shaft(a: Vector2, b: Vector2, strength: float) -> void:
	var ray := b - a
	var normal := ray.normalized().orthogonal()
	var flicker := 0.95 + sin(clock * 3.1) * sin(clock * 5.7) * 0.05
	draw_set_transform(a, ray.angle())
	draw_texture_rect(RIBBON, Rect2(0, -16, ray.length(), 32), false, Color(1, 0.82, 0.5, strength * 0.27 * flicker))
	draw_texture_rect(RIBBON, Rect2(0, -5, ray.length(), 10), false, Color(1, 0.91, 0.7, strength * 0.40 * flicker))
	draw_set_transform(Vector2.ZERO)
	# Individual particles drift through the illuminated air at different speeds.
	for i in range(31):
		var progress := fposmod(i * 0.61803 + clock * (0.009 + (i % 5) * 0.003), 1.0)
		var offset := sin(clock * (0.18 + i * 0.007) + i * 2.4) * (3.0 + i % 5 * 1.6)
		var p := a.lerp(b, progress) + normal * offset
		var fade := sin(progress * PI) * (0.35 + 0.65 * pow(0.5 + 0.5 * sin(clock * 0.8 + i * 2.3), 2.0))
		draw_circle(p, 0.4 + (i % 4) * 0.18, Color(1, 0.84, 0.57, fade * strength * 0.48))
		if i % 6 == 0:
			_halo(p, Vector2.ONE * 3.1, Color(1, 0.8, 0.4, fade * strength * 0.11))


func _draw() -> void:
	if energy <= 0.001:
		return
	_shaft(source, mirror, energy * 0.63)
	_shaft(mirror, landing, energy)
	_halo(source, Vector2(28, 44), Color(1, 0.56, 0.21, energy * 0.30))
	_halo(mirror, Vector2(25, 15), Color(1, 0.86, 0.58, energy * 0.45))
	var arrival := 0.25 + 0.14 * sin(clock * 2.1)
	_halo(landing, Vector2(29, 38) if focused else Vector2(18, 26), Color(1, 0.83, 0.48, energy * arrival))
	_halo(landing, Vector2(6, 9), Color(1, 0.94, 0.76, energy * 0.40))
