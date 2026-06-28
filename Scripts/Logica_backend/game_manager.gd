extends Node

var oggetti_illuminati: Array = []
var coppie_vicine = {}
var fatica_tot: float = 100.0
signal fatica_changed 
var oggetti = []
var quota_fatica_oggetto: float

var speakers = []
var brkn_speaker = null

# Timer interno per gli altoparlanti
var brk_time_min: float = 10.0
var brk_time_max: float = 30.0
var brk_timer: float = randf_range(brk_time_min, brk_time_max)
var timer_rottura_spk: float = 0.0 
var quota_fatica_spk : float = 1.0 
var fatica_tot_rimossa_spk: float = 0.0

@warning_ignore("unused_signal")
signal game_over

func _ready() -> void:
	pass

# --- IL NUOVO CALCOLO DEL LIMITE INVALICABILE ---
func calcola_limite_minimo() -> float:
	var limite = 0.0
	
	# 1. Tappo dell'altoparlante rotto
	if brkn_speaker != null:
		limite += 15.0 # Se suona, la barra non scende sotto il 15%
		
	# 2. Tappo del disordine (somma tutti i malus degli oggetti vicini)
	for malus in coppie_vicine.values():
		limite += malus 
		
	return limite

func _process(delta: float) -> void:
	# --- 1. ROTTURA ALTOPARLANTE ---
	brk_timer -= delta
	if brk_timer <= 0:
		if !brkn_speaker and speakers.size() > 0:
			brkn_speaker = speakers.pick_random()
			brk_timer = randf_range(brk_time_min, brk_time_max)
			
	if brkn_speaker != null: 
		timer_rottura_spk += delta
		if timer_rottura_spk >= 2.0: 
			fatica_tot += quota_fatica_spk
			fatica_tot_rimossa_spk += quota_fatica_spk
			fatica_tot = clamp(fatica_tot, 0, 100)
			timer_rottura_spk = 0.0

	# --- 2. IL LIMITE ATTUALE ---
	var limite_minimo = calcola_limite_minimo()

	# --- 3. CURA DELLA LUCE ---
	if oggetti_illuminati.size() > 0:
		var velocita_riduzione_luce = 8.0 
		
		# La luce cura la fatica, ma si ferma prima se incontra il limite
		if fatica_tot > limite_minimo:
			fatica_tot -= (velocita_riduzione_luce * delta)

	# --- 4. BLOCCO DI SICUREZZA GLOBALE ---
	# Indipendentemente da tutto, forziamo la barra a non "sfondare" il pavimento dinamico
	if fatica_tot < limite_minimo:
		fatica_tot = limite_minimo
		
	# Aggiorniamo sempre la barra a schermo
	fatica_changed.emit(fatica_tot)


# --- REGISTRAZIONI ---
func registra_oggetti(o) -> void: 
	oggetti.append(o)

func calcola_quote() -> void:
	var num_oggetti = len(oggetti)
	if num_oggetti != 0:
		quota_fatica_oggetto = fatica_tot / num_oggetti 
	else: 
		quota_fatica_oggetto = 0 

func registra_speakers(s) -> void: 
	speakers.append(s)

# --- MECCANICA SPAZIALE (Disordine vs Ordine) ---
func registra_coppia(a,b) -> void:
	var id_a = a.get_instance_id()
	var id_b = b.get_instance_id()
	var chiave = str(min(id_a, id_b)) + "_" + str(max(id_a, id_b))
	
	if chiave in coppie_vicine: 
		return
	else: 
		var distance = a.global_position.distance_to(b.global_position)
		var contributo = clamp(remap(distance, 0.5, 3.0, 10.0, 0.0), 0.0, 10.0) 
		coppie_vicine[chiave] = contributo
		
		# Botta di fatica istantanea quando sbagli
		fatica_tot += contributo 
		fatica_tot = clamp(fatica_tot, 0, 100)
		
func rimuovi_coppia(a,b) -> void:
	var id_a = a.get_instance_id()
	var id_b = b.get_instance_id()
	var chiave = str(min(id_a, id_b)) + "_" + str(max(id_a, id_b))
	
	if chiave in coppie_vicine: 
		# Sollievo istantaneo quando ricollochi
		fatica_tot -= coppie_vicine[chiave] 
		coppie_vicine.erase(chiave)
		
# --- GESTIONE DATI FARETTO ---
func aggiungi_luce_oggetto(object_id: int) -> void:
	if not oggetti_illuminati.has(object_id):
		oggetti_illuminati.append(object_id)

func rimuovi_luce_oggetto(object_id: int) -> void:
	if oggetti_illuminati.has(object_id):
		oggetti_illuminati.erase(object_id)
