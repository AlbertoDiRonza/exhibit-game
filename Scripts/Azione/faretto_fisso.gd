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

# --- LAMPEGGIO DI AVVISO PRIMA DELLO SPEGNIMENTO ---
# Quando uno speaker si rompe non vogliamo che la luce sparisca di scatto:
# lampeggia per un breve periodo (avviso per il giocatore) e solo alla fine
# del lampeggio si spegne davvero (is_on = false, con tutte le conseguenze
# per illumina_adesso() e GameManager.oggetti_illuminati). Se lo speaker
# viene riparato mentre si sta ancora lampeggiando, annulliamo e restiamo
# accesi senza mai essere arrivati a spegnerci per davvero.
const DURATA_LAMPEGGIO: float = 0.8
const INTERVALLO_LAMPEGGIO: float = 0.08
var sta_lampeggiando: bool = false
var timer_lampeggio: float = 0.0

func _ready() -> void:
	add_to_group("faretti")
	cono_luce.body_entered.connect(_on_cono_luce_body_entered)
	cono_luce.body_exited.connect(_on_cono_luce_body_exited)

# Controllo diretto (non basato su segnali/array che potrebbero non essere
# ancora aggiornati): l'oggetto passato è ORA, in questo istante, dentro il
# mio cono di luce E il faretto è acceso? Durante il lampeggio di avviso la
# luce conta ancora come accesa (is_on resta true finché il lampeggio non
# finisce): è solo un avviso, non ha ancora smesso di illuminare davvero.
func illumina_adesso(body: Node3D) -> bool:
	return is_on and cono_luce.get_overlapping_bodies().has(body)

func _process(delta: float) -> void:
	var deve_essere_acceso = GameManager.brkn_speaker == null

	if sta_lampeggiando:
		if deve_essere_acceso:
			# Riparato mentre lampeggiava: annulliamo l'avviso, resta accesa.
			sta_lampeggiando = false
			if spot_light:
				spot_light.visible = true
			return

		timer_lampeggio += delta
		if spot_light:
			var fase = int(timer_lampeggio / INTERVALLO_LAMPEGGIO)
			spot_light.visible = (fase % 2 == 0)

		if timer_lampeggio >= DURATA_LAMPEGGIO:
			sta_lampeggiando = false
			is_on = false
			if spot_light:
				spot_light.visible = false
			# Il faretto si spegne per davvero: nessuno conta più come
			# illuminato da qui.
			for id in oggetti_nel_cono:
				GameManager.rimuovi_luce_oggetto(id)
		return

	if not deve_essere_acceso and is_on:
		# Lo speaker si è appena rotto: invece di spegnere di scatto, avvisiamo
		# lampeggiando. La luce resta funzionalmente accesa (is_on = true)
		# finché il lampeggio non è concluso.
		sta_lampeggiando = true
		timer_lampeggio = 0.0
		return

	if deve_essere_acceso != is_on:
		is_on = deve_essere_acceso
		if spot_light:
			spot_light.visible = is_on
		if is_on:
			# Il faretto si riaccende: chi è rimasto dentro il cono torna a
			# contare come illuminato.
			for id in oggetti_nel_cono:
				GameManager.aggiungi_luce_oggetto(id)

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
