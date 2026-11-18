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
}

/**
 * Protocolo del multijugador (anadido del port): mensajes del cliente (ClientMsg) y del servidor (ServerMsg), escritos a mano
 * con NetWriter/NetReader. Cada campo tiene su limite al leer (cadenas, listas, rangos): un mensaje que no cuadra lanza NetError.
 * PROTOCOL sube con cualquier cambio de un mensaje.
 */
class Msg {

	public static inline var PROTOCOL = 1;
	public static inline var NAME_MAX = 24;
	public static inline var CHAT_MAX = 200;
	public static inline var PASSWORD_MAX = 64;
	public static inline var SERVER_NAME_MAX = 48;
	public static inline var PLAYERS_MAX = 4096;

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
		case k: throw new NetReader.NetError("mensaje de servidor desconocido " + k);
		}
		r.done();
		return m;
	}
}
