import SaveData.SaveInfo;
import SaveData.UniInfo;
import ExpData;

/**
 * Licencias de la ESCorp (anadido del port). En el original el servidor daba una licencia libre (ExploreInfos.freeLicense: sin
 * ella, "Pas de licence" al escanear) y los planetas se abandonaban desde la web (ADiscardPlanet); esa parte no se publico.
 * - Escanear un planeta gasta una licencia. En aventura hay MAX (1 principal y MAX - 1 de exploracion); en creativo no hay limite.
 * - El primer planeta escaneado pasa a ser el principal; con el tutorial, su planeta al acabarlo (Tutorial.finish). En aventura
 *   es el unico sobre el que se pilota la nave (GameView.pilotLicensed; en los demas el ordenador de a bordo no lo ofrece), y por
 *   tanto el unico en el que se elige donde aparece.
 * - Cambiar de principal: solo al planeta en el que estas, desde el ordenador de a bordo (Licencias de exploracion). Gratis la
 *   primera vez, luego MAIN_COST creditos; tras cada cambio hay que esperar MAIN_COOLDOWN segundos de hora real.
 * - Abandonar un planeta con licencia (ventana del mapa, con la nave a su lado; nunca el principal) libera la licencia y borra
 *   sus cambios: ya no se puede ir a el. Un sistema con todos sus planetas abandonados desaparece y deja otro cerca (UniInfo.gone).
 * Todo va en UniInfo, en campos opcionales: las partidas anteriores se completan al leerlas (migrate).
 */
class Licenses {

	public static inline var MAX = 4;
	public static inline var MAIN_COST = 1000;
	public static inline var MAIN_COOLDOWN = 24 * 3600;

	/** solo pruebas (Dev "licenses clock H"): segundos que se suman a la hora real */
	public static var devShift = 0.;

	public static function now() : Float return Sys.time() + devShift;

	/** partidas anteriores a las licencias: los planetas visitados tienen licencia y el inicial es el principal (con el tutorial
	    en curso aun no hay principal) */
	public static function migrate( uni : UniInfo, tuto : Bool ) {
		if( uni.licenses == null ) {
			uni.licenses = [uni.planetId];
			for( p in uni.planets ) if( uni.licenses.indexOf(p.id) < 0 ) uni.licenses.push(p.id);
			if( !tuto ) uni.main = uni.licenses.indexOf(0) >= 0 ? 0 : uni.planetId;
		}
		if( uni.abandoned == null ) uni.abandoned = [];
		if( uni.gone == null ) uni.gone = [];
		if( uni.mainChanges == null ) uni.mainChanges = 0;
	}

	public static inline function unlimited( info : SaveInfo ) return info.creative == true;

	public static function has( uni : UniInfo, id : Int ) return uni != null && uni.licenses != null && uni.licenses.indexOf(id) >= 0;

	public static function isMain( uni : UniInfo, id : Int ) return uni != null && uni.main == id;

	public static function isAbandoned( uni : UniInfo, id : Int ) return uni != null && uni.abandoned != null && uni.abandoned.indexOf(id) >= 0;

	/** se puede escanear un planeta nuevo (queda una licencia libre) */
	public static function canClaim( info : SaveInfo ) return unlimited(info) || info.uni.licenses.length < MAX;

	/** al aterrizar: el planeta gasta su licencia si aun no la tenia; el primero pasa a ser el principal (no en el tutorial) */
	public static function claim( info : SaveInfo, id : Int ) {
		var uni = info.uni;
		if( !has(uni, id) ) uni.licenses.push(id);
		if( uni.main == null && !Tutorial.active(info) ) uni.main = id;
	}

	/** al acabar el tutorial: su planeta, en el que estas, pasa a ser el principal */
	public static function tutorialDone( info : SaveInfo ) {
		var uni = info.uni;
		if( uni == null || uni.main != null ) return;
		if( !has(uni, uni.planetId) ) uni.licenses.push(uni.planetId);
		uni.main = uni.planetId;
	}

	/** precio del siguiente cambio de planeta principal: el primero es gratis */
	public static function mainPrice( uni : UniInfo ) return uni.mainChanges == null || uni.mainChanges == 0 ? 0 : MAIN_COST;

	/** segundos que faltan para poder cambiar otra vez de planeta principal (0 = ya se puede) */
	public static function cooldown( uni : UniInfo ) : Float return uni.mainTime == null ? 0 : Math.max(0, uni.mainTime + MAIN_COOLDOWN - now());

	/** hace de id (el planeta en el que estas, con licencia) el principal, cobrando a la ESCorp. null si se hizo; si no, el motivo */
	public static function setMain( info : SaveInfo, id : Int ) : String {
		var uni = info.uni;
		if( uni.main == null || uni.main == id || id != uni.planetId || !has(uni, id) ) return Lang.t("licenses.notyours");
		var wait = cooldown(uni);
		if( wait > 0 ) return Lang.t("licenses.wait").split("%t%").join(Lang.duration(wait));
		var price = mainPrice(uni);
		var credits = info.credits == null ? Market.START_CREDITS : info.credits;
		if( credits < price ) return Lang.t("licenses.nocredits").split("%n%").join("" + price);
		info.credits = credits - price;
		uni.main = id;
		uni.mainTime = now();
		uni.mainChanges = (uni.mainChanges == null ? 0 : uni.mainChanges) + 1;
		return null;
	}

	/**
	 * Abandonar el planeta p del sistema s: pierde su licencia, sus cambios y sus cantinas, y ya no se puede ir a el.
	 * true = era el ultimo planeta del sistema sin abandonar: el sistema desaparece (queda en gone; el que lo sustituye es newSystem).
	 */
	public static function abandon( info : SaveInfo, p : ExpPlanet, s : ExpSystem ) : Bool {
		var uni = info.uni;
		uni.licenses.remove(p.id);
		if( !isAbandoned(uni, p.id) ) uni.abandoned.push(p.id);
		uni.planets = uni.planets.filter(function(q) return q.id != p.id);
		// el planeta del que despegaste: sus cambios estan en la partida hasta aterrizar en otro
		if( uni.planetId == p.id ) {
			info.edits = [];
			info.shipAt = null;
		}
		if( info.chests != null ) info.chests = info.chests.filter(function(c) return !StringTools.startsWith(c.key, "p" + p.id + ":"));
		p.status = PAbandonned;
		if( Lambda.exists(s.planets, function(q) return !isAbandoned(uni, q.id)) ) return false;
		uni.gone.push(s.id);
		return true;
	}

	/** id del sistema que dejo el ultimo que desaparecio (ExpOffline.make los numera asi) */
	public static function newSystem( uni : UniInfo ) return ExpOffline.SYSTEMS + uni.gone.length - 1;

	/** los planetas con licencia (nombre en el idioma actual y bioma) */
	public static function planets( uni : UniInfo ) : Map<Int, ExpPlanet> {
		var d = ExpOffline.make(uni.seed, uni.start, null, null, null, uni.gone);
		var out = new Map();
		for( id in uni.licenses ) {
			var f = ExpOffline.planet(d, id);
			if( f != null ) out.set(id, f.p);
		}
		return out;
	}
}
