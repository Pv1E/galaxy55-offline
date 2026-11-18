param([switch]$Record, [string[]]$Only = @(), [int]$Timeout = 240, [double]$MaxPct = 0.5, [string]$HlFile = "port/out/galaxy55.hl")
# Base de referencia del juego en solo para el multijugador (anadido del port): mientras se separan las reglas del dibujo, el solo
# no debe cambiar. -Record pasa cada guion DOS veces con --rngseed=1 y guarda salida y capturas en port/out/baseline/<guion>/a y b;
# sin -Record lo pasa una vez y lo compara con a, sin contar lo que ya cambia solo entre a y b (lineas con tiempos o posiciones,
# pixeles del cielo o de particulas). Cada pasada usa una carpeta de datos vacia. Necesita haber compilado port/game.hxml.
# Uso: powershell -File port/dev/baseline.ps1 -Record    y despues    powershell -File port/dev/baseline.ps1
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
$scripts = @("place", "place_top", "bomb", "bomb_liquids", "chest", "chest_move", "cascade", "flow", "drop_rest", "mort_conteneur",
	"muerte_nave", "dock", "pilotar_vuelo", "sintetizador_mano", "recetas_cantidades", "contrats", "shop", "licencias", "cometa",
	"kubindex", "hangar", "explore", "mother_save", "stockage_vaisseau", "creatif_survie", "vida", "palette_charges")
if ($Only.Count -gt 0) { $scripts = @($Only | ForEach-Object { $_ -split "," } | Where-Object { $_ -ne "" }) }
$base = "$repo\port\out\baseline"

function Run-One([string]$name, [string]$dest) {
	if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
	New-Item -ItemType Directory -Force $dest | Out-Null
	$data = "$repo\port\out\bl_data"
	if (Test-Path $data) { Remove-Item -Recurse -Force $data }
	New-Item -ItemType Directory -Force $data | Out-Null
	$start = Get-Date
	$out = & powershell -NoProfile -ExecutionPolicy Bypass -File "$repo\port\dev\devrun.ps1" -Script "port/dev/$name.txt" -Timeout $Timeout -Data $data -HlFile $HlFile -Extra "--rngseed=1 --fixeddt=0.016666667"
	$out | Set-Content -Encoding utf8 "$dest\out.txt"
	Get-ChildItem "$repo\port\out\*.png" | Where-Object { $_.LastWriteTime -ge $start } | ForEach-Object { Copy-Item $_.FullName $dest }
}

function Bag([string[]]$lines) {
	$h = @{}
	foreach ($l in $lines) { if ($h.ContainsKey($l)) { $h[$l]++ } else { $h[$l] = 1 } }
	return $h
}

$fails = 0
foreach ($s in $scripts) {
	if ($Record) {
		Write-Host "grabando $s"
		Run-One $s "$base\$s\a"
		Run-One $s "$base\$s\b"
		continue
	}
	if (-not (Test-Path "$base\$s\a")) { Write-Host "SIN REFERENCIA $s"; $fails++; continue }
	Run-One $s "$base\$s\new"
	$la = @(Get-Content "$base\$s\a\out.txt"); $lb = @(Get-Content "$base\$s\b\out.txt"); $ln = @(Get-Content "$base\$s\new\out.txt")
	$ba = Bag $la; $bb = Bag $lb; $bn = Bag $ln
	$missing = @()
	foreach ($k in $ba.Keys) {
		if (-not $bb.ContainsKey($k)) { continue }
		$want = [Math]::Min($ba[$k], $bb[$k])
		$got = if ($bn.ContainsKey($k)) { $bn[$k] } else { 0 }
		if ($got -lt $want) { $missing += $k }
	}
	$imgBad = @()
	foreach ($png in Get-ChildItem "$base\$s\a\*.png") {
		$nb = "$base\$s\new\$($png.Name)"
		$bp = "$base\$s\b\$($png.Name)"
		if (-not (Test-Path $nb)) { $imgBad += "$($png.Name) falta"; continue }
		if (-not (Test-Path $bp)) { $bp = $png.FullName }
		$r = (& "$repo\port\dev\shotdiff.ps1" -A $png.FullName -B $bp -New $nb).Split(" ")
		if ([int]$r[0] -lt 0 -or [double]::Parse($r[2], [Globalization.CultureInfo]::InvariantCulture) -gt $MaxPct) { $imgBad += "$($png.Name) $($r[2])% de $($r[1]) px" }
	}
	if ($missing.Count -eq 0 -and $imgBad.Count -eq 0) { Write-Host "IGUAL   $s" }
	else {
		$fails++
		Write-Host "CAMBIA  $s"
		foreach ($m in $missing) { Write-Host "  falta: $m" }
		foreach ($m in $imgBad) { Write-Host "  imagen: $m" }
	}
}
if (-not $Record) { Write-Host $(if ($fails -eq 0) { "BASELINE IGUAL ($($scripts.Count) guiones)" } else { "BASELINE CAMBIA ($fails de $($scripts.Count))" }) }
