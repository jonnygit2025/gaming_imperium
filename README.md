# Regna – L'Ombra di Roma (476–732 d.C.)

Strategia in stile Total War: campagna a turni sul Mediterraneo e battaglie in tempo reale in 3D,
dalla caduta dell'Impero d'Occidente alla battaglia di Poitiers. Sviluppato con **Godot 4.7.2**
(GDScript tipizzato) e pensato per girare bene anche su PC non recenti.

> Stato: **Fase 1 – Base e menu**. Il piano completo (8 fasi) è in `docs/PIANO.md`.
> Il vecchio prototipo pygame è in `legacy/`.

## Giocare (Windows 10/11 x64)

1. Avvia `Regna.exe`. Al primo avvio Windows può mostrare "Windows ha protetto il PC":
   clicca **Ulteriori informazioni → Esegui comunque** (il file non è firmato digitalmente).
2. Al primo avvio il gioco **rileva il PC** e sceglie preset grafico e renderer. Se il renderer
   consigliato è diverso da quello in uso, propone un riavvio.
3. In **Opzioni** puoi cambiare tutto e avviare il **Test prestazioni**, che scrive i risultati in
   `benchmark_risultati.txt` accanto all'eseguibile.

Tasti: `F3` contatore FPS · `Esc` indietro.

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
  scenarios/           5 scenari (476, 535, 568, 636, 711)
src/core/        LOGICA PURA, nessun nodo grafico → testabile in headless
  data/          lettura e validazione dei dati (GameDatabase)
  campaign/      stato della partita (CampaignState, FactionState)
  save/          salvataggi JSON con versione
src/settings/    preset grafici, profilo hardware, consiglio preset, statistiche FPS (logica pura)
src/game/        autoload: GameData, Settings, Session; percorsi delle scene
src/view/        SOLO GRAFICA: menu, schermata provvisoria di campagna, test prestazioni
scenes/          scene .tscn (radici con script)
assets/          font, shader, icona; CREDITS.md con le licenze
tests/           test GUT (unit e integrazione)
tools/           script per test ed export
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

## Licenze

Asset di terze parti e relative licenze: `assets/CREDITS.md`. Framework di test GUT: licenza MIT (`addons/gut/LICENSE.md`).
