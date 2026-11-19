param([string]$Script, [int]$Timeout = 120, [string]$Extra = "", [string]$Data = "", [string]$OutFile = "", [string]$Shots = "")
# Uso: powershell -File port/dev/devrun.ps1 -Script port/dev/synth.txt   (ver Dev.hx para las ordenes). Necesita haber compilado port/game.hxml.
# -Data: carpeta de datos (port/out/testdata); -OutFile: salida del juego (port/out/dev_out.txt; los errores van al mismo nombre
# con .err.txt); -Shots: carpeta de las capturas del guion (port/out). runall.ps1 los usa para lanzar varios guiones a la vez.
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $repo
# con Haxe/HashLink portables junto al repositorio (si existen); si no, hl debe estar en el PATH
$env1 = "$repo\..\tools-portable\env.ps1"
if (Test-Path $env1) { . $env1 }
$env:GALAXY55_DATA = if ($Data) { $Data } else { "$repo\port\out\testdata" }
$env:GALAXY55_SHOTS = $Shots
$out = if ($OutFile) { $OutFile } else { "$repo\port\out\dev_out.txt" }
$err = if ($OutFile) { [IO.Path]::ChangeExtension($OutFile, ".err.txt") } else { "$repo\port\out\dev_err.txt" }
# como jugar.bat: galaxy55.exe (hl.exe con el icono del juego, port\tools\galaxy55_exe.ps1), asi la ventana de prueba lleva
# el icono y Discord no la toma por Half-Life. Se crea la primera vez; si no se puede, hl
$exe = "$repo\port\out\galaxy55.exe"
$hl = Get-Command hl -ErrorAction SilentlyContinue
if (-not (Test-Path $exe) -and $hl) { try { & "$repo\port\tools\galaxy55_exe.ps1" -Hl $hl.Source -Out $exe | Out-Null } catch {} }
$run = if (Test-Path $exe) { $exe } else { "hl" }
# la ventana de prueba se abre minimizada SIN activarse (SW_SHOWMINNOACTIVE) y sin consola (CREATE_NO_WINDOW). Con Start-Process
# -WindowStyle Minimized (SW_SHOWMINIMIZED) pasaba al primer plano al arrancar y se quedaba con el teclado de lo que se estuviera
# usando: Esc, WASD, E o Mayus llegaban al juego de prueba (el jugador andaba, excavaba, pausaba) y el guion fallaba a ratos.
# Ademas hlsdl muestra la ventana otra vez y la sube al crearla (sdl.c, win_create_ex: SDL_ShowWindow y SDL_RaiseWindow), que
# la activan salvo con estas pistas de SDL3 (se leen del entorno)
$env:SDL_WINDOW_ACTIVATE_WHEN_SHOWN = "0"
$env:SDL_WINDOW_ACTIVATE_WHEN_RAISED = "0"
# y el mando: hlsdl deja que llegue sin el foco (init_once: SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS = 1), asi que un mando usado
# en otro sitio tambien manejaba el juego de prueba; la variable de entorno puede mas que SDL_SetHint
$env:SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS = "0"
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class DevRun {
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	struct STARTUPINFO {
		public int cb; public string lpReserved, lpDesktop, lpTitle;
		public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
		public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
	}
	[StructLayout(LayoutKind.Sequential)]
	struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
	[StructLayout(LayoutKind.Sequential)]
	struct SECURITY_ATTRIBUTES { public int nLength; public IntPtr lpSecurityDescriptor; public bool bInheritHandle; }
	[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
	static extern bool CreateProcess(string app, System.Text.StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, int flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
	[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
	static extern IntPtr CreateFile(string name, uint access, int share, ref SECURITY_ATTRIBUTES sa, int disposition, int attrs, IntPtr template);
	[DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h, int ms);
	[DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr h, int code);
	[DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
	static IntPtr Output(string path) {
		var sa = new SECURITY_ATTRIBUTES { nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)), bInheritHandle = true };
		var h = CreateFile(path, 0x40000000 /* GENERIC_WRITE */, 3 /* FILE_SHARE_READ | WRITE */, ref sa, 2 /* CREATE_ALWAYS */, 0x80, IntPtr.Zero);
		if( h == new IntPtr(-1) ) throw new System.ComponentModel.Win32Exception();
		return h;
	}
	/** false si se acaba el tiempo (el proceso se cierra) */
	public static bool Run(string cmd, string dir, string outPath, string errPath, int timeoutMs) {
		IntPtr o = Output(outPath), e = Output(errPath);
		var si = new STARTUPINFO { cb = Marshal.SizeOf(typeof(STARTUPINFO)), dwFlags = 0x101 /* STARTF_USESHOWWINDOW | USESTDHANDLES */, wShowWindow = 7 /* SW_SHOWMINNOACTIVE */, hStdOutput = o, hStdError = e };
		PROCESS_INFORMATION pi;
		bool ok = CreateProcess(null, new System.Text.StringBuilder(cmd), IntPtr.Zero, IntPtr.Zero, true, 0x08000000 /* CREATE_NO_WINDOW */, IntPtr.Zero, dir, ref si, out pi);
		int err = Marshal.GetLastWin32Error();
		CloseHandle(o);
		CloseHandle(e);
		if( !ok ) throw new System.ComponentModel.Win32Exception(err);
		bool done = WaitForSingleObject(pi.hProcess, timeoutMs) == 0;
		if( !done ) TerminateProcess(pi.hProcess, 1);
		CloseHandle(pi.hThread);
		CloseHandle(pi.hProcess);
		return done;
	}
}
"@
if (-not [DevRun]::Run("`"$run`" port/out/galaxy55.hl --script=$Script $Extra", $repo, $out, $err, $Timeout * 1000)) { "TIMEOUT" }
Get-Content $out | Where-Object { $_ -notmatch '^(fondo|ruta|mundo)' }
$e = Get-Content $err -ErrorAction SilentlyContinue | Select-Object -First 8
if ($e) { "ERR: $e" }
