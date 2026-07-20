extends Node

var _using_controller := false
var _last_controller_aim := Vector2.RIGHT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_controller_bindings()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_using_controller = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		_using_controller = false


func get_movement_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func get_aim_position(viewport: Viewport) -> Vector2:
	if _using_controller and is_instance_valid(GameManager.player):
		var aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if aim.length() > 0.18:
			_last_controller_aim = aim.normalized()
		return GameManager.player.global_position + _last_controller_aim * 520.0
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()


func is_dash_just_pressed() -> bool:
	return Input.is_action_just_pressed("dash")


func is_pause_just_pressed() -> bool:
	return Input.is_action_just_pressed("pause_game")


func is_primary_attack_pressed() -> bool:
	return Input.is_action_pressed("primary_attack")


func is_cursor_move_pressed() -> bool:
	return Input.is_action_pressed("cursor_move")


func is_glide_pressed() -> bool:
	return Input.is_action_pressed("glide")


func is_interact_just_pressed() -> bool:
	return Input.is_action_just_pressed("interact")


func is_spell_cast_pressed() -> bool:
	return Input.is_action_pressed("cast_spell")


func get_requested_spell_slot() -> int:
	for index in range(6):
		if Input.is_action_just_pressed("spell_slot_%d" % (index + 1)):
			return index
	return -1


func get_spell_cycle_direction() -> int:
	if Input.is_action_just_pressed("spell_next"):
		return 1
	if Input.is_action_just_pressed("spell_previous"):
		return -1
	return 0


func is_using_controller() -> bool:
	return _using_controller


func _configure_controller_bindings() -> void:
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_RIGHT)
	_add_key("move_up", KEY_UP)
	_add_key("move_down", KEY_DOWN)
	_add_key("cast_spell", KEY_F)
	_add_key("glide", KEY_G)
	_add_key("interact", KEY_E)
	_remove_mouse_button("dash", MOUSE_BUTTON_RIGHT)
	_add_mouse_button("cursor_move", MOUSE_BUTTON_RIGHT)
	_add_axis("move_left", 0, -1.0)
	_add_axis("move_right", 0, 1.0)
	_add_axis("move_up", 1, -1.0)
	_add_axis("move_down", 1, 1.0)
	_add_axis("aim_left", 2, -1.0)
	_add_axis("aim_right", 2, 1.0)
	_add_axis("aim_up", 3, -1.0)
	_add_axis("aim_down", 3, 1.0)
	_add_button("dash", 0)
	_add_button("pause_game", 6)
	_add_button("primary_attack", 10)
	_add_button("primary_attack", 2)
	_add_button("cast_spell", 9)
	_add_button("cast_spell", 1)
	_add_button("spell_previous", 13)
	_add_button("spell_next", 14)
	_add_button("interact", 3)


func _add_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _add_mouse_button(action: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)


func _remove_mouse_button(action: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button_index:
			InputMap.action_erase_event(action, event)


func _add_axis(action: StringName, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.18)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)


func _add_button(action: StringName, button_index: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)
