extends RefCounted
## بستهٔ طرح‌های آماده (قلعه، روستا، شهرک): محتوای قابل فروش جدا از کتابخانهٔ شخصی.
## هر طرح با کد ساخته می‌شود (قطعی، بدون فایل داده) و خروجی‌اش دقیقاً همان قالب copy_region است:
## ۵ عدد برای هر بلوک [dx, dy, dz, شناسهٔ نوع، متا] با ابعاد حداکثر ۱۶ و حداکثر ۵۱۲ بلوک.
## استفادهٔ طرح همان مسیر چسباندن معمولی است (برد، مالکیت و مواد را سرور بررسی می‌کند)؛ این‌جا فقط داده است.
## متن‌ها در Loc: pack_<id>، pack_<id>_d و bpk_<id>.

const FWConst = preload("res://scripts/core/const.gd")

## بسته‌ها به ترتیب نمایش. premium = پس از اتصال درگاه پرداخت قفل می‌شود (الان همه باز است).
const PACKS := [
	{"id": "castle", "premium": true, "items": ["castle_keep", "castle_wall", "castle_gate", "castle_tower"]},
	{"id": "village", "premium": true, "items": ["village_house", "village_cottage", "village_well", "village_barn", "village_stall"]},
	{"id": "town", "premium": true, "items": ["town_shop_row", "town_hall", "town_plaza", "town_watch_tower"]},
]


static func ids() -> Array:
	var out: Array = []
	for p in PACKS:
		out.append(p["id"])
	return out


static func pack(id: String) -> Dictionary:
	for p in PACKS:
		if str(p["id"]) == id:
			return p
	return {}


static func is_premium(id: String) -> bool:
	return bool(pack(id).get("premium", false))


static func item_ids() -> Array:
	var out: Array = []
	for p in PACKS:
		out.append_array(p["items"])
	return out


## داده‌ٔ طرح؛ شناسهٔ ناشناخته ← آرایهٔ خالی.
static func build(item: String) -> PackedInt32Array:
	var b := _B.new()
	match item:
		"castle_keep": _keep(b)
		"castle_wall": _wall(b)
		"castle_gate": _gate(b)
		"castle_tower": _tower(b, 7, 12)
		"village_house": _house(b, 7, 5, 7, "wood", true)
		"village_cottage": _house(b, 5, 4, 5, "brick", false)
		"village_well": _well(b)
		"village_barn": _barn(b)
		"village_stall": _stall(b)
		"town_shop_row": _shop_row(b)
		"town_hall": _hall(b)
		"town_plaza": _plaza(b)
		"town_watch_tower": _tower(b, 5, 14)
		_: return PackedInt32Array()
	return b.data()


# ---------------- سازنده ----------------

class _B:
	var cells: Dictionary = {}

	func put(x: int, y: int, z: int, t: String, meta: int = 0) -> void:
		if x < 0 or y < 0 or z < 0 or x >= FWConst.REGION_MAX_SIDE or y >= FWConst.REGION_MAX_SIDE or z >= FWConst.REGION_MAX_SIDE:
			return
		cells[Vector3i(x, y, z)] = [FWConst.BLOCK_ORDER.find(t), meta]

	func box(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, t: String) -> void:
		for x in range(x0, x1 + 1):
			for y in range(y0, y1 + 1):
				for z in range(z0, z1 + 1):
					put(x, y, z, t)

	## فقط دیوارهای دور جعبه (بدون کف و سقف)
	func shell(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, t: String) -> void:
		for x in range(x0, x1 + 1):
			for y in range(y0, y1 + 1):
				for z in range(z0, z1 + 1):
					if x == x0 or x == x1 or z == z0 or z == z1:
						put(x, y, z, t)

	func clear(x: int, y: int, z: int) -> void:
		cells.erase(Vector3i(x, y, z))

	## کلاه هرمی از «سقف»، از ارتفاع y شروع می‌شود و هر لایه یک خانه کوچک‌تر می‌شود
	func pyramid(x0: int, z0: int, x1: int, z1: int, y: int) -> void:
		while x0 <= x1 and z0 <= z1:
			box(x0, y, z0, x1, y, z1, "roof")
			x0 += 1
			z0 += 1
			x1 -= 1
			z1 -= 1
			y += 1

	func crenels(x0: int, z0: int, x1: int, z1: int, y: int) -> void:
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				if x == x0 or x == x1 or z == z0 or z == z1:
					if (x + z) % 2 == 0:
						put(x, y, z, "fence")

	func data() -> PackedInt32Array:
		var out := PackedInt32Array()
		for v in cells:
			out.append_array(PackedInt32Array([v.x, v.y, v.z, int(cells[v][0]), int(cells[v][1])]))
		return out


# ---------------- قلعه ----------------

static func _keep(b: _B) -> void:
	b.shell(0, 0, 0, 12, 5, 12, "stone")
	b.box(0, 6, 0, 12, 6, 12, "stone")
	b.crenels(0, 0, 12, 12, 7)
	for t in [Vector2i(0, 0), Vector2i(12, 0), Vector2i(0, 12), Vector2i(12, 12)]:
		b.box(t.x, 6, t.y, t.x, 8, t.y, "stone")
		b.put(t.x, 9, t.y, "lamp")
	# در بزرگ و پنجره‌های باریک
	b.put(6, 0, 0, "door")
	b.put(6, 1, 0, "door")
	b.put(5, 0, 0, "stone")
	b.put(7, 0, 0, "stone")
	for x in [2, 4, 8, 10]:
		b.put(x, 3, 0, "window")
		b.put(x, 3, 12, "window")
	for z in [3, 6, 9]:
		b.put(0, 3, z, "window")
		b.put(12, 3, z, "window")
	b.put(6, 0, 11, "lamp")
	b.put(6, 5, 1, "lamp")


static func _wall(b: _B) -> void:
	b.box(0, 0, 0, 15, 4, 2, "stone")
	b.box(0, 5, 0, 15, 5, 2, "stone")
	for x in range(0, 16, 2):
		b.box(x, 6, 0, x, 6, 0, "stone")
		b.box(x, 6, 2, x, 6, 2, "stone")
	# چراغ‌دان‌های دیوار
	b.put(3, 6, 1, "lamp")
	b.put(12, 6, 1, "lamp")


static func _gate(b: _B) -> void:
	b.box(0, 0, 0, 8, 8, 4, "stone")
	# گذرگاه ۳ خانه‌ای و درِ بزرگ
	for y in range(0, 4):
		b.box(3, y, 0, 5, y, 4, "fence")
	for y in range(0, 4):
		for x in range(3, 6):
			for z in range(0, 5):
				b.clear(x, y, z)
	b.put(3, 0, 0, "door")
	b.put(3, 1, 0, "door")
	b.put(4, 0, 0, "door")
	b.put(4, 1, 0, "door")
	b.put(5, 0, 0, "door")
	b.put(5, 1, 0, "door")
	b.put(4, 2, 0, "window")
	b.crenels(0, 0, 8, 4, 9)
	b.put(1, 9, 2, "lamp")
	b.put(7, 9, 2, "lamp")


static func _tower(b: _B, side: int, height: int) -> void:
	var e := side - 1
	b.shell(0, 0, 0, e, height - 1, e, "stone")
	b.box(0, height, 0, e, height, e, "stone")
	b.crenels(0, 0, e, e, height + 1)
	var mid := e / 2
	b.put(mid, 0, 0, "door")
	b.put(mid, 1, 0, "door")
	var y := 3
	while y < height - 1:
		b.put(mid, y, 0, "window")
		b.put(mid, y, e, "window")
		b.put(0, y, mid, "window")
		b.put(e, y, mid, "window")
		y += 4
	b.put(mid, height + 2, mid, "lamp")


# ---------------- روستا ----------------

static func _house(b: _B, w: int, h: int, d: int, wall: String, porch: bool) -> void:
	b.shell(0, 0, 0, w - 1, h - 1, d - 1, wall)
	var mid := w / 2
	b.put(mid, 0, 0, "door")
	b.put(mid, 1, 0, "door")
	for x in range(1, w - 1):
		if x != mid and x % 2 == 1:
			b.put(x, 2 if h > 3 else 1, 0, "window")
			b.put(x, 2 if h > 3 else 1, d - 1, "window")
	for z in range(1, d - 1):
		if z % 2 == 1:
			b.put(0, 2 if h > 3 else 1, z, "window")
			b.put(w - 1, 2 if h > 3 else 1, z, "window")
	b.box(0, h, 0, w - 1, h, d - 1, "roof")
	b.pyramid(1, 1, w - 2, d - 2, h + 1)
	if porch:
		# پایه‌های ایوان دو طرف در و یک چراغ بالای آن
		b.put(mid - 1, 0, 0, "fence")
		b.put(mid + 1, 0, 0, "fence")
		b.put(mid, 3, 0, "lamp")


static func _well(b: _B) -> void:
	b.shell(0, 0, 0, 2, 0, 2, "stone")
	b.put(1, 0, 1, "dirt")
	for c in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]:
		b.box(c.x, 1, c.y, c.x, 3, c.y, "fence")
	b.box(0, 4, 0, 2, 4, 2, "roof")
	b.put(1, 5, 1, "roof")


static func _barn(b: _B) -> void:
	b.shell(0, 0, 0, 8, 4, 6, "wood")
	b.put(3, 0, 0, "door")
	b.put(3, 1, 0, "door")
	b.put(4, 0, 0, "door")
	b.put(4, 1, 0, "door")
	b.put(5, 0, 0, "door")
	b.put(5, 1, 0, "door")
	for z in [2, 4]:
		b.put(0, 2, z, "window")
		b.put(8, 2, z, "window")
	b.box(0, 5, 0, 8, 5, 6, "roof")
	b.pyramid(1, 1, 7, 5, 6)
	b.box(1, 0, 1, 2, 1, 2, "dirt")


static func _stall(b: _B) -> void:
	for c in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 2), Vector2i(4, 2)]:
		b.box(c.x, 0, c.y, c.x, 2, c.y, "fence")
	b.box(0, 3, 0, 4, 3, 2, "roof")
	b.box(1, 0, 0, 3, 0, 0, "wood")
	b.put(2, 3 + 1, 1, "lamp")


# ---------------- شهرک ----------------

static func _shop_row(b: _B) -> void:
	b.shell(0, 0, 0, 15, 4, 6, "brick")
	for x in [2, 7, 12]:
		b.put(x, 0, 0, "door")
		b.put(x, 1, 0, "door")
		b.put(x - 1, 1, 0, "window")
		b.put(x + 1, 1, 0, "window")
		b.put(x, 3, 0, "window")
	for x in [5, 10]:
		b.box(x, 0, 0, x, 4, 0, "stone")
	b.box(0, 5, 0, 15, 5, 6, "roof")
	for x in range(1, 15, 2):
		b.put(x, 6, 0, "fence")
		b.put(x, 6, 6, "fence")
	b.put(0, 6, 3, "lamp")
	b.put(15, 6, 3, "lamp")


static func _hall(b: _B) -> void:
	b.shell(0, 0, 0, 12, 4, 8, "stone")
	# پلهٔ ورودی (جادهٔ سنگ‌فرش) و در سه‌خانه‌ای
	b.box(4, 0, 0, 8, 0, 0, "road")
	for x in [5, 6, 7]:
		b.put(x, 0, 0, "door")
		b.put(x, 1, 0, "door")
	for x in [2, 10]:
		b.put(x, 2, 0, "window")
		b.put(x, 2, 8, "window")
	for z in [2, 4, 6]:
		b.put(0, 2, z, "window")
		b.put(12, 2, z, "window")
	b.pyramid(0, 0, 12, 8, 5)
	b.put(6, 10, 4, "lamp")


static func _plaza(b: _B) -> void:
	b.box(0, 0, 0, 14, 0, 14, "road")
	# حلقهٔ سنگی و ستون چراغ مرکزی
	b.shell(5, 0, 5, 9, 0, 9, "stone")
	for x in range(5, 10):
		b.put(x, 0, 5, "stone")
		b.put(x, 0, 9, "stone")
	b.box(7, 1, 7, 7, 4, 7, "stone")
	b.put(7, 5, 7, "lamp")
	for c in [Vector2i(0, 0), Vector2i(14, 0), Vector2i(0, 14), Vector2i(14, 14), Vector2i(7, 0), Vector2i(7, 14), Vector2i(0, 7), Vector2i(14, 7)]:
		b.box(c.x, 1, c.y, c.x, 2, c.y, "fence")
		b.put(c.x, 3, c.y, "lamp")
