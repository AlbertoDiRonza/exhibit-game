extends StaticBody3D

@export var model: PackedScene

# Taglia dello speaker: determina sia quanto è visivamente grande sia quanto
# tempo serve per ripararlo (uno grande è più complesso da sistemare).
enum Taglia { PICCOLO, MEDIO, GRANDE }
@export var taglia: Taglia = Taglia.PICCOLO

@onready var noise: AudioStreamPlayer3D = $AudioStreamPlayer3D

enum State {FUNCTIONING, BROKEN}
var spk_state : State = State.FUNCTIONING

# Chiamata da player.gd al posto del vecchio valore fisso "3.0": ogni speaker
# decide da solo quanto ci vuole a ripararlo, in base alla propria taglia.
func tempo_riparazione() -> float:
	match taglia:
		Taglia.PICCOLO:
			return 3.0
		Taglia.MEDIO:
			return 5.0
		Taglia.GRANDE:
			return 7.0
	return 3.0

func _fattore_scala() -> float:
	match taglia:
		Taglia.PICCOLO:
			return 0.75
		Taglia.MEDIO:
			return 1.0
		Taglia.GRANDE:
			return 1.35
	return 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# La taglia scala l'intero nodo (modello + CollisionShape3D, entrambi
	# figli di questo StaticBody3D): uno speaker "grande" è visivamente più
	# grande e ha anche un'area di collisione proporzionalmente più grande.
	scale = Vector3.ONE * _fattore_scala()

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
