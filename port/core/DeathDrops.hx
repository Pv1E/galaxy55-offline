import Common;
import SaveData.SaveInfo;

/** equipo que se quedo en el sitio al morir o al volver con Mayus+K (SaveInfo.deathDrops) */
typedef DeathDropInfo = {
	/** numero unico en la partida: las listas aparte del guardado (EditorKubes) lo usan como clave */
	var id : Int;
	/** "p<planeta>" en un planeta o una cometa (coordenadas del planeta); "s" a bordo de la nave (x, y de la nave, z del planeta) */
	var key : String;
	var x : Float;
	var y : Float;
	var z : Float;
	/** los bloques en las casillas que tenian en el inventario (con huecos): al recogerlos vuelven a ellas si estan libres */
	var t : Protocol.BlockInventory;
	var charges : Protocol.UserCharges;
}

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
 *   - nada en creativo, en el tutorial, en el hangar ni en la nave nodriza; Mayus+K a bordo de la nave tampoco (morir a bordo si)
 *   - es una opcion de la partida (SaveInfo.dropOnDeath, enabled), activada si no se cambia: sin ella, como en el modo local del
 *     original, no se pierde nada (los contenedores que ya hubiera se quedan y se pueden recoger)
 */
class DeathDrops {

	/** el bloque que se ve */
	public static function block() : Block return Block.get(BChest);

	/** la partida deja el equipo en el suelo (opcion de la partida; las partidas de antes de la opcion, si) */
	public static function enabled( info : SaveInfo ) : Bool return info.dropOnDeath != false;

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
