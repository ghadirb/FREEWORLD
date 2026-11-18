extends RefCounted
## متن‌های رابط (فارسی پیش‌فرض، انگلیسی اختیاری) و تبدیل اعداد.

static var lang: String = "fa"

const FA := {
	"app_title": "جهان آزاد",
	"connect": "اتصال",
	"server": "آدرس سرور",
	"port": "پورت",
	"secret": "رمز حساب (فقط مدیران)",
	"player_name": "نام بازیکن",
	"connecting": "در حال اتصال…",
	"connect_failed": "اتصال به سرور برقرار نشد.",
	"disconnected": "ارتباط با سرور قطع شد.",
	"solo": "بازی تک‌نفره (آفلاین)",
	"host": "میزبانی بازی (Wi‑Fi / هات‌اسپات)",
	"join_title": "بازی‌های پیدا‌شده در این شبکه",
	"no_games": "بازی‌ای پیدا نشد. میزبان باید در همین Wi‑Fi یا هات‌اسپات باشد.",
	"join_manual": "اتصال دستی با آدرس",
	"players_count": "بازیکن",
	"host_started": "میزبانی فعال است",
	"host_ip": "آدرس شما برای دیگران",
	"host_keep_open": "برنامه را باز و صفحه را روشن نگه دارید.",
	"host_failed": "میزبانی شروع نشد. پورت ممکن است در حال استفاده باشد.",
	"offline_failed": "شروع بازی آفلاین ممکن نشد.",
	"offline_world": "جهان آفلاین",
	"language": "English",
	"quality": "کیفیت",
	"q_low": "کم",
	"q_med": "متوسط",
	"q_high": "بالا",
	"build": "ساخت",
	"life_mode": "حالت زندگی",
	"world_mode": "نمای شهر",
	"chat": "گفتگو",
	"send": "ارسال",
	"menu": "منو",
	"disconnect": "خروج از شهر",
	"back": "بازگشت",
	"confirm": "تأیید",
	"cancel": "لغو",
	"collect": "برداشت و فروش",
	"demolish": "تخریب",
	"owner": "مالک",
	"stock": "موجودی",
	"admin": "مدیریت",
	"audit": "گزارش اقدامات",
	"online": "آنلاین",
	"wheat_price": "قیمت گندم",
	"coins": "سکه",
	"role_player": "بازیکن",
	"role_city_admin": "مدیر شهر",
	"role_world_admin": "مدیر کل",
	"set_role": "تعیین نقش",
	"target_name": "نام بازیکن",
	"type_house": "خانه",
	"type_shop": "مغازه",
	"type_farm": "مزرعه",
	"type_road": "جاده",
	"type_well": "چاه",
	"state_sleep": "خواب",
	"state_work": "کار",
	"state_leisure": "تفریح",
	"state_walk": "در راه",
	"state_idle": "بیکار",
	"state_wake": "بیدار",
	"state_commute_work": "در راه کار",
	"state_commute_home": "در راه خانه",
	"tap_to_place": "روی زمین بزنید تا محل را انتخاب کنید",
	"ghost_ok": "محل پیشنهادی مناسب است. برای تغییر روی زمین بزنید، سپس تأیید.",
	"new_world": "جهان آفلاین جدید (حذف ذخیره)",
	"new_world_confirm": "مطمئنید؟ دوباره بزنید تا جهان آفلاین پاک شود.",
	"world_reset": "جهان آفلاین پاک شد.",
	"err_unknown_type": "نوع ساختمان نامعتبر است.",
	"err_out_of_bounds": "خارج از محدودهٔ شهر.",
	"err_occupied": "این محل پر است.",
	"err_reserved": "میدان مرکزی فقط برای مدیران است.",
	"err_water": "روی آب نمی‌شود ساخت.",
	"err_too_steep": "زمین بیش از حد شیب‌دار است.",
	"err_no_money": "سکهٔ کافی ندارید.",
	"err_limit": "به سقف تعداد ساختمان رسیده‌اید.",
	"err_forbidden": "اجازهٔ این کار را ندارید.",
	"err_too_far": "برای این کار باید نزدیک‌تر شوید.",
	"err_nothing": "هنوز محصولی آماده نیست.",
	"err_not_farm": "این ساختمان مزرعه نیست.",
	"err_no_building": "ساختمان پیدا نشد.",
	"err_rate_limited": "کمی آهسته‌تر!",
	"err_bad_token": "این نام قبلاً با رمز دیگری ثبت شده است.",
	"err_bad_name": "نام باید ۳ تا ۱۶ حرف یا عدد باشد.",
	"err_server_full": "ظرفیت سرور تکمیل است.",
	"err_server_busy": "سرور ثبت‌نام جدید نمی‌پذیرد.",
	"err_version": "نسخهٔ بازی با سرور سازگار نیست.",
	"err_not_ready": "هنوز آماده نیست.",
	"msg_collected": "%d گندم فروخته شد: +%d سکه",
	"msg_role_set": "نقش %s اکنون «%s» است.",
	"msg_your_building_removed": "یکی از ساختمان‌های شما توسط %s تخریب شد.",
	"msg_joined": "%s وارد شهر شد.",
	"msg_left": "%s از شهر رفت.",
	"chat_hint": "پیام…",
}

const EN := {
	"app_title": "FREEWORLD",
	"connect": "Connect",
	"server": "Server address",
	"port": "Port",
	"secret": "Account secret (admins only)",
	"player_name": "Player name",
	"connecting": "Connecting…",
	"connect_failed": "Could not reach the server.",
	"disconnected": "Disconnected from the server.",
	"solo": "Single player (offline)",
	"host": "Host a game (Wi-Fi / hotspot)",
	"join_title": "Games found on this network",
	"no_games": "No games found. The host must be on the same Wi-Fi or hotspot.",
	"join_manual": "Connect manually by address",
	"players_count": "players",
	"host_started": "Hosting is active",
	"host_ip": "Your address for others",
	"host_keep_open": "Keep the app open and the screen on.",
	"host_failed": "Could not start hosting. The port may be in use.",
	"offline_failed": "Could not start the offline game.",
	"offline_world": "Offline world",
	"language": "فارسی",
	"quality": "Quality",
	"q_low": "Low",
	"q_med": "Medium",
	"q_high": "High",
	"build": "Build",
	"life_mode": "Life mode",
	"world_mode": "City view",
	"chat": "Chat",
	"send": "Send",
	"menu": "Menu",
	"disconnect": "Leave city",
	"back": "Back",
	"confirm": "Confirm",
	"cancel": "Cancel",
	"collect": "Collect & sell",
	"demolish": "Demolish",
	"owner": "Owner",
	"stock": "Stock",
	"admin": "Admin",
	"audit": "Audit log",
	"online": "Online",
	"wheat_price": "Wheat price",
	"coins": "coins",
	"role_player": "Player",
	"role_city_admin": "City admin",
	"role_world_admin": "World admin",
	"set_role": "Set role",
	"target_name": "Player name",
	"type_house": "House",
	"type_shop": "Shop",
	"type_farm": "Farm",
	"type_road": "Road",
	"type_well": "Well",
	"state_sleep": "Sleeping",
	"state_work": "Working",
	"state_leisure": "Leisure",
	"state_walk": "Walking",
	"state_idle": "Idle",
	"state_wake": "Waking up",
	"state_commute_work": "Going to work",
	"state_commute_home": "Going home",
	"tap_to_place": "Tap the ground to choose a spot",
	"ghost_ok": "Suggested spot is valid. Tap the ground to move it, then confirm.",
	"new_world": "New offline world (erase save)",
	"new_world_confirm": "Sure? Tap again to erase the offline world.",
	"world_reset": "Offline world erased.",
	"err_unknown_type": "Unknown building type.",
	"err_out_of_bounds": "Outside the city limits.",
	"err_occupied": "That spot is taken.",
	"err_reserved": "The central plaza is for admins only.",
	"err_water": "You cannot build on water.",
	"err_too_steep": "The ground is too steep.",
	"err_no_money": "Not enough coins.",
	"err_limit": "Building limit reached.",
	"err_forbidden": "You are not allowed to do that.",
	"err_too_far": "Get closer to do that.",
	"err_nothing": "Nothing is ready yet.",
	"err_not_farm": "That is not a farm.",
	"err_no_building": "Building not found.",
	"err_rate_limited": "Slow down a little!",
	"err_bad_token": "That name is registered with a different secret.",
	"err_bad_name": "Name must be 3-16 letters or digits.",
	"err_server_full": "The server is full.",
	"err_server_busy": "The server is not accepting new accounts.",
	"err_version": "Game version does not match the server.",
	"err_not_ready": "Not ready yet.",
	"msg_collected": "Sold %d wheat: +%d coins",
	"msg_role_set": "%s is now «%s».",
	"msg_your_building_removed": "One of your buildings was demolished by %s.",
	"msg_joined": "%s entered the city.",
	"msg_left": "%s left the city.",
	"chat_hint": "Message…",
}


static func t(key: String) -> String:
	var table: Dictionary = FA if lang == "fa" else EN
	return table.get(key, key)


static func err(code: String) -> String:
	var key := "err_" + code
	var table: Dictionary = FA if lang == "fa" else EN
	return table.get(key, code)


static func fmt(key: String, args: Array) -> String:
	return t(key) % args


static func digits(s: String) -> String:
	if lang != "fa":
		return s
	var out := ""
	for ch in s:
		var c: int = ch.unicode_at(0)
		if c >= 48 and c <= 57:
			out += String.chr(0x06F0 + c - 48)
		else:
			out += ch
	return out


static func clock(world_time: float) -> String:
	var h := int(world_time / 3600.0) % 24
	var m := int(world_time / 60.0) % 60
	return digits("%02d:%02d" % [h, m])


static func role_name(role: String) -> String:
	return t("role_" + role)
