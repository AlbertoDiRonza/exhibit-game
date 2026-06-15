extends Node3D

@export var mouse_sensitivity: float = 0.002
@export var move_speed: float = 4.0

var is_xr_active: bool = false

@onready var camera_3d: Camera3D = $Camera3D
@onready var body: CharacterBody3D = $"."
@onready var crosshair: Control = $HUD/mirino

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

	body.velocity.x = direction.x * move_speed
	body.velocity.z = direction.z * move_speed
	body.move_and_slide()

	# Sincronizza posizione del Node3D con il body dopo le collisioni
	global_position = body.global_position
