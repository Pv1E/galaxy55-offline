@echo off
rem Galaxy 55 (offline) - port nativo, version DirectX (para equipos sin OpenGL 3.2, como maquinas virtuales).
rem Requiere compilar antes con:  haxe port\game_dx.hxml
cd /d "%~dp0.."
if defined HL set "PATH=%HL%;%PATH%"
where hl >nul 2>nul
if not errorlevel 1 goto found
if exist "..\tools-portable\hashlink\hl.exe" set "PATH=%CD%\..\tools-portable\hashlink;%PATH%"
for /d %%D in ("..\tools-portable\hashlink\*") do set "PATH=%%~fD;%PATH%"
where hl >nul 2>nul
if not errorlevel 1 goto found
echo No encuentro hl.exe. Pon HashLink en el PATH o define la variable HL con su carpeta.
pause
exit /b 1
:found
if exist port\out\galaxy55_dx.hl goto run
echo Falta port\out\galaxy55_dx.hl: compila primero con  haxe port\game_dx.hxml
pause
exit /b 1
:run
rem galaxy55.exe = hl.exe con el icono del juego y sin consola (port\tools\galaxy55_exe.ps1); con su propio nombre Discord
rem no lo toma por Half-Life. Se crea la primera vez (borralo si cambias de HashLink). Si no se puede: hlw.exe o hl.exe.
if not exist port\out\galaxy55.exe for /f "delims=" %%H in ('where hl') do if not exist port\out\galaxy55.exe powershell -NoProfile -ExecutionPolicy Bypass -File port\tools\galaxy55_exe.ps1 -Hl "%%H" -Out port\out\galaxy55.exe >nul 2>nul
if exist port\out\galaxy55.exe (start "" port\out\galaxy55.exe port\out\galaxy55_dx.hl %* & exit /b 0)
rem hlw.exe = hl.exe en modo ventana (sin la consola negra vacia), si esta junto a hl; si no, hl con su consola
where hlw >nul 2>nul && (start "" hlw port\out\galaxy55_dx.hl %* & exit /b 0)
start "" hl port\out\galaxy55_dx.hl %*