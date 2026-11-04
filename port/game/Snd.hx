/** Efectos de sonido, copia de Sfx.hx del original (mismos .wav de src/G55/fla/client/sfx, mismo volumen general 0.3).
    Busca res/sfx_<nombre>.wav (paquete portatil) o la carpeta del repositorio. Si no hay audio, no suena y sigue. */
class Snd {
	public static var VOLUME = 0.3;
	static var cache = new Map<String, hxd.res.Sound>();
	static var broken = false;
	/** veces que se ha pedido cada sonido, aunque no haya audio (para los guiones de prueba: print snd) */
	public static var played = new Map<String, Int>();

	static function get( name : String ) : hxd.res.Sound {
		var s = cache.get(name);
		if( s != null || cache.exists(name) ) return s;
		try {
			var p = "res/sfx_" + name + ".wav";
			if( !sys.FileSystem.exists(p) ) p = "src/G55/fla/client/sfx/" + name + ".wav";
			s = hxd.res.Any.fromBytes(name + ".wav", sys.io.File.getBytes(p)).toSound();
		} catch( e : Dynamic ) s = null;
		cache.set(name, s);
		return s;
	}

	public static function play( name : String, vol = 1.0, loop = false ) : hxd.snd.Channel {
		var n = played.get(name);
		played.set(name, n == null ? 1 : n + 1);
		if( broken ) return null;
		var s = get(name);
		if( s == null ) return null;
		try {
			applyVolume();
			return s.play(loop, vol * VOLUME);
		} catch( e : Dynamic ) {
			broken = true;
			return null;
		}
	}

	/** volumen de Opciones (Settings.volume, 0-100) como volumen maestro: vale para todos los canales, tambien los bucles
	    que ya suenan (jetpack, laser), y a 0 no suena nada */
	public static function applyVolume() {
		if( broken ) return;
		try hxd.snd.Manager.get().masterVolume = Settings.volume / 100 catch( e : Dynamic ) broken = true;
	}
}
