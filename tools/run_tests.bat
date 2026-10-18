@echo off
REM Esegue i test automatici GUT in modalita' headless.
REM Imposta GODOT con il percorso di Godot 4.7.2, per esempio:
REM   set GODOT=C:\Godot\Godot_v4.7.2-stable_win64_console.exe
cd /d "%~dp0\.."
if "%GODOT%"=="" set GODOT=godot
"%GODOT%" --headless --import >nul 2>&1
"%GODOT%" --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
pause
