extends Node

var oggetti_illuminati: Array = []
var coppie_vicine = {}
var fatica_tot: float = 100.0
signal fatica_changed 
var oggetti = []
var quota_fatica_oggetto: float

var speakers = []
var brkn_speaker = null
var brk_time_min: float = 10.0
var brk_time_max: float = 30.0
var brk_timer: float = randf_range(brk_time_min, brk_time_max)

# Limite minimo "congelato" quando uno speaker si rompe: se la fatica è già
# sotto 15 la spinge a 15, altrimenti resta dov'è. Sparisce alla riparazione.
var cap_altoparlante_rotto: float = 0.0


@warning_ignore("unused_signal")
signal game_over
signal vittoria_raggiunta

func _ready() -> void:
	pass

# Unico punto da cui modificare la fatica: tiene il valore dentro 0-100
# subito, non solo una volta a frame, altrimenti i calcoli successivi nello
# stesso frame partirebbero da un numero "sporco".
func modifica_fatica(delta_fatica: float) -> void:
	fatica_tot = clamp(fatica_tot + delta_fatica, 0.0, 100.0)
	fatica_changed.emit(fatica_tot)

# Chiamata prima di ricaricare il livello (da menu o "riprova"). GameManager
# è un autoload: senza reset, i valori resterebbero quelli della partita
# precedente.
func reset_stato() -> void:
	oggetti_illuminati.clear()
	coppie_vicine.clear()
	fatica_tot = 100.0
	oggetti.clear()
	speakers.clear()
	brkn_speaker = null
	brk_timer = randf_range(brk_time_min, brk_time_max)
	quota_fatica_oggetto = 0.0
	cap_altoparlante_rotto = 0.0

# Il limite minimo sotto cui la fatica non può scendere.
func calcola_limite_minimo() -> float:
	var limite = 0.0
	if brkn_speaker != null:
		limite += cap_altoparlante_rotto
	for malus in coppie_vicine.values():
		limite += malus
	return limite

func _process(delta: float) -> void:
	# Vittoria se la fatica arriva a 0.
	if fatica_tot <= 0.0:
		vittoria_raggiunta.emit()

	# Il countdown per la rottura avanza solo se nessuno speaker è già rotto,
	# altrimenti sembrerebbero rompersi "insieme" invece che uno dopo l'altro.
	if !brkn_speaker:
		brk_timer -= delta
		if brk_timer <= 0:
			if speakers.size() > 0:
				brkn_speaker = speakers.pick_random()
				# Il cap si congela qui: sotto al 15% sale a 15, sopra resta dov'è.
				cap_altoparlante_rotto = max(15.0, fatica_tot)
				brk_timer = randf_range(brk_time_min, brk_time_max)


	var limite_minimo = calcola_limite_minimo()

	# oggetti_illuminati è solo l'elenco di chi è sotto un faretto acceso ora:
	# oggetto.gd lo controlla una sola volta, al momento del piazzamento
	# (vedi oggetto.gd::place()).

	# La fatica non può scendere sotto il limite minimo.
	if fatica_tot < limite_minimo:
		fatica_tot = limite_minimo

	fatica_tot = clamp(fatica_tot, 0.0, 100.0)
	fatica_changed.emit(fatica_tot)


# Registrazioni
func registra_oggetti(o) -> void: 
	oggetti.append(o)

func calcola_quote() -> void:
	var num_oggetti = len(oggetti)
	if num_oggetti != 0:
		# Entrambi gli oggetti tolgono 50% quando piazzati (totale 100%)
		quota_fatica_oggetto = 100.0 / num_oggetti 
	else: 
		quota_fatica_oggetto = 0 

func registra_speakers(s) -> void: 
	speakers.append(s)

# Logica di prossimità tra oggetti
func registra_coppia(a,b) -> void:
	var id_a = a.get_instance_id()
	var id_b = b.get_instance_id()
	var chiave = str(min(id_a, id_b)) + "_" + str(max(id_a, id_b))
	
	if not chiave in coppie_vicine:
		var distance = a.global_position.distance_to(b.global_position)

		# Penalità massima sotto i 30cm, annullata a 2 metri di distanza.
		var contributo = clamp(remap(distance, 0.3, 2.0, 35.0, 0.0), 0.0, 35.0)
		coppie_vicine[chiave] = contributo
		modifica_fatica(contributo)

func rimuovi_coppia(a,b) -> void:
	var id_a = a.get_instance_id()
	var id_b = b.get_instance_id()
	var chiave = str(min(id_a, id_b)) + "_" + str(max(id_a, id_b))

	if chiave in coppie_vicine:
		modifica_fatica(-coppie_vicine[chiave])
		coppie_vicine.erase(chiave)
		
# Dati faretto
func aggiungi_luce_oggetto(object_id: int) -> void:
	if not oggetti_illuminati.has(object_id):
		oggetti_illuminati.append(object_id)

func rimuovi_luce_oggetto(object_id: int) -> void:
	if oggetti_illuminati.has(object_id):
		oggetti_illuminati.erase(object_id)
