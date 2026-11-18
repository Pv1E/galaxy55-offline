import Common;
import Msg;
import SaveData.SaveInfo;
import GameServer.Session;

/**
 * El mundo compartido del servidor (anadido del port, multijugador): la partida de cada jugador (su SaveInfo, guardado en la
 * base de datos), los planetas cargados (PlanetInstance) y lo que pasa en ellos: aterrizar y despegar, la posicion de cada uno
 * (a los demas del mismo planeta, 20 veces por segundo), romper y poner bloques (comprobado aqui y mandado a todos) y el
 * proceso del mundo, que solo corre en el servidor. Cada segundo se guarda todo junto en una transaccion: tras un corte, nunca
 * queda un bloque roto en un sitio y no en otro.
 */
class ServerWorlds {

	var server : GameServer;
	var db : ServerDb;
	var instances = new Map<String, PlanetInstance>();
	var dirtyRecords = new Map<String, Session>();
	var tickAcc = 0.;
	var commitAcc = 0.;
	static inline var TICK = 0.05;
	static inline var COMMIT = 1.;
	/** un planeta vacio se descarga al cabo de (s) */
	static inline var UNLOAD = 60.;
	/** distancia maxima (bloques) entre un jugador y la celda que rompe o pone */
	static inline var REACH = 10.;

	public function new( server : GameServer, db : ServerDb ) {
		this.server = server;
		this.db = db;
	}

	// ---------------------------------------------------------------- partidas de los jugadores

	/** al entrar: su partida, o null si es nuevo (espera CNewGame) */
	public function onLogin( s : Session ) : Bool {
		var row = db.getPlayer(s.uid);
		if( row == null || row.record == "" ) return false;
		try s.record = SaveData.parse(haxe.Json.parse(row.record), s.uid) catch( e : Dynamic ) s.record = null;
		if( s.record == null ) {
			server.files.log("partida ilegible de " + s.display + ": se empieza de nuevo");
			return false;
		}
		sendRecord(s);
		return true;
	}

	function newGame( s : Session, tuto : Bool ) {
		if( s.record != null ) return;
		var seed = 1 + SecureRandom.int(999998);
		s.record = TutoSetup.newGame(s.display, seed, tuto);
		s.record.dropOnDeath = server.files.options.deathDrop;
		saveRecord(s);
		server.files.log(s.display + " empieza en el sector " + seed + (tuto ? " con el tutorial" : ""));
		sendRecord(s);
	}

	/** la partida al cliente; si esta en un planeta, con el terreno de ese planeta (que es del servidor) */
	function sendRecord( s : Session ) {
		var info = s.record;
		if( info.uni != null && info.uni.space != true && info.hangar != true && info.mothership != true ) {
			var inst = enter(s, ownKey(s, info.uni.planetId), info.uni.planetId);
			if( inst != null ) {
				info.edits = currentEdits(inst);
				info.shipAt = readShipAt(inst.row.shipAt);
				info.genVersion = inst.row.gen;
			}
		}
		var json = haxe.Json.stringify(info);
		s.send(SRecord(NetZip.packString(json)));
	}

	function saveRecord( s : Session ) {
		if( s.record == null ) return;
		dirtyRecords.set(s.uid, s);
	}

	/** provisional (hasta que el servidor lleve inventario y economia): la partida que manda el cliente, sin el terreno */
	function clientRecord( s : Session, data : haxe.io.Bytes ) {
		var o : Dynamic;
		try o = haxe.Json.parse(NetZip.unpackString(data, 16 << 20)) catch( e : Dynamic ) return;
		var info = SaveData.parse(o, s.uid);
		if( info == null ) return;
		// el terreno es del servidor (planet_edits): no se guarda en la partida
		info.edits = [];
		if( info.uni != null ) for( p in info.uni.planets ) p.edits = [];
		s.record = info;
		saveRecord(s);
	}

	// ---------------------------------------------------------------- planetas

	inline function ownKey( s : Session, pid : Int ) return s.uid + ":" + pid;

	static function readShipAt( j : String ) : { x : Int, y : Int } {
		if( j == null || j == "" ) return null;
		try {
			var o : Dynamic = haxe.Json.parse(j);
			return { x : Std.int(o.x), y : Std.int(o.y) };
		} catch( e : Dynamic ) return null;
	}

	/** el planeta pid de la galaxia de s: lo da de alta la primera vez (semilla, bioma y tamano los da el mapa, ExpOffline) */
	function planetRow( s : Session, pid : Int ) : ServerDb.PlanetRow {
		var gkey = ownKey(s, pid);
		var row = db.getPlanet(gkey);
		if( row != null ) return row;
		var uni = s.record.uni;
		if( uni == null ) return null;
		var d = ExpData.ExpOffline.make(uni.seed, uni.start, null, null, null, uni.gone);
		var f = ExpData.ExpOffline.planet(d, pid);
		if( f == null ) return null;
		row = { gkey : gkey, owner : s.uid, galaxy : s.uid, pid : pid, seed : f.p.seed, biome : f.p.biome, size : f.p.size,
			gen : gen.Generator.VERSION, shipAt : "", access : "" };
		// los cambios de una partida solo (la del anfitrion) pasan al planeta la primera vez
		for( q in uni.planets ) if( q.id == pid ) {
			if( q.genVersion != null ) row.gen = SaveData.genVersion(q.genVersion);
			if( q.shipAt != null ) row.shipAt = haxe.Json.stringify(q.shipAt);
		}
		db.begin();
		db.putPlanet(row);
		db.commit();
		return row;
	}

	function instance( gkey : String, row : ServerDb.PlanetRow ) : PlanetInstance {
		var inst = instances.get(gkey);
		if( inst != null ) return inst;
		inst = new PlanetInstance(row, db.loadEdits(gkey));
		instances.set(gkey, inst);
		server.files.log("planeta " + gkey + " cargado (" + row.biome + ", " + row.size + ")");
		return inst;
	}

	function currentEdits( inst : PlanetInstance ) : Array<Int> {
		return inst.ready() ? inst.world.editsFlat() : db.loadEdits(inst.key);
	}

	/** s entra en el planeta pid de su galaxia */
	function enter( s : Session, gkey : String, pid : Int ) : PlanetInstance {
		leaveInstance(s);
		var row = planetRow(s, pid);
		if( row == null ) return null;
		var inst = instance(gkey, row);
		inst.players.push(s);
		s.instance = inst;
		s.where = gkey;
		return inst;
	}

	function leaveInstance( s : Session ) {
		var inst = s.instance;
		if( inst == null ) return;
		inst.players.remove(s);
		if( inst.players.length == 0 ) inst.emptySince = haxe.Timer.stamp();
		for( o in inst.players ) o.send(SGone(s.id));
		s.instance = null;
		s.where = "";
		s.pos = null;
	}

	function land( s : Session, galaxy : String, pid : Int ) {
		if( galaxy != "" ) {
			// los planetas de otros (invitaciones) llegan con los accesos
			s.send(SNotice("mp.land.denied", []));
			return;
		}
		var inst = enter(s, ownKey(s, pid), pid);
		if( inst == null ) {
			s.send(SNotice("mp.land.denied", []));
			return;
		}
		var uni = s.record.uni;
		uni.planetId = pid;
		uni.space = null;
		saveRecord(s);
		var row = inst.row;
		s.send(SPlanetData(inst.key, row.seed, row.biome, row.size, row.gen, row.shipAt, NetZip.packInts(currentEdits(inst)),
			server.db.displayOf(row.owner), 0xFFFF));
	}

	function takeoff( s : Session ) {
		leaveInstance(s);
		if( s.record != null && s.record.uni != null ) {
			s.record.uni.space = true;
			saveRecord(s);
		}
	}

	public function onLeave( s : Session ) {
		leaveInstance(s);
	}

	// ---------------------------------------------------------------- romper y poner

	function near( s : Session, inst : PlanetInstance, x : Int, y : Int, z : Int ) : Bool {
		var p = s.pos;
		if( p == null ) return false;
		var size = inst.world.size;
		inline function d( a : Float, b : Float ) {
			var v = Math.abs(a - b) % size;
			return v > size * 0.5 ? size - v : v;
		}
		var dx = d(p.x, x + 0.5), dy = d(p.y, y + 0.5), dz = p.z + 1.5 - (z + 0.5);
		return dx * dx + dy * dy + dz * dz <= REACH * REACH;
	}

	function blockChange( s : Session, m : ClientMsg ) {
		var inst = s.instance;
		if( inst == null ) return;
		if( !inst.ready() ) {
			inst.waiting.push({ s : s, m : m });
			return;
		}
		switch( m ) {
		case CBreak(seq, x, y, z, gi):
			// la nave es de cada uno y aun no la lleva el servidor
			if( z >= WorldData.SHIP_Z ) { s.send(SSetResult(seq, true, gi)); return; }
			var w = inst.world;
			var key = ((x + y * w.size) << WorldData.ZBITS) | z;
			var cur = x < w.size && y < w.size && z < WorldData.HEIGHT ? w.blockAtKey(key) : null;
			if( cur == null || cur.index != gi || z < 1 || !near(s, inst, x, y, z) ) {
				s.send(SSetResult(seq, false, x < w.size && y < w.size && z < WorldData.HEIGHT ? w.valueAt(key) : 0));
				return;
			}
			w.setBlock(x, y, z, null);
			inst.process.onSet(x, y, z, cur, null);
			s.send(SSetResult(seq, true, 0));
		case CPlace(seq, x, y, z, gi, level, slot):
			if( z >= WorldData.SHIP_Z ) { s.send(SSetResult(seq, true, gi)); return; }
			var w = inst.world;
			var b = gi < Block.all.length ? Block.all[gi] : null;
			var key = ((x + y * w.size) << WorldData.ZBITS) | z;
			var inside = x < w.size && y < w.size && z >= 1 && z < WorldData.HEIGHT - 1;
			var cur = inside ? w.blockAtKey(key) : null;
			if( b == null || !inside || (cur != null && !cur.canOverride() && cur.type != BTWater) || !near(s, inst, x, y, z) ) {
				s.send(SSetResult(seq, false, inside ? w.valueAt(key) : 0));
				return;
			}
			if( b.type == BTWater ) w.setWater(x, y, z, b, level) else w.setBlock(x, y, z, b);
			inst.process.onSet(x, y, z, cur, b);
			s.send(SSetResult(seq, true, gi));
		default:
		}
	}

	// ---------------------------------------------------------------- mensajes

	/** mensajes del mundo de un jugador ya dentro; true si era uno de ellos */
	public function handle( s : Session, m : ClientMsg ) : Bool {
		switch( m ) {
		case CNewGame(tuto):
			newGame(s, tuto);
		case CLand(galaxy, pid):
			if( s.record != null ) land(s, galaxy, pid);
		case CTakeoff:
			takeoff(s);
		case CState(p):
			p.id = s.id;
			s.pos = p;
		case CBreak(_, _, _, _, _), CPlace(_, _, _, _, _, _, _):
			blockChange(s, m);
		case CSaveRecord(data):
			if( s.record != null ) clientRecord(s, data);
		default:
			return false;
		}
		return true;
	}

	// ---------------------------------------------------------------- bucle

	/** budgetMs: tiempo para generar planetas en esta llamada */
	public function pump( dt : Float, budgetMs : Float ) {
		var t0 = haxe.Timer.stamp();
		for( inst in instances ) {
			if( inst.ready() ) continue;
			var left = budgetMs - (haxe.Timer.stamp() - t0) * 1000;
			if( left <= 0 ) break;
			if( inst.generate(left) ) {
				server.files.log("planeta " + inst.key + " generado");
				var w = inst.waiting;
				inst.waiting = [];
				for( q in w ) if( q.s.instance == inst ) blockChange(q.s, q.m);
			}
		}
		tickAcc += dt;
		var n = 0;
		while( tickAcc >= TICK && n++ < 3 ) {
			tickAcc -= TICK;
			tick();
		}
		if( tickAcc > TICK * 3 ) tickAcc = 0;
		commitAcc += dt;
		if( commitAcc >= COMMIT ) {
			commitAcc = 0;
			commit();
		}
	}

	function tick() {
		var now = haxe.Timer.stamp();
		for( inst in instances.copy() ) {
			if( inst.players.length == 0 ) {
				if( now - inst.emptySince > UNLOAD ) unload(inst);
				continue;
			}
			var dropped = inst.tick(TICK);
			var ch = inst.takeChanges();
			if( ch != null ) {
				var i = 0;
				while( i < ch.length ) {
					var part = ch.slice(i, i + Msg.CHANGES_MAX);
					for( p in inst.players ) p.send(SChanges(part));
					i += Msg.CHANGES_MAX;
				}
			}
			if( dropped ) for( p in inst.players ) p.send(SReduceWater);
			var states = [for( p in inst.players ) if( p.pos != null ) p.pos];
			if( states.length > 1 )
				for( p in inst.players ) p.send(SStates([for( st in states ) if( st.id != p.id ) st]));
		}
	}

	function unload( inst : PlanetInstance ) {
		saveInstance(inst);
		instances.remove(inst.key);
		server.files.log("planeta " + inst.key + " descargado");
	}

	function saveInstance( inst : PlanetInstance ) {
		if( !inst.ready() ) return;
		for( c => pairs in inst.world.takeDirty() ) db.saveEditChunk(inst.key, c, pairs);
	}

	/** todo lo cambiado, en una transaccion */
	public function commit() {
		db.begin();
		for( inst in instances ) saveInstance(inst);
		for( uid => s in dirtyRecords ) if( s.record != null ) db.setRecord(uid, haxe.Json.stringify(s.record));
		dirtyRecords = new Map();
		db.commit();
	}

	public function close() {
		commit();
	}
}
