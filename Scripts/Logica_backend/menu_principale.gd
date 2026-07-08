extends Control

@onready var play_button: Button = $PlayButton
@onready var quit_button: Button = $QuitButton

func _ready() -> void:
	# Schermata 2D pura: se si arriva da Tutorial/Livello 1 (dove l'AR è
	# attivo), lo sfondo camera resterebbe acceso e coprirebbe questa UI.
	get_viewport().use_xr = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	GameManager.reset_stato()
	SceneTransition.cambia_scena("res://Scene/tutorial.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
