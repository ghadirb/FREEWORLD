extends RefCounted
## شخصیت‌های نام‌دار و «کتاب ماجراجویی». فقط داده و توابع خالص است؛ متن‌ها در Loc
## (کلیدهای book_<id>، book_<id>_d و dlg_<نقش>_*) و ارزیابی دستاوردها فقط در سرور (scripts/server/book.gd).
## هیچ دستاوردی اجباری نیست؛ جایزه‌ها کوچک‌اند و در جهان خلاقانه اصلاً سکه‌ای داده نمی‌شود.

const Scenarios = preload("res://scripts/shared/scenarios.gd")

## نقش‌ها (هرکدام پنج متن در Loc دارند: dlg_<نقش>_0..2 سلام بر اساس سطح دوستی، _hint و _done).
const ROLES := ["villager", "farmer", "baker", "guide", "hunter", "innkeeper", "nomad", "smith", "elder"]

## شخصیت‌های هر جهان به ترتیب NPC (شناسهٔ ۱، ۲، …): [نام، نقش]. بقیهٔ شهروندان «villager» هستند.
## جهانی که اینجا نیامده از فهرست پیش‌فرض ("") استفاده می‌کند. نام فقط هنگام ساخت جهان آماده گذاشته می‌شود.
const CASTS := {
	"": [["علی", "farmer"], ["مریم", "baker"], ["رضا", "guide"]],
	"medieval_fort": [["آرش", "smith"], ["سیمین", "elder"], ["پوریا", "guide"], ["بهرام", "farmer"]],
	"frozen_north": [["بهمن", "hunter"], ["شیرین", "innkeeper"], ["داراب", "elder"]],
	"desert_caravan": [["کاوه", "nomad"], ["گلنار", "innkeeper"], ["مهرداد", "smith"]],
}

## مأموریت‌های چندمرحلهٔ هر نقش (زنجیره‌ای، به ترتیب): تحویل کالا به همان NPC.
## need = حداقل سطح دوستی لازم (۰ آشنا، ۱ دوست، ۲ دوست صمیمی)؛ reward = سکه؛ bonus = [کالا، تعداد] فقط در مرحلهٔ آخر.
## هر مرحله ۱۲ امتیاز دوستی هم می‌دهد. در جهان خلاقانه کالا گرفته نمی‌شود و سکه‌ای داده نمی‌شود، ولی پیشرفت ثبت می‌شود.
const QUESTS := {
	"farmer": [
		{"item": "wood", "n": 20, "need": 0, "reward": 30},
		{"item": "stone", "n": 25, "need": 1, "reward": 60},
		{"item": "brick", "n": 15, "need": 2, "reward": 120, "bonus": ["gem", 1]},
	],
	"baker": [
		{"item": "wood", "n": 15, "need": 0, "reward": 25},
		{"item": "fish", "n": 6, "need": 1, "reward": 50},
		{"item": "glass", "n": 8, "need": 2, "reward": 110, "bonus": ["gold", 1]},
	],
	"guide": [
		{"item": "stone", "n": 20, "need": 0, "reward": 30},
		{"item": "brick", "n": 10, "need": 1, "reward": 60},
		{"item": "iron", "n": 6, "need": 2, "reward": 130, "bonus": ["gem", 1]},
	],
	"hunter": [
		{"item": "fish", "n": 8, "need": 0, "reward": 30},
		{"item": "coal", "n": 10, "need": 1, "reward": 60},
		{"item": "iron", "n": 8, "need": 2, "reward": 140, "bonus": ["gold", 1]},
	],
	"innkeeper": [
		{"item": "wood", "n": 30, "need": 0, "reward": 35},
		{"item": "fish", "n": 10, "need": 1, "reward": 60},
		{"item": "glass", "n": 10, "need": 2, "reward": 120, "bonus": ["gold", 1]},
	],
	"nomad": [
		{"item": "clay", "n": 20, "need": 0, "reward": 30},
		{"item": "sand", "n": 25, "need": 1, "reward": 60},
		{"item": "gold", "n": 2, "need": 2, "reward": 150, "bonus": ["gem", 1]},
	],
	"smith": [
		{"item": "coal", "n": 10, "need": 0, "reward": 35},
		{"item": "iron", "n": 5, "need": 1, "reward": 70},
		{"item": "gold", "n": 2, "need": 2, "reward": 160, "bonus": ["gem", 1]},
	],
	"elder": [
		{"item": "fish", "n": 5, "need": 0, "reward": 25},
		{"item": "brick", "n": 12, "need": 1, "reward": 60},
		{"item": "gem", "n": 1, "need": 2, "reward": 150, "bonus": ["gold", 2]},
	],
}
const QUEST_FRIEND_POINTS := 12

## دستاوردها به ترتیب نمایش. kind و پارامترهای a، b را book.gd معنا می‌کند.
## climate خالی = همهٔ جهان‌ها. giver = نقشی که دربارهٔ آن حرف می‌زند.
const ENTRIES := [
	{"id": "explorer_60", "kind": "dist", "a": 60, "b": 0, "reward": 15, "giver": "guide", "climate": ""},
	{"id": "explorer_200", "kind": "dist", "a": 200, "b": 0, "reward": 40, "giver": "guide", "climate": ""},
	{"id": "visit_village", "kind": "in_village", "a": 0, "b": 0, "reward": 20, "giver": "guide", "climate": ""},
	{"id": "road_maker", "kind": "blocks_of", "a": "road", "b": 20, "reward": 25, "giver": "guide", "climate": ""},
	{"id": "driver", "kind": "flag", "a": "car", "b": 0, "reward": 60, "giver": "guide", "climate": ""},
	{"id": "first_house", "kind": "owns", "a": "house", "b": 1, "reward": 30, "giver": "farmer", "climate": ""},
	{"id": "wheat_farm", "kind": "owns", "a": "farm", "b": 1, "reward": 30, "giver": "farmer", "climate": ""},
	{"id": "bakery_owner", "kind": "owns", "a": "bakery", "b": 1, "reward": 40, "giver": "baker", "climate": ""},
	{"id": "shop_owner", "kind": "owns", "a": "shop", "b": 1, "reward": 40, "giver": "baker", "climate": ""},
	{"id": "rich", "kind": "money", "a": 10000, "b": 0, "reward": 50, "giver": "baker", "climate": ""},
	{"id": "builder_50", "kind": "blocks", "a": 50, "b": 0, "reward": 25, "giver": "smith", "climate": ""},
	{"id": "builder_300", "kind": "blocks", "a": 300, "b": 0, "reward": 80, "giver": "smith", "climate": ""},
	{"id": "lamp_lighter", "kind": "blocks_of", "a": "lamp", "b": 5, "reward": 25, "giver": "smith", "climate": ""},
	{"id": "miner", "kind": "in_mine", "a": 0, "b": 0, "reward": 30, "giver": "smith", "climate": ""},
	{"id": "iron_tools", "kind": "tool_any", "a": 0, "b": 0, "reward": 50, "giver": "smith", "climate": ""},
	{"id": "friend_first", "kind": "friends", "a": 1, "b": 1, "reward": 20, "giver": "elder", "climate": ""},
	{"id": "friend_three", "kind": "friends", "a": 1, "b": 3, "reward": 60, "giver": "elder", "climate": ""},
	{"id": "best_friend", "kind": "friends", "a": 2, "b": 1, "reward": 80, "giver": "elder", "climate": ""},
	{"id": "chatterbox", "kind": "stat", "a": "talks", "b": 10, "reward": 20, "giver": "elder", "climate": ""},
	{"id": "generous", "kind": "stat", "a": "gifts", "b": 5, "reward": 30, "giver": "elder", "climate": ""},
	{"id": "sailor", "kind": "flag", "a": "boat", "b": 0, "reward": 40, "giver": "hunter", "climate": ""},
	{"id": "summit", "kind": "height", "a": 16, "b": 0, "reward": 30, "giver": "hunter", "climate": ""},
	{"id": "rider", "kind": "flag", "a": "horse", "b": 0, "reward": 40, "giver": "nomad", "climate": ""},
	{"id": "quest_first", "kind": "stat", "a": "quests", "b": 1, "reward": 20, "giver": "elder", "climate": ""},
	{"id": "quest_five", "kind": "stat", "a": "quests", "b": 5, "reward": 50, "giver": "elder", "climate": ""},
	{"id": "quest_chain", "kind": "chains", "a": 1, "b": 0, "reward": 80, "giver": "elder", "climate": ""},
	# زمستان
	{"id": "snow_walker", "kind": "biome", "a": ["snow", "snow_forest"], "b": 0, "reward": 15, "giver": "hunter", "climate": "winter"},
	{"id": "frost_summit", "kind": "biome", "a": ["mountain"], "b": 20, "reward": 40, "giver": "hunter", "climate": "winter"},
	{"id": "lodge_builder", "kind": "blocks_of", "a": "wood", "b": 40, "reward": 40, "giver": "innkeeper", "climate": "winter"},
	# صحرا
	{"id": "oasis_find", "kind": "biome", "a": ["oasis"], "b": 0, "reward": 20, "giver": "nomad", "climate": "desert"},
	{"id": "mesa_climber", "kind": "biome", "a": ["mesa"], "b": 12, "reward": 35, "giver": "nomad", "climate": "desert"},
	{"id": "sand_city", "kind": "blocks_of", "a": "brick", "b": 40, "reward": 40, "giver": "innkeeper", "climate": "desert"},
]

## «افسانه»: زنجیرهٔ اختیاری مقصدهای واقعی روی نقشهٔ هر جهان آماده (پروتکل ۳۶). هر مرحله باید به ترتیب انجام شود؛
## دو متن book_<id> و book_<id>_d در Loc دارد. dx و dz فاصله از مرکز شهر (متر)؛ مکان نهایی را سرور روی خشکی می‌گذارد.
## giver = نقشی که دربارهٔ مرحله حرف می‌زند؛ r = شعاع رسیدن (متر)؛ reward = سکهٔ کوچک (در جهان خلاقانه صفر).
const LEGENDS := {
	"medieval_fort": [
		{"dx": -60, "dz": -30, "reward": 25, "giver": "elder"},
		{"dx": 40, "dz": -90, "reward": 35, "giver": "guide"},
		{"dx": 110, "dz": 20, "reward": 45, "giver": "smith"},
		{"dx": 70, "dz": 110, "reward": 55, "giver": "farmer"},
		{"dx": -90, "dz": 90, "reward": 90, "giver": "elder", "bonus": ["gem", 1]},
	],
	"frozen_north": [
		{"dx": 50, "dz": -70, "reward": 25, "giver": "hunter"},
		{"dx": -80, "dz": -20, "reward": 40, "giver": "innkeeper"},
		{"dx": -40, "dz": 100, "reward": 55, "giver": "hunter"},
		{"dx": 100, "dz": 80, "reward": 90, "giver": "elder", "bonus": ["gold", 1]},
	],
	"desert_caravan": [
		{"dx": -70, "dz": 40, "reward": 25, "giver": "nomad"},
		{"dx": 20, "dz": -100, "reward": 40, "giver": "innkeeper"},
		{"dx": 110, "dz": -30, "reward": 55, "giver": "smith"},
		{"dx": 60, "dz": 100, "reward": 90, "giver": "nomad", "bonus": ["gem", 1]},
	],
	"green_valley": [
		{"dx": 45, "dz": -40, "reward": 25, "giver": "farmer"},
		{"dx": -50, "dz": -60, "reward": 35, "giver": "baker"},
		{"dx": -80, "dz": 40, "reward": 50, "giver": "guide"},
		{"dx": 60, "dz": 80, "reward": 90, "giver": "farmer", "bonus": ["gem", 1]},
	],
	"island_castaway": [
		{"dx": 30, "dz": -25, "reward": 25, "giver": "farmer"},
		{"dx": -35, "dz": -30, "reward": 35, "giver": "guide"},
		{"dx": -40, "dz": 30, "reward": 50, "giver": "baker"},
		{"dx": 35, "dz": 35, "reward": 90, "giver": "guide", "bonus": ["gold", 1]},
	],
	"merchant_city": [
		{"dx": 50, "dz": 35, "reward": 25, "giver": "baker"},
		{"dx": -55, "dz": 45, "reward": 35, "giver": "guide"},
		{"dx": -60, "dz": -50, "reward": 50, "giver": "farmer"},
		{"dx": 70, "dz": -70, "reward": 90, "giver": "baker", "bonus": ["gem", 1]},
	],
}
const LEGEND_RADIUS := 8.0


## مرحله‌های افسانهٔ یک جهان به شکل ورودی کتاب (kind = legend). a = شمارهٔ مرحله (۰-پایه).
static func legend_entries(scenario: String) -> Array:
	var out: Array = []
	var steps: Array = LEGENDS.get(scenario, [])
	for i in range(steps.size()):
		var st: Dictionary = steps[i]
		out.append({"id": "lg_%s_%d" % [scenario, i + 1], "kind": "legend", "a": i, "b": 0, "reward": int(st["reward"]),
			"giver": str(st["giver"]), "climate": "", "scenario": scenario, "dx": int(st["dx"]), "dz": int(st["dz"]), "r": LEGEND_RADIUS, "bonus": st.get("bonus", [])})
	return out


## فهرست شخصیت‌های یک جهان (سناریوی ناشناخته یا خالی ← فهرست پیش‌فرض).
static func cast_for(scenario: String) -> Array:
	return CASTS.get(scenario, CASTS[""])


## نقش NPC با شناسهٔ npc_id (از ۱) در این جهان؛ بیرون از فهرست «villager».
static func role_of(scenario: String, npc_id: int) -> String:
	var cast: Array = cast_for(scenario)
	var i := npc_id - 1
	if i >= 0 and i < cast.size():
		return str(cast[i][1])
	return "villager"


## دستاوردهای قابل‌دیدن این اقلیم؛ در جهان خلاقانه دستاوردهای سکه‌ای (پول) حذف می‌شوند.
static func entries_for(climate: String, creative: bool, scenario: String = "") -> Array:
	var out: Array = []
	for e in ENTRIES:
		if str(e["climate"]) != "" and str(e["climate"]) != climate:
			continue
		if creative and str(e["kind"]) == "money":
			continue
		out.append(e)
	out.append_array(legend_entries(scenario))
	return out


static func entry(id: String) -> Dictionary:
	for e in ENTRIES:
		if str(e["id"]) == id:
			return e
	if id.begins_with("lg_"):
		for sc in LEGENDS:
			for e in legend_entries(str(sc)):
				if str(e["id"]) == id:
					return e
	return {}


## مرحلهٔ بعدی مأموریت نقش (۰-پایه)؛ خالی اگر نقش مأموریت ندارد یا زنجیره تمام شده.
static func quest_step(role: String, done: int) -> Dictionary:
	var chain: Array = QUESTS.get(role, [])
	if done < 0 or done >= chain.size():
		return {}
	return chain[done]


static func quest_total(role: String) -> int:
	return (QUESTS.get(role, []) as Array).size()


static func line_key(role: String, level: int) -> String:
	return "dlg_%s_%d" % [role, clampi(level, 0, 2)]


static func hint_key(role: String) -> String:
	return "dlg_%s_hint" % role


static func done_key(role: String) -> String:
	return "dlg_%s_done" % role
