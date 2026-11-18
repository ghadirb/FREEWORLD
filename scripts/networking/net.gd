extends Node
## گرهٔ مشترک RPC. روی سرور و کلاینت باید دقیقاً با مسیر /root/Net وجود داشته باشد.
## این گره فقط پیام را به GameServer یا GameClient تحویل می‌دهد؛ منطق بازی اینجا نیست.

var server = null  # GameServer (فقط روی سرور)
var client = null  # GameClient (فقط روی کلاینت)


# ---------------- کلاینت -> سرور ----------------

@rpc("any_peer", "call_remote", "reliable")
func c2s_login(player_name: String, token: String, proto: int) -> void:
	if server:
		server.on_login(multiplayer.get_remote_sender_id(), player_name, token, proto)


@rpc("any_peer", "call_remote", "unreliable")
func c2s_move(x: float, z: float, yaw: float) -> void:
	if server:
		server.on_move(multiplayer.get_remote_sender_id(), x, z, yaw)


@rpc("any_peer", "call_remote", "reliable")
func c2s_place(req_id: int, type: String, cx: int, cz: int) -> void:
	if server:
		server.on_place(multiplayer.get_remote_sender_id(), req_id, type, cx, cz)


@rpc("any_peer", "call_remote", "reliable")
func c2s_remove(id: int) -> void:
	if server:
		server.on_remove(multiplayer.get_remote_sender_id(), id)


@rpc("any_peer", "call_remote", "reliable")
func c2s_collect(id: int) -> void:
	if server:
		server.on_collect(multiplayer.get_remote_sender_id(), id)


@rpc("any_peer", "call_remote", "reliable")
func c2s_set_world(key: String, value: Variant) -> void:
	if server:
		server.on_set_world(multiplayer.get_remote_sender_id(), key, value)


@rpc("any_peer", "call_remote", "reliable")
func c2s_enter(id: int) -> void:
	if server:
		server.on_enter(multiplayer.get_remote_sender_id(), id)


@rpc("any_peer", "call_remote", "reliable")
func c2s_leave() -> void:
	if server:
		server.on_leave(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func c2s_chat(text: String) -> void:
	if server:
		server.on_chat(multiplayer.get_remote_sender_id(), text)


@rpc("any_peer", "call_remote", "reliable")
func c2s_set_role(target: String, role: String) -> void:
	if server:
		server.on_set_role(multiplayer.get_remote_sender_id(), target, role)


@rpc("any_peer", "call_remote", "reliable")
func c2s_job(building_id: int) -> void:
	if server:
		server.on_job(multiplayer.get_remote_sender_id(), building_id)


@rpc("any_peer", "call_remote", "reliable")
func c2s_get_audit() -> void:
	if server:
		server.on_get_audit(multiplayer.get_remote_sender_id())


# ---------------- سرور -> کلاینت ----------------

@rpc("authority", "call_remote", "reliable")
func s2c_login_result(ok: bool, error: String, info: Dictionary) -> void:
	if client:
		client.on_login_result(ok, error, info)


@rpc("authority", "call_remote", "reliable")
func s2c_snapshot(buildings: Array, npcs: Array, players: Dictionary) -> void:
	if client:
		client.on_snapshot(buildings, npcs, players)


@rpc("authority", "call_remote", "reliable")
func s2c_building_added(b: Dictionary) -> void:
	if client:
		client.on_building_added(b)


@rpc("authority", "call_remote", "reliable")
func s2c_building_removed(id: int) -> void:
	if client:
		client.on_building_removed(id)


@rpc("authority", "call_remote", "reliable")
func s2c_stocks(stocks: Dictionary) -> void:
	if client:
		client.on_stocks(stocks)


@rpc("authority", "call_remote", "reliable")
func s2c_job(building_id: int) -> void:
	if client:
		client.on_job(building_id)


@rpc("authority", "call_remote", "reliable")
func s2c_world(settings: Dictionary) -> void:
	if client:
		client.on_world(settings)


@rpc("authority", "call_remote", "reliable")
func s2c_inside(building_id: int) -> void:
	if client:
		client.on_inside(building_id)


@rpc("authority", "call_remote", "reliable")
func s2c_energy(value: int) -> void:
	if client:
		client.on_energy(value)


@rpc("authority", "call_remote", "reliable")
func s2c_market(market: Dictionary) -> void:
	if client:
		client.on_market(market)


@rpc("authority", "call_remote", "reliable")
func s2c_money(money: int) -> void:
	if client:
		client.on_money(money)


@rpc("authority", "call_remote", "reliable")
func s2c_player_joined(player_name: String, role: String) -> void:
	if client:
		client.on_player_joined(player_name, role)


@rpc("authority", "call_remote", "reliable")
func s2c_player_left(player_name: String) -> void:
	if client:
		client.on_player_left(player_name)


@rpc("authority", "call_remote", "reliable")
func s2c_notice(code: String, args: Dictionary) -> void:
	if client:
		client.on_notice(code, args)


@rpc("authority", "call_remote", "reliable")
func s2c_chat(from_name: String, text: String) -> void:
	if client:
		client.on_chat(from_name, text)


@rpc("authority", "call_remote", "reliable")
func s2c_role(role: String) -> void:
	if client:
		client.on_role(role)


@rpc("authority", "call_remote", "reliable")
func s2c_audit(entries: Array) -> void:
	if client:
		client.on_audit(entries)


@rpc("authority", "call_remote", "reliable")
func s2c_teleport(x: float, z: float) -> void:
	if client:
		client.on_teleport(x, z)


@rpc("authority", "call_remote", "unreliable")
func s2c_tick(world_time: float, wheat_price: float, players: Dictionary, npcs: Array) -> void:
	if client:
		client.on_tick(world_time, wheat_price, players, npcs)
