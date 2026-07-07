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
	# Differenza resa più marcata (era 0.75/1.0/1.35, troppo simile per essere
	# notata a colpo d'occhio in gioco): ora il piccolo è quasi la metà del
	# medio, il grande quasi il doppio.
	match taglia:
		Taglia.PICCOLO:
			return 0.55
		Taglia.MEDIO:
			return 1.0
		Taglia.GRANDE:
			return 1.75
	return 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var fattore = _fattore_scala()

	if model:
		var istanza = model.instantiate()
		add_child(istanza)

		# Scaliamo il modello importato direttamente (non il StaticBody3D
		# radice): scalare il nodo radice non dava risultati affidabili in
		# pratica, probabilmente perché il modello importato dal .glb non
		# eredita in modo prevedibile la scala del genitore.
		istanza.scale = Vector3.ONE * fattore

		GameManager.registra_speakers(self)

	# La CollisionShape3D usa una BoxShape3D condivisa da TUTTE le istanze di
	# questa scena (definita una sola volta nel file .tscn): ridimensionarla
	# "sul posto" cambierebbe la taglia di ogni speaker della galleria insieme.
	# La duplichiamo per-istanza prima di scalarla.
	var collision_shape := $CollisionShape3D as CollisionShape3D
	if collision_shape and collision_shape.shape is BoxShape3D:
		var base_shape := collision_shape.shape as BoxShape3D
		var shape_scalata := base_shape.duplicate() as BoxShape3D
		shape_scalata.size = base_shape.size * fattore
		collision_shape.shape = shape_scalata

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
