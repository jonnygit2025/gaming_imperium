# Prompt per sviluppare "Regna – L'Ombra di Roma (476–732 d.C.)"

Come usarlo: incolla **il PROMPT PRINCIPALE** una sola volta all'inizio di una nuova sessione.
Poi incolla **una fase alla volta** e passa alla successiva solo quando hai provato il gioco sul
tuo PC e la fase funziona. Un'unica richiesta gigante produce un gioco pieno di bug: a fasi no.

---

## PROMPT PRINCIPALE (contesto, da incollare per primo)

```
Lavora nella repo jonnygit2025/gaming_imperium. Sostituisci il prototipo pygame attuale con un
nuovo gioco sviluppato con Godot 4 (ultima versione stabile, linguaggio GDScript tipizzato).
Sposta il vecchio prototipo in /legacy.

IL GIOCO
Strategia in stile Total War: una campagna a turni su mappa 3D e battaglie in tempo reale in 3D.
Periodo: dalla caduta dell'Impero d'Occidente (476) alla battaglia di Poitiers (732).
Mappa: Mediterraneo ed Europa occidentale (Italia, Gallia, Hispania, Nord Africa, Balcani,
Anatolia, Levante, Egitto), divisa in circa 40 province, ognuna con una città capoluogo.

Scenari di partenza selezionabili:
1. 476 – Caduta di Roma: Odoacre, Impero d'Oriente, Visigoti, Franchi, Vandali, Ostrogoti.
2. 535 – Guerra greco-gotica: Bizantini (Belisario) contro Ostrogoti per l'Italia.
3. 568 – Invasione longobarda: Longobardi, Bizantini, Franchi, Avari.
4. 636 – Espansione islamica: Califfato, Bizantini (Yarmuk), Sasanidi.
5. 711–732 – Hispania e Poitiers: Omayyadi, Visigoti, Franchi (Carlo Martello), Aquitania.
Il giocatore sceglie scenario e fazione; le altre sono gestite dall'IA.

CAMPAGNA (a turni, 1 turno = 1 stagione)
- Risorse: oro, cibo, legname, ferro, uomini (popolazione arruolabile), fede/ordine pubblico.
- Costruzione in ogni città su slot: case/quartieri (popolazione e tasse), fattorie, mercati,
  caserme, scuderie, arcerie, fabbri, mura (3 livelli), chiese o moschee, porti.
  Ogni edificio ha costo, tempo di costruzione, livelli e requisiti.
- Reclutamento di eserciti guidati da generali (max 20 unità per esercito), mantenimento per turno.
- Movimento degli eserciti sulla mappa con punti movimento, assedi, battaglie, occupazione o saccheggio.
- Diplomazia semplice: pace, guerra, alleanza, tributo, con relazioni numeriche.
- Eventi storici agli anni giusti (es. arrivo di Belisario, morte di Teodorico, Yarmuk, Poitiers).
- Condizioni di vittoria per ogni fazione. Salvataggio e caricamento della partita.

BATTAGLIE 3D (tempo reale, si aprono quando due eserciti si scontrano)
- Terreno 3D generato dalla provincia (pianura, colline, bosco, fiume, mura per gli assedi).
- Fase di schieramento, poi battaglia. Selezione di unità col mouse (clic, trascinamento,
  gruppi Ctrl+1..9), ordini di movimento, attacco, formazione, carica, ritirata.
- Ogni unità è un reggimento di 40–120 soldati 3D in formazione.
- Combattimento: attacco, difesa, carica, morale, stanchezza, munizioni per arcieri,
  bonus di fianco e retro, bonus di terreno; le unità con morale a zero fuggono.
- Unità per cultura: legionari tardo-romani, catafratti e skutatoi bizantini, fanteria e
  cavalleria gotica, guerrieri franchi con francisca, cavalleria longobarda, cavalieri
  e arcieri a cavallo arabi, fanteria berbera, arcieri. Ognuna con statistiche proprie.
- Telecamera libera stile Total War (WASD, rotazione, zoom), minimappa, barra delle unità.
- Opzione "risoluzione automatica" della battaglia per chi non vuole combatterla.
- Il risultato della battaglia aggiorna l'esercito nella campagna.

GRAFICA E PRESTAZIONI
- Stile low-poly curato e coerente, con illuminazione, ombre, acqua, nebbia e cielo.
- Solo asset liberi (licenza CC0 o CC-BY, es. Kenney, Quaternius, Poly Haven), elencati con la
  licenza in /assets/CREDITS.md. Nessun file, nome o grafica presi da giochi commerciali.
- I soldati vanno disegnati con MultiMeshInstance3D (o istanziazione equivalente) per gestire
  almeno 2.000 soldati in battaglia a 60 FPS su una GPU di fascia media; LOD per la distanza.
- Menu "Opzioni grafiche" con preset Basso/Medio/Alto/Ultra (ombre, distanza di vista, numero di
  soldati per unità, antialiasing, risoluzione) e rilevamento automatico al primo avvio.
- Deve funzionare su Windows 10/11 x64. Renderer Forward+ con fallback al renderer Compatibility.

QUALITÀ (obbligatoria in ogni fase)
- Architettura: la logica (dati, regole, IA) separata dalla grafica, in script senza nodi visivi,
  così è testabile. Dati di unità, edifici, fazioni, province e scenari in file JSON/Resource.
- Test automatici con GUT eseguiti in modalità headless (godot --headless) per economia,
  costruzione, reclutamento, combattimento, IA, salvataggio/caricamento.
- Prima di dichiarare finita una fase: esegui tutti i test, avvia il gioco in headless per
  almeno 200 turni simulati con sole IA senza errori né warning nel log, e correggi ogni problema.
- Ogni fase si chiude con: commit su un branch, pull request con descrizione, elenco di cosa
  provare a mano sul PC, e un export Windows (.exe) funzionante se l'ambiente lo permette;
  altrimenti istruzioni passo passo per esportarlo da Godot sul mio PC.
- Interfaccia e testi in italiano.

Non iniziare a scrivere codice: per ora conferma di aver capito, proponi la struttura delle
cartelle e la lista delle fasi, e segnalami qualunque punto irrealistico o da semplificare.
```

---

## FASI (incollane una alla volta)

**Fase 1 – Base e menu**
```
Fase 1: crea il progetto Godot, la struttura delle cartelle, il sistema dati (fazioni, province,
unità, edifici in JSON), il menu principale (Nuova partita, Carica, Opzioni, Esci), la scelta di
scenario e fazione, il menu Opzioni grafiche con rilevamento automatico. Test GUT funzionanti.
```

**Fase 2 – Mappa di campagna 3D**
```
Fase 2: mappa di campagna 3D del Mediterraneo con province selezionabili, confini colorati per
fazione, città e eserciti visibili, telecamera, interfaccia delle risorse, fine turno.
```

**Fase 3 – Economia e costruzione**
```
Fase 3: risorse, tasse, popolazione, ordine pubblico, costruzione degli edifici con slot,
livelli e coda di costruzione, pannello città completo. Test per ogni regola economica.
```

**Fase 4 – Eserciti e IA di campagna**
```
Fase 4: reclutamento, generali, movimento sulla mappa, assedi, risoluzione automatica delle
battaglie, diplomazia, IA delle fazioni, eventi storici, vittoria/sconfitta, salvataggi.
Simulazione headless di 200 turni con sole IA senza errori.
```

**Fase 5 – Battaglie 3D**
```
Fase 5: scena di battaglia 3D: terreno, schieramento, reggimenti in formazione con MultiMesh,
selezione e ordini, combattimento con morale e stanchezza, telecamera, minimappa, fine battaglia
con ritorno alla campagna. Obiettivo: 2.000 soldati a 60 FPS sul preset Alto.
```

**Fase 6 – Rifinitura e impatto**
```
Fase 6: effetti (polvere, sangue disattivabile, frecce, fuoco negli assedi), animazioni, suoni e
musica liberi, schermate di caricamento storiche, tutorial, bilanciamento delle fazioni,
correzione di tutti i bug noti, export Windows finale.
```

---

## Dopo ogni fase, sul tuo PC
1. Prova il gioco seguendo l'elenco "cosa provare" della pull request.
2. Se trovi bug, descrivili così: *cosa ho fatto → cosa mi aspettavo → cosa è successo* (+ screenshot).
3. Solo quando funziona, unisci la pull request e passa alla fase successiva.
