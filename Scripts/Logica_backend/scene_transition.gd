extends CanvasLayer

# Autoload globale: un rettangolo nero a schermo intero per dissolvere e
# riportare alla luce a ogni cambio scena, invece del taglio secco di
# get_tree().change_scene_to_file(). Essendo un autoload sopravvive al
# cambio scena, quindi il nero resta visibile anche mentre la scena vecchia
# viene distrutta e la nuova istanziata.
#
# Uso: SceneTransition.cambia_scena("res://Scene/x.tscn") al posto di
# get_tree().change_scene_to_file() diretto.

@export var durata_dissolvenza: float = 0.5

var overlay: ColorRect
var in_transizione: bool = false

func _ready() -> void:
	layer = 128 # sempre sopra a qualunque HUD di scena
	process_mode = Node.PROCESS_MODE_ALWAYS

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

func cambia_scena(percorso: String) -> void:
	if in_transizione:
		return
	in_transizione = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	await _dissolvi(1.0)

	get_tree().change_scene_to_file(percorso)
	MusicManager.riavvia()

	# Aspettiamo un paio di frame per essere sicuri che la nuova scena sia già
	# in albero, altrimenti si vedrebbe per un istante quella vecchia.
	await get_tree().process_frame
	await get_tree().process_frame

	await _dissolvi(0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	in_transizione = false

func _dissolvi(alpha_finale: float) -> void:
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", alpha_finale, durata_dissolvenza)
	await tween.finished
