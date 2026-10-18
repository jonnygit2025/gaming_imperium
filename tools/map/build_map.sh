#!/usr/bin/env bash
# Rigenera tutta la mappa di campagna: dati Natural Earth -> texture, mesh e metadati.
# Requisiti: python3 con numpy, scipy e pillow; Godot 4.7.2 (variabile GODOT).
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
tools/map/fetch_natural_earth.sh
python3 tools/map/generate_map.py "$@"
"$GODOT" --headless --import > /dev/null 2>&1 || true
"$GODOT" --headless -s tools/map/build_map_resources.gd
echo "Mappa rigenerata."
