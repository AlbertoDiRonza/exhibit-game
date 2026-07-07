# Exhibit!

![Copertina](Assets/Immagini/copertina_menu.png)

Un videogioco arcade runner in Realtà Aumentata per Android, fatto con Godot 4.7, sul tema della **fatica museale**. Il giocatore veste i panni di un allestitore: deve sistemare le opere di una galleria sotto i faretti giusti, mantenendo la giusta distanza tra loro, entro un tempo limitato, mentre gestisce interferenze sonore che rendono il compito più difficile.

## Indice

- [Concept](#concept)
- [Struttura del gioco: Tutorial + Livello 1](#struttura-del-gioco-tutorial--livello-1)
- [Come si gioca: la fatica](#come-si-gioca-la-fatica)
- [Livello 1: oggetti e faretti](#livello-1-oggetti-e-faretti)
- [Altoparlanti e riparazione](#altoparlanti-e-riparazione)
- [Musica di sottofondo](#musica-di-sottofondo)
- [Modalità PC vs AR](#modalità-pc-vs-ar)
- [Comandi](#comandi)
- [Schermate](#schermate)
- [Struttura del progetto](#struttura-del-progetto)
- [File esclusi dal repository](#file-esclusi-dal-repository)

## Concept

Il gioco è ispirato al fenomeno della **"museum fatigue"**: il calo di attenzione e interesse dei visitatori durante una visita al museo, causato da fattori come il sovraffollamento di oggetti in poco spazio ("object competition"), la disposizione degli ambienti e stimoli distraenti (anche sonori).

Riferimenti principali:
- Bitgood, S. (2009). *Museum Fatigue: A Critical Review*. Visitor Studies, 12(2), 93–111.
- Fisher, A. V., Godwin, K. E., & Seltman, H. (2014). *Visual Environment, Attention Allocation, and Learning in Young Children: When Too Much of a Good Thing May Be Bad*. Psychological Science.
- Mukhortova, E. (2025). *Visitor Attention in Museum and Museum Fatigue Syndrome*. Museologica Brunensia, 14(1), 29–37.

## Struttura del gioco: Tutorial + Livello 1

All'avvio del **Menu principale** parte anche la musica di sottofondo. Premendo "Gioca" si entra nel **Tutorial** (Livello 0): una versione ridotta della galleria, con una sola statua, un solo altoparlante e un solo faretto, pensata per insegnare passo passo le meccaniche di base (prendere un oggetto, piazzarlo sotto la luce, reagire a un altoparlante che si rompe e ripararlo). Finito il tutorial, il gioco passa in automatico al **Livello 1** (la galleria vera e propria, con tutti gli oggetti e i faretti).

Ogni cambio di scena — menu → tutorial, tutorial → livello 1, livello 1 → vittoria/sconfitta, "Riprova" → livello 1 — passa da una **dissolvenza in nero** (fade-out/fade-in) invece di un taglio secco, per rendere le transizioni meno brusche.

## Come si gioca: la fatica

Il cuore del gioco è la barra della **fatica** (`GameManager.fatica_tot`), che parte al 100% e deve scendere a 0% per vincere. Ecco cosa la fa muovere:

- **Posizionare un'opera sotto un faretto acceso** scala una quota fissa di fatica (100% diviso il numero di opere in scena — nel Livello 1, con 5 opere, sono 20 punti a testa). La quota si applica una volta sola al momento del posizionamento, solo se l'opera è davvero dentro il cono di luce di un faretto acceso in quell'istante; riprendendo in mano l'opera, la quota viene restituita (la fatica risale).
- **Piazzare due opere troppo vicine tra loro** genera un malus che si somma alla fatica, e resta finché non le allontani abbastanza.
- **Un altoparlante che si rompe** a caso ogni 10-30 secondi inizia a fare rumore. Finché non lo ripari, la fatica non può scendere sotto un certo valore "congelato" nel momento della rottura (minimo 15%, o il valore che aveva già se era più alto) — e mentre è rotto **non puoi raccogliere nuovi oggetti** (posare quello che hai già in mano resta sempre permesso, per non restare bloccato). I faretti, invece di spegnersi di scatto, **lampeggiano per circa un secondo** come avviso prima di spegnersi davvero, e restano accesi se ripari l'altoparlante mentre stanno ancora lampeggiando.
- Un **timer** (60 secondi nel Livello 1) limita il tempo a disposizione: se scade prima che la fatica arrivi a 0, è sconfitta. Il tempo rimasto è mostrato su un pannello 3D montato a muro, non come testo fisso a schermo: bisogna girarsi fisicamente per controllarlo.

## Livello 1: oggetti e faretti

Il Livello 1 contiene **5 opere** da allestire: la Venere di Milo, un tavolino antico, una brocca, un torso e una statua di Polinnia. Tutte hanno una dimensione raddoppiata rispetto al modello originale (la brocca è scalata leggermente di più, per essere comunque ben visibile e abbastanza alta da rientrare nel cono di un faretto).

Le opere sono illuminate da **3 faretti fissi**. Ogni faretto ha un cono di rilevamento abbastanza ampio da poter ospitare più di un'opera contemporaneamente, a patto di non ammassarle troppo vicine (in quel caso scatta comunque il malus di prossimità descritto sopra). La zona di "ingombro personale" di ogni opera (quella che genera il malus se si sovrappone a quella di un'altra) è stata ridotta rispetto alle prime versioni proprio per rendere possibile piazzare più di un'opera per faretto.

## Altoparlanti e riparazione

Gli altoparlanti esistono in **tre taglie**, ciascuna con un tempo di riparazione diverso:

| Taglia | Scala visiva | Tempo di riparazione |
|---|---|---|
| Piccolo | 1x | 3 secondi |
| Medio | 2x | 5 secondi |
| Grande | 4x | 7 secondi |


## Musica di sottofondo

Una traccia musicale riparte automaticamente **a ogni cambio di scena** (gestita da un autoload dedicato, `MusicManager`) e parte da sola già nel menu principale. Mentre un altoparlante è rotto la musica si **mette in pausa**, e riprende esattamente da dove si era fermata non appena l'altoparlante viene riparato — coerente con l'idea che il rumore "interrompe" l'esperienza del visitatore.

## Modalità PC vs AR

Il gioco gira su due modalità, decise automaticamente all'avvio da `player.gd`:

- **AR (utenti finali)**: passthrough della fotocamera e tracking dello spazio reale. È la modalità pensata per il telefono.
- **PC (solo per test interni)**: quando la modalità AR non è disponibile (es. in editor su desktop), il gioco passa in automatico a un controllo classico da tastiera/mouse. Serve solo per provare le meccaniche senza dover esportare e installare sul telefono ogni volta.

## Comandi

| | PC | AR |
|---|---|---|
| Movimento | WASD | Joystick virtuale touch (basso a sinistra) |
| Guardarsi intorno | Mouse (tasto F per catturare il cursore) | Movimento fisico del telefono |
| Raccogliere/posizionare oggetto | Tasto E | Tasto "Raccogli"/"Posiziona" (appare quando guardi un oggetto interagibile) |
| Riparare speaker rotto | Tieni premuto E guardandolo (3-7s a seconda della taglia) | Tieni premuto il tasto "Ripara" dedicato |

## Schermate

Tre schermate di contorno al gioco vero e proprio, collegate tra loro con le stesse dissolvenze in nero descritte sopra:

- **Menu principale** — copertina a piena pagina, titolo in stile "poster" e due tasti (Gioca / Esci). La musica di sottofondo parte già da qui.
- **Vittoria** — folla e direttore del museo felici.
- **Sconfitta** — folla e direttore arrabbiati, sfondo più cupo.

<p float="left">
  <img src="Assets/Immagini/direttore_vittoria.png" width="45%" alt="Direttore felice (vittoria)" />
  <img src="Assets/Immagini/direttore_sconfitta.png" width="45%" alt="Direttore arrabbiato (sconfitta)" />
</p>

Entrambe le schermate di fine partita hanno un tasto "Riprova" (ricarica direttamente il Livello 1, senza passare dal tutorial) e "Esci".

## Struttura del progetto

```
Scene/                      Scene Godot (.tscn)
  menu_principale.tscn         Menu principale
  tutorial.tscn                 Tutorial (Livello 0)
  main_scene.tscn                La galleria vera e propria (Livello 1)
  vittoria.tscn / game_over.tscn   Schermate di fine partita
  player.tscn                   Giocatore (PC + AR)
  pavimento.tscn                 Pavimento + muri, riusato da tutorial e livello 1
  faretto_fisso.tscn             Faretto con cono di luce rilevabile
  oggetto.tscn / altoparlante.tscn  Opere d'arte e speaker

Scripts/
  Azione/                    Logica lato giocatore/oggetti (player.gd, oggetto.gd, faretto_fisso.gd, virtual_joystick.gd, ...)
  Logica_backend/            Stato di gioco condiviso e navigazione (game_manager.gd, galleria.gd, tutorial.gd,
                              menu_principale.gd, vittoria.gd, game_over.gd, scene_transition.gd, music_manager.gd)

Assets/Immagini/             Immagini usate nell'interfaccia (copertina, direttore, folla, ...)
Assets/Sound/                 Audio (rumore altoparlanti, musica di sottofondo)
Assets/3D_models/              Modelli 3D delle opere, degli speaker e dei faretti
```

Tre autoload (singleton, sempre attivi) tengono lo stato e la navigazione del gioco:

- `GameManager` — fatica, oggetti registrati, altoparlante rotto, coppie di oggetti vicine. Va resettato esplicitamente con `GameManager.reset_stato()` prima di ricaricare una scena di gioco (dal menu, dal tutorial, o da "Riprova"), altrimenti lo stato della partita precedente resterebbe attaccato.
- `SceneTransition` — gestisce la dissolvenza in nero a ogni cambio scena (`SceneTransition.cambia_scena("res://...")` al posto della chiamata diretta di Godot).
- `MusicManager` — gestisce la musica di sottofondo (avvio, riavvio a ogni cambio scena, pausa/ripresa sui guasti agli altoparlanti).

## File esclusi dal repository

Il `.gitignore` esclude di proposito alcune cartelle/file legati alla configurazione locale di sviluppo, all'esportazione Android e alla traccia audio originale non tagliata (`gamemusic.flac`, 11 minuti — in gioco si usa solo la versione tagliata `gamemusic.ogg`), non necessari a chi lavora solo sulla logica di gioco.
