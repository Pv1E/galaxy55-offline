param(
	[string]$Label = "cur",
	[string]$Ref = "",
	[switch]$Reference,
	[string]$Filter = "",
	[int]$Jobs = 1,
	[double]$TimeoutScale = 2,
	[switch]$CompareOnly,
	[switch]$Reclean,
	[switch]$KeepData
)
# Lanza todos los guiones de port/dev (*.txt) con devrun.ps1 y guarda lo que dicen y sus capturas, para comparar dos versiones.
#   powershell -File port/dev/runall.ps1 -Reference -Label ref    dos veces (ref y ref.2): lineas y capturas que cambian solas
#   powershell -File port/dev/runall.ps1 -Label cur -Ref ref      y comparar con la referencia (sin sus lineas inestables)
# Necesita haber compilado port/game.hxml. Opciones:
#   -Label NOMBRE   carpeta de salida: port/out/runall/NOMBRE (o una ruta)
#   -Ref NOMBRE     referencia con la que comparar (port/out/runall/NOMBRE o una ruta); -CompareOnly compara sin lanzar nada
#                   (con -Reference, rehace unstable.txt y shots_noise.tsv de las dos pasadas que ya hay); -Reclean vuelve a
#                   limpiar las salidas que ya hay (raw/) con las reglas de ahora, sin lanzar nada (con -Reference, las dos pasadas)
#   -Filter a*,b    solo esos guiones (comodines, separados por comas); en una carpeta que ya existe solo rehace esos
#   -Jobs N         guiones a la vez (1); con mas, el reloj de cada partida va mas cargado: hacer la referencia igual
#   -TimeoutScale F multiplica el -Timeout de cada guion (2: con varios a la vez algunos pasan de los 120 s por defecto)
#   -KeepData       no borra la carpeta de datos de cada guion (en %TEMP%\g55runall)
# Cada guion corre con una carpeta de datos nueva (GALAXY55_DATA: ajustes por defecto, sin partidas) y sus -Extra / -Timeout,
# que se leen de su cabecera (la primera vez que aparece cada uno en un comentario: '-Extra "--lang=fr"', '-Timeout 400').
# Salida en la carpeta: NOMBRE.txt (lo que dijo el juego, limpio de tiempos, ids, fechas y rutas), raw/ (sin limpiar),
# shots/NOMBRE/*.jpg (capturas a 640 de ancho), summary.tsv (estado, segundos, opciones), index.html (todas las capturas).
# -Reference: ademas unstable.txt (por guion, las lineas que cambiaron entre las dos pasadas, con los numeros como #) y
# shots_noise.tsv (diferencia media de cada captura entre las dos pasadas).
# -Ref: compare.txt (diferencias que no son inestables, capturas que cambian mas que su ruido), compare.html (todas las
# capturas, la referencia al lado, de la que mas cambia a la que menos) y compare_N.png (planchas de las que cambian).
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $repo
$env1 = "$repo\..\tools-portable\env.ps1"
if (Test-Path $env1) { . $env1 }
$root = "$repo\port\out\runall"

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
public static class RunAll {
	/** la linea con cada numero (signo y decimales incluidos) como # (una linea inestable cambia sobre todo sus numeros) */
	public static string Mask(string s) { return Regex.Replace(s, "-?[0-9]+([.][0-9]+)?", "#"); }

	/** diferencias por lineas (subsecuencia comun mas larga): {0, i, j} igual, {1, i, -1} solo en a, {2, -1, j} solo en b */
	public static List<int[]> Diff(string[] a, string[] b) {
		var ops = new List<int[]>();
		int pre = 0;
		while (pre < a.Length && pre < b.Length && a[pre] == b[pre]) pre++;
		int suf = 0;
		while (suf < a.Length - pre && suf < b.Length - pre && a[a.Length - 1 - suf] == b[b.Length - 1 - suf]) suf++;
		int n = a.Length - pre - suf, m = b.Length - pre - suf;
		for (int i = 0; i < pre; i++) ops.Add(new int[] { 0, i, i });
		if ((long)n * m > 30000000L) {
			for (int i = 0; i < n; i++) ops.Add(new int[] { 1, pre + i, -1 });
			for (int j = 0; j < m; j++) ops.Add(new int[] { 2, -1, pre + j });
		} else {
			var L = new int[n + 1, m + 1];
			for (int i = n - 1; i >= 0; i--)
				for (int j = m - 1; j >= 0; j--)
					L[i, j] = a[pre + i] == b[pre + j] ? L[i + 1, j + 1] + 1 : Math.Max(L[i + 1, j], L[i, j + 1]);
			int x = 0, y = 0;
			while (x < n && y < m) {
				if (a[pre + x] == b[pre + y]) { ops.Add(new int[] { 0, pre + x, pre + y }); x++; y++; }
				else if (L[x + 1, y] >= L[x, y + 1]) { ops.Add(new int[] { 1, pre + x, -1 }); x++; }
				else { ops.Add(new int[] { 2, -1, pre + y }); y++; }
			}
			for (; x < n; x++) ops.Add(new int[] { 1, pre + x, -1 });
			for (; y < m; y++) ops.Add(new int[] { 2, -1, pre + y });
		}
		for (int i = 0; i < suf; i++) ops.Add(new int[] { 0, a.Length - suf + i, b.Length - suf + i });
		return ops;
	}

	/** las lineas que cambian entre dos pasadas (con Mask): las inestables de un guion */
	public static string[] Unstable(string[] a, string[] b) {
		var set = new SortedSet<string>(StringComparer.Ordinal);
		foreach (var op in Diff(a, b)) {
			if (op[0] == 1) set.Add(Mask(a[op[1]]));
			else if (op[0] == 2) set.Add(Mask(b[op[2]]));
		}
		var r = new string[set.Count];
		set.CopyTo(r);
		return r;
	}

	/** diferencias de b (nueva) respecto a a (referencia) sin las lineas inestables: "- linea" (solo en a) y "+ linea" (solo en b) */
	public static string[] Changes(string[] a, string[] b, string[] unstable) {
		var u = new HashSet<string>(unstable, StringComparer.Ordinal);
		var outp = new List<string>();
		var ops = Diff(a, b);
		int k = 0;
		while (k < ops.Count) {
			if (ops[k][0] == 0) { k++; continue; }
			var rem = new List<string>();
			var add = new List<string>();
			while (k < ops.Count && ops[k][0] != 0) {
				if (ops[k][0] == 1) rem.Add(a[ops[k][1]]); else add.Add(b[ops[k][2]]);
				k++;
			}
			foreach (var r in rem) if (!u.Contains(Mask(r))) outp.Add("- " + r);
			foreach (var s in add) if (!u.Contains(Mask(s))) outp.Add("+ " + s);
		}
		return outp.ToArray();
	}

	static Bitmap Load(string path) {
		using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read)) using (var img = Image.FromStream(fs)) return new Bitmap(img);
	}

	/** diferencia media por canal (0-255) entre dos imagenes del mismo tamano; 255 si no lo son */
	public static double ImageDiff(string pa, string pb) {
		using (var a = Load(pa)) using (var b = Load(pb)) {
			if (a.Width != b.Width || a.Height != b.Height) return 255;
			var r = new Rectangle(0, 0, a.Width, a.Height);
			var da = a.LockBits(r, ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
			var db = b.LockBits(r, ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
			int n = da.Stride * a.Height;
			var ba = new byte[n];
			var bb = new byte[n];
			Marshal.Copy(da.Scan0, ba, 0, n);
			Marshal.Copy(db.Scan0, bb, 0, n);
			a.UnlockBits(da);
			b.UnlockBits(db);
			long sum = 0;
			for (int y = 0; y < a.Height; y++) {
				int p = y * da.Stride;
				for (int x = 0; x < a.Width * 3; x++) sum += Math.Abs(ba[p + x] - bb[p + x]);
			}
			return (double)sum / ((long)a.Width * a.Height * 3);
		}
	}

	static ImageCodecInfo Jpeg() {
		foreach (var c in ImageCodecInfo.GetImageEncoders()) if (c.MimeType == "image/jpeg") return c;
		return null;
	}

	/** la captura a w de ancho, en JPEG */
	public static void Thumb(string src, string dst, int w) {
		using (var img = Load(src)) {
			int h = (int)Math.Round((double)w * img.Height / img.Width);
			using (var t = new Bitmap(w, h)) {
				using (var g = Graphics.FromImage(t)) {
					g.InterpolationMode = InterpolationMode.HighQualityBicubic;
					g.DrawImage(img, 0, 0, w, h);
				}
				var ep = new EncoderParameters(1);
				ep.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 90L);
				t.Save(dst, Jpeg(), ep);
			}
		}
	}

	/** plancha: una fila por pareja (referencia | nueva), w x h cada imagen, con su rotulo; "" = falta */
	public static void Sheet(string dst, string[] left, string[] right, string[] labels, int w, int h) {
		int rows = labels.Length;
		using (var bmp = new Bitmap(w * 2 + 4, rows * (h + 4)))
		using (var g = Graphics.FromImage(bmp))
		using (var font = new Font("Arial", 11))
		using (var bg = new SolidBrush(Color.FromArgb(170, 0, 0, 0))) {
			g.Clear(Color.FromArgb(40, 40, 40));
			g.InterpolationMode = InterpolationMode.HighQualityBicubic;
			for (int i = 0; i < rows; i++) {
				int y = i * (h + 4);
				string[] pics = { left[i], right[i] };
				for (int k = 0; k < 2; k++) {
					int x = k * (w + 4);
					if (pics[k] != "" && File.Exists(pics[k])) using (var img = Load(pics[k])) g.DrawImage(img, x, y, w, h);
					else g.DrawString("falta", font, Brushes.White, x + w / 2 - 20, y + h / 2);
				}
				var text = labels[i];
				var sz = g.MeasureString(text, font);
				g.FillRectangle(bg, 0, y, sz.Width + 6, sz.Height + 4);
				g.DrawString(text, font, Brushes.Yellow, 3, y + 2);
				g.FillRectangle(bg, w + 4, y, 30, sz.Height + 4);
				g.DrawString("ref", font, Brushes.White, 3, y + h - sz.Height - 2);
				g.DrawString("nueva", font, Brushes.White, w + 7, y + h - sz.Height - 2);
			}
			bmp.Save(dst, ImageFormat.Png);
		}
	}
}
"@

function Get-Dir([string]$name) {
	if ($name -match '[\\/:]') { return [IO.Path]::GetFullPath($name) }
	return "$root\$name"
}

# las lineas de un fichero (nada si no existe; para un metodo de RunAll: [string[]]@(Read-Lines ...)). La salida redirigida de
# un devrun que acaba de terminar puede seguir abierta un momento: se lee compartida y se reintenta
function Read-Lines([string]$path) {
	if (-not (Test-Path $path)) { return }
	for ($i = 0; ; $i++) {
		try {
			$fs = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
			$sr = New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)
			$lines = New-Object System.Collections.Generic.List[string]
			while ($null -ne ($l = $sr.ReadLine())) { $lines.Add($l) }
			$sr.Close()
			return $lines.ToArray()
		} catch [IO.IOException] {
			if ($i -ge 40) { throw }
			Start-Sleep -Milliseconds 250
		}
	}
}

function Write-Lines([string]$path, $lines) {
	[IO.File]::WriteAllLines($path, [string[]]@($lines), (New-Object Text.UTF8Encoding($false)))
}

# los guiones elegidos, con las opciones de su cabecera
function Get-Scripts {
	$pats = if ($Filter) { $Filter.Split(",") } else { @("*") }
	Get-ChildItem "$repo\port\dev\*.txt" | Sort-Object Name | Where-Object {
		$n = $_.BaseName
		($pats | Where-Object { $n -like $_ }).Count -gt 0
	} | ForEach-Object {
		$head = (Get-Content $_.FullName -Encoding UTF8) | Where-Object { $_ -match '^\s*#' }
		$text = $head -join "`n"
		$extra = if ($text -match '-Extra\s+"([^"]*)"') { $Matches[1] } else { "" }
		$timeout = if ($text -match '-Timeout\s+(\d+)') { [int]$Matches[1] } else { 120 }
		[pscustomobject]@{ Name = $_.BaseName; Path = "port/dev/$($_.Name)"; Extra = $extra; Timeout = [int][math]::Ceiling($timeout * $TimeoutScale) }
	}
}

# limpia la salida de un guion: rutas de las carpetas de la pasada (%TEMP%\g55runall\...\data|shots\GUION) y del repositorio, ids
# de partida, fechas (tambien dia/mes), horas, md5, milisegundos y fps
function Get-Clean($lines) {
	$rules = @(
		@('[A-Za-z]:[\\/][^ ]*?g55runall[\\/][^\\/ ]+[\\/]data[\\/][^\\/ ]+', '<datos>'),
		@('[A-Za-z]:[\\/][^ ]*?g55runall[\\/][^\\/ ]+[\\/]shots[\\/][^\\/ ]+', '<capturas>'),
		@([regex]::Escape($repo), '<repo>'),
		@([regex]::Escape($repo.Replace('\', '/')), '<repo>'),
		@('\b\d{8}_\d{6}_\d{1,4}\b', '<id>'),
		@('\b\d{4}-\d{2}-\d{2}(?:[ T]\d{2}:\d{2}(?::\d{2})?)?\b', '<fecha>'),
		@('\b\d{1,2}/\d{1,2}/\d{2,4}\b', '<fecha>'),
		@('\b\d{1,2}/\d{1,2}(?= \d{1,2}:\d{2})', '<fecha>'),
		@('\b\d{1,2}:\d{2}(?::\d{2})?\b', '<hora>'),
		@('\b[0-9a-f]{32}\b', '<md5>'),
		@('-?\d+(?:\.\d+)? ?ms\b', '<ms>'),
		@('\btime_ms=\d+', 'time_ms=<ms>'),
		@('\bfps \d+', 'fps <n>')
	)
	foreach ($l in $lines) {
		if ($l -match '^(fondo|ruta|mundo)') { continue }
		foreach ($r in $rules) { $l = $l -replace $r[0], $r[1] }
		$l
	}
}

# NOMBRE.txt a partir de raw/: lo que dijo el juego, limpio, y TIMEOUT o lo que dijo en stderr segun el estado; devuelve las lineas
function Write-Clean([string]$dest, [string]$name, [string]$state) {
	$lines = @(Get-Clean (Read-Lines "$dest\raw\$name.txt"))
	if ($state -eq "timeout") { $lines += "TIMEOUT" }
	elseif ($state -eq "err") { $lines += @(Get-Clean (Read-Lines "$dest\raw\$name.err.txt" | Select-Object -First 8 | ForEach-Object { "ERR: $_" })) }
	Write-Lines "$dest\$name.txt" $lines
	return $lines
}

# -Reclean: vuelve a limpiar las salidas que ya hay (raw/) con las reglas de ahora
function Invoke-Reclean([string]$dest) {
	$s = Get-Summary $dest
	foreach ($name in $s.Keys) { Write-Clean $dest $name $s[$name][1] | Out-Null }
	Write-Host "$dest`: $($s.Count) salidas limpias de nuevo"
}

# lanza los guiones en dest (como mucho $Jobs a la vez) y deja su salida limpia, sus capturas y summary.tsv. Con -Filter solo se
# rehacen esos guiones en una carpeta que ya existe (el resto se queda); si no, la carpeta se vacia antes
function Invoke-Run([string]$dest, $scripts) {
	$summary = @("guion`testado`tsegundos`terrores`tcapturas`textra`ttimeout")
	if ($Filter -and (Test-Path "$dest\summary.tsv")) {
		$names = @($scripts | ForEach-Object Name)
		$summary += @(Read-Lines "$dest\summary.tsv" | Select-Object -Skip 1 | Where-Object { $names -notcontains $_.Split("`t")[0] })
		foreach ($n in $names) { Remove-Item -Recurse -Force "$dest\$n.txt", "$dest\raw\$n.*", "$dest\shots\$n" -ErrorAction SilentlyContinue }
	} elseif (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
	New-Item -ItemType Directory -Force "$dest\raw", "$dest\shots" | Out-Null
	$tmp = "$env:TEMP\g55runall\" + (Split-Path $dest -Leaf) + "-$PID"
	if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
	New-Item -ItemType Directory -Force $tmp | Out-Null
	$exe = "$repo\port\out\galaxy55.exe"
	$hl = Get-Command hl -ErrorAction SilentlyContinue
	if (-not (Test-Path $exe) -and $hl) { try { & "$repo\port\tools\galaxy55_exe.ps1" -Hl $hl.Source -Out $exe | Out-Null } catch {} }
	$queue = New-Object System.Collections.Queue
	foreach ($s in $scripts) { $queue.Enqueue($s) }
	$running = @()
	$t0 = Get-Date
	$done = 0
	$total = @($scripts).Count
	while ($queue.Count -gt 0 -or $running.Count -gt 0) {
		while ($queue.Count -gt 0 -and $running.Count -lt $Jobs) {
			$s = $queue.Dequeue()
			$data = "$tmp\data\$($s.Name)"
			$shots = "$tmp\shots\$($s.Name)"
			New-Item -ItemType Directory -Force $data, $shots | Out-Null
			$argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$repo\port\dev\devrun.ps1`" -Script $($s.Path) -Timeout $($s.Timeout) -Data `"$data`" -Shots `"$shots`" -OutFile `"$dest\raw\$($s.Name).txt`""
			if ($s.Extra) { $argLine += " -Extra `"$($s.Extra)`"" }
			$p = Start-Process powershell -ArgumentList $argLine -WindowStyle Hidden -PassThru -RedirectStandardOutput "$tmp\$($s.Name).devrun.txt"
			$running += [pscustomobject]@{ S = $s; P = $p; Start = Get-Date; Data = $data; Shots = $shots }
		}
		Start-Sleep -Milliseconds 500
		$still = @()
		foreach ($r in $running) {
			$secs = ((Get-Date) - $r.Start).TotalSeconds
			if (-not $r.P.HasExited -and $secs -lt $r.S.Timeout + 90) { $still += $r; continue }
			# devrun no acaba (el juego deberia cerrarse a su -Timeout): fuera devrun y el juego
			if (-not $r.P.HasExited) { & taskkill /T /F /PID $r.P.Id 2>&1 | Out-Null }
			$name = $r.S.Name
			$dev = Read-Lines "$tmp\$name.devrun.txt"
			$state = if ($dev -contains "TIMEOUT" -or -not $r.P.HasExited) { "timeout" } elseif (Read-Lines "$dest\raw\$name.err.txt") { "err" } else { "ok" }
			$lines = Write-Clean $dest $name $state
			$pngs = @(Get-ChildItem "$($r.Shots)\*.png" -ErrorAction SilentlyContinue)
			if ($pngs.Count -gt 0) {
				New-Item -ItemType Directory -Force "$dest\shots\$name" | Out-Null
				foreach ($png in $pngs) { [RunAll]::Thumb($png.FullName, "$dest\shots\$name\$($png.BaseName).jpg", 640) }
			}
			$errors = @($lines | Where-Object { $_ -match '^ERROR en ' }).Count
			$summary += "$name`t$state`t$([int]$secs)`t$errors`t$($pngs.Count)`t$($r.S.Extra)`t$($r.S.Timeout)"
			if (-not $KeepData) { Remove-Item -Recurse -Force $r.Data, $r.Shots -ErrorAction SilentlyContinue }
			$done++
			Write-Host ("[{0}/{1}] {2} {3} ({4} s){5}" -f $done, $total, $name, $state, [int]$secs, $(if ($errors) { ", $errors ERROR en" } else { "" }))
		}
		$running = $still
	}
	Write-Lines "$dest\summary.tsv" (@($summary[0]) + @($summary | Select-Object -Skip 1 | Sort-Object))
	if (-not $KeepData) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
	Write-Index $dest
	Write-Host ("{0}: {1} guiones en {2:N1} min" -f $dest, $total, ((Get-Date) - $t0).TotalMinutes)
}

# index.html: todas las capturas de una pasada, por guion
function Write-Index([string]$dest) {
	$h = @("<!doctype html><meta charset=utf-8><title>runall $(Split-Path $dest -Leaf)</title><style>body{background:#222;color:#ddd;font:13px sans-serif}img{width:320px;margin:2px}h3{margin:12px 0 2px}</style>")
	foreach ($d in Get-ChildItem "$dest\shots" -Directory | Sort-Object Name) {
		$h += "<h3>$($d.Name)</h3>"
		foreach ($f in Get-ChildItem "$($d.FullName)\*.jpg" | Sort-Object Name) { $h += "<img src=`"shots/$($d.Name)/$($f.Name)`" title=`"$($f.BaseName)`">" }
	}
	Write-Lines "$dest\index.html" $h
}

function Get-Summary([string]$dir) {
	$m = @{}
	foreach ($l in (Read-Lines "$dir\summary.tsv" | Select-Object -Skip 1)) { $f = $l.Split("`t"); $m[$f[0]] = $f }
	return $m
}

# referencia: las lineas que cambiaron entre las dos pasadas y el ruido de cada captura
function Write-Unstable([string]$a, [string]$b) {
	$out = @()
	$noise = @("guion`tcaptura`truido")
	$sa = Get-Summary $a
	$sb = Get-Summary $b
	foreach ($name in $sa.Keys | Sort-Object) {
		$u = [RunAll]::Unstable([string[]]@(Read-Lines "$a\$name.txt"), [string[]]@(Read-Lines "$b\$name.txt"))
		if ($sa[$name] -and $sb[$name] -and $sa[$name][1] -ne $sb[$name][1]) { $u = @("*") + $u }
		foreach ($l in $u) { $out += "$name`t$l" }
		foreach ($j in Get-ChildItem "$a\shots\$name\*.jpg" -ErrorAction SilentlyContinue) {
			$o = "$b\shots\$name\$($j.Name)"
			$v = if (Test-Path $o) { [RunAll]::ImageDiff($j.FullName, $o) } else { 255 }
			$noise += "$name`t$($j.BaseName)`t$([math]::Round($v, 2))"
		}
	}
	Write-Lines "$a\unstable.txt" $out
	Write-Lines "$a\shots_noise.tsv" $noise
	$n = @($out | ForEach-Object { $_.Split("`t")[0] } | Sort-Object -Unique).Count
	Write-Host "lineas inestables: $($out.Count) en $n guiones ($a\unstable.txt)"
}

# comparacion de cur con ref: compare.txt, compare.html y planchas compare_N.png de las capturas que cambian
function Write-Compare([string]$cur, [string]$ref, $scripts) {
	$unstable = @{}
	foreach ($l in (Read-Lines "$ref\unstable.txt")) {
		$f = $l.Split("`t", 2)
		if (-not $unstable[$f[0]]) { $unstable[$f[0]] = New-Object System.Collections.Generic.List[string] }
		$unstable[$f[0]].Add($f[1])
	}
	$noise = @{}
	foreach ($l in (Read-Lines "$ref\shots_noise.tsv" | Select-Object -Skip 1)) { $f = $l.Split("`t"); $noise["$($f[0])/$($f[1])"] = [double]$f[2] }
	$sr = Get-Summary $ref
	$sc = Get-Summary $cur
	$txt = @()
	$same = 0
	$changed = @()
	$skipped = @()
	foreach ($s in $scripts) {
		$name = $s.Name
		if (-not (Test-Path "$ref\$name.txt")) { $txt += "== $name`: no esta en la referencia"; $changed += $name; continue }
		$u = [string[]]@(if ($unstable[$name]) { $unstable[$name] })
		if ($u -contains "*") { $skipped += $name }
		$d = [RunAll]::Changes([string[]]@(Read-Lines "$ref\$name.txt"), [string[]]@(Read-Lines "$cur\$name.txt"), $u)
		$st = if ($sr[$name] -and $sc[$name] -and $sr[$name][1] -ne $sc[$name][1]) { " (estado $($sr[$name][1]) -> $($sc[$name][1]))" } else { "" }
		if ($d.Count -eq 0 -and -not $st) { $same++; continue }
		$changed += $name
		$txt += "== $name`: $($d.Count) lineas distintas$st"
		$txt += @($d | Select-Object -First 30)
		if ($d.Count -gt 30) { $txt += "  ..." }
	}
	# capturas
	$pairs = @()
	foreach ($s in $scripts) {
		$names = @()
		foreach ($dir in "$ref\shots\$($s.Name)", "$cur\shots\$($s.Name)") { $names += @(Get-ChildItem "$dir\*.jpg" -ErrorAction SilentlyContinue | ForEach-Object BaseName) }
		foreach ($n in ($names | Sort-Object -Unique)) {
			$a = "$ref\shots\$($s.Name)\$n.jpg"
			$b = "$cur\shots\$($s.Name)\$n.jpg"
			$v = if ((Test-Path $a) -and (Test-Path $b)) { [RunAll]::ImageDiff($a, $b) } else { 255 }
			$z = $noise["$($s.Name)/$n"]
			if ($null -eq $z) { $z = 0 }
			$pairs += [pscustomobject]@{ Key = "$($s.Name)/$n"; A = $a; B = $b; Diff = [math]::Round($v, 2); Noise = $z; Flag = $v -gt [math]::Max(1.0, 2 * $z + 0.5) }
		}
	}
	$pairs = @($pairs | Sort-Object @{ Expression = { $_.Diff - $_.Noise }; Descending = $true })
	$flagged = @($pairs | Where-Object Flag)
	$head = @(
		"comparacion: $cur",
		"referencia:  $ref",
		"guiones: $(@($scripts).Count), iguales $same, con diferencias $($changed.Count)$(if ($changed.Count) { ': ' + ($changed -join ', ') })",
		"guiones inestables en la referencia (estado distinto entre sus dos pasadas, sin comparar su estado): $(if ($skipped.Count) { $skipped -join ', ' } else { 'ninguno' })",
		"capturas: $($pairs.Count), cambian mas que su ruido $($flagged.Count)$(if ($flagged.Count) { ': ' + (($flagged | ForEach-Object { "$($_.Key) ($($_.Diff))" }) -join ', ') })",
		""
	)
	Write-Lines "$cur\compare.txt" ($head + $txt)
	$h = @("<!doctype html><meta charset=utf-8><title>runall: $(Split-Path $cur -Leaf) / $(Split-Path $ref -Leaf)</title><style>body{background:#222;color:#ddd;font:13px sans-serif}img{width:480px;margin:2px}.f{color:#ff6}</style>")
	foreach ($p in $pairs) {
		$cls = if ($p.Flag) { " class=f" } else { "" }
		$h += "<p$cls>$($p.Key): diferencia $($p.Diff), ruido $($p.Noise)<br><img src=`"file:///$($p.A.Replace('\', '/'))`" title=ref> <img src=`"file:///$($p.B.Replace('\', '/'))`" title=nueva></p>"
	}
	Write-Lines "$cur\compare.html" $h
	Get-ChildItem "$cur\compare_*.png" -ErrorAction SilentlyContinue | Remove-Item
	for ($i = 0; $i -lt $flagged.Count; $i += 6) {
		$page = @($flagged[$i..([math]::Min($i + 5, $flagged.Count - 1))])
		$l = [string[]]@($page | ForEach-Object { if (Test-Path $_.A) { $_.A } else { "" } })
		$r = [string[]]@($page | ForEach-Object { if (Test-Path $_.B) { $_.B } else { "" } })
		$t = [string[]]@($page | ForEach-Object { "$($_.Key)  diferencia $($_.Diff)  ruido $($_.Noise)" })
		[RunAll]::Sheet("$cur\compare_$([int]($i / 6) + 1).png", $l, $r, $t, 480, 270)
	}
	$head | ForEach-Object { Write-Host $_ }
	Write-Host "detalle: $cur\compare.txt, $cur\compare.html$(if ($flagged.Count) { ", $cur\compare_*.png" })"
}

$scripts = @(Get-Scripts)
if ($scripts.Count -eq 0) { throw "ningun guion con -Filter '$Filter'" }
$dest = Get-Dir $Label
if ($Reclean) {
	Invoke-Reclean $dest
	if ($Reference) { Invoke-Reclean "$dest.2" }
} elseif (-not $CompareOnly) {
	Invoke-Run $dest $scripts
	if ($Reference) { Invoke-Run "$dest.2" $scripts }
}
# con -CompareOnly o -Reclean, -Reference solo vuelve a sacar las lineas inestables de las dos pasadas que ya hay
if ($Reference) { Write-Unstable $dest "$dest.2" }
if ($Ref) { Write-Compare $dest (Get-Dir $Ref) $scripts }
