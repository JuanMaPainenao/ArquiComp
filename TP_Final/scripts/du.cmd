@echo off
rem du.cmd - Lanza du.ps1 desde cmd.exe (cmd no ejecuta .ps1 directamente)
rem Uso: scripts\du [comando] [args]   ej: scripts\du   /   scripts\du file programs\pipeline.hex
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0du.ps1" %*
