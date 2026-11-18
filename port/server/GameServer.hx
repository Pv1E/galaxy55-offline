import haxe.io.Bytes;
import Msg;
import Handshake.TokenBucket;
import Transport;

private enum SessionState {
	SHello;
	SLogin;
	SPlay;
	SClosed;
}

/** Una conexion al servidor */
class Session {
	public var id : Int;
	public var channel : Channel;
	public var state : SessionState = SHello;
	public var transcript : Bytes;
	public var uid : String;
	public var display : String;
	public var role : Role = Player;
	public var creative = false;
	public var lastSeen = haxe.Timer.stamp();
	public var chatRate = new TokenBucket(2, 5);
	public var msgRate = new TokenBucket(60, 120);
	public var floodStrikes = 0;
	/** donde esta (clave de planeta, "" en el espacio) */
	public var where = "";
	/** su partida en este servidor (null hasta CNewGame si es nuevo) */
	public var record : SaveData.SaveInfo;
	/** el planeta donde esta (null en el espacio) */
	public var instance : PlanetInstance;
	/** su ultima posicion (CState) */
	public var pos : NetState;
	/** derechos en el planeta donde esta (Rights) */
	public var rights = 0;

	public function new( id : Int, t : Transport ) {
		this.id = id;
		channel = new Channel(t);
	}

	public function send( m : ServerMsg ) channel.send(Msg.encodeServer(m));

	public inline function isManager() return role == Manager || role == Owner;
}

/**
 * Servidor del multijugador (anadido del port). El mismo codigo para el servidor dentro del juego (Crear, y el solo de una
 * partida con servidor) y para el servidor dedicado (ServerMain): sin hilos, pump() en cada fotograma o en cada vuelta del bucle
 * del dedicado. Aqui: conexiones (TCP y en memoria), saludo cifrado, entrada de los jugadores (identidad, prohibidos, contrasena,
 * pseudo con #2 si ya lo usa otro), chat, ordenes de los gestionnaires y descubrimiento en la red local.
 */
class GameServer {

	public var files(default, null) : ServerFiles;
	public var db(default, null) : ServerDb;
	var keys : { pk : Bytes, sk : Bytes };
	public var fingerprint(default, null) : String;
	var listener : sys.net.Socket;
	var udp : sys.net.UdpSocket;
	var sessions = new Array<Session>();
	var nextId = 1;
	var udpBuf = Bytes.alloc(64);
	var udpFrom = new sys.net.Address();
	/** puerto TCP abierto (0 = solo conexiones en memoria) */
	public var port(default, null) = 0;
	public var stopped(default, null) = false;
	public var worlds(default, null) : ServerWorlds;
	/** tiempo para generar planetas en cada pump (ms): poco dentro del juego (no se nota en los fotogramas), mas en un dedicado */
	public var genBudgetMs = 4.;
	/** tiempo maximo sin noticias de un cliente antes de cerrarlo (s) */
	static inline var TIMEOUT = 30.;

	public function new( dir : String ) {
		SecureRandom.init(dir);
		files = new ServerFiles(dir);
		db = new ServerDb(dir + "/monde.sqlite");
		files.names = db.displayOf;
		keys = files.serverKeys();
		fingerprint = Handshake.fingerprint(keys.pk);
		worlds = new ServerWorlds(this, db);
		files.log("servidor \"" + files.options.name + "\" listo (huella " + fingerprint + ", azar: " + SecureRandom.source + ")");
	}

	public function publicKey() return keys.pk;

	/** abre el puerto TCP (y el de descubrimiento UDP si lanVisible); host "0.0.0.0" = todas las interfaces */
	public function listen( host = "0.0.0.0", ?port : Int ) {
		if( port == null ) port = files.options.port;
		listener = new sys.net.Socket();
		listener.bind(new sys.net.Host(host), port);
		listener.listen(16);
		listener.setBlocking(false);
		this.port = port;
		files.log("escuchando en " + host + ":" + port);
		if( files.options.lanVisible ) {
			try {
				udp = new sys.net.UdpSocket();
				udp.bind(new sys.net.Host(host), port);
				udp.setBlocking(false);
			} catch( e : Dynamic ) {
				files.log("descubrimiento en la red local no disponible: " + e);
				udp = null;
			}
		}
	}

	/** conexion en memoria (el jugador del anfitrion): devuelve el extremo del cliente */
	public function connectLocal() : Transport {
		var p = LocalTransport.pair();
		addSession(p[1]);
		return p[0];
	}

	function addSession( t : Transport ) : Session {
		var s = new Session(nextId++, t);
		sessions.push(s);
		return s;
	}

	public function sessionById( id : Int ) : Session {
		for( o in sessions ) if( o.id == id && o.state == SPlay ) return o;
		return null;
	}

	/** las sesiones dentro del juego */
	public function playing() : Array<Session> return [for( o in sessions ) if( o.state == SPlay ) o];

	public function playersOnline() : Int {
		var n = 0;
		for( s in sessions ) if( s.state == SPlay ) n++;
		return n;
	}

	// ---------------------------------------------------------------- bucle

	public function pump( dt : Float ) {
		if( stopped ) return;
		if( listener != null ) {
			while( true ) {
				var c : sys.net.Socket = null;
				try c = listener.accept() catch( e : Dynamic ) c = null;
				if( c == null ) break;
				var s = addSession(new TcpTransport(c));
				files.log("conexion " + s.id + " desde " + s.channel.transport.peerName());
			}
		}
		pumpUdp();
		var now = haxe.Timer.stamp();
		for( s in sessions.copy() ) {
			var n = 0;
			while( s.state != SClosed && n++ < 200 ) {
				var b = s.channel.receive();
				if( b == null ) break;
				s.lastSeen = now;
				var m : ClientMsg;
				try m = Msg.decodeClient(b) catch( e : NetReader.NetError ) {
					drop(s, RProtocol, e.msg);
					break;
				} catch( e : Dynamic ) {
					drop(s, RProtocol, Std.string(e));
					break;
				}
				if( !s.msgRate.take() ) {
					if( ++s.floodStrikes > 50 ) drop(s, RFlood, "demasiados mensajes");
					continue;
				}
				handle(s, m);
			}
			if( s.state != SClosed && now - s.lastSeen > TIMEOUT ) drop(s, RProtocol, "sin noticias");
			if( s.state != SClosed && s.channel.transport.closed ) leave(s, s.channel.transport.closeReason);
			s.channel.flush();
		}
		worlds.pump(dt, genBudgetMs);
		if( files.poll(dt) ) applyFiles();
	}

	/** el anfitrion o el servidor dedicado se paran: avisa y cierra todo */
	public function stop() {
		if( stopped ) return;
		for( s in sessions.copy() ) if( s.state != SClosed ) drop(s, RServerStop, "");
		for( s in sessions ) s.channel.flush();
		if( listener != null ) try listener.close() catch( e : Dynamic ) {}
		if( udp != null ) try udp.close() catch( e : Dynamic ) {}
		worlds.close();
		db.close();
		stopped = true;
		files.log("servidor parado");
	}

	// ---------------------------------------------------------------- mensajes

	function handle( s : Session, m : ClientMsg ) {
		switch( [s.state, m] ) {
		case [SHello, CHello(proto, version, content, eph)]:
			if( proto != Msg.PROTOCOL || version != GameVersion.VERSION || content != GameVersion.contentHash() ) {
				s.send(SRefuse(RVersion, GameVersion.VERSION));
				files.log("conexion " + s.id + " rechazada: version " + version + " (protocolo " + proto + ", contenido " + content + ")");
				close(s);
				return;
			}
			var e = Handshake.ephemeral();
			s.transcript = Handshake.transcript(eph, e.pk, keys.pk);
			var sig = Nacl.sign(s.transcript, keys.sk);
			s.send(SServerHello(files.options.name, keys.pk, e.pk, sig, files.hasPassword()));
			var k = Handshake.keys(e.sk, eph, s.transcript);
			s.channel.setKeys(k.s2c, k.c2s);
			s.state = SLogin;
		case [SLogin, CLogin(pk, sig, pseudo, password, tuto)]:
			login(s, pk, sig, pseudo, password, tuto);
		case [SPlay, CPing(t)]:
			s.send(SPong(t, Sys.time()));
		case [SPlay, CTalk(chan, to, msg)]:
			talk(s, chan, to, msg);
		case [SPlay, CAdmin(op, target, arg)]:
			admin(s, op, target, arg);
		case [SPlay, CSetMode(creative)]:
			if( !s.isManager() ) return;
			s.creative = creative;
			saveMode(s);
			s.send(SMode(creative));
			files.log(s.display + " pasa a " + (creative ? "creativo" : "supervivencia"));
		case [_, CBye]:
			leave(s, "se va");
		default:
			if( s.state == SPlay && worlds.handle(s, m) ) return;
			drop(s, RProtocol, "mensaje fuera de lugar: " + Type.enumConstructor(m));
		}
	}

	function login( s : Session, pk : Bytes, sig : Bytes, pseudo : String, password : String, tuto : Int ) {
		if( !Nacl.verify(Handshake.loginMessage(s.transcript), sig, pk) ) {
			refuse(s, RBadLogin, "firma de identidad invalida");
			return;
		}
		var key = pk.toHex();
		var uid = db.findIdentity("ed25519", key);
		if( uid != null && files.banned.exists(uid) ) {
			refuse(s, RBanned, "");
			return;
		}
		if( !files.checkPassword(password) ) {
			refuse(s, RPassword, "");
			return;
		}
		var name = cleanPseudo(pseudo);
		db.begin();
		var first = uid == null;
		if( first ) {
			uid = db.createPlayer(name, uniqueDisplay(name, null));
			db.addIdentity("ed25519", key, uid);
		} else {
			var row = db.getPlayer(uid);
			var display = row.pseudo == name ? row.display : uniqueDisplay(name, uid);
			db.setNames(uid, name, display);
		}
		db.commit();
		// una sola conexion por identidad: la nueva sustituye a la vieja
		for( o in sessions ) if( o != s && o.state == SPlay && o.uid == uid ) drop(o, RReplaced, "");
		s.uid = uid;
		s.display = db.displayOf(uid);
		var owner = false;
		if( files.ownerUid == null ) {
			files.setOwner(uid);
			owner = true;
			files.log(s.display + " (" + uid + ") es el propietario del servidor (primer jugador)");
		}
		s.role = uid == files.ownerUid ? Owner : (files.managers.exists(uid) ? Manager : Player);
		s.creative = loadMode(s, owner);
		s.state = SPlay;
		// "primera vez" = sin partida en este servidor: el cliente pregunta lo del tutorial y manda CNewGame
		var row = db.getPlayer(uid);
		var needGame = row == null || row.record == "";
		s.send(SWelcome(s.id, s.display, s.role, s.creative, Sys.time(), needGame));
		s.send(SPlayers([for( o in sessions ) if( o.state == SPlay ) netPlayer(o, s)]));
		for( o in sessions ) if( o != s && o.state == SPlay ) o.send(SUserJoin(netPlayer(s, o)));
		files.log("entra " + s.display + " (" + uid + ", conexion " + s.id + ", " + s.channel.transport.peerName() + ")" + (first ? " por primera vez" : ""));
		files.chat("--- entra " + s.display + " (" + uid + ")");
		if( !needGame ) worlds.onLogin(s);
	}

	function netPlayer( p : Session, viewer : Session ) : NetPlayer {
		return { id : p.id, name : p.display, role : p.role, place : placeFor(p, viewer) };
	}

	/** lo que ve viewer de donde esta p: "" = en el espacio (el cliente pone "Espace"); el mundo compartido lo completa */
	function placeFor( p : Session, viewer : Session ) : String {
		return p.where;
	}

	function cleanPseudo( p : String ) : String {
		var out = new StringBuf();
		p = StringTools.trim(p == null ? "" : p);
		for( i in 0...p.length ) {
			var c = p.charCodeAt(i);
			if( c >= 32 && c != 127 && c != "#".code ) out.addChar(c);
		}
		var s = out.toString();
		if( s.length > Msg.NAME_MAX ) s = s.substr(0, Msg.NAME_MAX);
		return s == "" ? "User" + StringTools.lpad(Std.string(SecureRandom.int(1000000)), "0", 6) : s;
	}

	/** el pseudo si nadie mas lo lleva; si no, pseudo#2, pseudo#3... */
	function uniqueDisplay( name : String, uid : String ) : String {
		if( !db.displayTaken(name, uid) ) return name;
		var n = 2;
		while( db.displayTaken(name + "#" + n, uid) ) n++;
		return name + "#" + n;
	}

	function loadMode( s : Session, owner : Bool ) : Bool {
		var v = db.meta("mode:" + s.uid);
		if( v == null ) {
			// el anfitrion (o el primero de un dedicado) empieza en creativo; los demas en supervivencia
			if( owner ) db.setMeta("mode:" + s.uid, "1");
			return owner;
		}
		return v == "1" && s.isManager();
	}

	function saveMode( s : Session ) {
		db.begin();
		db.setMeta("mode:" + s.uid, s.creative ? "1" : "0");
		db.commit();
	}

	function clean( msg : String ) : String {
		var out = new StringBuf();
		for( i in 0...msg.length ) {
			var c = msg.charCodeAt(i);
			if( c >= 32 && c != 127 ) out.addChar(c);
		}
		return StringTools.trim(out.toString());
	}

	function talk( s : Session, chan : Int, to : Int, msg : String ) {
		msg = clean(msg);
		if( msg == "" ) return;
		if( !s.chatRate.take() ) {
			s.send(SNotice("mp.chat.slow", []));
			return;
		}
		switch( (chan : ChatChan) ) {
		case CWorld:
			files.chat("[monde] " + s.display + " (" + s.uid + "): " + msg);
			for( o in sessions ) if( o.state == SPlay ) o.send(STalk(s.id, s.display, chan, msg));
		case CPlanet:
			files.chat("[planete " + (s.where == "" ? "espace" : s.where) + "] " + s.display + " (" + s.uid + "): " + msg);
			for( o in sessions ) if( o.state == SPlay && o.where == s.where ) o.send(STalk(s.id, s.display, chan, msg));
		case CPrivate:
			var t = byId(to);
			if( t == null ) {
				s.send(SNotice("mp.chat.nobody", []));
				return;
			}
			files.chat("[prive " + s.display + " (" + s.uid + ") -> " + t.display + " (" + t.uid + ")] " + msg);
			t.send(STalk(s.id, s.display, chan, msg));
			if( t != s ) s.send(STalk(s.id, s.display, chan, msg));
		default:
		}
	}

	function byId( id : Int ) : Session {
		for( o in sessions ) if( o.id == id && o.state == SPlay ) return o;
		return null;
	}

	function admin( s : Session, op : Int, target : Int, arg : String ) {
		if( !s.isManager() ) {
			s.send(SNotice("mp.admin.denied", []));
			return;
		}
		var t = byId(target);
		switch( (op : AdminOp) ) {
		case APromote, ADemote, AKick, ABan:
			if( t == null ) return;
			if( t.role == Owner ) {
				s.send(SNotice("mp.admin.owner", []));
				return;
			}
			switch( (op : AdminOp) ) {
			case APromote:
				files.setManager(t.uid, true);
				files.log(s.display + " nombra gestionnaire a " + t.display);
			case ADemote:
				files.setManager(t.uid, false);
				files.log(s.display + " destituye a " + t.display);
			case AKick:
				files.log(s.display + " expulsa a " + t.display);
				drop(t, RKicked, s.display);
			case ABan:
				files.setBanned(t.uid, true);
				files.log(s.display + " prohibe a " + t.display);
				drop(t, RBanned, s.display);
			default:
			}
			applyFiles();
		case APassword:
			files.setPassword(arg);
			files.log(s.display + (arg == "" ? " quita la contrasena" : " cambia la contrasena"));
		case AServerName:
			files.options.name = ServerFiles.cleanName(arg);
			files.saveOptions();
			files.log(s.display + " llama al servidor \"" + files.options.name + "\"");
		case ALanVisible:
			files.options.lanVisible = arg == "1";
			files.saveOptions();
		case ADeathDrop:
			files.options.deathDrop = arg == "1";
			files.saveOptions();
		}
		s.send(SNotice("mp.admin.done", []));
	}

	/** gestionnaires.txt o bannis.txt han cambiado: papeles al dia y fuera los prohibidos */
	function applyFiles() {
		for( o in sessions ) {
			if( o.state != SPlay ) continue;
			if( files.banned.exists(o.uid) && o.uid != files.ownerUid ) {
				drop(o, RBanned, "");
				continue;
			}
			var r : Role = o.uid == files.ownerUid ? Owner : (files.managers.exists(o.uid) ? Manager : Player);
			if( r != o.role ) {
				o.role = r;
				if( !o.isManager() && o.creative ) {
					o.creative = false;
					saveMode(o);
					o.send(SMode(false));
				}
				for( v in sessions ) if( v.state == SPlay ) v.send(SUserJoin(netPlayer(o, v)));
			}
		}
	}

	// ---------------------------------------------------------------- salidas

	function refuse( s : Session, r : RefuseReason, detail : String ) {
		s.send(SRefuse(r, detail));
		files.log("conexion " + s.id + " rechazada (" + r + ") " + detail);
		close(s);
	}

	/** echa a un jugador (o corta una conexion a medias) avisandole */
	function drop( s : Session, r : RefuseReason, detail : String ) {
		if( s.state == SClosed ) return;
		if( s.state == SPlay ) s.send(SKicked(r, detail));
		else s.send(SRefuse(r, detail));
		leave(s, "cerrada (" + r + ") " + detail);
	}

	function leave( s : Session, why : String ) {
		if( s.state == SClosed ) return;
		var wasPlaying = s.state == SPlay;
		if( wasPlaying ) worlds.onLeave(s);
		close(s);
		if( wasPlaying ) {
			files.log("sale " + s.display + " (" + why + ")");
			files.chat("--- sale " + s.display + " (" + s.uid + ")");
			for( o in sessions ) if( o.state == SPlay ) o.send(SUserLeave(s.id));
		}
	}

	function close( s : Session ) {
		s.state = SClosed;
		s.channel.close("cerrada por el servidor");
		sessions.remove(s);
	}

	// ---------------------------------------------------------------- red local

	/** responde a las sondas "G55?" de los clientes que buscan partidas en la red local */
	function pumpUdp() {
		if( udp == null ) return;
		for( _ in 0...16 ) {
			var n = -1;
			try n = udp.readFrom(udpBuf, 0, udpBuf.length, udpFrom) catch( e : Dynamic ) n = -1;
			if( n < 0 ) return;
			if( n != 4 || udpBuf.getString(0, 4) != "G55?" ) continue;
			var info = haxe.Json.stringify({ name : files.options.name, version : GameVersion.VERSION, content : GameVersion.contentHash(),
				players : playersOnline(), port : port, password : files.hasPassword() });
			var b = Bytes.ofString("G55!" + info);
			try udp.sendTo(b, 0, b.length, udpFrom) catch( e : Dynamic ) {}
		}
	}
}
