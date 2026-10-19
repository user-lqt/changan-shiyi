extends RefCounted
## Pure scoring rules for chapter 5 (曲江诗牌). No nodes, no drawing, so tests can call it directly.
## A line = 2 or 3 word cards followed by exactly one foot card (五言 2+2+1, 七言 2+2+2+1).
## Score = 墨 (chips) × 韵 (mult), like a poker hand in Balatro, with Tang-verse "hands":
##   合律  the tones alternate the way a regulated line must (see tone_ok)
##   押韵  the foot is 平 and in the round's rhyme group
##   对仗  this line mirrors the previous line: same length, same parts of speech, opposite tones
##   意象  two or more cards share an image tag
## Charms then add 墨 / 韵 or multiply 韵.

const Cards = preload("res://scripts/data/poem_cards.gd")

const BASE_MULT := 1.0
const LU_MULT := 3.0        # 合律
const RHYME_MULT := 3.0     # 押韵
const PAIR_MULT := 4.0      # 对仗
const IMAGE_CHIPS := 10     # per extra card sharing the most common tag
const SEVEN_CHIPS := 15     # a 七言 line is longer, so it carries more ink


## Tone string of a line, one letter per syllable ("PZ…").
static func tones(cards: Array) -> String:
	var s := ""
	for c in cards:
		s += str(c["p"])
	return s


## The two Tang rules every regulated line keeps:
##  · 二四六分明: syllables 2, 4 (and 6 in 七言) alternate 平 / 仄.
##  · 忌三平尾 / 三仄尾: the last three syllables are not all the same tone.
## (Syllables 1, 3, 5 are free — "一三五不论" — so they are not checked.)
static func tone_ok(cards: Array) -> bool:
	var t := tones(cards)
	if t.length() != 5 and t.length() != 7:
		return false
	var keys := [1, 3] if t.length() == 5 else [1, 3, 5]
	for i in range(keys.size() - 1):
		if t[keys[i]] == t[keys[i + 1]]:
			return false
	var tail := t.right(3)
	return tail != "PPP" and tail != "ZZZ"


static func is_line(cards: Array) -> bool:
	if cards.size() != 3 and cards.size() != 4:
		return false
	for i in range(cards.size() - 1):
		if cards[i].has("r"):
			return false            # feet only at the end
	return cards[-1].has("r")


static func rhymes(cards: Array, rhyme: String) -> bool:
	var foot: Dictionary = cards[-1]
	return foot["p"] == "P" and foot["r"] == rhyme


## 对仗 with the previous line: same length, word cards match part of speech position by
## position, and the tones at every even syllable are opposite.
static func paired(cards: Array, prev: Array) -> bool:
	if prev.is_empty() or prev.size() != cards.size():
		return false
	for i in range(cards.size() - 1):
		if cards[i]["pos"] != prev[i]["pos"] or cards[i]["w"] == prev[i]["w"]:
			return false
	var a := tones(cards)
	var b := tones(prev)
	for i in range(1, a.length(), 2):
		if a[i] == b[i]:
			return false
	return true


## Most shared image tag and how many cards carry it.
static func top_tag(cards: Array) -> Array:
	var count := {}
	for c in cards:
		for t in c["tag"]:
			count[t] = int(count.get(t, 0)) + 1
	var best := ""
	var n := 0
	for t in count:
		if count[t] > n:
			best = t
			n = count[t]
	return [best, n]


static func has_tag(cards: Array, tag: String) -> bool:
	for c in cards:
		if c["tag"].has(tag):
			return true
	return false


static func count_tag(cards: Array, tag: String) -> int:
	var n := 0
	for c in cards:
		if c["tag"].has(tag):
			n += 1
	return n


## Full score breakdown. charms = Array of charm ids; rnd = Cards.ROUNDS entry.
## Returns {ok, chips, mult, total, steps: [[label, text]], lu, rhyme, pair, seven}.
static func score_line(cards: Array, prev: Array, charms: Array, rnd: Dictionary) -> Dictionary:
	var out := {"ok": false, "chips": 0, "mult": 0.0, "total": 0, "steps": [], "lu": false, "rhyme": false, "pair": false, "seven": false}
	if not is_line(cards):
		return out
	out["ok"] = true
	var ban: String = rnd.get("ban", "")
	var chips := 0
	for c in cards:
		if ban.is_empty() or not c["tag"].has(ban):
			chips += int(c["v"])
	out["steps"].append(["字", "%d 墨" % chips])
	var seven := cards.size() == 4
	out["seven"] = seven
	if seven:
		chips += SEVEN_CHIPS
		out["steps"].append(["七言", "+%d 墨" % SEVEN_CHIPS])
	var tt := top_tag(cards)
	if int(tt[1]) >= 2:
		var bonus: int = IMAGE_CHIPS * (int(tt[1]) - 1)
		chips += bonus
		out["steps"].append(["意象 · " + str(tt[0]), "+%d 墨" % bonus])
	var mult := BASE_MULT
	if tone_ok(cards):
		mult += LU_MULT
		out["lu"] = true
		out["steps"].append(["合律", "+%d 韵" % int(LU_MULT)])
	if rhymes(cards, rnd["rhyme"]):
		mult += RHYME_MULT
		out["rhyme"] = true
		out["steps"].append(["押韵 · " + str(rnd["rhyme"]), "+%d 韵" % int(RHYME_MULT)])
	if paired(cards, prev):
		mult += PAIR_MULT
		out["pair"] = true
		out["steps"].append(["对仗", "+%d 韵" % int(PAIR_MULT)])
	# Additive charms first, multiplicative ones last (order matters, as in Balatro).
	var xs := []
	for id in charms:
		var ch: Dictionary = Cards.CHARMS[id]
		var label := "%s · %s" % [ch["who"], ch["name"]]
		match ch["kind"]:
			"add_mult_tag":
				var n := count_tag(cards, ch["tag"])
				if n > 0:
					mult += n * float(ch["n"])
					out["steps"].append([label, "+%d 韵" % int(n * float(ch["n"]))])
			"add_chips_tag":
				var n := count_tag(cards, ch["tag"])
				if n > 0:
					chips += n * int(ch["n"])
					out["steps"].append([label, "+%d 墨" % (n * int(ch["n"]))])
			"couplet_plus":
				if out["pair"]:
					mult += float(ch["n"])
					out["steps"].append([label, "+%d 韵" % int(ch["n"])])
			"xmult_tag":
				if has_tag(cards, ch["tag"]):
					xs.append([label, float(ch["n"])])
			"xmult_both":
				if has_tag(cards, ch["tag"]) and has_tag(cards, ch["tag2"]):
					xs.append([label, float(ch["n"])])
			"xmult_seven":
				if seven:
					xs.append([label, float(ch["n"])])
	for x in xs:
		mult *= float(x[1])
		out["steps"].append([x[0], "×%s 韵" % str(x[1])])
	out["chips"] = chips
	out["mult"] = mult
	out["total"] = int(round(chips * mult))
	return out


## Text of a line as it would be read, e.g. 春风杏花花.
static func text(cards: Array) -> String:
	var s := ""
	for c in cards:
		s += str(c["w"])
	return s


static func word(w: String) -> Dictionary:
	for c in Cards.WORDS:
		if c["w"] == w:
			return c
	return {}


static func foot(w: String) -> Dictionary:
	for c in Cards.FEET:
		if c["w"] == w:
			return c
	return {}
