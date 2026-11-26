import Common;
import SaveData.SaveInfo;
import DeathDrops.DeathDropInfo;

/**
 * Lo de DeathDrops que necesita el juego en marcha (GameView, Drops): dejar el equipo, poner los contenedores en el mundo y
 * seguirlos. Separado de DeathDrops (port/core) para el multijugador (anadido del port).
 */
class DeathDropsPlay {

	/**
	 * Al empezar el fundido de la muerte (manual = false) o de Mayus+K: todo el equipo pasa a un contenedor guardado en la
	 * partida y el inventario queda vacio. El contenedor se ve al acabar el fundido (spawn): antes el jugador sigue al lado y lo
	 * recogeria. null si no hay nada que dejar o no toca dejarlo (a bordo de la nave, nunca: DeathDrops).
	 */
	public static function leave( g : GameView, manual : Bool ) : DeathDropInfo {
		var info = g.info;
		if( !DeathDrops.enabled(info) || g.creative || info.tuto != null || g.hangar != null || info.mothership == true || g.ship == null ) return null;
		if( g.pz >= World.SHIP_Z ) return null;
		var inv = g.inv.inv;
		var t = [for( s in inv.t ) s == null || s.n <= 0 ? null : { k : s.k, n : s.n }];
		var charges = [for( c in inv.charges ) if( c.n > 0 ) { c : c.c, n : c.n }];
		if( charges.length == 0 && !Lambda.exists(t, s -> s != null) ) return null;
		var l = DeathDrops.list(info), id = 1;
		for( d in l ) if( d.id >= id ) id = d.id + 1;
		var d : DeathDropInfo = {
			id : id,
			key : DeathDrops.planetKey(info),
			x : g.px,
			y : g.py,
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
		g.info.deathDrops = g.info.deathDrops.filter(d -> !DeathDrops.isEmpty(d));
		for( d in g.info.deathDrops ) spawn(g, d);
	}

	/** pone el contenedor d en el mundo si es de aqui */
	public static function spawn( g : GameView, d : DeathDropInfo ) {
		var w = g.world, x = d.x, y = d.y;
		if( d.key == "s" ) {
			if( g.ship == null || g.hangar != null || g.info.mothership == true ) return;
			x += w.shipDX;
			y += w.shipDY;
		} else if( d.key != DeathDrops.planetKey(g.info) || g.ship == null || g.info.mothership == true ) return;
		else if( w.solid(Math.floor(x), Math.floor(y), Math.floor(d.z)) ) {
			// anadido del port: dentro de algo solido (ver GameView), sube a la superficie y se guarda alli
			d.z = w.topCollide(Math.floor(x), Math.floor(y)) + 0.01;
		}
		var drop = g.drops.add(DeathDrops.wrap(x, w.size), DeathDrops.wrap(y, w.size), d.z, DeathDrops.block());
		// cae recto, sin la deriva al azar de lo que se suelta (Dummy): en el sitio exacto y en el mismo en cada carga
		drop.vx = drop.vy = 0;
		drop.loot = d;
		drop.time = Math.POSITIVE_INFINITY;
	}

	/** el contenedor ha caido o se ha movido: el guardado lo vuelve a poner ahi */
	public static function follow( g : GameView, drop : Drops.Drop ) {
		var d = drop.loot, w = g.world;
		// se ha caido de la nave (se murio fuera del casco, en el borde): ahora es del planeta y no se va con la nave
		if( d.key == "s" && drop.z < World.SHIP_Z ) d.key = DeathDrops.planetKey(g.info);
		if( d.key == "s" ) {
			d.x = DeathDrops.wrap(drop.x - w.shipDX, w.size);
			d.y = DeathDrops.wrap(drop.y - w.shipDY, w.size);
		} else {
			d.x = drop.x;
			d.y = drop.y;
		}
		d.z = drop.z;
	}

	/** orden `print deathdrops` (Dev): inventario, cargas, contenedores guardados y los que hay en el mundo */
	public static function devInfo( g : GameView ) : String {
		inline function r( v : Float ) return Math.round(v * 100) / 100;
		function items( t : Protocol.BlockInventory ) return [for( s in t ) s == null ? "-" : EditorKubes.label(Block.all[s.k]) + "x" + s.n].join(" ");
		function charges( c : Protocol.UserCharges ) return [for( x in c ) Type.enumConstructor(Type.createEnumIndex(ChargeKind, x.c)) + "x" + x.n].join(" ");
		var l = g.info.deathDrops == null ? [] : g.info.deathDrops;
		var live = [for( d in @:privateAccess g.drops.list ) if( d.loot != null ) d];
		return "opcion " + (DeathDrops.enabled(g.info) ? "si" : "no") + " inv [" + items(g.inv.inv.t) + "] cargas [" + charges(g.inv.inv.charges) + "] creditos " + g.info.credits
			+ "\n  guardados " + l.length + ": " + [for( d in l ) "#" + d.id + " " + d.key + "@" + r(d.x) + "," + r(d.y) + "," + r(d.z) + " [" + items(d.t) + "] cargas [" + charges(d.charges) + "]"].join("  ")
			+ "\n  en el mundo " + live.length + ": " + [for( d in live ) "#" + d.loot.id + " " + d.block.k + "@" + r(d.x) + "," + r(d.y) + "," + r(d.z)].join("  ");
	}
}
