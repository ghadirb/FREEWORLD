extends RefCounted
## حافظه و روابط شخصیت‌های هوشمند مستقل (پروتکل ۵۴، مرحلهٔ ۳). فقط روی سرور.
## حافظه متن آزاد نیست؛ ساختارمند و کوچک است و در فایل ذخیره می‌آید:
##   ai["mem"] = {
##     "rel":    {حساب: {trust, friend, enemy, respect, fear, debt, coop, betray, d}},   # روابط
##     "events": [{d, k, w, s}],   # رویدادهای مهم (سقف EVENTS_MAX)؛ کم‌اهمیت‌ترین و قدیمی‌ترین حذف می‌شود
##     "tally":  {نوع: تعداد},     # رویدادهای کم‌اهمیت فقط شمرده می‌شوند (تجمیع)
##   }
## ویژگی‌های شخصیت واقعاً اثر دارند: هرچه اعتمادپذیرتر، دیرتر اعتماد پس می‌دهد ولی زودتر می‌بخشد؛
## هرچه پرخاشگرتر، کینه‌اش عمیق‌تر و ماندگارتر است. پس دو تیپ مختلف یک رویداد را متفاوت به خاطر می‌سپارند.

const REL_KEYS := ["trust", "friend", "enemy", "respect", "fear"]
const EVENTS_MAX := 16
const REL_MAX := 12             # حداکثر تعداد طرف‌های ثبت‌شده در حافظهٔ هر شخصیت
const IMPORTANT := 0.35         # رویداد با اهمیت بیشتر از این در فهرست رویدادها می‌ماند
const KINDS := ["talk", "gift", "trade", "demolish", "betray", "help", "chat", "quarrel", "alliance"]

const STANCES := ["ally", "friend", "neutral", "wary", "enemy"]


static func fresh() -> Dictionary:
	return {"rel": {}, "events": [], "tally": {}}


static func _new_rel(ai: Dictionary) -> Dictionary:
	# اعتماد اولیه از ویژگی اعتمادپذیری می‌آید: غریبه برای حیله‌گر مشکوک‌تر از معامله‌گر است.
	var t: float = float((ai["traits"] as Dictionary).get("trust", 0.5))
	return {"trust": snappedf(t * 0.3, 0.001), "friend": 0.0, "enemy": 0.0, "respect": 0.0, "fear": 0.0,
		"debt": 0, "coop": 0, "betray": 0, "d": 0}


static func _rel(ai: Dictionary, who: String, day: int) -> Dictionary:
	var rel: Dictionary = ai["mem"]["rel"]
	if not rel.has(who):
		if rel.size() >= REL_MAX:
			# جای تازه: ضعیف‌ترین رابطه (کم‌اهمیت‌ترین طرف) را فراموش کن
			var weakest := ""
			var ws := INF
			for k in rel:
				var r: Dictionary = rel[k]
				var w: float = float(r["friend"]) + float(r["enemy"]) + float(r["trust"]) + float(int(r["betray"])) * 2.0
				if w < ws:
					ws = w
					weakest = str(k)
			rel.erase(weakest)
		var nr := _new_rel(ai)
		nr["d"] = day
		rel[who] = nr
	_decay(ai, rel[who], day)
	return rel[who]


## فراموشی تدریجی: دوستی و دشمنی با گذر روز کم می‌شود. پرخاشگر کینه‌اش را بیشتر نگه می‌دارد،
## همکارجو زودتر می‌بخشد. خیانت و بدهی هیچ‌وقت خودبه‌خود پاک نمی‌شوند.
static func _decay(ai: Dictionary, r: Dictionary, day: int) -> void:
	var days: int = clampi(day - int(r["d"]), 0, 60)
	r["d"] = day
	if days <= 0:
		return
	var t: Dictionary = ai["traits"]
	var enemy_keep: float = 0.97 + 0.025 * float(t["aggression"]) - 0.015 * float(t["cooperation"])   # ضریب روزانه
	enemy_keep = clampf(enemy_keep, 0.9, 0.995)
	r["enemy"] = snappedf(float(r["enemy"]) * pow(enemy_keep, float(days)), 0.001)
	r["friend"] = snappedf(float(r["friend"]) * pow(0.985, float(days)), 0.001)
	r["fear"] = snappedf(float(r["fear"]) * pow(0.95, float(days)), 0.001)


static func _bump(r: Dictionary, key: String, v: float) -> void:
	r[key] = snappedf(clampf(float(r[key]) + v, 0.0, 1.0), 0.001)


## امتیاز نگرش بین -۱ و ۱ (مثبت = دوست‌داشتن). خیانت‌ها همیشه سنگین حساب می‌شوند.
static func attitude(ai: Dictionary, who: String, day: int) -> float:
	var rel: Dictionary = ai["mem"]["rel"]
	if not rel.has(who):
		return 0.0
	var r: Dictionary = _rel(ai, who, day)
	var s: float = float(r["friend"]) * 0.5 + float(r["trust"]) * 0.3 + float(r["respect"]) * 0.1 \
		- float(r["enemy"]) * 0.7 - float(mini(int(r["betray"]), 3)) * 0.15 - float(r["fear"]) * 0.1
	return clampf(s, -1.0, 1.0)


static func stance(ai: Dictionary, who: String, day: int) -> String:
	var s := attitude(ai, who, day)
	if s >= 0.55:
		return "ally"
	if s >= 0.2:
		return "friend"
	if s > -0.15:
		return "neutral"
	if s > -0.4:
		return "wary"
	return "enemy"


## ضریب قیمت برای معامله با این طرف: دوست مهربان‌تر، دشمن سخت‌گیرتر. معامله‌گر به رابطه کمتر وابسته است.
static func price_factor(ai: Dictionary, who: String, day: int) -> float:
	var s := attitude(ai, who, day)
	var weight: float = 0.35 if str(ai["arch"]) == "trader" else 0.5
	return clampf(1.0 + s * weight, 0.7, 1.3)


## ثبت یک رویداد. strength بین ۰ و ۱. بازگشت: ساختار خلاصهٔ اثر برای تست و گزارش.
static func record(ai: Dictionary, kind: String, who: String, strength: float, day: int) -> Dictionary:
	if not (ai.get("mem", null) is Dictionary) or who == "" or not (kind in KINDS):
		return {}
	var t: Dictionary = ai["traits"]
	var s: float = clampf(strength, 0.0, 1.0)
	var r: Dictionary = _rel(ai, who, day)
	var before := stance(ai, who, day)
	var trust_gain: float = 0.6 + 0.8 * float(t["trust"])                 # اعتمادپذیر زود اعتماد می‌کند
	var grudge: float = 0.7 + 0.6 * float(t["aggression"])               # پرخاشگر عمیق‌تر کینه می‌گیرد
	var importance: float = s
	match kind:
		"talk":
			_bump(r, "friend", 0.02 * trust_gain)
			_bump(r, "trust", 0.01 * trust_gain)
			importance = 0.05
		"gift":
			_bump(r, "friend", (0.06 + 0.15 * s) * trust_gain)
			_bump(r, "trust", (0.03 + 0.08 * s) * trust_gain)
			_bump(r, "respect", 0.02 * s)
			r["debt"] = int(r["debt"]) + int(round(s * 10.0))        # احساس بدهکاری
			importance = 0.2 + 0.4 * s
		"trade":
			_bump(r, "trust", 0.03 * trust_gain)
			_bump(r, "respect", 0.02)
			r["coop"] = int(r["coop"]) + 1
			importance = 0.1 + 0.25 * s
		"help":
			_bump(r, "friend", 0.12 * trust_gain)
			_bump(r, "trust", 0.1 * trust_gain)
			_bump(r, "respect", 0.05)
			r["coop"] = int(r["coop"]) + 1
			importance = 0.5
		"chat":
			_bump(r, "friend", 0.07 * trust_gain)
			_bump(r, "trust", 0.05 * trust_gain)
			importance = 0.08
		"quarrel":
			_bump(r, "enemy", (0.12 + 0.2 * s) * grudge)
			_bump(r, "trust", -0.08)
			_bump(r, "friend", -0.1)
			importance = 0.25 + 0.2 * s
		"alliance":
			_bump(r, "friend", 0.15)
			_bump(r, "trust", 0.15)
			_bump(r, "respect", 0.1)
			importance = 0.7
		"demolish":
			_bump(r, "enemy", (0.35 + 0.4 * s) * grudge)
			_bump(r, "trust", -(0.3 + 0.3 * s))
			_bump(r, "friend", -0.3)
			# ترس از طرف مقابل: شجاع کمتر می‌ترسد
			_bump(r, "fear", 0.15 * (1.0 - float(t["bravery"])))
			importance = 0.6 + 0.3 * s
		"betray":
			r["betray"] = int(r["betray"]) + 1
			_bump(r, "enemy", (0.5 + 0.3 * s) * grudge)
			_bump(r, "trust", -0.6)
			_bump(r, "friend", -0.5)
			importance = 0.9
	# اعتماد و دوستی منفی را به صفر می‌بریم؛ وقتی trust کاهش یافته، با bump به ۰ گیر می‌کند.
	var tally: Dictionary = ai["mem"]["tally"]
	tally[kind] = int(tally.get(kind, 0)) + 1
	if importance >= IMPORTANT:
		_remember(ai, {"d": day, "k": kind, "w": who, "s": snappedf(importance, 0.01)})
	return {"kind": kind, "who": who, "before": before, "after": stance(ai, who, day), "importance": importance}


static func _remember(ai: Dictionary, e: Dictionary) -> void:
	var ev: Array = ai["mem"]["events"]
	ev.append(e)
	while ev.size() > EVENTS_MAX:
		# کم‌اهمیت‌ترین (و در برابری، قدیمی‌ترین) رویداد فراموش می‌شود؛ خیانت‌ها هرگز پیش از بقیه حذف نمی‌شوند.
		var drop := 0
		var ds := INF
		for i in ev.size():
			var sc: float = float(ev[i]["s"]) + (1.0 if str(ev[i]["k"]) == "betray" else 0.0)
			if sc < ds:
				ds = sc
				drop = i
		ev.remove_at(drop)


## آیا این شخصیت رویداد مهمی از این نوع با این طرف به خاطر دارد؟
static func remembers(ai: Dictionary, who: String, kind: String) -> bool:
	if not (ai.get("mem", null) is Dictionary):
		return false
	for e in ai["mem"]["events"]:
		if str(e["w"]) == who and str(e["k"]) == kind:
			return true
	return false


## یادگیری از نتیجهٔ برنامه‌ها (مرحلهٔ ۳): شکست‌های پی‌درپی محتاط‌ترش می‌کند، موفقیت‌ها جسورتر.
## تغییر کوچک و محدود است تا تیپ شخصیت هرگز کامل عوض نشود (حداکثر ±۰٫۲۵ از مقدار پایهٔ تیپ).
static func learn(ai: Dictionary, success: bool, base_traits: Dictionary) -> void:
	var t: Dictionary = ai["traits"]
	var d := 0.012
	if success:
		_shift(t, "caution", -d * 0.5, base_traits)
		_shift(t, "risk", d, base_traits)
		_shift(t, "bravery", d * 0.5, base_traits)
	else:
		_shift(t, "caution", d, base_traits)
		_shift(t, "risk", -d, base_traits)
	ai["learned"] = int(ai.get("learned", 0)) + 1


static func _shift(t: Dictionary, key: String, delta: float, base: Dictionary) -> void:
	var b: float = float(base[key])
	t[key] = snappedf(clampf(float(t[key]) + delta, maxf(0.0, b - 0.25), minf(1.0, b + 0.25)), 0.001)


# ---------------- ذخیره و بازیابی ----------------

## بازیابی ایمن: هر مقدار نامعتبر به مقدار مجاز برمی‌گردد و ساختار بزرگ‌تر از سقف بریده می‌شود.
static func load_mem(raw: Variant, ai: Dictionary) -> Dictionary:
	var m := fresh()
	if not (raw is Dictionary):
		return m
	var rr: Variant = raw.get("rel", {})
	if rr is Dictionary:
		for who in rr.keys():
			if m["rel"].size() >= REL_MAX:
				break
			var src: Variant = rr[who]
			if not (src is Dictionary):
				continue
			var r := _new_rel(ai)
			for k in REL_KEYS:
				r[k] = snappedf(clampf(float(src.get(k, r[k])), 0.0, 1.0), 0.001)
			r["debt"] = clampi(int(src.get("debt", 0)), 0, 100000)
			r["coop"] = clampi(int(src.get("coop", 0)), 0, 100000)
			r["betray"] = clampi(int(src.get("betray", 0)), 0, 1000)
			r["d"] = maxi(0, int(src.get("d", 0)))
			m["rel"][str(who).substr(0, 40)] = r
	var re: Variant = raw.get("events", [])
	if re is Array:
		for e in re.slice(0, EVENTS_MAX):
			if e is Dictionary and str(e.get("k", "")) in KINDS:
				m["events"].append({"d": maxi(0, int(e.get("d", 0))), "k": str(e["k"]), "w": str(e.get("w", "")).substr(0, 40),
					"s": snappedf(clampf(float(e.get("s", 0.0)), 0.0, 1.0), 0.01)})
	var rt: Variant = raw.get("tally", {})
	if rt is Dictionary:
		for k in KINDS:
			if rt.has(k):
				m["tally"][k] = clampi(int(rt[k]), 0, 1000000)
	return m
