extends Node

var coppie_vicine = {}
var fatica_tot: float = 100.0 # la fatica deve essere ridotta a zero dal giocatore in un certo tempo
signal fatica_changed 
var oggetti = []
var quota_fatica_oggetto: float

signal game_over

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
 
func registra_oggetti(o) -> void: 
	oggetti.append(o)

func calcola_quote() -> void:
	var num_oggetti = len(oggetti)
	if num_oggetti != 0:
		quota_fatica_oggetto = fatica_tot/num_oggetti #assumendo tutti gli oggetti con stessa quota di fatica che viene tolta
	else: 
		quota_fatica_oggetto = 0 

func registra_coppia(a,b) -> void:
	var id_a = a.get_instance_id()
	var id_b = b.get_instance_id()
	var chiave = str(min(id_a, id_b)) + "_" + str(max(id_a, id_b))
	if chiave in coppie_vicine: 
		return
	else: 
		var distance = a.global_position.distance_to(b.global_position) #restituisce la distanza in metri tra due punti
		var contributo = clamp(remap(distance, 0.5, 3.0, 10.0, 0.0), 0.0, 10.0) #contributo di prossimità aggiunto alla barra della fatica
		coppie_vicine[chiave] = contributo
		fatica_tot += contributo #la coppia è la chiave e il valore è il contributo associato
		fatica_changed.emit(fatica_tot)
		
func rimuovi_coppia(a,b) -> void:
	var id_a = a.get_instance_id()
	var id_b = b.get_instance_id()
	var chiave = str(min(id_a, id_b)) + "_" + str(max(id_a, id_b))
	if chiave in coppie_vicine: 
		fatica_tot -= coppie_vicine[chiave] #la coppia è la chiave e il valore è il contributo associato
		fatica_changed.emit(fatica_tot)
		coppie_vicine.erase(chiave)
	else: 
		return
