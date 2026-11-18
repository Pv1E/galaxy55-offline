/** Localiza los graficos del original: carpeta `res/` junto al juego (paquete portatil) o, en el repositorio, `src/G55/fla/client/gfx/`.
    La variable GALAXY55_RES fuerza otra carpeta. */
class Res {
	static var dir:String;

	public static function path(name:String):String {
		if (dir == null) {
			var cands = [Sys.getEnv("GALAXY55_RES"), "res", "src/G55/fla/client/gfx"];
			dir = "res";
			for (c in cands)
				if (c != null && c != "" && sys.FileSystem.exists(c + "/texture.png")) {
					dir = c;
					break;
				}
		}
		return dir + "/" + name;
	}

	public static function bytes(name:String):haxe.io.Bytes {
		return sys.io.File.getBytes(path(name));
	}

	/** gráficos del explorador: res/explore_<nombre> o src/G55/fla/explore/gfx/<nombre> */
	public static function exploreBytes( name : String ) : haxe.io.Bytes {
		var p = "res/explore_" + name;
		if( !sys.FileSystem.exists(p) ) p = "src/G55/fla/explore/gfx/" + name;
		return sys.io.File.getBytes(p);
	}
}
