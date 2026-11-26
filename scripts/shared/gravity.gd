extends RefCounted
## جاذبه و پرش: کلاینت برای شبیه‌سازی کمان پرش و سرور برای سقف مجاز ارتفاع از همین توابع استفاده می‌کنند.
## سرعت پرش در همهٔ اقلیم‌ها یکی است؛ جاذبهٔ ماه حدود یک‌ششم زمین است، پس پرش حدود ۶ برابر بلندتر و طولانی‌تر می‌شود.

const EARTH_G := 9.8
const MOON_G := 1.62
const JUMP_SPEED := 3.6  # متر بر ثانیهٔ رو به بالا هنگام پرش
const SERVER_SLACK := 0.25  # حاشیهٔ تأخیر شبکه برای سقف ارتفاعی که سرور می‌پذیرد


static func g(climate: String) -> float:
	return MOON_G if climate == "moon" else EARTH_G


## بیشینهٔ ارتفاع یک پرش (متر).
static func max_height(climate: String) -> float:
	return JUMP_SPEED * JUMP_SPEED / (2.0 * g(climate))


## مدت هوا ماندن یک پرش (ثانیه).
static func air_time(climate: String) -> float:
	return 2.0 * JUMP_SPEED / g(climate)


## بالاترین ارتفاعی که سرور از یک بازیکن غیرپرواز می‌پذیرد.
static func server_cap(climate: String) -> float:
	return max_height(climate) + SERVER_SLACK


static func is_low_gravity(climate: String) -> bool:
	return g(climate) < EARTH_G * 0.5
