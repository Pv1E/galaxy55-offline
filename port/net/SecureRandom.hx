import haxe.io.Bytes;

/**
 * Azar para las claves del multijugador (anadido del port). HashLink no da el azar del sistema (Std.random se siembra con la hora
 * y el proceso: se adivina), asi que se mezclan en SHA-512:
 * - una semilla guardada (alea.bin en la carpeta de datos), que se renueva en cada arranque;
 * - la variacion de los tiempos de la CPU (QueryPerformanceCounter, miles de medidas);
 * - el azar del sistema cuando no hay semilla aun (la primera vez): /dev/urandom en Linux, RNGCryptoServiceProvider (PowerShell,
 *   ventana oculta) en Windows; si no se puede, solo lo anterior.
 * De la mezcla sale un flujo XSalsa20 que cambia de clave tras cada peticion (lo ya dado no se puede recalcular).
 */
class SecureRandom {

	static var key : Bytes;
	static var counter = 0;
	/** de donde salio el azar del sistema ("system", "seed" o "timings only"), para el registro */
	public static var source(default, null) = "";

	/** dir: carpeta donde guardar la semilla (la de las partidas o la del servidor) */
	public static function init( dir : String ) {
		var pool = new haxe.io.BytesBuffer();
		var seedFile = dir == null ? null : dir + "/alea.bin";
		var hadSeed = false;
		if( seedFile != null && sys.FileSystem.exists(seedFile) ) {
			try {
				pool.add(sys.io.File.getBytes(seedFile));
				hadSeed = true;
			} catch( e : Dynamic ) {}
		}
		var os = osEntropy(!hadSeed);
		if( os != null ) pool.add(os);
		pool.add(jitter(4096));
		pool.addDouble(Sys.time());
		pool.addDouble(Sys.cpuTime());
		pool.addDouble(haxe.Timer.stamp());
		for( _ in 0...8 ) pool.addInt32(Std.random(0x3FFFFFFF));
		var h = Nacl.sha512(pool.getBytes());
		key = h.sub(0, 32);
		counter = 0;
		source = os != null ? "system" : (hadSeed ? "seed" : "timings only");
		if( seedFile != null ) {
			var next = new haxe.io.BytesBuffer();
			next.add(h);
			next.add(Bytes.ofString("g55-semilla-siguiente"));
			try {
				sys.FileSystem.createDirectory(dir);
				sys.io.File.saveBytes(seedFile, Nacl.sha512(next.getBytes()));
			} catch( e : Dynamic ) {}
		}
	}

	/** n bytes al azar */
	public static function bytes( n : Int ) : Bytes {
		if( key == null ) init(null);
		var nonce = Bytes.alloc(24);
		nonce.fill(0, 24, 0);
		nonce.setInt32(0, counter++);
		nonce.setInt32(4, 0x47353521);
		var out = Bytes.alloc(n + 32);
		Nacl.xsalsa20Xor(out, 0, null, 0, n + 32, nonce, key);
		key = out.sub(n, 32);
		return out.sub(0, n);
	}

	/** entero al azar de 0 a max - 1 (sin sesgo) */
	public static function int( max : Int ) : Int {
		if( max <= 1 ) return 0;
		var limit = 0x7FFFFFFF - (0x7FFFFFFF % max);
		while( true ) {
			var v = bytes(4).getInt32(0) & 0x7FFFFFFF;
			if( v < limit ) return v % max;
		}
	}

	/** diferencias de tiempo de un trabajo que varia con la memoria y las interrupciones */
	static function jitter( n : Int ) : Bytes {
		var out = Bytes.alloc(n * 2);
		var work = new Array<Int>();
		var acc = 0;
		for( i in 0...n ) {
			var t0 = haxe.Timer.stamp();
			var k = 1 + (acc & 31);
			for( j in 0...k ) {
				work.push(acc + j);
				acc = (acc * 31 + work[(acc & 0x7FFFFFFF) % work.length]) | 0;
			}
			if( work.length > 4096 ) work = [];
			var dt = haxe.Timer.stamp() - t0;
			var v = Std.int((dt * 1e9) % 65536);
			out.setUInt16(i * 2, v ^ (acc & 0xFFFF));
		}
		return out;
	}

	/** azar del sistema: siempre en Linux; en Windows solo si force (lanza PowerShell, ~0,5 s) */
	static function osEntropy( force : Bool ) : Null<Bytes> {
		if( Sys.systemName() != "Windows" ) {
			try {
				var f = sys.io.File.read("/dev/urandom", true);
				var b = f.read(32);
				f.close();
				return b;
			} catch( e : Dynamic ) return null;
		}
		if( !force ) return null;
		try {
			var cmd = "$b=New-Object byte[] 32;[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($b);[Convert]::ToBase64String($b)";
			var p = new sys.io.Process("powershell", ["-NoProfile", "-NonInteractive", "-Command", cmd]);
			var s = StringTools.trim(p.stdout.readAll().toString());
			p.close();
			var b = haxe.crypto.Base64.decode(s);
			return b.length == 32 ? b : null;
		} catch( e : Dynamic ) return null;
	}
}
