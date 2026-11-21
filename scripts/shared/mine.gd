extends RefCounted
## معدن زیرزمینی: شبکهٔ تونل و سنگ‌های معدن، قطعی از روی Seed و مختصات ورودی.
## سرور و کلاینت یک نتیجهٔ یکسان می‌گیرند؛ فقط وضعیت «برداشت‌شده» جداگانه ذخیره و همگام می‌شود.
## مختصات معدن محلی است: x و z از ۰ تا SIZE×TILE و کف در y=۰ (مستقل از جهان بیرون).

const FWConst = preload("res://scripts/core/const.gd")

const ROOMS := FWConst.MINE_ROOMS
const SIZE := FWConst.MINE_ROOMS * 2 + 1
const TILE := FWConst.MINE_TILE
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

static var _cache: Dictionary = {}


## مولد اعداد شبه‌تصادفی صحیح؛ فقط عملیات ۶۴ بیتی صحیح (مستقل از پلتفرم).
class Rng extends RefCounted:
	var s: int

	func _init(seed_in: int) -> void:
		s = seed_in & 0x7fffffff
		if s == 0:
			s = 1
		for _i in range(4):
			next()

	func next() -> int:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		return s >> 8

	func below(n: int) -> int:
		return next() % maxi(n, 1)

	func chance(p: float) -> bool:
		return float(next() % 10000) / 10000.0 < p


static func mine_id(mx: int, mz: int) -> String:
	return "%d,%d" % [mx, mz]


static func parse_id(id: String) -> Vector2i:
	var parts: PackedStringArray = id.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-99999, -99999)
	return Vector2i(int(parts[0]), int(parts[1]))


static func _mix(seed_value: int, mx: int, mz: int) -> int:
	var sv: int = absi(seed_value) % 2147483647
	return ((sv * 73856093) ^ ((mx + 1000) * 19349663) ^ ((mz + 1000) * 83492791)) & 0x7fffffff


static func tile_index(tx: int, tz: int) -> int:
	return tz * SIZE + tx


static func tile_open(l: Dictionary, tx: int, tz: int) -> bool:
	if tx < 0 or tz < 0 or tx >= SIZE or tz >= SIZE:
		return false
	return int(l["tiles"][tz * SIZE + tx]) == 1


static func tile_center(tx: int, tz: int) -> Vector2:
	return Vector2((float(tx) + 0.5) * TILE, (float(tz) + 0.5) * TILE)


## نقطهٔ ورود/خروج (مرکز کاشی ورودی). ورودی در ضلع جنوبی (z بزرگ) است.
static func spawn_point(l: Dictionary) -> Vector2:
	var e: Vector2i = l["entry"]
	return tile_center(e.x, e.y)


## آیا شخصیت می‌تواند در این نقطه بایستد؟ کاشی باید باز باشد و از دیوار و گوشه‌ها فاصله داشته باشد.
static func walkable(l: Dictionary, x: float, z: float) -> bool:
	if not (is_finite(x) and is_finite(z)):
		return false
	var tx := int(floor(x / TILE))
	var tz := int(floor(z / TILE))
	if not tile_open(l, tx, tz):
		return false
	var fx := x - float(tx) * TILE
	var fz := z - float(tz) * TILE
	var m := FWConst.MINE_MARGIN
	var hi := TILE - m
	if fx < m and not tile_open(l, tx - 1, tz):
		return false
	if fx > hi and not tile_open(l, tx + 1, tz):
		return false
	if fz < m and not tile_open(l, tx, tz - 1):
		return false
	if fz > hi and not tile_open(l, tx, tz + 1):
		return false
	if fx < m and fz < m and not tile_open(l, tx - 1, tz - 1):
		return false
	if fx > hi and fz < m and not tile_open(l, tx + 1, tz - 1):
		return false
	if fx < m and fz > hi and not tile_open(l, tx - 1, tz + 1):
		return false
	if fx > hi and fz > hi and not tile_open(l, tx + 1, tz + 1):
		return false
	return true


static func _open_neighbors(l_tiles: PackedByteArray, tx: int, tz: int) -> int:
	var n := 0
	for d in DIRS:
		var x: int = tx + d.x
		var z: int = tz + d.y
		if x >= 0 and z >= 0 and x < SIZE and z < SIZE and int(l_tiles[z * SIZE + x]) == 1:
			n += 1
	return n


## چیدمان کامل یک معدن: {tiles, dist, entry, nodes, max_dist}. نتیجه کش می‌شود.
static func layout(seed_value: int, mx: int, mz: int) -> Dictionary:
	var key := "%d:%d:%d" % [seed_value, mx, mz]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 64:
		_cache.clear()
	var l := _generate(seed_value, mx, mz)
	_cache[key] = l
	return l


static func _generate(seed_value: int, mx: int, mz: int) -> Dictionary:
	var rng := Rng.new(_mix(seed_value, mx, mz))
	var tiles := PackedByteArray()
	tiles.resize(SIZE * SIZE)
	tiles.fill(0)
	# ۱) هزارتوی DFS روی اتاق‌ها؛ اتاق (a,b) کاشی (2a+1, 2b+1) است و راه بین دو اتاق کاشی میانی.
	var visited := PackedByteArray()
	visited.resize(ROOMS * ROOMS)
	visited.fill(0)
	var entry_room := Vector2i(ROOMS / 2, ROOMS - 1)
	var stack: Array = [entry_room]
	visited[entry_room.y * ROOMS + entry_room.x] = 1
	tiles[tile_index(entry_room.x * 2 + 1, entry_room.y * 2 + 1)] = 1
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var opts: Array = []
		for d in DIRS:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < ROOMS and n.y < ROOMS and int(visited[n.y * ROOMS + n.x]) == 0:
				opts.append(d)
		if opts.is_empty():
			stack.pop_back()
			continue
		var dir: Vector2i = opts[rng.below(opts.size())]
		var nxt: Vector2i = cur + dir
		visited[nxt.y * ROOMS + nxt.x] = 1
		tiles[tile_index(cur.x * 2 + 1 + dir.x, cur.y * 2 + 1 + dir.y)] = 1
		tiles[tile_index(nxt.x * 2 + 1, nxt.y * 2 + 1)] = 1
		stack.append(nxt)
	# ۲) غارهای باز (۳×۳) در چند اتاق.
	for _c in range(FWConst.MINE_CAVERNS):
		var ca: int = 1 + rng.below(ROOMS - 2)
		var cb: int = 1 + rng.below(ROOMS - 2)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				tiles[tile_index(ca * 2 + 1 + dx, cb * 2 + 1 + dz)] = 1
	# ۳) چند حلقه: دیوار بین دو اتاق باز را گاهی بردار تا مسیر دوم وجود داشته باشد.
	for tz in range(1, SIZE - 1):
		for tx in range(1, SIZE - 1):
			if int(tiles[tile_index(tx, tz)]) == 1 or (tx % 2) == (tz % 2):
				continue
			var between_h: bool = (tx % 2 == 0) and int(tiles[tile_index(tx - 1, tz)]) == 1 and int(tiles[tile_index(tx + 1, tz)]) == 1
			var between_v: bool = (tz % 2 == 0) and int(tiles[tile_index(tx, tz - 1)]) == 1 and int(tiles[tile_index(tx, tz + 1)]) == 1
			if (between_h or between_v) and rng.chance(FWConst.MINE_LOOP_CHANCE):
				tiles[tile_index(tx, tz)] = 1
	# ۴) فاصلهٔ مسیر از ورودی (BFS).
	var entry := Vector2i(entry_room.x * 2 + 1, entry_room.y * 2 + 1)
	var dist := PackedInt32Array()
	dist.resize(SIZE * SIZE)
	dist.fill(-1)
	dist[tile_index(entry.x, entry.y)] = 0
	var queue: Array = [entry]
	var head := 0
	var max_dist := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var cd: int = dist[tile_index(c.x, c.y)]
		max_dist = maxi(max_dist, cd)
		for d in DIRS:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= SIZE or n.y >= SIZE:
				continue
			var ni := tile_index(n.x, n.y)
			if int(tiles[ni]) == 1 and dist[ni] < 0:
				dist[ni] = cd + 1
				queue.append(n)
	# ۵) صندوق‌ها در عمیق‌ترین بن‌بست‌ها.
	var dead: Array = []
	for tz in range(SIZE):
		for tx in range(SIZE):
			var ti := tile_index(tx, tz)
			if int(tiles[ti]) == 1 and dist[ti] >= 3 and _open_neighbors(tiles, tx, tz) == 1:
				dead.append([dist[ti], ti])
	dead.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var chest_tiles: Dictionary = {}
	for i in range(mini(FWConst.MINE_CHESTS, dead.size())):
		chest_tiles[int(dead[i][1])] = true
	var dead_set: Dictionary = {}
	for e in dead:
		dead_set[int(e[1])] = true
	# ۶) سنگ‌های معدن.
	var nodes: Array = []
	for tz in range(SIZE):
		for tx in range(SIZE):
			var ti := tile_index(tx, tz)
			if int(tiles[ti]) != 1 or dist[ti] < 3:
				continue
			var is_dead: bool = dead_set.has(ti)
			var is_chest: bool = chest_tiles.has(ti)
			if not is_dead and not rng.chance(FWConst.MINE_ORE_CHANCE):
				continue
			var depth_pct: int = (dist[ti] * 100) / maxi(max_dist, 1)
			var kind := "chest" if is_chest else _pick_kind(rng, depth_pct, is_dead)
			var def: Dictionary = FWConst.MINE_ORES[kind]
			var n_amt: int = int(def["min"]) + rng.below(int(def["max"]) - int(def["min"]) + 1)
			var reward := 0
			if kind == "chest":
				reward = int(def["reward_min"]) + rng.below(int(def["reward_max"]) - int(def["reward_min"]) + 1)
			# سنگ کنار یک دیوار قرار می‌گیرد (اگر دیواری نباشد، گوشهٔ تصادفی).
			var off := Vector2.ZERO
			var walls: Array = []
			for d in DIRS:
				if not tile_open({"tiles": tiles}, tx + d.x, tz + d.y):
					walls.append(d)
			if not walls.is_empty():
				var wd: Vector2i = walls[rng.below(walls.size())]
				off = Vector2(float(wd.x), float(wd.y)) * 0.95
			else:
				off = Vector2(1.0 if rng.below(2) == 0 else -1.0, 1.0 if rng.below(2) == 0 else -1.0) * 0.8
			var c := tile_center(tx, tz) + off
			nodes.append({"idx": nodes.size(), "kind": kind, "x": c.x, "z": c.y, "tx": tx, "tz": tz,
				"n": n_amt, "reward": reward, "depth": dist[ti]})
	return {"tiles": tiles, "dist": dist, "entry": entry, "nodes": nodes, "max_dist": max_dist}


static func _pick_kind(rng: Rng, depth_pct: int, dead: bool) -> String:
	var r := rng.below(100)
	if depth_pct < 30:
		if r < 55:
			return "stone"
		if r < 85:
			return "coal"
		return "iron"
	if depth_pct < 65:
		if r < 18:
			return "stone"
		if r < 38:
			return "coal"
		if r < 78:
			return "iron"
		return "gold"
	if dead:
		if r < 15:
			return "iron"
		if r < 45:
			return "gold"
		return "gem"
	return "iron" if r < 45 else "gold"


static func node_of(l: Dictionary, idx: int) -> Dictionary:
	var nodes: Array = l["nodes"]
	if idx < 0 or idx >= nodes.size():
		return {}
	return nodes[idx]
