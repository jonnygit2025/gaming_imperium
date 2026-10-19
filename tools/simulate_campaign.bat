@echo off
REM Simula 200 turni per ogni scenario in modalita' headless.
REM Imposta GODOT con il percorso di Godot 4.7.2 (versione console).
cd /d "%~dp0\.."
if "%GODOT%"=="" set GODOT=godot
"%GODOT%" --headless --import >nul 2>&1
"%GODOT%" --headless -s tools/simulate_campaign.gd -- --turni=200
pause
