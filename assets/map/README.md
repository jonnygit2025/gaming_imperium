# Mappa di campagna — file generati

Tutti i file di questa cartella sono **generati offline** da `tools/map/` partendo da Natural Earth
(pubblico dominio). Il gioco li carica già pronti: all'avvio non calcola nulla.

Per rigenerarli: `tools/map/build_map.sh` (serve Python 3 con numpy, scipy e pillow, e Godot 4.7.2).
Solo i dettagli (strade, campi, alberi, villaggi, porti): `python3 tools/map/generate_details.py`.

| File | Contenuto | Uso |
|---|---|---|
| `province_ids.png` | 2048×1509. R = provincia (1..47 in ordine di `provinces.json`, 0 = mare, 255 = terre esterne), G = provincia oltre il confine più vicino, B = 255 sulla terra | shader del terreno e minimappa (filtro *nearest*) |
| `province_fields.png` | R = distanza dal confine di provincia (texel × 15,9), G = distanza con segno dalla costa (128 ± texel × 6), B = laghi | linee dei confini e della costa nette a ogni zoom (filtro lineare) |
| `terrain_albedo.png` | colori del terreno: biomi, foreste, deserti, fiumi, laghi e ombreggiatura del rilievo | shader del terreno (compressa in VRAM) |
| `minimap_base.png` | 512 px, sfondo della minimappa | minimappa |
| `water_noise.png` | 256 px ripetibile, due rumori per le onde | shader del mare |
| `terrain_mesh.res` | mesh low-poly del terreno (triangolazione di Delaunay adattiva, ~310.000 triangoli) | terreno |
| `heights.res` | quote 1024×754 (Image RF) | telecamera, selezione col mouse, posizione di città ed eserciti |
| `details.png` | R = distanza dalla strada più vicina (texel × 16), G = campi coltivati | campi nello shader del terreno, posizione degli alberi (filtro lineare) |
| `roads.png` | RG = punto della strada più vicina (scarto dal centro del texel), B = direzione del tratto, A = vicino a una strada | strade nette a ogni zoom nello shader del terreno (filtro *nearest*) |
| `trees.bin` | ~220.000 alberi (x, y, z, scala, rotazione, tipo) a blocchi di 12×12 unità | `DetailLayer`: MultiMesh costruiti solo vicino alla telecamera |
| `province_lookup.res` | mappa degli id per la CPU (Image RG8: provincia, terra) | selezione col mouse, test |

Le posizioni di città ed etichette, la proiezione e i limiti del mondo sono in
`data/map/campaign_map.json`. Stili delle città, strade, villaggi minori, porti e indice dei blocchi
di alberi sono in `data/map/campaign_details.json` (generati da `tools/map/generate_details.py`).

**Dettagli** (come nelle mappe di campagna dei grandi strategici, appaiono avvicinandosi):
- *strade*: percorso di costo minimo fra le città confinanti (pendenza, quota e deserto costano;
  un secondo giro fa confluire i percorsi vicini in una rete); niente strade sugli stretti;
- *campi*: attorno alle città (raggio secondo popolazione e fertilità), ai villaggi e lungo le
  strade vicino alle città; disegnati dallo shader a strisce orientate per provincia;
- *alberi*: stessa maschera dei boschi della texture dei colori (stesso rumore), conifere a nord e
  in quota, pini domestici nel Mediterraneo, latifoglie altrove (spoglie d'inverno);
- *villaggi minori*: 1-3 per provincia, lontani dalla città e fra loro; *porti*: punto di costa
  più vicino alle città costiere (entro 3,7 unità).

**Proiezione**: equirettangolare corretta per la latitudine media (38°N), centrata su 19°E;
1 unità di gioco = 10 km; il rilievo è esagerato 10 volte (1 km di quota = 1 unità).

**Province**: diagramma di Voronoi "geodetico" sulle coordinate delle città, ritagliato sulla
terraferma; attraversare le montagne costa di più (i confini seguono le catene); due province
non confinanti in `provinces.json` non possono toccarsi (il terreno conteso va a una terza
provincia confinante con entrambe, oppure resta "terre esterne"); alcuni semi secondari storici
(es. Corsica per la Sardegna, Naissus e Singidunum per la Mesia) avvicinano le forme alla
geografia dell'epoca. Il test `tests/unit/test_campaign_map_data.gd` verifica che la mappa e i
confini del JSON coincidano.
