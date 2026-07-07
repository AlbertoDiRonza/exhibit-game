extends StaticBody3D

@onready var cono_luce = $ConoLuce
@onready var spot_light: SpotLight3D = $SpotLight3D

# Il faretto deve restare spento mentre uno speaker fa rumore (vedi _process).
var is_on: bool = true

# Id degli oggetti attualmente dentro IL MIO cono di luce, a prescindere dal
# fatto che il faretto sia acceso o spento in questo momento. Serve per sapere
# chi far ricomparire/sparire da GameManager.oggetti_illuminati quando il
# faretto si riaccende o si spegne.
var oggetti_nel_cono: Array = []

func _ready() -> void:
	add_to_group("faretti")
	cono_luce.body_entered.connect(_on_cono_luce_body_entered)
	cono_luce.body_exited.connect(_on_cono_luce_body_exited)

# Controllo diretto (non basato su segnali/array che potrebbero non essere
# ancora aggiornati): l'oggetto passato è ORA, in questo istante, dentro il
# mio cono di luce E il faretto è acceso?
func illumina_adesso(body: Node3D) -> bool:
	return is_on and cono_luce.get_overlapping_bodies().has(body)

func _process(_delta: float) -> void:
	var deve_essere_acceso = GameManager.brkn_speaker == null
	if deve_essere_acceso != is_on:
		is_on = deve_essere_acceso
		if spot_light:
			spot_light.visible = is_on
		if is_on:
			# Il faretto si riaccende: chi è rimasto dentro il cono torna a
			# contare come illuminato.
			for id in oggetti_nel_cono:
				GameManager.aggiungi_luce_oggetto(id)
		else:
			# Il faretto si spegne: nessuno conta più come illuminato da qui.
			for id in oggetti_nel_cono:
				GameManager.rimuovi_luce_oggetto(id)

func _on_cono_luce_body_entered(body: Node3D) -> void:
	# 1. LETTURA SICURA: Chiediamo le variabili senza far arrabbiare Godot
	var stato = body.get("obj_state")
	var opera = body.get("is_artwork")

	# 2. FILTRO DI SICUREZZA: Se è il pavimento o il faretto stesso, ignoralo.
	if stato == null:
		return

	# 3. FILTRO LOGICA: A questo punto sappiamo che è un Oggetto (Statua o Tavolino).
	# Se è il tavolino, 'opera' sarà false. L'if qui sotto fallisce e non ricevi il bonus luce!
	# Solo la Scultura supererà questo controllo.
	if opera == true:
		if stato == body.State.PLACED:
			var id = body.get_instance_id()
			if not oggetti_nel_cono.has(id):
				oggetti_nel_cono.append(id)
			if is_on:
				GameManager.aggiungi_luce_oggetto(id)

func _on_cono_luce_body_exited(body: Node3D) -> void:
	var stato = body.get("obj_state")
	var opera = body.get("is_artwork")

	if stato == null:
		return

	if opera == true:
		var id = body.get_instance_id()
		oggetti_nel_cono.erase(id)
		GameManager.rimuovi_luce_oggetto(id)
