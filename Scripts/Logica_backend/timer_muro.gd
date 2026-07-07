extends Node3D

# Pannello del tempo rimasto montato a muro, non più nell'HUD 2D: il
# giocatore deve fisicamente girarsi verso il muro per controllare quanto
# tempo resta. galleria.gd chiama set_tempo() ogni frame, esattamente come
# prima faceva con la Label 2D dell'HUD.

@onready var label_tempo: Label = $SubViewport/Panel/LabelTempo
@onready var sub_viewport: SubViewport = $SubViewport
@onready var display: MeshInstance3D = $Display

func _ready() -> void:
	# Assegnata qui via codice invece che nel file di scena: get_texture()
	# restituisce sempre una ViewportTexture valida legata a questo esatto
	# SubViewport, evitando problemi di risoluzione del percorso che possono
	# capitare scrivendo a mano il riferimento nel file .tscn (placeholder
	# magenta = texture non risolta correttamente).
	var mat := display.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_texture = sub_viewport.get_texture()

func set_tempo(minuti: float, secondi: float) -> void:
	if label_tempo:
		label_tempo.text = "%02d:%02d" % [minuti, secondi]
