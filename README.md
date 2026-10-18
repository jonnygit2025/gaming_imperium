# Regna – L'Ombra di Roma (476–732 d.C.)

Strategia in stile Total War: campagna a turni sul Mediterraneo e battaglie in tempo reale in 3D,
dalla caduta dell'Impero d'Occidente alla battaglia di Poitiers. Sviluppato con **Godot 4.7.2**
(GDScript tipizzato) e pensato per girare bene anche su PC non recenti.

> Stato: **Fase 2 – Mappa di campagna 3D**. Il piano completo (8 fasi) è in `docs/PIANO.md`.
> Il vecchio prototipo pygame è in `legacy/`.

## Giocare (Windows 10/11 x64)

1. Avvia `Regna.exe`. Al primo avvio Windows può mostrare "Windows ha protetto il PC":
   clicca **Ulteriori informazioni → Esegui comunque** (il file non è firmato digitalmente).
2. Al primo avvio il gioco **rileva il PC** e sceglie preset grafico e renderer. Se il renderer
   consigliato è diverso da quello in uso, propone un riavvio.
3. In **Opzioni** puoi cambiare tutto e avviare il **Test prestazioni**, che scrive i risultati in
   `benchmark_risultati.txt` accanto all'eseguibile.

Tasti nei menu: `F3` contatore FPS · `Esc` indietro.

Sulla mappa di campagna: `WASD`/frecce o mouse sul bordo dello schermo per muoversi · rotella per
lo zoom · `Q`/`E` o tasto centrale trascinato per ruotare · clic sinistro seleziona una provincia,
doppio clic la centra · clic destro o `Esc` deseleziona · `Esc` menu di pausa · `Invio` fine turno ·
`F3` misure (FPS medi e minimi, chiamate di disegno, triangoli, memoria video).

In **Opzioni** ci sono due test prestazioni: la battaglia (Fase 1) e il volo sulla mappa di
campagna; entrambi scrivono i risultati in `benchmark_risultati.txt` accanto all'eseguibile.

Opzione di avvio per le prove: `Regna.exe -- --partita-prova=476_caduta_di_roma:odoacre`
apre direttamente una partita (scenario:fazione).

Impostazioni, salvataggi e log: `%APPDATA%\Regna\` (`settings.cfg`, `override.cfg`, `saves\`, `logs\`).

## Sviluppo

Requisiti: [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) (versione standard, non .NET).

- **Aprire il progetto**: Godot → Importa → seleziona `project.godot`.
- **Test automatici** (GUT, in headless):
  - Linux/macOS: `tools/run_tests.sh`
  - Windows: `tools\run_tests.bat` (imposta `GODOT` con il percorso dell'eseguibile di Godot)
  I test falliscono anche se nel log compaiono errori o warning.
- **Simulazione** di 200 turni per ogni scenario, con salvataggi e ricaricamenti:
  `tools/simulate_campaign.sh` (fallisce se nel log compaiono errori o warning).
- **Mappa di campagna**: i file in `assets/map/` sono generati offline da Natural Earth con
  `tools/map/build_map.sh` (Python 3 con numpy, scipy e pillow + Godot). Vedi `assets/map/README.md`.
- **Foto di controllo** della mappa (Linux, senza schermo): `tools/capture/capture_campaign.gd`
  (istruzioni in cima al file).
- **Controlli severi**: i warning più importanti di GDScript (variabili senza tipo, divisioni intere,
  variabili oscurate…) sono trattati come errori in `project.godot`.

### Esportare il .exe da Godot sul tuo PC

1. Apri il progetto in Godot 4.7.2.
2. Menu **Editor → Gestisci modelli di esportazione → Scarica e installa** (una volta sola).
3. Menu **Progetto → Esporta…**, seleziona il preset **Windows Desktop**.
4. Clic su **Esporta progetto**, togli la spunta a "Esporta con debug", salva come `Regna.exe`.
   Il preset è già configurato: un solo file con i dati inclusi, test e prototipo esclusi.

Da riga di comando: `godot --headless --export-release "Windows Desktop" build/windows/Regna.exe`.

## Struttura

```
data/            contenuto di gioco in JSON (fonte di verità, modificabile senza toccare il codice)
  religions.json cultures.json factions.json units.json buildings.json
  map/provinces.json   47 province, confini e stretti
  map/campaign_map.json  generato: proiezione, posizioni di città ed etichette
  scenarios/           5 scenari (476, 535, 568, 636, 711)
src/core/        LOGICA PURA, nessun nodo grafico → testabile in headless
  data/          lettura e validazione dei dati (GameDatabase)
  campaign/      stato della partita (CampaignState, FactionState, ArmyState), fine turno (TurnProcessor)
  map/           geometria della mappa: proiezione, ricerca della provincia, quote (CampaignMapData)
  save/          salvataggi JSON con versione
src/settings/    preset grafici, profilo hardware, consiglio preset, statistiche FPS (logica pura)
src/game/        autoload: GameData, Settings, Session; percorsi delle scene
src/view/        SOLO GRAFICA: menu, mappa di campagna 3D e interfaccia, test prestazioni
scenes/          scene .tscn (radici con script)
assets/          font, shader, icona, mappa generata (map/); CREDITS.md con le licenze
tests/           test GUT (unit e integrazione)
tools/           script per test, simulazione, generazione della mappa (map/) e foto (capture/)
legacy/          prototipo pygame (non più usato)
```

### Scelte per le prestazioni

- Soldati disegnati con **una MultiMesh per reggimento**: muovere un reggimento costa una sola
  trasformazione; l'animazione dei singoli soldati è nello shader (`assets/shaders/soldier.gdshader`).
- Modelli low-poly generati da forme semplici (~150 triangoli per fante).
- Preset Basso/Medio/Alto/Ultra: ombre, distanza visiva, densità dei soldati (Alto = 2.000 soldati),
  vegetazione, antialiasing, scala di rendering, effetti.
- Renderer selezionabile (Forward+, Mobile, Compatibilità) tramite `user://override.cfg`; per schede
  come la GTX 650 il gioco consiglia **Compatibilità** (OpenGL 3.3).
- **Mappa di campagna**: tutto è precalcolato (mesh, texture, campi di distanza). Terreno con
  ~310.000 triangoli in una sola chiamata di disegno; colori delle fazioni con **uno shader** che
  legge la mappa degli id e una tavolozza di 256×2 pixel: cambiare il padrone di una provincia
  costa due pixel, nessuna mesh si ricostruisce. Confini e coste da campi di distanza filtrati:
  linee nette a ogni zoom. Città (4 tipi) ed eserciti in **MultiMesh** (5 chiamate di disegno in
  tutto). Il terreno non proietta ombre (costerebbe ridisegnarlo 4 volte); selezione col mouse
  senza fisica, con un raggio sulla griglia delle quote e una lettura della mappa degli id.

## Licenze

Asset di terze parti e relative licenze: `assets/CREDITS.md`. Framework di test GUT: licenza MIT (`addons/gut/LICENSE.md`).
