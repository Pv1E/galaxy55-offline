/**
 * Azar de las reglas del juego (anadido del port para el multijugador). En solo es Std.random / Math.random; con
 * --rngseed=N (pruebas) la semilla de HashLink queda fija, asi un guion tira los mismos dados en cada pasada.
 * En el servidor, las reglas usan este azar y nunca el del cliente.
 */
class GameRng {

	/** --rngseed=N de la linea de ordenes: fija la semilla de Std.random y Math.random */
	public static function applyArgs() {
		for( a in Sys.args() )
			if( StringTools.startsWith(a, "--rngseed=") ) seed(Std.parseInt(a.substr(10)));
	}

	public static function seed( s : Int ) {
		#if hl
		setSeed(@:privateAccess Std.rnd, s);
		#end
	}

	public static inline function int( n : Int ) : Int return Std.random(n);

	public static inline function float() : Float return Math.random();

	#if hl
	@:hlNative("std", "rnd_set_seed") static function setSeed( r : hl.Abstract<"hl_random">, s : Int ) : Void {}
	#end
}
