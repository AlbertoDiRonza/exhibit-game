extends Node3D

# Tutorial: script originale del collega, adattato solo su due punti per farlo
# combaciare con il resto del progetto:
#   1. il percorso della scena finale ("LivelloPrincipale.tscn" era un
#      placeholder) ora punta a res://Scene/main_scene.tscn, che è il
#      "Livello 1" vero e proprio;
#   2. prima di cambiare scena chiamiamo GameManager.reset_stato(): senza
#      questo, l'unico oggetto/speaker del tutorial resterebbe registrato nel
#      GameManager (che è un autoload, sopravvive al cambio scena) e si
#      sommerebbe ai due oggetti/quattro speaker veri del Livello 1, sballando
#      il calcolo della quota fatica. reset_stato() azzera tutto PRIMA che gli
#      oggetti del Livello 1 si auto-registrino nel loro _ready(), esattamente
#      come già succede quando si passa dal menu o si preme "Riprova".
# Il resto della logica (macchina a stati, registrazione manuale degli
# oggetti, gestione forzata del blackout) è invariato.

# --- RIFERIMENTI AI NODI DELLA SCENA ---
# @onready + $percorso invece di @export: un @export tipizzato su un nodo
# (es. "RigidBody3D") in Godot richiede comunque un NodePath assegnato "sul
# serio" dall'Inspector per essere risolto in un riferimento vero; scrivendolo
# a mano nel file .tscn (come avevo fatto) la proprietà restava Nil a runtime,
# causando il crash "Invalid access to property or key 'obj_state' on a base
# object of type 'Nil'". @onready con $ è lo stesso pattern già usato ovunque
# nel resto del progetto (galleria.gd, player.gd, timer_muro.gd) e si risolve
# sempre correttamente perché legge la scena reale al momento di _ready().
@onready var testo_tutorial: Label = $TutorialHUD/Panel/TestoTutorial
@onready var oggetto_statua: RigidBody3D = $OggettoStatua
@onready var speaker_tutorial: StaticBody3D = $SpeakerTutorial
@onready var faretto_tutorial: StaticBody3D = $FarettoTutorial

# --- STATI DEL TUTORIAL ---
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
		# FONDAMENTALE: Diciamo al GameManager di calcolare il valore della statua!
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
			# IL FIX: Controlliamo solo lo stato dello speaker.
			# Rimosso il controllo "and GameManager.brkn_speaker == null" che bloccava il flusso.
			if speaker_tutorial.spk_state == speaker_tutorial.State.FUNCTIONING:

				# Facciamo noi pulizia per sicurezza!
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
				# Riacendiamo il GameManager per la prossima scena prima di cambiare!
				GameManager.set_process(true)

				# Puliamo lo stato del tutorial (un oggetto, uno speaker) prima
				# che il Livello 1 registri i suoi (due oggetti, quattro
				# speaker), altrimenti si sommerebbero.
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
			testo_tutorial.text = "Silenzio, finalmente.\nOra prendi di nuovo la statua\n e posala sotto la luce del faretto\nper azzerare la fatica."
		Step.FINE:
			testo_tutorial.text = "TUTORIAL COMPLETATO!\nSei pronto per il gioco vero."
