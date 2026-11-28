extends RefCounted
## شخصیت‌های هوشمند مستقل (پروتکل ۵۴، مرحلهٔ ۱): ویژگی‌ها و پنج تیپ اولیه.
## ویژگی‌ها عددی بین ۰ و ۱ هستند و در امتیازدهی هدف‌ها و برنامه‌ها اثر واقعی دارند (char_ai.gd).

const FWConst = preload("res://scripts/core/const.gd")

const TRAIT_KEYS := ["bravery", "caution", "ambition", "trust", "aggression", "cooperation", "selfishness", "risk"]

## build: وزن علاقهٔ تیپ به هر ساختمان؛ life: هدف اصلی زندگی (در مراحل بعد برای قلمرو/اتحاد/جنگ به کار می‌رود).
const ARCHETYPES := {
	"schemer": {
		"traits": {"bravery": 0.5, "caution": 0.6, "ambition": 0.95, "trust": 0.2, "aggression": 0.6, "cooperation": 0.3, "selfishness": 0.85, "risk": 0.6},
		"build": {"house": 0.9, "shop": 0.8, "farm": 0.5, "coop": 0.4, "well": 0.3},
		"life": "expand", "names": ["آرمان", "شهرام", "کیوان"],
	},
	"rival": {
		"traits": {"bravery": 0.6, "caution": 0.5, "ambition": 0.85, "trust": 0.5, "aggression": 0.35, "cooperation": 0.5, "selfishness": 0.5, "risk": 0.5},
		"build": {"farm": 1.0, "house": 0.9, "coop": 0.8, "shop": 0.7, "well": 0.4},
		"life": "best_city", "names": ["بهار", "نیلوفر", "پارسا"],
	},
	"mystery": {
		"traits": {"bravery": 0.4, "caution": 0.9, "ambition": 0.5, "trust": 0.3, "aggression": 0.3, "cooperation": 0.4, "selfishness": 0.6, "risk": 0.4},
		"build": {"house": 0.9, "well": 0.8, "farm": 0.4, "coop": 0.3, "shop": 0.2},
		"life": "secrecy", "names": ["آذر", "سایه", "رها"],
	},
	"trader": {
		"traits": {"bravery": 0.3, "caution": 0.5, "ambition": 0.6, "trust": 0.5, "aggression": 0.1, "cooperation": 0.7, "selfishness": 0.7, "risk": 0.6},
		"build": {"shop": 1.0, "house": 0.8, "coop": 0.6, "farm": 0.5, "well": 0.2},
		"life": "wealth", "names": ["سعید", "مهتاب", "کامیار"],
	},
	"warlord": {
		"traits": {"bravery": 0.95, "caution": 0.2, "ambition": 0.8, "trust": 0.4, "aggression": 0.95, "cooperation": 0.3, "selfishness": 0.6, "risk": 0.8},
		"build": {"house": 0.9, "farm": 0.7, "coop": 0.6, "well": 0.5, "shop": 0.3},
		"life": "dominion", "names": ["کاوه", "اسفندیار", "گرشاسب"],
	},
}
const ORDER := ["schemer", "rival", "mystery", "trader", "warlord"]


static func valid(arch: String) -> bool:
	return ARCHETYPES.has(arch)


## ویژگی‌های پایهٔ تیپ با انحراف کوچک و قطعی از شناسه (دو شخصیت هم‌تیپ دقیقاً یکسان نیستند).
static func traits_for(arch: String, npc_id: int) -> Dictionary:
	var base: Dictionary = ARCHETYPES[arch]["traits"]
	var out := {}
	var i := 0
	for k in TRAIT_KEYS:
		var jitter: float = (float(((npc_id * 37 + i * 11) % 7)) - 3.0) * 0.02
		out[k] = clampf(float(base[k]) + jitter, 0.0, 1.0)
		i += 1
	return out


static func clean_traits(d: Variant, arch: String, npc_id: int) -> Dictionary:
	var out: Dictionary = traits_for(arch, npc_id)
	if d is Dictionary:
		for k in TRAIT_KEYS:
			if d.has(k):
				out[k] = clampf(float(d[k]), 0.0, 1.0)
	return out


static func build_weight(arch: String, type: String) -> float:
	return float(ARCHETYPES[arch]["build"].get(type, 0.0))


static func pick_name(arch: String, npc_id: int) -> String:
	var names: Array = ARCHETYPES[arch]["names"]
	return str(names[npc_id % names.size()])
