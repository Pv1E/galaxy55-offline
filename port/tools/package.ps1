param([Parameter(Mandatory)][string]$Version, [Parameter(Mandatory)][string]$HashLink, [string]$LinuxHashLink = "", [string]$Hlc = "port\out\hlc.zip", [string]$Out = "port\out\release")
# Arma los zips de una version (como los de la v0.2): Windows con HashLink incluido (OpenGL y DirectX), Linux y macOS.
# Uso (desde la raiz del repo, con port\out\galaxy55.hl, galaxy55_dx.hl y server.hl ya compilados):
#   powershell -File port\tools\package.ps1 -Version 0.3 -HashLink <carpeta de hashlink-1.16.0-win> [-LinuxHashLink <carpeta>]
# -LinuxHashLink: HashLink para Linux x86-64 hecho con port/tools/build-hl-linux.sh (hl, libhl.so, los hdll y SDL3); va en la
# carpeta hashlink del zip de Linux, que asi funciona sin instalar nada. Sin el, el zip de Linux usa el hl del sistema.
# -Hlc: el codigo C del juego y del servidor para macOS, hecho en Linux con port/tools/build-hlc-sources.sh (en Windows un
# archivo pisaria a otro); sus entradas pasan tal cual al zip de macOS. Sin el, no se hace el zip de macOS.
# Compilar con HAXE_STD_PATH relativo (..\tools-portable\haxe\std): si no, los .hl llevan la ruta absoluta de la libreria
# estandar de Haxe en este PC (con el nombre de usuario).
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$out = Join-Path $root $Out
if (Test-Path $out) {
	# la carpeta se vacia: no si alguien juega o tiene un servidor abierto desde ella (borraba res\ y los datos del servidor
	# a medias, con monde.sqlite en uso), ni si guarda datos de un servidor (carpeta serveur)
	$full = (Resolve-Path $out).Path.TrimEnd("\") + "\"
	$busy = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($full, [StringComparison]::OrdinalIgnoreCase) })
	if ($busy.Count -gt 0) { throw "$out esta en uso ($(($busy | ForEach-Object { $_.ProcessId.ToString() + ' ' + $_.Name }) -join ', ')): cierralo o usa otra carpeta con -Out" }
	$data = @(Get-ChildItem $out -Directory -Recurse -Filter "serveur" -ErrorAction SilentlyContinue)
	if ($data.Count -gt 0) { throw "$out guarda datos de un servidor ($($data[0].FullName)): llevalos a otro sitio o usa otra carpeta con -Out" }
	Remove-Item -Recurse -Force $out
}
$win = Join-Path $out "galaxy55-offline"
$lin = Join-Path $out "galaxy55-offline-linux"
$mac = Join-Path $out "galaxy55-offline-mac"
New-Item -ItemType Directory -Force "$win\res", "$lin\res", "$mac\res" | Out-Null

# recursos: graficos del cliente, mapa de estrellas, nave nodriza, contratos de la ESCorp y sonidos
$gfx = "src\G55\fla\client\gfx"
$res = @("digger.png", "door.md", "hud.png", "hud_jetpack.png", "icons.png", "lazer.png", "lazer2.png", "lazer3.png", "lazer4.png", "ship_halo.png", "texture.png", "mothership.bin", "contracts.json", "kubindex.json", "cone.png")
foreach ($d in $win, $lin, $mac) {
	foreach ($r in $res) { Copy-Item "$gfx\$r" "$d\res\$r" }
	Copy-Item "src\G55\fla\explore\gfx\tiles.png" "$d\res\explore_tiles.png"
	# iconos del multijugador en el mapa (candados y camara de Kube)
	Copy-Item "src\G55\fla\explore\gfx\mp_icons.png" "$d\res\explore_mp_icons.png"
	Get-ChildItem "src\G55\fla\client\sfx\*.wav" | ForEach-Object { Copy-Item $_.FullName "$d\res\sfx_$($_.Name)" }
	Copy-Item "port\out\galaxy55.hl", "LICENSE", "NOTICE" $d
	# servidor dedicado del multijugador, sin ventana (port\server.hxml)
	if (Test-Path "port\out\server.hl") { Copy-Item "port\out\server.hl" $d }
}
# Windows: HashLink y sus librerias (sin las de compilar), y la version DirectX
# galaxy55.exe: copia de hl.exe con el icono del juego y sin consola (port\tools\galaxy55_exe.ps1); con su propio nombre
# Discord no lo toma por Half-Life
Copy-Item "port\out\galaxy55_dx.hl" $win
# doble clic en galaxy55.exe: hl.exe sin argumentos carga hlboot.dat de la carpeta actual; sin el se cerraba sin decir nada
Copy-Item "port\out\galaxy55.hl" "$win\hlboot.dat"
foreach ($f in "hl.exe", "libhl.dll", "fmt.hdll", "heaps.hdll", "openal.hdll", "OpenAL32.dll", "sdl.hdll", "SDL3.dll", "ui.hdll", "uv.hdll", "directx.hdll", "sqlite.hdll", "ssl.hdll", "vcruntime140.dll") {
	Copy-Item (Join-Path $HashLink $f) $win
}
$utf8 = New-Object Text.UTF8Encoding $false
function Save([string]$path, [string]$text, [string]$nl) { [IO.File]::WriteAllText($path, ($text -replace "`r?`n", $nl), $utf8) }
& "$PSScriptRoot\galaxy55_exe.ps1" -Hl (Join-Path $HashLink "hl.exe") -Out "$win\galaxy55.exe" | Out-Null
foreach ($v in @(@("jugar.bat", "galaxy55.hl", "version OpenGL. Si no abre, usa jugar_dx.bat."), @("jugar_dx.bat", "galaxy55_dx.hl", "version DirectX (equipos sin OpenGL 3.2, maquinas virtuales)."))) {
	# galaxy55.exe sin consola; si falta, hl.exe con su consola (y pausa si hay error)
	Save "$win\$($v[0])" "@echo off`nrem Galaxy 55 (offline) v$Version - $($v[2])`ncd /d `"%~dp0`"`nif exist galaxy55.exe goto exe`nhl $($v[1]) %*`nif errorlevel 1 pause`nexit /b`n:exe`nstart `"`" galaxy55.exe $($v[1]) %*`n" "`r`n"
}
# servidor dedicado: consola con el registro y las ordenes (help); sus datos en la carpeta "serveur" (o --data OTRA)
if (Test-Path "$win\server.hl") {
	Save "$win\galaxy55-serveur.bat" "@echo off`nrem Galaxy 55 (offline) v$Version - servidor multijugador dedicado (sin ventana). Ordenes: help, stop`ncd /d `"%~dp0`"`nhl server.hl --data serveur %*`npause`n" "`r`n"
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

MULTIJUGADOR: menu Multijugador (unirse a un servidor guardado o de la red local, o crear una partida desde una partida
guardada). Tu identidad es el archivo identite.g55 de %APPDATA%\Galaxy55\ : copialo para jugar con ella en otro PC y no se
lo des a nadie. Servidor dedicado sin ventana: galaxy55-serveur.bat (puerto 55055 TCP y UDP; sus datos en "serveur").
Para jugar por Internet hay que abrir ese puerto en el router (la casilla UPnP lo intenta sola).
Kubes del editor del servidor dedicado: los .kube de serveur\kubes (en una partida creada desde el juego, los del anfitrion).
Se juega tambien con jugadores de Linux y macOS (sus zips -linux y -mac), si todos tienen ESTA misma version.

Controles (teclado y raton): W/Z/flechas mover, raton mirar, Espacio saltar y jetpack, X caminar despacio, H casco,
clic izquierdo/E/Mayus excavar, colocar o usar, 1-0 o rueda elegir casilla, Tab excavador, R tirar, Mayus+K volver a la nave,
I paleta (creativo), clic central copiar bloque (creativo), Esc pausa, F5 guardar.
Mando: stick izquierdo mover, stick derecho mirar, A saltar, gatillos excavar/colocar, LB/RB elegir casilla, Y tirar,
Back casco, Start pausa, R3 paleta y L3 copiar bloque (creativo). Cofres y tienda tambien con el mando.

---
English: unofficial native Windows port of Motion Twin's Galaxy 55 (2012). Unzip the whole folder and run jugar.bat
(OpenGL) or jugar_dx.bat (DirectX, for PCs without OpenGL 3.2 or virtual machines). Keep "res" next to galaxy55.hl.
Saves go to %APPDATA%\Galaxy55\ . Known bugs: BUGS.md in the repository.
Multiplayer: Multiplayer menu (join a saved or LAN server, or create a game from a saved game). Your identity is the file
identite.g55 in %APPDATA%\Galaxy55\ (copy it to another PC to keep it; never share it). Dedicated server without a window:
galaxy55-serveur.bat (port 55055 TCP and UDP, data in "serveur"); for Internet play, forward that port (UPnP tries it).
Editor kubes of a dedicated server: the .kube files in serveur\kubes (in a game created from the game, the host's).
Players on Linux and macOS (the -linux and -mac zips) can join too, as long as everyone has THIS same version.
"@ "`r`n"
# Linux: HashLink del paquete (carpeta hashlink, con -LinuxHashLink) o el del sistema. Un zip hecho en Windows no guarda el
# permiso de ejecucion: los .sh se abren con "sh" y le dan ese permiso a hl antes de usarlo
if ($LinuxHashLink) {
	New-Item -ItemType Directory -Force "$lin\hashlink" | Out-Null
	Get-ChildItem $LinuxHashLink -File | Where-Object { $_.Name -match '^(hl|libhl\.so|.*\.hdll|lib.*\.so(\.[0-9]+)*)$' } | ForEach-Object { Copy-Item $_.FullName "$lin\hashlink\" }
	foreach ($f in "hl", "libhl.so", "sdl.hdll", "libSDL3.so.0") { if (-not (Test-Path "$lin\hashlink\$f")) { throw "falta $f en $LinuxHashLink" } }
}
function UnixRun([string]$what, [string]$file, [string]$extra) {
	"#!/bin/sh`n# Galaxy 55 (offline) v$Version - $what`ncd `"`$(dirname `"`$0`")`"`nif [ -f hashlink/hl ]; then`n`tchmod +x hashlink/hl 2>/dev/null`n`tLD_LIBRARY_PATH=`"`$PWD/hashlink`${LD_LIBRARY_PATH:+:`$LD_LIBRARY_PATH}`" exec hashlink/hl $file$extra `"`$@`"`nfi`nexec hl $file$extra `"`$@`"`n"
}
Save "$lin\jugar.sh" (UnixRun "abre el juego" "galaxy55.hl" "") "`n"
if (Test-Path "$lin\server.hl") { Save "$lin\galaxy55-serveur.sh" (UnixRun "servidor multijugador dedicado (sin ventana). Ordenes: help, stop" "server.hl" " --data serveur") "`n" }
$withHl = if ($LinuxHashLink) { "si" } else { "no" }
# los $ del ejemplo de shell del final van con ` para que salgan tal cual y PowerShell no los evalue
Save "$lin\LEEME.txt" @"
Galaxy 55 (offline) v$Version - Linux
=====================================
Port NO oficial de Galaxy 55 (Motion Twin, 2012). Licencia CC BY-NC-SA 4.0 (ver LICENSE y NOTICE).
Codigo y novedades: https://github.com/Pv1E/galaxy55-offline

JUGAR: descomprime la carpeta ENTERA y, en una terminal dentro de ella:  sh jugar.sh
Con la carpeta "hashlink" (HashLink 1.16 y SDL3 incluidos: $withHl) no hace falta instalar HashLink: sirve en Linux
x86-64 (PC de 64 bits) con glibc 2.35 o mas nuevo (Ubuntu 22.04, Debian 12, Fedora 36, Mint 21 o posteriores).
Necesita los drivers OpenGL del sistema (Mesa o los del fabricante), OpenAL (libopenal1), libuv, libpng, libturbojpeg,
libvorbis y SQLite, que casi todas las distribuciones traen; si falta alguno, el juego dice cual al abrirse.
Sin la carpeta "hashlink": instala HashLink 1.16 (con SDL3) y que "hl" funcione en una terminal.
Las partidas, los ajustes y tu identidad del multijugador (identite.g55, no se la des a nadie) van en ~/Galaxy55
(con la variable GALAXY55_DATA eliges otra carpeta).

MULTIJUGADOR: con jugadores de Windows, Linux y macOS a la vez, si todos tienen ESTA version. Menu Multijugador para
unirse o crear una partida. Servidor dedicado sin ventana: sh galaxy55-serveur.sh (puerto 55055 TCP y UDP, datos en
"serveur"); con cortafuegos, abre ese puerto (por ejemplo: sudo ufw allow 55055).

---
English: unofficial native port of Motion Twin's Galaxy 55 (2012). Unzip the whole folder and run "sh jugar.sh" in a
terminal inside it. With the "hashlink" folder (HashLink 1.16 + SDL3 included: $withHl) nothing has to be installed on
Linux x86-64 with glibc 2.35 or newer (Ubuntu 22.04, Debian 12, Fedora 36, Mint 21 or later); it uses the system OpenGL
drivers, OpenAL, libuv, libpng, libturbojpeg, libvorbis and SQLite. Saves, settings and your multiplayer identity
(identite.g55, never share it) go to ~/Galaxy55. Multiplayer works between Windows, Linux and macOS players on THIS same
version. Dedicated server: sh galaxy55-serveur.sh (port 55055 TCP and UDP; open it in your firewall).

Francais : portage non officiel de Galaxy 55 (Motion Twin, 2012). Decompresse tout le dossier, puis dans un terminal
ouvert dedans : sh jugar.sh . Avec le dossier "hashlink" (HashLink 1.16 et SDL3 inclus : $withHl), rien a installer sur
Linux x86-64 avec glibc 2.35 ou plus recent (Ubuntu 22.04, Debian 12, Fedora 36, Mint 21 ou suivants) ; il utilise les
pilotes OpenGL, OpenAL, libuv, libpng, libturbojpeg, libvorbis et SQLite du systeme. Parties, reglages et identite du
multijoueur (identite.g55, ne la donne a personne) dans ~/Galaxy55. Le multijoueur marche entre joueurs Windows, Linux et
macOS sur CETTE meme version. Serveur dedie : sh galaxy55-serveur.sh (port 55055 TCP et UDP, a ouvrir dans le pare-feu).
"@ "`n"

# macOS: HashLink no tiene la maquina virtual hl en los Mac con procesador Apple (solo HashLink/C): el paquete lleva el
# codigo C del juego y del servidor (-Hlc) y compilar.sh, que los compila en el Mac con el HashLink de Homebrew
Add-Type -AssemblyName System.IO.Compression.FileSystem
$withMac = $false
if (Test-Path $Hlc) {
	$hz = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $Hlc).Path)
	try { $names = @($hz.Entries | ForEach-Object { $_.FullName }) } finally { $hz.Dispose() }
	if (-not ($names -ccontains "hlc/game/galaxy55.c" -and $names -ccontains "hlc/server/server.c")) { throw "$Hlc sin hlc/game/galaxy55.c o hlc/server/server.c" }
	# macOS y Windows no distinguen mayusculas: dos archivos que solo se diferencian en ellas se pisarian al descomprimir
	$clash = @($names | Group-Object { $_.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Group -join " / " })
	if ($clash.Count -gt 0) { throw "$Hlc tiene archivos que solo cambian en mayusculas (rehacerlo con build-hlc-sources.sh): $($clash -join ', ')" }
	$withMac = $true
}
if ($withMac) {
	Save "$mac\compilar.sh" ([IO.File]::ReadAllText("$PSScriptRoot\build-hlc.sh").Replace("__VERSION__", $Version)) "`n"
	# icono de "Galaxy 55.app": la imagen de 256x256 de port\galaxy55.ico, que ya es un PNG dentro del .ico (se copia tal cual:
	# System.Drawing la lee mal); compilar.sh la pasa a .icns en el Mac
	$ib = [IO.File]::ReadAllBytes((Resolve-Path "port\galaxy55.ico").Path)
	$png = $null
	for ($k = 0; $k -lt [BitConverter]::ToUInt16($ib, 4); $k++) {
		$e = 6 + 16 * $k
		if ($ib[$e] -ne 0 -or $ib[$e + 1] -ne 0) { continue }
		$len = [BitConverter]::ToInt32($ib, $e + 8); $off = [BitConverter]::ToInt32($ib, $e + 12)
		if ($ib[$off] -eq 0x89 -and $ib[$off + 1] -eq 0x50) { $png = New-Object byte[] $len; [Array]::Copy($ib, $off, $png, 0, $len) }
	}
	if ($png) { [IO.File]::WriteAllBytes("$mac\icon.png", $png) } else { "aviso: port\galaxy55.ico sin imagen PNG de 256x256: la app de macOS ira sin icono" }
	function MacRun([string]$what, [string]$bin, [string]$file, [string]$extra) {
		"#!/bin/sh`n# Galaxy 55 (offline) v$Version - $what`ncd `"`$(dirname `"`$0`")`"`nif [ -x ./$bin ]; then exec ./$bin$extra `"`$@`"; fi`nif command -v hl > /dev/null 2>&1; then exec hl $file$extra `"`$@`"; fi`necho `"Primero / First / D'abord : sh compilar.sh`"`nexit 1`n"
	}
	Save "$mac\jugar.sh" (MacRun "abre el juego (compilado antes con compilar.sh)" "galaxy55" "galaxy55.hl" "") "`n"
	Save "$mac\galaxy55-serveur.sh" (MacRun "servidor multijugador dedicado (sin ventana). Ordenes: help, stop" "galaxy55-serveur" "server.hl" " --data serveur") "`n"
	Save "$mac\LEEME.txt" @"
Galaxy 55 (offline) v$Version - macOS
=====================================
Port NO oficial de Galaxy 55 (Motion Twin, 2012). Licencia CC BY-NC-SA 4.0 (ver LICENSE y NOTICE).
Codigo y novedades: https://github.com/Pv1E/galaxy55-offline

No hay aplicacion lista para Mac: en los Mac con procesador Apple (M1 y siguientes) HashLink no tiene maquina virtual, asi
que el juego se compila UNA VEZ en tu Mac (unos minutos) y eso crea la aplicacion "Galaxy 55.app". Sirve igual en un Mac Intel.
1. Instala Homebrew (https://brew.sh) y las herramientas de Xcode (en Terminal: xcode-select --install).
2. Descomprime esta carpeta ENTERA. Abre Terminal (Aplicaciones > Utilidades), escribe  sh  y un espacio, arrastra el
   archivo compilar.sh desde el Finder a la ventana de Terminal y pulsa Intro. Instala "hashlink" con Homebrew si falta.
3. Aparece "Galaxy 55.app" en esta carpeta: doble clic para jugar (puedes moverla a Aplicaciones). No desinstales hashlink.
Servidor dedicado sin ventana: sh galaxy55-serveur.sh (en Terminal, igual que en el paso 2; puerto 55055 TCP y UDP).
NO PROBADO en un Mac por nosotros: si falla, cuentanoslo con lo que sale en Terminal.
Las partidas, los ajustes y tu identidad del multijugador (identite.g55, no se la des a nadie) van en ~/Galaxy55.
Multijugador con jugadores de Windows, Linux y macOS a la vez, si todos tienen ESTA version.

---
English: there is no ready-made Mac app: on Apple Silicon Macs HashLink has no virtual machine, so the game is compiled
ONCE on your Mac (a few minutes), which creates the app "Galaxy 55.app" (also works on Intel Macs).
1. Install Homebrew (https://brew.sh) and the Xcode tools (in Terminal: xcode-select --install).
2. Unzip the whole folder. Open Terminal (Applications > Utilities), type  sh  and a space, drag the file compilar.sh from
   the Finder into the Terminal window and press Return. It installs "hashlink" with Homebrew if needed.
3. "Galaxy 55.app" appears in this folder: double-click it to play (you can move it to Applications). Keep hashlink installed.
Dedicated server without a window: sh galaxy55-serveur.sh (port 55055 TCP and UDP). NOT tested on a Mac by us: please
report what Terminal shows. Saves and your multiplayer identity (identite.g55, never share it) go to ~/Galaxy55.
Multiplayer works between Windows, Linux and macOS players on THIS same version.

Francais : il n'y a pas d'application Mac toute prete : sur les Mac a puce Apple, HashLink n'a pas de machine virtuelle,
donc le jeu se compile UNE FOIS sur ton Mac (quelques minutes), ce qui cree l'application "Galaxy 55.app" (marche aussi
sur Mac Intel).
1. Installe Homebrew (https://brew.sh) et les outils Xcode (dans Terminal : xcode-select --install).
2. Decompresse tout le dossier. Ouvre Terminal (Applications > Utilitaires), tape  sh  et un espace, glisse le fichier
   compilar.sh depuis le Finder dans la fenetre de Terminal, puis Entree. Il installe "hashlink" avec Homebrew si besoin.
3. "Galaxy 55.app" apparait dans ce dossier : double-clic pour jouer (tu peux la ranger dans Applications). Garde hashlink.
Serveur dedie sans fenetre : sh galaxy55-serveur.sh (port 55055 TCP et UDP). PAS teste sur Mac par nous : signale ce
qu'affiche Terminal en cas de souci. Parties et identite du multijoueur (identite.g55, ne la donne a personne) dans
~/Galaxy55. Le multijoueur marche entre joueurs Windows, Linux et macOS sur CETTE meme version.
"@ "`n"
} else { "aviso: sin $Hlc (port/tools/build-hlc-sources.sh) no se hace el zip de macOS" }

$zw = Join-Path $out "galaxy55-offline-v$Version.zip"
$zl = Join-Path $out "galaxy55-offline-v$Version-linux.zip"
$zm = Join-Path $out "galaxy55-offline-v$Version-mac.zip"
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
$zips = @($zw, $zl)
if ($withMac) {
	New-Zip $mac $zm
	# el codigo C, de zip a zip sin pasar por el disco (Windows no distingue _sP.h de _sp.h)
	$hz = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $Hlc).Path)
	$mz = [IO.Compression.ZipFile]::Open($zm, "Update")
	try {
		foreach ($e in $hz.Entries) {
			if ($e.FullName.EndsWith("/")) { continue }
			$i = $e.Open(); $o = $mz.CreateEntry($e.FullName, "Optimal").Open()
			try { $i.CopyTo($o) } finally { $o.Dispose(); $i.Dispose() }
		}
	} finally { $mz.Dispose(); $hz.Dispose() }
	$zips += $zm
}
Get-Item $zips | ForEach-Object { "{0}  {1:N0} bytes" -f $_.Name, $_.Length }
