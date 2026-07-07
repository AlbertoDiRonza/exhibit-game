extends Node

# Musica di sottofondo del gioco. Autoload, quindi il suo _ready() gira
# all'avvio del gioco, prima ancora che la scena Menu entri nell'albero:
# per questo la musica parte già da sola quando il menu compare, senza
# bisogno che menu_principale.gd faccia nulla.
#
# Comportamento:
# - Riparte da 0:00 ogni volta che si cambia scena: SceneTransition.cambia_scena()
#   chiama riavvia() a ogni transizione (menu -> tutorial, tutorial -> livello1,
#   livello1 -> vittoria/game over, riprova -> livello1).
# - Si interrompe (pausa, non stop) mentre uno speaker è rotto, e riprende
#   esattamente da dove si era fermata quando viene riparato: usiamo
#   stream_paused, che congela la posizione di riproduzione invece di
#   azzerarla.
# - Il file caricato è una versione tagliata a 5 minuti della traccia
#   originale da 11 minuti (gamemusic.ogg, ~5MB), non il file originale da
#   215MB (gamemusic.flac): quest'ultimo resta negli asset ma non viene mai
#   caricato in gioco. Essendo la traccia usata più corta di una partita
#   completa, si rimette in loop da sola tramite il segnale "finished".

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
	# "finished" non scatta mentre stream_paused è true, quindi se arriva qui
	# vuol dire che la traccia è arrivata davvero in fondo: la rimandiamo da capo.
	player.play(0.0)

func _process(_delta: float) -> void:
	var speaker_rotto = GameManager.brkn_speaker != null
	if speaker_rotto and not in_pausa_per_speaker:
		in_pausa_per_speaker = true
		player.stream_paused = true
	elif not speaker_rotto and in_pausa_per_speaker:
		in_pausa_per_speaker = false
		player.stream_paused = false
