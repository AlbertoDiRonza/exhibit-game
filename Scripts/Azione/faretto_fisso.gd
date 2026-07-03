extends StaticBody3D

@onready var cono_luce = $ConoLuce

func _ready() -> void:
	cono_luce.body_entered.connect(_on_cono_luce_body_entered)
	cono_luce.body_exited.connect(_on_cono_luce_body_exited)

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
			GameManager.aggiungi_luce_oggetto(body.get_instance_id())

func _on_cono_luce_body_exited(body: Node3D) -> void:
	var stato = body.get("obj_state")
	var opera = body.get("is_artwork")
	
	if stato == null:
		return
		
	if opera == true:
		GameManager.rimuovi_luce_oggetto(body.get_instance_id())
