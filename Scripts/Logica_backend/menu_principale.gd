extends Control

@onready var play_button: Button = $PlayButton
@onready var quit_button: Button = $QuitButton

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	GameManager.reset_stato()
	get_tree().change_scene_to_file("res://Scene/main_scene.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
