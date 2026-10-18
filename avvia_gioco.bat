@echo off
cd /d "%~dp0"
if not exist .venv (
    echo Prima esegui setup_windows.bat
    pause
    exit /b 1
)
call .venv\Scripts\activate.bat
python -m game
if errorlevel 1 pause
