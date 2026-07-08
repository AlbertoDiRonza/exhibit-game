extends Control

@onready var play_button: Button = $PlayButton
@onready var quit_button: Button = $QuitButton

func _ready() -> void:
	# Questa schermata è 2D pura (nessun Player/camera). Se si arriva qui
	# DOPO essere già stati in Tutorial o Livello 1 (dove player.gd ha
	# acceso get_viewport().use_xr = true per l'AR), il viewport resta
	# marcato come XR anche qui: Godot continua a richiamare l'hook nativo
	# che disegna lo sfondo della fotocamera, che finisce sopra a questa UI
	# 2D nascondendola. Disattivandolo esplicitamente si torna a un
	# viewport normale non-XR, senza sfondo camera.
	get_viewport().use_xr = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	GameManager.reset_stato()
	SceneTransition.cambia_scena("res://Scene/tutorial.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
