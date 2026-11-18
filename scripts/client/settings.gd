extends RefCounted
## تنظیمات و توکن حساب‌ها روی دستگاه (user://settings.cfg).

const PATH := "user://settings.cfg"

static var _cfg: ConfigFile = null


static func _load() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)
	return _cfg


static func get_value(key: String, default: Variant) -> Variant:
	return _load().get_value("game", key, default)


static func set_value(key: String, value: Variant) -> void:
	_load().set_value("game", key, value)
	_load().save(PATH)


static func default_quality() -> int:
	return 0 if OS.has_feature("mobile") else 1


static func token_for(host: String, port: int, player_name: String) -> String:
	return str(_load().get_value("tokens", "%s:%d|%s" % [host, port, player_name], ""))


static func save_token(host: String, port: int, player_name: String, token: String) -> void:
	_load().set_value("tokens", "%s:%d|%s" % [host, port, player_name], token)
	_load().save(PATH)
