extends StaticBody3D

@onready var cono_luce = $ConoLuce

func _ready() -> void:
	cono_luce.body_entered.connect(_on_cono_luce_body_entered)
	cono_luce.body_exited.connect(_on_cono_luce_body_exited)

func _on_cono_luce_body_entered(body: Node3D) -> void:
	if body.has_method("pick_up") and "obj_state" in body:
		# IL NUOVO FILTRO: L'oggetto ha la variabile 'is_artwork' ed è impostata su vero?
		if "is_artwork" in body and body.is_artwork == true:
			# È un'opera d'arte! Controlliamo se è posata a terra
			if body.obj_state == body.State.PLACED:
				GameManager.aggiungi_luce_oggetto(body.get_instance_id())

func _on_cono_luce_body_exited(body: Node3D) -> void:
	if body.has_method("pick_up") and "obj_state" in body:
		# Se esce, controlliamo sempre che fosse un'opera d'arte prima di rimuoverla
		if "is_artwork" in body and body.is_artwork == true:
			GameManager.rimuovi_luce_oggetto(body.get_instance_id())
