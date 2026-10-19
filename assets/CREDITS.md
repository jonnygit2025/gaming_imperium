# Crediti e licenze degli asset

Solo asset con licenza libera (CC0, CC-BY, OFL, MIT). Nessun file, nome o grafica presi da giochi commerciali.

| Asset | Autore | Licenza | File |
|---|---|---|---|
| Font **Cinzel** (titoli) | Natanael Gama | SIL Open Font License 1.1 | `fonts/Cinzel-Variable.ttf`, licenza in `fonts/Cinzel-OFL.txt` |
| Font **Alegreya Sans** (testi) | Juan Pablo del Peral, Huerta Tipográfica | SIL Open Font License 1.1 | `fonts/AlegreyaSans-*.ttf`, licenza in `fonts/AlegreyaSans-OFL.txt` |
| Icona, shader, modelli low-poly dei soldati e degli alberi | creati per questo progetto | come il codice del gioco | `ui/icon.svg`, `shaders/`, generati in `src/view/common/low_poly_builder.gd` |
| Modelli low-poly di città ed eserciti della campagna | creati per questo progetto | come il codice del gioco | generati in `src/view/campaign_map/campaign_models.gd` |
| **Mappa di campagna** (coste, laghi, fiumi, catene montuose, deserti, vette) | [Natural Earth](https://www.naturalearthdata.com/) 5.2 – Tom Patterson, Nathaniel Vaughn Kelso e contributori, dal repository [nvkelso/natural-earth-vector](https://github.com/nvkelso/natural-earth-vector) | **Pubblico dominio** | `map/*` generati da `tools/map/` con `ne_50m_land`, `ne_50m_lakes`, `ne_50m_rivers_lake_centerlines`, `ne_10m_geography_regions_polys`, `ne_10m_geography_regions_elevation_points`; vedi `map/README.md` |

Strumenti (non inclusi nel gioco esportato):

| Strumento | Autore | Licenza |
|---|---|---|
| Godot Engine 4.7.2 | Juan Linietsky, Ariel Manzur e contributori | MIT |
| GUT – Godot Unit Test 9.7.1 | Tom "bitwes" Butler e contributori | MIT (`addons/gut/LICENSE.md`) |
| NumPy, SciPy, Pillow (generazione della mappa, `tools/map/`) | rispettivi autori | BSD / HPND |

Quando verranno aggiunti modelli, texture, suoni o musica (fasi 5–6), ogni file sarà elencato qui
con autore, licenza e link alla fonte (es. Kenney, Quaternius, Poly Haven: CC0).
