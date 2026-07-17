extends Node

signal lobby_state_changed(members: Array, join_code: String)
signal connection_status_changed(message: String, is_error: bool)
signal game_start_requested
signal lobby_left

const MAX_PLAYERS := 3
const SIGNAL_POLL_INTERVAL := 0.28
const STATUS_POLL_INTERVAL := 0.75
const PLAYER_STATE_INTERVAL := 0.05
const STUN_CONFIGURATION := {
	"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]
}

var join_code := ""
var local_peer_id := 0
var is_host := false
var _host_token := ""
var members: Array = []
var game_started := false

var _webrtc_multiplayer: WebRTCMultiplayerPeer
var _connections: Dictionary = {}
var _remote_avatars: Dictionary = {}
var _seen_signal_ids: Dictionary = {}
var _signal_outbox: Array[Dictionary] = []
var _poll_elapsed := 0.0
var _status_elapsed := 0.0
var _state_elapsed := 0.0
var _action_kind := ""
var _action_request: HTTPRequest
var _poll_request: HTTPRequest
var _status_request: HTTPRequest
var _signal_request: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_action_request = _make_request(_on_action_completed)
	_poll_request = _make_request(_on_poll_completed)
	_status_request = _make_request(_on_status_completed)
	_signal_request = _make_request(_on_signal_sent)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


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
	if not is_in_lobby():
		return 1.0
	return 1.5 * get_player_count()


func request_lobby_refresh() -> void:
	_status_elapsed = STATUS_POLL_INTERVAL


func _process(delta: float) -> void:
	if not is_in_lobby():
		return
	_poll_elapsed += delta
	_status_elapsed += delta
	_state_elapsed += delta
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
		connection_status_changed.emit("Lobby service did not respond. Try again after the Netlify deploy finishes.", true)
		return
	if not bool(response.get("ok", false)):
		connection_status_changed.emit(String(response.get("error", "Lobby request failed.")), true)
		return
	match _action_kind:
		"create":
			join_code = String(response.get("code", ""))
			_host_token = String(response.get("host_token", ""))
			local_peer_id = 1
			is_host = true
			members = response.get("members", []) as Array
			_initialize_host()
			connection_status_changed.emit("Lobby ready. Share code %s." % join_code, false)
			lobby_state_changed.emit(members, join_code)
		"join":
			join_code = String(response.get("code", ""))
			local_peer_id = int(response.get("peer_id", 0))
			is_host = false
			members = response.get("members", []) as Array
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
	connection_status_changed.emit("The host started the run.", false)
	game_start_requested.emit()


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


func broadcast_spell_cast(spell_id: String, origin: Vector2, target: Vector2) -> void:
	if not game_started or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_receive_spell_cast.rpc(local_peer_id, spell_id, origin, target)


@rpc("any_peer", "call_remote", "reliable")
func _receive_spell_cast(peer_id: int, spell_id: String, origin: Vector2, target: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	var definition := MetaProgression.find_spell_definition(spell_id)
	var avatar := _get_or_create_avatar(peer_id)
	var scene := get_tree().current_scene
	if definition == null or definition.spell_scene == null or avatar == null or scene == null:
		return
	var spell := definition.spell_scene.instantiate() as Spell
	if spell == null:
		return
	var modifiers := SpellModifiers.new()
	if MetaProgression.is_fusion_spell_id(definition.id):
		modifiers.damage_multiplier *= MetaProgression.get_fusion_damage_multiplier(definition.id)
	spell.configure(definition, avatar, origin, target, modifiers)
	spell.sound_enabled = true
	scene.add_child(spell)
	spell.activate()


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
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for avatar_variant in _remote_avatars.values():
		var avatar := avatar_variant as RemotePlayerAvatar
		if is_instance_valid(avatar):
			avatar.queue_free()
	join_code = ""
	local_peer_id = 0
	is_host = false
	_host_token = ""
	members.clear()
	game_started = false
	_connections.clear()
	_remote_avatars.clear()
	_seen_signal_ids.clear()
	_signal_outbox.clear()


func _post(request: HTTPRequest, payload: Dictionary) -> void:
	request.request(_endpoint(), ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))


func _http_get(request: HTTPRequest, parameters: Dictionary) -> void:
	var query: Array[String] = []
	for key in parameters:
		query.append("%s=%s" % [String(key).uri_encode(), str(parameters[key]).uri_encode()])
	request.request("%s?%s" % [_endpoint(), "&".join(query)])


func _endpoint() -> String:
	if OS.has_feature("web"):
		return "%s/_api/lobby" % str(JavaScriptBridge.eval("window.location.origin"))
	return "http://127.0.0.1:8888/_api/lobby"


func _parse_response(response_code: int, body: PackedByteArray) -> Dictionary:
	if response_code < 200 or response_code >= 300:
		return {}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	return parsed as Dictionary if parsed is Dictionary else {}
