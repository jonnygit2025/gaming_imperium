# Regna – indicazioni per Claude

- **Branch**: lavora sempre e soltanto sul branch `claude` (niente branch nuovi per ogni fase).
  Prima di iniziare allinealo a `main`; le pull request vanno da `claude` a `main`.
- Interfaccia, testi, commenti e messaggi di commit in italiano.
- PC di riferimento: GTX 650 (2 GB), renderer Compatibilità, 1600×900. Ogni novità grafica va misurata
  (`tools/capture/perf_ab.tscn` nel cloud, test prestazioni in Opzioni sul PC) e controllata con
  screenshot reali (`tools/capture/capture_campaign.tscn`).
- Logica in `src/core` senza nodi, grafica in `src/view`, dati in `data/`; warning di GDScript = errori.
- Prima di consegnare: `tools/run_tests.sh` e `tools/simulate_campaign.sh` con log pulito.
- Consegna sul PC: export Windows, zip diviso in pezzi da 20 MB con `Regna.sha256`, copiato in
  `C:\Users\utente\Desktop\gioco_imperium\Regna_FaseN` con `AVVIA_REGNA.bat` e `LEGGIMI.txt`;
  dopo la copia rileggere i pezzi e verificarne l'impronta.
