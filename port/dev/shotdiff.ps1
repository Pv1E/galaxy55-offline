param([Parameter(Mandatory)][string]$A, [Parameter(Mandatory)][string]$B, [Parameter(Mandatory)][string]$New, [int]$Tol = 24)
# Compara una captura nueva con la de referencia A sin contar los pixeles que ya cambian solos entre dos pasadas de referencia
# (A y B: cielo animado, particulas, temblor). Escribe "pixeles_distintos estables porcentaje". Uso: port/dev/baseline.ps1
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class ShotDiff {
	static byte[] Load(string path, out int w, out int h) {
		using (var bmp = new Bitmap(path)) {
			w = bmp.Width; h = bmp.Height;
			var d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
			var buf = new byte[d.Stride * h];
			Marshal.Copy(d.Scan0, buf, 0, buf.Length);
			bmp.UnlockBits(d);
			return buf;
		}
	}
	static int Diff(byte[] x, byte[] y, int i) {
		int m = 0;
		for (int c = 0; c < 3; c++) { int d = Math.Abs(x[i + c] - y[i + c]); if (d > m) m = d; }
		return m;
	}
	public static string Compare(string a, string b, string n, int tol) {
		int wa, ha, wb, hb, wn, hn;
		var pa = Load(a, out wa, out ha);
		var pb = Load(b, out wb, out hb);
		var pn = Load(n, out wn, out hn);
		if (wa != wn || ha != hn) return "-1 0 tamano_distinto";
		bool useB = wb == wa && hb == ha;
		long stable = 0, bad = 0;
		for (int i = 0; i < pa.Length; i += 4) {
			if (useB && Diff(pa, pb, i) > tol) continue;
			stable++;
			if (Diff(pa, pn, i) > tol) bad++;
		}
		double pct = stable == 0 ? 0 : 100.0 * bad / stable;
		return bad + " " + stable + " " + pct.ToString("0.000", System.Globalization.CultureInfo.InvariantCulture);
	}
}
"@
[ShotDiff]::Compare((Resolve-Path $A).Path, (Resolve-Path $B).Path, (Resolve-Path $New).Path, $Tol)
