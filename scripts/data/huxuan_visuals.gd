extends RefCounted
## Visual direction only. Song timing and judgement remain in huxuan_chart.gd.

const LOOKS := [
	{"name": "散序", "caption": "灯下起势 · 舒袖听鼓", "ink": Color("b9d4ca"), "light": Color("dfb776"), "turn_beats": 8.0, "ribbon": 0.24},
	{"name": "中序", "caption": "踏节回旋 · 衣带生风", "ink": Color("f0cb83"), "light": Color("f4ba67"), "turn_beats": 4.0, "ribbon": 0.60},
	{"name": "入破", "caption": "急鼓催舞 · 回雪流风", "ink": Color("ffdd9e"), "light": Color("ffb36d"), "turn_beats": 2.0, "ribbon": 1.0},
]
const OPENING := [0, 1, 0, 7]


static func movement(seconds: float, section: int, bpm: float, start: float, combo: int) -> Dictionary:
	var beat := maxf(0.0, seconds - start) * bpm / 60.0
	var sequence: Array = OPENING if section == 0 else [0, 1, 2, 3, 4, 5, 6, 7]
	var cursor := beat * (0.5 if section == 0 else 8.0 / float(LOOKS[section]["turn_beats"]))
	var index := int(floor(cursor)) % sequence.size()
	var fraction := fposmod(cursor, 1.0)
	return {
		"frame": sequence[index], "next": sequence[(index + 1) % sequence.size()],
		"blend": smoothstep(0.74, 1.0, fraction), "beat": beat,
		"pulse": pow(1.0 - fposmod(beat, 1.0), 3.0),
		"strength": float(LOOKS[section]["ribbon"]) * (0.70 + minf(combo / 45.0, 0.30)),
		"sway": sin(beat * PI * 0.5) * (0.018 if section == 0 else 0.012),
		"step": sin(beat * TAU) * (2.0 if section == 0 else 4.0),
	}
