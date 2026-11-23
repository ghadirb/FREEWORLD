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
	# زمستان
	{"id": "snow_walker", "kind": "biome", "a": ["snow", "snow_forest"], "b": 0, "reward": 15, "giver": "hunter", "climate": "winter"},
	{"id": "frost_summit", "kind": "biome", "a": ["mountain"], "b": 20, "reward": 40, "giver": "hunter", "climate": "winter"},
	{"id": "lodge_builder", "kind": "blocks_of", "a": "wood", "b": 40, "reward": 40, "giver": "innkeeper", "climate": "winter"},
	# صحرا
	{"id": "oasis_find", "kind": "biome", "a": ["oasis"], "b": 0, "reward": 20, "giver": "nomad", "climate": "desert"},
	{"id": "mesa_climber", "kind": "biome", "a": ["mesa"], "b": 12, "reward": 35, "giver": "nomad", "climate": "desert"},
	{"id": "sand_city", "kind": "blocks_of", "a": "brick", "b": 40, "reward": 40, "giver": "innkeeper", "climate": "desert"},
]


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
static func entries_for(climate: String, creative: bool) -> Array:
	var out: Array = []
	for e in ENTRIES:
		if str(e["climate"]) != "" and str(e["climate"]) != climate:
			continue
		if creative and str(e["kind"]) == "money":
			continue
		out.append(e)
	return out


static func entry(id: String) -> Dictionary:
	for e in ENTRIES:
		if str(e["id"]) == id:
			return e
	return {}


static func line_key(role: String, level: int) -> String:
	return "dlg_%s_%d" % [role, clampi(level, 0, 2)]


static func hint_key(role: String) -> String:
	return "dlg_%s_hint" % role


static func done_key(role: String) -> String:
	return "dlg_%s_done" % role
