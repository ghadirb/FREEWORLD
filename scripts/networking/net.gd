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
func c2s_move(x: float, z: float, yaw: float, alt: float) -> void:
	if server:
		server.on_move(multiplayer.get_remote_sender_id(), x, z, yaw, alt)


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
func c2s_mine_enter(mine_id: String) -> void:
	if server:
		server.on_mine_enter(multiplayer.get_remote_sender_id(), mine_id)


@rpc("any_peer", "call_remote", "reliable")
func c2s_mine_leave() -> void:
	if server:
		server.on_mine_leave(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func c2s_mine_gather(idx: int) -> void:
	if server:
		server.on_mine_gather(multiplayer.get_remote_sender_id(), idx)


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


@rpc("any_peer", "call_remote", "reliable")
func c2s_place_block(req_id: int, x: int, y: int, z: int, type: String, color: int) -> void:
	if server:
		server.on_place_block(multiplayer.get_remote_sender_id(), req_id, x, y, z, type, color)


@rpc("any_peer", "call_remote", "reliable")
func c2s_remove_block(x: int, y: int, z: int) -> void:
	if server:
		server.on_remove_block(multiplayer.get_remote_sender_id(), x, y, z)


@rpc("any_peer", "call_remote", "reliable")
func c2s_paint_block(x: int, y: int, z: int, color: int) -> void:
	if server:
		server.on_paint_block(multiplayer.get_remote_sender_id(), x, y, z, color)


@rpc("any_peer", "call_remote", "reliable")
func c2s_build_region(op: String, x1: int, y1: int, z1: int, x2: int, y2: int, z2: int, type: String, color: int) -> void:
	if server:
		server.on_build_region(multiplayer.get_remote_sender_id(), op, x1, y1, z1, x2, y2, z2, type, color)


@rpc("any_peer", "call_remote", "reliable")
func c2s_paste(ox: int, oy: int, oz: int, data: PackedInt32Array) -> void:
	if server:
		server.on_paste(multiplayer.get_remote_sender_id(), ox, oy, oz, data)


@rpc("any_peer", "call_remote", "reliable")
func c2s_undo() -> void:
	if server:
		server.on_undo(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func c2s_gather(rx: int, rz: int, tool: String) -> void:
	if server:
		server.on_gather(multiplayer.get_remote_sender_id(), rx, rz, tool)


@rpc("any_peer", "call_remote", "reliable")
func c2s_dig(x: float, z: float, tool: String) -> void:
	if server:
		server.on_dig(multiplayer.get_remote_sender_id(), x, z, tool)


@rpc("any_peer", "call_remote", "reliable")
func c2s_fill(x: float, z: float, tool: String) -> void:
	if server:
		server.on_fill(multiplayer.get_remote_sender_id(), x, z, tool)


@rpc("any_peer", "call_remote", "reliable")
func c2s_craft(recipe: String, times: int) -> void:
	if server:
		server.on_craft(multiplayer.get_remote_sender_id(), recipe, times)


@rpc("any_peer", "call_remote", "reliable")
func c2s_npc(npc_id: int, item: String) -> void:
	if server:
		server.on_npc(multiplayer.get_remote_sender_id(), npc_id, item)


@rpc("any_peer", "call_remote", "reliable")
func c2s_npc_sell(npc_id: int, item: String, n: int) -> void:
	if server:
		server.on_npc_sell(multiplayer.get_remote_sender_id(), npc_id, item, n)


@rpc("any_peer", "call_remote", "reliable")
func c2s_npc_buy(npc_id: int, item: String, n: int) -> void:
	if server:
		server.on_npc_buy(multiplayer.get_remote_sender_id(), npc_id, item, n)


@rpc("any_peer", "call_remote", "reliable")
func c2s_furn_place(type: String, x: float, z: float, rot: int) -> void:
	if server:
		server.on_furn_place(multiplayer.get_remote_sender_id(), type, x, z, rot)


@rpc("any_peer", "call_remote", "reliable")
func c2s_furn_remove(idx: int) -> void:
	if server:
		server.on_furn_remove(multiplayer.get_remote_sender_id(), idx)


@rpc("any_peer", "call_remote", "reliable")
func c2s_minigame_start() -> void:
	if server:
		server.on_minigame_start(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func s2c_minigame(data: Dictionary) -> void:
	if client:
		client.on_minigame(data)


@rpc("any_peer", "call_remote", "reliable")
func c2s_race_start() -> void:
	if server:
		server.on_race_start(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func s2c_race(data: Dictionary) -> void:
	if client:
		client.on_race(data)


@rpc("any_peer", "call_remote", "reliable")
func c2s_disaster(kind: String) -> void:
	if server:
		server.on_disaster(multiplayer.get_remote_sender_id(), kind)


@rpc("authority", "call_remote", "reliable")
func s2c_disaster(data: Dictionary) -> void:
	if client:
		client.on_disaster(data)


@rpc("any_peer", "call_remote", "reliable")
func c2s_god(action: String, kind: String, x: float, z: float) -> void:
	if server:
		server.on_god(multiplayer.get_remote_sender_id(), action, kind, x, z)


@rpc("authority", "call_remote", "reliable")
func s2c_god(list: Array) -> void:
	if client:
		client.on_god(list)


@rpc("any_peer", "call_remote", "reliable")
func c2s_trade(item: String, n: int, buy: bool) -> void:
	if server:
		server.on_trade(multiplayer.get_remote_sender_id(), item, n, buy)


@rpc("any_peer", "call_remote", "reliable")
func c2s_offer(to_name: String, item: String, n: int, price: int) -> void:
	if server:
		server.on_offer(multiplayer.get_remote_sender_id(), to_name, item, n, price)


@rpc("any_peer", "call_remote", "reliable")
func c2s_offer_answer(id: int, accept: bool) -> void:
	if server:
		server.on_offer_answer(multiplayer.get_remote_sender_id(), id, accept)


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
func s2c_furn(data: Dictionary) -> void:
	if client:
		client.on_furn(data)


@rpc("authority", "call_remote", "reliable")
func s2c_mine(mine_id: String, depleted: PackedInt32Array) -> void:
	if client:
		client.on_mine(mine_id, depleted)


@rpc("authority", "call_remote", "reliable")
func s2c_mine_node(idx: int, alive: bool) -> void:
	if client:
		client.on_mine_node(idx, alive)


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


@rpc("authority", "call_remote", "reliable")
func s2c_offer(data: Dictionary) -> void:
	if client:
		client.on_offer(data)


@rpc("authority", "call_remote", "reliable")
func s2c_inv(data: Dictionary) -> void:
	if client:
		client.on_inv(data)


## [x, y, z, type_id, color] ؛ type_id = -1 یعنی بلوک برداشته شد.
@rpc("authority", "call_remote", "reliable")
func s2c_block(data: PackedInt32Array) -> void:
	if client:
		client.on_block(data)


## دسته‌ای از بلوک‌ها (پنج عدد برای هر بلوک) هنگام ورود.
@rpc("authority", "call_remote", "reliable")
func s2c_blocks(batch: PackedInt32Array) -> void:
	if client:
		client.on_blocks(batch)


## [rx, rz, alive(0/1)]
@rpc("authority", "call_remote", "reliable")
func s2c_resource(data: PackedInt32Array) -> void:
	if client:
		client.on_resource(data)


## فهرست منابع برداشت‌شدهٔ فعلی: جفت‌های rx, rz
@rpc("authority", "call_remote", "reliable")
func s2c_fire(flat: PackedInt32Array) -> void:
	if client:
		client.on_fire(flat)


@rpc("authority", "call_remote", "reliable")
func s2c_depleted(flat: PackedInt32Array) -> void:
	if client:
		client.on_depleted(flat)


## کل تغییرات زمین هنگام ورود: سه‌تایی‌های ix, iz, مقدار (پروتکل ۱۶)
@rpc("authority", "call_remote", "reliable")
func s2c_terrain(flat: PackedInt32Array) -> void:
	if client:
		client.on_terrain(flat)


## تغییر تازهٔ زمین (همان قالب سه‌تایی)
@rpc("authority", "call_remote", "reliable")
func s2c_terrain_edit(flat: PackedInt32Array) -> void:
	if client:
		client.on_terrain_edit(flat)


@rpc("authority", "call_remote", "unreliable")
func s2c_tick(world_time: float, wheat_price: float, players: Dictionary, npcs: Array) -> void:
	if client:
		client.on_tick(world_time, wheat_price, players, npcs)
