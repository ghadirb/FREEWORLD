extends RefCounted
## ثابت‌های مشترک بین سرور و کلاینت.

const PROTOCOL_VERSION := 47
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
# اقلیم جهان (فقط ظاهر زمین، نوع درخت و منابع؛ ارتفاع و آب همان Seed است). پیش‌فرض «temperate» دقیقاً مثل قبل است.
const CLIMATES := ["temperate", "winter", "desert"]
# حوادث طبیعی (فقط مدیران آغاز می‌کنند؛ موقت، ذخیره نمی‌شوند، در گزارش مدیریتی ثبت می‌شوند).
# طوفان: بیرون از ساختمان انرژی دو برابر سریع‌تر تمام می‌شود و مزارع ۵۰٪ سریع‌تر محصول می‌دهند. زلزله: فقط لرزش (بدون خسارت به دارایی).
const DISASTERS := {"storm": 60.0, "quake": 10.0}
const DISASTER_COOLDOWN := 30.0
const STORM_ENERGY_MULT := 2.0
const STORM_FARM_MULT := 1.5

const MAX_BUILDINGS_PER_PLAYER := 40
const MAX_ACCOUNTS := 500
const INTERACT_RANGE := 15.0
const CHAT_MAX := 200
const WORLD_LIMIT := 800.0
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
const REGION_MAX_SIDE := 16      # بیشینهٔ طول هر ضلع جعبهٔ پر کردن/پاک کردن/چسباندن
const REGION_MAX_VOLUME := 512   # بیشینهٔ تعداد خانه در یک عمل دسته‌ای
const UNDO_DEPTH := 20           # تعداد عمل‌های قابل واگرد برای هر بازیکن
const ITEM_CAP := 999
const COLOR_COUNT := 12  # ۰ = رنگ طبیعی
# فیلد color هر بلوک یک «متا» است: رنگ (۰..۱۱) + ۱۶×جهت (۰..۳؛ فقط برای پله: جهت بالا رفتن).
const META_MAX := 64
const STEP_UP := 1.0  # بیشترین بالا رفتن در یک قدم

# مواد: قیمت پایهٔ فروش. خرید از فروشگاه عمومی ۱٫۸ برابر است.
const ITEMS := {
	"wood": 4.0, "stone": 5.0, "clay": 4.0, "dirt": 1.0, "sand": 2.0, "brick": 10.0, "glass": 12.0,
	"iron": 14.0, "gold": 40.0, "coal": 8.0, "gem": 60.0, "fish": 8.0,
}
const ITEM_ORDER := ["wood", "stone", "clay", "dirt", "sand", "brick", "glass", "iron", "gold", "coal", "gem", "fish"]
const BUY_MARKUP := 1.8
const SELL_DROP := 0.04   # نسبت کاهش قیمت با هر فروش
const SELL_FLOOR := 0.5   # حداقل قیمت نسبت به پایه
const SELL_RECOVER_PER_SEC := 0.01
const START_ITEMS := {"wood": 24, "stone": 12, "dirt": 12, "glass": 2, "brick": 4}

# نوع بلوک‌ها. cost = مواد لازم برای هر بلوک. passable = بازیکن می‌تواند از آن عبور کند.
const BLOCK_ORDER := ["dirt", "wood", "stone", "brick", "glass", "window", "door", "roof", "fence", "road", "stairs", "lamp", "rail"]
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
	"rail": {"cost": {"iron": 1}, "passable": true},
}

# دستورهای ساخت مواد: ورودی ← خروجی
const RECIPES := {
	"brick": {"in": {"clay": 2}, "out": "brick", "n": 2},
	"glass": {"in": {"sand": 2}, "out": "glass", "n": 1},
	"upgrade_axe": {"in": {"iron": 3, "wood": 4}, "upgrade": "axe"},
	"upgrade_pickaxe": {"in": {"iron": 4, "wood": 2}, "upgrade": "pickaxe"},
	"upgrade_shovel": {"in": {"iron": 2, "wood": 2}, "upgrade": "shovel"},
	# قایق (پروتکل ۲۵): یک‌بار ساخته می‌شود و برای همیشه مال خود بازیکن است؛ در جهان خلاقانه رایگان است.
	"boat": {"in": {"wood": 20, "iron": 2}, "unlock": "boat"},
	# اسب (پروتکل ۲۶): یک‌بار با سکه خریده می‌شود؛ روی خشکی ۱٫۹ برابر سریع‌تر.
	"horse": {"in": {}, "money": 300, "unlock": "horse"},
	# ماشین (پروتکل ۲۷): یک‌بار با سکه و آهن؛ سریع‌ترین وسیلهٔ خشکی.
	"car": {"in": {"iron": 6}, "money": 1200, "unlock": "car"},
	# سلاح و زره (پروتکل ۴۷): مرحله‌به‌مرحله؛ هر ساخت یک سطح بالاتر از سطح فعلی را می‌دهد.
	"club": {"in": {"wood": 5}, "gear": "weapon", "tier": 1},
	"sword": {"in": {"iron": 3, "wood": 2}, "gear": "weapon", "tier": 2},
	"vest": {"in": {"wood": 4, "stone": 4}, "gear": "armor", "tier": 1},
	"plate": {"in": {"iron": 6}, "gear": "armor", "tier": 2},
}
const HORSE_SPEED_MULT := 1.9
const CAR_SPEED_MULT := 3.0
## ضریب اضافهٔ سرعت ماشین روی جاده (ساختمان جاده یا بلوک جاده)؛ NPCها هم مسیر جاده‌دار را ترجیح می‌دهند.
const CAR_ROAD_MULT := 1.5
const NPC_ROAD_WEIGHT := 0.5
## ریل (بلوک «ریل» روی سطح زمین): ماشین روی آن حتی از جاده سریع‌تر است.
const CAR_RAIL_MULT := 2.0
## قطار خودکار روی ریل (پروتکل ۳۲): سرعت بر حسب واحد بر ثانیه؛ ساعت قطار را سرور هر TRAIN_CLOCK_INTERVAL ثانیه می‌فرستد.
const TRAIN_SPEED := 6.0
const TRAIN_CLOCK_INTERVAL := 1.0
const TRAIN_WAGONS := 2
const TRAIN_MAX_LINES := 12
# ماهیگیری: کنار آب یا از روی قایق؛ هر بار ۰ تا ۲ ماهی، با فاصلهٔ زمانی بین دو بار.
const FISH_COOLDOWN_MS := 3000
const FISH_RANGE := 4.0
const FISH_MISS := 0.25
const FISH_DOUBLE := 0.85

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
# دوستی با NPC: هر روز بازی یک بار صحبت و یک بار هدیه. هدیه به ارزش کالا امتیاز می‌دهد.
const NPC_TALK_RANGE := 7.0
const FRIEND_MAX := 100
const FRIEND_LEVELS := [25, 70]          # آستانهٔ «دوست» و «دوست صمیمی»
const FRIEND_TALK_POINTS := 2
const FRIEND_REWARD := [0, 10, 25]       # پاداش روزانهٔ صحبت (از پول خود NPC پرداخت می‌شود)
# فروش کالا به NPC: قیمت بازار + پاداش دوستی، از پول خود NPC پرداخت می‌شود (قیمت بازار را پایین نمی‌آورد)
const NPC_TRADE_BONUS := [0.0, 0.10, 0.25]
const NPC_TRADE_MAX := 50

# خرید از NPC (پروتکل ۲۳): ارزان‌تر از فروشگاه عمومی (×۱٫۸) ولی با سهمیهٔ روزانهٔ هر NPC؛ دوستان تخفیف می‌گیرند.
# پول خریدار به NPC می‌رسد (و NPC می‌تواند دوباره با آن از بازیکنان بخرد).
const NPC_BUY_MARKUP := 1.4
const NPC_BUY_DISCOUNT := [0.0, 0.05, 0.15]
const NPC_STOCK_PER_DAY := 20
const NPC_SELLS := ["wood", "stone", "clay", "dirt", "sand", "brick", "glass", "coal"]

# مبلمان خانه (پروتکل ۲۳): فقط صاحب خانه، داخل خانهٔ خودش؛ سرور هزینه و جا را می‌سنجد.
# size = [عرض x, عمق z] به متر؛ اتاق ۸×۸ است و حرکت‌پذیری بازیکن تا ±۳٫۳ متر.
const FURN_MAX := 16
const FURN_SNAP := 0.25
const FURN_BOUND := 3.8
const FURN_REFUND := 0.5
const FURNITURE_ORDER := ["bed", "table", "chair", "sofa", "shelf", "lamp", "plant", "rug"]
const FURNITURE := {
	"bed": {"cost": 80, "size": [2.0, 1.0]},
	"table": {"cost": 40, "size": [1.6, 1.0]},
	"chair": {"cost": 15, "size": [0.6, 0.6]},
	"sofa": {"cost": 70, "size": [2.0, 0.9]},
	"shelf": {"cost": 45, "size": [1.4, 0.5]},
	"lamp": {"cost": 20, "size": [0.5, 0.5]},
	"plant": {"cost": 12, "size": [0.5, 0.5]},
	"rug": {"cost": 25, "size": [2.0, 1.4], "flat": true},
}
# مینی‌بازی «سکه‌یاب»: ۲۰ سکه دور بازیکن، ۶۰ ثانیه. جایزه فقط برای چند دور اول هر روز بازی (جلوگیری از پول‌سازی بی‌پایان).
const MINIGAME_COINS := 20
const MINIGAME_TIME := 60.0
const MINIGAME_RADIUS := 30.0
const MINIGAME_MIN_DIST := 4.0
const MINIGAME_MAX_HEIGHT := 18.0
const MINIGAME_PICK_RANGE := 1.8
const MINIGAME_REWARD_PER_COIN := 2
const MINIGAME_FULL_BONUS := 10
const MINIGAME_REWARDED_RUNS := 3
const MINIGAME_BOARD_SIZE := 10
## میدان‌های ساخته‌شده توسط بازیکن (پروتکل ۳۱، docs/ARENAS.md)
const ARENA_COST := 150
const ARENA_MAX_PER_PLAYER := 12
const ARENA_MAX_TOTAL := 80
const ARENA_NAME_MAX := 24
const ARENA_R_MIN := 6.0
const ARENA_R_MAX := 20.0
const ARENA_COINS_MIN := 5
const ARENA_COINS_MAX := 30
const ARENA_TIME_MIN := 20.0
const ARENA_TIME_MAX := 120.0
const ARENA_REWARD_MAX := 3
const ARENA_SPACING := 12.0
const ARENA_PLAY_MARGIN := 4.0
const ARENA_OBS_MAX := 6          # حداکثر مانع متحرک در میدان پارکور (پروتکل ۳۹)
const ARENA_OBS_HIT_RANGE := 1.2  # فاصلهٔ برخورد (متر)
const ARENA_OBS_PENALTY := 4.0    # ثانیه‌ای که از زمان دور کم می‌شود
const ARENA_CODE_MAX := 3000          # بیشینهٔ طول کد اشتراک میدان (پروتکل ۴۰)
const ARENA_PROPS_MAX := 12          # اشیای سفارشی هر میدان: «جایزهٔ زمان» و «تله»
const ARENA_PROP_SPACING := 2.0     # حداقل فاصلهٔ دو شیء
const ARENA_PROP_RANGE := 1.6       # فاصلهٔ برخورد با شیء
const ARENA_BONUS_TIME := 5.0       # ثانیه‌ای که جایزهٔ زمان اضافه می‌کند (حداکثر تا زمان کل میدان)
const ARENA_RESPAWN_PENALTY := 3.0   # ثانیه‌ای که با بازگشت به نقطهٔ ذخیرهٔ پارکور از زمان کم می‌شود
const ARENA_OBS_COOLDOWN := 1.5   # بین دو برخورد پشت‌سرهم
const ARENA_WIN_MAX := 100   # درصد لازم برای برد؛ ۰ = بدون شرط برد (پروتکل ۳۷)
# سختی بازی (پروتکل ۴۶): ۰ آسان، ۱ متوسط، ۲ سخت. برای همهٔ نوع‌ها یکسان است و زمان، جایزه، مانع، دشمن و طول مسیر را عوض می‌کند.
const ARENA_DIFF_DEFAULT := 1
const ARENA_DIFF_TIME := [1.35, 1.0, 0.75]      # ضریب زمان دور
const ARENA_DIFF_REWARD := [0.75, 1.0, 1.5]     # ضریب جایزهٔ هر هدف
const ARENA_DIFF_PENALTY := [0.75, 1.0, 1.5]    # ضریب جریمهٔ برخورد با مانع یا تله
const ARENA_DIFF_FOE_SPEED := [0.8, 1.0, 1.25]  # سرعت دشمن در مبارزه و بقا
const ARENA_DIFF_FOE_DAMAGE := [0.7, 1.0, 1.4]  # آسیب دشمن
const ARENA_DIFF_GOAL := [1.35, 1.0, 0.75]      # اندازهٔ دروازهٔ فوتبال
const ARENA_DIFF_OBS_ADD := [-2, 0, 2]          # مانع متحرک اضافه یا کم نسبت به تنظیم سازنده
# مسیر بازی بیرون از میدان: میدان فقط «نقطهٔ شروع» است و هدف‌ها در شهر پخش می‌شوند (سکه‌یاب، پارکور، مسابقه، ماجراجویی).
const ARENA_COURSE_GAP := 8.0                   # کمینهٔ فاصلهٔ هدف از لبهٔ میدان
const ARENA_COURSE_RANGE := {"coins": [60.0, 100.0, 150.0], "parkour": [90.0, 140.0, 200.0], "race": [55.0, 85.0, 120.0], "adventure": [80.0, 130.0, 190.0]}
const ARENA_COURSE_SPEED := {"coins": 5.0, "parkour": 5.0, "race": 14.0, "adventure": 5.0}   # سرعت مرجع برای زمان سفر (متر بر ثانیه)
const ARENA_TIME_CAP := 600.0                   # سقف زمان کل دور پس از افزودن زمان سفر
const ARENA_PROP_BOUND := 260.0                 # دورترین فاصلهٔ شیء سفارشی از مرکز میدان
const SURV_HP := 100.0            # سلامت بازیکن در دور مبارزه و بقا (پروتکل ۴۳)
const SURV_FOE_HP := 3            # ضربه‌های لازم برای شکست یک دشمن
const SURV_FOE_SPEED := 2.6       # سرعت دشمن (متر بر ثانیه)
const SURV_FOE_DAMAGE := 10.0     # آسیب هر برخورد
const SURV_FOE_CD := 1.0          # فاصلهٔ دو حملهٔ هر دشمن
const SURV_FOE_REACH := 1.3       # فاصلهٔ حملهٔ دشمن
const SURV_ATTACK_RANGE := 2.4    # برد ضربهٔ خودکار بازیکن
const SURV_ATTACK_CD := 0.6       # فاصلهٔ ضربه‌های بازیکن
const SURV_ALIVE_MAX := 3         # حداکثر دشمن هم‌زمان
const SURV_COUNT_MAX := 20        # حداکثر دشمن هر دور
const ADV_STAGES_MAX := 8         # حداکثر مرحلهٔ ماجراجویی (پروتکل ۴۴)
const FOOT_GOALS_MAX := 10        # حداکثر گل هدف در میدان فوتبال (پروتکل ۴۲)
const FOOT_KICK_SPEED := 9.0      # سرعت توپ پس از لمس بازیکن (متر بر ثانیه)
const FOOT_RANGE := 1.6           # فاصلهٔ لمس توپ
const FOOT_KICK_CD := 0.3         # فاصلهٔ دو ضربه
const FOOT_FRICTION := 1.6        # کاهش نمایی سرعت توپ
const FOOT_GOAL_RANGE := 2.2      # فاصلهٔ ورود توپ به دروازه
const FOOT_SEND := 0.2            # هر چند ثانیه موقعیت توپ برای بازیکن فرستاده می‌شود
const ARENA_PARKOUR_MAX := 12   # حداکثر ایستگاه در میدان پارکور (پروتکل ۳۶)
# مسابقهٔ ایستگاه‌ها: ۶ ایستگاه به ترتیب روی حلقه، سقف زمان ۹۰ ثانیه، سرعت مجاز در طول مسابقه ۱٫۶ برابر.
const RACE_GATES := 6
const RACE_TIME := 90.0
const RACE_RADIUS := 22.0
const RACE_GATE_RANGE := 3.0
const RACE_SPEED_MULT := 1.6
# پرواز (فقط حالت خلاقانه، پروتکل ۲۱): ارتفاع بالای زمین، سرعت صعود و ضریب سرعت افقی
const FLY_MAX_ALT := 30.0
const FLY_MIN_ALT := 0.3
const FLY_CLIMB_SPEED := 8.0
const FLY_SPEED_MULT := 1.6
const RACE_REWARD := 30
## قایق (پروتکل ۲۴): فقط روی آب حرکت می‌کند، سرعت بیشتر از پیاده‌روی؛ مسابقهٔ قایق ایستگاه‌هایش روی آب است.
const BOAT_SPEED_MULT := 1.8
const BOAT_BOARD_RANGE := 5.0
const BOAT_MIN_H := -0.3
const BOAT_RACE_RADIUS := 14.0
const BOAT_RACE_GATE_RANGE := 3.5
const BOAT_RACE_TIME := 120.0
const BOAT_RACE_REWARD := 40
# مسابقهٔ ماشین (پروتکل ۲۸): حلقهٔ بزرگ‌تر روی خشکی، جدول و جایزهٔ جدا.
const CAR_RACE_RADIUS := 70.0
const CAR_RACE_GATE_RANGE := 5.0
const CAR_RACE_TIME := 75.0
const CAR_RACE_REWARD := 50
# مسابقهٔ گروهی هم‌زمان (پروتکل ۲۹): همه روی یک مسیر پیاده؛ جایزه بر اساس رتبه.
const GROUP_LOBBY_TIME := 15.0
const GROUP_MAX := 10
const GROUP_REWARDS := [80, 50, 30]
const RACE_REWARDED_RUNS := 3
# ابزارهای خلقت (World Mode، فقط مدیران): درخت، سنگ و حیوانات آرام. وضعیتشان با شهر ذخیره می‌شود.
const GOD_STATIC := ["tree", "rock"]
const GOD_ANIMALS := {"sheep": 1.0, "deer": 2.2, "rabbit": 1.7}   # سرعت راه رفتن
const GOD_MAX := 150
const GOD_REMOVE_RANGE := 3.0
## حذف دائمی منبع طبیعی (درخت/سنگ/معدن) با نگه‌داشتن: زمان رویش بی‌نهایت در لایهٔ depleted.
const CLEARED_FOREVER := 1.0e12
const GOD_MIN_HEIGHT := 0.3
const TOOLS := ["hand", "axe", "pickaxe", "shovel", "fill", "hammer", "brush"]
## حالت‌های چکش: تک‌بلوک و ابزارهای دسته‌ای (دو گوشه → اجرا)
const BUILD_MODES := ["single", "fill", "walls", "clear", "copy", "paste"]

## تغییر زمین (پروتکل ۱۶): شبکهٔ ۲ متری، واحد ۱/۸ متر؛ هر بار کندن مرکز ۰٫۵ متر پایین می‌برد.
const TERRAIN_EDIT_STEP := 2.0
const TERRAIN_UNIT := 0.125
const TERRAIN_MIN_UNITS := -40      # حداکثر ۵ متر عمق نسبت به زمین پایه
const TERRAIN_MAX_UNITS := 24       # حداکثر ۳ متر بلندی
const TERRAIN_ADMIN_MIN_UNITS := -80   # ابزار مدیر: تا ۱۰ متر عمق
const TERRAIN_ADMIN_MAX_UNITS := 160   # ابزار مدیر: تا ۲۰ متر بلندی
## ابزار شکل‌دهی زمین برای مدیر (World Mode): کوه، دریاچه، صاف کردن
const GOD_SHAPES := ["mountain", "lake", "flatten"]
# قوانین جهان (پروتکل ۲۲، حس WorldBox): آتش‌سوزی درخت‌ها و رشد جنگل. فقط روی درخت‌های ساخته‌شده/کاشته‌شده (god) اثر دارد.
## رنگ کشورها (به ترتیب شمارهٔ رنگ در Civ.COLOR_COUNT)
const CIV_COLORS := [Color("e6504a"), Color("4a8be6"), Color("4ac86a"), Color("a05ae6"), Color("f0963c"), Color("3cc8c8")]
const GOD_POWERS := ["fire", "grove", "kingdom", "plague", "famine"]
const FIRE_BURN_SECONDS := 8.0
const FIRE_SPREAD_RANGE := 5.0
const FIRE_SPREAD_CHANCE := 0.25     # احتمال در هر ثانیه برای هر درخت همسایه
const FIRE_IGNITE_RANGE := 4.0
const FIRE_RAIN_SPREAD := 0.25       # باران احتمال گسترش را ضرب می‌کند
const FIRE_RAIN_DECAY := 2.0         # باران آتش را دو برابر سریع خاموش می‌کند
const GROW_INTERVAL := 15.0
const GROW_CHANCE := 0.12            # احتمال زاد و ولد هر درخت در هر دوره
const GROW_CAP := 100                # سقف درخت‌های جهان برای قانون رشد (بقیهٔ ظرفیت god برای حیوانات)
const GROVE_SIZE := 6
const FIRE_REGROW := 300.0           # درخت طبیعیِ سوخته بعد از این‌همه ثانیه دوباره می‌روید
const NFIRE_MAX := 60                # سقف هم‌زمان درخت طبیعی در حال سوختن (برای سبک ماندن سرور)
const SHAPE_RADIUS := 5                # شعاع به رأس (هر رأس ۲ متر → ۱۰ متر)
const SHAPE_MOUNTAIN_UNITS := 64       # هر بار بلندی مرکز کوه (۸ متر)
const SHAPE_LAKE_FLOOR := -1.5         # کف دریاچه (متر)؛ آب زیر ۰٫۲ متر است
const TERRAIN_MAX_EDITS := 6000     # سقف رأس‌های تغییرکرده در هر شهر
const TERRAIN_DIG_STRENGTH := [4, 2, 1]  # بیل معمولی ۳×۳: بر اساس فاصلهٔ منهتن از مرکز
const TERRAIN_DIG_STRENGTH_IRON := [4, 3, 2, 1, 1]  # بیل آهنی ۵×۵
const RIVER_WIDTH := 0.05           # نیم‌پهنای کانال در نویز (بزرگ‌تر = رودخانهٔ پهن‌تر)
const RIVER_MIN_DIST := 125.0       # رودخانه فقط بیرون از شهر

## ---------------- معدن زیرزمینی (پروتکل ۱۷) ----------------
## ورودی معدن در کوهستان است (قطعی از Seed). داخل معدن شبکهٔ تونل ۲۵×۲۵ کاشی (هر کاشی ۳ متر) با سنگ معدن است.
## هرچه از ورودی دورتر، سنگ ارزشمندتر: سنگ/زغال ← آهن ← طلا ← جواهر. دورترین بن‌بست‌ها صندوق گنج دارند.
const MINE_CELL_WORLD := 96.0       # شبکهٔ جست‌وجوی ورودی‌ها روی نقشه (متر)
const MINE_MIN_HEIGHT := 14.5       # ورودی فقط روی کوه (زیست‌بوم کوهستان از ۱۴ شروع می‌شود)
const MINE_MAX_HEIGHT := 48.0
const MINE_ENTER_RANGE := 7.0       # فاصلهٔ مجاز برای ورود
const MINE_NO_BUILD_RADIUS := 7.0   # ساخت و تغییر زمین نزدیک ورودی ممنوع
const MINE_GATHER_RANGE := 4.0
const MINE_TILE := 3.0
const MINE_ROOMS := 12              # اتاق‌ها در هر ضلع؛ اندازهٔ شبکه = ۲×۱۲+۱ = ۲۵
const MINE_MARGIN := 0.45           # فاصلهٔ شخصیت تا دیوار
const MINE_CAVERNS := 5
const MINE_LOOP_CHANCE := 0.07
const MINE_ORE_CHANCE := 0.14       # احتمال سنگ در کاشی معمولی (بن‌بست‌ها همیشه سنگ دارند)
const MINE_CHESTS := 3
# روستاهای از پیش‌ساخته (پروتکل ۱۹): قطعی از Seed، بیرون از شهر، روی زمین هموار.
const VILLAGE_CELL := 128.0
const VILLAGE_RADIUS := 22.0
const VILLAGE_MIN_CITY_DIST := 140.0
const VILLAGE_MIN_H := 1.2
const VILLAGE_MAX_H := 10.0
const HOUSE_HALF := 2.5            # خانه ۵×۵ متر، هم‌تراز محورها
const HOUSE_ENTER_RANGE := 4.5
const VILLAGE_ANIMALS := ["sheep", "sheep", "rabbit"]
const HOME_REST_COOLDOWN := 90.0   # تخت: هر ۹۰ ثانیه یک بار انرژی کامل
const HOME_CHEST := {"respawn": 900.0, "reward_min": 15, "reward_max": 45}
const MINE_ORES := {
	"stone": {"item": "stone", "min": 2, "max": 4, "respawn": 120.0},
	"coal": {"item": "coal", "min": 2, "max": 4, "respawn": 150.0},
	"iron": {"item": "iron", "min": 1, "max": 3, "respawn": 180.0},
	"gold": {"item": "gold", "min": 1, "max": 2, "respawn": 300.0, "min_tier": 2},
	"gem": {"item": "gem", "min": 1, "max": 1, "respawn": 600.0, "min_tier": 2},
	"chest": {"item": "", "min": 1, "max": 1, "respawn": 1200.0, "reward_min": 150, "reward_max": 500},
}


static func role_rank(role: String) -> int:
	return ROLES.find(role)


static func is_livestock(type: String) -> bool:
	return LIVESTOCK.has(type)


static func is_admin(role: String) -> bool:
	return role_rank(role) >= 1


static func building_size(type: String) -> Array:
	return BUILDING_TYPES[type]["size"]


## قیمت خرید یک واحد از NPC در سطح دوستی lv (۰..۲). قیمت ثابت و مستقل از بازار است.
static func npc_buy_price(item: String, lv: int) -> int:
	var d: float = float(NPC_BUY_DISCOUNT[clampi(lv, 0, NPC_BUY_DISCOUNT.size() - 1)])
	return maxi(1, int(ceil(float(ITEMS[item]) * NPC_BUY_MARKUP * (1.0 - d))))


## نیم‌ابعاد (x, z) مبلمان با درنظرگرفتن چرخش r (۰..۳؛ فرد = جابه‌جایی عرض و عمق).
static func furn_half(type: String, r: int) -> Vector2:
	var sz: Array = FURNITURE[type]["size"]
	var w: float = float(sz[0]) * 0.5
	var d: float = float(sz[1]) * 0.5
	return Vector2(d, w) if r % 2 == 1 else Vector2(w, d)


static func block_passable(type: String) -> bool:
	return bool(BLOCK_TYPES.get(type, {}).get("passable", false))


static func meta_color(m: int) -> int:
	return m % 16


static func meta_facing(m: int) -> int:
	return (m / 16) % 4


static func meta_valid(m: int) -> bool:
	return m >= 0 and m < META_MAX and m % 16 < COLOR_COUNT


## دشمنان وحشی در جهان آزاد (پروتکل ۴۷): شب‌ها نزدیک بازیکن‌ها پیدا می‌شوند و با سپیده‌دم می‌روند.
## در جهان خلاقانه، میدان مرکزی، داخل ساختمان/معدن و حین بازی‌ساز دشمنی نیست.
const WILD_KINDS := {
	"wolf": {"hp": 3, "speed": 3.6, "dmg": 6.0, "cd": 1.2, "reach": 1.4, "money": 6, "drop": "", "drop_chance": 0.0},
	"ghoul": {"hp": 6, "speed": 2.3, "dmg": 11.0, "cd": 1.6, "reach": 1.5, "money": 18, "drop": "iron", "drop_chance": 0.3},
}
const WILD_NIGHT_START := 20.0       # ساعت شروع شب
const WILD_NIGHT_END := 5.0          # ساعت پایان شب
const WILD_PER_PLAYER := 2           # حداکثر دشمن نزدیک هر بازیکن
const WILD_GLOBAL_MAX := 12
const WILD_SPAWN_EVERY := 5.0        # ثانیه
const WILD_SPAWN_MIN := 24.0
const WILD_SPAWN_MAX := 38.0
const WILD_DESPAWN_DIST := 70.0
const WILD_SAFE_RADIUS := 45.0       # دور میدان مرکزی/نقطهٔ زایش امن است
const WILD_AGGRO := 45.0             # دشمن فقط تا این فاصله بازیکن را دنبال می‌کند (بیشتر از فاصلهٔ زایش)
const WILD_SEND_EVERY := 0.25
const PLAYER_HP_MAX := 100.0
const PLAYER_HP_REGEN := 1.5         # در ثانیه، پس از ۶ ثانیه بدون آسیب
const PLAYER_HP_REGEN_DELAY := 6.0
const PLAYER_ATTACK_RANGE := 2.6
const PLAYER_ATTACK_CD := 0.7
const GEAR_WEAPON_DAMAGE := [1, 2, 3]            # مشت، چماق، شمشیر (ضربه‌های هر حمله)
const GEAR_ARMOR_REDUCE := [0.0, 0.25, 0.5]      # بدون زره، جلیقه، زره آهنی
const DEATH_MONEY_LOSS_FRAC := 0.1
const DEATH_MONEY_LOSS_MAX := 50
