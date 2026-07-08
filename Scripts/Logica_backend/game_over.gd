extends Control

@onready var retry_button: Button = $RetryButton
@onready var quit_button: Button = $QuitButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Vedi lo stesso commento in menu_principale.gd: schermata 2D pura, va
	# spenta esplicitamente l'AR sul viewport altrimenti lo sfondo camera
	# (rimasto acceso da Tutorial/Livello 1) copre l'interfaccia.
	get_viewport().use_xr = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_retry_pressed() -> void:
	GameManager.reset_stato()
	SceneTransition.cambia_scena("res://Scene/main_scene.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
