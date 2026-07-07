extends RigidBody3D

@export var is_artwork: bool = true
@export var model: PackedScene

var mesh_instance: MeshInstance3D = null
var box : BoxShape3D = BoxShape3D.new()

@onready var area_occupata = $"Area occupata"
var area_box = BoxShape3D.new()

enum State {STORAGE, HAND, PLACED}
var obj_state: State = State.STORAGE
var player = null
var half_height: float = 0.0

# Vero se l'ULTIMO posizionamento di quest'oggetto era sotto un faretto
# acceso e ha quindi scalato la quota fatica. Serve per sapere, quando lo
# si riprende in mano, se restituire la quota oppure no (altrimenti si
# potrebbe raccogliere fatica gratis piazzando fuori dalla luce).
var luce_applicata: bool = false

func _ready() -> void:
	if model: 
		var istanza = model.instantiate()
		add_child(istanza)
		
		var aabb = AABB()
		var all_children = istanza.find_children("*", "MeshInstance3D", true, false)
		for child in all_children:
			if child is MeshInstance3D:
				mesh_instance = child
				aabb = mesh_instance.get_aabb()
		
		box.size = aabb.size * 0.8
		$CollisionShape3D.shape = box
		$CollisionShape3D.position = aabb.get_center()
		
		# Trova questa riga dentro la funzione _ready() di oggetto.gd:
		area_box.size = aabb.size * 2.5 
		$"Area occupata/CollisionShape3D".shape = area_box
		$"Area occupata/CollisionShape3D".position = aabb.get_center()

	var shape = $CollisionShape3D.shape as BoxShape3D
	if shape:
		half_height = shape.size.y / 2.0
	
	GameManager.registra_oggetti(self)
	area_occupata.area_entered.connect(_on_area_occupata_area_entered)
	area_occupata.area_exited.connect(_on_area_occupata_area_exited)

func _physics_process(delta: float) -> void: 
	if obj_state == State.HAND and player: 
		var target_position = player.camera_3d.global_position + (player.camera_3d.global_transform.basis * Vector3(0, -0.3, -1.5))
		global_position = global_position.lerp(target_position, delta * 10) 

func pick_up(p) -> void:
	if obj_state == State.PLACED:
		# Restituisce la fatica solo se era stata effettivamente scalata
		# (cioè solo se questo posizionamento era sotto una luce accesa)
		if is_artwork and luce_applicata:
			GameManager.modifica_fatica(GameManager.quota_fatica_oggetto)
		luce_applicata = false

	obj_state = State.HAND
	player = p
	freeze = true
	collision_layer = 0
	collision_mask = 0

func place(p: Vector3) -> void:
	obj_state = State.PLACED
	player = null
	global_position = p
	freeze = false
	collision_layer = 1
	collision_mask = 1

	# Assicura la sincronizzazione del motore fisico prima di controllare chi ha
	# intorno E prima di controllare se siamo dentro il cono di un faretto
	# acceso. Aspettiamo un paio di frame fisici invece di uno solo: essendo
	# un teletrasporto (global_position diretto, non un movimento fisico), il
	# motore potrebbe impiegare un frame in più ad aggiornare le collisioni.
	await get_tree().physics_frame
	await get_tree().physics_frame

	# La quota fatica si scala una volta sola, e SOLO se l'opera è finita
	# sotto un faretto acceso: questa è la meccanica corretta (in precedenza
	# scattava sempre, a prescindere dalla luce, ed era per questo che
	# muovere gli oggetti causava riduzioni non volute).
	var sotto_luce = is_artwork and _sotto_faretto_acceso()
	if sotto_luce:
		luce_applicata = true
		GameManager.modifica_fatica(-GameManager.quota_fatica_oggetto)
	else:
		luce_applicata = false

	ricontrolla_prossimita()

# Chiede direttamente a ogni faretto in scena se in questo momento mi sta
# illuminando (invece di fidarsi di un array aggiornato da un segnale che, a
# volte, non aveva ancora fatto in tempo a scattare subito dopo place()).
func _sotto_faretto_acceso() -> bool:
	for faretto in get_tree().get_nodes_in_group("faretti"):
		if faretto.illumina_adesso(self):
			return true
	return false

func ricontrolla_prossimita() -> void:
	var aree_sovrapposte = area_occupata.get_overlapping_areas()
	for area in aree_sovrapposte:
		_on_area_occupata_area_entered(area)

func _on_area_occupata_area_entered(area: Area3D) -> void:
	var proximity_obj = area.get_parent()
	
	# L'area del faretto può interagire con l'oggetto, ma non avendo obj_state fa crashare godot
	if proximity_obj and "obj_state" in proximity_obj:
		if self.obj_state == State.PLACED and proximity_obj.obj_state == State.PLACED:
			GameManager.registra_coppia(self, proximity_obj)
		
func _on_area_occupata_area_exited(area: Area3D) -> void:
	var proximity_obj = area.get_parent()
	
	if proximity_obj and "obj_state" in proximity_obj:
		GameManager.rimuovi_coppia(self, proximity_obj)
