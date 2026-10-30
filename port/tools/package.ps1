param([Parameter(Mandatory)][string]$Version, [Parameter(Mandatory)][string]$HashLink, [string]$Out = "port\out\release")
# Arma los zips de una version (como los de la v0.2): Windows con HashLink incluido (OpenGL y DirectX) y Linux/macOS.
# Uso (desde la raiz del repo, con port\out\galaxy55.hl y galaxy55_dx.hl ya compilados):
#   powershell -File port\tools\package.ps1 -Version 0.3 -HashLink <carpeta de hashlink-1.16.0-win>
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$out = Join-Path $root $Out
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
$win = Join-Path $out "galaxy55-offline"
$lin = Join-Path $out "galaxy55-offline-linux-mac"
New-Item -ItemType Directory -Force "$win\res", "$lin\res" | Out-Null

# recursos: graficos del cliente, mapa de estrellas, nave nodriza, contratos de la ESCorp y sonidos
$gfx = "src\G55\fla\client\gfx"
$res = @("digger.png", "door.md", "hud.png", "hud_jetpack.png", "icons.png", "lazer.png", "lazer2.png", "lazer3.png", "lazer4.png", "ship_halo.png", "texture.png", "mothership.bin", "contracts.json")
foreach ($d in $win, $lin) {
	foreach ($r in $res) { Copy-Item "$gfx\$r" "$d\res\$r" }
	Copy-Item "src\G55\fla\explore\gfx\tiles.png" "$d\res\explore_tiles.png"
	Get-ChildItem "src\G55\fla\client\sfx\*.wav" | ForEach-Object { Copy-Item $_.FullName "$d\res\sfx_$($_.Name)" }
	Copy-Item "port\out\galaxy55.hl", "LICENSE", "NOTICE" $d
}
# Windows: HashLink y sus librerias (sin las de compilar), y la version DirectX
# galaxy55.exe: copia de hl.exe con el icono del juego y sin consola (port\tools\galaxy55_exe.ps1); con su propio nombre
# Discord no lo toma por Half-Life
Copy-Item "port\out\galaxy55_dx.hl" $win
foreach ($f in "hl.exe", "libhl.dll", "fmt.hdll", "heaps.hdll", "openal.hdll", "OpenAL32.dll", "sdl.hdll", "SDL3.dll", "ui.hdll", "uv.hdll", "directx.hdll", "vcruntime140.dll") {
	Copy-Item (Join-Path $HashLink $f) $win
}
$utf8 = New-Object Text.UTF8Encoding $false
function Save([string]$path, [string]$text, [string]$nl) { [IO.File]::WriteAllText($path, ($text -replace "`r?`n", $nl), $utf8) }
& "$PSScriptRoot\galaxy55_exe.ps1" -Hl (Join-Path $HashLink "hl.exe") -Out "$win\galaxy55.exe" | Out-Null
foreach ($v in @(@("jugar.bat", "galaxy55.hl", "version OpenGL. Si no abre, usa jugar_dx.bat."), @("jugar_dx.bat", "galaxy55_dx.hl", "version DirectX (equipos sin OpenGL 3.2, maquinas virtuales)."))) {
	# galaxy55.exe sin consola; si falta, hl.exe con su consola (y pausa si hay error)
	Save "$win\$($v[0])" "@echo off`nrem Galaxy 55 (offline) v$Version - $($v[2])`ncd /d `"%~dp0`"`nif exist galaxy55.exe goto exe`nhl $($v[1]) %*`nif errorlevel 1 pause`nexit /b`n:exe`nstart `"`" galaxy55.exe $($v[1]) %*`n" "`r`n"
}
Save "$win\LEEME.txt" @"
GALAXY 55 (offline) v$Version - port nativo para Windows
=======================================================

Port NO oficial de Galaxy 55 (Motion Twin, 2012), sin Flash ni navegador. Version en desarrollo: tiene errores conocidos.
Licencia CC BY-NC-SA 4.0 (ver LICENSE y NOTICE). Codigo y novedades: https://github.com/Pv1E/galaxy55-offline

JUGAR: descomprime la carpeta ENTERA y haz doble clic en jugar.bat. No hace falta instalar nada.
Si no abre (equipos sin OpenGL 3.2, maquinas virtuales), usa jugar_dx.bat (version DirectX).
La carpeta "res" debe quedar junto a galaxy55.hl. Las partidas y los ajustes se guardan en %APPDATA%\Galaxy55\ .
El formato de las partidas puede cambiar entre versiones.

Controles (teclado y raton): W/Z/flechas mover, raton mirar, Espacio saltar y jetpack, X caminar despacio, H casco,
clic izquierdo/E/Mayus excavar, colocar o usar, 1-0 o rueda elegir casilla, Tab excavador, R tirar, Mayus+K volver a la nave,
I paleta (creativo), clic central copiar bloque (creativo), Esc pausa, F5 guardar.
Mando: stick izquierdo mover, stick derecho mirar, A saltar, gatillos excavar/colocar, LB/RB elegir casilla, Y tirar,
Back casco, Start pausa, R3 paleta y L3 copiar bloque (creativo). Cofres y tienda tambien con el mando.

---
English: unofficial native Windows port of Motion Twin's Galaxy 55 (2012). Unzip the whole folder and run jugar.bat
(OpenGL) or jugar_dx.bat (DirectX, for PCs without OpenGL 3.2 or virtual machines). Keep "res" next to galaxy55.hl.
Saves go to %APPDATA%\Galaxy55\ . Known bugs: BUGS.md in the repository.
"@ "`r`n"
# Linux / macOS: con HashLink del sistema
Save "$lin\jugar.sh" "#!/bin/sh`n# Abre Galaxy 55. Necesita HashLink (hl) instalado: ver LEEME.txt`ncd `"`$(dirname `"`$0`")`"`nexec hl galaxy55.hl `"`$@`"`n" "`n"
# los $ del ejemplo de shell del final van con ` para que salgan tal cual y PowerShell no los evalue
Save "$lin\LEEME.txt" @"
Galaxy 55 (offline) v$Version - Linux y macOS
=========================================
Port NO oficial de Galaxy 55 (Motion Twin, 2012). Licencia CC BY-NC-SA 4.0 (ver LICENSE y NOTICE).

IMPORTANTE: nosotros no la probamos en Linux ni en macOS. Sekhmet, un jugador del original, la usa en Linux
con HashLink. Si te funciona o te falla, cuentanoslo (issue en GitHub o Discord).

Como jugar
1. Instala HashLink 1.16 o mas nuevo para tu sistema:
     macOS (Homebrew):  brew install hashlink
     Linux:             compila o descarga HashLink desde https://github.com/HaxeFoundation/hashlink/releases
                        y que el comando "hl" funcione en una terminal.
2. Descomprime esta carpeta ENTERA. Debe verse la carpeta "res" junto a "galaxy55.hl".
3. En una terminal, dentro de esta carpeta:
     sh jugar.sh        (o:  hl galaxy55.hl)

Las partidas se guardan en la carpeta de datos de tu usuario; con la variable GALAXY55_DATA puedes elegir otra.
Controles y mas informacion: https://github.com/Pv1E/galaxy55-offline

---
English: NOT tested by us on Linux/macOS (a player uses it on Linux). Install HashLink 1.16+ so that "hl" works
(macOS: brew install hashlink), unzip everything keeping the "res" folder next to galaxy55.hl, then run
"sh jugar.sh" or "hl galaxy55.hl" from this folder. Tell us if it works or not.
If your HashLink is a pre-built folder and not installed: /your/path/to/hashlink/hl galaxy55.hl
If the unzipped files have names with backslashes (res\...), the zip was made on Windows with old tools: this package no
longer does that; with an old zip, rename them first (for example: for f in *\*; do mkdir -p "`$(dirname "`${f//\//}")"; mv "`$f" "`${f//\//}"; done).
(Thanks to Sekhmet for these steps.)
"@ "`n"

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zw = Join-Path $out "galaxy55-offline-v$Version.zip"
$zl = Join-Path $out "galaxy55-offline-v$Version-linux-mac.zip"
# CreateFromDirectory de Windows PowerShell 5.1 guarda las rutas con \ y en Linux/macOS salen archivos con ese nombre: aqui se escriben con /
function New-Zip($dir, $zip) {
    if (Test-Path $zip) { [IO.File]::Delete($zip) }
    $root = (Resolve-Path $dir).Path.TrimEnd("\") + "\"
    $za = [IO.Compression.ZipFile]::Open($zip, "Create")
    try {
        foreach ($f in Get-ChildItem $dir -Recurse -File) {
            $name = $f.FullName.Substring($root.Length).Replace("\", "/")
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($za, $f.FullName, $name, "Optimal")
        }
    } finally { $za.Dispose() }
}
New-Zip $win $zw
New-Zip $lin $zl
Get-Item $zw, $zl | ForEach-Object { "{0}  {1:N0} bytes" -f $_.Name, $_.Length }
