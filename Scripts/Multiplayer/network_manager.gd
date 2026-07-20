extends Node

signal lobby_state_changed(members: Array, join_code: String)
signal connection_status_changed(message: String, is_error: bool)
signal game_start_requested
signal lobby_left

const MAX_PLAYERS := 3
const SIGNAL_POLL_INTERVAL := 0.28
const STATUS_POLL_INTERVAL := 0.75
const PLAYER_STATE_INTERVAL := 0.05
const HTTP_SYNC_INTERVAL := 0.25
const WEBSOCKET_SYNC_INTERVAL := 0.1
const MAX_SEEN_CAST_IDS := 384
const MAX_SNAPSHOT_ENEMIES := 72
const MAX_SNAPSHOT_ALLIES := 48
const MAX_SNAPSHOT_HAZARDS := 32
const MAX_SNAPSHOT_PROJECTILES := 64
# Filled in after the first Cloudflare deployment prints its workers.dev URL.
const CLOUDFLARE_WORKER_URL := ""
const BOSS_HAZARD_SCENE := preload("res://Scenes/Hazards/BossHazard.tscn")
const BOSS_PROJECTILE_SCENE := preload("res://Scenes/Hazards/BossProjectile.tscn")
const STUN_CONFIGURATION := {
	"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]
}

var join_code := ""
var local_peer_id := 0
var is_host := false
var _host_token := ""
var _peer_token := ""
var members: Array = []
var game_started := false

var _webrtc_multiplayer: WebRTCMultiplayerPeer
var _connections: Dictionary = {}
var _remote_avatars: Dictionary = {}
var _remote_world_actors: Dictionary = {}
var _remote_hazards: Dictionary = {}
var _remote_projectiles: Dictionary = {}
var _seen_signal_ids: Dictionary = {}
var _signal_outbox: Array[Dictionary] = []
var _poll_elapsed := 0.0
var _status_elapsed := 0.0
var _state_elapsed := 0.0
var _sync_elapsed := 0.0
var _http_cast_sequence := 0
var _pending_http_casts: Array[Dictionary] = []
var _sync_cast_ids_in_flight: Array[String] = []
var _seen_http_cast_ids: Dictionary = {}
var _seen_damage_event_ids: Dictionary = {}
var _downed_peers: Dictionary = {}
var _relic_charges: Dictionary = {}
var _pending_revive_target := 0
var _pending_camp_upgrade_id := ""
var _pending_camp_upgrade_choice := ""
var _pending_camp_upgrade_request := ""
var _seen_camp_upgrade_requests: Dictionary = {}
var _socket := WebSocketPeer.new()
var _socket_was_open := false
var _socket_reconnect_remaining := 0.0
var _cloudflare_status_requested := false
var _action_kind := ""
var _action_request: HTTPRequest
var _poll_request: HTTPRequest
var _status_request: HTTPRequest
var _signal_request: HTTPRequest
var _sync_request: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_action_request = _make_request(_on_action_completed)
	_poll_request = _make_request(_on_poll_completed)
	_status_request = _make_request(_on_status_completed)
	_signal_request = _make_request(_on_signal_sent)
	_sync_request = _make_request(_on_sync_completed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	GameManager.boss_reward_collected.connect(_on_boss_reward_collected)


func _make_request(callback: Callable) -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = 8.0
	request.request_completed.connect(callback)
	add_child(request)
	return request


func host_lobby() -> void:
	leave_lobby(false)
	_action_kind = "create"
	connection_status_changed.emit("Creating co-op lobby…", false)
	_post(_action_request, {"action": "create", "name": "Host Wizard", "player_code": MetaProgression.player_code})


func join_lobby(code: String) -> void:
	var cleaned := code.strip_edges().to_upper().replace(" ", "")
	if cleaned.length() != 6:
		connection_status_changed.emit("Join codes contain exactly 6 letters or numbers.", true)
		return
	leave_lobby(false)
	_action_kind = "join"
	connection_status_changed.emit("Joining lobby %s…" % cleaned, false)
	_post(_action_request, {"action": "join", "code": cleaned, "name": "Guest Wizard", "player_code": MetaProgression.player_code})


func request_start_game() -> void:
	if not is_host or join_code.is_empty():
		return
	_action_kind = "start"
	_post(_action_request, {"action": "start", "code": join_code, "host_token": _host_token})


func leave_lobby(notify_server := true) -> void:
	if notify_server and not join_code.is_empty() and _action_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_action_kind = "leave"
		_post(_action_request, {"action": "leave", "code": join_code, "peer_id": local_peer_id})
	_reset_network_state()
	lobby_left.emit()


func is_in_lobby() -> bool:
	return not join_code.is_empty()


func get_player_count() -> int:
	return maxi(members.size(), 1) if is_in_lobby() else 1


func get_enemy_health_multiplier() -> float:
	return 1.0


func is_realtime_coop_session() -> bool:
	return game_started and is_in_lobby() and get_player_count() > 1


func get_dropped_relic_count(peer_id: int) -> int:
	var data := _downed_peers.get(peer_id, {}) as Dictionary
	return int(data.get("dropped_relics", 0))


func request_space_camp_upgrade(camp_id: String, choice := "") -> void:
	if camp_id.is_empty():
		return
	if is_world_authority():
		_apply_space_camp_upgrade(camp_id, choice)
		return
	_pending_camp_upgrade_id = camp_id
	_pending_camp_upgrade_choice = choice.to_lower()
	_pending_camp_upgrade_request = "%d-%d" % [local_peer_id, Time.get_ticks_msec()]


func _apply_space_camp_upgrade(camp_id: String, choice: String) -> void:
	for camp_variant in get_tree().get_nodes_in_group("space_camps"):
		var camp := camp_variant as SpawnerStructure
		if not is_instance_valid(camp) or "ally-" + str(camp.get_instance_id()) != camp_id:
			continue
		camp.request_space_upgrade(choice)
		return


func _handle_space_camp_upgrade_state(state: Dictionary) -> void:
	var request_id := String(state.get("camp_upgrade_request", ""))
	if request_id.is_empty() or _seen_camp_upgrade_requests.has(request_id):
		return
	_seen_camp_upgrade_requests[request_id] = true
	_apply_space_camp_upgrade(String(state.get("camp_upgrade_id", "")), String(state.get("camp_upgrade_choice", "")))
	while _seen_camp_upgrade_requests.size() > 64:
		_seen_camp_upgrade_requests.erase(_seen_camp_upgrade_requests.keys().front())


func _clear_pending_camp_upgrade() -> void:
	_pending_camp_upgrade_id = ""
	_pending_camp_upgrade_choice = ""
	_pending_camp_upgrade_request = ""


func notify_local_player_downed() -> void:
	if not is_realtime_coop_session() or not is_host:
		return
	_register_downed_peer(local_peer_id, GameManager.player.global_position if is_instance_valid(GameManager.player) else Vector2.ZERO)


func notify_remote_player_downed(peer_id: int, position: Vector2) -> void:
	if not is_host or not is_realtime_coop_session():
		return
	_register_downed_peer(peer_id, position)


func _register_downed_peer(peer_id: int, position: Vector2) -> void:
	if peer_id <= 0 or _downed_peers.has(peer_id):
		return
	var dropped := int(_relic_charges.get(peer_id, 0))
	_relic_charges[peer_id] = 0
	_downed_peers[peer_id] = {"x": position.x, "y": position.y, "dropped_relics": dropped}
	var spawner := get_tree().current_scene.get_node_or_null("EnemySpawner") if get_tree().current_scene != null else null
	if spawner != null and spawner.has_method("spawn_ambush"):
		spawner.spawn_ambush(position, 6 + mini(dropped, 3))


func _on_boss_reward_collected(_reward_id: String, _reward_name: String) -> void:
	if not is_host or not is_realtime_coop_session():
		return
	for member_variant in members:
		var peer_id := int((member_variant as Dictionary).get("peer_id", 0))
		if peer_id > 0:
			_relic_charges[peer_id] = int(_relic_charges.get(peer_id, 0)) + 1


func request_lobby_refresh() -> void:
	_cloudflare_status_requested = true
	_status_elapsed = STATUS_POLL_INTERVAL


func _process(delta: float) -> void:
	if not is_in_lobby():
		return
	_capture_interact_request()
	if _uses_cloudflare():
		_process_cloudflare_socket(delta)
		return
	_poll_elapsed += delta
	_status_elapsed += delta
	_state_elapsed += delta
	_sync_elapsed += delta
	# Signaling and lobby status are only needed before the run starts. Keeping
	# these requests alive during combat caused needless network pressure beside
	# the authoritative world sync, especially on Netlify's HTTP fallback.
	if not game_started:
		if _poll_elapsed >= SIGNAL_POLL_INTERVAL and _poll_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			_poll_elapsed = 0.0
			_http_get(_poll_request, {"action": "poll", "code": join_code, "peer_id": local_peer_id})
		if _status_elapsed >= STATUS_POLL_INTERVAL and _status_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			_status_elapsed = 0.0
			var status_parameters := {"action": "status", "code": join_code}
			if is_host and GameManager.owner_access_enabled:
				status_parameters["owner_code"] = "609618"
				status_parameters["host_token"] = _host_token
			_http_get(_status_request, status_parameters)
		_flush_signal_outbox()
	if game_started and _state_elapsed >= PLAYER_STATE_INTERVAL:
		_state_elapsed = 0.0
		_broadcast_local_player_state()
	if game_started and _sync_elapsed >= HTTP_SYNC_INTERVAL and _sync_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_sync_elapsed = 0.0
		_send_http_sync()


func _process_cloudflare_socket(delta: float) -> void:
	_socket.poll()
	var socket_state := _socket.get_ready_state()
	if socket_state == WebSocketPeer.STATE_OPEN:
		if not _socket_was_open:
			_socket_was_open = true
			connection_status_changed.emit("Real-time co-op connected.", false)
		while _socket.get_available_packet_count() > 0:
			_handle_socket_message(_socket.get_packet().get_string_from_utf8())
		_sync_elapsed += delta
		if game_started and _sync_elapsed >= WEBSOCKET_SYNC_INTERVAL:
			_sync_elapsed = 0.0
			_send_socket_sync()
	elif socket_state == WebSocketPeer.STATE_CLOSED:
		if _socket_was_open:
			_socket_was_open = false
			connection_status_changed.emit("Co-op connection interrupted. Reconnecting…", true)
		_socket_reconnect_remaining -= delta
		if _socket_reconnect_remaining <= 0.0:
			_socket_reconnect_remaining = 1.5
			_connect_cloudflare_socket()
	if _cloudflare_status_requested and _status_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_cloudflare_status_requested = false
		var status_parameters := {"action": "status", "code": join_code}
		if is_host and GameManager.owner_access_enabled:
			status_parameters["owner_code"] = "609618"
			status_parameters["host_token"] = _host_token
		_http_get(_status_request, status_parameters)


func _initialize_host() -> void:
	_webrtc_multiplayer = WebRTCMultiplayerPeer.new()
	var error := _webrtc_multiplayer.create_server()
	if error != OK:
		connection_status_changed.emit("This browser could not create a WebRTC host.", true)
		return
	multiplayer.multiplayer_peer = _webrtc_multiplayer


func _initialize_client() -> void:
	_webrtc_multiplayer = WebRTCMultiplayerPeer.new()
	var error := _webrtc_multiplayer.create_client(local_peer_id)
	if error != OK:
		connection_status_changed.emit("This browser could not create a WebRTC client.", true)
		return
	multiplayer.multiplayer_peer = _webrtc_multiplayer
	_add_connection(1, false)


func _add_connection(remote_peer_id: int, should_offer: bool) -> void:
	if _connections.has(remote_peer_id) or _webrtc_multiplayer == null:
		return
	var connection := WebRTCPeerConnection.new()
	var error := connection.initialize(STUN_CONFIGURATION)
	if error != OK:
		connection_status_changed.emit("Could not initialize the co-op connection.", true)
		return
	connection.session_description_created.connect(_on_session_created.bind(remote_peer_id))
	connection.ice_candidate_created.connect(_on_ice_candidate_created.bind(remote_peer_id))
	_connections[remote_peer_id] = connection
	error = _webrtc_multiplayer.add_peer(connection, remote_peer_id)
	if error != OK:
		_connections.erase(remote_peer_id)
		connection_status_changed.emit("Could not add teammate connection %d." % remote_peer_id, true)
		return
	if should_offer:
		connection.create_offer()


func _on_session_created(type: String, sdp: String, remote_peer_id: int) -> void:
	var connection := _connections.get(remote_peer_id) as WebRTCPeerConnection
	if connection == null:
		return
	connection.set_local_description(type, sdp)
	_queue_signal(remote_peer_id, "session", {"type": type, "sdp": sdp})


func _on_ice_candidate_created(media: String, index: int, candidate: String, remote_peer_id: int) -> void:
	_queue_signal(remote_peer_id, "ice", {"media": media, "index": index, "candidate": candidate})


func _queue_signal(remote_peer_id: int, kind: String, payload: Dictionary) -> void:
	_signal_outbox.append({
		"action": "signal",
		"code": join_code,
		"from": local_peer_id,
		"to": remote_peer_id,
		"kind": kind,
		"payload": payload,
	})
	_flush_signal_outbox()


func _flush_signal_outbox() -> void:
	if _signal_outbox.is_empty() or _signal_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_post(_signal_request, _signal_outbox.front())


func _on_signal_sent(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code >= 200 and response_code < 300 and not _signal_outbox.is_empty():
		_signal_outbox.pop_front()
	_flush_signal_outbox()


func _on_action_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response := _parse_response(response_code, body)
	if response.is_empty():
		connection_status_changed.emit("Lobby service did not respond. Check that the multiplayer server finished deploying.", true)
		return
	if not bool(response.get("ok", false)):
		connection_status_changed.emit(String(response.get("error", "Lobby request failed.")), true)
		return
	match _action_kind:
		"create":
			join_code = String(response.get("code", ""))
			_host_token = String(response.get("host_token", ""))
			_peer_token = String(response.get("peer_token", ""))
			local_peer_id = 1
			is_host = true
			members = response.get("members", []) as Array
			if _uses_cloudflare():
				_connect_cloudflare_socket()
			else:
				_initialize_host()
			connection_status_changed.emit("Lobby ready. Share code %s." % join_code, false)
			lobby_state_changed.emit(members, join_code)
		"join":
			join_code = String(response.get("code", ""))
			local_peer_id = int(response.get("peer_id", 0))
			_peer_token = String(response.get("peer_token", ""))
			is_host = false
			members = response.get("members", []) as Array
			if _uses_cloudflare():
				_connect_cloudflare_socket()
			else:
				_initialize_client()
			connection_status_changed.emit("Joined lobby %s. Waiting for the host." % join_code, false)
			lobby_state_changed.emit(members, join_code)
		"start":
			_mark_game_started()


func _on_poll_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response := _parse_response(response_code, body)
	if not bool(response.get("ok", false)):
		return
	for message_variant in response.get("messages", []):
		var message := message_variant as Dictionary
		var signal_id := String(message.get("id", ""))
		if signal_id.is_empty() or _seen_signal_ids.has(signal_id):
			continue
		_seen_signal_ids[signal_id] = true
		var sender_id := int(message.get("from", 0))
		if not _connections.has(sender_id):
			_add_connection(sender_id, is_host)
		var connection := _connections.get(sender_id) as WebRTCPeerConnection
		if connection == null:
			continue
		var payload := message.get("payload", {}) as Dictionary
		match String(message.get("kind", "")):
			"session":
				connection.set_remote_description(String(payload.get("type", "")), String(payload.get("sdp", "")))
			"ice":
				connection.add_ice_candidate(String(payload.get("media", "")), int(payload.get("index", 0)), String(payload.get("candidate", "")))


func _on_status_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response := _parse_response(response_code, body)
	if not bool(response.get("ok", false)):
		return
	members = response.get("members", []) as Array
	for member_variant in members:
		var member := member_variant as Dictionary
		var peer_id := int(member.get("peer_id", 0))
		if is_host and peer_id > 1:
			_add_connection(peer_id, true)
	lobby_state_changed.emit(members, join_code)
	if bool(response.get("started", false)):
		_mark_game_started()


func _mark_game_started() -> void:
	if game_started:
		return
	game_started = true
	for member_variant in members:
		var peer_id := int((member_variant as Dictionary).get("peer_id", 0))
		if peer_id > 0 and not _relic_charges.has(peer_id):
			_relic_charges[peer_id] = 0
	connection_status_changed.emit("The host started the run.", false)
	game_start_requested.emit()
	_sync_elapsed = HTTP_SYNC_INTERVAL


func _broadcast_local_player_state() -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var player := GameManager.player
	if not is_instance_valid(player) or not player.visible:
		return
	_receive_player_state.rpc(local_peer_id, player.global_position, player.global_rotation, player.velocity, MetaProgression.selected_weapon_id)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _receive_player_state(peer_id: int, position: Vector2, facing: float, velocity: Vector2, weapon_id: String) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	var avatar := _get_or_create_avatar(peer_id)
	if avatar != null:
		avatar.apply_network_state(position, facing, velocity, weapon_id)


func broadcast_spell_cast(spell_id: String, origin: Vector2, target: Vector2, modifiers: SpellModifiers = null) -> void:
	if not game_started or not is_in_lobby():
		return
	_http_cast_sequence += 1
	_pending_http_casts.append({
		"id": "%d-%d-%d" % [Time.get_unix_time_from_system(), local_peer_id, _http_cast_sequence],
		"spell_id": spell_id,
		"ox": origin.x,
		"oy": origin.y,
		"tx": target.x,
		"ty": target.y,
		"modifiers": _modifiers_to_dictionary(modifiers),
	})
	if _pending_http_casts.size() > 16:
		_pending_http_casts.pop_front()


@rpc("any_peer", "call_remote", "reliable")
func _receive_spell_cast(peer_id: int, spell_id: String, origin: Vector2, target: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_spawn_remote_spell(peer_id, spell_id, origin, target)


func _spawn_remote_spell(peer_id: int, spell_id: String, origin: Vector2, target: Vector2, modifier_data: Dictionary = {}) -> void:
	var definition := MetaProgression.find_spell_definition(spell_id)
	var avatar := _get_or_create_avatar(peer_id)
	var scene := get_tree().current_scene
	if definition == null or definition.spell_scene == null or avatar == null or scene == null:
		return
	var first_spell := definition.spell_scene.instantiate() as Spell
	if first_spell == null:
		return
	var modifiers := _modifiers_from_dictionary(modifier_data)
	if modifier_data.is_empty() and MetaProgression.is_fusion_spell_id(definition.id):
		modifiers.damage_multiplier *= MetaProgression.get_fusion_damage_multiplier(definition.id)
	var projectile_count := maxi(1 + modifiers.extra_projectiles, 1) if first_spell.supports_projectile_modifiers() else 1
	for projectile_index in range(projectile_count):
		var spell := first_spell if projectile_index == 0 else definition.spell_scene.instantiate() as Spell
		if spell == null:
			continue
		var spread := deg_to_rad(8.0) * (projectile_index - (projectile_count - 1) * 0.5)
		var offset_target := origin + (target - origin).rotated(spread)
		spell.configure(definition, avatar, origin, offset_target, modifiers)
		spell.sound_enabled = projectile_index == 0
		scene.add_child(spell)
		spell.activate()


func _modifiers_to_dictionary(modifiers: SpellModifiers) -> Dictionary:
	if modifiers == null:
		return {}
	return {
		"damage": modifiers.damage_multiplier, "speed": modifiers.projectile_speed_multiplier,
		"area": modifiers.area_multiplier, "critical_chance": modifiers.critical_chance,
		"critical_multiplier": modifiers.critical_multiplier, "extra": modifiers.extra_projectiles,
		"bounce": modifiers.bounce_count, "pierce": modifiers.pierce_bonus,
		"freeze_chance": modifiers.freeze_chance, "freeze_duration": modifiers.freeze_duration,
		"burn_chance": modifiers.burn_chance, "burn_damage": modifiers.burn_damage, "burn_duration": modifiers.burn_duration,
		"poison_chance": modifiers.poison_chance, "poison_damage": modifiers.poison_damage, "poison_duration": modifiers.poison_duration,
		"homing": modifiers.homing_enabled, "homing_bonus": modifiers.homing_strength_bonus,
	}


func _modifiers_from_dictionary(data: Dictionary) -> SpellModifiers:
	var modifiers := SpellModifiers.new()
	if data.is_empty():
		return modifiers
	modifiers.damage_multiplier = clampf(float(data.get("damage", 1.0)), 0.1, 20.0)
	modifiers.projectile_speed_multiplier = clampf(float(data.get("speed", 1.0)), 0.1, 10.0)
	modifiers.area_multiplier = clampf(float(data.get("area", 1.0)), 0.1, 10.0)
	modifiers.critical_chance = clampf(float(data.get("critical_chance", 0.0)), 0.0, 1.0)
	modifiers.critical_multiplier = clampf(float(data.get("critical_multiplier", 2.0)), 1.0, 10.0)
	modifiers.extra_projectiles = clampi(int(data.get("extra", 0)), 0, 12)
	modifiers.bounce_count = clampi(int(data.get("bounce", 0)), 0, 20)
	modifiers.pierce_bonus = clampi(int(data.get("pierce", 0)), 0, 30)
	modifiers.freeze_chance = clampf(float(data.get("freeze_chance", 0.0)), 0.0, 1.0)
	modifiers.freeze_duration = clampf(float(data.get("freeze_duration", 0.0)), 0.0, 10.0)
	modifiers.burn_chance = clampf(float(data.get("burn_chance", 0.0)), 0.0, 1.0)
	modifiers.burn_damage = clampf(float(data.get("burn_damage", 0.0)), 0.0, 10000.0)
	modifiers.burn_duration = clampf(float(data.get("burn_duration", 3.0)), 0.0, 20.0)
	modifiers.poison_chance = clampf(float(data.get("poison_chance", 0.0)), 0.0, 1.0)
	modifiers.poison_damage = clampf(float(data.get("poison_damage", 0.0)), 0.0, 10000.0)
	modifiers.poison_duration = clampf(float(data.get("poison_duration", 4.0)), 0.0, 20.0)
	modifiers.homing_enabled = bool(data.get("homing", false))
	modifiers.homing_strength_bonus = clampf(float(data.get("homing_bonus", 0.0)), 0.0, 20.0)
	return modifiers


func get_nearest_combat_target(from_position: Vector2) -> Node2D:
	var nearest := GameManager.player
	var nearest_distance := from_position.distance_squared_to(nearest.global_position) if is_instance_valid(nearest) else INF
	if is_host:
		for avatar_variant in _remote_avatars.values():
			var avatar := avatar_variant as RemotePlayerAvatar
			if not is_instance_valid(avatar) or not avatar.is_combat_active():
				continue
			var distance := from_position.distance_squared_to(avatar.global_position)
			if distance < nearest_distance:
				nearest = avatar
				nearest_distance = distance
	for ally_variant in get_tree().get_nodes_in_group("allied_targets"):
		var ally := ally_variant as Node2D
		if not is_instance_valid(ally) or ally.is_queued_for_deletion():
			continue
		var distance := from_position.distance_squared_to(ally.global_position)
		if distance < nearest_distance:
			nearest = ally
			nearest_distance = distance
	return nearest


func is_world_authority() -> bool:
	return not is_in_lobby() or is_host


func _capture_player_state() -> Dictionary:
	var player := GameManager.player
	if not is_instance_valid(player):
		return {}
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	return {
		"x": player.global_position.x,
		"y": player.global_position.y,
		"rotation": player.global_rotation,
		"vx": player.velocity.x if player is CharacterBody2D else 0.0,
		"vy": player.velocity.y if player is CharacterBody2D else 0.0,
		"weapon_id": MetaProgression.selected_weapon_id,
		"maximum_health": health.maximum_health if health != null else 100.0,
		"revive_target": _pending_revive_target,
		"camp_upgrade_id": _pending_camp_upgrade_id,
		"camp_upgrade_choice": _pending_camp_upgrade_choice,
		"camp_upgrade_request": _pending_camp_upgrade_request,
	}


func _capture_interact_request() -> void:
	if not is_realtime_coop_session() or not InputManager.is_interact_just_pressed() or not is_instance_valid(GameManager.player):
		return
	_pending_revive_target = _find_nearest_downed_peer(GameManager.player.global_position, local_peer_id)
	if is_host and _pending_revive_target > 0:
		_try_revive(local_peer_id, _pending_revive_target)
		_pending_revive_target = 0


func _send_socket_sync() -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var player_state := _capture_player_state()
	if player_state.is_empty():
		return
	var payload := {
		"type": "sync",
		"state": player_state,
		"casts": _pending_http_casts.duplicate(true),
	}
	if is_host:
		payload["world"] = _capture_world_snapshot()
	var error := _socket.send_text(JSON.stringify(payload))
	if error == OK:
		_pending_http_casts.clear()
		_pending_revive_target = 0
		_clear_pending_camp_upgrade()


func _handle_socket_message(message_text: String) -> void:
	var parsed = JSON.parse_string(message_text)
	if not parsed is Dictionary:
		return
	var message := parsed as Dictionary
	match String(message.get("type", "")):
		"welcome":
			members = message.get("members", []) as Array
			lobby_state_changed.emit(members, join_code)
			if not is_host and message.has("world"):
				_apply_world_snapshot(message.get("world", {}) as Dictionary)
			if bool(message.get("started", false)):
				_mark_game_started()
		"members":
			members = message.get("members", []) as Array
			lobby_state_changed.emit(members, join_code)
		"started":
			_mark_game_started()
		"sync":
			_apply_socket_sync(message)
		"closed":
			connection_status_changed.emit(String(message.get("message", "The lobby closed.")), true)
			leave_lobby(false)


func _apply_socket_sync(message: Dictionary) -> void:
	var peer_id := int(message.get("peer_id", 0))
	if peer_id <= 0 or peer_id == local_peer_id:
		return
	var state := message.get("state", {}) as Dictionary
	var avatar := _get_or_create_avatar(peer_id)
	if avatar != null and not state.is_empty():
		avatar.apply_network_state(
			Vector2(float(state.get("x", 0.0)), float(state.get("y", 0.0))),
			float(state.get("rotation", 0.0)),
			Vector2(float(state.get("vx", 0.0)), float(state.get("vy", 0.0))),
			String(state.get("weapon_id", "wand")),
			float(state.get("maximum_health", 100.0))
		)
	if is_host:
		var revive_target := int(state.get("revive_target", 0))
		if revive_target > 0:
			_try_revive(peer_id, revive_target)
		_handle_space_camp_upgrade_state(state)
	for cast_variant in message.get("casts", []):
		var cast := cast_variant as Dictionary
		var cast_id := String(cast.get("id", ""))
		if cast_id.is_empty() or _seen_http_cast_ids.has(cast_id):
			continue
		_remember_remote_cast(cast_id)
		_spawn_remote_spell(
			peer_id,
			String(cast.get("spell_id", "")),
			Vector2(float(cast.get("ox", 0.0)), float(cast.get("oy", 0.0))),
			Vector2(float(cast.get("tx", 0.0)), float(cast.get("ty", 0.0))),
			cast.get("modifiers", {}) as Dictionary
		)
	if not is_host and message.has("world"):
		_apply_world_snapshot(message.get("world", {}) as Dictionary)


func _connect_cloudflare_socket() -> void:
	if not _uses_cloudflare() or join_code.is_empty() or _peer_token.is_empty():
		return
	_socket = WebSocketPeer.new()
	var url := "%s/lobby/%s/ws?peer_id=%d&peer_token=%s" % [
		CLOUDFLARE_WORKER_URL.trim_suffix("/").replace("https://", "wss://").replace("http://", "ws://"),
		join_code.uri_encode(), local_peer_id, _peer_token.uri_encode(),
	]
	var error := _socket.connect_to_url(url)
	if error != OK:
		connection_status_changed.emit("Could not open the real-time co-op connection.", true)


func _send_http_sync() -> void:
	var player_state := _capture_player_state()
	if player_state.is_empty():
		return
	var casts: Array = _pending_http_casts.duplicate(true)
	_sync_cast_ids_in_flight.clear()
	for cast_variant in casts:
		_sync_cast_ids_in_flight.append(String((cast_variant as Dictionary).get("id", "")))
	var payload := {
		"action": "sync",
		"code": join_code,
		"peer_id": local_peer_id,
		"state": player_state,
		"casts": casts,
	}
	if is_host:
		payload["host_token"] = _host_token
		payload["world"] = _capture_world_snapshot()
	_post(_sync_request, payload)


func _on_sync_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response := _parse_response(response_code, body)
	if not bool(response.get("ok", false)):
		return
	for index in range(_pending_http_casts.size() - 1, -1, -1):
		if _sync_cast_ids_in_flight.has(String(_pending_http_casts[index].get("id", ""))):
			_pending_http_casts.remove_at(index)
	_sync_cast_ids_in_flight.clear()
	_pending_revive_target = 0
	_clear_pending_camp_upgrade()
	for state_variant in response.get("players", []):
		var state := state_variant as Dictionary
		var peer_id := int(state.get("peer_id", 0))
		if peer_id <= 0 or peer_id == local_peer_id:
			continue
		var avatar := _get_or_create_avatar(peer_id)
		if avatar != null:
			avatar.apply_network_state(
				Vector2(float(state.get("x", 0.0)), float(state.get("y", 0.0))),
				float(state.get("rotation", 0.0)),
				Vector2(float(state.get("vx", 0.0)), float(state.get("vy", 0.0))),
				String(state.get("weapon_id", "wand")),
				float(state.get("maximum_health", 100.0))
			)
		if is_host:
			var revive_target := int(state.get("revive_target", 0))
			if revive_target > 0:
				_try_revive(peer_id, revive_target)
			_handle_space_camp_upgrade_state(state)
	for cast_variant in response.get("casts", []):
		var cast := cast_variant as Dictionary
		var cast_id := String(cast.get("id", ""))
		var peer_id := int(cast.get("peer_id", 0))
		if cast_id.is_empty() or peer_id == local_peer_id or _seen_http_cast_ids.has(cast_id):
			continue
		_remember_remote_cast(cast_id)
		_spawn_remote_spell(
			peer_id,
			String(cast.get("spell_id", "")),
			Vector2(float(cast.get("ox", 0.0)), float(cast.get("oy", 0.0))),
			Vector2(float(cast.get("tx", 0.0)), float(cast.get("ty", 0.0))),
			cast.get("modifiers", {}) as Dictionary
		)
	if not is_host:
		_apply_world_snapshot(response.get("world", {}) as Dictionary)


func _capture_world_snapshot() -> Dictionary:
	var actors: Array[Dictionary] = []
	var captured_enemies := 0
	for enemy in GameManager.enemies:
		if is_instance_valid(enemy) and not enemy is RemoteWorldActor:
			actors.append(_capture_actor(enemy, false))
			captured_enemies += 1
			if captured_enemies >= MAX_SNAPSHOT_ENEMIES:
				break
	for boss in GameManager.active_bosses:
		if is_instance_valid(boss):
			actors.append(_capture_actor(boss, true))
	var captured_allies := 0
	for ally_variant in get_tree().get_nodes_in_group("network_allies"):
		var ally := ally_variant as Node2D
		if is_instance_valid(ally) and ally.has_method("get_network_actor_data"):
			var ally_data := ally.call("get_network_actor_data") as Dictionary
			ally_data["id"] = "ally-" + str(ally.get_instance_id())
			ally_data["x"] = ally.global_position.x
			ally_data["y"] = ally.global_position.y
			ally_data["rotation"] = ally.global_rotation
			actors.append(ally_data)
			captured_allies += 1
			if captured_allies >= MAX_SNAPSHOT_ALLIES:
				break
	var hazards: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("network_hazards"):
		var hazard := node as BossHazard
		if hazard == null:
			continue
		hazards.append({
			"id": str(hazard.get_instance_id()), "shape": hazard.shape_type,
			"x": hazard.global_position.x, "y": hazard.global_position.y, "rotation": hazard.global_rotation,
			"radius": hazard.radius, "length": hazard.line_length, "width": hazard.line_width,
			"warning": hazard.warning_duration, "active": hazard.active_duration, "elapsed": hazard._elapsed,
			"damage": hazard.damage, "color": hazard.accent_color.to_html(false),
		})
		if hazards.size() >= MAX_SNAPSHOT_HAZARDS:
			break
	var projectiles: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("network_projectiles"):
		var projectile := node as BossProjectile
		if projectile != null:
			projectiles.append({
				"id": str(projectile.get_instance_id()), "x": projectile.global_position.x, "y": projectile.global_position.y,
				"dx": projectile.direction.x, "dy": projectile.direction.y, "speed": projectile.speed,
				"damage": projectile.damage, "radius": projectile.radius, "lifetime": projectile.lifetime,
				"color": projectile.accent_color.to_html(false),
			})
			if projectiles.size() >= MAX_SNAPSHOT_PROJECTILES:
				break
			continue
		var ally_projectile := node as SpawnerUnitProjectile
		if ally_projectile != null:
			var ally_radius := 8.0 if ally_projectile.shot_style in ["odyssey_beam", "aries_beam"] else (3.0 if ally_projectile.shot_style == "aries_dart" else 5.0 + ally_projectile.tier * 0.35)
			projectiles.append({
				"id": "ally-shot-" + str(ally_projectile.get_instance_id()), "x": ally_projectile.global_position.x, "y": ally_projectile.global_position.y,
				"dx": ally_projectile.direction.x, "dy": ally_projectile.direction.y, "speed": ally_projectile.speed,
				"damage": 0.0, "radius": ally_radius, "lifetime": ally_projectile.lifetime,
				"color": ally_projectile.accent_color.to_html(false), "shot_style": ally_projectile.shot_style,
			})
			if projectiles.size() >= MAX_SNAPSHOT_PROJECTILES:
				break
	var player_healths := {}
	var local_health := GameManager.player.get_node_or_null("HealthComponent") as HealthComponent if is_instance_valid(GameManager.player) else null
	if local_health != null:
		player_healths[str(local_peer_id)] = {"current": local_health.current_health, "maximum": local_health.maximum_health}
	for peer_id_variant in _remote_avatars:
		var avatar := _remote_avatars[peer_id_variant] as RemotePlayerAvatar
		if is_instance_valid(avatar):
			player_healths[str(peer_id_variant)] = avatar.get_health_snapshot()
	return {
		"actors": actors, "hazards": hazards, "projectiles": projectiles,
		"player_healths": player_healths, "experience": GameManager.experience, "coins": GameManager.coins,
		"damage_events": VFXManager.get_recent_network_damage_events(),
		"downed": _serialize_downed_peers(), "relic_charges": _serialize_int_dictionary(_relic_charges),
	}


func _capture_actor(actor: Node2D, is_boss_actor: bool) -> Dictionary:
	var definition = actor.get("definition")
	var color := Color("e34c67")
	var radius := 20.0
	if definition is EnemyDefinition:
		color = definition.color
		radius = 20.0 * definition.visual_scale * actor.scale.x
	elif definition is BossDefinition:
		color = definition.primary_color
		radius = 52.0 * actor.scale.x
	var health := actor.get_node_or_null("HealthComponent") as HealthComponent
	var ratio := health.current_health / maxf(health.maximum_health, 1.0) if health != null else 1.0
	var shield_ratio := float(actor.call("get_shield_ratio")) if actor.has_method("get_shield_ratio") else 0.0
	return {
		"id": ("boss-" if is_boss_actor else "enemy-") + str(actor.get_instance_id()),
		"x": actor.global_position.x, "y": actor.global_position.y, "rotation": actor.global_rotation,
		"color": color.to_html(false), "radius": radius, "health": ratio, "shield": shield_ratio, "boss": is_boss_actor,
	}


func _apply_world_snapshot(world: Dictionary) -> void:
	if world.is_empty():
		return
	var active_actor_ids: Dictionary = {}
	for actor_variant in world.get("actors", []):
		var data := actor_variant as Dictionary
		var actor_id := String(data.get("id", ""))
		if actor_id.is_empty():
			continue
		active_actor_ids[actor_id] = true
		var actor := _remote_world_actors.get(actor_id) as RemoteWorldActor
		if not is_instance_valid(actor):
			actor = RemoteWorldActor.new()
			actor.network_id = actor_id
			get_tree().current_scene.add_child(actor)
			_remote_world_actors[actor_id] = actor
		actor.apply_snapshot(data)
	_remove_missing_remote_nodes(_remote_world_actors, active_actor_ids)
	_apply_remote_hazards(world.get("hazards", []) as Array)
	_apply_remote_projectiles(world.get("projectiles", []) as Array)
	var healths := world.get("player_healths", {}) as Dictionary
	var local_health := healths.get(str(local_peer_id), {}) as Dictionary
	if not local_health.is_empty() and is_instance_valid(GameManager.player) and GameManager.player.has_method("synchronize_network_health"):
		GameManager.player.synchronize_network_health(float(local_health.get("current", 100.0)), float(local_health.get("maximum", 100.0)))
	for peer_id_variant in _remote_avatars.keys():
		var avatar := _remote_avatars[peer_id_variant] as RemotePlayerAvatar
		var health_data := healths.get(str(peer_id_variant), {}) as Dictionary
		if is_instance_valid(avatar) and not health_data.is_empty():
			avatar.apply_network_health(float(health_data.get("current", 100.0)), float(health_data.get("maximum", 100.0)))
	_apply_network_damage_events(world.get("damage_events", []) as Array)
	_downed_peers = _deserialize_int_dictionary(world.get("downed", {}) as Dictionary)
	_relic_charges = _deserialize_int_dictionary(world.get("relic_charges", {}) as Dictionary)
	for peer_id_variant in _remote_avatars:
		var downed_avatar := _remote_avatars[peer_id_variant] as RemotePlayerAvatar
		if is_instance_valid(downed_avatar):
			downed_avatar.set_dropped_relics(get_dropped_relic_count(int(peer_id_variant)))
	GameManager.synchronize_shared_rewards(int(world.get("experience", 0)), int(world.get("coins", 0)))


func _apply_network_damage_events(events: Array) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for event_variant in events:
		var event := event_variant as Dictionary
		var event_id := int(event.get("id", 0))
		if event_id <= 0 or _seen_damage_event_ids.has(event_id):
			continue
		_seen_damage_event_ids[event_id] = true
		VFXManager.spawn_damage_number(scene, Vector2(float(event.get("x", 0.0)), float(event.get("y", 0.0))), float(event.get("amount", 0.0)), Color(String(event.get("color", "ffffff"))))
	while _seen_damage_event_ids.size() > 128:
		_seen_damage_event_ids.erase(_seen_damage_event_ids.keys().front())


func _remember_remote_cast(cast_id: String) -> void:
	_seen_http_cast_ids[cast_id] = true
	while _seen_http_cast_ids.size() > MAX_SEEN_CAST_IDS:
		_seen_http_cast_ids.erase(_seen_http_cast_ids.keys().front())


func _serialize_downed_peers() -> Dictionary:
	var serialized := {}
	for peer_id in _downed_peers:
		serialized[str(peer_id)] = _downed_peers[peer_id]
	return serialized


func _serialize_int_dictionary(source: Dictionary) -> Dictionary:
	var serialized := {}
	for key in source:
		serialized[str(key)] = int(source[key])
	return serialized


func _deserialize_int_dictionary(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		result[int(key)] = source[key]
	return result


func _find_nearest_downed_peer(from_position: Vector2, reviver_peer_id: int) -> int:
	var nearest_peer := 0
	var nearest_distance := 125.0 * 125.0
	for peer_id_variant in _downed_peers:
		var peer_id := int(peer_id_variant)
		if peer_id == reviver_peer_id:
			continue
		var data := _downed_peers[peer_id_variant] as Dictionary
		var distance := from_position.distance_squared_to(Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))))
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_peer = peer_id
	return nearest_peer


func _try_revive(reviver_peer_id: int, target_peer_id: int) -> bool:
	if not is_host or not _downed_peers.has(target_peer_id):
		return false
	var reviver := GameManager.player if reviver_peer_id == 1 else _remote_avatars.get(reviver_peer_id) as Node2D
	var target_data := _downed_peers[target_peer_id] as Dictionary
	var target_position := Vector2(float(target_data.get("x", 0.0)), float(target_data.get("y", 0.0)))
	if not is_instance_valid(reviver) or reviver.global_position.distance_squared_to(target_position) > 145.0 * 145.0:
		return false
	var charge := int(_relic_charges.get(reviver_peer_id, 0))
	var dropped := int(target_data.get("dropped_relics", 0))
	if charge > 0:
		_relic_charges[reviver_peer_id] = charge - 1
	elif dropped > 0:
		target_data["dropped_relics"] = dropped - 1
	else:
		connection_status_changed.emit("A boss relic is required to revive a teammate.", true)
		return false
	if target_peer_id == 1 and is_instance_valid(GameManager.player):
		var health := GameManager.player.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			GameManager.player.synchronize_network_health(health.maximum_health * 0.5, health.maximum_health)
	else:
		var avatar := _remote_avatars.get(target_peer_id) as RemotePlayerAvatar
		if is_instance_valid(avatar):
			avatar.revive(0.5)
	_downed_peers.erase(target_peer_id)
	VFXManager.spawn_death(get_tree().current_scene, target_position, Color("7fffe5"))
	return true


func _apply_remote_hazards(snapshots: Array) -> void:
	var active_ids: Dictionary = {}
	for snapshot_variant in snapshots:
		var data := snapshot_variant as Dictionary
		var network_id := String(data.get("id", ""))
		active_ids[network_id] = true
		var hazard := _remote_hazards.get(network_id) as BossHazard
		if not is_instance_valid(hazard):
			hazard = BOSS_HAZARD_SCENE.instantiate() as BossHazard
			if int(data.get("shape", 0)) == BossHazard.ShapeType.CIRCLE:
				hazard.configure_circle(Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))), float(data.get("radius", 90.0)), float(data.get("warning", 0.9)), float(data.get("active", 0.3)), float(data.get("damage", 25.0)), Color(String(data.get("color", "ff4455"))))
			else:
				hazard.configure_line(Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))), float(data.get("rotation", 0.0)), float(data.get("length", 600.0)), float(data.get("width", 46.0)), float(data.get("warning", 0.9)), float(data.get("active", 0.3)), float(data.get("damage", 25.0)), Color(String(data.get("color", "ff4455"))))
			get_tree().current_scene.add_child(hazard)
			hazard.collision_mask = 0
			hazard.monitoring = false
			_remote_hazards[network_id] = hazard
		hazard.global_position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
		hazard.global_rotation = float(data.get("rotation", 0.0))
		hazard._elapsed = float(data.get("elapsed", 0.0))
	_remove_missing_remote_nodes(_remote_hazards, active_ids)


func _apply_remote_projectiles(snapshots: Array) -> void:
	var active_ids: Dictionary = {}
	for snapshot_variant in snapshots:
		var data := snapshot_variant as Dictionary
		var network_id := String(data.get("id", ""))
		active_ids[network_id] = true
		var projectile := _remote_projectiles.get(network_id) as BossProjectile
		if not is_instance_valid(projectile):
			projectile = BOSS_PROJECTILE_SCENE.instantiate() as BossProjectile
			projectile.configure(Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))), Vector2(float(data.get("dx", 1.0)), float(data.get("dy", 0.0))), float(data.get("speed", 320.0)), float(data.get("damage", 18.0)), float(data.get("radius", 11.0)), Color(String(data.get("color", "ff4455"))), float(data.get("lifetime", 4.0)))
			projectile.visual_style = String(data.get("shot_style", "standard"))
			get_tree().current_scene.add_child(projectile)
			projectile.collision_mask = 0
			projectile.monitoring = false
			_remote_projectiles[network_id] = projectile
		projectile.global_position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
		projectile.direction = Vector2(float(data.get("dx", 1.0)), float(data.get("dy", 0.0))).normalized()
		projectile.lifetime = float(data.get("lifetime", 1.0))
		projectile.visual_style = String(data.get("shot_style", "standard"))
		projectile.queue_redraw()
	_remove_missing_remote_nodes(_remote_projectiles, active_ids)


func _remove_missing_remote_nodes(nodes: Dictionary, active_ids: Dictionary) -> void:
	for network_id in nodes.keys():
		if active_ids.has(network_id):
			continue
		var node := nodes[network_id] as Node
		if is_instance_valid(node):
			node.queue_free()
		nodes.erase(network_id)


func _get_or_create_avatar(peer_id: int) -> RemotePlayerAvatar:
	var existing := _remote_avatars.get(peer_id) as RemotePlayerAvatar
	if is_instance_valid(existing):
		return existing
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var avatar := RemotePlayerAvatar.new()
	avatar.name = "Teammate%d" % peer_id
	avatar.peer_id = peer_id
	avatar.display_name = _member_name(peer_id)
	scene.add_child(avatar)
	_remote_avatars[peer_id] = avatar
	return avatar


func _member_name(peer_id: int) -> String:
	for member_variant in members:
		var member := member_variant as Dictionary
		if int(member.get("peer_id", 0)) == peer_id:
			return String(member.get("name", "Wizard %d" % peer_id))
	return "Wizard %d" % peer_id


func _on_peer_disconnected(peer_id: int) -> void:
	_connections.erase(peer_id)
	var avatar := _remote_avatars.get(peer_id) as RemotePlayerAvatar
	if is_instance_valid(avatar):
		avatar.queue_free()
	_remote_avatars.erase(peer_id)


func _reset_network_state() -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.close(1000, "Leaving lobby")
	_socket = WebSocketPeer.new()
	_socket_was_open = false
	_socket_reconnect_remaining = 0.0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for avatar_variant in _remote_avatars.values():
		var avatar := avatar_variant as RemotePlayerAvatar
		if is_instance_valid(avatar):
			avatar.queue_free()
	for collection in [_remote_world_actors, _remote_hazards, _remote_projectiles]:
		for node_variant in collection.values():
			var remote_node := node_variant as Node
			if is_instance_valid(remote_node):
				remote_node.queue_free()
	join_code = ""
	local_peer_id = 0
	is_host = false
	_host_token = ""
	_peer_token = ""
	members.clear()
	game_started = false
	_clear_pending_camp_upgrade()
	_seen_camp_upgrade_requests.clear()
	_connections.clear()
	_remote_avatars.clear()
	_remote_world_actors.clear()
	_remote_hazards.clear()
	_remote_projectiles.clear()
	_seen_signal_ids.clear()
	_signal_outbox.clear()
	_pending_http_casts.clear()
	_sync_cast_ids_in_flight.clear()
	_seen_http_cast_ids.clear()
	_seen_damage_event_ids.clear()
	_downed_peers.clear()
	_relic_charges.clear()
	_pending_revive_target = 0
	_cloudflare_status_requested = false


func _post(request: HTTPRequest, payload: Dictionary) -> void:
	request.request(_endpoint(), ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))


func _http_get(request: HTTPRequest, parameters: Dictionary) -> void:
	var query: Array[String] = []
	for key in parameters:
		query.append("%s=%s" % [String(key).uri_encode(), str(parameters[key]).uri_encode()])
	request.request("%s?%s" % [_endpoint(), "&".join(query)])


func _endpoint() -> String:
	if _uses_cloudflare():
		return "%s/api/lobby" % CLOUDFLARE_WORKER_URL.trim_suffix("/")
	if OS.has_feature("web"):
		return "%s/_api/lobby" % str(JavaScriptBridge.eval("window.location.origin"))
	return "http://127.0.0.1:8888/_api/lobby"


func _uses_cloudflare() -> bool:
	return CLOUDFLARE_WORKER_URL.begins_with("https://") and not CLOUDFLARE_WORKER_URL.contains("REPLACE")


func _parse_response(response_code: int, body: PackedByteArray) -> Dictionary:
	if response_code < 200 or response_code >= 300:
		return {}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	return parsed as Dictionary if parsed is Dictionary else {}
