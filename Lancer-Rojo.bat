@echo off
cd /d "%~dp0"
git pull
"%USERPROFILE%\Downloads\rojo-7.7.0-windows-x86_64\rojo.exe" serve
pause
