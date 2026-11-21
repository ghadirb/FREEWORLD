extends RefCounted
## ثابت‌های مشترک بین سرور و کلاینت.

const PROTOCOL_VERSION := 9
# ترافیک شبکه با DTLS رمز می‌شود (نسخهٔ ۴ به بعد). فقط برای عیب‌یابی خاموش شود.
const USE_DTLS := true
const DEFAULT_PORT := 7777
const MAX_PLAYERS := 10

const CHUNK_SIZE := 32.0
const CELL_SIZE := 2.0
const CITY_CELLS := 64
const CITY_SIZE := CELL_SIZE * CITY_CELLS
const SEA_LEVEL := 0.0

const PLAYER_SPEED := 6.0
const START_MONEY := 1000
const REFUND_RATIO := 0.5
const AUDIT_MAX := 500

# ناحیه‌ی میدان مرکزی (سلول‌ها) که فقط مدیران حق ساخت در آن را دارند.
const PLAZA_MIN := 30
const PLAZA_MAX := 33

const ROLE_PLAYER := "player"
const ROLE_CITY_ADMIN := "city_admin"
const ROLE_WORLD_ADMIN := "world_admin"
const ROLES := ["player", "city_admin", "world_admin"]

# size = [عرض, طول] بر حسب سلول
const BUILDING_TYPES := {
	"house": {"cost": 300, "size": [2, 2]},
	"shop": {"cost": 500, "size": [2, 2]},
	"farm": {"cost": 200, "size": [3, 3]},
	"road": {"cost": 20, "size": [1, 1]},
	"well": {"cost": 100, "size": [1, 1]},
	"bakery": {"cost": 600, "size": [2, 2]},
	"coop": {"cost": 250, "size": [2, 2]},
	"barn": {"cost": 350, "size": [3, 2]},
	"mill": {"cost": 450, "size": [2, 2]},
	"dairy": {"cost": 550, "size": [2, 2]},
}

# دامداری: مرغداری تخم‌مرغ و گاوداری شیر تولید می‌کند (مثل مزرعه، با موجودی و قیمت بازار).
const LIVESTOCK := {
	"coop": {"good": "egg", "seconds": 15.0, "max": 12.0, "base": 6.0, "min": 2.0, "drop": 0.3, "recover": 0.03},
	"barn": {"good": "milk", "seconds": 25.0, "max": 8.0, "base": 14.0, "min": 5.0, "drop": 0.6, "recover": 0.05},
}
# ساختمان‌هایی که تولید و «برداشت و فروش» دارند.
const PROCESSORS := {
	"mill": {"input": "wheat", "output": "flour", "amount": 2, "seconds": 16.0, "max": 12.0, "base": 16.0, "min": 6.0, "drop": 0.4, "recover": 0.05},
	"bakery": {"input": "flour", "output": "bread", "amount": 2, "seconds": 20.0, "max": 10.0, "base": 20.0, "min": 8.0, "drop": 0.5, "recover": 0.05},
	"dairy": {"input": "milk", "output": "cheese", "amount": 2, "seconds": 24.0, "max": 8.0, "base": 34.0, "min": 14.0, "drop": 0.7, "recover": 0.06},
}
# ساختمان‌هایی که محصولشان را می‌توان برداشت و در بازار فروخت.
const PRODUCERS := ["farm", "bakery", "coop", "barn", "mill", "dairy"]

const FARM_SECONDS_PER_WHEAT := 10.0
const FARM_MAX_STOCK := 10.0
const WHEAT_BASE_PRICE := 8.0
const WHEAT_MIN_PRICE := 2.0
const WHEAT_SELL_DROP := 0.1
const WHEAT_RECOVER_PER_SEC := 0.02

# نانوایی: ۲ آرد از بازار می‌خرد و ۱ نان می‌پزد.
const BREAD_WHEAT_COST := 2 # نام قدیمی برای سازگاری با ذخیره‌ها/افزونه‌های قدیمی
const BAKERY_SECONDS_PER_BREAD := 20.0
const BAKERY_MAX_STOCK := 10.0
const BREAD_BASE_PRICE := 20.0
const BREAD_MIN_PRICE := 8.0
const BREAD_SELL_DROP := 0.5
const BREAD_BUY_RISE := 0.5
const BREAD_RECOVER_PER_SEC := 0.05
const MARKET_MAX_STOCK := 200.0

# مشاغل: کارگر کنار محل کار حاضر باشد ← تولید ۵۰٪ سریع‌تر و هر WAGE_INTERVAL ثانیه حقوق از کارفرما.
const WORKER_BONUS := 0.5
const WAGE_INTERVAL := 30.0
const WAGE_AMOUNT := 12
const JOB_TYPES := ["farm", "bakery", "coop", "barn", "mill", "dairy"]

# ساختمان‌های قابل‌ورود. خانه فقط برای صاحبش؛ مغازه و نانوایی برای همه.
const ENTERABLE := ["house", "shop", "bakery"]
# انرژی بازیکن: به‌آرامی کم می‌شود؛ در خانهٔ خودش استراحت می‌کند. صفر = توان کار ندارد (حقوق/تولید متوقف).
const ENERGY_MAX := 100.0
const ENERGY_DECAY_PER_SEC := 0.04
const ENERGY_REST_PER_SEC := 2.5

# هر ثانیهٔ واقعی = یک دقیقهٔ بازی
const TIME_SCALE := 60.0
# ابزارهای World Mode (فقط مدیران): ضریب سرعت زمان و آب‌وهوا.
const TIME_SPEEDS := [0.0, 1.0, 4.0, 10.0]
const WEATHERS := ["clear", "rain", "fog"]

const MAX_BUILDINGS_PER_PLAYER := 40
const MAX_ACCOUNTS := 500
const INTERACT_RANGE := 15.0
const CHAT_MAX := 200
const WORLD_LIMIT := 400.0
const NPC_COUNT := 4
const NPC_SPEED := 3.0
const NPC_SHOP_PAYMENT := 5
const NPC_DAILY_INCOME := 15
const NPC_MAX_MONEY := 200
const NPC_WORK_BONUS := 0.5
const NPC_NAMES := ["علی", "مریم", "رضا", "زهرا", "حسین", "سارا"]

# ---------------- ساخت بلوکی (مثل ماینکرفت) ----------------
# هر بلوک یک مکعب ۱×۱×۱ است. مختصات صحیح (x, y, z)؛ y=0 همان سطح دریاست.
const BLOCK_REACH := 18.0
const GATHER_RANGE := 7.0
const MAX_BLOCKS_PER_PLAYER := 2500
const MAX_BLOCKS_TOTAL := 25000
const MAX_BLOCK_HEIGHT := 24  # بالاتر از سطح زمین همان ستون
const BLOCK_SEND_BATCH := 400
const ITEM_CAP := 999
const COLOR_COUNT := 12  # ۰ = رنگ طبیعی
# فیلد color هر بلوک یک «متا» است: رنگ (۰..۱۱) + ۱۶×جهت (۰..۳؛ فقط برای پله: جهت بالا رفتن).
const META_MAX := 64
const STEP_UP := 1.0  # بیشترین بالا رفتن در یک قدم

# مواد: قیمت پایهٔ فروش. خرید از فروشگاه عمومی ۱٫۸ برابر است.
const ITEMS := {
	"wood": 4.0, "stone": 5.0, "clay": 4.0, "dirt": 1.0, "sand": 2.0, "brick": 10.0, "glass": 12.0,
	"iron": 14.0, "gold": 40.0,
}
const ITEM_ORDER := ["wood", "stone", "clay", "dirt", "sand", "brick", "glass", "iron", "gold"]
const BUY_MARKUP := 1.8
const SELL_DROP := 0.04   # نسبت کاهش قیمت با هر فروش
const SELL_FLOOR := 0.5   # حداقل قیمت نسبت به پایه
const SELL_RECOVER_PER_SEC := 0.01
const START_ITEMS := {"wood": 24, "stone": 12, "dirt": 12, "glass": 2, "brick": 4}

# نوع بلوک‌ها. cost = مواد لازم برای هر بلوک. passable = بازیکن می‌تواند از آن عبور کند.
const BLOCK_ORDER := ["dirt", "wood", "stone", "brick", "glass", "window", "door", "roof", "fence", "road", "stairs", "lamp"]
const BLOCK_TYPES := {
	"dirt": {"cost": {"dirt": 1}},
	"wood": {"cost": {"wood": 1}},
	"stone": {"cost": {"stone": 1}},
	"brick": {"cost": {"brick": 1}},
	"glass": {"cost": {"glass": 1}},
	"window": {"cost": {"glass": 1, "wood": 1}},
	"door": {"cost": {"wood": 2}, "passable": true},
	"roof": {"cost": {"wood": 1, "clay": 1}},
	"fence": {"cost": {"wood": 1}},
	"road": {"cost": {"stone": 1}, "passable": true},
	"stairs": {"cost": {"wood": 2}},
	"lamp": {"cost": {"glass": 1, "wood": 1}},
}

# دستورهای ساخت مواد: ورودی ← خروجی
const RECIPES := {
	"brick": {"in": {"clay": 2}, "out": "brick", "n": 2},
	"glass": {"in": {"sand": 2}, "out": "glass", "n": 1},
	"upgrade_axe": {"in": {"iron": 3, "wood": 4}, "upgrade": "axe"},
	"upgrade_pickaxe": {"in": {"iron": 4, "wood": 2}, "upgrade": "pickaxe"},
	"upgrade_shovel": {"in": {"iron": 2, "wood": 2}, "upgrade": "shovel"},
}

# گره‌های منبع در جهان و ابزار مناسب هرکدام.
const RESOURCE_CELL := 4.0
const RESOURCES := {
	"tree": {"tool": "axe", "item": "wood", "min": 2, "max": 4, "respawn": 90.0},
	"rock": {"tool": "pickaxe", "item": "stone", "min": 2, "max": 3, "respawn": 120.0},
	"clay": {"tool": "shovel", "item": "clay", "min": 2, "max": 3, "respawn": 100.0},
	# اکتشاف: سنگ معدن فقط در کوهستان؛ صندوق گنج پنهان با دست باز می‌شود و پول می‌دهد.
	"iron_ore": {"tool": "pickaxe", "item": "iron", "min": 1, "max": 3, "respawn": 180.0},
	"gold_ore": {"tool": "pickaxe", "item": "gold", "min": 1, "max": 2, "respawn": 300.0, "min_tier": 2},
	"chest": {"tool": "hand", "item": "", "min": 1, "max": 1, "respawn": 900.0, "reward_min": 60, "reward_max": 240},
}
const GOLD_MIN_HEIGHT := 20.0
# ابزار آهنی (سطح ۲): یک واحد بیشتر از هر گره/کندن می‌دهد و برای سنگ طلا لازم است. دائمی است.
const TOOL_UPGRADES := ["axe", "pickaxe", "shovel"]
# معامله مستقیم بین بازیکنان
const OFFER_TTL := 60.0
const OFFER_MAX_PENDING := 5
const OFFER_MAX_PRICE := 100000
const TOOLS := ["hand", "axe", "pickaxe", "shovel", "hammer", "brush"]


static func role_rank(role: String) -> int:
	return ROLES.find(role)


static func is_livestock(type: String) -> bool:
	return LIVESTOCK.has(type)


static func is_admin(role: String) -> bool:
	return role_rank(role) >= 1


static func building_size(type: String) -> Array:
	return BUILDING_TYPES[type]["size"]


static func block_passable(type: String) -> bool:
	return bool(BLOCK_TYPES.get(type, {}).get("passable", false))


static func meta_color(m: int) -> int:
	return m % 16


static func meta_facing(m: int) -> int:
	return (m / 16) % 4


static func meta_valid(m: int) -> bool:
	return m >= 0 and m < META_MAX and m % 16 < COLOR_COUNT
