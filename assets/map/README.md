# Mappa di campagna — file generati

Tutti i file di questa cartella sono **generati offline** da `tools/map/` partendo da Natural Earth
(pubblico dominio). Il gioco li carica già pronti: all'avvio non calcola nulla.

Per rigenerarli: `tools/map/build_map.sh` (serve Python 3 con numpy, scipy e pillow, e Godot 4.7.2).

| File | Contenuto | Uso |
|---|---|---|
| `province_ids.png` | 2048×1509. R = provincia (1..47 in ordine di `provinces.json`, 0 = mare, 255 = terre esterne), G = provincia oltre il confine più vicino, B = 255 sulla terra | shader del terreno e minimappa (filtro *nearest*) |
| `province_fields.png` | R = distanza dal confine di provincia (texel × 15,9), G = distanza con segno dalla costa (128 ± texel × 6), B = laghi | linee dei confini e della costa nette a ogni zoom (filtro lineare) |
| `terrain_albedo.png` | colori del terreno: biomi, foreste, deserti, fiumi, laghi e ombreggiatura del rilievo | shader del terreno (compressa in VRAM) |
| `minimap_base.png` | 512 px, sfondo della minimappa | minimappa |
| `water_noise.png` | 256 px ripetibile, due rumori per le onde | shader del mare |
| `terrain_mesh.res` | mesh low-poly del terreno (triangolazione di Delaunay adattiva, ~310.000 triangoli) | terreno |
| `heights.res` | quote 1024×754 (Image RF) | telecamera, selezione col mouse, posizione di città ed eserciti |
| `province_lookup.res` | mappa degli id per la CPU (Image RG8: provincia, terra) | selezione col mouse, test |

Le posizioni di città ed etichette, la proiezione e i limiti del mondo sono in
`data/map/campaign_map.json`.

**Proiezione**: equirettangolare corretta per la latitudine media (38°N), centrata su 19°E;
1 unità di gioco = 10 km; il rilievo è esagerato 10 volte (1 km di quota = 1 unità).

**Province**: diagramma di Voronoi "geodetico" sulle coordinate delle città, ritagliato sulla
terraferma; attraversare le montagne costa di più (i confini seguono le catene); due province
non confinanti in `provinces.json` non possono toccarsi (il terreno conteso va a una terza
provincia confinante con entrambe, oppure resta "terre esterne"); alcuni semi secondari storici
(es. Corsica per la Sardegna, Naissus e Singidunum per la Mesia) avvicinano le forme alla
geografia dell'epoca. Il test `tests/unit/test_campaign_map_data.gd` verifica che la mappa e i
confini del JSON coincidano.
