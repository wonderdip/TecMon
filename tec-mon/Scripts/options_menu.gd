extends CanvasLayer

var parent_scene : int

func _ready() -> void:
	hide()

func _on_back_button_pressed() -> void:
	hide()
	if parent_scene == 1:
		SceneManager.game_manager.get_child(4).show()
	else:
		get_tree().paused = false

func _on_visibility_changed() -> void:
	if visible and get_tree().paused:
		parent_scene = 1
	elif visible:
		get_tree().paused = true
		parent_scene = 2
