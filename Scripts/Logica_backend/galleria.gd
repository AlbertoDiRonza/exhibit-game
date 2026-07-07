extends Node3D

# Il timer non è più mostrato nell'HUD 2D: è un pannello 3D montato a muro
# (vedi Scene/timer_muro.tscn), il giocatore deve girarsi verso il muro per
# controllarlo, esattamente come un vero orologio da museo.
@onready var timer_muro = $TimerMuro
@onready var timer: Timer = $Timer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("GALLERIA READY")
	#questo è chiamato per ultimo dopo aver chiamato tutti i nodi figli
	GameManager.calcola_quote()
	timer.start()

	GameManager.game_over.connect(_on_game_over)
	GameManager.vittoria_raggiunta.connect(_on_vittoria_raggiunta)

# Called every frame. 'delta' is the elapsed time since the previous frame.
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
	# Se un altoparlante era rimasto rotto proprio alla fine, azzeriamo il
	# riferimento: altrimenti MusicManager continuerebbe a vedere uno speaker
	# rotto e lascerebbe la musica in pausa anche nella schermata di game over,
	# dove non c'è più nulla da riparare.
	GameManager.brkn_speaker = null
	SceneTransition.cambia_scena("res://Scene/game_over.tscn")

func _on_vittoria_raggiunta() -> void:
	GameManager.brkn_speaker = null
	SceneTransition.cambia_scena("res://Scene/vittoria.tscn")
