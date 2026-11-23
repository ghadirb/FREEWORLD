extends RefCounted
## مجوز باز بودن جهان‌های ویژه (پولی). تا وقتی درگاه پرداخت (بازار/مایکت) وصل نشده PAYMENTS_ENABLED خاموش است
## و همهٔ جهان‌ها باز می‌مانند تا کسی بدون راه خرید قفل نماند. بعد از اتصال درگاه فقط کافی است
## PAYMENTS_ENABLED را روشن کنید و پس از تأیید خرید unlock(id) را صدا بزنید. جهان‌های رایگان همیشه باز هستند.

const Settings = preload("res://scripts/client/settings.gd")
const Scenarios = preload("res://scripts/shared/scenarios.gd")

const PAYMENTS_ENABLED := false
const KEY := "unlocked_worlds"


static func is_unlocked(id: String) -> bool:
	if id == "" or not Scenarios.is_premium(id):
		return true
	if not PAYMENTS_ENABLED:
		return true
	var v = Settings.get_value(KEY, [])
	return typeof(v) == TYPE_ARRAY and (v as Array).has(id)


## فقط پس از تأیید خرید در درگاه صدا زده شود.
static func unlock(id: String) -> void:
	if not Scenarios.has(id):
		return
	var v = Settings.get_value(KEY, [])
	var arr: Array = v if typeof(v) == TYPE_ARRAY else []
	if not arr.has(id):
		arr.append(id)
		Settings.set_value(KEY, arr)
