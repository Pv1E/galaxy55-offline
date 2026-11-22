package gen;

/**
 * Anadido del port (generador version 1): el azar del generador, por nombre. Cada paso, cada estructura y cada bonus (cristales
 * de hexalita) tiene su propia suite (Generator.stream), hecha del hash de la semilla del planeta y de su nombre: anadir o
 * quitar algo no cambia el azar de lo demas (antes todo tiraba de una sola suite y una anomalia nueva cambiaba medio planeta).
 * La misma interfaz que mt.Rand (random, rand, sign, clone, getSeed) para no tocar las llamadas. Solo desplazamientos, XOR y
 * sumas de 32 bits (xorshift32 y djb2), sin multiplicaciones: da lo mismo en HashLink y en el GenMain de Flash.
 */
class Rng {

	var state : Int;

	public function new( seed : Int ) {
		state = seed == 0 ? 0x2545F491 : seed;
	}

	public inline function clone() : Rng {
		var r = new Rng(1);
		r.state = state;
		return r;
	}

	/** el estado (como mt.Rand.getSeed: para trazas) */
	public inline function getSeed() : Int return state;

	/** 0..2^30-1 */
	inline function int() : Int {
		var x = state;
		x ^= x << 13;
		x ^= x >>> 17;
		x ^= x << 5;
		state = x;
		return x & 0x3FFFFFFF;
	}

	/** 0..n-1; 0 si n <= 0 (mt.Rand dividia por cero) */
	public inline function random( n : Int ) : Int {
		return n <= 0 ? 0 : int() % n;
	}

	/** [0, 1), como mt.Rand */
	public inline function rand() : Float {
		return (int() % 10007) / 10007.0;
	}

	public inline function sign() : Int {
		return random(2) * 2 - 1;
	}

	/** mezcla de un entero (xorshift dos veces) */
	public static inline function mix( h : Int ) : Int {
		h ^= h << 13;
		h ^= h >>> 17;
		h ^= h << 5;
		h ^= h << 13;
		h ^= h >>> 17;
		h ^= h << 5;
		return h;
	}

	/** hash de un nombre a partir de h (djb2: h * 33 + c con desplazamiento y suma) */
	public static function hashString( h : Int, s : String ) : Int {
		for( i in 0...s.length )
			h = (h << 5) + h + StringTools.fastCodeAt(s, i);
		return h;
	}

	/** hash de una semilla, un nombre y hasta tres enteros: la semilla de una suite (nunca 0) */
	public static function hash( seed : Int, name : String, a = 0, b = 0, c = 0 ) : Int {
		var h = mix(seed ^ 0x5BD1E995);
		h = mix(hashString(h, name));
		h = mix(h + a);
		h = mix(h ^ (b + 0x3C6EF372));
		h = mix(h + (c ^ 0x1B873593));
		return h == 0 ? 1 : h;
	}
}
