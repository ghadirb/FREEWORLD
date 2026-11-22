extends RefCounted
## شبکهٔ ریل و مسیر قطار خودکار. ریل‌های بلوکی که کنار هم (چهارجهته) باشند یک «خط» می‌سازند.
## مسیر قطار تابعی قطعی از چیدمان ریل‌ها و یک ساعت مشترک است؛ پس سرور و همهٔ کلاینت‌ها بدون ارسال
## موقعیت قطار، آن را در یک نقطه می‌بینند. خط ساده: قطار رفت‌وبرگشت می‌کند؛ حلقهٔ بسته: بی‌نهایت می‌چرخد؛
## خط منشعب: طولانی‌ترین مسیر اصلی انتخاب می‌شود.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const MIN_LINE_CELLS := 2
const MIN_LOOP_CELLS := 4


## سلول‌های ریل را از دیکشنری بلوک‌ها (Vector3i -> [نوع، رنگ، مالک]) بیرون می‌کشد؛ خروجی مرتب و بدون تکرار.
static func rail_cells(blocks: Dictionary) -> Array:
	var seen: Dictionary = {}
	for v in blocks:
		if str(blocks[v][0]) == "rail":
			seen[Vector2i(v.x, v.z)] = true
	var out: Array = seen.keys()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out


## خروجی: فهرست {path: Array[Vector2] (مرکز سلول‌ها)، loop: bool، length: float}، مرتب بر اساس کوچک‌ترین سلول.
static func build_lines(cells: Array) -> Array:
	var set: Dictionary = {}
	for c in cells:
		set[c] = true
	var visited: Dictionary = {}
	var lines: Array = []
	for start in cells:
		if visited.has(start):
			continue
		var comp: Array = _component(set, start, visited)
		if comp.size() < MIN_LINE_CELLS:
			continue
		var all_two := true
		for c in comp:
			if _degree(set, c) != 2:
				all_two = false
				break
		var ordered: Array
		var is_loop := false
		if all_two and comp.size() >= MIN_LOOP_CELLS:
			ordered = _walk_loop(set, start)
			is_loop = true
		else:
			ordered = _longest_path(set, comp)
		var pts: Array = []
		for c in ordered:
			pts.append(Vector2(c.x + 0.5, c.y + 0.5))
		var seg_count := float(pts.size() if is_loop else pts.size() - 1)
		lines.append({"path": pts, "loop": is_loop, "length": seg_count})
	return lines


## موقعیت و جهت قطار روی یک خط: Vector3(x, z, yaw). dist مسافت پیموده‌شدهٔ کل است (سرعت × ساعت).
static func position_on(line: Dictionary, dist: float) -> Vector3:
	var pts: Array = line["path"]
	var total: float = float(line["length"])
	if pts.size() < 2 or total <= 0.0:
		return Vector3(0.0, 0.0, 0.0)
	var s: float
	var forward := true
	if bool(line["loop"]):
		s = fposmod(dist, total)
	else:
		s = fposmod(dist, total * 2.0)
		if s > total:
			s = total * 2.0 - s
			forward = false
	var i := int(floor(s))
	if not bool(line["loop"]):
		i = mini(i, pts.size() - 2)
	i = mini(i, pts.size() - 1)
	var a: Vector2 = pts[i]
	var b: Vector2 = pts[(i + 1) % pts.size()]
	var p: Vector2 = a.lerp(b, s - float(i))
	var dir: Vector2 = (b - a) if forward else (a - b)
	return Vector3(p.x, p.y, atan2(dir.x, dir.y))


static func _degree(set: Dictionary, c: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if set.has(c + d):
			n += 1
	return n


static func _component(set: Dictionary, start: Vector2i, visited: Dictionary) -> Array:
	var comp: Array = []
	var queue: Array = [start]
	visited[start] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		comp.append(c)
		for d in DIRS:
			var n: Vector2i = c + d
			if set.has(n) and not visited.has(n):
				visited[n] = true
				queue.append(n)
	return comp


static func _bfs(set: Dictionary, from: Vector2i) -> Dictionary:
	var parent: Dictionary = {from: from}
	var order: Array = []
	var queue: Array = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		order.append(c)
		for d in DIRS:
			var n: Vector2i = c + d
			if set.has(n) and not parent.has(n):
				parent[n] = c
				queue.append(n)
	return {"parent": parent, "last": order[order.size() - 1]}


static func _longest_path(set: Dictionary, comp: Array) -> Array:
	var a: Vector2i = _bfs(set, comp[0])["last"]
	var r: Dictionary = _bfs(set, a)
	var parent: Dictionary = r["parent"]
	var path: Array = []
	var c: Vector2i = r["last"]
	while c != a:
		path.append(c)
		c = parent[c]
	path.append(a)
	path.reverse()
	# جهت ثابت: همیشه از سلول «کوچک‌تر» شروع شود تا نتیجه به نقطهٔ شروع جست‌وجو وابسته نباشد.
	var f: Vector2i = path[0]
	var l: Vector2i = path[path.size() - 1]
	if f.x > l.x or (f.x == l.x and f.y > l.y):
		path.reverse()
	return path


static func _walk_loop(set: Dictionary, start: Vector2i) -> Array:
	var out: Array = [start]
	var prev := start
	var cur := start
	for d in DIRS:
		if set.has(start + d):
			cur = start + d
			break
	while cur != start and out.size() <= set.size():
		out.append(cur)
		var nxt := cur
		for d in DIRS:
			var n: Vector2i = cur + d
			if set.has(n) and n != prev:
				nxt = n
				break
		prev = cur
		cur = nxt
	return out
