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

	static function list( info : SaveInfo ) : Array<DeathDropInfo> {
		if( info.deathDrops == null ) info.deathDrops = [];
		return info.deathDrops;
	}

	static inline function wrap( v : Float, s : Int ) : Float {
		var l = v % s;
		return l < 0 ? l + s : l;
	}

	/**
	 * Al empezar el fundido de la muerte (manual = false) o de Mayus+K: todo el equipo pasa a un contenedor guardado en la
	 * partida y el inventario queda vacio. El contenedor se ve al acabar el fundido (spawn): antes el jugador sigue al lado y lo
	 * recogeria. null si no hay nada que dejar o no toca dejarlo.
	 */
	public static function leave( g : GameView, manual : Bool ) : DeathDropInfo {
		var info = g.info;
		if( !enabled(info) || g.creative || info.tuto != null || g.hangar != null || info.mothership == true || g.ship == null ) return null;
		var aboard = g.pz >= World.SHIP_Z;
		if( manual && aboard ) return null;
		var inv = g.inv.inv;
		var t = [for( s in inv.t ) s == null || s.n <= 0 ? null : { k : s.k, n : s.n }];
		var charges = [for( c in inv.charges ) if( c.n > 0 ) { c : c.c, n : c.n }];
		if( charges.length == 0 && !Lambda.exists(t, s -> s != null) ) return null;
		var l = list(info), id = 1;
		for( d in l ) if( d.id >= id ) id = d.id + 1;
		var w = g.world;
		var d : DeathDropInfo = {
			id : id,
			key : aboard ? "s" : planetKey(info),
			x : aboard ? wrap(g.px - w.shipDX, w.size) : g.px,
			y : aboard ? wrap(g.py - w.shipDY, w.size) : g.py,
			z : g.pz + 0.5,
			t : t,
			charges : charges,
		};
		l.push(d);
		for( i in 0...inv.t.length ) inv.t[i] = null;
		inv.charges.splice(0, inv.charges.length);
		g.inv.select(0);
		g.inv.display();
		return d;
	}

	/** los contenedores de este sitio, al empezar a jugar en el (GameView): el planeta o la cometa y la nave */
	public static function spawnAll( g : GameView ) {
		if( g.info.deathDrops == null ) return;
		// uno vacio no se podria recoger nunca (p. ej. solo llevaba kubes del editor y una version sin ellos lo ha guardado)
		g.info.deathDrops = g.info.deathDrops.filter(d -> !isEmpty(d));
		for( d in g.info.deathDrops ) spawn(g, d);
	}

	/** pone el contenedor d en el mundo si es de aqui */
	public static function spawn( g : GameView, d : DeathDropInfo ) {
		var w = g.world, x = d.x, y = d.y;
		if( d.key == "s" ) {
			if( g.ship == null || g.hangar != null || g.info.mothership == true ) return;
			x += w.shipDX;
			y += w.shipDY;
		} else if( d.key != planetKey(g.info) || g.ship == null || g.info.mothership == true ) return;
		else if( w.solid(Math.floor(x), Math.floor(y), Math.floor(d.z)) ) {
			// anadido del port: dentro de algo solido (ver GameView), sube a la superficie y se guarda alli
			d.z = w.topCollide(Math.floor(x), Math.floor(y)) + 0.01;
		}
		var drop = g.drops.add(wrap(x, w.size), wrap(y, w.size), d.z, block());
		// cae recto, sin la deriva al azar de lo que se suelta (Dummy): en el sitio exacto y en el mismo en cada carga
		drop.vx = drop.vy = 0;
		drop.loot = d;
		drop.time = Math.POSITIVE_INFINITY;
	}

	/** el contenedor ha caido o se ha movido: el guardado lo vuelve a poner ahi */
	public static function follow( g : GameView, drop : Drops.Drop ) {
		var d = drop.loot, w = g.world;
		// se ha caido de la nave (se murio fuera del casco, en el borde): ahora es del planeta y no se va con la nave
		if( d.key == "s" && drop.z < World.SHIP_Z ) d.key = planetKey(g.info);
		if( d.key == "s" ) {
			d.x = wrap(drop.x - w.shipDX, w.size);
			d.y = wrap(drop.y - w.shipDY, w.size);
		} else {
			d.x = drop.x;
			d.y = drop.y;
		}
		d.z = drop.z;
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

	/** orden `print deathdrops` (Dev): inventario, cargas, contenedores guardados y los que hay en el mundo */
	public static function devInfo( g : GameView ) : String {
		inline function r( v : Float ) return Math.round(v * 100) / 100;
		function items( t : Protocol.BlockInventory ) return [for( s in t ) s == null ? "-" : EditorKubes.label(Block.all[s.k]) + "x" + s.n].join(" ");
		function charges( c : Protocol.UserCharges ) return [for( x in c ) Type.enumConstructor(Type.createEnumIndex(ChargeKind, x.c)) + "x" + x.n].join(" ");
		var l = g.info.deathDrops == null ? [] : g.info.deathDrops;
		var live = [for( d in @:privateAccess g.drops.list ) if( d.loot != null ) d];
		return "opcion " + (enabled(g.info) ? "si" : "no") + " inv [" + items(g.inv.inv.t) + "] cargas [" + charges(g.inv.inv.charges) + "] creditos " + g.info.credits
			+ "\n  guardados " + l.length + ": " + [for( d in l ) "#" + d.id + " " + d.key + "@" + r(d.x) + "," + r(d.y) + "," + r(d.z) + " [" + items(d.t) + "] cargas [" + charges(d.charges) + "]"].join("  ")
			+ "\n  en el mundo " + live.length + ": " + [for( d in live ) "#" + d.loot.id + " " + d.block.k + "@" + r(d.x) + "," + r(d.y) + "," + r(d.z)].join("  ");
	}
}
