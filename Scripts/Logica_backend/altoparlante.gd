extends StaticBody3D

@export var model: PackedScene

# La taglia determina sia quanto è grande sia quanto ci vuole a ripararlo.
enum Taglia { PICCOLO, MEDIO, GRANDE }
@export var taglia: Taglia = Taglia.PICCOLO

@onready var noise: AudioStreamPlayer3D = $AudioStreamPlayer3D

enum State {FUNCTIONING, BROKEN}
var spk_state : State = State.FUNCTIONING

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
	# Scale ben distanziate così la differenza si nota a colpo d'occhio.
	match taglia:
		Taglia.PICCOLO:
			return 1.0
		Taglia.MEDIO:
			return 2.0
		Taglia.GRANDE:
			return 4.0
	return 1.0

func _ready() -> void:
	var fattore = _fattore_scala()

	if model:
		var istanza = model.instantiate()
		add_child(istanza)

		# Scaliamo il modello importato, non lo StaticBody3D radice.
		istanza.scale = Vector3.ONE * fattore

		GameManager.registra_speakers(self)

	# La BoxShape3D è condivisa da tutte le istanze: la duplichiamo prima di
	# scalarla, altrimenti cambieremmo la taglia di ogni speaker insieme.
	var collision_shape := $CollisionShape3D as CollisionShape3D
	if collision_shape and collision_shape.shape is BoxShape3D:
		var base_shape := collision_shape.shape as BoxShape3D
		var shape_scalata := base_shape.duplicate() as BoxShape3D
		shape_scalata.size = base_shape.size * fattore
		collision_shape.shape = shape_scalata

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
