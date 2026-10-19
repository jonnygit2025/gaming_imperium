@echo off
REM Se ci sono i pezzi di una nuova versione, ricompone Regna.exe controllandone
REM l'integrita' (SHA-256); poi avvia il gioco.
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
    if exist Regna.sha256 (
        powershell -NoProfile -Command "$l=Get-Content 'Regna.sha256'; $z=($l | Where-Object {$_ -like '*Regna.zip'}).Split(' ')[0]; if ((Get-FileHash 'Regna.zip' -Algorithm SHA256).Hash -ne $z.ToUpper()) { exit 1 }"
        if errorlevel 1 (
            del Regna.zip
            echo.
            echo I pezzi Regna.zip.part* sono danneggiati: vanno copiati di nuovo.
            echo Non li ho cancellati, cosi' puoi controllarli.
            pause
            exit /b 1
        )
    )
    powershell -NoProfile -Command "Expand-Archive -Force -LiteralPath 'Regna.zip' -DestinationPath '.'"
    if errorlevel 1 (
        echo Qualcosa e' andato storto durante l'estrazione.
        pause
        exit /b 1
    )
    if exist Regna.sha256 (
        powershell -NoProfile -Command "$l=Get-Content 'Regna.sha256'; $e=($l | Where-Object {$_ -like '*Regna.exe'}).Split(' ')[0]; if ((Get-FileHash 'Regna.exe' -Algorithm SHA256).Hash -ne $e.ToUpper()) { exit 1 }"
        if errorlevel 1 (
            echo.
            echo Regna.exe estratto non e' integro: copia di nuovo i pezzi.
            pause
            exit /b 1
        )
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
