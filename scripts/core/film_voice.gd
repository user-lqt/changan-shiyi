extends RefCounted
## Spoken lines use the video clock; skipping cancels their shared audio player.
const CUES := {
	"echo": [
		{"at": 3.8, "until": 9.9, "w": "boss", "t": "……光。是你带来的光。"},
	],
	"reveal": [
		{"at": 5.4, "until": 12.0, "w": "boss", "t": "……别把那束光带走。"},
	],
	"memory": [
		{"at": 7.5, "until": 14.5, "w": "boss", "t": "去吧。替我看看千年以后的月亮。"},
	],
}

var g
var cues: Array = []
var fired := {}
var active := false
var owned_voice := false
var time := 0.0


func start(game, id: String) -> void:
	stop()
	g = game
	g.stop_voice()
	cues = CUES.get(id, [])
	fired.clear()
	time = 0.0
	active = true


func update(position: float) -> void:
	if not active:
		return
	time = position
	for i in range(cues.size()):
		var cue: Dictionary = cues[i]
		if time >= float(cue["at"]) and not fired.has(i):
			fired[i] = true
			if time < float(cue["until"]):
				g.voice(cue["w"], cue["t"])
				owned_voice = true
	if owned_voice and caption().is_empty():
		g.stop_voice()
		owned_voice = false


func caption() -> String:
	if active:
		for cue in cues:
			if time >= float(cue["at"]) and time < float(cue["until"]):
				return "「%s」" % cue["t"]
	return ""


func stop() -> void:
	if active and owned_voice and is_instance_valid(g):
		g.stop_voice()
	active = false
	owned_voice = false
