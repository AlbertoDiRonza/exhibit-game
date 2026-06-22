extends CharacterBody3D

@export var mouse_sensitivity: float = 0.002
@export var move_speed: float = 4.0

var is_xr_active: bool = false

@onready var camera_3d: Camera3D = $Camera3D
@onready var crosshair: Control = $HUD/mirino
@onready var label_interazione: Label = $HUD/interact
@onready var fatigue_bar: ProgressBar = $"HUD/barra fatica"

var held_objct: RigidBody3D = null
var focused_objct: RigidBody3D = null

var place_position: Vector3
var is_floor: bool 

func _ready():
	var interface = XRServer.find_interface("OpenXR")
	if interface and interface.initialize():
		get_viewport().use_xr = true
		is_xr_active = true
		camera_3d.current = false
		if crosshair:
			crosshair.visible = false
	else:
		is_xr_active = false
		camera_3d.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	GameManager.fatica_changed.connect(_on_fatica_changed)
	_on_fatica_changed(GameManager.fatica_tot)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event):
	if not is_xr_active:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)
			camera_3d.rotate_x(-event.relative.y * mouse_sensitivity)
			camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80), deg_to_rad(80))

		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			elif event.keycode == KEY_F:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				
		if event is InputEventKey and event.pressed:
			if focused_objct: 
				if event.keycode == KEY_E:
					focused_objct.pick_up(self)
					held_objct = focused_objct
					focused_objct = null
			elif held_objct:
				if event.keycode == KEY_E:
					# result_place.position è la posione della collisione del ray cast con il pavimento
					# il centro dell'oggetto (da cui determino la posizione relativa) è più in alto 
					# se sottraessi metterei il metà oggetto sotto il pavimento
					if is_floor:
						held_objct.place(Vector3(place_position.x, place_position.y + held_objct.half_height, place_position.z))
						place_position = Vector3.ZERO
						held_objct = null
		

func _physics_process(delta):
	if is_xr_active:
		return

	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_forward"): input_dir.y -= 1
	if Input.is_action_pressed("move_back"):    input_dir.y += 1
	if Input.is_action_pressed("move_left"):    input_dir.x -= 1
	if Input.is_action_pressed("move_right"):   input_dir.x += 1

	input_dir = input_dir.normalized()
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y))

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	move_and_slide()
	
	var space_state = get_world_3d().direct_space_state
	
	if not held_objct:
		var ray_pick_origin = camera_3d.global_position 
		var ray_pick_end =  ray_pick_origin + (-camera_3d.global_transform.basis.z * 4.0)
		var query_pick = PhysicsRayQueryParameters3D.create(ray_pick_origin, ray_pick_end)
		var result_pick = space_state.intersect_ray(query_pick)
		
		if result_pick and result_pick.collider.has_method("pick_up"):
			# ha colpito qualcosa, se ha questo metodo è interagibile
			focused_objct = result_pick.collider
		else:
			#oggetto colpito non ha il metodo
			focused_objct = null
	else:
		focused_objct = null
	label_interazione.visible = (focused_objct != null)

			
	if held_objct:
		var ray_place_origin = camera_3d.global_position
		var ray_place_end = ray_place_origin + (-camera_3d.global_transform.basis.z * 5.0)
		var query_place = PhysicsRayQueryParameters3D.create(ray_place_origin, ray_place_end)
		query_place.exclude = [held_objct.get_rid()]
		var result_place = space_state.intersect_ray(query_place)
		
		if result_place:
			# controllo su prodotto scalare per vedere se la normale del piano di incidenza sulla direzione y
			if result_place.normal.y >= 0.99:
				is_floor = true
				place_position = result_place.position
			else: 
				is_floor = false
		else: 
				is_floor = false
				
func _on_fatica_changed(f) -> void:
		fatigue_bar.value = f

		
