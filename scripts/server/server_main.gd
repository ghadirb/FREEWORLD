extends RefCounted
## راه‌اندازی سرور اختصاصی از خط فرمان:
##   godot --headless --path . -- --server --port 7777 --seed 12345 --data-dir /data --admin نام:رمز
## رمز مدیر را ترجیحاً با متغیر محیطی FREEWORLD_ADMIN=نام:رمز بدهید تا در فهرست پردازه‌ها دیده نشود.

const FWConst = preload("res://scripts/core/const.gd")
const NetScript = preload("res://scripts/networking/net.gd")
const GameServer = preload("res://scripts/server/game_server.gd")


static func parse_args(args: PackedStringArray) -> Dictionary:
	var cfg := {
		"port": FWConst.DEFAULT_PORT, "seed": 12345,
		"data_dir": "user://server_data", "admins": [], "max_seconds": 0.0,
	}
	var i := 0
	while i < args.size():
		var a := args[i]
		var has_val := i + 1 < args.size()
		match a:
			"--port":
				if has_val:
					cfg["port"] = int(args[i + 1])
					i += 1
			"--seed":
				if has_val:
					cfg["seed"] = int(args[i + 1])
					i += 1
			"--data-dir":
				if has_val:
					cfg["data_dir"] = args[i + 1]
					i += 1
			"--admin":
				if has_val:
					_add_admin(cfg, args[i + 1])
					i += 1
			"--max-seconds":
				if has_val:
					cfg["max_seconds"] = float(args[i + 1])
					i += 1
		i += 1
	var env := OS.get_environment("FREEWORLD_ADMIN")
	if env != "":
		_add_admin(cfg, env)
	return cfg


static func _add_admin(cfg: Dictionary, spec: String) -> void:
	var parts := spec.split(":", true, 1)
	if parts.size() == 2 and parts[0] != "" and parts[1].length() >= 6:
		cfg["admins"].append([parts[0], parts[1]])
	else:
		push_warning("--admin ignored: use name:secret (secret >= 6 chars)")


## سرور را زیر گرهٔ والد می‌سازد و برمی‌گرداند. null یعنی شکست.
static func launch(parent: Node, cfg: Dictionary) -> Node:
	var net: Node = parent.get_tree().root.get_node_or_null("Net")
	if net == null:
		net = Node.new()
		net.set_script(NetScript)
		net.name = "Net"
		parent.get_tree().root.add_child(net)
	var server := Node.new()
	server.set_script(GameServer)
	server.name = "GameServer"
	parent.get_tree().root.add_child(server)
	server.net = net
	net.server = server
	var err: int = server.start(int(cfg["port"]), int(cfg["seed"]), str(cfg["data_dir"]), cfg["admins"], str(cfg.get("tls_dir", "")))
	if err != OK:
		push_error("server failed to start: error %d" % err)
		return null
	if float(cfg["max_seconds"]) > 0.0:
		var t := parent.get_tree().create_timer(float(cfg["max_seconds"]))
		t.timeout.connect(func():
			server.shutdown()
			parent.get_tree().quit(0))
	return server
