# Imperium – remake

Gioco di strategia in tempo reale sull'Italia antica, ispirato ai giochi della serie *Imperium*,
scritto da zero in **Python 3.12 + pygame-ce** e pensato per girare bene anche su PC datati.

## Installazione (Windows)

1. Doppio clic su **`setup_windows.bat`**
   - se manca Python 3.12 lo installa con `winget` (poi rilancia il file),
   - crea l'ambiente `.venv`, installa le librerie, verifica il PC.
2. Doppio clic su **`avvia_gioco.bat`**

Solo verifica risorse del PC: `python tools\check_pc.py`

Forzare un profilo grafico: `python -m game basso` (oppure `medio`, `alto`).

## Comandi

| Azione | Comando |
|---|---|
| Seleziona una tua città | clic sinistro |
| Recluta 10 soldati (50 oro) | `R` |
| Invia metà delle truppe a una città vicina | clic destro sulla città |
| Pausa / velocità | `SPAZIO`, `+` / `-` |
| Esci | `ESC` |

Obiettivo: conquistare tutte le 16 città. Le città rendono oro ogni giorno, i soldati costano mantenimento.

## Struttura

```
game/
  config.py   impostazioni e profili grafici (basso/medio/alto) scelti in base a CPU/RAM
  world.py    logica pura: città, fazioni, economia, battaglie, IA (nessuna grafica, testabile)
  app.py      finestra, disegno e input (pygame-ce)
tools/
  check_pc.py verifica CPU, core, RAM, GPU, disco, Python
```

## Scelte per PC vecchi

- 2D, nessun motore 3D: basta una qualsiasi scheda video integrata.
- FPS limitati (30/45/60 secondo il profilo): la CPU non gira al 100%.
- Sfondo e strade disegnati una sola volta e riusati a ogni frame; testi fissi in cache.
- Logica separata dalla grafica: in futuro si può cambiare grafica senza riscrivere il gioco.

## Perché da zero e non con il reverse engineering

Decompilare o estrarre codice e grafica dal gioco originale violerebbe copyright e licenza
d'uso, e il codice ottenuto sarebbe comunque difficile da modificare. Le **meccaniche** di gioco
(città, risorse, eserciti, conquista) invece si possono reimplementare liberamente: è quello
che fa questo progetto, con nomi, grafica e codice propri.

## Prossimi passi possibili

- Risorse multiple (cibo, legno, ferro) e edifici nelle città
- Tipi di unità (fanteria, arcieri, cavalleria) con vantaggi reciproci
- Mappa con terreno e province, salvataggio/caricamento
- Battaglie tattiche su mappa separata
