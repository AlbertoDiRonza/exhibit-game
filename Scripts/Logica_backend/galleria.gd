extends Node3D

# Il timer è un pannello 3D a muro (Scene/timer_muro.tscn): bisogna girarsi
# per controllarlo, come un vero orologio da museo.
@onready var timer_muro = $TimerMuro
@onready var timer: Timer = $Timer


func _ready() -> void:
	print("GALLERIA READY")
	# Chiamato per ultimo, dopo tutti i nodi figli.
	GameManager.calcola_quote()
	timer.start()

	GameManager.game_over.connect(_on_game_over)
	GameManager.vittoria_raggiunta.connect(_on_vittoria_raggiunta)

func _process(delta: float) -> void:
	var tempo = time_left_museum()
	if timer_muro:
		timer_muro.set_tempo(tempo[0], tempo[1])

func time_left_museum(): 
	var time_left = timer.time_left
	var minute = floor(time_left/60)
	var second = int(time_left) % 60
	return [minute, second]
	
func _on_timer_timeout() -> void:
	GameManager.game_over.emit()

func _on_game_over() -> void:
	# Azzeriamo lo speaker rotto: altrimenti la musica resterebbe in pausa
	# anche nella schermata di game over.
	GameManager.brkn_speaker = null
	SceneTransition.cambia_scena("res://Scene/game_over.tscn")

func _on_vittoria_raggiunta() -> void:
	GameManager.brkn_speaker = null
	SceneTransition.cambia_scena("res://Scene/vittoria.tscn")
