import Common;
import Msg;
import Protocol;
import GameServer.Session;

/**
 * La nave de un jugador en el servidor (anadido del port para el multijugador). Cada uno tiene la suya, que no se comparte:
 * sus celdas (el plano de la partida, ShipData, y sus cambios, SaveInfo.shipEdits), las zonas del sintetizador, los sueltos,
 * las cantinas (claves "s:x,y,z" de SaveInfo.chests) y el stockage. A bordo solo se cambian las zonas del sintetizador
 * (poner y quitar), y se mueven cosas entre el inventario, las cantinas y el stockage: todo pasa por aqui con las mismas
 * cuentas que en el planeta, asi que nada se crea ni se pierde. Coordenadas: las de la nave (como ShipData), z sin SHIP_Z.
 * Los sueltos de a bordo no tienen fisica aqui: los mueve el cliente (es su nave) y el servidor solo lleva lo que hay; como
 * en solo, se pierden al despegar o aterrizar (GameView se rehace).
 */
class ServerShip {

	/** ids de los sueltos de la nave (los del planeta van de 1 en adelante: no se cruzan) */
	public static inline var LOOT_BASE = 1 << 28;

	public var world(default, null) : WorldData;
	public var crafts(default, null) : Array<ShipData.CraftArea>;
	public var loot = new Map<Int, { b : Block, n : Int }>();
	var nextId = LOOT_BASE;
	var s : Session;
	var worlds : ServerWorlds;
	var chestVer = 0;

	public function new( s : Session, worlds : ServerWorlds ) {
		this.s = s;
		this.worlds = worlds;
		var info = s.record;
		var data = ShipData.load(ShipData.current(info));
		// como Ship.makeWorld: una puerta abierta vuelve cerrada; las claves negativas son del mar
		var e = info.shipEdits;
		var edits = e == null ? null : [for( i in 0...e.length ) i & 1 == 1 && e[i - 1] >= 0 ? ShipData.shipId(Block.all[e[i] & 0xFFFF]) | (e[i] & ~0xFFFF) : e[i]];
		var biome = info.biome != null ? info.biome : "BIAutumn";
		world = new WorldData(info.seed, biome, 1, edits, data);
		while( !world.genStep(haxe.Timer.stamp(), 1e9) ) {}
		crafts = data.crafts;
		// Ship.initCrafts: lo que ya hay en las zonas cuenta para el sintetizador
		for( c in crafts )
			for( dx in 0...c.w )
				for( dy in 0...c.h )
					for( dz in 0...c.heights[dx][dy] ) {
						var b = world.block(c.x + dx, c.y + dy, c.z + dz);
						if( b != null ) c.engine.add(b, dx, dy, dz);
					}
	}

	inline function inside( x : Int, y : Int, z : Int ) return x >= 0 && y >= 0 && z >= 0 && x < world.size && y < world.size && z < WorldData.HEIGHT;

	function areaAt( x : Int, y : Int, z : Int ) : ShipData.CraftArea {
		for( c in crafts ) if( c.inside(x, y, z) ) return c;
		return null;
	}

	function cellValue( x : Int, y : Int, z : Int ) : Int {
		var b = world.block(x, y, z);
		return b == null ? 0 : b.index;
	}

	function saveEdits() {
		s.record.shipEdits = world.editsFlat();
		worlds.markRecord(s);
	}

	// ---------------------------------------------------------------- poner y quitar (zonas del sintetizador)

	/** CShipSet: poner gi (o quitar, gi = 0) en una zona del sintetizador, donde habia expect; el bloque sale de la casilla slot */
	public function set( seq : Int, x : Int, y : Int, z : Int, expect : Int, gi : Int, slot : Int ) {
		var ok = false;
		var c = inside(x, y, z) ? areaAt(x, y, z) : null;
		if( c != null && cellValue(x, y, z) == expect && gi < Block.all.length ) {
			var cur = world.block(x, y, z);
			if( gi == 0 && cur != null ) {
				world.setBlock(x, y, z, null);
				c.engine.remove(x - c.x, y - c.y, z - c.z);
				// GameView.breakBlock: en una zona del sintetizador lo que se rompe se recupera siempre
				var get = cur.getDrop();
				if( get != null && !s.creative ) for( i in 0...get.count ) spawn(get.b, 1, x + 0.5, y + 0.5, z + 0.5);
				if( cur.hasProp(PContainer) ) spillChest(x, y, z);
				ok = true;
			} else if( gi > 0 && cur == null ) {
				var b = Block.all[gi];
				if( b.type != BTWater && worlds.items.consumeForPlace(s, slot, gi) ) {
					world.setBlock(x, y, z, b);
					c.engine.add(b, x - c.x, y - c.y, z - c.z);
					ok = true;
				}
			}
		}
		if( ok ) saveEdits();
		s.ack = seq;
		s.send(SSetResult(seq, ok, cellValue(x, y, z)));
		worlds.items.sendInv(s);
	}

	// ---------------------------------------------------------------- sintetizador

	/** CShipCraft: el ordenador del sintetizador de (x, y, z) fabrica la receta de su zona (Ship.activateCraft) */
	public function craft( x : Int, y : Int, z : Int ) {
		var c : ShipData.CraftArea = null;
		for( cc in crafts ) if( cc.out != null && cc.out.x == x && cc.out.y == y && cc.out.z == z ) c = cc;
		if( c == null ) return;
		var info = s.record;
		var r = c.engine.checkAll();
		if( r == null || !TutoSetup.craftAllowed(info, r) ) return;
		var blocks = c.engine.getBlocks(true);
		var inv = new Inv(info.inv);
		// si el inventario tiene todos los bloques de la receta se gastan esos y la zona queda de plantilla; si no, los de la zona
		var fromInv = true;
		for( b in blocks ) if( !inv.hasBlocks(b.b, b.n) ) fromInv = false;
		var changes : Array<NetChange> = [];
		if( fromInv ) {
			for( b in blocks ) if( !inv.useBlocks(b.b, b.n) ) return;
		} else {
			c.engine.clear();
			for( b in blocks )
				for( q in b.pos ) {
					var bx = c.x + q.x, by = c.y + q.y, bz = c.z + q.z;
					world.setBlock(bx, by, bz, null);
					changes.push({ key : ((bx + by * world.size) << WorldData.ZBITS) | bz, v : 0 });
				}
			saveEdits();
		}
		var outs = Data.craftRoll(r);
		Kubindex.crafted(info, r, outs);
		for( o in outs )
			for( i in 0...o.n ) spawn(Block.get(o.k), 1, c.out.x + 0.5, c.out.y + 0.5, c.out.z + 0.25, 30);
		worlds.markRecord(s);
		if( changes.length > 0 ) s.send(SShipCells(changes));
		worlds.items.sendInv(s);
		worlds.server.files.log(s.display + " fabrica " + Block.get(r.out).k + (fromInv ? " con su inventario" : ""));
	}

	// ---------------------------------------------------------------- sueltos de a bordo

	public function spawn( b : Block, n : Int, x : Float, y : Float, z : Float, delay = 0. ) {
		var id = nextId++;
		loot.set(id, { b : b, n : n });
		var vx = (GameRng.int(2) * 2 - 1) * GameRng.float() * 0.04, vy = (GameRng.int(2) * 2 - 1) * GameRng.float() * 0.04;
		s.send(SAddLoot({ id : id, x : x, y : y, z : z + WorldData.SHIP_Z, vx : vx, vy : vy, vz : 0., gi : b.index, n : n, delay : delay, container : false }));
	}

	/** CPick de un suelto de la nave: al inventario lo que quepa */
	public function pick( id : Int ) {
		var l = loot.get(id);
		if( l == null ) return;
		var i = new Inv(s.record.inv);
		var got = 0;
		if( l.b.charge != null ) got = i.addCharge(l.b.charge, l.n);
		else if( l.n <= 1 ) got = i.addBlock(l.b) >= 0 ? 1 : 0;
		else got = i.addBlocks(l.b, l.n);
		if( got > 0 ) worlds.markRecord(s);
		l.n -= got;
		if( l.n <= 0 ) {
			loot.remove(id);
			s.send(SDeleteLoot(id));
		} else
			// lo que no cabe se queda: el cliente lo vuelve a ensenar (NetGame, SLootCount de un suelto pedido)
			s.send(SLootCount(id, l.n));
	}

	/** CThrow a bordo (ServerItems.throwSlot): delante del jugador, en la nave */
	public function throwBlocks( b : Block, n : Int ) {
		var p = s.pos;
		if( p == null ) return;
		var size = world.size;
		var lx = (p.x - s.shipDX) % size, ly = (p.y - s.shipDY) % size;
		if( lx < 0 ) lx += size;
		if( ly < 0 ) ly += size;
		var id = nextId++;
		loot.set(id, { b : b, n : n });
		s.send(SAddLoot({ id : id, x : lx + Math.cos(p.yaw), y : ly + Math.sin(p.yaw), z : p.z + 1.2, vx : Math.cos(p.yaw) * 0.3, vy : Math.sin(p.yaw) * 0.3,
			vz : 0., gi : b.index, n : n, delay : 0., container : false }));
	}

	/** al despegar o aterrizar el juego se rehace y los sueltos de a bordo se pierden, como en solo */
	public function clearLoot() loot = new Map();

	// ---------------------------------------------------------------- cantinas de a bordo

	static inline function chestKey( x : Int, y : Int, z : Int ) return "s:" + x + "," + y + "," + z;

	function chestOf( x : Int, y : Int, z : Int, b : Block ) : BlockInventory {
		var info = s.record;
		if( info.chests == null ) info.chests = [];
		var k = chestKey(x, y, z);
		for( c in info.chests ) if( c.key == k ) return c.t;
		var c = { key : k, t : [for( _ in 0...ServerItems.chestSlots(b) ) null] };
		info.chests.push(c);
		return c.t;
	}

	function spillChest( x : Int, y : Int, z : Int ) {
		var info = s.record;
		if( info.chests == null ) return;
		var k = chestKey(x, y, z);
		for( c in info.chests )
			if( c.key == k ) {
				info.chests.remove(c);
				for( st in c.t ) if( st != null ) spawn(Block.all[st.k], st.n, x + 0.5, y + 0.5, z + 0.5);
				if( s.chest == k ) {
					s.chest = null;
					s.send(SChest(x, y, z + WorldData.SHIP_Z, -1, [], ""));
				}
				return;
			}
	}

	/** CChestOpen a bordo (z de la nave) */
	public function chestOpen( x : Int, y : Int, z : Int ) {
		var b = inside(x, y, z) ? world.block(x, y, z) : null;
		if( b == null || !b.hasProp(PContainer) ) return;
		worlds.items.release(s);
		s.chest = chestKey(x, y, z);
		s.send(SChest(x, y, z + WorldData.SHIP_Z, chestVer, chestOf(x, y, z, b), ""));
	}

	/** CChestMove a bordo: como en el planeta, los totales de cantina + inventario no cambian */
	public function chestMove( x : Int, y : Int, z : Int, ver : Int, nc : Array<Null<{ k : Int, n : Int }>>, ni : NetInv ) {
		var k = chestKey(x, y, z);
		var b = inside(x, y, z) ? world.block(x, y, z) : null;
		if( s.chest != k || b == null || !b.hasProp(PContainer) ) return;
		var c = chestOf(x, y, z, b);
		var cur = s.record.inv;
		var ok = ver == chestVer && nc.length == c.length && ni.t.length == cur.t.length && ServerItems.validSlots(nc, 0x7FFFFFFF)
			&& ServerItems.validSlots(ni.t, cur.maxWeight, cur.t)
			&& ServerItems.sameTotals(ServerItems.totals(c, null, ServerItems.totals(cur.t, cur.charges)), ServerItems.totals(nc, null, ServerItems.totals(ni.t, ni.charges)));
		if( ok ) {
			for( i in 0...c.length ) c[i] = nc[i] == null ? null : { k : nc[i].k, n : nc[i].n };
			setInv(ni);
			chestVer++;
		} else worlds.server.files.log("cantina de la nave rechazada de " + s.display + " en " + k);
		s.send(SChest(x, y, z + WorldData.SHIP_Z, chestVer, c, ""));
	}

	function setInv( ni : NetInv ) {
		var cur = s.record.inv;
		for( i in 0...cur.t.length ) cur.t[i] = ni.t[i] == null ? null : { k : ni.t[i].k, n : ni.t[i].n };
		cur.charges.splice(0, cur.charges.length);
		for( ch in ni.charges ) cur.charges.push({ c : ch.c, n : ch.n });
		worlds.markRecord(s);
	}

	// ---------------------------------------------------------------- hangar

	/**
	 * CSaveShip: al salir del hangar con una nave nueva. El hangar se juega en el cliente (como en solo) y aqui se mira el
	 * resultado: que la nave sea valida (Hangar.serverCheck) y que el inventario no tenga mas de lo que daba la nave de antes
	 * menos la nueva (Hangar.delta: lo quitado da lo suyo, lo puesto se gasta; lo que se quedo en el suelo del hangar se pierde,
	 * como en solo). Nada de lo que no se tenia puede salir del hangar. Si vale, la nave de a bordo se rehace.
	 */
	public static function saveShip( s : Session, worlds : ServerWorlds, seq : Int, ship : haxe.io.Bytes, ni : NetInv ) {
		var info = s.record;
		var why = Hangar.serverCheck(ship, NetZip.inflate);
		var cur = info.inv;
		if( why == null && (ni.t.length != cur.t.length || !ServerItems.validSlots(ni.t, cur.maxWeight, cur.t)) ) why = "inventario";
		if( why == null ) {
			var had = ServerItems.totals(cur.t, cur.charges);
			var now = ServerItems.totals(ni.t, ni.charges);
			var d = s.creative ? new Map<Int, Int>() : Hangar.delta(ShipData.current(info), ship);
			var keys = [for( k in had.keys() ) k];
			for( k in now.keys() ) keys.push(k);
			for( k in d.keys() ) keys.push(k);
			for( k in keys ) {
				var can = (had.exists(k) ? had.get(k) : 0) + (d.exists(k) ? d.get(k) : 0);
				var got = now.exists(k) ? now.get(k) : 0;
				// las cargas (claves negativas) no cambian en el hangar: no se gastan ni se ganan
				if( can < 0 || got > can || (k < 0 && got != can) ) {
					why = "cuentas (" + (k < 0 ? "carga " + (-1 - k) : "" + Block.all[k].k) + ": tiene " + got + ", podia " + can + ")";
					break;
				}
			}
		}
		s.ack = seq;
		if( why == null ) {
			info.shipData = haxe.crypto.Base64.encode(ship);
			info.shipEdits = [];
			for( i in 0...cur.t.length ) cur.t[i] = ni.t[i] == null ? null : { k : ni.t[i].k, n : ni.t[i].n };
			s.ship = null;
			worlds.markRecord(s);
			worlds.server.files.log(s.display + " guarda una nave nueva en el hangar");
		} else {
			worlds.server.files.log("nave del hangar rechazada de " + s.display + ": " + why);
			s.send(SPatch("ship", haxe.Json.stringify(info.shipData)));
		}
		worlds.items.sendInv(s);
	}

	// ---------------------------------------------------------------- stockage

	/** CStorage: lo movido entre el stockage y el inventario; nada se crea ni se pierde y cada carga cabe en su contador */
	public function storage( seq : Int, st : NetInv, ni : NetInv ) {
		var info = s.record;
		var cur = StorageData.ensure(info);
		var inv = info.inv;
		var ok = st.t.length == cur.t.length && ni.t.length == inv.t.length && ServerItems.validSlots(st.t, 0x7FFFFFFF)
			&& ServerItems.validSlots(ni.t, inv.maxWeight, inv.t)
			// cada carga en su contador; uno que ya pasaba del maximo (partida creativa traida al servidor) no impide lo demas
			&& ServerItems.chargesFit(st.charges, cur.charges, StorageData.chargeMax())
			&& ServerItems.chargesFit(ni.charges, inv.charges, StorageData.invChargeMax());
		if( ok ) ok = ServerItems.sameTotals(ServerItems.totals(cur.t, cur.charges, ServerItems.totals(inv.t, inv.charges)),
			ServerItems.totals(st.t, st.charges, ServerItems.totals(ni.t, ni.charges)));
		if( ok ) {
			for( i in 0...cur.t.length ) cur.t[i] = st.t[i] == null ? null : { k : st.t[i].k, n : st.t[i].n };
			cur.charges = [for( c in st.charges ) if( c.n > 0 ) { c : c.c, n : c.n }];
			setInv(ni);
		} else worlds.server.files.log("stockage rechazado de " + s.display);
		s.ack = seq;
		s.send(SPatch("storage", haxe.Json.stringify(cur)));
		worlds.items.sendInv(s);
	}
}
