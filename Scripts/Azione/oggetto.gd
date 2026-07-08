extends RigidBody3D

@export var is_artwork: bool = true
@export var model: PackedScene

# Fattore di scala di mesh, collisione e area di prossimità. 2.0 = doppio
# della taglia originale del modello.
@export var fattore_scala: float = 2.0

var mesh_instance: MeshInstance3D = null
var box : BoxShape3D = BoxShape3D.new()

@onready var area_occupata = $"Area occupata"
var area_box = BoxShape3D.new()

enum State {STORAGE, HAND, PLACED}
var obj_state: State = State.STORAGE
var player = null
var half_height: float = 0.0

# Vero se l'ultimo piazzamento era sotto un faretto acceso: serve a sapere
# se restituire la quota fatica quando l'oggetto viene ripreso in mano.
var luce_applicata: bool = false

func _ready() -> void:
	if model:
		var istanza = model.instantiate()
		add_child(istanza)

		# Scaliamo il modello importato (istanza), non il RigidBody3D radice.
		istanza.scale = Vector3.ONE * fattore_scala

		var aabb = AABB()
		var all_children = istanza.find_children("*", "MeshInstance3D", true, false)
		for child in all_children:
			if child is MeshInstance3D:
				mesh_instance = child
				aabb = mesh_instance.get_aabb()

		# Collisioni create da zero per ogni oggetto: scaliamo direttamente
		# per fattore_scala.
		box.size = aabb.size * 0.8 * fattore_scala
		$CollisionShape3D.shape = box
		$CollisionShape3D.position = aabb.get_center() * fattore_scala

		# Area di prossimità più larga della sagoma reale, per dare margine
		# prima che scatti il malus di vicinanza.
		area_box.size = aabb.size * 1.8 * fattore_scala
		$"Area occupata/CollisionShape3D".shape = area_box
		$"Area occupata/CollisionShape3D".position = aabb.get_center() * fattore_scala

	var shape = $CollisionShape3D.shape as BoxShape3D
	if shape:
		half_height = shape.size.y / 2.0
	
	GameManager.registra_oggetti(self)
	area_occupata.area_entered.connect(_on_area_occupata_area_entered)
	area_occupata.area_exited.connect(_on_area_occupata_area_exited)

func _physics_process(delta: float) -> void:
	if obj_state == State.HAND and player:
		# In AR la camera che si muove davvero è xr_camera_3d (camera_3d resta
		# ferma, disattivata in _ready()).
		var cam = player.xr_camera_3d if player.is_xr_active else player.camera_3d
		var target_position = cam.global_position + (cam.global_transform.basis * Vector3(0, -0.3, -1.5))
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

	# Il piazzamento è un teletrasporto, non un movimento fisico: aspettiamo
	# due frame prima di controllare prossimità e luce, per dare tempo al
	# motore fisico di aggiornare le collisioni.
	await get_tree().physics_frame
	await get_tree().physics_frame

	# La quota fatica si scala una volta sola, solo se l'opera è sotto un
	# faretto acceso.
	var sotto_luce = is_artwork and _sotto_faretto_acceso()
	if sotto_luce:
		luce_applicata = true
		GameManager.modifica_fatica(-GameManager.quota_fatica_oggetto)
	else:
		luce_applicata = false

	ricontrolla_prossimita()

# Chiede direttamente a ogni faretto in scena se mi sta illuminando ora.
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
	
	# Il faretto non ha obj_state: controlliamo prima di accedervi.
	if proximity_obj and "obj_state" in proximity_obj:
		if self.obj_state == State.PLACED and proximity_obj.obj_state == State.PLACED:
			GameManager.registra_coppia(self, proximity_obj)
		
func _on_area_occupata_area_exited(area: Area3D) -> void:
	var proximity_obj = area.get_parent()
	
	if proximity_obj and "obj_state" in proximity_obj:
		GameManager.rimuovi_coppia(self, proximity_obj)
