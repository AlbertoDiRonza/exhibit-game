extends Node3D

# Pannello del tempo a muro: bisogna girarsi per vederlo. galleria.gd
# chiama set_tempo() ogni frame.

@onready var label_tempo: Label = $SubViewport/Panel/LabelTempo
@onready var sub_viewport: SubViewport = $SubViewport
@onready var display: MeshInstance3D = $Display

func _ready() -> void:
	# Assegnata via codice: get_texture() garantisce sempre una
	# ViewportTexture valida.
	var mat := display.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_texture = sub_viewport.get_texture()

func set_tempo(minuti: float, secondi: float) -> void:
	if label_tempo:
		label_tempo.text = "%02d:%02d" % [minuti, secondi]
