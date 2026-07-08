extends StaticBody3D

@onready var cono_luce = $ConoLuce
@onready var spot_light: SpotLight3D = $SpotLight3D

# Resta spento mentre uno speaker fa rumore (vedi _process).
var is_on: bool = true

# Oggetti dentro il mio cono in questo momento, acceso o spento che sia.
# Serve per aggiornare GameManager.oggetti_illuminati quando mi accendo o spengo.
var oggetti_nel_cono: Array = []

# Quando uno speaker si rompe la luce non sparisce di scatto: lampeggia un
# attimo come avviso e si spegne solo alla fine. Se lo speaker viene riparato
# durante il lampeggio, annulliamo e restiamo accesi.
const DURATA_LAMPEGGIO: float = 0.8
const INTERVALLO_LAMPEGGIO: float = 0.08
var sta_lampeggiando: bool = false
var timer_lampeggio: float = 0.0

func _ready() -> void:
	add_to_group("faretti")
	cono_luce.body_entered.connect(_on_cono_luce_body_entered)
	cono_luce.body_exited.connect(_on_cono_luce_body_exited)

# Controllo diretto invece che affidarsi a segnali/array (potrebbero non
# essere ancora aggiornati): l'oggetto è ora dentro il cono ed è acceso?
# Durante il lampeggio conta ancora come acceso, è solo un avviso.
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
			# Ora è spento per davvero: nessuno qui conta più come illuminato.
			for id in oggetti_nel_cono:
				GameManager.rimuovi_luce_oggetto(id)
		return

	if not deve_essere_acceso and is_on:
		# Lo speaker si è appena rotto: avvisiamo lampeggiando invece di
		# spegnere di scatto.
		sta_lampeggiando = true
		timer_lampeggio = 0.0
		return

	if deve_essere_acceso != is_on:
		is_on = deve_essere_acceso
		if spot_light:
			spot_light.visible = is_on
		if is_on:
			# Si riaccende: chi è rimasto nel cono torna a contare come illuminato.
			for id in oggetti_nel_cono:
				GameManager.aggiungi_luce_oggetto(id)

func _on_cono_luce_body_entered(body: Node3D) -> void:
	# get() invece di accesso diretto, per non crashare se il body non ha
	# queste proprietà (es. pavimento o il faretto stesso).
	var stato = body.get("obj_state")
	var opera = body.get("is_artwork")

	if stato == null:
		return

	# Solo le opere d'arte danno il bonus luce (es. il tavolino no).
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
