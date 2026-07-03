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
		# Restituisce la fatica solo se è un'opera d'arte
		if is_artwork:
			GameManager.fatica_tot += GameManager.quota_fatica_oggetto
			GameManager.fatica_changed.emit(GameManager.fatica_tot)
			
	obj_state = State.HAND
	player = p
	freeze = true
	collision_layer = 0
	collision_mask = 0

func place(p: Vector3) -> void: 
	obj_state = State.PLACED
	player = null
	global_position = p
	
	# Sottrae la fatica solo se è un'opera d'arte
	if is_artwork:
		GameManager.fatica_tot -= GameManager.quota_fatica_oggetto
		GameManager.fatica_changed.emit(GameManager.fatica_tot)
		
	freeze = false
	collision_layer = 1
	collision_mask = 1
	
	# Assicura la sincronizzazione del motore fisico prima di controllare chi ha intorno
	await get_tree().physics_frame
	ricontrolla_prossimita()

func ricontrolla_prossimita() -> void:
	var aree_sovrapposte = area_occupata.get_overlapping_areas()
	for area in aree_sovrapposte:
		_on_area_occupata_area_entered(area)

func _on_area_occupata_area_entered(area: Area3D) -> void:
	var proximity_obj = area.get_parent()
	
	# Il filtro di sicurezza per evitare che Godot crashi leggendo il faretto!
	if proximity_obj and "obj_state" in proximity_obj:
		if self.obj_state == State.PLACED and proximity_obj.obj_state == State.PLACED:
			GameManager.registra_coppia(self, proximity_obj)
		
func _on_area_occupata_area_exited(area: Area3D) -> void:
	var proximity_obj = area.get_parent()
	
	if proximity_obj and "obj_state" in proximity_obj:
		GameManager.rimuovi_coppia(self, proximity_obj)
