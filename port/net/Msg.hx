import haxe.io.Bytes;

/** Por que el servidor no deja entrar o echa (SRefuse, SKicked); el cliente lo traduce (Lang "mp.refuse.*") */
enum abstract RefuseReason(Int) to Int from Int {
	var RVersion = 0;
	var RBanned = 1;
	var RPassword = 2;
	var RFull = 3;
	var RBadLogin = 4;
	var RKicked = 5;
	var RReplaced = 6;
	var RServerStop = 7;
	var RFlood = 8;
	var RProtocol = 9;
	public static inline var MAX = 9;
}

/** Papel de un jugador en el servidor */
enum abstract Role(Int) to Int from Int {
	var Player = 0;
	var Manager = 1;
	/** el anfitrion o el primero que entro en un servidor dedicado: no se le puede destituir, echar ni prohibir */
	var Owner = 2;
	public static inline var MAX = 2;
}

/** Canales del chat */
enum abstract ChatChan(Int) to Int from Int {
	var CWorld = 0;
	var CPlanet = 1;
	var CPrivate = 2;
	/** mensajes del servidor (llegadas, salidas, avisos) */
	var CServer = 3;
	public static inline var MAX = 3;
}

/** Ordenes de los gestionnaires (CAdmin) */
enum abstract AdminOp(Int) to Int from Int {
	var APromote = 0;
	var ADemote = 1;
	var AKick = 2;
	var ABan = 3;
	var APassword = 4;
	var AServerName = 5;
	var ALanVisible = 6;
	var ADeathDrop = 7;
	public static inline var MAX = 7;
}

/**
 * Estado de un jugador en el mundo, 20 veces por segundo: posicion de los pies, mirada, laser (activo, carga: -1 = sin carga, y
 * punto apuntado) y banderas (NetFlags). Lo que dibujan los demas: el cono, su nombre y su laser.
 */
typedef NetState = { id : Int, x : Float, y : Float, z : Float, yaw : Float, pitch : Float, flags : Int, charge : Int, hx : Float, hy : Float, hz : Float };

/** cambio de una celda del mundo: clave de WorldData (((x + y * size) << 7) | z) y valor de editMap (bloque global | nivel << 16) */
typedef NetChange = { key : Int, v : Int };

/** banderas de NetState */
enum abstract NetFlags(Int) to Int {
	var FLaser = 1;
	/** dentro de su nave (no se dibuja: cada uno ve solo la suya) */
	var FInShip = 2;
	var FJetpack = 4;
}

/** Jugador en la lista (Tab, Opciones multijugador): id de la sesion (no la identidad), pseudo, papel y donde esta */
typedef NetPlayer = { id : Int, name : String, role : Int, place : String };

enum ClientMsg {
	/** primer mensaje, sin cifrar: protocolo, version del juego, huella del contenido y clave X25519 efimera */
	CHello( proto : Int, version : String, content : String, eph : Bytes );
	/** ya cifrado: clave publica del jugador para este servidor, firma de la transcripcion, pseudo, contrasena, tutorial */
	CLogin( pk : Bytes, sig : Bytes, pseudo : String, password : String, tuto : Int );
	CPing( t : Float );
	CTalk( chan : Int, to : Int, msg : String );
	CAdmin( op : Int, target : Int, arg : String );
	/** cambia su propio modo (solo gestionnaires) */
	CSetMode( creative : Bool );
	CBye;
	/** jugador nuevo: empezar con o sin tutorial (tras SWelcome con firstTime) */
	CNewGame( tuto : Bool );
	/** aterrizar en un planeta: galaxia ("" = la suya) e id del planeta; el servidor contesta SPlanetData */
	CLand( galaxy : String, pid : Int );
	/** despegar: deja el planeta */
	CTakeoff;
	CState( s : NetState );
	/** romper el bloque gi de (x, y, z); seq numera las peticiones (SSetResult) */
	CBreak( seq : Int, x : Int, y : Int, z : Int, gi : Int );
	/** poner el bloque gi (nivel de agua level) en (x, y, z) desde la casilla slot del inventario */
	CPlace( seq : Int, x : Int, y : Int, z : Int, gi : Int, level : Int, slot : Int );
	/** partida del jugador (JSON comprimido): provisional, hasta que el servidor lleve el inventario y la economia */
	CSaveRecord( data : Bytes );
}

enum ServerMsg {
	/** respuesta sin cifrar: nombre, clave publica del servidor, su clave X25519 efimera, firma, si pide contrasena */
	SServerHello( name : String, pk : Bytes, eph : Bytes, sig : Bytes, password : Bool );
	SWelcome( id : Int, name : String, role : Int, creative : Bool, clock : Float, firstTime : Bool );
	SRefuse( reason : Int, detail : String );
	SPong( t : Float, serverTime : Float );
	SPlayers( list : Array<NetPlayer> );
	SUserJoin( p : NetPlayer );
	SUserLeave( id : Int );
	STalk( from : Int, name : String, chan : Int, msg : String );
	/** aviso traducible: clave de Lang y sus valores */
	SNotice( key : String, args : Array<String> );
	SMode( creative : Bool );
	SKicked( reason : Int, detail : String );
	/** la partida del jugador en este servidor (SaveInfo en JSON comprimido), con el terreno del planeta donde esta */
	SRecord( data : Bytes );
	/** datos de un planeta al aterrizar: semilla, bioma, tamano, version del generador, sitio de la nave (JSON o ""), cambios
	    del terreno (pares de enteros comprimidos), nombre del propietario y derechos del jugador alli (Access) */
	SPlanetData( key : String, seed : Int, biome : String, size : Int, genVersion : Int, shipAt : String, edits : Bytes, owner : String, rights : Int );
	SChanges( list : Array<NetChange> );
	/** respuesta a CBreak o CPlace: aceptado, o no y lo que hay de verdad en la celda (current) */
	SSetResult( seq : Int, ok : Bool, current : Int );
	SStates( list : Array<NetState> );
	/** ese jugador ya no esta en este planeta */
	SGone( id : Int );
	/** el mar ha bajado una capa en este planeta */
	SReduceWater;
}

/**
 * Protocolo del multijugador (anadido del port): mensajes del cliente (ClientMsg) y del servidor (ServerMsg), escritos a mano
 * con NetWriter/NetReader. Cada campo tiene su limite al leer (cadenas, listas, rangos): un mensaje que no cuadra lanza NetError.
 * PROTOCOL sube con cualquier cambio de un mensaje.
 */
class Msg {

	public static inline var PROTOCOL = 2;
	/** cambios de celdas en un mensaje, y bytes de un terreno descomprimido */
	public static inline var CHANGES_MAX = 1 << 16;
	public static inline var EDITS_MAX = 64 << 20;
	public static inline var NAME_MAX = 24;
	public static inline var CHAT_MAX = 200;
	public static inline var PASSWORD_MAX = 64;
	public static inline var SERVER_NAME_MAX = 48;
	public static inline var PLAYERS_MAX = 4096;

	static function writeState( w : NetWriter, s : NetState ) {
		w.uint(s.id); w.float(s.x); w.float(s.y); w.float(s.z); w.float(s.yaw); w.float(s.pitch);
		w.uint(s.flags); w.int(s.charge); w.float(s.hx); w.float(s.hy); w.float(s.hz);
	}

	static function readState( r : NetReader ) : NetState {
		var id = r.uint(); var x = r.floatIn(-1e5, 1e5); var y = r.floatIn(-1e5, 1e5); var z = r.floatIn(-1e3, 1e4);
		var yaw = r.floatIn(-1e3, 1e3); var pitch = r.floatIn(-1e3, 1e3); var flags = r.uintIn(0, 255); var charge = r.intIn(-1, 15);
		var hx = r.floatIn(-1e5, 1e5); var hy = r.floatIn(-1e5, 1e5); var hz = r.floatIn(-1e3, 1e4);
		return { id : id, x : x, y : y, z : z, yaw : yaw, pitch : pitch, flags : flags, charge : charge, hx : hx, hy : hy, hz : hz };
	}

	/** coordenadas de celda que puede mandar un cliente (planeta de hasta 384, nave y nodriza por encima) */
	static inline var COORD_MAX = 4096;
	static inline var Z_MAX = 512;

	static function writePlayer( w : NetWriter, p : NetPlayer ) {
		w.uint(p.id);
		w.string(p.name);
		w.uint(p.role);
		w.string(p.place);
	}

	static function readPlayer( r : NetReader ) : NetPlayer {
		var id = r.uint();
		var name = r.string(NAME_MAX + 8);
		var role = r.uintIn(0, Role.MAX);
		var place = r.string(64);
		return { id : id, name : name, role : role, place : place };
	}

	public static function encodeClient( m : ClientMsg ) : Bytes {
		var w = new NetWriter();
		w.byte(Type.enumIndex(m));
		switch( m ) {
		case CHello(proto, version, content, eph):
			w.uint(proto); w.string(version); w.string(content); w.raw(eph);
		case CLogin(pk, sig, pseudo, password, tuto):
			w.raw(pk); w.raw(sig); w.string(pseudo); w.string(password); w.int(tuto);
		case CPing(t):
			w.double(t);
		case CTalk(chan, to, msg):
			w.uint(chan); w.int(to); w.string(msg);
		case CAdmin(op, target, arg):
			w.uint(op); w.int(target); w.string(arg);
		case CSetMode(creative):
			w.bool(creative);
		case CBye:
		case CNewGame(tuto):
			w.bool(tuto);
		case CLand(galaxy, pid):
			w.string(galaxy); w.uint(pid);
		case CTakeoff:
		case CState(s):
			writeState(w, s);
		case CBreak(seq, x, y, z, gi):
			w.uint(seq); w.uint(x); w.uint(y); w.uint(z); w.uint(gi);
		case CPlace(seq, x, y, z, gi, level, slot):
			w.uint(seq); w.uint(x); w.uint(y); w.uint(z); w.uint(gi); w.uint(level); w.uint(slot);
		case CSaveRecord(data):
			w.bytes(data);
		}
		return w.getBytes();
	}

	/** los campos se leen en variables, en orden: Haxe no asegura el orden en que se evaluan los argumentos de una llamada */
	public static function decodeClient( b : Bytes ) : ClientMsg {
		var r = new NetReader(b);
		var m = switch( r.byte() ) {
		case 0:
			var proto = r.uint(); var version = r.string(32); var content = r.string(64); var eph = r.raw(Nacl.DH);
			CHello(proto, version, content, eph);
		case 1:
			var pk = r.raw(Nacl.SIGN_PK); var sig = r.raw(Nacl.SIGNATURE); var pseudo = r.string(NAME_MAX);
			var password = r.string(PASSWORD_MAX); var tuto = r.intIn(-1, 1);
			CLogin(pk, sig, pseudo, password, tuto);
		case 2: CPing(r.double());
		case 3:
			var chan = r.uintIn(0, ChatChan.MAX); var to = r.int(); var msg = r.string(CHAT_MAX);
			CTalk(chan, to, msg);
		case 4:
			var op = r.uintIn(0, AdminOp.MAX); var target = r.int(); var arg = r.string(64);
			CAdmin(op, target, arg);
		case 5: CSetMode(r.bool());
		case 6: CBye;
		case 7: CNewGame(r.bool());
		case 8:
			var g = r.string(16); var pid = r.uintIn(0, 1 << 20);
			CLand(g, pid);
		case 9: CTakeoff;
		case 10: CState(readState(r));
		case 11:
			var seq = r.uint(); var x = r.uintIn(0, COORD_MAX); var y = r.uintIn(0, COORD_MAX); var z = r.uintIn(0, Z_MAX); var gi = r.uintIn(0, 0xFFFF);
			CBreak(seq, x, y, z, gi);
		case 12:
			var seq = r.uint(); var x = r.uintIn(0, COORD_MAX); var y = r.uintIn(0, COORD_MAX); var z = r.uintIn(0, Z_MAX); var gi = r.uintIn(1, 0xFFFF);
			var level = r.uintIn(0, 15); var slot = r.uintIn(0, 255);
			CPlace(seq, x, y, z, gi, level, slot);
		case 13: CSaveRecord(r.bytes(Channel.MAX_FRAME));
		case k: throw new NetReader.NetError("mensaje de cliente desconocido " + k);
		}
		r.done();
		return m;
	}

	public static function encodeServer( m : ServerMsg ) : Bytes {
		var w = new NetWriter();
		w.byte(Type.enumIndex(m));
		switch( m ) {
		case SServerHello(name, pk, eph, sig, password):
			w.string(name); w.raw(pk); w.raw(eph); w.raw(sig); w.bool(password);
		case SWelcome(id, name, role, creative, clock, firstTime):
			w.uint(id); w.string(name); w.uint(role); w.bool(creative); w.double(clock); w.bool(firstTime);
		case SRefuse(reason, detail):
			w.uint(reason); w.string(detail);
		case SRecord(data):
			w.bytes(data);
		case SPlanetData(key, seed, biome, size, genVersion, shipAt, edits, owner, rights):
			w.string(key); w.int(seed); w.string(biome); w.uint(size); w.uint(genVersion); w.string(shipAt); w.bytes(edits);
			w.string(owner); w.uint(rights);
		case SChanges(list):
			w.uint(list.length);
			for( c in list ) { w.uint(c.key); w.uint(c.v); }
		case SSetResult(seq, ok, current):
			w.uint(seq); w.bool(ok); w.uint(current);
		case SStates(list):
			w.uint(list.length);
			for( s in list ) writeState(w, s);
		case SGone(id):
			w.uint(id);
		case SReduceWater:
		case SPong(t, serverTime):
			w.double(t); w.double(serverTime);
		case SPlayers(list):
			w.uint(list.length);
			for( p in list ) writePlayer(w, p);
		case SUserJoin(p):
			writePlayer(w, p);
		case SUserLeave(id):
			w.uint(id);
		case STalk(from, name, chan, msg):
			w.int(from); w.string(name); w.uint(chan); w.string(msg);
		case SNotice(key, args):
			w.string(key);
			w.uint(args.length);
			for( a in args ) w.string(a);
		case SMode(creative):
			w.bool(creative);
		case SKicked(reason, detail):
			w.uint(reason); w.string(detail);
		}
		return w.getBytes();
	}

	public static function decodeServer( b : Bytes ) : ServerMsg {
		var r = new NetReader(b);
		var m = switch( r.byte() ) {
		case 0:
			var name = r.string(SERVER_NAME_MAX); var pk = r.raw(Nacl.SIGN_PK); var eph = r.raw(Nacl.DH);
			var sig = r.raw(Nacl.SIGNATURE); var password = r.bool();
			SServerHello(name, pk, eph, sig, password);
		case 1:
			var id = r.uint(); var name = r.string(NAME_MAX + 8); var role = r.uintIn(0, Role.MAX); var creative = r.bool();
			var clock = r.double(); var firstTime = r.bool();
			SWelcome(id, name, role, creative, clock, firstTime);
		case 2:
			var reason = r.uintIn(0, RefuseReason.MAX); var detail = r.string(200);
			SRefuse(reason, detail);
		case 3:
			var t = r.double(); var st = r.double();
			SPong(t, st);
		case 4:
			var n = r.count(PLAYERS_MAX, 4);
			SPlayers([for( _ in 0...n ) readPlayer(r)]);
		case 5: SUserJoin(readPlayer(r));
		case 6: SUserLeave(r.uint());
		case 7:
			var from = r.int(); var name = r.string(NAME_MAX + 8); var chan = r.uintIn(0, ChatChan.MAX); var msg = r.string(CHAT_MAX);
			STalk(from, name, chan, msg);
		case 8:
			var key = r.string(64); var n = r.count(8);
			SNotice(key, [for( _ in 0...n ) r.string(200)]);
		case 9: SMode(r.bool());
		case 10:
			var reason = r.uintIn(0, RefuseReason.MAX); var detail = r.string(200);
			SKicked(reason, detail);
		case 11: SRecord(r.bytes(Channel.MAX_FRAME));
		case 12:
			var key = r.string(48); var seed = r.int(); var biome = r.string(32); var size = r.uintIn(1, 8); var gv = r.uintIn(0, 1000);
			var shipAt = r.string(200); var edits = r.bytes(Channel.MAX_FRAME); var owner = r.string(NAME_MAX + 8); var rights = r.uintIn(0, 0xFFFF);
			SPlanetData(key, seed, biome, size, gv, shipAt, edits, owner, rights);
		case 13:
			var n = r.count(CHANGES_MAX, 2);
			SChanges([for( _ in 0...n ) { var k = r.uint(); var v = r.uint(); { key : k, v : v }; }]);
		case 14:
			var seq = r.uint(); var ok = r.bool(); var cur = r.uint();
			SSetResult(seq, ok, cur);
		case 15:
			var n = r.count(PLAYERS_MAX, 20);
			SStates([for( _ in 0...n ) readState(r)]);
		case 16: SGone(r.uint());
		case 17: SReduceWater;
		case k: throw new NetReader.NetError("mensaje de servidor desconocido " + k);
		}
		r.done();
		return m;
	}
}
