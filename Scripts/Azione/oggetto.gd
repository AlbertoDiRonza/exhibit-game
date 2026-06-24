extends RigidBody3D

var mesh_instance: MeshInstance3D = null

@export var model: PackedScene
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
		#aggiungo scena come figlio del rigidbody così che si muovono assieme
		add_child(istanza)
		#Axis aligned bounding box trovo dinamicamente più piccola box che copre l'oggetto
		var aabb = AABB()
		var all_children = istanza.find_children("*", "MeshInstance3D", true, false)
		for child in all_children:
			if child is MeshInstance3D:
				mesh_instance = child
				aabb = mesh_instance.get_aabb()
				print(aabb.size)
		
		box.size = aabb.size * 0.8
		$CollisionShape3D.shape = box
		$CollisionShape3D.position = aabb.get_center()
		
		area_box.size = aabb.size * 1.5
		$"Area occupata/CollisionShape3D".shape = area_box
		$"Area occupata/CollisionShape3D".position = aabb.get_center()
		

	var shape = $CollisionShape3D.shape as BoxShape3D
	half_height = shape.size.y / 2.0
	
	GameManager.registra_oggetti(self)
	# se le  metto dall'editor non vengono ereditati da oggetti diversi
	area_occupata.area_entered.connect(_on_area_occupata_area_entered)
	area_occupata.area_exited.connect(_on_area_occupata_area_exited)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void: 
	if obj_state == State.HAND: 
		var target_position = player.camera_3d.global_position + (player.camera_3d.global_transform.basis * Vector3(0, -0.3, -1.5))
		global_position = global_position.lerp(target_position, delta*10) #delta valore piccolo il movimento risulterebbe lentissimo 
		
func pick_up(p) -> void: 
	if obj_state == State.PLACED:
		GameManager.fatica_tot += GameManager.quota_fatica_oggetto
		GameManager.fatica_changed.emit(GameManager.fatica_tot)
	obj_state = State.HAND
	player = p
	freeze = true
	#altrimenti collide con il player
	collision_layer = 0
	collision_mask = 0

func place(p: Vector3) -> void: 
	obj_state = State.PLACED
	player = null
	global_position = p
	GameManager.fatica_tot -= GameManager.quota_fatica_oggetto
	GameManager.fatica_changed.emit(GameManager.fatica_tot)
	freeze = false
	collision_layer = 1
	collision_mask = 1

func _on_area_occupata_area_entered(area: Area3D) -> void:
	var proximity_obj = area.get_parent()
	if self.obj_state == State.PLACED and proximity_obj.obj_state == State.PLACED:
		GameManager.registra_coppia(self, proximity_obj)
		
func _on_area_occupata_area_exited(area: Area3D) -> void:
	var proximity_obj = area.get_parent()
	GameManager.rimuovi_coppia(self, proximity_obj)
	
