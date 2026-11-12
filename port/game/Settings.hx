/** Ajustes del jugador, guardados en %APPDATA%\Galaxy55\settings.json */
class Settings {

	public static var lang = "es";
	public static var mouseSens = 1.0;
	public static var fov = 70;
	public static var volume = 80;
	public static var fullscreen = false;
	public static var invertY = false;
	/** true: A/D y flechas izquierda/derecha giran al personaje (como el original); false: se desplaza de lado */
	public static var turnKeys = false;
	/** ayuda de controles en pantalla (arriba a la izquierda) */
	public static var showHelp = true;
	/** sombra del bloque de la mano en la celda donde se pondra */
	public static var placePreview = true;
	/** marco de seleccion: el bloque apuntado (mano vacia) o la celda donde se pondra el de la mano */
	public static var selectBox = true;
	/** olas del agua (animWater del original, que las quitaba sin aceleracion grafica): se aplica al momento */
	public static var waterWaves = true;
	/** nombre del bloque apuntado, pequeno en una esquina */
	public static var targetName = true;
	/** sincronizacion vertical (sin ella los FPS solo los limita maxFps) */
	public static var vsync = true;
	/** limite de fotogramas por segundo (0 = sin limite) */
	public static var maxFps = 0;
	public static var FPS_STEPS = [0, 30, 60, 120, 144, 240];
	/** primera vez que se abre el juego (no habia settings.json): se pregunta el idioma */
	public static var firstRun = false;

	public static function dir() : String {
		var base = Sys.getEnv("GALAXY55_DATA");
		if( base == null || base == "" ) base = Sys.getEnv("APPDATA");
		if( base == null || base == "" ) base = Sys.getEnv("HOME");
		if( base == null || base == "" ) base = ".";
		var d = base + "/Galaxy55";
		if( !sys.FileSystem.exists(d) ) sys.FileSystem.createDirectory(d);
		return d;
	}

	public static function load() {
		var path = dir() + "/settings.json";
		if( !sys.FileSystem.exists(path) ) {
			firstRun = true;
			return;
		}
		try {
			var o : Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
			if( o.lang != null ) lang = o.lang;
			if( o.mouseSens != null ) mouseSens = o.mouseSens;
			if( o.fov != null ) fov = o.fov;
			if( o.volume != null ) volume = o.volume;
			if( o.fullscreen != null ) fullscreen = o.fullscreen;
			if( o.invertY != null ) invertY = o.invertY;
			if( o.turnKeys != null ) turnKeys = o.turnKeys;
			if( o.showHelp != null ) showHelp = o.showHelp;
			if( o.placePreview != null ) placePreview = o.placePreview;
			if( o.selectBox != null ) selectBox = o.selectBox;
			if( o.waterWaves != null ) waterWaves = o.waterWaves;
			if( o.targetName != null ) targetName = o.targetName;
			if( o.vsync != null ) vsync = o.vsync;
			if( o.maxFps != null ) maxFps = Std.int(o.maxFps);
		} catch( e : Dynamic ) {}
		Lang.setCode(lang);
	}

	public static function save() {
		var o = { lang : lang, mouseSens : mouseSens, fov : fov, volume : volume, fullscreen : fullscreen, invertY : invertY, turnKeys : turnKeys, showHelp : showHelp, placePreview : placePreview, selectBox : selectBox, waterWaves : waterWaves, targetName : targetName, vsync : vsync, maxFps : maxFps };
		try sys.io.File.saveContent(dir() + "/settings.json", haxe.Json.stringify(o, null, "  ")) catch( e : Dynamic ) {}
	}
}
