import Common;
import SaveData.SaveInfo;
import SaveData.UniInfo;
import ExpData;

/**
 * Cometas (añadido del port): planetas pequeños (SIZE x SIZE) que aparecen a veces dentro de los sistemas solares.
 * - Cada sistema tiene franjas de SLOT segundos de hora real (Licenses.now), desplazadas de un sistema a otro. En cada franja,
 *   una tirada fija (semilla del sector, sistema y franja) le da una cometa con una probabilidad de 1 entre CHANCE. No se guarda
 *   nada por cometa: las partidas anteriores las tienen igual.
 * - Solo se ve dentro del sistema: no esta en ExpSystem.planets, asi que ni el sector ni las licencias la cuentan. Su id es
 *   sistema * 10 + ID, que ningun planeta usa (ExpOffline: sistema * 10 + 0..3).
 * - No gasta licencia ni puede ser el principal; escanearla es aterrizar. Al despegar se pierde (UniInfo.comets) con sus
 *   cambios y sus cantinas.
 * - En ella el tiempo esta contado (dockTime, segun la velocidad de la nave): al acabarse, el jugador vuelve a la nave y el
 *   teletransportador ya no baja (GameView.updateComet).
 * Cada tipo de cometa es un bioma (BICometCinder...) con su receta en CometGenerator: para anadir otro basta con su bioma en
 * DataGen, su nombre en Lang, su caso en CometGenerator y su entrada en KINDS.
 */
class Comets {

	public static inline var SIZE = 96;
	public static inline var SLOT = 2 * 3600;
	public static inline var CHANCE = 6;
	public static inline var ID = 9;
	/** tipos de cometa: su bioma */
	public static var KINDS = ["BICometCinder"];

	/** solo pruebas (Dev "comet here"): sistema con cometa en cualquier franja */
	public static var devForce = -1;

	public static function isComet( biome : String ) return KINDS.indexOf(biome) >= 0;

	public static inline function idOf( sys : Int ) return sys * 10 + ID;

	/** franja actual de un sistema: cada uno empieza las suyas en otro momento */
	public static function slot( seed : Int, sys : Int, now : Float ) : Int {
		var phase = rand(seed, sys, -1).random(SLOT);
		return Math.floor((now + phase) / SLOT);
	}

	static function rand( seed : Int, sys : Int, slot : Int ) : mt.Rand {
		var r = new mt.Rand(0);
		r.initSeed(Const.quickHash(seed, sys + 1, slot));
		return r;
	}

	/** la cometa del sistema ahora mismo (null si no tiene o ya se visito) */
	public static function of( uni : UniInfo, s : ExpSystem ) : ExpPlanet {
		var k = slot(uni.seed, s.id, Licenses.now());
		if( visited(uni, s.id, k) ) return null;
		var r = rand(uni.seed, s.id, k);
		if( !draw(r) && s.id != devForce ) return null;
		return {
			id : idOf(s.id), seed : r.random(1000000), size : 1, distance : -1, name : Lang.t("exp.comet"), status : PUnexplored, gas : false,
			biome : KINDS[r.random(KINDS.length)], comet : k,
		};
	}

	/** el sistema tiene cometa en la franja k (aunque ya se visitara) */
	public static function drawn( seed : Int, sys : Int, k : Int ) : Bool return draw(rand(seed, sys, k));

	/** 1 de CHANCE. Con random(CHANCE) == 0, mt.Rand en HashLink (enteros de 32 bits) daba 1 de 6,2; asi, 1 de 6,0 */
	static inline function draw( r : mt.Rand ) : Bool return r.random(CHANCE * 1000) < 1000;

	/** UniInfo.comets: pares [sistema, franja] de las cometas ya visitadas */
	static function visited( uni : UniInfo, sys : Int, k : Int ) : Bool {
		var l = uni.comets;
		if( l == null ) return false;
		var i = 0;
		while( i + 1 < l.length ) {
			if( l[i] == sys && l[i + 1] == k ) return true;
			i += 2;
		}
		return false;
	}

	/** al despegar de una cometa: ya no vuelve; se olvidan las de franjas pasadas, que ya no pueden salir */
	public static function leave( info : SaveInfo ) {
		var c = info.comet, uni = info.uni;
		info.comet = null;
		if( c == null || uni == null ) return;
		var l = uni.comets != null ? uni.comets : [];
		var keep = [];
		var i = 0;
		while( i + 1 < l.length ) {
			if( l[i + 1] >= slot(uni.seed, l[i], Licenses.now()) ) {
				keep.push(l[i]);
				keep.push(l[i + 1]);
			}
			i += 2;
		}
		keep.push(c.sys);
		keep.push(c.slot);
		uni.comets = keep;
		// sus cambios y sus cantinas se tiran; la nave sigue en el sistema
		var key = "p" + idOf(c.sys) + ":";
		if( info.chests != null ) info.chests = info.chests.filter(function(ch) return !StringTools.startsWith(ch.key, key));
		info.edits = [];
		info.shipAt = null;
		uni.pos = [1, c.sys];
	}

	/**
	 * Tiempo en la cometa (s) segun la velocidad de la nave (PC/s, la del hangar): 1:30 a 0,2 o menos; 45 s mas por cada 0,1
	 * hasta 0,5 y 30 s mas por cada 0,1 despues, como mucho 15:00. Entre dos pasos sigue la velocidad (0,25 -> 1:52).
	 */
	public static function dockTime( speed : Float ) : Int {
		var t = speed <= 0.5 ? 90 + (speed - 0.2) * 450 : 225 + (speed - 0.5) * 300;
		return t < 90 ? 90 : (t > 900 ? 900 : Math.round(t));
	}

	/** m:ss */
	public static function clock( secs : Float ) : String {
		var s = Math.ceil(secs);
		if( s < 0 ) s = 0;
		return Std.int(s / 60) + ":" + StringTools.lpad("" + (s % 60), "0", 2);
	}
}
