extends RefCounted
## قوانین مشترک قایق: سرور برای تصمیم نهایی و کلاینت برای پیش‌بینی حرکت از همین توابع استفاده می‌کنند.
## قایق فقط روی آبِ زمین می‌رود؛ جایی که بازیکن پیاده نمی‌تواند راه برود (پل و بلوک آب را می‌بندد).

const FWConst = preload("res://scripts/core/const.gd")


## آب یعنی ارتفاع زمین زیر آستانه و جای ایستادن نباشد (مثلاً پل روی آب آب حساب نمی‌شود).
static func is_water(cs, x: float, z: float) -> bool:
	return cs.world.height_at(x, z) < FWConst.BOAT_MIN_H and not cs.is_walkable(x, z)


## نزدیک‌ترین نقطهٔ آب تا شعاع r (حلقه‌های ۰٫۵ متری)؛ اگر نبود INF.
static func find_water_near(cs, pos: Vector2, r: float) -> Vector2:
	return _ring_search(pos, r, func(p: Vector2) -> bool: return is_water(cs, p.x, p.y))


## نزدیک‌ترین نقطهٔ خشکی قابل‌ایستادن تا شعاع r؛ اگر نبود INF.
static func find_land_near(cs, pos: Vector2, r: float, ref_y: float = NAN) -> Vector2:
	return _ring_search(pos, r, func(p: Vector2) -> bool: return cs.is_walkable(p.x, p.y, ref_y))


static func _ring_search(pos: Vector2, r: float, ok: Callable) -> Vector2:
	if ok.call(pos):
		return pos
	var step := 0.5
	var rad := step
	while rad <= r:
		var n := maxi(8, int(ceil(TAU * rad / step)))
		for i in n:
			var a := TAU * float(i) / float(n)
			var p := pos + Vector2(cos(a), sin(a)) * rad
			if ok.call(p):
				return Vector2(snappedf(p.x, 0.01), snappedf(p.y, 0.01))
		rad += step
	return Vector2(INF, INF)


static func found(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)
