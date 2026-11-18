extends Node3D
## دوربین دوحالته: «زندگی» (سوم‌شخص دور شخصیت) و «شهر» (نمای مدیریتی از بالا با جابه‌جایی آزاد).

const FWConst = preload("res://scripts/core/const.gd")

const LIFE_PITCH := -22.0
const WORLD_PITCH := -58.0

var camera: Camera3D
var world
var mode: String = "life"
var focus: Vector3 = Vector3.ZERO      # کانون هدف
var yaw: float = 0.0                   # رادیان
var life_distance: float = 9.0
var world_distance: float = 42.0

var _cur_focus: Vector3 = Vector3.ZERO
var _cur_yaw: float = 0.0
var _cur_pitch: float = LIFE_PITCH
var _cur_dist: float = 9.0


func setup(world_gen) -> void:
	world = world_gen
	camera = Camera3D.new()
	camera.current = true
	camera.near = 0.2
	camera.far = 600.0
	camera.fov = 65.0
	add_child(camera)


func snap(f: Vector3) -> void:
	focus = f
	_cur_focus = f
	_cur_yaw = yaw
	_apply()


func rotate_by(dx: float, dy: float) -> void:
	yaw -= dx
	if mode == "life":
		life_pitch_offset = clampf(life_pitch_offset - dy * 30.0, -20.0, 45.0)
	else:
		world_pitch_offset = clampf(world_pitch_offset - dy * 30.0, -25.0, 20.0)


var life_pitch_offset: float = 0.0
var world_pitch_offset: float = 0.0


func zoom_by(factor: float) -> void:
	if mode == "life":
		life_distance = clampf(life_distance * factor, 4.0, 22.0)
	else:
		world_distance = clampf(world_distance * factor, 14.0, 160.0)


## جابه‌جایی کانون در حالت شهر؛ delta بر حسب متر در دستگاه مختصات صفحه (راست، جلو).
func pan(right_m: float, forward_m: float) -> void:
	var r := Vector3(cos(yaw), 0, -sin(yaw))
	var f := Vector3(-sin(yaw), 0, -cos(yaw))
	focus += r * right_m + f * forward_m
	focus.x = clampf(focus.x, -FWConst.WORLD_LIMIT, FWConst.CITY_SIZE + FWConst.WORLD_LIMIT)
	focus.z = clampf(focus.z, -FWConst.WORLD_LIMIT, FWConst.CITY_SIZE + FWConst.WORLD_LIMIT)
	focus.y = world.height_at(focus.x, focus.z)


func set_life_focus(p: Vector3) -> void:
	focus = p + Vector3(0, 1.3, 0)


## بردارهای افقی جلو/راست دوربین برای حرکت شخصیت.
func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func right_flat() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


func _process(delta: float) -> void:
	var k := 1.0 - exp(-9.0 * delta)
	var target_pitch := (LIFE_PITCH + life_pitch_offset) if mode == "life" else (WORLD_PITCH + world_pitch_offset)
	var target_dist := life_distance if mode == "life" else world_distance
	_cur_focus = _cur_focus.lerp(focus, k if mode == "world" else 1.0 - exp(-16.0 * delta))
	_cur_yaw = lerp_angle(_cur_yaw, yaw, k)
	_cur_pitch = lerpf(_cur_pitch, target_pitch, k)
	_cur_dist = lerpf(_cur_dist, target_dist, k)
	_apply()


func _apply() -> void:
	var pitch := deg_to_rad(_cur_pitch)
	var dir := Vector3(sin(_cur_yaw) * cos(pitch), -sin(pitch), cos(_cur_yaw) * cos(pitch))
	var pos := _cur_focus + dir * _cur_dist
	var ground: float = world.height_at(pos.x, pos.z) + 1.2
	pos.y = maxf(pos.y, ground)
	camera.global_position = pos
	camera.look_at(_cur_focus, Vector3.UP)
