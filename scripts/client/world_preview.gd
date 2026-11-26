extends RefCounted
## پیش‌نمایش واقعی یک جهان آماده: همان زمین قطعی Seed و همان سازه‌هایی که پس از ورود می‌سازند،
## از بالا و با سایه‌روشن ارتفاع نقاشی می‌شود (بدون عکس ثابت؛ هر جهان دقیقاً خودش را نشان می‌دهد).

const WorldGenerator = preload("res://scripts/world/world_generator.gd")
const Scenarios = preload("res://scripts/shared/scenarios.gd")

const W := 192
const H := 148
## پنجرهٔ نمایش (متر) دور مرکز شهر.
const SPAN_X := 130.0
const SPAN_Z := 100.0

const BLOCK_COLORS := {
	"dirt": Color("8a6038"), "wood": Color("a9743f"), "stone": Color("8d9096"), "brick": Color("b4533a"),
	"glass": Color("a8dcf0"), "window": Color("7fb6d4"), "door": Color("5e3c1e"), "roof": Color("7a3b2a"),
	"fence": Color("c79a5a"), "road": Color("5c5d62"), "stairs": Color("b88450"), "lamp": Color("ffe27a"), "rail": Color("3a3a3e"),
}
const SKY := {"temperate": Color("6fb7e8"), "winter": Color("b9d3e8"), "desert": Color("f0c77a"), "moon": Color("1a1d2e")}

static var _cache: Dictionary = {}


## عکس سه‌بعدی واقعی بازی (assets/worlds/<id>.png، ساختهٔ --scenario/--focus) اگر هست؛ وگرنه نقشهٔ بالا.
static func photo_path(id: String) -> String:
	return "res://assets/worlds/%s.png" % id


static func texture(id: String) -> Texture2D:
	if not _cache.has(id):
		if ResourceLoader.exists(photo_path(id)):
			_cache[id] = load(photo_path(id))
		else:
			_cache[id] = ImageTexture.create_from_image(render(id))
	return _cache[id]


static func render(id: String, w: int = W, h: int = H) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var d: Dictionary = Scenarios.def(id)
	if d.is_empty():
		img.fill(Color("224455"))
		return img
	var gen := WorldGenerator.new(int(d["seed"]))
	gen.climate = Scenarios.climate(id)
	# بالاترین بلوک هر ستون سازه
	var top: Dictionary = {}
	for c in Scenarios.columns(id):
		var k := Vector2i(int(c[0]), int(c[1]))
		var t: int = int(c[2]) + int(c[3])
		if not top.has(k) or int(top[k][0]) < t:
			top[k] = [t, str(c[4])]
	var x0 := float(Scenarios.CENTER) - SPAN_X * 0.5
	var z0 := float(Scenarios.CENTER) - SPAN_Z * 0.5
	var step_x := SPAN_X / float(w)
	var step_z := SPAN_Z / float(h)
	for py in range(h):
		for px in range(w):
			var x := x0 + (float(px) + 0.5) * step_x
			var z := z0 + (float(py) + 0.5) * step_z
			var ht := gen.height_at(x, z)
			var biome := gen.biome_from(ht, gen.moisture_at(x, z))
			var col := WorldGenerator.biome_color(biome)
			# سایه‌روشن از شیب (نور از شمال‌غرب)
			var slope := gen.height_at(x - 1.5, z - 1.5) - gen.height_at(x + 1.5, z + 1.5)
			var lit := clampf(1.0 + slope * 0.09, 0.7, 1.3)
			if biome == "water":
				col = col.darkened(clampf(-ht * 0.08, 0.0, 0.35))
			else:
				col = Color(col.r * lit, col.g * lit, col.b * lit)
			var cell := Vector2i(int(floor(x)), int(floor(z)))
			if top.has(cell):
				var bc: Color = BLOCK_COLORS.get(str(top[cell][1]), Color("999999"))
				var tall := clampf(0.82 + float(top[cell][0]) * 0.04, 0.82, 1.2)
				col = Color(bc.r * tall, bc.g * tall, bc.b * tall)
			img.set_pixel(px, py, col)
	# محو شدن لبه‌ها به رنگ آسمان تا مثل تصویر قاب‌شده دیده شود
	var sky: Color = SKY.get(Scenarios.climate(id), SKY["temperate"])
	for py in range(h):
		for px in range(w):
			var e := minf(minf(float(px), float(w - 1 - px)) / 10.0, minf(float(py), float(h - 1 - py)) / 10.0)
			if e < 1.0:
				img.set_pixel(px, py, img.get_pixel(px, py).lerp(sky, (1.0 - e) * 0.35))
	return img


## شمارش‌های تبلیغاتی کارت: سازه، شهروند، حیوان.
static func stats(id: String) -> Dictionary:
	var d: Dictionary = Scenarios.def(id)
	var animals := 0
	for k in d.get("animals", {}):
		animals += int(d["animals"][k])
	return {"structures": (d.get("structures", []) as Array).size(), "npcs": int(d.get("npcs", 0)), "animals": animals, "trees": int(d.get("trees", 0))}
