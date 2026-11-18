import Common;
import Msg;
import SaveData.SaveInfo;
import GameServer.Session;

/** accesos de un planeta (planets.access en JSON): abierto, todos los invitados visitantes, visita para todo el servidor, lo que
    pueden hacer los visitantes (Rights) y los invitados (uid y papel: 0 explorador, 1 visitante) */
typedef PlanetAccess = { open : Bool, allVisitors : Bool, serverVisit : Bool, vr : Int, guests : Array<{ uid : String, role : Int }> };

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
	public var items(default, null) : ServerItems;
	public var econ(default, null) : ServerEcon;
	/** pruebas (port/headless/NetTest.hx): semilla de todas las partidas nuevas, para tener siempre el mismo terreno */
	public static var fixedSeed : Null<Int> = null;
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
		items = new ServerItems(this, server, db);
		econ = new ServerEcon(this, server);
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
		items.sendInv(s);
		sendForeign(s);
		return true;
	}

	function newGame( s : Session, tuto : Bool ) {
		if( s.record != null ) return;
		var seed = fixedSeed != null ? fixedSeed : 1 + SecureRandom.int(999998);
		s.record = TutoSetup.newGame(s.display, seed, tuto);
		s.record.dropOnDeath = server.files.options.deathDrop;
		saveRecord(s);
		server.files.log(s.display + " empieza en el sector " + seed + (tuto ? " con el tutorial" : ""));
		sendRecord(s);
		items.sendInv(s);
		sendForeign(s);
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

	/** la partida de s ha cambiado: se guarda en el siguiente commit */
	public inline function markRecord( s : Session ) saveRecord(s);

	function saveRecord( s : Session ) {
		if( s.record == null ) return;
		dirtyRecords.set(s.uid, s);
	}

	/**
	 * La partida que manda el cliente (al guardar, al despegar): solo se toma lo que no da nada, donde esta y lo que ha visto.
	 * Lo demas es del servidor, que lo cambia con sus reglas: inventario y contenedores (ServerItems), creditos, mercado,
	 * contratos y planeta principal (ServerEcon), licencias (land, CAbandon), terreno (planet_edits), modo y tiempo de juego.
	 * Provisional hasta que el servidor lleve tambien la nave (sus cambios, cantinas y stockage), el hangar, la nodriza, la
	 * cometa y el tutorial: eso aun se toma del cliente.
	 */
	function clientRecord( s : Session, data : haxe.io.Bytes ) {
		var o : Dynamic;
		try o = haxe.Json.parse(NetZip.unpackString(data, 16 << 20)) catch( e : Dynamic ) return;
		var info = SaveData.parse(o, s.uid);
		var r = s.record;
		if( info == null || r == null ) return;
		r.px = info.px;
		r.py = info.py;
		r.pz = info.pz;
		r.yaw = info.yaw;
		r.pitch = info.pitch;
		r.fly = info.fly;
		r.life = info.life;
		r.saved = info.saved;
		r.savedWith = info.savedWith;
		r.kub = info.kub;
		r.shipEdits = info.shipEdits;
		r.shipData = info.shipData;
		r.storage = info.storage;
		r.hangar = info.hangar;
		r.mothership = info.mothership;
		r.inMother = info.inMother;
		// las cantinas de los planetas son del servidor (planet_chests): de la partida, solo las de la nave
		r.chests = info.chests == null ? null : info.chests.filter(c -> StringTools.startsWith(c.key, "s:"));
		r.comet = info.comet;
		r.tuto = info.tuto;
		r.tutorial = info.tutorial;
		var u = info.uni, ru = r.uni;
		if( u != null && ru != null ) {
			ru.pos = u.pos;
			ru.robot = u.robot;
			ru.ship = u.ship;
			ru.traveled = u.traveled;
			ru.comets = u.comets;
			// en un planeta de otro jugador: su partida sigue en su galaxia (al volver, en el espacio)
			ru.space = s.instance != null && s.instance.row.galaxy != s.uid ? true : u.space;
			// los planetas visitados sin sus cambios (estan en planet_edits), y solo los de su galaxia que tiene
			ru.planets = [for( p in u.planets ) if( Licenses.has(ru, p.id) ) { id : p.id, edits : [], shipAt : p.shipAt, genVersion : p.genVersion }];
		}
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
		// licencias: el servidor cuenta los planetas que tiene (tambien los cedidos por otros); gestionnaires y creativo, sin limite
		if( !s.isManager() && s.record.creative != true && ownedCount(s.uid) >= Licenses.MAX ) return null;
		row = { gkey : gkey, owner : s.uid, galaxy : s.uid, pid : pid, seed : f.p.seed, biome : f.p.biome, size : f.p.size,
			gen : gen.Generator.VERSION, shipAt : "", access : "" };
		// lo de una partida solo (la del anfitrion, al hospedarla): el planeta guardado pasa al servidor la primera vez
		var saved : Array<Int> = null;
		for( q in uni.planets ) if( q.id == pid ) {
			if( q.genVersion != null ) row.gen = SaveData.genVersion(q.genVersion);
			if( q.shipAt != null ) row.shipAt = haxe.Json.stringify(q.shipAt);
			saved = q.edits;
		}
		if( uni.planetId == pid && s.record.edits != null && s.record.edits.length > 0 ) {
			saved = s.record.edits;
			row.gen = SaveData.genVersion(s.record.genVersion);
			if( s.record.shipAt != null ) row.shipAt = haxe.Json.stringify(s.record.shipAt);
		}
		db.begin();
		db.putPlanet(row);
		if( saved != null && saved.length > 0 ) importEdits(row, saved);
		db.commit();
		return row;
	}

	/** los cambios de una partida solo, a los trozos del servidor */
	function importEdits( row : ServerDb.PlanetRow, flat : Array<Int> ) {
		var size = row.size << Const.BITS;
		var chunks = new Map<Int, Array<Int>>();
		var i = 0;
		while( i + 1 < flat.length ) {
			var k = flat[i], v = flat[i + 1];
			i += 2;
			var col = k >> WorldData.ZBITS;
			var c = k < 0 ? -1 : ((col % size) >> 4) | ((Std.int(col / size) >> 4) << 8);
			var l = chunks.get(c);
			if( l == null ) chunks.set(c, l = []);
			l.push(k);
			l.push(v);
		}
		for( c => l in chunks ) db.saveEditChunk(row.gkey, c, l);
	}

	function ownedCount( uid : String ) : Int {
		var n = 0;
		for( p in db.allPlanets() ) if( p.owner == uid ) n++;
		return n;
	}

	function instance( gkey : String, row : ServerDb.PlanetRow ) : PlanetInstance {
		var inst = instances.get(gkey);
		if( inst != null ) return inst;
		var created : PlanetInstance = null;
		inst = created = new PlanetInstance(row, db.loadEdits(gkey), function( x, y, z, b ) items.onBreak(created, x, y, z, b, false), function( x, y, z, b ) items.lavaBomb(created, x, y, z));
		items.load(inst);
		instances.set(gkey, inst);
		server.files.log("planeta " + gkey + " cargado (" + row.biome + ", " + row.size + ")");
		return inst;
	}

	function currentEdits( inst : PlanetInstance ) : Array<Int> {
		return inst.ready() ? inst.world.editsFlat() : db.loadEdits(inst.key);
	}

	/** s entra en el planeta row */
	function enterRow( s : Session, row : ServerDb.PlanetRow ) : PlanetInstance {
		leaveInstance(s);
		var inst = instance(row.gkey, row);
		inst.players.push(s);
		items.sendLoots(s, inst);
		s.instance = inst;
		s.where = row.gkey;
		s.rights = rightsFor(s.uid, inst.row);
		return inst;
	}

	/** s entra en el planeta pid de su galaxia (al conectarse, si estaba en el) */
	function enter( s : Session, gkey : String, pid : Int ) : PlanetInstance {
		var row = planetRow(s, pid);
		if( row == null || rightsFor(s.uid, row) & REnter == 0 ) return null;
		return enterRow(s, row);
	}

	function leaveInstance( s : Session ) {
		var inst = s.instance;
		if( inst == null ) return;
		inst.players.remove(s);
		if( inst.players.length == 0 ) inst.emptySince = haxe.Timer.stamp();
		for( o in inst.players ) o.send(SGone(s.id));
		items.release(s);
		s.instance = null;
		s.where = "";
		s.pos = null;
		s.rights = 0;
	}

	function land( s : Session, galaxy : String, pid : Int ) {
		var row : ServerDb.PlanetRow = null;
		if( galaxy == "" ) row = planetRow(s, pid);
		else {
			var g = db.uidOfPub(galaxy);
			if( g != null ) row = db.getPlanet(g + ":" + pid);
		}
		if( row == null || rightsFor(s.uid, row) & REnter == 0 ) {
			s.send(SPlanetLost("mp.land.denied"));
			return;
		}
		var inst = enterRow(s, row);
		if( galaxy == "" ) {
			var uni = s.record.uni;
			uni.planetId = pid;
			uni.space = null;
			// escanear gasta una licencia (GalaxyApp.landOnPlanet hace lo mismo en su copia); planetRow ya ha mirado que quede
			Licenses.claim(s.record, pid);
			saveRecord(s);
			s.send(SPatch("licenses", haxe.Json.stringify({ licenses : uni.licenses, main : uni.main })));
		}
		s.send(SPlanetData(inst.key, row.seed, row.biome, row.size, row.gen, row.shipAt, NetZip.packInts(currentEdits(inst)),
			server.db.displayOf(row.owner), s.rights));
	}

	function takeoff( s : Session ) {
		leaveInstance(s);
		if( s.record != null && s.record.uni != null ) {
			s.record.uni.space = true;
			saveRecord(s);
		}
	}

	public function onLeave( s : Session ) {
		if( s.instance != null && s.instance.row.galaxy != s.uid && s.record != null && s.record.uni != null ) {
			s.record.uni.space = true;
			saveRecord(s);
		}
		leaveInstance(s);
	}

	// ---------------------------------------------------------------- accesos

	static function readAccess( j : String ) : PlanetAccess {
		var a : PlanetAccess = { open : false, allVisitors : false, serverVisit : false, vr : 0, guests : [] };
		if( j == null || j == "" ) return a;
		try {
			var o : Dynamic = haxe.Json.parse(j);
			a.open = o.open == true;
			a.allVisitors = o.allVisitors == true;
			a.serverVisit = o.serverVisit == true;
			a.vr = Std.int(o.vr) & ((RChests : Int) | (RActivate : Int) | (RPickup : Int));
			if( o.guests != null ) for( g in (o.guests : Array<Dynamic>) ) a.guests.push({ uid : Std.string(g.uid), role : Std.int(g.role) == 1 ? 1 : 0 });
		} catch( e : Dynamic ) {}
		return a;
	}

	/** derechos de uid en el planeta row (Rights): el propietario todo; cerrado, nadie mas; un invitado como explorador o visitante */
	function rightsFor( uid : String, row : ServerDb.PlanetRow ) : Int {
		if( row.owner == uid ) return Rights.ALL;
		var a = readAccess(row.access);
		if( !a.open ) return 0;
		for( g in a.guests )
			if( g.uid == uid ) return a.allVisitors || g.role == (GVisitor : Int) ? (REnter : Int) | (RVisitor : Int) | a.vr : Rights.EXPLORER;
		if( a.serverVisit ) return (REnter : Int) | (RVisitor : Int) | a.vr;
		return 0;
	}

	/** el planeta pid de s como propietario: en su galaxia, o cedido por otro y en el que esta ahora */
	function ownedPlanet( s : Session, pid : Int ) : ServerDb.PlanetRow {
		var row = db.getPlanet(ownKey(s, pid));
		if( row != null && row.owner == s.uid ) return row;
		if( s.instance != null && s.instance.row.pid == pid && s.instance.row.owner == s.uid ) return s.instance.row;
		return null;
	}

	function saveAccess( row : ServerDb.PlanetRow, a : PlanetAccess ) {
		row.access = haxe.Json.stringify(a);
		db.begin();
		db.putPlanet(row);
		db.commit();
		var inst = instances.get(row.gkey);
		if( inst != null ) inst.row = row;
		enforce(row);
	}

	/** tras cambiar los accesos: derechos al dia de los que estan alli, fuera los que ya no pueden, mapas al dia */
	function enforce( row : ServerDb.PlanetRow ) {
		var inst = instances.get(row.gkey);
		if( inst != null )
			for( p in inst.players.copy() ) {
				var r = rightsFor(p.uid, row);
				if( r & REnter == 0 ) {
					leaveInstance(p);
					p.send(SPlanetLost("mp.planet.closed"));
				} else if( r != p.rights ) {
					p.rights = r;
					p.send(SRights(r));
				}
			}
		for( p in server.playing() ) sendForeign(p);
	}

	function sendAccess( s : Session, row : ServerDb.PlanetRow ) {
		var a = readAccess(row.access);
		var guests = [for( g in a.guests ) { pub : db.pubOf(g.uid), name : db.displayOf(g.uid), role : g.role }];
		s.send(SAccess(row.pid, a.open, a.allVisitors, a.serverVisit, a.vr, guests));
	}

	/** galaxias de otros con planetas accesibles para s: sus sistemas enteros, con el estado de cada planeta para s */
	public function sendForeign( s : Session ) {
		if( s.record == null ) return;
		var byGalaxy = new Map<String, Array<ServerDb.PlanetRow>>();
		for( p in db.allPlanets() ) {
			if( p.galaxy == s.uid ) continue;
			if( rightsFor(s.uid, p) & REnter == 0 ) continue;
			var l = byGalaxy.get(p.galaxy);
			if( l == null ) byGalaxy.set(p.galaxy, l = []);
			l.push(p);
		}
		var out = [];
		for( g => rows in byGalaxy ) {
			var owner = db.getPlayer(g);
			if( owner == null || owner.record == "" ) continue;
			var rec : Dynamic = try haxe.Json.parse(owner.record) catch( e : Dynamic ) null;
			if( rec == null || rec.uni == null ) continue;
			var seed = Std.int(rec.uni.seed), st : Dynamic = rec.uni.start;
			var gone : Array<Int> = rec.uni.gone == null ? [] : [for( v in (rec.uni.gone : Array<Dynamic>) ) Std.int(v)];
			var start = st == null ? null : { seed : Std.int(st.seed), biome : Std.string(st.biome), size : Std.int(st.size) };
			var d = ExpData.ExpOffline.make(seed, start, null, null, null, gone);
			var planets = new Array<NetForeignPlanet>();
			var systems = new Map<Int, Bool>();
			for( r in rows ) {
				var f = ExpData.ExpOffline.planet(d, r.pid);
				if( f != null ) systems.set(f.s.id, true);
			}
			for( sys in d.systems ) {
				if( !systems.exists(sys.id) ) continue;
				for( p in sys.planets ) {
					var row = Lambda.find(rows, r -> r.pid == p.id);
					var status : ExpData.ExpPlanetStatus = PForbidden;
					if( row != null ) {
						var r = rightsFor(s.uid, row);
						status = r & ROwner != 0 ? PActive : (r & RVisitor != 0 ? PVisit : PInvited);
					}
					planets.push({ pid : p.id, status : Type.enumIndex(status) });
				}
			}
			out.push({ pub : db.pubOf(g), owner : owner.display, seed : seed, startSeed : start == null ? 0 : start.seed,
				startBiome : start == null ? "" : start.biome, startSize : start == null ? 0 : start.size, gone : gone, planets : planets });
		}
		s.send(SForeign(out));
	}

	function accessMessage( s : Session, m : ClientMsg ) {
		switch( m ) {
		case CGetAccess(pid):
			var row = ownedPlanet(s, pid);
			if( row != null ) sendAccess(s, row);
		case CAccess(pid, open, allVisitors, serverVisit, vr):
			var row = ownedPlanet(s, pid);
			if( row == null ) return;
			var a = readAccess(row.access);
			a.open = open;
			a.allVisitors = allVisitors;
			// la visita de todo el servidor solo la pone un gestionnaire
			a.serverVisit = serverVisit && s.isManager();
			a.vr = vr & ((RChests : Int) | (RActivate : Int) | (RPickup : Int));
			saveAccess(row, a);
			sendAccess(s, row);
		case CInvite(pid, target, role):
			var row = ownedPlanet(s, pid);
			var t = server.sessionById(target);
			if( row == null || t == null || t.uid == s.uid ) return;
			var a = readAccess(row.access);
			a.guests = a.guests.filter(g -> g.uid != t.uid);
			a.guests.push({ uid : t.uid, role : role });
			saveAccess(row, a);
			sendAccess(s, row);
			t.send(SNotice("mp.invited", [s.display]));
			server.files.log(s.display + " invita a " + t.display + " a " + row.gkey + (role == 1 ? " (visitante)" : ""));
		case CGuest(pid, pub, role):
			var row = ownedPlanet(s, pid);
			var uid = db.uidOfPub(pub);
			if( row == null || uid == null ) return;
			var a = readAccess(row.access);
			if( role < 0 ) a.guests = a.guests.filter(g -> g.uid != uid);
			else for( g in a.guests ) if( g.uid == uid ) g.role = role;
			saveAccess(row, a);
			sendAccess(s, row);
		case CTransfer(pid, target):
			var row = ownedPlanet(s, pid);
			var t = server.sessionById(target);
			if( row == null || t == null || t.uid == s.uid || t.record == null ) return;
			// el que lo recibe necesita una licencia libre, salvo que sea gestionnaire o este en creativo
			if( !t.isManager() && t.record.creative != true && ownedCount(t.uid) >= Licenses.MAX ) {
				s.send(SNotice("mp.transfer.full", [t.display]));
				return;
			}
			var a = readAccess(row.access);
			a.guests = a.guests.filter(g -> g.uid != t.uid && g.uid != s.uid);
			// el que lo cede se queda como explorador
			a.guests.push({ uid : s.uid, role : 0 });
			a.open = true;
			row.owner = t.uid;
			if( s.record.uni != null && row.galaxy == s.uid ) s.record.uni.licenses = s.record.uni.licenses.filter(l -> l != pid);
			saveRecord(s);
			saveAccess(row, a);
			server.files.log(s.display + " cede " + row.gkey + " a " + t.display);
			t.send(SNotice("mp.transfer.got", [s.display]));
			s.send(SNotice("mp.transfer.done", [t.display]));
		case CAbandon(pid):
			var row = ownedPlanet(s, pid);
			if( row == null ) return;
			var inst = instances.get(row.gkey);
			if( inst != null ) {
				for( p in inst.players.copy() ) {
					leaveInstance(p);
					if( p != s ) p.send(SPlanetLost("mp.planet.abandoned"));
				}
				instances.remove(row.gkey);
			}
			db.begin();
			db.deletePlanet(row.gkey);
			db.commit();
			// un planeta de su galaxia: pierde la licencia y, si era el ultimo del sistema, el sistema (Licenses.abandon, lo mismo
			// que hace el cliente en su copia); uno cedido por otro solo se borra
			var uni = s.record == null ? null : s.record.uni;
			if( uni != null && row.galaxy == s.uid ) {
				var f = ExpData.ExpOffline.planet(ExpData.ExpOffline.make(uni.seed, uni.start, null, null, null, uni.gone), pid);
				if( f != null ) Licenses.abandon(s.record, f.p, f.s);
				saveRecord(s);
				s.send(SPatch("licenses", haxe.Json.stringify({ licenses : uni.licenses, main : uni.main, abandoned : uni.abandoned, gone : uni.gone })));
			}
			server.files.log(s.display + " abandona " + row.gkey);
			for( p in server.playing() ) sendForeign(p);
		default:
		}
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
		if( s.rights & RBuild == 0 ) {
			switch( m ) {
			case CBreak(seq, _, _, _, _), CPlace(seq, _, _, _, _, _, _): s.send(SSetResult(seq, false, 0));
			default:
			}
			return;
		}
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
			items.onBreak(inst, x, y, z, cur, s.creative);
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
			// el bloque sale de su inventario (lo lleva el servidor): si no lo tiene, no se pone
			if( !items.consumeForPlace(s, slot, gi) ) {
				s.send(SSetResult(seq, false, w.valueAt(key)));
				items.sendInv(s);
				return;
			}
			if( b.type == BTWater ) w.setWater(x, y, z, b, level) else w.setBlock(x, y, z, b);
			inst.process.onSet(x, y, z, cur, b);
			s.send(SSetResult(seq, true, gi));
			s.ack = seq;
			if( !s.creative ) items.sendInv(s);
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
		case CAccess(_, _, _, _, _), CInvite(_, _, _), CGuest(_, _, _), CTransfer(_, _), CAbandon(_), CGetAccess(_):
			if( s.record != null ) accessMessage(s, m);
		case CSaveRecord(data):
			if( s.record != null ) clientRecord(s, data);
		case CEcon(seq, op, a, n):
			if( s.record != null ) econ.handle(s, seq, op, a, n);
		default:
			return items.handle(s, m);
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
		// el tiempo de juego de cada uno (los precios del robot vuelven a lo normal con el: Market.advance); se guarda con lo demas
		for( s in server.playing() ) if( s.record != null ) s.record.playSeconds += TICK;
		for( inst in instances.copy() ) {
			if( inst.players.length == 0 ) {
				if( now - inst.emptySince > UNLOAD ) unload(inst);
				continue;
			}
			var dropped = inst.tick(TICK);
			items.tick(inst, TICK);
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
		items.save(inst);
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
