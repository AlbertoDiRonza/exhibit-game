extends StaticBody3D

@export var model: PackedScene
@onready var noise: AudioStreamPlayer3D = $AudioStreamPlayer3D

enum State {FUNCTIONING, BROKEN}
var spk_state : State = State.FUNCTIONING
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if model: 
		var istanza = model.instantiate()
		add_child(istanza)
		
		GameManager.registra_speakers(self)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if self == GameManager.brkn_speaker:
		var stato_corrente = self.spk_state
		self.spk_state = State.BROKEN
		if self.spk_state != stato_corrente:
			noise.play()
			stato_corrente = self.spk_state

func repair() -> void: 
	self.spk_state = State.FUNCTIONING
	GameManager.brkn_speaker = null
	noise.stop()
	GameManager.timer_rottura_spk = 0.0
	GameManager.fatica_tot -= GameManager.fatica_tot_rimossa_spk
	GameManager.fatica_changed.emit(GameManager.fatica_tot)
	GameManager.fatica_tot_rimossa_spk = 0.0
