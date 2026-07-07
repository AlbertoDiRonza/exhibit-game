extends Control

@onready var play_button: Button = $PlayButton
@onready var quit_button: Button = $QuitButton

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	GameManager.reset_stato()
	SceneTransition.cambia_scena("res://Scene/tutorial.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
