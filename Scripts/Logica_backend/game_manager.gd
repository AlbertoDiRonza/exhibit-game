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

# Cap "congelato" nel momento in cui uno speaker si rompe: se la fatica in
# quel momento è già sotto il 15%, il cap è 15 (la spinge su); altrimenti il
# cap è la fatica stessa in quel momento (resta bloccata lì, non sale a 15
# né può scendere). Sparisce del tutto quando lo speaker viene riparato.
var cap_altoparlante_rotto: float = 0.0


@warning_ignore("unused_signal")
signal game_over
signal vittoria_raggiunta

func _ready() -> void:
	pass

# Unico punto da cui la fatica va modificata (quota luce, malus di
# prossimità, ecc.): tiene il valore sempre dentro 0-100 SUBITO, non solo una
# volta a frame in _process(). Senza questo, un valore temporaneamente sopra
# 100 (es. un malus di prossimità alto) restava "gonfiato" per un istante e
# tutte le somme/sottrazioni successive nello stesso frame partivano da quel
# numero sporco invece che da uno pulito, causando sbalzi confusi.
func modifica_fatica(delta_fatica: float) -> void:
	fatica_tot = clamp(fatica_tot + delta_fatica, 0.0, 100.0)
	fatica_changed.emit(fatica_tot)

# Chiamata prima di (ri)caricare main_scene.tscn (da menu, riprova dopo
# vittoria o riprova dopo sconfitta). GameManager è un autoload: senza questo
# reset esplicito, fatica_tot e le altre variabili restano quelle
# dell'ultima partita, invece di ripartire puliti.
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

# 1. IL CALCOLO DEL MURO INVALICABILE
func calcola_limite_minimo() -> float:
	var limite = 0.0
	if brkn_speaker != null:
		limite += cap_altoparlante_rotto
	for malus in coppie_vicine.values():
		limite += malus
	return limite

func _process(delta: float) -> void:
	# SEGNALE DI VITTORIA (Se arrivi a 0)
	if fatica_tot <= 0.0:
		vittoria_raggiunta.emit()

	# ROTTURA ALTOPARLANTE
	# Il countdown avanza SOLO se nessuno speaker è già rotto: altrimenti,
	# se il countdown scendeva sotto zero durante l'attesa che il giocatore
	# ripari quello attuale, alla riparazione ne scattava subito un altro
	# (sembrava che si rompessero "insieme", in realtà uno subito dopo l'altro).
	if !brkn_speaker:
		brk_timer -= delta
		if brk_timer <= 0:
			if speakers.size() > 0:
				brkn_speaker = speakers.pick_random()
				# Il cap si "congela" qui: sotto al 15% viene spinto a 15,
				# sopra al 15% resta esattamente dov'è (non sale, non scende).
				cap_altoparlante_rotto = max(15.0, fatica_tot)
				brk_timer = randf_range(brk_time_min, brk_time_max)


	var limite_minimo = calcola_limite_minimo()

	# NOTA: la riduzione della fatica NON avviene più qui in modo continuo.
	# oggetti_illuminati serve solo come elenco di "chi è sotto un faretto
	# acceso in questo momento": oggetto.gd lo controlla una volta sola, nel
	# momento in cui posizioni un'opera, per decidere se applicare la quota
	# fissa (vedi oggetto.gd::place()).

	# BLOCCO DI SICUREZZA
	if fatica_tot < limite_minimo:
		fatica_tot = limite_minimo

	fatica_tot = clamp(fatica_tot, 0.0, 100.0)
	fatica_changed.emit(fatica_tot)


# --- REGISTRAZIONI ---
func registra_oggetti(o) -> void: 
	oggetti.append(o)

func calcola_quote() -> void:
	var num_oggetti = len(oggetti)
	if num_oggetti != 0:
		# Entrambi gli oggetti tolgono 50% quando piazzati (Totale 100%)
		quota_fatica_oggetto = 100.0 / num_oggetti 
	else: 
		quota_fatica_oggetto = 0 

func registra_speakers(s) -> void: 
	speakers.append(s)

# --- LOGICA SPAZIALE ---
func registra_coppia(a,b) -> void:
	var id_a = a.get_instance_id()
	var id_b = b.get_instance_id()
	var chiave = str(min(id_a, id_b)) + "_" + str(max(id_a, id_b))
	
	if not chiave in coppie_vicine:
		var distance = a.global_position.distance_to(b.global_position)

		# MODIFICA: Cambiato il valore massimo da 3.0 a 6.0 metri!
		# Significa che gli oggetti genereranno fatica finché non saranno distanti ALMENO 6 metri.
		# AR Scale: Penalità massima a 30cm, annullata quando distanti 2 metri
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
		
# --- DATI FARETTO ---
func aggiungi_luce_oggetto(object_id: int) -> void:
	if not oggetti_illuminati.has(object_id):
		oggetti_illuminati.append(object_id)

func rimuovi_luce_oggetto(object_id: int) -> void:
	if oggetti_illuminati.has(object_id):
		oggetti_illuminati.erase(object_id)
