#!/usr/bin/env bash
# Simula 200 turni per ogni scenario in headless e fallisce se nel log compaiono errori o warning.
# Uso: tools/simulate_campaign.sh [turni]   (variabile GODOT per indicare l'eseguibile)
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
"$GODOT" --headless --import > /dev/null 2>&1
"$GODOT" --headless -s tools/simulate_campaign.gd -- --turni="${1:-200}" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
problems="$(grep -nE '^(ERROR|SCRIPT ERROR|WARNING|USER ERROR|USER WARNING):|Parse Error' "$LOG" || true)"
rm -f "$LOG"
if [ -n "$problems" ]; then
	echo
	echo "=== PROBLEMI NEL LOG ==="
	echo "$problems"
	exit 1
fi
exit $status
