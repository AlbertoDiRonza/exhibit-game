extends Node3D

# Tutorial: script del collega, adattato su due punti per combaciare col
# resto del progetto: la scena finale ora punta a main_scene.tscn (Livello 1
# vero), e prima del cambio scena chiamiamo GameManager.reset_stato() per non
# sommare l'oggetto/speaker del tutorial a quelli veri del Livello 1.

# Riferimenti ai nodi della scena, con @onready + $percorso invece di
# @export: un @export su un nodo va comunque assegnato "sul serio"
# dall'Inspector, altrimenti resta Nil a runtime e causa un crash. @onready
# funziona sempre perché legge la scena reale al momento di _ready().
@onready var testo_tutorial: Label = $TutorialHUD/Panel/TestoTutorial
@onready var oggetto_statua: RigidBody3D = $OggettoStatua
@onready var speaker_tutorial: StaticBody3D = $SpeakerTutorial
@onready var faretto_tutorial: StaticBody3D = $FarettoTutorial

# Stati del tutorial
enum Step {
	PRENDI_OGGETTO,
	PIAZZA_OGGETTO,
	ATTESA_BLACKOUT,
	RIPARA_SPEAKER,
	PORTA_SOTTO_LUCE,
	FINE
}

var stato_corrente: Step = Step.PRENDI_OGGETTO
var timer_attesa: float = 0.0

func _ready() -> void:
	# 1. Pulizia totale
	GameManager.oggetti.clear()
	GameManager.speakers.clear()
	GameManager.oggetti_illuminati.clear()

	# 2. Registriamo gli oggetti con le funzioni ufficiali
	if oggetto_statua:
		GameManager.registra_oggetti(oggetto_statua)
		# Serve per far calcolare al GameManager il valore della statua.
		GameManager.calcola_quote()

	if speaker_tutorial:
		GameManager.registra_speakers(speaker_tutorial)

	# 3. Resettiamo la fatica
	GameManager.fatica_tot = 100.0
	if GameManager.has_signal("fatica_changed"):
		GameManager.fatica_changed.emit(GameManager.fatica_tot)

	GameManager.brk_timer = 9999.0
	aggiorna_testo()

func _process(delta: float) -> void:
	match stato_corrente:

		Step.PRENDI_OGGETTO:
			if oggetto_statua.obj_state == oggetto_statua.State.HAND:
				stato_corrente = Step.PIAZZA_OGGETTO
				aggiorna_testo()

		Step.PIAZZA_OGGETTO:
			if oggetto_statua.obj_state == oggetto_statua.State.PLACED:
				stato_corrente = Step.ATTESA_BLACKOUT
				aggiorna_testo()

		Step.ATTESA_BLACKOUT:
			timer_attesa += delta
			if timer_attesa >= 4.0:
				GameManager.brkn_speaker = speaker_tutorial

				# Forziamo audio e stato per il blackout
				speaker_tutorial.spk_state = speaker_tutorial.State.BROKEN
				if speaker_tutorial.noise and not speaker_tutorial.noise.playing:
					speaker_tutorial.noise.play()

				stato_corrente = Step.RIPARA_SPEAKER
				aggiorna_testo()

		Step.RIPARA_SPEAKER:
			# Basta controllare lo stato dello speaker (il controllo su
			# brkn_speaker bloccava il flusso).
			if speaker_tutorial.spk_state == speaker_tutorial.State.FUNCTIONING:

				# Pulizia extra per sicurezza.
				GameManager.brkn_speaker = null

				stato_corrente = Step.PORTA_SOTTO_LUCE
				aggiorna_testo()

		Step.PORTA_SOTTO_LUCE:
			if GameManager.fatica_tot <= 0.0:
				stato_corrente = Step.FINE
				aggiorna_testo()
				timer_attesa = 0.0

		Step.FINE:
			timer_attesa += delta
			if timer_attesa >= 3.0:
				# Riattiviamo il GameManager prima di cambiare scena.
				GameManager.set_process(true)

				# Puliamo lo stato del tutorial prima che il Livello 1 registri
				# il suo, altrimenti si sommerebbero.
				GameManager.reset_stato()

				SceneTransition.cambia_scena("res://Scene/main_scene.tscn")

func aggiorna_testo() -> void:
	if not testo_tutorial:
		return

	match stato_corrente:
		Step.PRENDI_OGGETTO:
			testo_tutorial.text = "Guardati intorno.\nGuarda la statua e premi 'E' per prenderla."
		Step.PIAZZA_OGGETTO:
			testo_tutorial.text = "Ottimo.\nOra guarda il pavimento e premi 'E' per posarla.\nGuarda la barra della fatica scendere!"
		Step.ATTESA_BLACKOUT:
			testo_tutorial.text = "Perfetto.\nHai posizionato l'oggetto. Ma aspetta..."
		Step.RIPARA_SPEAKER:
			testo_tutorial.text = "ALLARME!\nIl rumore aumenta la fatica e la luce salta!\nCorri allo speaker e tieni premuto 'E' per ripararlo."
		Step.PORTA_SOTTO_LUCE:
			testo_tutorial.text = "Silenzio, finalmente. Ora prendi di nuovo la statua\n e posala sotto la luce del faretto\nper azzerare la fatica."
		Step.FINE:
			testo_tutorial.text = "TUTORIAL COMPLETATO!\nSei pronto per il gioco vero."
