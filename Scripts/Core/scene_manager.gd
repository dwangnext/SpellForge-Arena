extends Node

var _is_transitioning := false
var _skip_main_menu_once := false


func change_scene(scene_path: String) -> void:
	if _is_transitioning or not ResourceLoader.exists(scene_path):
		return
	_is_transitioning = true
	GameManager.reset_session_state()
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s (error %d)." % [scene_path, error])
	call_deferred("_finish_transition")


func reload_current_scene() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	GameManager.reset_session_state()
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("Failed to reload the current scene (error %d)." % error)
	call_deferred("_finish_transition")


func restart_run() -> void:
	_skip_main_menu_once = true
	reload_current_scene()


func consume_skip_main_menu() -> bool:
	var should_skip := _skip_main_menu_once
	_skip_main_menu_once = false
	return should_skip


func quit_game() -> void:
	AudioManager.shutdown()
	await get_tree().create_timer(0.12, true).timeout
	get_tree().quit()


func _finish_transition() -> void:
	_is_transitioning = false
