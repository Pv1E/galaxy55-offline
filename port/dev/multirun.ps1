param([Parameter(Mandatory)][string]$ScriptList, [int]$Timeout = 300, [string]$Hl = "port/out/galaxy55.hl", [string]$Extra = "--rngseed=1")
# Multijugador (anadido del port): varios juegos de prueba a la vez, cada uno con su guion y su carpeta de datos (y por tanto su
# identidad, identite.g55), minimizados y sin quitar el foco, como port/dev/devrun.ps1. Escribe la salida de cada uno.
# Uso: powershell -File port/dev/multirun.ps1 -ScriptList port/dev/mp_host.txt,port/dev/mp_guest.txt
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $repo
$Scripts = @($ScriptList.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
$env1 = "$repo\..\tools-portable\env.ps1"
if (Test-Path $env1) { . $env1 }
$env:SDL_WINDOW_ACTIVATE_WHEN_SHOWN = "0"
$env:SDL_WINDOW_ACTIVATE_WHEN_RAISED = "0"
$env:SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS = "0"
$hlExe = (Get-Command hl).Source
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class MultiRun {
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	struct STARTUPINFO {
		public int cb; public string lpReserved, lpDesktop, lpTitle;
		public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
		public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
	}
	[StructLayout(LayoutKind.Sequential)]
	public struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
	[StructLayout(LayoutKind.Sequential)]
	struct SECURITY_ATTRIBUTES { public int nLength; public IntPtr lpSecurityDescriptor; public bool bInheritHandle; }
	[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
	static extern bool CreateProcess(string app, System.Text.StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, int flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
	[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
	static extern IntPtr CreateFile(string name, uint access, int share, ref SECURITY_ATTRIBUTES sa, int disposition, int attrs, IntPtr template);
	[DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr h, int ms);
	[DllImport("kernel32.dll")] public static extern bool TerminateProcess(IntPtr h, int code);
	[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
	static IntPtr Output(string path) {
		var sa = new SECURITY_ATTRIBUTES { nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)), bInheritHandle = true };
		var h = CreateFile(path, 0x40000000, 3, ref sa, 2, 0x80, IntPtr.Zero);
		if( h == new IntPtr(-1) ) throw new System.ComponentModel.Win32Exception();
		return h;
	}
	public static PROCESS_INFORMATION Start(string cmd, string dir, string outPath, string errPath) {
		IntPtr o = Output(outPath), e = Output(errPath);
		var si = new STARTUPINFO { cb = Marshal.SizeOf(typeof(STARTUPINFO)), dwFlags = 0x101, wShowWindow = 7, hStdOutput = o, hStdError = e };
		PROCESS_INFORMATION pi;
		bool ok = CreateProcess(null, new System.Text.StringBuilder(cmd), IntPtr.Zero, IntPtr.Zero, true, 0x08000000, IntPtr.Zero, dir, ref si, out pi);
		int err = Marshal.GetLastWin32Error();
		CloseHandle(o);
		CloseHandle(e);
		if( !ok ) throw new System.ComponentModel.Win32Exception(err);
		return pi;
	}
}
"@
$out = "$repo\port\out\multirun"
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null
$procs = @()
for ($i = 0; $i -lt $Scripts.Count; $i++) {
	$data = "$out\data$i"
	New-Item -ItemType Directory -Force $data | Out-Null
	$env:GALAXY55_DATA = $data
	$procs += [MultiRun]::Start("`"$hlExe`" $Hl --script=$($Scripts[$i]) $Extra", $repo, "$out\out$i.txt", "$out\err$i.txt")
}
$deadline = (Get-Date).AddSeconds($Timeout)
for ($i = 0; $i -lt $procs.Count; $i++) {
	$left = [int][Math]::Max(0, ($deadline - (Get-Date)).TotalMilliseconds)
	if ([MultiRun]::WaitForSingleObject($procs[$i].hProcess, $left) -ne 0) { [void][MultiRun]::TerminateProcess($procs[$i].hProcess, 1); "TIMEOUT $i ($($Scripts[$i]))" }
	[void][MultiRun]::CloseHandle($procs[$i].hThread)
	[void][MultiRun]::CloseHandle($procs[$i].hProcess)
}
for ($i = 0; $i -lt $Scripts.Count; $i++) {
	"===== $i $($Scripts[$i])"
	Get-Content "$out\out$i.txt" | Where-Object { $_ -notmatch '^(fondo|ruta|mundo)' }
	$e = Get-Content "$out\err$i.txt" -ErrorAction SilentlyContinue | Select-Object -First 8
	if ($e) { "ERR: $e" }
}
