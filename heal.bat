@echo off
if "%1"=="minimized" goto run
start /min "" "%~f0" minimized
exit

:run
cd /d "%~dp0"
call .venv\Scripts\activate.bat
python heal.py
exit

