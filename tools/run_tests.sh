#!/usr/bin/env bash
# Esegue tutti i test GUT in modalità headless e fallisce se nel log compaiono
# errori o warning del motore o degli script del gioco.
# Uso: tools/run_tests.sh   (variabile GODOT per indicare l'eseguibile)
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"

# L'importazione compila tutti gli script: anche i suoi errori contano.
"$GODOT" --headless --import > "$LOG" 2>&1
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json 2>&1 | tee -a "$LOG"
status=${PIPESTATUS[0]}

# Righe sospette nel log: errori del motore, errori di script, warning di GDScript.
problems="$(grep -nE '^(ERROR|SCRIPT ERROR|WARNING|USER ERROR|USER WARNING):|Parse Error|Invalid call' "$LOG" | grep -v 'addons/gut' || true)"
rm -f "$LOG"
if [ -n "$problems" ]; then
	echo
	echo "=== PROBLEMI NEL LOG ==="
	echo "$problems"
	exit 1
fi
exit $status
