extends RefCounted
## سازندهٔ شخصیت (پروتکل ۵۵، مرحلهٔ ۶ سند). فقط روی سرور؛ بدون اینترنت و بدون مدل زبانی.
## بازیکن (مدیر یا جهان خلاقانه) شخصیت دلخواه می‌سازد: نام، نقش (یکی از پنج تیپ پایه)، هشت ویژگی، هدف اصلی زندگی،
## سبک اقتصادی/نظامی و رابطهٔ اولیه با خودش. شخصیت ساخته‌شده همان NPC مستقل مرحلهٔ ۱ است و همهٔ اقدام‌هایش
## از توابع معتبر بازیکن می‌گذرد. قالب‌ها (تا ۸ تا) همراه ذخیرهٔ جهان می‌مانند و دوباره قابل استفاده یا ویرایش‌اند.

const Personality = preload("res://scripts/server/char_personality.gd")
const Memory = preload("res://scripts/server/char_memory.gd")
const CharAI = preload("res://scripts/server/char_ai.gd")

const TEMPLATES_MAX := 8


## ساخت شخصیت از مشخصات (پس از پاک‌سازی). creator = نام حساب سازنده برای رابطهٔ اولیه.
static func create(cs, raw_spec: Variant, creator: String) -> Dictionary:
	var spec: Dictionary = Personality.clean_spec(raw_spec)
	var res: Dictionary = CharAI.spawn(cs, str(spec["arch"]), str(spec["name"]))
	if not bool(res["ok"]):
		return res
	var npc: Dictionary = res["npc"]
	_apply(cs, npc, spec)
	Memory.set_initial(npc["ai"], creator, str(spec["rel"]), cs.day_count)
	cs._log("ai:%d" % int(npc["id"]), "ai_custom", {"arch": spec["arch"], "rel": spec["rel"]})
	return res


## ویژگی‌ها، هدف و سبک را روی شخصیت می‌نشاند. ویژگی‌های انتخابی «پایه» می‌شوند تا یادگیری فقط ±۰٫۲۵ از آن‌ها دور شود.
static func _apply(_cs, npc: Dictionary, spec: Dictionary) -> void:
	var ai: Dictionary = npc["ai"]
	ai["custom"] = true
	ai["traits"] = (spec["traits"] as Dictionary).duplicate()
	ai["base"] = (spec["traits"] as Dictionary).duplicate()
	ai["life"] = str(spec["life"])
	ai["bw"] = Personality.style_weights(str(spec["arch"]), str(spec["style"]))
	ai["learned"] = 0
	# هدف‌ها و برنامهٔ قبلی کنار می‌رود تا با ویژگی‌های جدید دوباره رتبه‌بندی شود.
	ai["goals"] = []
	ai["plan"] = []
	ai["active"] = {}
	ai["w"] = 0.0
	ai["t"] = 0.0


## ویرایش شخصیت موجود (فقط شخصیت هوشمند). حافظه، روابط، دارایی و ساخته‌هایش دست‌نخورده می‌ماند.
static func edit(cs, npc_id: int, raw_spec: Variant) -> Dictionary:
	var npc: Dictionary = {}
	for n in cs.npcs:
		if int(n["id"]) == npc_id:
			npc = n
			break
	if npc.is_empty() or not CharAI.is_ai(npc):
		return {"ok": false, "error": "bad_request"}
	var spec: Dictionary = Personality.clean_spec(raw_spec)
	# نقش (تیپ پایه) عوض نمی‌شود: جنگ و قیمت‌گذاری به آن وابسته است و حافظه با آن ساخته شده.
	spec["arch"] = str(npc["ai"]["arch"])
	if str(spec["name"]) != "":
		npc["name"] = str(spec["name"])
	var keep: Dictionary = {"mem": npc["ai"]["mem"], "war": npc["ai"]["war"], "allies": npc["ai"]["allies"], "stats": npc["ai"]["stats"], "seen": npc["ai"]["seen"]}
	_apply(cs, npc, spec)
	for k in keep:
		npc["ai"][k] = keep[k]
	cs._log(str(npc.get("acct", "")), "ai_edit", {"id": npc_id})
	return {"ok": true, "npc": npc}


# ---------------- قالب‌ها ----------------

static func save_template(cs, raw_spec: Variant) -> Dictionary:
	if cs.ai_templates.size() >= TEMPLATES_MAX:
		return {"ok": false, "error": "ai_tpl_full"}
	var spec: Dictionary = Personality.clean_spec(raw_spec)
	if str(spec["name"]) == "":
		spec["name"] = Personality.pick_name(str(spec["arch"]), cs.ai_templates.size() + 1)
	cs.ai_templates.append(spec)
	return {"ok": true, "spec": spec}


static func delete_template(cs, idx: int) -> Dictionary:
	if idx < 0 or idx >= cs.ai_templates.size():
		return {"ok": false, "error": "bad_request"}
	cs.ai_templates.remove_at(idx)
	return {"ok": true}


static func spawn_template(cs, idx: int, creator: String) -> Dictionary:
	if idx < 0 or idx >= cs.ai_templates.size():
		return {"ok": false, "error": "bad_request"}
	return create(cs, cs.ai_templates[idx], creator)


static func load_templates(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for e in (raw as Array).slice(0, TEMPLATES_MAX):
			if e is Dictionary:
				out.append(Personality.clean_spec(e))
	return out
