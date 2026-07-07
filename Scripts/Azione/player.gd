extends CharacterBody3D

@export var mouse_sensitivity: float = 0.004
@export var move_speed: float = 5.0

var is_xr_active: bool = false

@onready var camera_3d: Camera3D = $Camera3D
@onready var xr_camera_3d: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var crosshair: Control = $HUD/mirino
@onready var label_interazione: Label = $HUD/interact
@onready var fatigue_bar: ProgressBar = $"HUD/barra fatica"
@onready var label_interazione_spk: Label = $HUD/interact_spk
@onready var barra_riparazione: ProgressBar = $HUD/barra_riparazione
@onready var virtual_joystick: ArTouchJoystick = $HUD/VirtualJoystick
@onready var pickup_button: Button = $HUD/PickupButton

var held_objct: RigidBody3D = null
var focused_objct: RigidBody3D = null
var focused_speaker : StaticBody3D = null

var place_position: Vector3
var is_floor: bool 

var repair_timer: float = 0.0

func _ready():
	# Su Android proviamo prima ARCore (AR passthrough su telefono),
	# poi OpenXR (visori/headset), poi il fallback desktop.
	var interface = null
	var interface_name = ""

	# CAUSA REALE DEL NERO (confermata dal log nativo, tag ARCoreExtension):
	# il plugin ARCore crea correttamente un CameraFeed chiamato "ARCore" con
	# id 1 DENTRO interface.initialize() ("Godot ARCore: Feed 1 added").
	# Ma subito dopo, la nostra CameraServer.set_monitoring_feeds(true)
	# (chiamata DOPO initialize) fa scattare la scansione delle fotocamere
	# generiche di Android, che ripulisce/sostituisce l'elenco feed e
	# CANCELLA quello di ARCore — infatti un secondo più tardi
	# CameraServer.feeds() mostrava solo feed generici "0 | BACK" ecc. che
	# riusano lo stesso id 1, mai più "ARCore". Risultato: l'Environment
	# punta a un feed generico inattivo invece che a quello reale di ARCore
	# → schermo nero. Fix: attivare il monitoraggio PRIMA di initialize(),
	# così la scansione generica avviene per prima e il feed di ARCore,
	# creato dopo, ottiene un id libero senza essere cancellato.
	CameraServer.set_monitoring_feeds(true)

	# IMPORTANTE: il plugin ARCore richiede di inizializzare esplicitamente
	# l'ambiente nativo (JNIEnv/JavaVM/Activity) tramite il singleton Android
	# PRIMA di poter usare l'interfaccia XR "ARCore" — altrimenti va in crash
	# (il puntatore JNIEnv resta nullo). Vedi plugin/demo/main3D.gd nel repo
	# del plugin per il pattern d'uso ufficiale.
	if Engine.has_singleton("ARCorePlugin"):
		var arcore_plugin = Engine.get_singleton("ARCorePlugin")
		arcore_plugin.initializeEnvironment()
		interface = XRServer.find_interface("ARCore")
		interface_name = "ARCore"

	if interface == null:
		interface = XRServer.find_interface("OpenXR")
		interface_name = "OpenXR"
	print("Interface found (", interface_name, "): ", interface)
	if interface != null:
		var result = interface.initialize()
		print("Initialize result: ", result)
		if result:
			get_viewport().use_xr = true
			is_xr_active = true
			camera_3d.current = false
			if crosshair:
				crosshair.visible = false
			# _physics_process_ar() non aggiorna questi elementi (pensati per
			# l'interazione da PC, con label/barra a testo fisso); li
			# nascondiamo qui una volta per tutte, altrimenti restavano
			# sempre visibili nella loro posizione di default a schermo.
			if label_interazione:
				label_interazione.visible = false
			if label_interazione_spk:
				label_interazione_spk.visible = false
			if barra_riparazione:
				barra_riparazione.visible = false
			# HUD touch dedicato all'AR: joystick virtuale per lo spostamento
			# (in AR "transform.basis" del CharacterBody3D non ruota da solo
			# camminando fisicamente, serve un input esplicito) e pulsante
			# per raccogliere/posizionare gli oggetti al posto del tasto E,
			# che su schermo touch non esiste.
			if virtual_joystick:
				virtual_joystick.visible = true
			if pickup_button:
				pickup_button.visible = true
				pickup_button.pressed.connect(_on_pickup_button_pressed)
			if interface_name == "ARCore":
				# Abilita il rilevamento dei piani orizzontali/verticali e
				# il posizionamento istantaneo, utili per l'interazione AR reale.
				if interface.has_method("enable_horizontal_plane_detection"):
					interface.enable_horizontal_plane_detection(true)
				if interface.has_method("enable_vertical_plane_detection"):
					interface.enable_vertical_plane_detection(true)
				if interface.has_method("enable_instant_placement"):
					interface.enable_instant_placement(true)
				# Il feed "ARCore" esiste ed è attivo (verificato nei log). La
				# causa reale del nero era un limite del renderer GLES3/
				# Compatibility di Godot 4.7 stable: il codice che disegna le
				# CameraFeed esterne (FeedEffects) esiste nel motore ma non
				# viene mai chiamato in questa versione (verificato sui
				# sorgenti del tag 4.7-stable). Anche il quad 3D con
				# CameraTexture+StandardMaterial3D non può funzionare, perché
				# la texture della camera è di tipo GL_TEXTURE_EXTERNAL_OES e
				# richiede uno shader con samplerExternalOES, non ottenibile
				# da un materiale standard. Soluzione adottata: patch nativa
				# nel plugin C++ (ARCoreInterface::_pre_draw_viewport) che
				# disegna lo sfondo camera direttamente in OpenGL ES prima del
				# render della scena 3D. Qui in GDScript non serve più fare
				# nulla per lo sfondo: Environment.background_mode è impostato
				# su BG_KEEP (4) per non farlo cancellare dal motore.
				if interface.has_method("get_camera_feed_id"):
					var feed_id = interface.get_camera_feed_id()
					print("ARCore feed id: ", feed_id)
		else:
			print(interface_name, " init FAILED, modalità PC")
			is_xr_active = false
			camera_3d.current = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		print("Nessuna interfaccia XR trovata, modalità PC")
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
			# Con uno speaker che sta facendo rumore non si può RACCOGLIERE un
			# nuovo oggetto. Posizionare quello che hai già in mano resta
			# sempre permesso, altrimenti se il rumore parte mentre tieni
			# qualcosa in mano resti bloccato (non puoi nemmeno riparare lo
			# speaker, dato che serve avere le mani libere).
			if focused_objct:
				if event.keycode == KEY_E and GameManager.brkn_speaker == null:
					focused_objct.pick_up(self)
					held_objct = focused_objct
					focused_objct = null
			elif held_objct:
				if event.keycode == KEY_E:
					# result_place.position è la posione della collisione del ray cast con il pavimento
					# il centro dell'oggetto (da cui determino la posizione relativa) è più in alto
					# se sottraessi metterei il metà oggetto sotto il pavimento
					if is_floor:
						#held_objct.place(Vector3(place_position.x, place_position.y + held_objct.half_height, place_position.z))
						held_objct.place(Vector3(place_position.x, place_position.y, place_position.z))
						place_position = Vector3.ZERO
						held_objct = null
			
		

@warning_ignore("unused_parameter")
func _physics_process(delta):
	if is_xr_active:
		_physics_process_ar(delta)
	else:
		_physics_process_pc(delta)


func _physics_process_pc(delta):
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_forward"): input_dir.y -= 1
	if Input.is_action_pressed("move_back"):    input_dir.y += 1
	if Input.is_action_pressed("move_left"):    input_dir.x -= 1
	if Input.is_action_pressed("move_right"):   input_dir.x += 1
	if Input.is_key_pressed(KEY_E):
		if focused_speaker != null:
			repair_timer += delta
			barra_riparazione.value = repair_timer / 3.0
			if repair_timer >= 3.0:
				focused_speaker.repair()
				repair_timer = 0.0
				barra_riparazione.value = 0.0
	else:
			repair_timer = 0.0
			barra_riparazione.value = 0.0


	input_dir = input_dir.normalized()
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y))

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	move_and_slide()

	_update_interaction_raycast(camera_3d.global_position, camera_3d.global_transform.basis)

	label_interazione.visible = (focused_objct != null)
	label_interazione_spk.visible = (focused_speaker != null)
	barra_riparazione.visible = (focused_speaker != null)

	if held_objct:
		_update_place_raycast(camera_3d.global_position, camera_3d.global_transform.basis)


func _physics_process_ar(_delta):
	# Movimento da joystick virtuale: la direzione è relativa a dove sta
	# guardando la XRCamera3D (proiettata sul piano orizzontale), perché il
	# CharacterBody3D in AR non ruota mai da solo camminando fisicamente —
	# è la testa (la camera) a ruotare, tracciata da ARCore.
	var joy: Vector2 = virtual_joystick.output if virtual_joystick else Vector2.ZERO
	if joy.length() > 0.0:
		var cam_basis := xr_camera_3d.global_transform.basis
		var forward := -cam_basis.z
		forward.y = 0.0
		forward = forward.normalized() if forward.length() > 0.001 else Vector3.FORWARD
		var right := cam_basis.x
		right.y = 0.0
		right = right.normalized() if right.length() > 0.001 else Vector3.RIGHT

		var direction: Vector3 = (right * joy.x + forward * -joy.y)
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()

	_update_interaction_raycast(xr_camera_3d.global_position, xr_camera_3d.global_transform.basis)

	if held_objct:
		_update_place_raycast(xr_camera_3d.global_position, xr_camera_3d.global_transform.basis)

	_update_pickup_button()


func _update_interaction_raycast(origin: Vector3, basis: Basis) -> void:
	var space_state = get_world_3d().direct_space_state

	if not held_objct:
		var ray_pick_origin = origin
		var ray_pick_end = ray_pick_origin + (-basis.z * 4.0)
		var query_pick = PhysicsRayQueryParameters3D.create(ray_pick_origin, ray_pick_end)
		var result_pick = space_state.intersect_ray(query_pick)

		if result_pick and result_pick.collider.has_method("pick_up"):
			# ha colpito qualcosa, se ha questo metodo è interagibile
			focused_objct = result_pick.collider
		elif result_pick and result_pick.collider.has_method("repair"):
			if result_pick.collider.spk_state == result_pick.collider.State.BROKEN:
				focused_speaker = result_pick.collider
			else:
				focused_speaker = null
		else:
			#oggetto colpito non ha il metodo
			focused_objct = null
			focused_speaker = null
	else:
		focused_objct = null


func _update_place_raycast(origin: Vector3, basis: Basis) -> void:
	var space_state = get_world_3d().direct_space_state
	var ray_place_origin = origin
	var ray_place_end = ray_place_origin + (-basis.z * 5.0)
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


func _update_pickup_button() -> void:
	if not pickup_button:
		return
	if held_objct:
		# Posizionare quello che hai già in mano resta sempre permesso, anche
		# con uno speaker rumoroso: altrimenti resteresti bloccato con
		# l'oggetto in mano finché non lo ripari (e per riparare servono le
		# mani libere).
		pickup_button.text = "Posiziona"
		pickup_button.disabled = not is_floor
	elif focused_objct:
		pickup_button.text = "Raccogli"
		# Con uno speaker che sta facendo rumore non si può raccogliere un
		# nuovo oggetto.
		pickup_button.disabled = (GameManager.brkn_speaker != null)
	else:
		pickup_button.text = "Raccogli"
		pickup_button.disabled = true


func _on_pickup_button_pressed() -> void:
	if focused_objct:
		if GameManager.brkn_speaker != null:
			return
		focused_objct.pick_up(self)
		held_objct = focused_objct
		focused_objct = null
	elif held_objct:
		if is_floor:
			held_objct.place(Vector3(place_position.x, place_position.y, place_position.z))
			place_position = Vector3.ZERO
			held_objct = null


func _on_fatica_changed(f) -> void:
		fatigue_bar.value = f

		
