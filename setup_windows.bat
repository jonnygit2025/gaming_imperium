@echo off
REM ============================================================
REM  Installazione automatica per Imperium (remake) su Windows
REM  Doppio clic su questo file: installa Python 3.12 (se manca),
REM  crea l'ambiente virtuale, installa le librerie e verifica il PC.
REM ============================================================
cd /d "%~dp0"

where py >nul 2>nul
if errorlevel 1 (
    echo Python non trovato: lo installo con winget...
    winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
    if errorlevel 1 (
        echo.
        echo winget non disponibile. Scarica Python 3.12 da https://www.python.org/downloads/
        echo e durante l'installazione spunta "Add python.exe to PATH". Poi rilancia questo file.
        pause
        exit /b 1
    )
    echo Python installato. Chiudi questa finestra e rilancia setup_windows.bat.
    pause
    exit /b 0
)

if not exist .venv (
    echo Creo l'ambiente virtuale .venv ...
    py -3.12 -m venv .venv 2>nul || py -3 -m venv .venv
)

call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

echo.
python tools\check_pc.py
echo.
echo Tutto pronto. Per giocare: doppio clic su avvia_gioco.bat
pause
