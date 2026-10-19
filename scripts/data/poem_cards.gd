extends RefCounted
## Data for chapter 5 · 曲江诗牌 (a deck-building poetry contest).
## A played line follows the Tang rhythm 2 + 2 + 1 (五言) or 2 + 2 + 2 + 1 (七言):
## two or three WORD cards (two syllables each) and one FOOT card (the final, rhyming syllable).
##   p   = tones of the syllables, "P" 平 / "Z" 仄, by Middle Chinese as used in Tang verse.
##         入声 syllables (月 白 落 曲 得 一 寂 寞 雪 …) are 仄 even though most are level today.
##   tag = imagery the card carries; charms react to these.
##   pos = part of speech for 对仗: n noun, v verb, a descriptive.
##   v   = base 墨 (points) the card adds to a line.
## Feet: r = 平水韵 rhyme group. 仄 feet never count as 押韵 (Tang regulated verse rhymes on 平).

const WORDS := [
	{"w": "春风", "p": "PP", "tag": ["春", "风"], "pos": "n", "v": 8},
	{"w": "杏花", "p": "ZP", "tag": ["春", "花"], "pos": "n", "v": 8},
	{"w": "垂柳", "p": "PZ", "tag": ["春", "柳"], "pos": "n", "v": 7},
	{"w": "曲江", "p": "ZP", "tag": ["水", "曲江"], "pos": "n", "v": 9},
	{"w": "流水", "p": "PZ", "tag": ["水"], "pos": "n", "v": 7},
	{"w": "明月", "p": "PZ", "tag": ["月"], "pos": "n", "v": 8},
	{"w": "清光", "p": "PP", "tag": ["月"], "pos": "n", "v": 7},
	{"w": "落日", "p": "ZZ", "tag": ["日"], "pos": "n", "v": 7},
	{"w": "青山", "p": "PP", "tag": ["山"], "pos": "n", "v": 7},
	{"w": "白云", "p": "ZP", "tag": ["云"], "pos": "n", "v": 7},
	{"w": "芳草", "p": "PZ", "tag": ["春"], "pos": "n", "v": 6},
	{"w": "飞花", "p": "PP", "tag": ["春", "花"], "pos": "n", "v": 8},
	{"w": "烟波", "p": "PP", "tag": ["水"], "pos": "n", "v": 7},
	{"w": "孤舟", "p": "PP", "tag": ["水"], "pos": "n", "v": 7},
	{"w": "雁塔", "p": "ZZ", "tag": ["功名", "曲江"], "pos": "n", "v": 10},
	{"w": "金榜", "p": "PZ", "tag": ["功名"], "pos": "n", "v": 9},
	{"w": "题名", "p": "PP", "tag": ["功名"], "pos": "v", "v": 9},
	{"w": "得意", "p": "ZZ", "tag": ["功名"], "pos": "a", "v": 8},
	{"w": "少年", "p": "ZP", "tag": ["人"], "pos": "n", "v": 8},
	{"w": "故人", "p": "ZP", "tag": ["人"], "pos": "n", "v": 7},
	{"w": "知己", "p": "PZ", "tag": ["人"], "pos": "n", "v": 7},
	{"w": "美酒", "p": "ZZ", "tag": ["酒"], "pos": "n", "v": 8},
	{"w": "金杯", "p": "PP", "tag": ["酒"], "pos": "n", "v": 8},
	{"w": "长安", "p": "PP", "tag": ["长安"], "pos": "n", "v": 9},
	{"w": "马蹄", "p": "ZP", "tag": ["功名"], "pos": "n", "v": 8},
	{"w": "归去", "p": "PZ", "tag": [], "pos": "v", "v": 6},
	{"w": "相逢", "p": "PP", "tag": ["人"], "pos": "v", "v": 7},
	{"w": "醉卧", "p": "ZZ", "tag": ["酒"], "pos": "v", "v": 7},
	{"w": "回首", "p": "PZ", "tag": [], "pos": "v", "v": 6},
	{"w": "初晴", "p": "PP", "tag": ["春"], "pos": "a", "v": 6},
	{"w": "千里", "p": "PZ", "tag": [], "pos": "a", "v": 6},
	{"w": "一夜", "p": "ZZ", "tag": ["月"], "pos": "a", "v": 6},
	{"w": "无边", "p": "PP", "tag": [], "pos": "a", "v": 6},
	{"w": "青青", "p": "PP", "tag": ["春"], "pos": "a", "v": 6},
	{"w": "寂寞", "p": "ZZ", "tag": [], "pos": "a", "v": 6},
	{"w": "万家", "p": "ZP", "tag": ["长安"], "pos": "a", "v": 6},
]

const FEET := [
	{"w": "花", "p": "P", "r": "麻", "tag": ["春", "花"], "v": 5},
	{"w": "家", "p": "P", "r": "麻", "tag": [], "v": 4},
	{"w": "霞", "p": "P", "r": "麻", "tag": [], "v": 4},
	{"w": "斜", "p": "P", "r": "麻", "tag": ["日"], "v": 4},
	{"w": "春", "p": "P", "r": "真", "tag": ["春"], "v": 5},
	{"w": "人", "p": "P", "r": "真", "tag": ["人"], "v": 4},
	{"w": "新", "p": "P", "r": "真", "tag": ["功名"], "v": 4},
	{"w": "尘", "p": "P", "r": "真", "tag": [], "v": 4},
	{"w": "天", "p": "P", "r": "先", "tag": [], "v": 4},
	{"w": "年", "p": "P", "r": "先", "tag": ["功名"], "v": 5},
	{"w": "烟", "p": "P", "r": "先", "tag": ["水"], "v": 4},
	{"w": "船", "p": "P", "r": "先", "tag": ["水"], "v": 4},
	{"w": "月", "p": "Z", "r": "", "tag": ["月"], "v": 6},
	{"w": "酒", "p": "Z", "r": "", "tag": ["酒"], "v": 6},
	{"w": "柳", "p": "Z", "r": "", "tag": ["春", "柳"], "v": 5},
	{"w": "雪", "p": "Z", "r": "", "tag": [], "v": 5},
]

## Charms (诗友 / 典故). kind decides the effect in ch5_qujiang.gd score_line().
##   add_mult_tag:  +n 韵 for each card carrying tag
##   add_chips_tag: +n 墨 for each card carrying tag
##   xmult_tag:     ×n 韵 if any card carries tag
##   xmult_both:    ×n 韵 if the line has both tags
##   xmult_seven:   ×n 韵 for 七言 lines
##   couplet_plus:  +n 韵 on top of the 对仗 bonus
##   extra_discard / extra_play: round resources
const CHARMS := {
	"libai": {"name": "酒仙", "who": "李白", "kind": "add_mult_tag", "tag": "酒", "n": 3, "cost": 4,
		"desc": "句中每张「酒」+3 韵。", "lore": "杜甫《饮中八仙歌》：「李白斗酒诗百篇」。"},
	"moon": {"name": "月下独酌", "who": "李白", "kind": "xmult_tag", "tag": "月", "n": 1.5, "cost": 5,
		"desc": "句中有「月」，韵 ×1.5。", "lore": "「举杯邀明月，对影成三人。」"},
	"mengjiao": {"name": "春风得意", "who": "孟郊", "kind": "xmult_both", "tag": "春", "tag2": "功名", "n": 2.0, "cost": 6,
		"desc": "句中同时有「春」与「功名」，韵 ×2。", "lore": "孟郊《登科后》：「春风得意马蹄疾，一日看尽长安花。」"},
	"qujiang": {"name": "曲江流饮", "who": "曲江", "kind": "add_chips_tag", "tag": "水", "n": 12, "cost": 4,
		"desc": "句中每张「水」+12 墨。", "lore": "曲江池是唐长安城东南的游赏胜地，新科进士常在此宴集。"},
	"timing": {"name": "雁塔题名", "who": "进士", "kind": "add_mult_tag", "tag": "功名", "n": 2, "cost": 5,
		"desc": "句中每张「功名」+2 韵。", "lore": "唐代新科进士在慈恩寺塔下题名留念，后世称为「雁塔题名」。"},
	"xingyuan": {"name": "杏园探花", "who": "进士", "kind": "add_chips_tag", "tag": "花", "n": 15, "cost": 4,
		"desc": "句中每张「花」+15 墨。", "lore": "进士及第后有杏园宴，选年少者为「探花使」遍游名园采花。"},
	"jiadao": {"name": "推敲", "who": "贾岛", "kind": "extra_discard", "n": 2, "cost": 4,
		"desc": "每巡多 2 次换字。", "lore": "贾岛「僧推月下门」改「敲」字未定，在驴背上做推敲的手势。"},
	"duilian": {"name": "对仗工稳", "who": "律诗", "kind": "couplet_plus", "n": 4, "cost": 5,
		"desc": "对仗时再 +4 韵。", "lore": "律诗中间两联要求对仗：词性相当，平仄相对。"},
	"qiyan": {"name": "七言长句", "who": "律诗", "kind": "xmult_seven", "n": 1.5, "cost": 5,
		"desc": "七言句韵 ×1.5。", "lore": "七言句一般按 2+2+2+1 断读，比五言多一组双音词。"},
	"jinshi": {"name": "新科进士", "who": "白居易", "kind": "extra_play", "n": 1, "cost": 6,
		"desc": "每巡多吟 1 句。", "lore": "白居易贞元十六年（800 年）进士及第，时年二十九岁（虚岁）。"},
}

## Three rounds of 酒令. rhyme = the rhyme group set for the round (限韵).
## ban = boss rule: cards carrying this tag score no 墨.
const ROUNDS := [
	{"name": "第一巡 · 曲水流觞", "rhyme": "麻", "target": 600, "plays": 4, "discards": 3, "host": "bai",
		"rule": "限「麻」韵：以 花 家 霞 斜 收尾，可得押韵。"},
	{"name": "第二巡 · 杏园春宴", "rhyme": "真", "target": 1200, "plays": 4, "discards": 3, "host": "bai",
		"rule": "限「真」韵：以 春 人 新 尘 收尾，可得押韵。"},
	{"name": "第三巡 · 郑公子出令", "rhyme": "先", "target": 1900, "plays": 4, "discards": 3, "host": "zheng", "ban": "春",
		"rule": "限「先」韵；郑公子令：本巡带「春」的牌不计墨。"},
]

const HAND_WORDS := 6
const HAND_FEET := 3
## Opening deck (by card text). Each round rhyme has three matching feet in it.
const START_WORDS := ["春风", "杏花", "垂柳", "曲江", "流水", "明月", "清光", "落日", "青山", "白云",
	"芳草", "烟波", "金榜", "题名", "少年", "故人", "美酒", "长安", "马蹄", "相逢", "归去", "千里", "无边", "醉卧"]
const START_FEET := ["花", "家", "斜", "春", "人", "新", "天", "年", "烟", "月", "酒", "柳"]
