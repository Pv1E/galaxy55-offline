import Common;
import Msg;

/**
 * La partida multijugador dentro de GameView (anadido del port): manda donde esta el jugador y su laser 20 veces por segundo,
 * anuncia al servidor lo que rompe y pone (el jugador lo ve al momento; si el servidor dice que no, la celda vuelve a lo que
 * hay de verdad), aplica los cambios que manda el servidor (los de los demas y los del proceso del mundo, que solo corre alli)
 * y dibuja a los demas (RemotePlayers).
 * Los objetos son del servidor (ServerItems): el inventario llega en SInventory y encima se rehace lo que el jugador ha hecho y
 * el servidor aun no ha visto (poner, tirar); los sueltos los crea el; recoger, tirar, ordenar, morir, la paleta, las cantinas y
 * lo que se activa son peticiones.
 */
class NetGame {

	var mp : MultiSession;
	var g : GameView;
	public var remotes(default, null) : RemotePlayers;
	/** aplicando un cambio del servidor: no se vuelve a mandar */
	public var applying(default, null) = false;
	var seq = 0;
	/** celda de cada peticion sin respuesta (para deshacerla si el servidor dice que no) */
	var pending = new Map<Int, Int>();
	/** lo que el jugador ha quitado de sus casillas sin respuesta aun (poner, tirar): se rehace sobre cada SInventory */
	var predicted = new Array<{ seq : Int, slot : Int, n : Int }>();
	/** sueltos del servidor en este mundo */
	var loots = new Map<Int, Drops.Drop>();
	/** cantina abierta del servidor: donde esta y su version */
	var chest : { x : Int, y : Int, z : Int, ver : Int, box : Protocol.BlockInventory };
	var stateAcc = 0.;
	static inline var STATE_RATE = 0.05;
	/** abrir y cerrar la ventana de una cantina (GalaxyApp) */
	public var onOpenChest : Protocol.BlockInventory -> Void;
	public var onCloseChest : Void -> Void;
	public var onToast : String -> Void;

	public function new( mp : MultiSession, g : GameView, root3d : h3d.scene.Object, s2d : h2d.Object ) {
		this.mp = mp;
		this.g = g;
		remotes = new RemotePlayers(g, root3d, s2d);
		remotes.names = function( id ) {
			var p = mp.players.get(id);
			return p == null ? null : p.name;
		};
	}

	public function dispose() {
		remotes.dispose();
	}

	public function update( dt : Float ) {
		stateAcc += dt;
		if( stateAcc >= STATE_RATE ) {
			stateAcc = 0;
			sendState();
		}
		// donde esta su nave en el planeta (al llegar y despues de pilotarla): el servidor pasa con ello los sueltos de a bordo
		var w = g.world;
		if( w.shipDX != sentDX || w.shipDY != sentDY ) {
			sentDX = w.shipDX;
			sentDY = w.shipDY;
			mp.client.send(CShipOffset(sentDX, sentDY));
		}
		remotes.update(dt);
	}

	var sentDX = -1;
	var sentDY = -1;

	// ---------------------------------------------------------------- su nave (ServerShip)

	/** coordenadas de la nave de una celda del planeta (z >= SHIP_Z) */
	function shipCoords( x : Int, y : Int, z : Int ) : { x : Int, y : Int, z : Int } {
		var w = g.world;
		return { x : Std.int(@:privateAccess w.shipLocal(x, w.shipDX)), y : Std.int(@:privateAccess w.shipLocal(y, w.shipDY)), z : z - WorldData.SHIP_Z };
	}

	/** celda del planeta de unas coordenadas de la nave */
	function planetCoords( lx : Float, ly : Float ) : { x : Float, y : Float } {
		var w = g.world, s = w.size;
		var x = (lx + w.shipDX) % s, y = (ly + w.shipDY) % s;
		if( x < 0 ) x += s;
		if( y < 0 ) y += s;
		return { x : x, y : y };
	}

	/** seq de cada peticion de la nave sin respuesta y su celda (del planeta) */
	var pendingShip = new Map<Int, { x : Int, y : Int, z : Int }>();

	/** ha puesto (put) o quitado (old) un bloque de una zona del sintetizador; el bloque salio de la casilla slot */
	public function sentShipSet( x : Int, y : Int, z : Int, old : Block, put : Block, slot : Int ) {
		var c = shipCoords(x, y, z);
		pendingShip.set(++seq, { x : x, y : y, z : z });
		if( put != null && !g.creative ) predicted.push({ seq : seq, slot : slot, n : 1 });
		mp.client.send(CShipSet(seq, c.x, c.y, c.z, old == null ? 0 : old.index, put == null ? 0 : put.index, slot));
	}

	/** el ordenador del sintetizador: fabrica el servidor */
	public function sentShipCraft( x : Int, y : Int, z : Int ) {
		var c = shipCoords(x, y, z);
		mp.client.send(CShipCraft(c.x, c.y, c.z));
	}

	/** el stockage ha cambiado (pantalla ShipStorage): stockage e inventario tal como quedan */
	public function sentStorage( store : StorageData.StorageInfo ) {
		predicted = [];
		mp.client.send(CStorage(++seq, ServerItems.netInv({ maxWeight : 0, t : store.t, charges : store.charges }), ServerItems.netInv(g.inv.inv)));
	}

	/** celdas de la nave cambiadas por el servidor (receta hecha con los bloques de la zona) */
	function applyShipCells( list : Array<NetChange> ) {
		var ss = 1 << Const.BITS;
		for( c in list ) {
			var lz = c.key & (WorldData.HEIGHT - 1), col = c.key >> WorldData.ZBITS;
			var p = planetCoords(col % ss, Std.int(col / ss));
			var x = Std.int(p.x), y = Std.int(p.y), z = lz + WorldData.SHIP_Z;
			var gi = c.v & 0xFFFF;
			var b = gi == 0 || gi >= Block.all.length ? null : Block.all[gi];
			var old = g.world.block(x, y, z);
			if( old == b ) continue;
			applying = true;
			g.world.setBlock(x, y, z, b);
			applying = false;
			if( g.ship != null ) g.ship.craft(x, y, z, b, g);
			if( b == null && old != null ) @:privateAccess g.parts.doBreak(x, y, z, old);
		}
	}

	function sendState() {
		var sel = g.select;
		var laser = g.laserActive && sel != null;
		var flags = (laser ? (FLaser : Int) : 0) | (g.pz >= WorldData.SHIP_Z - 1 ? (FInShip : Int) : 0);
		mp.client.send(CState({ id : 0, x : g.px, y : g.py, z : g.pz, yaw : g.yaw, pitch : g.pitch, flags : flags,
			charge : g.laserCharge == null ? -1 : Type.enumIndex(g.laserCharge),
			hx : laser ? sel.hx : 0, hy : laser ? sel.hy : 0, hz : laser ? sel.hz : 0 }));
	}

	// ---------------------------------------------------------------- lo que hace el jugador

	/** el jugador ha roto un bloque del planeta */
	public function sentBreak( x : Int, y : Int, z : Int, b : Block ) {
		pending.set(++seq, cellKey(x, y, z));
		mp.client.send(CBreak(seq, x, y, z, b.index));
	}

	/** el jugador ha puesto un bloque del planeta (level: nivel del agua puesta) desde la casilla slot (1 = tras el excavador) */
	public function sentPlace( x : Int, y : Int, z : Int, b : Block, level : Int, slot : Int ) {
		pending.set(++seq, cellKey(x, y, z));
		if( !g.creative ) predicted.push({ seq : seq, slot : slot, n : 1 });
		mp.client.send(CPlace(seq, x, y, z, b.index, level, slot));
	}

	public function sentCharge( c : ChargeKind ) mp.client.send(CCharge(Type.enumIndex(c)));

	public function sentPick( id : Int ) mp.client.send(CPick(++seq, id));

	/** ha tirado n de la casilla slot (ya quitados de su inventario) */
	public function sentThrow( slot : Int, n : Int ) {
		predicted.push({ seq : ++seq, slot : slot, n : n });
		mp.client.send(CThrow(seq, slot, n));
	}

	/** nuevo orden de su inventario (pantalla de inventario) */
	public function sentLayout() {
		predicted = [];
		mp.client.send(CInvLayout(++seq, ServerItems.netInv(g.inv.inv)));
	}

	/** muerte o Mayus+K: el servidor deja el contenedor; aqui el inventario queda vacio */
	public function sentDeath( manual : Bool ) {
		mp.client.send(CDeath(manual));
		var i = g.inv.inv;
		for( k in 0...i.t.length ) i.t[k] = null;
		i.charges.splice(0, i.charges.length);
		predicted = [];
		g.inv.select(0);
		g.inv.display();
	}

	public function sentCreative( slot : Int, b : Block, n : Int ) mp.client.send(CCreative(++seq, slot, b.index, n));

	public function sentActivate( x : Int, y : Int, z : Int ) mp.client.send(CActivate(x, y, z));

	/** progresion (tienda, contratos, planeta principal): ya hecha en la partida; el servidor la repite (ServerEcon) */
	public function sentEcon( op : EconOp, a : String, n : Int ) mp.client.send(CEcon(++seq, op, a, n));

	/** abrir una cantina; las de la nave van en sus coordenadas (z con SHIP_Z) */
	public function sentChestOpen( x : Int, y : Int, z : Int ) {
		if( z >= WorldData.SHIP_Z ) {
			var c = shipCoords(x, y, z);
			x = c.x;
			y = c.y;
		}
		mp.client.send(CChestOpen(x, y, z));
	}

	/** la cantina abierta ha cambiado (SlotGrid.onChange): cantina e inventario tal como quedan */
	public function sentChestMove() {
		if( chest == null ) return;
		mp.client.send(CChestMove(chest.x, chest.y, chest.z, chest.ver, ServerItems.netInv({ maxWeight : 0, t : chest.box, charges : [] }).t, ServerItems.netInv(g.inv.inv)));
	}

	public function sentChestClose() {
		if( chest == null ) return;
		chest = null;
		mp.client.send(CChestClose);
	}

	// ---------------------------------------------------------------- lo que manda el servidor

	public function onMessage( m : ServerMsg ) {
		switch( m ) {
		case SChanges(list):
			for( c in list ) apply(c.key, c.v, true);
		case SSetResult(s, ok, current) if( pendingShip.exists(s) ):
			// en la nave: si el servidor no lo acepta, la celda vuelve a lo que tiene el
			var c = pendingShip.get(s);
			pendingShip.remove(s);
			if( !ok ) {
				var cc = shipCoords(c.x, c.y, c.z);
				applyShipCells([{ key : ((cc.x + cc.y * (1 << Const.BITS)) << WorldData.ZBITS) | cc.z, v : current }]);
			}
		case SShipCells(list):
			applyShipCells(list);
		case SSetResult(s, ok, current):
			var key = pending.get(s);
			pending.remove(s);
			// el servidor manda tambien el cambio real (SChanges) si lo habia; aqui solo hace falta deshacer lo que no se acepto
			if( !ok && key != null ) apply(key, current, false);
		case SStates(list):
			remotes.setStates(list);
		case SGone(id):
			remotes.remove(id);
		case SReduceWater:
			applying = true;
			g.world.reduceWater();
			applying = false;
		case SInventory(ack, inv):
			applyInv(ack, inv);
		case SAddLoot(l):
			addLoot(l);
		case SDeleteLoot(id):
			var d = loots.get(id);
			if( d != null ) {
				loots.remove(id);
				if( d.pending ) Snd.play("pickupBlock", 0.3);
				g.drops.remove(d);
			}
		case SLootCount(id, n):
			var d = loots.get(id);
			if( d != null ) {
				d.n = n;
				// pedido y no cogido entero (no cabe): vuelve a verse
				if( d.pending ) {
					d.pending = false;
					if( d.obj != null ) d.obj.visible = true;
				}
			}
		case SLootRest(id, x, y, z):
			var d = loots.get(id);
			if( d != null ) {
				d.x = x;
				d.y = y;
				d.z = z;
				d.vx = d.vy = d.vz = 0;
			}
		case SChest(x, y, z, ver, t, busy):
			if( busy != "" ) {
				if( onToast != null ) onToast(Lang.t("mp.chest.busy").split("%n%").join(busy));
				return;
			}
			if( ver < 0 ) {
				// rota por otro: la ventana se cierra
				if( chest != null && chest.x == x && chest.y == y && chest.z == z ) {
					chest = null;
					if( onCloseChest != null ) onCloseChest();
				}
				return;
			}
			if( chest != null && chest.x == x && chest.y == y && chest.z == z ) {
				chest.ver = ver;
				for( i in 0...chest.box.length ) chest.box[i] = i < t.length && t[i] != null ? { k : t[i].k, n : t[i].n } : null;
			} else {
				var box : Protocol.BlockInventory = [for( s in t ) s == null ? null : { k : s.k, n : s.n }];
				chest = { x : x, y : y, z : z, ver : ver, box : box };
				if( onOpenChest != null ) onOpenChest(box);
			}
		case SHit(dmg):
			g.netHit(dmg);
		case SBomb(x, y, z):
			g.netBomb(x, y, z);
		default:
		}
	}

	/** el inventario del servidor, y encima lo que el jugador ha hecho despues (peticiones posteriores a ack) */
	function applyInv( ack : Int, ni : NetInv ) {
		var i = g.inv.inv;
		for( k in 0...i.t.length ) {
			var s = k < ni.t.length ? ni.t[k] : null;
			i.t[k] = s == null ? null : { k : s.k, n : s.n };
		}
		i.charges.splice(0, i.charges.length);
		for( c in ni.charges ) i.charges.push({ c : c.c, n : c.n });
		predicted = predicted.filter(p -> p.seq > ack);
		for( p in predicted ) {
			var s = p.slot >= 1 && p.slot <= i.t.length ? i.t[p.slot - 1] : null;
			if( s == null ) continue;
			s.n -= p.n;
			if( s.n <= 0 ) i.t[p.slot - 1] = null;
		}
		g.inv.display();
	}

	function addLoot( l : NetLoot ) {
		// los de la nave llegan en sus coordenadas (ServerShip): a las del planeta, donde esta la nave
		if( l.z >= WorldData.SHIP_Z ) {
			var p = planetCoords(l.x, l.y);
			l.x = p.x;
			l.y = p.y;
		}
		var old = loots.get(l.id);
		if( old != null ) {
			// rechazada la recogida: el suelto vuelve a verse
			old.pending = false;
			if( old.obj != null ) old.obj.visible = true;
			old.x = l.x;
			old.y = l.y;
			old.z = l.z;
			return;
		}
		var b = l.gi > 0 && l.gi < Block.all.length ? Block.all[l.gi] : DeathDrops.block();
		var d = g.drops.add(l.x, l.y, l.z, b);
		d.netId = l.id;
		d.vx = l.vx;
		d.vy = l.vy;
		d.vz = l.vz;
		d.n = l.n;
		d.delay = l.delay;
		// caduca en el servidor, no aqui
		d.time = Math.POSITIVE_INFINITY;
		loots.set(l.id, d);
	}

	/** pone la celda key como dice el servidor (valor de editMap: bloque global | nivel << 16) si no lo esta ya */
	function apply( key : Int, v : Int, effects : Bool ) {
		var w = g.world;
		var z = key & (WorldData.HEIGHT - 1), col = key >> WorldData.ZBITS;
		var x = col % w.size, y = Std.int(col / w.size);
		var gi = v & 0xFFFF, lvl = v >> 16;
		var b = gi == 0 || gi >= Block.all.length ? null : Block.all[gi];
		var old = w.block(x, y, z);
		if( old == b && w.waterLevelAt(x, y, z) == lvl ) return;
		applying = true;
		if( b != null && b.type == BTWater ) w.setWater(x, y, z, b, lvl) else w.setBlock(x, y, z, b);
		applying = false;
		// lo que rompen los demas se ve romperse
		if( effects && b == null && old != null && old.type != BTWater ) @:privateAccess g.parts.doBreak(x, y, z, old);
	}

	inline function cellKey( x : Int, y : Int, z : Int ) return ((x + y * g.world.size) << WorldData.ZBITS) | z;

	public function devInfo() return remotes.devInfo() + " pendientes " + Lambda.count(pending) + " sueltos " + Lambda.count(loots);
}
