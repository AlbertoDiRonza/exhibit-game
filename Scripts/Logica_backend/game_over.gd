extends Control

@onready var retry_button: Button = $RetryButton
@onready var quit_button: Button = $QuitButton

func _ready() -> void:
	# Schermata 2D pura: spegne l'AR sul viewport, altrimenti lo sfondo
	# camera coprirebbe questa UI.
	get_viewport().use_xr = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_retry_pressed() -> void:
	GameManager.reset_stato()
	SceneTransition.cambia_scena("res://Scene/main_scene.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
