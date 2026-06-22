extends Node3D

@onready var timer_lab: Label = $Player/CharacterBody3D/HUD/Timer
@onready var timer: Timer = $Timer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#questo è chiamato per ultimo dopo aver chiamato tutti i nodi figli
	GameManager.calcola_quote()
	timer.start()
	
	GameManager.game_over.connect(_on_game_over)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	timer_lab.text = "%02d:%02d" % time_left_museum()
	
func time_left_museum(): 
	var time_left = timer.time_left
	var minute = floor(time_left/60)
	var second = int(time_left) % 60
	return [minute, second]
	
func _on_timer_timeout() -> void:
	GameManager.game_over.emit()

func _on_game_over() -> void:
	get_tree().change_scene_to_file("res://Scene/game_over.tscn")
