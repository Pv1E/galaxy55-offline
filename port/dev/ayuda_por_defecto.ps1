# Ayuda en pantalla desactivada por defecto: lanza ayuda_por_defecto.txt tres veces con una carpeta de datos nueva
# (port/out/testdata_ayuda) y escribe cada pasada en port/out/ayuda_N.txt
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
$data = "$repo\port\out\testdata_ayuda"
if (Test-Path $data) { Remove-Item -Recurse -Force $data }
New-Item -ItemType Directory -Force $data | Out-Null
$head = (Get-Content "$PSScriptRoot\ayuda_por_defecto.txt") -join "`n"
$passes = @{
	1 = "wait 3`nplanet`nwait 20`nprint helptext`nsetlang fr`nprint helptext`nhelptext old`nprint helptext`nquit";
	2 = "wait 3`nplanet`nwait 20`nprint helptext`nhelptext 1`nsetlang fr`nwait 5`nprint helptext`nquit";
	3 = "wait 3`nplanet`nwait 20`nprint helptext`nquit"
}
foreach ($n in 1, 2, 3) {
	$s = "$repo\port\out\ayuda_pasada_$n.txt"
	Set-Content -Encoding ascii $s ($head + "`n" + $passes[$n])
	& "$PSScriptRoot\devrun.ps1" -Script $s -Data $data -Extra "--lang=fr" -Timeout 120 | Select-String '^helptext' | ForEach-Object { "pasada ${n}: $($_.Line)" }
}
