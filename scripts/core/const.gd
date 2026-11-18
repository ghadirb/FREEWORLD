extends RefCounted
## ثابت‌های مشترک بین سرور و کلاینت.

const PROTOCOL_VERSION := 5
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
}

# دامداری: مرغداری تخم‌مرغ و گاوداری شیر تولید می‌کند (مثل مزرعه، با موجودی و قیمت بازار).
const LIVESTOCK := {
	"coop": {"good": "egg", "seconds": 15.0, "max": 12.0, "base": 6.0, "min": 2.0, "drop": 0.3, "recover": 0.03},
	"barn": {"good": "milk", "seconds": 25.0, "max": 8.0, "base": 14.0, "min": 5.0, "drop": 0.6, "recover": 0.05},
}
# ساختمان‌هایی که تولید و «برداشت و فروش» دارند.
const PRODUCERS := ["farm", "bakery", "coop", "barn"]

const FARM_SECONDS_PER_WHEAT := 10.0
const FARM_MAX_STOCK := 10.0
const WHEAT_BASE_PRICE := 8.0
const WHEAT_MIN_PRICE := 2.0
const WHEAT_SELL_DROP := 0.1
const WHEAT_RECOVER_PER_SEC := 0.02

# نانوایی: ۲ گندم از بازار می‌خرد و ۱ نان می‌پزد.
const BREAD_WHEAT_COST := 2
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
const JOB_TYPES := ["farm", "bakery", "coop", "barn"]

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


static func role_rank(role: String) -> int:
	return ROLES.find(role)


static func is_livestock(type: String) -> bool:
	return LIVESTOCK.has(type)


static func is_admin(role: String) -> bool:
	return role_rank(role) >= 1


static func building_size(type: String) -> Array:
	return BUILDING_TYPES[type]["size"]
