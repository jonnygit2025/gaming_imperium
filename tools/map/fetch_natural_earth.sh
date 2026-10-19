#!/usr/bin/env bash
# Scarica SOLO i file di Natural Earth (pubblico dominio) che servono a generare la mappa,
# con un clone parziale di GitHub (niente storia, niente file inutili).
# Uso: tools/map/fetch_natural_earth.sh
set -euo pipefail
cd "$(dirname "$0")"
DEST="_cache/natural-earth-vector"
FILES=(
	/geojson/ne_50m_land.geojson
	/geojson/ne_50m_lakes.geojson
	/geojson/ne_50m_rivers_lake_centerlines.geojson
	/geojson/ne_10m_geography_regions_polys.geojson
	/geojson/ne_10m_geography_regions_elevation_points.geojson
	/LICENSE.md
	/VERSION
)
if [ ! -d "$DEST/.git" ]; then
	mkdir -p _cache
	git clone --depth 1 --filter=blob:none --sparse https://github.com/nvkelso/natural-earth-vector.git "$DEST"
fi
git -C "$DEST" sparse-checkout set --no-cone "${FILES[@]}"
echo "Natural Earth $(cat "$DEST/VERSION") pronto in tools/map/$DEST"
