import haxe.io.Bytes;
import Msg;
import NetClient.NetEvent;
import Transport;

/**
 * Pruebas del multijugador sin ventana (anadido del port): mensajes (ida y vuelta de cada uno; mensajes rotos, cortos, al azar e
 * inflados que el lector rechaza sin reventar) y un servidor de verdad con varios clientes por TCP (127.0.0.1) y en memoria:
 * propietario, pseudos repetidos, chat (y su registro), ordenes de los gestionnaires, contrasena, version distinta, huella
 * cambiada, misma identidad dos veces, trama alterada, gestionnaires.txt editado a mano y descubrimiento en la red local.
 * Sale con 1 si algo falla. hl port/out/net_test.hl [carpeta de datos temporal]
 */
class NetTest {

	static var fails = 0;
	static var server : GameServer;
	static var clients = new Array<TestClient>();

	static function check( name : String, ok : Bool, ?info : String ) {
		if( ok ) Sys.println("ok   " + name) else {
			fails++;
			Sys.println("MAL  " + name + (info == null ? "" : " (" + info + ")"));
		}
	}

	/** bombea servidor y clientes hasta que cond se cumpla (o pase el tiempo) */
	static function until( cond : Void -> Bool, secs = 5. ) : Bool {
		var t0 = haxe.Timer.stamp();
		while( haxe.Timer.stamp() - t0 < secs ) {
			server.pump(0.01);
			for( c in clients ) c.pump();
			if( cond() ) return true;
			Sys.sleep(0.002);
		}
		return false;
	}

	static function secret( n : Int ) : Bytes {
		var b = Bytes.alloc(32);
		b.fill(0, 32, n);
		return b;
	}

	static function main() {
		messages();
		var dir = Sys.args().length > 0 ? Sys.args()[0] : "port/out/net_test";
		deleteDir(dir);
		sys.FileSystem.createDirectory(dir);
		server = new GameServer(dir);
		server.listen("127.0.0.1", 55099);

		var alice = add(new TestClient("Alice", secret(1)));
		alice.tcp(55099);
		check("alice entra", until(() -> alice.welcome != null), alice.lastEvent());
		check("el primero es propietario", alice.role == Owner);
		check("el propietario empieza en creativo", alice.creative == true);
		check("primera vez", alice.firstTime == true);

		var bob = add(new TestClient("Bob", secret(2)));
		bob.tcp(55099);
		check("bob entra", until(() -> bob.welcome != null), bob.lastEvent());
		check("bob es jugador en supervivencia", bob.role == Player && !bob.creative);
		check("alice ve llegar a bob", until(() -> alice.has(m -> switch( m ) { case SUserJoin(p): p.name == "Bob"; default: false; })));

		var carol = add(new TestClient("Alice", secret(3)));
		carol.local(server.connectLocal());
		check("carol entra en memoria", until(() -> carol.welcome != null), carol.lastEvent());
		check("pseudo repetido lleva #2", carol.name == "Alice#2", carol.name);

		alice.client.send(CTalk(CWorld, 0, "hola a todos"));
		check("chat del mundo llega a bob y carol", until(() -> bob.heard("hola a todos") && carol.heard("hola a todos")));
		alice.client.send(CTalk(CPrivate, bob.id, "solo para bob"));
		check("privado llega a bob", until(() -> bob.heard("solo para bob")));
		until(() -> false, 0.2);
		check("privado no llega a carol", !carol.heard("solo para bob"));
		var log = sys.io.File.getContent(dir + "/chat.log");
		check("chat.log guarda el privado", log.indexOf("solo para bob") >= 0 && log.indexOf("[prive Alice") >= 0);

		bob.client.send(CAdmin(AKick, carol.id, ""));
		check("un jugador no puede expulsar", until(() -> bob.notice("mp.admin.denied")));
		alice.client.send(CAdmin(APromote, bob.id, ""));
		check("alice nombra gestionnaire a bob", until(() -> sys.io.File.getContent(dir + "/gestionnaires.txt").indexOf("# Bob") >= 0));
		bob.client.send(CAdmin(AKick, alice.id, ""));
		check("nadie expulsa al propietario", until(() -> bob.notice("mp.admin.owner")));
		bob.client.send(CSetMode(true));
		check("un gestionnaire pasa a creativo", until(() -> bob.has(m -> m.match(SMode(true)))));

		alice.client.send(CAdmin(AKick, carol.id, ""));
		check("carol expulsada", until(() -> carol.kicked == RKicked));
		var carol2 = add(new TestClient("Alice", secret(3)));
		carol2.local(server.connectLocal());
		check("carol vuelve tras la expulsion", until(() -> carol2.welcome != null) && carol2.name == "Alice#2", carol2.name);
		alice.client.send(CAdmin(ABan, carol2.id, ""));
		check("carol prohibida", until(() -> carol2.kicked == RBanned));
		var carol3 = add(new TestClient("Otra", secret(3)));
		carol3.tcp(55099);
		check("carol no puede volver (bannis.txt)", until(() -> carol3.refused == RBanned), carol3.lastEvent());

		alice.client.send(CAdmin(APassword, 0, "secreto"));
		until(() -> alice.notice("mp.admin.done"));
		var dan = add(new TestClient("Dan", secret(4)));
		dan.tcp(55099);
		check("sin contrasena no entra", until(() -> dan.refused == RPassword), dan.lastEvent());
		var dan2 = add(new TestClient("Dan", secret(4), "secreto"));
		dan2.tcp(55099);
		check("con contrasena entra", until(() -> dan2.welcome != null), dan2.lastEvent());

		var fp = server.fingerprint;
		var eve = add(new TestClient("Eve", secret(5), "secreto", "0000000000000000"));
		eve.tcp(55099);
		check("huella cambiada: se corta", until(() -> eve.keyChanged == fp), eve.lastEvent());

		var dan3 = add(new TestClient("Dan", secret(4), "secreto"));
		dan3.tcp(55099);
		check("misma identidad dos veces: la vieja sale", until(() -> dan2.kicked == RReplaced && dan3.welcome != null));

		var raw = new sys.net.Socket();
		raw.connect(new sys.net.Host("127.0.0.1"), 55099);
		var w = new NetWriter();
		var hello = Msg.encodeClient(CHello(Msg.PROTOCOL, "0.0.1", GameVersion.contentHash(), Bytes.alloc(32)));
		w.uint(hello.length);
		w.raw(hello);
		raw.output.write(w.getBytes());
		var rt = new Transport.TcpTransport(raw);
		var rc = new Channel(rt);
		var gotVersion = false;
		until(() -> {
			var b = rc.receive();
			if( b != null ) switch( Msg.decodeServer(b) ) { case SRefuse(r, _): gotVersion = r == RVersion; default: }
			gotVersion;
		});
		check("version distinta: rechazada", gotVersion);

		var bobT = bob.transport;
		bobT.send(Bytes.ofString("\x10basura que no es una trama cifrada"));
		bobT.flush();
		check("trama alterada: el servidor corta a bob", until(() -> alice.has(m -> switch( m ) { case SUserLeave(id): id == bob.id; default: false; })));

		var g = sys.io.File.getContent(dir + "/gestionnaires.txt");
		var owner = server.files.ownerUid;
		var danUid = server.db.findIdentity("ed25519", Identity.fromSecret(secret(4)).keysFor(server.publicKey()).pk.toHex());
		sys.io.File.saveContent(dir + "/gestionnaires.txt", g + danUid + " # Dan, a mano\n");
		var t0 = haxe.Timer.stamp();
		check("gestionnaires.txt editado a mano: dan es gestionnaire", until(() -> { dan3.has(m -> switch( m ) { case SUserJoin(p): p.name == "Dan" && p.role == (Manager : Int); default: false; }) || alice.has(m -> switch( m ) { case SUserJoin(p): p.name == "Dan" && p.role == (Manager : Int); default: false; }); }));

		var u = new sys.net.UdpSocket();
		u.setBlocking(false);
		var a = new sys.net.Address();
		a.host = new sys.net.Host("127.0.0.1").ip;
		a.port = 55099;
		u.sendTo(Bytes.ofString("G55?"), 0, 4, a);
		var rb = Bytes.alloc(512), from = new sys.net.Address(), reply : String = null;
		until(() -> {
			try { var n = u.readFrom(rb, 0, 512, from); if( n > 4 ) reply = rb.getString(0, n); } catch( e : Dynamic ) {}
			reply != null;
		});
		check("descubrimiento en la red local", reply != null && StringTools.startsWith(reply, "G55!") && reply.indexOf("\"password\":true") >= 0, reply);

		server.stop();
		check("al parar el servidor los jugadores lo saben", until(() -> alice.kicked == RServerStop || alice.closed));
		Sys.println(fails == 0 ? "FIN OK" : "FALLOS: " + fails);
		Sys.exit(fails == 0 ? 0 : 1);
	}

	static function add( c : TestClient ) {
		clients.push(c);
		return c;
	}

	static function deleteDir( d : String ) {
		if( !sys.FileSystem.exists(d) ) return;
		for( f in sys.FileSystem.readDirectory(d) ) {
			var p = d + "/" + f;
			if( sys.FileSystem.isDirectory(p) ) deleteDir(p) else sys.FileSystem.deleteFile(p);
		}
		sys.FileSystem.deleteDirectory(d);
	}

	/** mensajes: ida y vuelta de cada constructor, y lo que el lector debe rechazar */
	static function messages() {
		var b32 = Bytes.alloc(32), b64 = Bytes.alloc(64);
		var cs : Array<ClientMsg> = [CHello(1, "0.8.1", "abcd", b32), CLogin(b32, b64, "Pseudo é", "pwd", -1), CPing(1.5),
			CTalk(CPrivate, 7, "hola ñ"), CAdmin(ABan, 3, "x"), CSetMode(true), CBye];
		var ss : Array<ServerMsg> = [SServerHello("srv", b32, b32, b64, true), SWelcome(3, "Bob#2", Manager, true, 123.5, false),
			SRefuse(RBanned, "x"), SPong(1.25, 2.5), SPlayers([{ id : 1, name : "a", role : 2, place : "" }]),
			SUserJoin({ id : 2, name : "b", role : 0, place : "Planète de X" }), SUserLeave(9), STalk(-1, "srv", CServer, "m"),
			SNotice("mp.x", ["a", "b"]), SMode(false), SKicked(RKicked, "Alice")];
		var names = [for( c in cs ) Type.enumConstructor(c)];
		for( n in Type.getEnumConstructs(ClientMsg) ) check("muestra de " + n, names.indexOf(n) >= 0);
		names = [for( s in ss ) Type.enumConstructor(s)];
		for( n in Type.getEnumConstructs(ServerMsg) ) check("muestra de " + n, names.indexOf(n) >= 0);
		for( c in cs ) {
			var b = Msg.encodeClient(c);
			check("ida y vuelta " + Type.enumConstructor(c), Std.string(Msg.decodeClient(b)) == Std.string(c));
			check("corto rechazado " + Type.enumConstructor(c), b.length <= 1 || rejects(() -> Msg.decodeClient(b.sub(0, b.length - 1))));
			var longer = Bytes.alloc(b.length + 1);
			longer.blit(0, b, 0, b.length);
			check("largo rechazado " + Type.enumConstructor(c), rejects(() -> Msg.decodeClient(longer)));
		}
		for( s in ss ) {
			var b = Msg.encodeServer(s);
			check("ida y vuelta " + Type.enumConstructor(s), Std.string(Msg.decodeServer(b)) == Std.string(s));
			check("corto rechazado " + Type.enumConstructor(s), b.length <= 1 || rejects(() -> Msg.decodeServer(b.sub(0, b.length - 1))));
		}
		var w = new NetWriter();
		w.byte(4);
		w.uint(1000000000);
		check("lista inflada rechazada sin reservar memoria", rejects(() -> Msg.decodeServer(w.getBytes())));
		var w2 = new NetWriter();
		w2.byte(3);
		w2.uint(0);
		w2.int(0);
		w2.uint(100000);
		check("cadena inflada rechazada", rejects(() -> Msg.decodeClient(w2.getBytes())));
		var bad = Bytes.ofHex("0300000568c3");
		check("UTF-8 roto rechazado", rejects(() -> Msg.decodeClient(bad)));
		var crashes = 0;
		for( i in 0...3000 ) {
			var n = Std.random(40);
			var r = Bytes.alloc(n);
			for( j in 0...n ) r.set(j, Std.random(256));
			try Msg.decodeClient(r) catch( e : NetReader.NetError ) {} catch( e : Dynamic ) crashes++;
			try Msg.decodeServer(r) catch( e : NetReader.NetError ) {} catch( e : Dynamic ) crashes++;
		}
		check("3000 mensajes al azar: solo NetError", crashes == 0, crashes + " otras excepciones");
	}

	static function rejects( f : Void -> Dynamic ) : Bool {
		try f() catch( e : NetReader.NetError ) return true catch( e : Dynamic ) return false;
		return false;
	}
}

/** cliente de prueba: guarda lo que le llega */
class TestClient {
	public var client : NetClient;
	public var transport : Transport;
	public var events = new Array<NetEvent>();
	public var msgs = new Array<ServerMsg>();
	public var welcome : NetEvent;
	public var id = -1;
	public var name : String;
	public var role : Role;
	public var creative : Null<Bool>;
	public var firstTime : Null<Bool>;
	public var kicked : Null<RefuseReason>;
	public var refused : Null<RefuseReason>;
	public var keyChanged : String;
	public var closed = false;

	public function new( pseudo : String, secret : Bytes, ?password : String, ?fp : String ) {
		client = new NetClient(Identity.fromSecret(secret), pseudo, password, 0, fp);
	}

	public function tcp( port : Int ) client.connectTcp("127.0.0.1", port);

	public function local( t : Transport ) client.connectLocal(t);

	public function pump() {
		client.pump();
		if( transport == null ) transport = @:privateAccess client.channel == null ? null : @:privateAccess client.channel.transport;
		while( client.events.length > 0 ) {
			var e = client.events.shift();
			events.push(e);
			switch( e ) {
			case EWelcome(i, n, r, c, f): welcome = e; id = i; name = n; role = r; creative = c; firstTime = f;
			case EKicked(r, _): kicked = r;
			case ERefused(r, _): refused = r;
			case EKeyChanged(_, got): keyChanged = got;
			case EClosed(_): closed = true;
			case EMessage(m): msgs.push(m);
			default:
			}
		}
	}

	public function has( f : ServerMsg -> Bool ) : Bool {
		for( m in msgs ) if( f(m) ) return true;
		return false;
	}

	public function heard( text : String ) return has(m -> switch( m ) { case STalk(_, _, _, t): t == text; default: false; });

	public function notice( key : String ) return has(m -> switch( m ) { case SNotice(k, _): k == key; default: false; });

	public function lastEvent() return events.length == 0 ? "sin eventos" : Std.string(events[events.length - 1]);
}
