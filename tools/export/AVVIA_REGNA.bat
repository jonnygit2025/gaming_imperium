@echo off
REM Se ci sono i pezzi di una nuova versione, ricompone Regna.exe; poi avvia il gioco.
cd /d "%~dp0"
if exist Regna.zip.part0 (
    echo Preparo la nuova versione del gioco, un attimo...
    if exist Regna.zip del Regna.zip
    for /L %%i in (0,1,20) do (
        if exist Regna.zip.part%%i (
            if exist Regna.zip (
                copy /b Regna.zip + Regna.zip.part%%i Regna.zip.tmp >nul
                move /y Regna.zip.tmp Regna.zip >nul
            ) else (
                copy /b Regna.zip.part%%i Regna.zip >nul
            )
        )
    )
    powershell -NoProfile -Command "Expand-Archive -Force -LiteralPath 'Regna.zip' -DestinationPath '.'"
    if errorlevel 1 (
        echo Qualcosa e' andato storto durante l'estrazione.
        pause
        exit /b 1
    )
    del Regna.zip
    for /L %%i in (0,1,20) do if exist Regna.zip.part%%i del Regna.zip.part%%i
)
if not exist Regna.exe (
    echo Regna.exe non trovato.
    pause
    exit /b 1
)
start "" Regna.exe
