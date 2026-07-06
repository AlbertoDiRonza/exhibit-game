extends Area3D

# Quanta fatica toglie al secondo
@export var velocita_recupero: float = 15.0

# Ricorda quale scultura è sotto la luce
var opera_sotto_luce: Node3D = null

func _ready() -> void:
	# Attiviamo i sensori di collisione
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if opera_sotto_luce:
		# Cerchiamo il GameManager in modo dinamico e sicuro
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			# Accediamo alla variabile tramite il riferimento 'gm'
			gm.fatica_tot -= velocita_recupero * delta
			if gm.fatica_tot < 0:
				gm.fatica_tot = 0

func _on_body_entered(body: Node3D) -> void:
	# Filtro rigoroso: reagisce SOLO se l'oggetto è nel gruppo "scultura"
	if body.get("is_artwork"):
		opera_sotto_luce = body
		illumina_scultura(body, true)
		print("🔥 Opera d'arte sotto la luce! Fatica in discesa.")

func _on_body_exited(body: Node3D) -> void:
	# Se l'opera esce dal raggio, si spegne e la fatica smette di scendere
	if body == opera_sotto_luce:
		illumina_scultura(body, false)
		opera_sotto_luce = null
		print("❌ Opera d'arte fuori dalla luce.")

# La magia visiva: accende il materiale della statua
func illumina_scultura(oggetto: Node3D, attivo: bool) -> void:
	# Cerca la geometria 3D dentro l'oggetto
	var mesh = oggetto.get_node_or_null("MeshInstance3D")
	if mesh:
		var materiale = mesh.get_surface_override_material(0)
		if not materiale:
			materiale = mesh.mesh.surface_get_material(0)
			
		if materiale is StandardMaterial3D:
			materiale.emission_enabled = attivo
			materiale.emission = Color(0.9, 0.8, 0.5) # Luce calda dorata
			materiale.emission_energy_multiplier = 2.0 if attivo else 0.0
