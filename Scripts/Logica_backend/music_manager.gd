extends Node

# Musica di sottofondo. Autoload: parte da sola all'avvio, prima ancora che
# il Menu entri in scena.
#
# - Riparte da 0:00 a ogni cambio scena (SceneTransition chiama riavvia()).
# - Va in pausa (non stop) mentre uno speaker è rotto, e riprende da dove si
#   era fermata: usiamo stream_paused invece di azzerare la posizione.
# - Usa la versione tagliata a 5 minuti (gamemusic.ogg), non l'originale da
#   11 minuti (gamemusic.flac, tenuto negli asset ma mai caricato in gioco).

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()

var in_pausa_per_speaker: bool = false

func _ready() -> void:
	add_child(player)
	player.stream = load("res://Assets/Sound/gamemusic.ogg")
	player.volume_db = -8.0
	player.finished.connect(_on_finished)
	player.play()

# Chiamata da SceneTransition ad ogni cambio scena: riporta la musica a 0:00.
func riavvia() -> void:
	in_pausa_per_speaker = false
	player.stream_paused = false
	player.stop()
	player.play(0.0)

func _on_finished() -> void:
	# "finished" non scatta durante la pausa: se arriva qui la traccia è
	# finita davvero, la rimandiamo da capo.
	player.play(0.0)

func _process(_delta: float) -> void:
	var speaker_rotto = GameManager.brkn_speaker != null
	if speaker_rotto and not in_pausa_per_speaker:
		in_pausa_per_speaker = true
		player.stream_paused = true
	elif not speaker_rotto and in_pausa_per_speaker:
		in_pausa_per_speaker = false
		player.stream_paused = false
