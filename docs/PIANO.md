# Piano di sviluppo

Concordato il 18/10/2026. PC di riferimento: Windows 10, Intel i5-4440 (4 core), 16 GB RAM,
NVIDIA GeForce GTX 650 (2 GB). Il prompt originale è in `docs/PROMPT_GIOCO.md`.

## Decisioni rispetto al prompt originale

- **8 fasi** invece di 6: la 4 e la 5 sono divise in due.
- **2 turni all'anno** (estate e inverno) invece di 4; ogni scenario ha una data di fine.
- **47 province**: aggiunte Pannonia (Avari), Mesopotamia/Asoristan (Sasanidi) e Hijaz (Califfato).
- **Trasporto via mare** da porto a porto, niente battaglie navali.
- **Assedi semplificati**: mura, porta da sfondare con l'ariete, arcieri sulle mura.
- **Animazioni** dei soldati via shader (MultiMesh non supporta gli scheletri).
- **IA nemica in battaglia** aggiunta (mancava nel prompt).
- **Generali** con invecchiamento, morte e successione semplici.
- **GTX 650**: preset Basso e renderer Compatibilità consigliati; il test prestazioni verifica sul campo.

## Fasi

1. **Base e menu** — progetto, dati JSON, menu, scelta scenario/fazione, opzioni grafiche con
   rilevamento automatico, test prestazioni, test GUT, primo .exe. ✅
2. **Mappa di campagna 3D** — province selezionabili, confini colorati, città ed eserciti, telecamera,
   risorse, fine turno. ✅ (entrate provvisorie, eserciti fermi; simulazione headless di 200 turni)
3. **Economia e costruzione** — tasse, popolazione, ordine pubblico, edifici con slot, livelli e coda.
4a. **Eserciti** — reclutamento, generali, movimento, trasporto via mare, assedi, risoluzione automatica.
4b. **Mondo vivo** — diplomazia, IA delle fazioni, eventi storici, vittoria, salvataggi completi,
   simulazione headless di 200 turni.
5a. **Scena di battaglia** — terreno, schieramento, reggimenti MultiMesh, selezione e ordini,
   telecamera, minimappa.
5b. **Combattimento** — morale, stanchezza, munizioni, fianchi, IA di battaglia, assedi, ritorno in campagna.
6. **Rifinitura** — effetti, suoni e musica liberi, tutorial, bilanciamento, export finale.
