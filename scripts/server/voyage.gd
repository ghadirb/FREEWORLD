extends RefCounted
## سفر بین سیاره‌ها (پروتکل ۵۹، docs/VOYAGE.md). هر سیاره یک جهان جدا با ذخیرهٔ خودش است؛
## موشک «بار مسافر» (پول، کالا، تجهیزات) را از جهان مبدأ برمی‌دارد و در جهان مقصد پس از ورود تحویل می‌دهد.
## کاملاً آفلاین و فقط برای مدیر جهان (تک‌نفره یا میزبان). هر بسته یک شناسهٔ یکتا دارد و فقط یک‌بار پذیرفته می‌شود.

const FWConst = preload("res://scripts/core/const.gd")

const MAX_MONEY := 1000000000
const MAX_KINDS := 24
const GEAR_MAX := {"weapon": 5, "armor": 2}


static func scenario_of(dest: String) -> String:
	return str(FWConst.VOYAGE_DESTS.get(dest, ""))


## بسته را از روی داده‌های نامطمئن (از کلاینت) پاک‌سازی می‌کند؛ نامعتبر = {}.
static func clean_pack(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var id := str(raw.get("id", ""))
	if id.is_empty() or id.length() > 64:
		return {}
	var inv: Dictionary = {}
	var src: Variant = raw.get("inv", {})
	if src is Dictionary:
		for k in src:
			if inv.size() >= MAX_KINDS:
				break
			var key := str(k)
			var n := clampi(int(src[k]), 0, FWConst.ITEM_CAP)
			if FWConst.ITEMS.has(key) and n > 0:
				inv[key] = n
	var gear := {"weapon": 0, "armor": 0}
	var g: Variant = raw.get("gear", {})
	if g is Dictionary:
		for slot in GEAR_MAX:
			gear[slot] = clampi(int(g.get(slot, 0)), 0, int(GEAR_MAX[slot]))
	return {"id": id, "money": clampi(int(raw.get("money", 0)), 0, MAX_MONEY), "inv": inv, "gear": gear}


## شناسهٔ بسته‌های پذیرفته‌شده (برای جلوگیری از ثبت تکراری)، حداکثر VOYAGE_DONE_KEEP.
static func load_done(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for v in raw:
			var s := str(v)
			if not s.is_empty() and s.length() <= 64 and out.size() < FWConst.VOYAGE_DONE_KEEP:
				out.append(s)
	return out


## شروع سفر: هزینه گرفته می‌شود و کالا و پول بازیکن به بسته منتقل می‌شود (جابه‌جایی، نه کپی).
static func depart(cs, actor: String, dest: String) -> Dictionary:
	if not cs.accounts.has(actor):
		return {"ok": false, "error": "bad_request"}
	if not FWConst.is_admin(cs.role_of(actor)):
		return {"ok": false, "error": "forbidden"}
	if not FWConst.VOYAGE_DESTS.has(dest):
		return {"ok": false, "error": "bad_request"}
	if scenario_of(dest) == str(cs.scenario):
		return {"ok": false, "error": "voyage_same"}
	var acc: Dictionary = cs.accounts[actor]
	if not cs.creative:
		if not cs.has_items(acc["inv"], FWConst.VOYAGE_COST):
			return {"ok": false, "error": "no_items"}
		if int(acc["money"]) < FWConst.VOYAGE_FEE:
			return {"ok": false, "error": "no_money"}
		for item in FWConst.VOYAGE_COST:
			acc["inv"][item] = int(acc["inv"][item]) - int(FWConst.VOYAGE_COST[item])
		acc["money"] = int(acc["money"]) - FWConst.VOYAGE_FEE
	var pack := {"id": "%d-%d" % [Time.get_ticks_usec(), randi()], "money": 0, "inv": {}, "gear": {"weapon": 0, "armor": 0}}
	if not cs.creative:
		pack["money"] = clampi(int(acc["money"]), 0, MAX_MONEY)
		for k in acc["inv"]:
			var n := clampi(int(acc["inv"][k]), 0, FWConst.ITEM_CAP)
			if FWConst.ITEMS.has(str(k)) and n > 0:
				pack["inv"][str(k)] = n
		acc["money"] = int(acc["money"]) - int(pack["money"])
		acc["inv"] = {}
	var g := cs.gear_of(acc)
	pack["gear"] = {"weapon": int(g["weapon"]), "armor": int(g["armor"])}
	cs._log(actor, "voyage_depart", {"dest": dest})
	return {"ok": true, "dest": dest, "pack": pack}


## ورود به جهان مقصد: بسته پاک‌سازی، تکراری‌بودنش بررسی و محتوا به حساب افزوده می‌شود.
static func arrive(cs, actor: String, raw_pack: Variant) -> Dictionary:
	if not cs.accounts.has(actor):
		return {"ok": false, "error": "bad_request"}
	if not FWConst.is_admin(cs.role_of(actor)):
		return {"ok": false, "error": "forbidden"}
	var pack := clean_pack(raw_pack)
	if pack.is_empty():
		return {"ok": false, "error": "bad_request"}
	var acc: Dictionary = cs.accounts[actor]
	var done: Array = load_done(acc.get("voyages", []))
	if done.has(str(pack["id"])):
		return {"ok": false, "error": "voyage_duplicate"}
	if not cs.creative:
		acc["money"] = mini(int(acc["money"]) + int(pack["money"]), MAX_MONEY)
		for k in pack["inv"]:
			acc["inv"][k] = mini(int(acc["inv"].get(k, 0)) + int(pack["inv"][k]), FWConst.ITEM_CAP)
		var g: Dictionary = cs.gear_of(acc)
		acc["gear"] = {"weapon": maxi(int(g["weapon"]), int(pack["gear"]["weapon"])), "armor": maxi(int(g["armor"]), int(pack["gear"]["armor"]))}
	done.append(str(pack["id"]))
	if done.size() > FWConst.VOYAGE_DONE_KEEP:
		done = done.slice(done.size() - FWConst.VOYAGE_DONE_KEEP)
	acc["voyages"] = done
	cs._log(actor, "voyage_arrive", {"money": int(pack["money"])})
	return {"ok": true}
