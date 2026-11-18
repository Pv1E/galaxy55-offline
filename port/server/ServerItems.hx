import Common;
import Msg;
import Protocol;
import GameServer.Session;

/** Un bloque suelto del servidor (Drops.Drop sin el dibujo): la misma fisica (Dummy.updatePos) */
class ServerDrop {
	public var id : Int;
	public var x : Float;
	public var y : Float;
	public var z : Float;
	public var vx = 0.;
	public var vy = 0.;
	public var vz = 0.;
	public var b : Block;
	public var n = 1;
	/** vida restante en unidades de 30 tmod (180 al soltarlo); un contenedor no caduca */
	public var time = 180.;
	public var active = true;
	public var delay = 0.;
	/** contenedor del equipo dejado al morir (DeathDrops): lo que lleva */
	public var loot : DeathDrops.DeathDropInfo;
	public var rested = false;
	public function new() {}
}

/** Lo que hay suelto y guardado en un planeta cargado: sueltos, cantinas (y quien tiene abierta cada una) y bombas en espera */
class PlanetItems {
	public var drops = new Map<Int, ServerDrop>();
	public var chests = new Map<String, BlockInventory>();
	public var chestVer = new Map<String, Int>();
	public var leases = new Map<String, Session>();
	public var dirtyChests = new Map<String, Bool>();
	public var dirtyLoot = new Map<Int, Bool>();
	public var bombs = new Array<{ x : Int, y : Int, z : Int }>();
	public var nextId = 1;
	public function new() {}
}

/**
 * Los objetos del multijugador (anadido del port): el servidor es el unico que crea, mueve y destruye objetos, asi no hay forma de
 * duplicarlos. Lleva el inventario de cada jugador (SInventory, con ack: la ultima peticion suya hecha), los sueltos de cada
 * planeta (los crea al romper, al tirar o al morir, con su propio azar; recoger es atomico: lo coge uno y solo uno), las cantinas
 * (una persona a la vez, contenido con version; un movimiento solo vale si no se crea ni se pierde nada) y los bloques que se
 * activan (puertas, bomba). Todo cambia en memoria y se guarda en la misma transaccion que el terreno (ServerWorlds.commit).
 */
class ServerItems {

	var worlds : ServerWorlds;
	var server : GameServer;
	var db : ServerDb;
	/** distancia maxima para recoger (bloques; en el juego 0.4 tras acercarse desde 1.5) */
	static inline var PICK_REACH = 2.5;
	static inline var USE_REACH = 10.;

	public function new( worlds : ServerWorlds, server : GameServer, db : ServerDb ) {
		this.worlds = worlds;
		this.server = server;
		this.db = db;
	}

	// ---------------------------------------------------------------- inventario

	public static function netInv( i : InventoryInfos ) : NetInv {
		return { t : [for( s in i.t ) s == null || s.n <= 0 ? null : { k : s.k, n : s.n }], charges : [for( c in i.charges ) if( c.n > 0 ) { c : c.c, n : c.n }] };
	}

	public function sendInv( s : Session ) {
		if( s.record == null || s.record.inv == null ) return;
		s.send(SInventory(s.ack, netInv(s.record.inv)));
	}

	inline function inv( s : Session ) return new Inv(s.record.inv);

	/** CPlace: el bloque sale de la casilla slot (1 = la primera tras el excavador); false si no lo tiene */
	public function consumeForPlace( s : Session, slot : Int, gi : Int ) : Bool {
		if( s.creative ) return true;
		var t = s.record.inv.t;
		var st = slot >= 1 && slot <= t.length ? t[slot - 1] : null;
		if( st == null || st.k != gi || st.n <= 0 ) return false;
		st.n--;
		if( st.n == 0 ) t[slot - 1] = null;
		worlds.markRecord(s);
		return true;
	}

	/** totales por bloque (y por carga, con clave negativa) de un inventario: lo que no puede cambiar al ordenarlo */
	static function totals( t : Array<Null<{ k : Int, n : Int }>>, charges : Array<{ c : Int, n : Int }>, ?into : Map<Int, Int> ) : Map<Int, Int> {
		var m = into == null ? new Map<Int, Int>() : into;
		for( s in t ) if( s != null && s.n > 0 ) m.set(s.k, (m.exists(s.k) ? m.get(s.k) : 0) + s.n);
		if( charges != null ) for( c in charges ) if( c.n > 0 ) m.set(-1 - c.c, (m.exists(-1 - c.c) ? m.get(-1 - c.c) : 0) + c.n);
		return m;
	}

	static function sameTotals( a : Map<Int, Int>, b : Map<Int, Int> ) : Bool {
		for( k => v in a ) if( b.get(k) != v ) return false;
		for( k => v in b ) if( a.get(k) != v ) return false;
		return true;
	}

	/** cada casilla con un bloque que existe y sin pasar de su maximo */
	static function validSlots( t : Array<Null<{ k : Int, n : Int }>>, maxWeight : Int ) : Bool {
		for( s in t ) {
			if( s == null ) continue;
			if( s.k <= 0 || s.k >= Block.all.length || s.n <= 0 ) return false;
			if( s.n > Block.all[s.k].getMax(maxWeight) ) return false;
		}
		return true;
	}

	// ---------------------------------------------------------------- sueltos

	function lootOf( d : ServerDrop ) : NetLoot {
		return { id : d.id, x : d.x, y : d.y, z : d.z, vx : d.vx, vy : d.vy, vz : d.vz, gi : d.b.index, n : d.n, delay : d.delay, container : d.loot != null };
	}

	/** un suelto nuevo en el planeta (vx, vy null: la deriva al azar de lo que se suelta, Drop.new) */
	public function spawn( inst : PlanetInstance, x : Float, y : Float, z : Float, b : Block, n = 1, ?vx : Float, ?vy : Float, ?loot : DeathDrops.DeathDropInfo ) : ServerDrop {
		var it = inst.items;
		var d = new ServerDrop();
		d.id = it.nextId++;
		d.x = x;
		d.y = y;
		d.z = z;
		d.b = b;
		d.n = n;
		d.vx = vx != null ? vx : (GameRng.int(2) * 2 - 1) * GameRng.float() * 0.04;
		d.vy = vy != null ? vy : (GameRng.int(2) * 2 - 1) * GameRng.float() * 0.04;
		if( vx != null ) d.active = false;
		d.loot = loot;
		if( loot != null ) {
			d.time = Math.POSITIVE_INFINITY;
			d.vx = d.vy = 0;
			loot.id = d.id;
			it.dirtyLoot.set(d.id, true);
		}
		it.drops.set(d.id, d);
		for( p in inst.players ) p.send(SAddLoot(lootOf(d)));
		return d;
	}

	function removeDrop( inst : PlanetInstance, d : ServerDrop ) {
		inst.items.drops.remove(d.id);
		if( d.loot != null ) inst.items.dirtyLoot.set(d.id, true);
		for( p in inst.players ) p.send(SDeleteLoot(d.id));
	}

	/** lo que suelta un bloque roto (Game.blockBreak), y lo que tenia si era una cantina */
	public function onBreak( inst : PlanetInstance, x : Int, y : Int, z : Int, b : Block, creative : Bool ) {
		if( b.hasProp(PContainer) ) spillChest(inst, x, y, z);
		var get = b.getDrop();
		if( get == null || creative ) return;
		var chance = b.getMain().getDropChance();
		for( i in 0...get.count )
			if( GameRng.int(100) < chance ) spawn(inst, x + 0.5, y + 0.5, z + 0.5, get.b);
	}

	/** fisica de los sueltos (Drops.update sin el jugador ni el dibujo); dt en segundos */
	public function tick( inst : PlanetInstance, dt : Float ) {
		var w = inst.world;
		var tm = dt * 32;
		for( d in [for( d in inst.items.drops ) d] ) {
			if( d.loot == null ) {
				d.time -= tm / 30;
				if( d.time <= 0 ) {
					removeDrop(inst, d);
					continue;
				}
			}
			if( d.delay > 0 ) {
				d.delay -= tm;
				continue;
			}
			var ox = d.x, oy = d.y, oz = d.z;
			if( !w.collidePoint(d.x, d.y, d.z - 0.01) ) d.vz -= 0.01 * tm;
			else {
				d.active = true;
				if( d.vz < 0 ) d.vz *= Math.pow(0.3, tm);
				var r = 0;
				while( r < 20 && (w.collidePoint(d.x, d.y, d.z) || w.collidePoint(d.x, d.y, d.z + 0.3)) ) {
					d.z += 0.01 * tm;
					r++;
				}
			}
			d.x += d.vx * tm;
			d.y += d.vy * tm;
			if( w.collidePoint(d.x, d.y, d.z) ) {
				d.x -= d.vx * tm;
				d.y -= d.vy * tm;
				d.vx *= -0.6;
				d.vy *= -0.6;
			}
			d.z += d.vz * tm;
			var p = Math.pow(0.93, tm);
			d.vx *= p;
			d.vy *= p;
			d.vz *= p;
			if( d.x < 0 ) d.x += w.size else if( d.x >= w.size ) d.x -= w.size;
			if( d.y < 0 ) d.y += w.size else if( d.y >= w.size ) d.y -= w.size;
			if( d.z < -50 ) {
				removeDrop(inst, d);
				continue;
			}
			var moved = Math.abs(d.x - ox) + Math.abs(d.y - oy) + Math.abs(d.z - oz) > 0.001;
			if( !moved && !d.rested ) {
				d.rested = true;
				for( pl in inst.players ) pl.send(SLootRest(d.id, d.x, d.y, d.z));
				if( d.loot != null ) {
					d.loot.x = d.x;
					d.loot.y = d.y;
					d.loot.z = d.z;
					inst.items.dirtyLoot.set(d.id, true);
				}
			} else if( moved ) d.rested = false;
		}
		// bombas alcanzadas por una explosion o por la lava: una por paso (Process.onActivateLate)
		var b = inst.items.bombs.shift();
		if( b != null && inst.world.block(b.x, b.y, b.z) != null && inst.world.block(b.x, b.y, b.z).k == BArtiBomb ) explode(inst, b.x, b.y, b.z);
		else if( b != null && inst.world.block(b.x, b.y, b.z) == null ) explode(inst, b.x, b.y, b.z);
	}

	/** al entrar en el planeta: los sueltos que hay */
	public function sendLoots( s : Session, inst : PlanetInstance ) {
		for( d in inst.items.drops ) s.send(SAddLoot(lootOf(d)));
	}

	function dist2( inst : PlanetInstance, p : NetState, x : Float, y : Float, z : Float ) : Float {
		var size = inst.world.size;
		inline function d( a : Float, b : Float ) {
			var v = Math.abs(a - b) % size;
			return v > size * 0.5 ? size - v : v;
		}
		var dx = d(p.x, x), dy = d(p.y, y), dz = p.z + 0.9 - z;
		return dx * dx + dy * dy + dz * dz;
	}

	function pick( s : Session, id : Int ) {
		var inst = s.instance;
		if( inst == null ) return;
		var d = inst.items.drops.get(id);
		if( d == null ) return;
		var ok = s.rights & RPickup != 0 && s.pos != null && d.delay <= 0 && dist2(inst, s.pos, d.x, d.y, d.z) <= PICK_REACH * PICK_REACH;
		var got = false;
		if( ok ) {
			var i = inv(s);
			if( d.loot != null ) {
				got = DeathDrops.take(i, d.loot);
				if( DeathDrops.isEmpty(d.loot) ) removeDrop(inst, d);
				else if( got ) inst.items.dirtyLoot.set(d.id, true);
			} else if( d.n <= 1 ) {
				got = i.addBlock(d.b) >= 0;
				if( got ) removeDrop(inst, d);
			} else {
				var c = d.b.charge != null ? i.addCharge(d.b.charge, d.n) : i.addBlocks(d.b, d.n);
				got = c > 0;
				d.n -= c;
				if( d.n <= 0 ) removeDrop(inst, d) else if( got ) for( p in inst.players ) p.send(SLootCount(d.id, d.n));
			}
		}
		if( got ) worlds.markRecord(s);
		// no lo ha cogido (otro fue antes, no cabe, demasiado lejos): el suelto vuelve a verse en su juego
		if( !got && inst.items.drops.exists(id) ) s.send(SAddLoot(lootOf(d)));
	}

	function throwSlot( s : Session, slot : Int, n : Int ) {
		var t = s.record.inv.t;
		var st = slot >= 1 && slot <= t.length ? t[slot - 1] : null;
		if( st == null || n <= 0 || n > st.n ) return;
		var b = Block.all[st.k];
		st.n -= n;
		if( st.n <= 0 ) t[slot - 1] = null;
		worlds.markRecord(s);
		// en creativo, o fuera de un planeta, tirar solo vacia la casilla (GameView.throwStack)
		var inst = s.instance, p = s.pos;
		if( s.creative || inst == null || p == null ) return;
		var d = spawn(inst, p.x + Math.cos(p.yaw), p.y + Math.sin(p.yaw), p.z + 1.2, b, n, Math.cos(p.yaw) * 0.3, Math.sin(p.yaw) * 0.3);
		d.active = false;
	}

	function layout( s : Session, ni : NetInv ) {
		var cur = s.record.inv;
		if( ni.t.length != cur.t.length ) return;
		if( !validSlots(ni.t, cur.maxWeight) ) return;
		var a = totals(cur.t, cur.charges), b = totals(ni.t, cur.charges);
		if( !sameTotals(a, b) ) {
			server.files.log("inventario rechazado de " + s.display + ": no cuadra");
			return;
		}
		for( i in 0...cur.t.length ) cur.t[i] = ni.t[i] == null ? null : { k : ni.t[i].k, n : ni.t[i].n };
		worlds.markRecord(s);
	}

	/** muerte o Mayus+K: todo el equipo a un contenedor donde esta (DeathDrops.leave), si toca */
	function death( s : Session, manual : Bool ) {
		var inst = s.instance, p = s.pos;
		var info = s.record;
		if( inst == null || p == null || s.creative || !server.files.options.deathDrop || s.rights & RVisitor != 0 ) return;
		if( info.tuto != null ) return;
		var i = info.inv;
		var t = [for( st in i.t ) st == null || st.n <= 0 ? null : { k : st.k, n : st.n }];
		var charges = [for( c in i.charges ) if( c.n > 0 ) { c : c.c, n : c.n }];
		if( charges.length == 0 && !Lambda.exists(t, st -> st != null) ) return;
		var d : DeathDrops.DeathDropInfo = { id : 0, key : "p", x : p.x, y : p.y, z : p.z + 0.5, t : t, charges : charges };
		for( k in 0...i.t.length ) i.t[k] = null;
		i.charges.splice(0, i.charges.length);
		worlds.markRecord(s);
		spawn(inst, p.x, p.y, p.z + 0.5, DeathDrops.block(), 1, 0, 0, d);
		server.files.log(s.display + (manual ? " vuelve a la nave" : " muere") + " y deja su equipo en " + inst.key);
	}

	function creativeSet( s : Session, slot : Int, gi : Int, n : Int ) {
		if( !s.creative ) return;
		var t = s.record.inv.t;
		if( slot < 1 || slot > t.length || gi >= Block.all.length ) return;
		t[slot - 1] = gi == 0 || n <= 0 ? null : { k : gi, n : Std.int(Math.min(n, Block.all[gi].getMax(s.record.inv.maxWeight))) };
		worlds.markRecord(s);
	}

	// ---------------------------------------------------------------- cantinas

	static inline function chestKey( x : Int, y : Int, z : Int ) return x + "," + y + "," + z;

	/** slots de una cantina (BFContainer del bloque) */
	static function chestSlots( b : Block ) : Int {
		for( f in b.flags ) switch( f ) { case BFContainer(n): return n; default: }
		return 4;
	}

	function chestOf( inst : PlanetInstance, x : Int, y : Int, z : Int, b : Block ) : BlockInventory {
		var k = chestKey(x, y, z);
		var c = inst.items.chests.get(k);
		if( c == null ) {
			c = [for( _ in 0...chestSlots(b) ) null];
			inst.items.chests.set(k, c);
		}
		return c;
	}

	function spillChest( inst : PlanetInstance, x : Int, y : Int, z : Int ) {
		var k = chestKey(x, y, z);
		var c = inst.items.chests.get(k);
		if( c == null ) return;
		inst.items.chests.remove(k);
		inst.items.dirtyChests.set(k, true);
		var l = inst.items.leases.get(k);
		if( l != null ) {
			inst.items.leases.remove(k);
			l.chest = null;
			l.send(SChest(x, y, z, -1, [], ""));
		}
		for( s in c ) if( s != null ) spawn(inst, x + 0.5, y + 0.5, z + 0.5, Block.all[s.k], s.n);
	}

	function chestOpen( s : Session, x : Int, y : Int, z : Int ) {
		var inst = s.instance;
		if( inst == null || s.rights & RChests == 0 || s.pos == null ) return;
		var b = inst.world.block(x, y, z);
		if( b == null || !b.hasProp(PContainer) || dist2(inst, s.pos, x + 0.5, y + 0.5, z + 0.5) > USE_REACH * USE_REACH ) return;
		var k = chestKey(x, y, z);
		var l = inst.items.leases.get(k);
		if( l != null && l != s && l.instance == inst ) {
			s.send(SChest(x, y, z, -1, [], l.display));
			return;
		}
		release(s);
		inst.items.leases.set(k, s);
		s.chest = k;
		var c = chestOf(inst, x, y, z, b);
		var v = inst.items.chestVer.exists(k) ? inst.items.chestVer.get(k) : 0;
		s.send(SChest(x, y, z, v, c, ""));
	}

	function chestMove( s : Session, x : Int, y : Int, z : Int, ver : Int, nc : Array<Null<{ k : Int, n : Int }>>, ni : NetInv ) {
		var inst = s.instance;
		var k = chestKey(x, y, z);
		if( inst == null || s.chest != k || inst.items.leases.get(k) != s ) return;
		var b = inst.world.block(x, y, z);
		if( b == null || !b.hasProp(PContainer) ) return;
		var c = chestOf(inst, x, y, z, b);
		var v = inst.items.chestVer.exists(k) ? inst.items.chestVer.get(k) : 0;
		var cur = s.record.inv;
		var ok = ver == v && nc.length == c.length && ni.t.length == cur.t.length && validSlots(nc, 0x7FFFFFFF) && validSlots(ni.t, cur.maxWeight);
		if( ok ) {
			// nada se crea ni se pierde: los totales de cantina + inventario (bloques y cargas) son los mismos antes y despues
			var before = totals(c, null, totals(cur.t, cur.charges));
			var after = totals(nc, null, totals(ni.t, ni.charges));
			ok = sameTotals(before, after);
		}
		if( ok ) {
			for( i in 0...c.length ) c[i] = nc[i] == null ? null : { k : nc[i].k, n : nc[i].n };
			for( i in 0...cur.t.length ) cur.t[i] = ni.t[i] == null ? null : { k : ni.t[i].k, n : ni.t[i].n };
			cur.charges.splice(0, cur.charges.length);
			for( ch in ni.charges ) cur.charges.push({ c : ch.c, n : ch.n });
			inst.items.chestVer.set(k, v + 1);
			inst.items.dirtyChests.set(k, true);
			worlds.markRecord(s);
		} else server.files.log("cantina rechazada de " + s.display + " en " + k);
		s.send(SChest(x, y, z, inst.items.chestVer.exists(k) ? inst.items.chestVer.get(k) : 0, c, ""));
	}

	/** suelta la cantina que tenga abierta */
	public function release( s : Session ) {
		var inst = s.instance;
		if( s.chest == null ) return;
		if( inst != null && inst.items.leases.get(s.chest) == s ) inst.items.leases.remove(s.chest);
		s.chest = null;
	}

	// ---------------------------------------------------------------- bloques que se activan

	function activate( s : Session, x : Int, y : Int, z : Int ) {
		var inst = s.instance;
		if( inst == null || s.rights & RActivate == 0 || s.pos == null || !inst.ready() ) return;
		if( z >= WorldData.SHIP_Z || dist2(inst, s.pos, x + 0.5, y + 0.5, z + 0.5) > USE_REACH * USE_REACH ) return;
		var w = inst.world;
		var b = w.block(x, y, z);
		if( b == null ) return;
		if( b.activable != null ) {
			// la bomba rompe el terreno: hace falta poder construir
			if( b.k == BArtiBomb && s.rights & RBuild != 0 ) explode(inst, x, y, z);
		} else if( b.toggle != null ) {
			// Process.toggle: toda la columna del mismo bloque (una puerta mide varios bloques de alto)
			while( w.block(x, y, z - 1) == b ) z--;
			while( w.block(x, y, z) == b ) {
				w.setBlock(x, y, z, b.toggle);
				z++;
			}
		}
	}

	/** la lava alcanza una bomba (WorldProcess.lavaBombFn): explota en el paso siguiente */
	public function lavaBomb( inst : PlanetInstance, x : Int, y : Int, z : Int ) inst.items.bombs.push({ x : x, y : y, z : z });

	/**
	 * GameView.explodeBomb en el servidor: vacia una esfera de radio 8 sin soltar nada (las cantinas sueltan lo suyo), las bombas
	 * alcanzadas explotan despues, y cada jugador del planeta recibe su dano (20 en el borde, 150 en el centro) y el efecto.
	 */
	function explode( inst : PlanetInstance, x : Int, y : Int, z : Int ) {
		var ray = 8;
		var w = inst.world;
		var size = w.size;
		for( p in inst.players ) {
			p.send(SBomb(x + 0.5, y + 0.5, z + 0.5));
			if( p.pos == null || p.pos.flags & (FInShip : Int) != 0 ) continue;
			var hx = wd(p.pos.x - x, size), hy = wd(p.pos.y - y, size), hz = p.pos.z - z;
			var pow = 1 - (hx * hx + hy * hy + hz * hz) / (ray * ray);
			var dmg = Math.ceil(130 * pow) + 20;
			if( dmg > 0 ) p.send(SHit(dmg));
		}
		for( dx in -ray...ray )
			for( dy in -ray...ray )
				for( dz in -ray...ray ) {
					if( dx * dx + dy * dy + dz * dz > ray * ray ) continue;
					var bx = wi(x + dx, size), by = wi(y + dy, size), bz = z + dz;
					if( bz >= WorldData.SHIP_Z || bz < 1 || bz >= WorldData.HEIGHT - 1 ) continue;
					var old = w.block(bx, by, bz);
					if( old == null ) continue;
					var req = old.requiredPower != null ? old.requiredPower : old.matter.requiredPower;
					if( req != null && req < 0 ) continue;
					if( old.hasProp(PContainer) ) spillChest(inst, bx, by, bz);
					w.setBlock(bx, by, bz, null);
					inst.process.onSet(bx, by, bz, old, null);
					if( old.k == BArtiBomb && (dx != 0 || dy != 0 || dz != 0) ) inst.items.bombs.push({ x : bx, y : by, z : bz });
				}
	}

	static inline function wi( v : Int, s : Int ) return v < 0 ? v + s : (v >= s ? v - s : v);

	static inline function wd( v : Float, s : Int ) : Float {
		var d = v % s;
		if( d < 0 ) d += s;
		return d > s * 0.5 ? d - s : d;
	}

	// ---------------------------------------------------------------- mensajes, carga y guardado

	/** mensajes de objetos; true si era uno de ellos */
	public function handle( s : Session, m : ClientMsg ) : Bool {
		if( s.record == null ) return false;
		switch( m ) {
		case CCharge(c):
			if( !s.creative && c < Type.getEnumConstructs(ChargeKind).length ) {
				inv(s).useCharge(Type.createEnumIndex(ChargeKind, c));
				worlds.markRecord(s);
			}
		case CPick(seq, id):
			s.ack = seq;
			pick(s, id);
			sendInv(s);
		case CThrow(seq, slot, n):
			s.ack = seq;
			throwSlot(s, slot, n);
			sendInv(s);
		case CInvLayout(seq, ni):
			s.ack = seq;
			layout(s, ni);
			sendInv(s);
		case CDeath(manual):
			death(s, manual);
			sendInv(s);
		case CCreative(seq, slot, gi, n):
			s.ack = seq;
			creativeSet(s, slot, gi, n);
			sendInv(s);
		case CChestOpen(x, y, z):
			chestOpen(s, x, y, z);
		case CChestMove(x, y, z, ver, chest, ni):
			chestMove(s, x, y, z, ver, chest, ni);
			sendInv(s);
		case CChestClose:
			release(s);
		case CActivate(x, y, z):
			activate(s, x, y, z);
		default:
			return false;
		}
		return true;
	}

	/** al cargar un planeta: sus cantinas y los contenedores que quedaron en el */
	public function load( inst : PlanetInstance ) {
		for( k => j in db.loadChests(inst.key) ) {
			try {
				var a : Array<Dynamic> = haxe.Json.parse(j);
				inst.items.chests.set(k, [for( v in a ) v == null ? null : { k : Std.int(v.k), n : Std.int(v.n) }]);
			} catch( e : Dynamic ) {}
		}
		var loots = DeathDrops.read([for( j in db.loadLoot(inst.key) ) try haxe.Json.parse(j) catch( e : Dynamic ) null]);
		for( l in (loots == null ? [] : loots) ) {
			var old = l.id;
			var d = spawn(inst, l.x, l.y, l.z, DeathDrops.block(), 1, 0, 0, l);
			// el id cambia al cargar: el viejo se borra de la base
			if( old != d.id ) inst.items.dirtyLoot.set(old, true);
		}
	}

	/** lo cambiado del planeta, dentro de la transaccion de ServerWorlds.commit */
	public function save( inst : PlanetInstance ) {
		var it = inst.items;
		for( k in it.dirtyChests.keys() ) {
			var c = it.chests.get(k);
			db.saveChest(inst.key, k, c == null ? null : haxe.Json.stringify(c));
		}
		it.dirtyChests = new Map();
		for( id in it.dirtyLoot.keys() ) {
			var d = it.drops.get(id);
			db.saveLoot(inst.key, id, d == null || d.loot == null ? null : haxe.Json.stringify(d.loot));
		}
		it.dirtyLoot = new Map();
	}
}
