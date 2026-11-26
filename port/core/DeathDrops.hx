import Common;
import SaveData.SaveInfo;

/** equipo que se quedo en el sitio al morir o al volver con Mayus+K (SaveInfo.deathDrops) */
typedef DeathDropInfo = {
	/** numero unico en la partida: las listas aparte del guardado (EditorKubes) lo usan como clave */
	var id : Int;
	/** "p<planeta>" en un planeta o una cometa (coordenadas del planeta); "s" a bordo de la nave (x, y de la nave, z del planeta):
	    ya no se crean (morir a bordo no deja nada), los que haya en las partidas se quedan y se recogen igual */
	var key : String;
	var x : Float;
	var y : Float;
	var z : Float;
	/** los bloques en las casillas que tenian en el inventario (con huecos): al recogerlos vuelven a ellas si estan libres */
	var t : Protocol.BlockInventory;
	var charges : Protocol.UserCharges;
}

/** que pasa con el equipo al morir o con Mayus+K (DeathDrops.fate) */
enum abstract GearFate(Int) to Int {
	/** nada: no toca perder nada aqui o asi (a bordo, sin la opcion, creativo...) o no se lleva nada; no se gasta nada */
	var GNothing = 0;
	/** se queda todo: sauvegarde d'equipement de las cometas (EscorpUpgrades.KEEP_COMET) */
	var GKeptComet = 1;
	/** se queda todo: sauvegarde d'equipement del planeta principal (EscorpUpgrades.KEEP_MAIN) */
	var GKeptMain = 2;
	/** se queda todo gastando una bouee (EscorpUpgrades.BUOY) */
	var GKeptBuoy = 3;
	/** todo cae en un contenedor */
	var GDropped = 4;
}

/**
 * Donde se muere (o se pulsa Mayus+K), para DeathDrops.fate: en el juego, DeathDropsPlay.spot; en el servidor, ServerItems.death.
 *   aboard: a bordo de la nave (a su altura, encima de cualquier planeta o cometa)
 *   exempt: aqui o asi no se pierde nada: creativo, hangar, nave nodriza, visitante en multijugador, opcion del servidor apagada
 *   planet: el planeta propio en el que se esta (id en la galaxia del jugador); null en el de otro jugador
 */
typedef GearSpot = { aboard : Bool, exempt : Bool, planet : Null<Int> };

/**
 * Lo que se pierde al morir o al volver a la nave con Mayus+K (anadido del port; en el original lo decidia el servidor y el modo
 * local no quitaba nada). Game.returnToShip mandaba CReturnShip y el servidor contestaba con un botin (SAddLoot): un solo
 * Dummy, el bloque pequeno que gira como lo que se suelta al romper, dibujado con el bloque que elegia el servidor (LootInfos.k)
 * y con todos los bloques y cargas, sin limite de casillas. Se recogia al pasar al lado (lo que cabe; el resto se queda dentro).
 * Aqui:
 *   - es un Conteneur ESCorp pequeno (BChest) que cae y gira donde se murio o se pulso Mayus+K, aunque sea en un liquido
 *   - se lleva todos los bloques (gemas incluidas) y todas las cargas; los creditos no (son de la tienda)
 *   - no caduca (el original si, con un tiempo del servidor que se ha perdido): se guarda en la partida y solo desaparece al
 *     vaciarlo o con su planeta (abandonado: Licenses.abandon; cometa dejada: Comets.leave)
 *   - nada en creativo, en el tutorial, en el hangar ni en la nave nodriza; a bordo de la nave tampoco, encima de cualquier
 *     planeta o cometa: ni Mayus+K ni morir alli cuentan para el equipo (cambio del port: antes morir a bordo dejaba un
 *     contenedor en la nave, clave "s"; los que quedan en las partidas se recogen como siempre)
 *   - es una opcion de la partida (SaveInfo.dropOnDeath, enabled), activada si no se cambia: sin ella, como en el modo local del
 *     original, no se pierde nada (los contenedores que ya hubiera se quedan y se pueden recoger)
 *   - las mejoras de la ESCorp lo evitan (fate): las sauvegardes d'equipement de las cometas y del planeta principal y las bouees
 */
class DeathDrops {

	/** el bloque que se ve */
	public static function block() : Block return Block.get(BChest);

	/** la partida deja el equipo en el suelo (opcion de la partida; las partidas de antes de la opcion, si) */
	public static function enabled( info : SaveInfo ) : Bool return info.dropOnDeath != false;

	/**
	 * Que pasa con el equipo al morir o con Mayus+K, en una sola regla para el juego y el servidor, por orden:
	 *   1. a bordo de la nave: nada (ni contenedor, ni bouee, ni sauvegarde)
	 *   2. exento (spot.exempt), sin la opcion de la partida, en el tutorial o sin nada encima (ni bloques ni cargas): nada
	 *   3. en una cometa (SaveInfo.comet) con KEEP_COMET encendida: se queda todo
	 *   4. en el planeta principal, el de KEEP_MAIN, con ella encendida (no en una cometa): se queda todo
	 *   5. con una bouee: se queda todo y se gasta una (decide)
	 *   6. el contenedor (DeathDropsPlay.leave, ServerItems.death)
	 * inv: el inventario que se llevaria (el del juego es una copia del de la partida)
	 */
	public static function fate( info : SaveInfo, inv : Protocol.InventoryInfos, spot : GearSpot ) : GearFate {
		if( spot.aboard ) return GNothing;
		if( spot.exempt || !enabled(info) || info.tuto != null || !hasGear(inv) ) return GNothing;
		if( info.comet != null ) {
			if( EscorpUpgrades.isOn(info, EscorpUpgrades.KEEP_COMET) ) return GKeptComet;
		} else if( spot.planet != null && info.uni != null && spot.planet == info.uni.main && EscorpUpgrades.isOn(info, EscorpUpgrades.KEEP_MAIN) )
			return GKeptMain;
		if( EscorpUpgrades.buoys(info) > 0 ) return GKeptBuoy;
		return GDropped;
	}

	/** fate y, si es una bouee, la gasta: el juego y el servidor lo llaman una vez por muerte o Mayus+K */
	public static function decide( info : SaveInfo, inv : Protocol.InventoryInfos, spot : GearSpot ) : GearFate {
		var f = fate(info, inv, spot);
		if( f == GKeptBuoy ) EscorpUpgrades.useBuoy(info);
		return f;
	}

	/** lleva algo que dejar: un bloque o una carga */
	public static function hasGear( inv : Protocol.InventoryInfos ) : Bool {
		if( inv == null ) return false;
		for( s in inv.t ) if( s != null && s.n > 0 ) return true;
		for( c in inv.charges ) if( c.n > 0 ) return true;
		return false;
	}

	/** clave de un planeta: la de las cantinas sin la celda (GameView.chestKey) */
	public static function planetKey( info : SaveInfo ) : String return "p" + (info.uni != null ? info.uni.planetId : 0);

	public static function list( info : SaveInfo ) : Array<DeathDropInfo> {
		if( info.deathDrops == null ) info.deathDrops = [];
		return info.deathDrops;
	}

	public static inline function wrap( v : Float, s : Int ) : Float {
		var l = v % s;
		return l < 0 ? l + s : l;
	}


	/** Dummy.canGet de SAddLoot: cabe algo de lo que tiene */
	public static function canGet( inv : Inv, d : DeathDropInfo ) : Bool {
		for( s in d.t ) if( s != null && inv.canAddBlock(Block.all[s.k]) ) return true;
		for( c in d.charges ) if( inv.canCharge(Type.createEnumIndex(ChargeKind, c.c)) ) return true;
		return false;
	}

	/**
	 * Dummy.get de SAddLoot: pasa al inventario lo que cabe y el resto se queda dentro. Cambio del port: cada pila vuelve antes a
	 * la casilla que tenia si esta libre (la barra queda como estaba); si no, entra como un bloque recogido. true si entro algo
	 */
	public static function take( inv : Inv, d : DeathDropInfo ) : Bool {
		var got = false, t = inv.inv.t;
		for( i in 0...d.t.length ) {
			var s = d.t[i];
			if( s == null || i >= t.length || t[i] != null ) continue;
			var n = Std.int(Math.min(s.n, Block.all[s.k].getMax(inv.inv.maxWeight)));
			if( n <= 0 ) continue;
			t[i] = { k : s.k, n : n };
			s.n -= n;
			got = true;
		}
		for( i in 0...d.t.length ) {
			var s = d.t[i];
			if( s == null ) continue;
			if( s.n > 0 ) {
				var n = inv.addBlocks(Block.all[s.k], s.n);
				if( n > 0 ) {
					s.n -= n;
					got = true;
				}
			}
			if( s.n <= 0 ) d.t[i] = null;
		}
		for( c in d.charges.copy() ) {
			var n = inv.addCharge(Type.createEnumIndex(ChargeKind, c.c), c.n);
			if( n > 0 ) {
				c.n -= n;
				got = true;
			}
			if( c.n <= 0 ) d.charges.remove(c);
		}
		if( got ) inv.display();
		return got;
	}

	public static function isEmpty( d : DeathDropInfo ) : Bool return d.charges.length == 0 && !Lambda.exists(d.t, s -> s != null);

	/** vaciado: sale de la partida */
	public static function done( info : SaveInfo, d : DeathDropInfo ) {
		if( info.deathDrops != null ) info.deathDrops.remove(d);
	}

	/** su planeta se pierde (abandonado, cometa dejada): sus contenedores tambien */
	public static function forget( info : SaveInfo, key : String ) {
		if( info.deathDrops != null ) info.deathDrops = info.deathDrops.filter(d -> d.key != key);
	}

	/** SaveInfo.deathDrops de una partida leida de disco */
	public static function read( o : Dynamic ) : Array<DeathDropInfo> {
		try {
			if( o == null ) return null;
			var out = [];
			for( d in (o : Array<Dynamic>) ) {
				if( d == null || d.key == null || d.t == null ) continue;
				out.push({
					id : d.id != null ? Std.int(d.id) : out.length + 1,
					key : Std.string(d.key),
					x : (d.x : Float), y : (d.y : Float), z : (d.z : Float),
					t : [for( s in (d.t : Array<Dynamic>) ) s == null ? null : { k : Std.int(s.k), n : Std.int(s.n) }],
					charges : d.charges == null ? [] : [for( c in (d.charges : Array<Dynamic>) ) { c : Std.int(c.c), n : Std.int(c.n) }],
				});
			}
			return out;
		} catch( e : Dynamic ) {
			return null;
		}
	}

}
