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
		// siempre el mismo terreno (si no, cada partida nueva tiene su semilla al azar y lo que se rompe cambia)
		ServerWorlds.fixedSeed = 4242;
		world(Sys.args().length > 0 ? Sys.args()[0] + "_monde" : "port/out/net_test_monde");
		itemsTest(Sys.args().length > 0 ? Sys.args()[0] + "_objets" : "port/out/net_test_objets");
		econTest(Sys.args().length > 0 ? Sys.args()[0] + "_eco" : "port/out/net_test_eco");
		shipTest(Sys.args().length > 0 ? Sys.args()[0] + "_nave" : "port/out/net_test_nave");
		hangarTest(Sys.args().length > 0 ? Sys.args()[0] + "_hangar" : "port/out/net_test_hangar");
		cometTest(Sys.args().length > 0 ? Sys.args()[0] + "_comete" : "port/out/net_test_comete");
		tutoTest(Sys.args().length > 0 ? Sys.args()[0] + "_tuto" : "port/out/net_test_tuto");
		// endurance: 30 s por defecto; --soak=S para mas (port/headless: net_test.hl DIR --soak=600)
		var soak = 30.;
		for( a in Sys.args() ) if( StringTools.startsWith(a, "--soak=") ) soak = Std.parseFloat(a.substr(7));
		soakTest(Sys.args().length > 0 ? Sys.args()[0] + "_endurance" : "port/out/net_test_endurance", soak, 6);
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

	/**
	 * Mundo compartido: partida nueva, aterrizar en su planeta (mismo terreno que el que genera el cliente), romper y poner con
	 * sus comprobaciones (bloque esperado, distancia), cambios que manda el servidor (y el proceso del mundo: liquidos), guardado
	 * en la base de datos y partida al volver a entrar.
	 */
	static function world( dir : String ) {
		deleteDir(dir);
		sys.FileSystem.createDirectory(dir);
		PortRules.apply();
		server = new GameServer(dir);
		server.genBudgetMs = 50;
		server.listen("127.0.0.1", 55098);
		clients = [];
		var w = add(new TestClient("Wanda", secret(9)));
		w.tcp(55098);
		check("mundo: entra, partida por empezar", until(() -> w.welcome != null) && w.firstTime == true, w.lastEvent());
		w.client.send(CNewGame(false));
		var rec : Dynamic = null;
		until(() -> {
			for( m in w.msgs ) switch( m ) { case SRecord(d): rec = haxe.Json.parse(NetZip.unpackString(d, 1 << 24)); default: }
			rec != null;
		});
		check("mundo: partida nueva en el espacio", rec != null && rec.uni.space == true && rec.credits == Market.START_CREDITS);
		var pid = TutoSetup.PLANET;
		w.client.send(CLand("", pid));
		var pd = null;
		until(() -> {
			for( m in w.msgs ) switch( m ) { case SPlanetData(k, seed, biome, size, gv, _, edits, owner, _): pd = { k : k, seed : seed, biome : biome, size : size, gv : gv, owner : owner }; default: }
			pd != null;
		});
		var exp = ExpData.ExpOffline.planet(ExpData.ExpOffline.make(rec.uni.seed, rec.uni.start), pid).p;
		check("mundo: datos del planeta", pd != null && pd.seed == exp.seed && pd.biome == exp.biome && pd.size == exp.size && pd.owner == "Wanda", Std.string(pd));
		var inst : PlanetInstance = null;
		check("mundo: el servidor genera el planeta", until(() -> {
			for( i in @:privateAccess server.worlds.instances ) inst = i;
			inst != null && inst.ready();
		}, 30));
		var local = new WorldData(pd.seed, pd.biome, pd.size, null, null, pd.gv);
		while( !local.genStep(haxe.Timer.stamp(), 1000) ) {}
		check("mundo: mismo terreno en el cliente y el servidor", local.cellHash() == inst.world.cellHash());
		var sp = local.spawnPoint();
		var bx = Std.int(sp.x), by = Std.int(sp.y), bz = Std.int(sp.z) - 1;
		var b = local.block(bx, by, bz);
		var key = ((bx + by * local.size) << WorldData.ZBITS) | bz;
		var st = { id : 0, x : sp.x, y : sp.y, z : sp.z, yaw : 0., pitch : 0., flags : 0, charge : -1, hx : 0., hy : 0., hz : 0. };
		w.client.send(CState(st));
		w.client.send(CBreak(1, (bx + 40) % local.size, by, bz, b.index));
		check("mundo: romper lejos: no", until(() -> w.has(m -> m.match(SSetResult(1, false, _)))));
		w.client.send(CBreak(2, bx, by, bz, b.index));
		check("mundo: romper el bloque de debajo", until(() -> w.has(m -> m.match(SSetResult(2, true, _)))));
		check("mundo: el cambio llega", until(() -> w.has(m -> switch( m ) { case SChanges(l): Lambda.exists(l, c -> c.key == key && c.v == 0); default: false; })));
		w.client.send(CBreak(3, bx, by, bz, b.index));
		check("mundo: romper dos veces: no", until(() -> w.has(m -> m.match(SSetResult(3, false, 0)))));
		var rock = Block.get(BRock);
		w.client.send(CPlace(4, bx, by, bz, rock.index, 0, 1));
		check("mundo: poner roca", until(() -> w.has(m -> m.match(SSetResult(4, true, _))) && inst.world.block(bx, by, bz) == rock));
		var src = Block.get(BCascadeSource);
		w.client.send(CPlace(5, bx, by, bz + 2, src.index, 0, 1));
		check("mundo: la cascada corre en el servidor", until(() -> w.has(m -> switch( m ) { case SChanges(l): Lambda.exists(l, c -> c.key != key && (c.v & 0xFFFF) != 0 && (c.v & 0xFFFF) != src.index && (c.v & 0xFFFF) != rock.index); default: false; }), 8));
		server.worlds.commit();
		var saved = server.db.loadEdits(inst.key);
		var found = false;
		var i = 0;
		while( i + 1 < saved.length ) { if( saved[i] == key && saved[i + 1] == rock.index ) found = true; i += 2; }
		check("mundo: guardado en la base de datos", found);
		access(w, inst, pid, sp, bx, by, bz);
		w.client.send(CTakeoff);
		until(() -> false, 0.3);
		w.client.close();
		until(() -> false, 0.3);
		var w2 = add(new TestClient("Wanda", secret(9)));
		w2.tcp(55098);
		var rec2 : Dynamic = null;
		until(() -> {
			for( m in w2.msgs ) switch( m ) { case SRecord(d): rec2 = haxe.Json.parse(NetZip.unpackString(d, 1 << 24)); default: }
			rec2 != null;
		});
		check("mundo: al volver, su partida", w2.firstTime == false && rec2 != null && rec2.uni.seed == rec.uni.seed && rec2.uni.space == true);
		server.stop();
		clients = [];
	}

	/**
	 * Accesos: otro jugador no entra en un planeta cerrado; abierto e invitado, lo ve en su mapa (SForeign), entra, los dos se ven
	 * (SStates) y lo que rompe el invitado le llega al propietario; visitante, no rompe; cerrado, sale; cesion (el que cede se
	 * queda de explorador) y abandono (todos fuera).
	 */
	static function access( w : TestClient, inst : PlanetInstance, pid : Int, sp : { x : Float, y : Float, z : Float }, bx : Int, by : Int, bz : Int ) {
		var x = add(new TestClient("Xavier", secret(10)));
		x.tcp(55098);
		check("acceso: llega otro jugador", until(() -> x.welcome != null), x.lastEvent());
		x.client.send(CNewGame(false));
		until(() -> x.has(m -> m.match(SRecord(_))));
		var wuid = server.db.findIdentity("ed25519", Identity.fromSecret(secret(9)).keysFor(server.publicKey()).pk.toHex());
		var wpub = server.db.pubOf(wuid);
		x.client.send(CLand(wpub, pid));
		check("acceso: planeta cerrado, no entra", until(() -> x.has(m -> m.match(SPlanetLost("mp.land.denied")))));
		w.client.send(CAccess(pid, true, false, false, 0));
		w.client.send(CInvite(pid, x.id, 0));
		check("acceso: invitado (aviso)", until(() -> x.notice("mp.invited")));
		check("acceso: el planeta sale en su mapa", until(() -> x.has(m -> switch( m ) {
			case SForeign(l): Lambda.exists(l, f -> f.pub == wpub && f.owner == "Wanda" && Lambda.exists(f.planets, p -> p.pid == pid && p.status == Type.enumIndex(ExpData.ExpPlanetStatus.PInvited)));
			default: false;
		})));
		x.msgs = [];
		x.client.send(CLand(wpub, pid));
		var rights = -1;
		until(() -> { for( m in x.msgs ) switch( m ) { case SPlanetData(_, _, _, _, _, _, _, owner, r): rights = r; default: } rights >= 0; });
		check("acceso: entra como explorador", rights == Rights.EXPLORER, "" + rights);
		var st = { id : 0, x : sp.x, y : sp.y, z : sp.z, yaw : 0., pitch : 0., flags : 1, charge : -1, hx : 1., hy : 2., hz : 3. };
		w.client.send(CState(st));
		x.client.send(CState({ id : 0, x : sp.x + 1, y : sp.y, z : sp.z, yaw : 1., pitch : 0., flags : 0, charge : -1, hx : 0., hy : 0., hz : 0. }));
		check("acceso: los dos se ven", until(() -> w.has(m -> switch( m ) { case SStates(l): Lambda.exists(l, s -> s.id == x.id); default: false; })
			&& x.has(m -> switch( m ) { case SStates(l): Lambda.exists(l, s -> s.id == w.id && s.flags & 1 != 0); default: false; })));
		var tx = bx + 1, ty = by, tz = inst.world.topCollide(bx + 1, by) - 1;
		var tb = inst.world.block(tx, ty, tz);
		var tkey = ((tx + ty * inst.world.size) << WorldData.ZBITS) | tz;
		w.msgs = [];
		// juste encima de lo que rompe: el relieve cambia en cada partida nueva (semilla al azar)
		x.client.send(CState({ id : 0, x : tx + 0.5, y : ty + 0.5, z : tz + 1, yaw : 1., pitch : 0., flags : 0, charge : -1, hx : 0., hy : 0., hz : 0. }));
		until(() -> false, 0.2);
		x.client.send(CBreak(50, tx, ty, tz, tb.index));
		check("acceso: lo que rompe el invitado llega al propietario", until(() -> x.has(m -> m.match(SSetResult(50, true, _)))
			&& w.has(m -> switch( m ) { case SChanges(l): Lambda.exists(l, c -> c.key == tkey && c.v & 0xFFFF != tb.index); default: false; })));
		var xpub = server.db.pubOf(server.db.findIdentity("ed25519", Identity.fromSecret(secret(10)).keysFor(server.publicKey()).pk.toHex()));
		w.client.send(CGuest(pid, xpub, 1));
		check("acceso: pasa a visitante", until(() -> x.has(m -> switch( m ) { case SRights(r): r & (RVisitor : Int) != 0 && r & (RBuild : Int) == 0; default: false; })));
		var under = inst.world.block(tx, ty, tz - 1);
		if( under != null ) {
			x.client.send(CBreak(51, tx, ty, tz - 1, under.index));
			check("acceso: un visitante no rompe", until(() -> x.has(m -> m.match(SSetResult(51, false, _)))));
		}
		w.client.send(CAccess(pid, false, false, false, 0));
		check("acceso: cerrado, el invitado sale", until(() -> x.has(m -> m.match(SPlanetLost("mp.planet.closed")))));
		w.client.send(CAccess(pid, true, false, false, 0));
		w.client.send(CGuest(pid, xpub, 0));
		w.client.send(CTransfer(pid, x.id));
		check("acceso: cesion", until(() -> x.notice("mp.transfer.got")) && server.db.getPlanet(wuid + ":" + pid).owner != wuid);
		x.msgs = [];
		x.client.send(CLand(wpub, pid));
		until(() -> x.has(m -> m.match(SPlanetData(_, _, _, _, _, _, _, _, _))));
		w.client.send(CLand("", pid));
		until(() -> w.has(m -> m.match(SPlanetData(_, _, _, _, _, _, _, "Xavier", _))));
		check("acceso: el que cede sigue entrando (explorador)", w.has(m -> switch( m ) { case SPlanetData(_, _, _, _, _, _, _, "Xavier", r): r == Rights.EXPLORER; default: false; }));
		x.client.send(CAbandon(pid));
		check("acceso: abandono, todos fuera", until(() -> w.has(m -> m.match(SPlanetLost("mp.planet.abandoned")))) && server.db.getPlanet(wuid + ":" + pid) == null);
		x.client.close();
	}

	/** inventario que el servidor ha mandado por ultima vez a c (SInventory) */
	static function lastInv( c : TestClient ) : NetInv {
		var r : NetInv = null;
		for( m in c.msgs ) switch( m ) { case SInventory(_, i): r = i; default: }
		return r;
	}

	static function count( i : NetInv, gi : Int ) : Int {
		var n = 0;
		if( i != null ) for( s in i.t ) if( s != null && s.k == gi ) n += s.n;
		return n;
	}

	static function loots( c : TestClient ) : Map<Int, NetLoot> {
		var m = new Map<Int, NetLoot>();
		for( x in c.msgs ) switch( x ) {
			case SAddLoot(l): m.set(l.id, l);
			case SDeleteLoot(id): m.remove(id);
			default:
		}
		return m;
	}

	/**
	 * Objetos (el servidor es el unico que los crea): romper suelta, recoger es de uno solo (dos a la vez: uno gana), no se pone lo
	 * que no se tiene, tirar, ordenar el inventario sin inventar nada, morir deja un contenedor que otro puede recoger, cantinas
	 * (una persona a la vez, nada se crea al mover), bomba, y todo sigue igual tras parar y volver a arrancar el servidor.
	 */
	static function itemsTest( dir : String ) {
		deleteDir(dir);
		sys.FileSystem.createDirectory(dir);
		server = new GameServer(dir);
		server.genBudgetMs = 50;
		server.listen("127.0.0.1", 55097);
		clients = [];
		var p = add(new TestClient("Pia", secret(20)));
		p.tcp(55097);
		until(() -> p.welcome != null);
		// el primero es el propietario y empieza en creativo (sin sueltos): a supervivencia
		p.client.send(CSetMode(false));
		p.client.send(CNewGame(false));
		until(() -> p.has(m -> m.match(SRecord(_))));
		check("objetos: inventario del servidor al entrar", until(() -> lastInv(p) != null));
		var pid = TutoSetup.PLANET;
		p.client.send(CLand("", pid));
		until(() -> p.has(m -> m.match(SPlanetData(_, _, _, _, _, _, _, _, _))));
		var inst : PlanetInstance = null;
		until(() -> { for( i in @:privateAccess server.worlds.instances ) inst = i; inst != null && inst.ready(); }, 30);
		var w = inst.world;
		var sp = w.spawnPoint();
		var st = { id : 0, x : sp.x, y : sp.y, z : sp.z, yaw : 0., pitch : 0., flags : 0, charge : -1, hx : 0., hy : 0., hz : 0. };
		p.client.send(CState(st));
		var bx = Std.int(sp.x), by = Std.int(sp.y), bz = Std.int(sp.z) - 1;
		var b = w.block(bx, by, bz);
		var drop = b.getDrop().b;
		p.client.send(CBreak(1, bx, by, bz, b.index));

		check("objetos: romper suelta un objeto del servidor", until(() -> Lambda.count(loots(p)) > 0));
		var id = -1, lg = -1;
		for( l in loots(p) ) { id = l.id; lg = l.gi; }
		check("objetos: es lo que suelta el bloque", lg == drop.index);
		p.client.send(CPick(2, id));
		check("objetos: recogido, al inventario", until(() -> count(lastInv(p), drop.index) == 1 && !loots(p).exists(id)));
		p.client.send(CPick(3, id));
		until(() -> p.has(m -> m.match(SInventory(3, _))));
		check("objetos: recoger dos veces no da dos", count(lastInv(p), drop.index) == 1);
		var q = add(new TestClient("Quim", secret(21)));
		q.tcp(55097);
		until(() -> q.welcome != null);
		q.client.send(CNewGame(false));
		until(() -> q.has(m -> m.match(SRecord(_))));
		p.client.send(CAccess(pid, true, false, false, 0));
		p.client.send(CInvite(pid, q.id, 0));
		until(() -> q.has(m -> m.match(SForeign(_))) && q.notice("mp.invited"));
		var ppub = server.db.pubOf(@:privateAccess server.sessionById(p.id).uid);
		q.client.send(CLand(ppub, pid));
		until(() -> q.has(m -> m.match(SPlanetData(_, _, _, _, _, _, _, _, _))));
		q.client.send(CState({ id : 0, x : sp.x + 0.5, y : sp.y, z : sp.z, yaw : 0., pitch : 0., flags : 0, charge : -1, hx : 0., hy : 0., hz : 0. }));
		var ux = bx + 1, uz = w.topCollide(bx + 1, by) - 1;
		var under = w.block(ux, by, uz);
		for( c in [p, q] ) c.client.send(CState({ id : 0, x : ux + 0.5, y : by + 0.5, z : uz + 1, yaw : 0., pitch : 0., flags : 0, charge : -1, hx : 0., hy : 0., hz : 0. }));
		until(() -> false, 0.2);
		p.client.send(CBreak(4, ux, by, uz, under.index));
		var id2 = -1;
		until(() -> { for( l in loots(q) ) if( l.id != id ) id2 = l.id; id2 >= 0; });
		var dropUnder = under.getDrop() == null ? null : under.getDrop().b;
		p.client.send(CPick(5, id2));
		q.client.send(CPick(1, id2));
		until(() -> p.has(m -> m.match(SInventory(5, _))) && q.has(m -> m.match(SInventory(1, _))));
		var gp = dropUnder == null ? 0 : count(lastInv(p), dropUnder.index) - (dropUnder.index == drop.index ? 1 : 0);
		var gq = dropUnder == null ? 0 : count(lastInv(q), dropUnder.index);
		check("objetos: dos a la vez, solo uno lo coge", dropUnder == null || gp + gq == 1, gp + "+" + gq);
		var rock = Block.get(BRock);
		p.client.send(CState(st));
		until(() -> false, 0.2);
		p.client.send(CPlace(6, bx, by, bz, rock.index, 0, 1));
		check("objetos: no se pone lo que no se tiene", until(() -> p.has(m -> m.match(SSetResult(6, false, _)))) && inst.world.block(bx, by, bz) != rock);
		var slot = -1;
		var pi = lastInv(p);
		for( i in 0...pi.t.length ) if( pi.t[i] != null && pi.t[i].k == drop.index ) slot = i + 1;
		p.client.send(CPlace(7, bx, by, bz, drop.index, 0, slot));
		check("objetos: poner gasta el bloque", until(() -> p.has(m -> m.match(SSetResult(7, true, _)))) && until(() -> count(lastInv(p), drop.index) == 0 || p.has(m -> m.match(SInventory(_, _)))));
		var ps = @:privateAccess server.sessionById(p.id);
		ps.record.inv.t[0] = { k : rock.index, n : 10 };
		ps.record.inv.t[1] = { k : Block.get(BChest).index, n : 1 };
		ps.record.inv.t[2] = { k : Block.get(BArtiBomb).index, n : 1 };
		server.worlds.items.sendInv(ps);
		until(() -> count(lastInv(p), rock.index) == 10);
		p.client.send(CThrow(8, 1, 4));
		check("objetos: tirar 4 rocas", until(() -> count(lastInv(p), rock.index) == 6 && Lambda.exists([for( l in loots(p) ) l], l -> l.gi == rock.index && l.n == 4)));
		var fake = lastInv(p);
		fake.t[3] = { k : rock.index, n : 50 };
		p.client.send(CInvLayout(9, fake));
		until(() -> p.has(m -> m.match(SInventory(9, _))));
		check("objetos: ordenar inventando rocas: no", count(lastInv(p), rock.index) == 6);
		var swap = lastInv(p);
		var tmp = swap.t[0];
		swap.t[0] = swap.t[4];
		swap.t[4] = tmp;
		p.client.send(CInvLayout(10, swap));
		until(() -> p.has(m -> m.match(SInventory(10, _))));
		check("objetos: ordenar sin inventar: si", lastInv(p).t[4] != null && lastInv(p).t[4].k == rock.index && lastInv(p).t[0] == null);
		var cx = bx + 2, cy = by, cz = w.topCollide(bx + 2, by);
		p.client.send(CPlace(11, cx, cy, cz, Block.get(BChest).index, 0, 2));
		until(() -> p.has(m -> m.match(SSetResult(11, true, _))));
		p.client.send(CChestOpen(cx, cy, cz));
		var opened = false;
		until(() -> { for( m in p.msgs ) switch( m ) { case SChest(_, _, _, 0, t, ""): opened = t.length > 0; default: } opened; });
		check("objetos: abrir la cantina", opened);
		q.client.send(CChestOpen(cx, cy, cz));
		check("objetos: la cantina abierta por otro esta ocupada", until(() -> q.has(m -> m.match(SChest(_, _, _, -1, _, "Pia")))));
		var inv0 = lastInv(p);
		var cheat = inv0.t.copy();
		p.client.send(CChestMove(cx, cy, cz, 0, [{ k : rock.index, n : 30 }, null, null, null], { t : cheat, charges : inv0.charges }));
		until(() -> p.has(m -> m.match(SChest(_, _, _, 0, _, ""))) && p.msgs.filter(m -> m.match(SChest(_, _, _, _, _, _))).length >= 2);
		check("objetos: meter en la cantina lo que no se tiene: no", Lambda.count(server.worlds.items != null ? inst.items.chests.get(cx + "," + cy + "," + cz).filter(s -> s != null) : []) == 0);
		var moved = inv0.t.copy();
		var rs = moved[4];
		moved[4] = null;
		p.client.send(CChestMove(cx, cy, cz, 0, [rs, null, null, null], { t : moved, charges : inv0.charges }));
		check("objetos: meter rocas en la cantina", until(() -> p.has(m -> m.match(SChest(_, _, _, 1, _, "")))) && count(lastInv(p), rock.index) == 0);
		p.client.send(CChestClose);
		p.client.send(CBreak(12, cx, cy, cz, Block.get(BChest).index));
		check("objetos: romper la cantina suelta lo que tenia", until(() -> Lambda.exists([for( l in loots(p) ) l], l -> l.gi == rock.index && l.n == 6)));
		var qinv0 = count(lastInv(q), rock.index);
		ps.record.inv.t[0] = { k : rock.index, n : 5 };
		server.worlds.items.sendInv(ps);
		until(() -> count(lastInv(p), rock.index) == 5);
		p.client.send(CDeath(false));
		check("objetos: al morir, el inventario va a un contenedor", until(() -> count(lastInv(p), rock.index) == 0 && Lambda.exists([for( l in loots(q) ) l], l -> l.container)));
		var cont = Lambda.find([for( l in loots(q) ) l], l -> l.container);
		// el contenedor cae hasta el suelo: Quim va a donde se ha parado
		var sd : ServerItems.ServerDrop = null;
		until(() -> { sd = inst.items.drops.get(cont.id); sd != null && sd.rested; });
		q.client.send(CState({ id : 0, x : sd.x, y : sd.y, z : sd.z - 0.5, yaw : 0., pitch : 0., flags : 0, charge : -1, hx : 0., hy : 0., hz : 0. }));
		until(() -> false, 0.3);
		q.client.send(CPick(2, cont.id));
		check("objetos: otro jugador recoge el contenedor", until(() -> count(lastInv(q), rock.index) >= qinv0 + 5));
		var bombGi = Block.get(BArtiBomb).index;
		ps.record.inv.t[2] = { k : bombGi, n : 1 };
		server.worlds.items.sendInv(ps);
		until(() -> count(lastInv(p), bombGi) == 1);
		var ox = bx + 4, oy = by, oz = w.topCollide(bx + 4, by);
		p.client.send(CPlace(13, ox, oy, oz, bombGi, 0, 3));
		until(() -> p.has(m -> m.match(SSetResult(13, true, _))));
		p.client.send(CState({ id : 0, x : ox + 2.5, y : oy + 0.5, z : oz, yaw : 0., pitch : 0., flags : 0, charge : -1, hx : 0., hy : 0., hz : 0. }));
		until(() -> false, 0.2);
		p.client.send(CActivate(ox, oy, oz));
		check("objetos: la bomba explota (efecto y dano)", until(() -> p.has(m -> m.match(SBomb(_, _, _))) && p.has(m -> m.match(SHit(_)))) && inst.world.block(ox, oy, oz) == null);
		server.worlds.commit();
		var keep = count(lastInv(q), rock.index);
		server.stop();
		clients = [];
		server = new GameServer(dir);
		server.genBudgetMs = 50;
		server.listen("127.0.0.1", 55097);
		var q2 = add(new TestClient("Quim", secret(21)));
		q2.tcp(55097);
		check("objetos: tras volver a arrancar, el inventario sigue", until(() -> lastInv(q2) != null) && count(lastInv(q2), rock.index) == keep);
		server.stop();
		clients = [];
	}

	static function patched( c : TestClient, key : String ) : Dynamic {
		var r : Dynamic = null;
		for( m in c.msgs ) switch( m ) { case SPatch(k, j) if( k == key ): r = haxe.Json.parse(j); default: }
		return r;
	}

	/**
	 * Progresion en el servidor: comprar y vender con el robot (creditos e inventario de verdad, sin pasar de lo que se puede
	 * pagar ni vender lo que no se tiene), un contrato sin bloques no paga, y la partida que manda el cliente no cambia creditos,
	 * inventario ni licencias (CSaveRecord trucada).
	 */
	static function econTest( dir : String ) {
		deleteDir(dir);
		sys.FileSystem.createDirectory(dir);
		server = new GameServer(dir);
		server.listen("127.0.0.1", 55096);
		clients = [];
		var e = add(new TestClient("Eva", secret(30)));
		e.tcp(55096);
		until(() -> e.welcome != null);
		e.client.send(CSetMode(false));
		e.client.send(CNewGame(false));
		until(() -> e.has(m -> m.match(SRecord(_))) && lastInv(e) != null);
		var es = @:privateAccess server.sessionById(e.id);
		var w : Market.Ware = null;
		for( x in Market.wares ) if( w == null && x.onSale && x.charge == null && x.base > 0 ) w = x;
		var start = es.record.credits == null ? Market.START_CREDITS : es.record.credits;
		e.client.send(CEcon(1, EBuy, w.key, 3));
		until(() -> e.has(m -> m.match(SInventory(1, _))));
		var c1 : Int = patched(e, "credits");
		check("progresion: comprar da los bloques y cobra", count(lastInv(e), w.block.index) == 3 && c1 < start && es.record.credits == c1, start + " -> " + c1);
		e.client.send(CEcon(2, ESell, w.key, 50));
		until(() -> e.has(m -> m.match(SInventory(2, _))));
		var c2 : Int = patched(e, "credits");
		check("progresion: vender solo lo que se tiene", count(lastInv(e), w.block.index) == 0 && c2 > c1 && c2 < start, c1 + " -> " + c2);
		e.client.send(CEcon(3, EBuy, w.key, 1 << 19));
		until(() -> e.has(m -> m.match(SInventory(3, _))));
		var c3 : Int = patched(e, "credits");
		check("progresion: no se compra mas de lo que se puede pagar", c3 >= 0 && c3 < c2 && es.record.credits == c3, "" + c3);
		Contracts.state(es.record);
		var before = haxe.Json.stringify(es.record.contracts);
		e.client.send(CEcon(4, EDeliver, "", 0));
		until(() -> e.has(m -> m.match(SInventory(4, _))));
		check("progresion: un contrato sin sus bloques no paga", es.record.credits == c3 && haxe.Json.stringify(es.record.contracts) == before);
		// el cliente manda su partida con creditos, inventario y licencias inventados: no se toma nada de eso
		var fake : SaveData.SaveInfo = haxe.Json.parse(haxe.Json.stringify(es.record));
		fake.credits = 999999;
		fake.inv.t[0] = { k : Block.get(BChest).index, n : 9 };
		fake.uni.licenses = [1, 2, 3, 4, 5, 6, 7];
		fake.px = 12.5;
		var lic = es.record.uni.licenses.length;
		e.client.send(CSaveRecord(NetZip.packString(haxe.Json.stringify(SaveData.diskEncode(fake)))));
		e.client.send(CEcon(5, EDeliver, "", 0));
		until(() -> e.has(m -> m.match(SInventory(5, _))));
		check("progresion: la partida del cliente no da creditos, objetos ni licencias", es.record.credits == c3
			&& count(lastInv(e), Block.get(BChest).index) == 0 && es.record.uni.licenses.length == lic && es.record.px == 12.5);
		server.stop();
	}

	/**
	 * La nave en el servidor (ServerShip): solo se pone y se quita en las zonas del sintetizador, lo que se quita vuelve como
	 * suelto de a bordo, fabrica el servidor (con los bloques de la zona o del inventario), el stockage no crea nada y lo que se
	 * tira a bordo queda en la nave.
	 */
	static function shipTest( dir : String ) {
		deleteDir(dir);
		sys.FileSystem.createDirectory(dir);
		server = new GameServer(dir);
		server.listen("127.0.0.1", 55095);
		clients = [];
		var f = add(new TestClient("Fia", secret(40)));
		f.tcp(55095);
		until(() -> f.welcome != null);
		f.client.send(CSetMode(false));
		f.client.send(CNewGame(false));
		until(() -> f.has(m -> m.match(SRecord(_))) && lastInv(f) != null);
		var fs = @:privateAccess server.sessionById(f.id);
		var ship = server.worlds.shipOf(fs);
		var c = ship.crafts[0];
		var wood = Block.get(BWood);
		server.worlds.items.devGive(fs, wood, 2);
		until(() -> count(lastInv(f), wood.index) == 2);
		var slot = -1;
		var fi = lastInv(f);
		for( i in 0...fi.t.length ) if( fi.t[i] != null && fi.t[i].k == wood.index ) slot = i + 1;
		var x = c.x, y = c.y, z = c.z;
		var here = ship.world.block(x, y, z);
		f.client.send(CShipSet(1, x, y, z, here == null ? 0 : here.index, wood.index, slot));
		check("nave: poner en la zona del sintetizador gasta el bloque", until(() -> f.has(m -> m.match(SSetResult(1, true, _))))
			&& until(() -> count(lastInv(f), wood.index) == 1) && ship.world.block(x, y, z) == wood && fs.record.shipEdits.length > 0);
		f.client.send(CShipSet(2, c.x - 3 < 0 ? c.x + c.w + 3 : c.x - 3, c.y, c.z, 0, wood.index, slot));
		check("nave: fuera de las zonas no se pone nada", until(() -> f.has(m -> m.match(SSetResult(2, false, _)))) && until(() -> count(lastInv(f), wood.index) == 1));
		f.client.send(CShipSet(3, x, y, z, wood.index, 0, 0));
		var lid = -1;
		check("nave: quitar suelta el bloque a bordo", until(() -> { for( l in loots(f) ) if( l.id >= ServerShip.LOOT_BASE && l.gi == wood.index ) lid = l.id; lid >= 0; }) && ship.world.block(x, y, z) == null);
		f.client.send(CPick(4, lid));
		check("nave: recogerlo lo devuelve al inventario", until(() -> count(lastInv(f), wood.index) == 2 && !loots(f).exists(lid)));
		// receta con el bloque de la zona (el inventario no tiene bastante: se gasta el de la zona)
		f.client.send(CShipSet(5, x, y, z, 0, wood.index, slot));
		until(() -> f.has(m -> m.match(SSetResult(5, true, _))));
		var r = c.engine.checkAll();
		var before = Lambda.count(loots(f));
		if( r != null ) {
			// sin madera en el inventario, la receta gasta la de la zona
			var ws = -1;
			var li = lastInv(f);
			for( i in 0...li.t.length ) if( li.t[i] != null && li.t[i].k == wood.index ) ws = i + 1;
			fs.record.inv.t[ws - 1] = null;
			f.client.send(CShipCraft(c.out.x, c.out.y, c.out.z));
			check("nave: el servidor fabrica con la zona (la vacia y suelta el resultado)", until(() -> f.has(m -> m.match(SShipCells(_))) && Lambda.count(loots(f)) > before)
				&& ship.world.block(x, y, z) == null);
		} else check("nave: hay receta para un bloque de madera", false);
		// stockage: mover del inventario al stockage vale; inventar algo no
		server.worlds.items.devGive(fs, Block.get(BRock), 5);
		until(() -> count(lastInv(f), Block.get(BRock).index) == 5);
		var inv = lastInv(f);
		var st = StorageData.ensure(fs.record);
		var nst : NetInv = { t : [for( s in st.t ) s], charges : [] };
		var ninv : NetInv = { t : [for( s in inv.t ) s == null ? null : { k : s.k, n : s.n }], charges : inv.charges };
		for( i in 0...ninv.t.length ) if( ninv.t[i] != null && ninv.t[i].k == Block.get(BRock).index ) { nst.t[0] = { k : ninv.t[i].k, n : ninv.t[i].n }; ninv.t[i] = null; }
		f.client.send(CStorage(6, nst, ninv));
		check("nave: el stockage guarda lo que sale del inventario", until(() -> f.has(m -> m.match(SInventory(6, _)))) && count(lastInv(f), Block.get(BRock).index) == 0
			&& fs.record.storage.t[0] != null && fs.record.storage.t[0].n == 5);
		var cheat : NetInv = { t : [for( s in st.t ) s == null ? null : { k : s.k, n : s.n }], charges : [] };
		cheat.t[1] = { k : Block.get(BChest).index, n : 1 };
		f.client.send(CStorage(7, cheat, ninv));
		check("nave: el stockage no crea nada", until(() -> f.has(m -> m.match(SInventory(7, _)))) && fs.record.storage.t[1] == null);
		// tirar a bordo: queda en la nave
		server.worlds.items.devGive(fs, wood, 3);
		until(() -> count(lastInv(f), wood.index) == 3);
		f.client.send(CState({ id : 0, x : c.x + 0.5, y : c.y + 0.5, z : c.z + WorldData.SHIP_Z, yaw : 0., pitch : 0., flags : 0, charge : -1, hx : 0., hy : 0., hz : 0. }));
		var ts = -1;
		var ti = lastInv(f);
		for( i in 0...ti.t.length ) if( ti.t[i] != null && ti.t[i].k == wood.index ) ts = i + 1;
		var n0 = Lambda.count(ship.loot);
		f.client.send(CThrow(8, ts, 3));
		check("nave: lo tirado a bordo es un suelto de la nave", until(() -> f.has(m -> m.match(SInventory(8, _)))) && count(lastInv(f), wood.index) == 0 && Lambda.count(ship.loot) == n0 + 1);
		server.stop();
	}

	/** la nave del hangar como la guarda el juego (Hangar.shipBytes) a partir de las celdas del cobertizo (shedData) */
	static function hangarBytes( cells : Map<Int, Int> ) : haxe.io.Bytes {
		var SX = Hangar.SX, SY = Hangar.SY, SZ = Hangar.SZ, OX = @:privateAccess Hangar.OX;
		var data = haxe.io.Bytes.alloc(SX * SY * SZ * 2 + 3);
		data.set(0, SX);
		data.set(1, SY);
		data.set(2, SZ);
		var pos = 3;
		for( y in 0...SY )
			for( x in 0...SX )
				for( z in 0...SZ ) {
					var k = (((2 + x + OX) & Common.Const.MASK) << 16) | ((2 + y) << 8) | (1 + z);
					var id = cells.exists(k) ? ShipData.shipId(Block.all[cells.get(k)]) : 0;
					data.set(pos, id & 0xFF);
					data.set(pos + 1, id >> 8);
					pos += 2;
				}
		return haxe.zip.Compress.run(data, 9);
	}

	/**
	 * Hangar (ServerShip.saveShip): la nave que manda el cliente al salir solo vale si es valida y si el inventario no tiene mas
	 * de lo que daba la nave de antes menos la nueva; poner un bloque que no se tiene, inventar algo o una nave rota no pasan.
	 */
	static function hangarTest( dir : String ) {
		deleteDir(dir);
		sys.FileSystem.createDirectory(dir);
		server = new GameServer(dir);
		server.listen("127.0.0.1", 55094);
		clients = [];
		var g = add(new TestClient("Gus", secret(50)));
		g.tcp(55094);
		until(() -> g.welcome != null);
		g.client.send(CSetMode(false));
		g.client.send(CNewGame(false));
		until(() -> g.has(m -> m.match(SRecord(_))) && lastInv(g) != null);
		var gs = @:privateAccess server.sessionById(g.id);
		var cells = new Map<Int, Int>();
		for( c in Hangar.shedData(ShipData.current(gs.record)).cells ) cells.set((c.x << 16) | (c.y << 8) | c.z, c.id);
		var same = hangarBytes(cells);
		var inv0 = lastInv(g);
		g.client.send(CSaveShip(1, same, inv0));
		check("hangar: la misma nave y el mismo inventario valen", until(() -> g.has(m -> m.match(SInventory(1, _)))) && gs.record.shipData != null && !g.has(m -> m.match(SPatch("ship", _))));
		// un bloque de casco de mas en una celda libre de la zona que deje la nave valida
		var hull = Block.get(BShipHull);
		var added = -1;
		for( z in 1...Hangar.SZ + 1 ) for( y in 2...Hangar.SY + 2 ) for( x in 2...Hangar.SX + 2 ) {
			if( added >= 0 ) break;
			var k = (((x + @:privateAccess Hangar.OX) & Common.Const.MASK) << 16) | (y << 8) | z;
			if( cells.exists(k) ) continue;
			cells.set(k, hull.index);
			if( Hangar.serverCheck(hangarBytes(cells), NetZip.inflate) == null ) added = k else cells.remove(k);
		}
		check("hangar: hay sitio para un bloque de casco", added >= 0);
		var bigger = hangarBytes(cells);
		g.client.send(CSaveShip(2, bigger, inv0));
		check("hangar: poner un bloque que no se tiene no pasa", until(() -> g.has(m -> m.match(SPatch("ship", _)))) && gs.record.shipData == haxe.crypto.Base64.encode(same));
		server.worlds.items.devGive(gs, hull, 1);
		until(() -> count(lastInv(g), hull.index) == 1);
		var withHull = lastInv(g);
		var spent : NetInv = { t : [for( s in withHull.t ) s == null || s.k == hull.index ? null : { k : s.k, n : s.n }], charges : withHull.charges };
		g.client.send(CSaveShip(3, bigger, spent));
		check("hangar: con el bloque en el inventario, se gasta y la nave vale", until(() -> g.has(m -> m.match(SInventory(3, _))))
			&& gs.record.shipData == haxe.crypto.Base64.encode(bigger) && count(lastInv(g), hull.index) == 0 && gs.ship == null);
		var cheat : NetInv = { t : [for( s in spent.t ) s], charges : spent.charges };
		for( i in 0...cheat.t.length ) if( cheat.t[i] == null ) { cheat.t[i] = { k : Block.get(BChest).index, n : 3 }; break; }
		g.client.send(CSaveShip(4, bigger, cheat));
		check("hangar: el inventario no puede inventar nada", until(() -> g.has(m -> m.match(SInventory(4, _)))) && count(lastInv(g), Block.get(BChest).index) == 0);
		cells.remove(added);
		var back : NetInv = { t : [for( s in spent.t ) s], charges : spent.charges };
		var drop = hull.getDrop();
		for( i in 0...back.t.length ) if( back.t[i] == null ) { back.t[i] = { k : drop.b.index, n : drop.count }; break; }
		g.client.send(CSaveShip(5, hangarBytes(cells), back));
		check("hangar: quitar un bloque lo devuelve", until(() -> g.has(m -> m.match(SInventory(5, _)))) && count(lastInv(g), drop.b.index) == drop.count
			&& gs.record.shipData == haxe.crypto.Base64.encode(hangarBytes(cells)));
		g.client.send(CSaveShip(6, haxe.zip.Compress.run(haxe.io.Bytes.alloc(Hangar.SX * Hangar.SY * Hangar.SZ * 2 + 3), 9), back));
		check("hangar: una nave que no vale no pasa", until(() -> g.has(m -> m.match(SInventory(6, _)))) && gs.record.shipData == haxe.crypto.Base64.encode(hangarBytes(cells)));
		server.stop();
	}

	/**
	 * Cometas en el servidor: solo se aterriza en la que el servidor dice que hay (con su hora), es de ese jugador y de nadie mas,
	 * acabado su tiempo no se rompe nada y al despegar se borra y ya no se vuelve.
	 */
	static function cometTest( dir : String ) {
		deleteDir(dir);
		sys.FileSystem.createDirectory(dir);
		server = new GameServer(dir);
		server.listen("127.0.0.1", 55093);
		clients = [];
		var h = add(new TestClient("Hal", secret(60)));
		h.tcp(55093);
		until(() -> h.welcome != null);
		h.client.send(CSetMode(false));
		h.client.send(CNewGame(false));
		until(() -> h.has(m -> m.match(SRecord(_))) && lastInv(h) != null);
		var hs = @:privateAccess server.sessionById(h.id);
		var uni = hs.record.uni;
		var d = ExpData.ExpOffline.make(uni.seed, uni.start, null, null, null, uni.gone);
		var sys = d.systems[0].id;
		Comets.devForce = -1;
		var none = true;
		for( q in d.systems ) if( Comets.of(uni, q) != null ) none = false;
		if( none ) {
			h.client.send(CLand("", Comets.idOf(sys)));
			check("cometa: sin cometa ahora no se aterriza", until(() -> h.has(m -> m.match(SPlanetLost(_)))));
		}
		Comets.devForce = sys;
		h.client.send(CLand("", Comets.idOf(sys)));
		check("cometa: con la cometa del servidor se aterriza", until(() -> h.has(m -> m.match(SPlanetData(_, _, _, _, _, _, _, _, _)))) && hs.record.comet != null
			&& CometRules.isComet(hs.instance.row.biome));
		var inst = hs.instance;
		until(() -> inst.ready(), 30);
		var w = inst.world;
		var sp = w.spawnPoint();
		h.client.send(CState({ id : 0, x : sp.x, y : sp.y, z : sp.z, yaw : 0., pitch : 0., flags : 0, charge : -1, hx : 0., hy : 0., hz : 0. }));
		until(() -> false, 0.2);
		var bx = Std.int(sp.x), by = Std.int(sp.y), bz = Std.int(sp.z) - 1;
		h.client.send(CBreak(1, bx, by, bz, w.block(bx, by, bz).index));
		check("cometa: se rompe con tiempo", until(() -> h.has(m -> m.match(SSetResult(1, true, _)))));
		hs.record.comet.left = 0;
		var bz2 = w.topCollide(bx + 1, by) - 1;
		h.client.send(CBreak(2, bx + 1, by, bz2, w.block(bx + 1, by, bz2).index));
		check("cometa: acabado el tiempo no se rompe nada", until(() -> h.has(m -> m.match(SSetResult(2, false, _)))));
		var key = inst.key;
		h.client.send(CTakeoff);
		check("cometa: al despegar se borra y queda visitada", until(() -> hs.instance == null && !@:privateAccess server.worlds.instances.exists(key))
			&& hs.record.comet == null && hs.record.uni.comets != null && hs.record.uni.comets.indexOf(sys) >= 0);
		var lost = Lambda.count(h.msgs, m -> m.match(SPlanetLost(_)));
		h.client.send(CLand("", Comets.idOf(sys)));
		check("cometa: no se vuelve a una cometa visitada", until(() -> Lambda.count(h.msgs, m -> m.match(SPlanetLost(_))) > lost));
		Comets.devForce = -1;
		server.stop();
	}

	/**
	 * Tutorial en el servidor: pone lo del tutorial en su planeta (y dice donde), el envio de la ESCorp se da una sola vez al
	 * acabarlo, la partida del cliente no borra los sitios ni vuelve a empezar el tutorial, y pasarlo deja la partida como sin el.
	 */
	static function tutoTest( dir : String ) {
		deleteDir(dir);
		sys.FileSystem.createDirectory(dir);
		server = new GameServer(dir);
		server.genBudgetMs = 50;
		server.listen("127.0.0.1", 55092);
		clients = [];
		var t = add(new TestClient("Ida", secret(70)));
		t.tcp(55092);
		until(() -> t.welcome != null);
		t.client.send(CSetMode(false));
		t.client.send(CNewGame(true));
		until(() -> t.has(m -> m.match(SRecord(_))) && lastInv(t) != null);
		var ts = @:privateAccess server.sessionById(t.id);
		check("tutorial: partida nueva con tutorial", ts.record.tuto != null);
		t.client.send(CLand("", TutoSetup.PLANET));
		check("tutorial: el servidor pone sus bloques y dice donde", until(() -> t.has(m -> m.match(SPatch("tuto", _))), 30) && ts.record.tuto.spots != null
			&& ts.instance.world.block(ts.record.tuto.spots[0], ts.record.tuto.spots[1], ts.record.tuto.spots[2]) == Block.get(BYellowCrystalLight));
		var fake : SaveData.SaveInfo = haxe.Json.parse(haxe.Json.stringify(ts.record));
		fake.tuto.spots = null;
		fake.tuto.step = 3;
		t.client.send(CSaveRecord(NetZip.packString(haxe.Json.stringify(SaveData.diskEncode(fake)))));
		t.client.send(CEcon(1, EDeliver, "", 0));
		until(() -> t.has(m -> m.match(SInventory(1, _))));
		check("tutorial: la partida del cliente lleva el paso pero no borra los sitios", ts.record.tuto.step == 3 && ts.record.tuto.spots != null);
		var c0 = ts.record.credits == null ? 0 : ts.record.credits;
		t.client.send(CEcon(2, EEndTutorial, "", 0));
		until(() -> t.has(m -> m.match(SInventory(2, _))));
		var c1 = ts.record.credits;
		check("tutorial: al acabarlo, el envio de la ESCorp", ts.record.tuto == null && c1 == c0 + Market.START_CREDITS && ts.record.uni.main != null);
		t.client.send(CEcon(3, EEndTutorial, "", 0));
		until(() -> t.has(m -> m.match(SInventory(3, _))));
		fake.tuto = { step : 0 };
		t.client.send(CSaveRecord(NetZip.packString(haxe.Json.stringify(SaveData.diskEncode(fake)))));
		t.client.send(CEcon(4, EEndTutorial, "", 0));
		until(() -> t.has(m -> m.match(SInventory(4, _))));
		check("tutorial: el envio una sola vez, y no se vuelve a empezar", ts.record.credits == c1 && ts.record.tuto == null);
		var u = add(new TestClient("Ugo", secret(71)));
		u.tcp(55092);
		until(() -> u.welcome != null);
		u.client.send(CNewGame(true));
		until(() -> u.has(m -> m.match(SRecord(_))));
		var us = @:privateAccess server.sessionById(u.id);
		var records = Lambda.count(u.msgs, m -> m.match(SRecord(_)));
		u.client.send(CEcon(1, ESkipTutorial, "", 0));
		check("tutorial: pasarlo deja la partida como sin el (y se manda de nuevo)", until(() -> Lambda.count(u.msgs, m -> m.match(SRecord(_))) > records)
			&& us.record.tuto == null && us.record.credits == Market.START_CREDITS && us.record.uni.space == true);
		server.stop();
	}

	static function lastChest( c : TestClient ) : { ver : Int, t : Array<Null<{ k : Int, n : Int }>> } {
		var r = null;
		for( m in c.msgs ) switch( m ) { case SChest(_, _, _, ver, t, busy) if( busy == "" ): r = { ver : ver, t : t }; default: }
		return r;
	}

	/**
	 * Endurance (M8): robots en el planeta de uno, con 120 rocas y una cantina para todos, tiran, recogen (a la vez lo mismo),
	 * ordenan, mueven entre inventario y cantina, se desconectan y vuelven, al azar y sin esperar respuestas. Al final, el grand
	 * livre: rocas de los inventarios + la cantina + los sueltos y contenedores = 120, y ninguna pila vacia ni por encima de su
	 * maximo. Asi se ve que ni las carreras ni los mensajes viejos o repetidos crean o pierden nada.
	 */
	static function soakTest( dir : String, secs : Float, nbots : Int ) {
		deleteDir(dir);
		sys.FileSystem.createDirectory(dir);
		server = new GameServer(dir);
		server.genBudgetMs = 50;
		server.listen("127.0.0.1", 55091);
		clients = [];
		var rock = Block.get(BRock);
		var bots = [for( i in 0...nbots ) add(new TestClient("Bot" + i, secret(80 + i)))];
		for( b in bots ) b.tcp(55091);
		until(() -> Lambda.foreach(bots, b -> b.welcome != null), 10);
		bots[0].client.send(CSetMode(false));
		for( b in bots ) b.client.send(CNewGame(false));
		until(() -> Lambda.foreach(bots, b -> b.has(m -> m.match(SRecord(_)))), 20);
		var pid = TutoSetup.PLANET;
		var owner = @:privateAccess server.sessionById(bots[0].id);
		var pub = server.db.pubOf(owner.uid);
		bots[0].client.send(CLand("", pid));
		var inst : PlanetInstance = null;
		until(() -> { inst = owner.instance; inst != null && inst.ready(); }, 40);
		// el planeta existe en el servidor desde el aterrizaje: ahora se abre
		bots[0].client.send(CAccess(pid, true, false, false, 0));
		for( i in 1...nbots ) bots[0].client.send(CInvite(pid, bots[i].id, 0));
		until(() -> false, 0.3);
		for( i in 1...nbots ) bots[i].client.send(CLand(pub, pid));
		until(() -> Lambda.foreach(bots, b -> @:privateAccess server.sessionById(b.id).instance == inst), 20);
		var w = inst.world;
		var sp = w.spawnPoint();
		var st = { id : 0, x : sp.x, y : sp.y, z : sp.z, yaw : 0., pitch : 0., flags : 0, charge : -1, hx : 0., hy : 0., hz : 0. };
		var cx = Std.int(sp.x) + 2, cy = Std.int(sp.y);
		var cz = w.topCollide(cx, cy);
		w.setBlock(cx, cy, cz, Block.get(BChest));
		var seqs = [for( _ in 0...nbots ) 1000];
		for( b in bots ) {
			b.client.send(CState(st));
			server.worlds.items.devGive(@:privateAccess server.sessionById(b.id), rock, 20);
		}
		var given = until(() -> Lambda.foreach(bots, b -> count(lastInv(b), rock.index) == 20), 10);
		check("endurance: cada robot empieza con 20 rocas en el planeta", given && Lambda.foreach(bots, b -> @:privateAccess server.sessionById(b.id).instance == inst),
			[for( b in bots ) b.name + "=" + count(lastInv(b), rock.index) + (@:privateAccess server.sessionById(b.id).instance == inst ? "" : "(fuera)")].join(" "));
		var actions = 0, reconnects = 0;
		var t0 = haxe.Timer.stamp();
		while( haxe.Timer.stamp() - t0 < secs ) {
			for( i in 0...nbots ) {
				var b = bots[i];
				var inv = lastInv(b);
				if( inv == null ) continue;
				var r = Math.random();
				var seq = ++seqs[i];
				if( r < 0.22 ) {
					var slots = [for( k in 0...inv.t.length ) if( inv.t[k] != null ) k + 1];
					if( slots.length > 0 ) {
						var s = slots[Std.random(slots.length)];
						b.client.send(CThrow(seq, s, 1 + Std.random(inv.t[s - 1].n)));
					}
				} else if( r < 0.5 ) {
					var ids = [for( id in loots(b).keys() ) id];
					if( ids.length > 0 ) b.client.send(CPick(seq, ids[Std.random(ids.length)]));
				} else if( r < 0.62 ) {
					var t = [for( s in inv.t ) s == null ? null : { k : s.k, n : s.n }];
					for( k in 0...t.length ) {
						var j = Std.random(t.length), x = t[k];
						t[k] = t[j];
						t[j] = x;
					}
					b.client.send(CInvLayout(seq, { t : t, charges : inv.charges }));
				} else if( r < 0.85 ) {
					var c = lastChest(b);
					if( c == null || Math.random() < 0.3 ) b.client.send(CChestOpen(cx, cy, cz));
					else {
						// pasar una pila de un lado al otro (sobre lo ultimo que sabe: si ya no vale, el servidor lo rechaza)
						var nc = [for( s in c.t ) s == null ? null : { k : s.k, n : s.n }];
						var ni = [for( s in inv.t ) s == null ? null : { k : s.k, n : s.n }];
						var from = Math.random() < 0.5 ? nc : ni, to = from == nc ? ni : nc;
						var fs = [for( k in 0...from.length ) if( from[k] != null ) k], ts = [for( k in 0...to.length ) if( to[k] == null ) k];
						if( fs.length > 0 && ts.length > 0 ) {
							var a = fs[Std.random(fs.length)], z = ts[Std.random(ts.length)];
							to[z] = from[a];
							from[a] = null;
							b.client.send(CChestMove(cx, cy, cz, c.ver, nc, { t : ni, charges : inv.charges }));
						}
						if( Math.random() < 0.2 ) b.client.send(CChestClose);
					}
				} else if( r < 0.87 ) {
					// se va y vuelve (lo que tenia pedido se pierde o llega tarde)
					b.client.close();
					clients.remove(b);
					var nb = add(new TestClient("Bot" + i, secret(80 + i)));
					nb.tcp(55091);
					bots[i] = nb;
					reconnects++;
					until(() -> nb.welcome != null, 5);
					nb.client.send(CLand(i == 0 ? "" : pub, pid));
					until(() -> @:privateAccess server.sessionById(nb.id) != null && @:privateAccess server.sessionById(nb.id).instance == inst, 5);
					nb.client.send(CState(st));
				}
				actions++;
			}
			until(() -> false, 0.01);
		}
		for( b in bots ) b.client.send(CChestClose);
		until(() -> false, 2);
		// el grand livre, en el servidor
		var total = 0, bad = [];
		inline function slotsOk( t : Array<Null<{ k : Int, n : Int }>>, where : String ) {
			for( s in t ) if( s != null ) {
				if( s.n <= 0 || s.n > Block.all[s.k].getMax(9999) ) bad.push(where + " " + s.k + "x" + s.n);
				if( s.k == rock.index ) total += s.n;
			}
		}
		for( b in bots ) {
			var s = @:privateAccess server.sessionById(b.id);
			if( s != null && s.record != null ) slotsOk(s.record.inv.t, "inv " + s.display);
		}
		for( k => c in inst.items.chests ) slotsOk(c, "cantina " + k);
		for( d in inst.items.drops ) {
			if( d.loot != null ) slotsOk(d.loot.t, "contenedor");
			else if( d.b == rock ) total += d.n;
		}
		if( total != 20 * nbots ) Sys.println("  cantinas " + [for( k => c in inst.items.chests ) k + ":" + count({ t : c, charges : [] }, rock.index)].join(",") + " sueltos " + [for( d in inst.items.drops ) d.b.k + "x" + d.n].join(","));
		check("endurance: " + actions + " acciones de " + nbots + " robots (" + reconnects + " reconexiones) en " + Std.int(secs) + " s, ni se crea ni se pierde nada",
			total == 20 * nbots && bad.length == 0, "rocas " + total + " de " + (20 * nbots) + (bad.length > 0 ? ", pilas raras: " + bad.join(", ") : ""));
		server.stop();
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
			CTalk(CPrivate, 7, "hola ñ"), CAdmin(ABan, 3, "x"), CSetMode(true), CBye, CNewGame(true), CLand("", 3), CTakeoff,
			CState({ id : 0, x : 1.5, y : 2.5, z : 3.5, yaw : 0.25, pitch : -0.5, flags : 1, charge : -1, hx : 4, hy : 5, hz : 6 }),
			CBreak(1, 2, 3, 4, 5), CPlace(2, 3, 4, 5, 6, 0, 1), CSaveRecord(Bytes.ofString("z")),
			CAccess(3, true, false, true, 4), CInvite(3, 2, 1), CGuest(3, "ab12cd34", -1), CTransfer(3, 2), CAbandon(3), CGetAccess(3),
			CCharge(1), CPick(4, 9), CThrow(5, 2, 3), CInvLayout(6, { t : [null, { k : 5, n : 2 }], charges : [{ c : 1, n : 3 }] }), CDeath(true),
			CCreative(7, 1, 5, 9), CChestOpen(1, 2, 3), CChestMove(1, 2, 3, 4, [{ k : 5, n : 1 }, null], { t : [null], charges : [] }), CChestClose,
			CActivate(4, 5, 6), CEcon(9, EBuy, "b12", 3), CShipOffset(-37, 34), CShipSet(3, 4, 5, 6, 7, 8, 2), CShipCraft(1, 2, 3),
			CStorage(4, { t : [null, { k : 3, n : 2 }], charges : [{ c : 1, n : 4 }] }, { t : [{ k : 5, n : 1 }], charges : [] }),
			CSaveShip(2, haxe.io.Bytes.ofString("nave"), { t : [null], charges : [] }), CShipMove(56, 78)];
		var ss : Array<ServerMsg> = [SServerHello("srv", b32, b32, b64, true), SWelcome(3, "Bob#2", Manager, true, 123.5, false),
			SRefuse(RBanned, "x"), SPong(1.25, 2.5), SPlayers([{ id : 1, name : "a", role : 2, place : "" }]),
			SUserJoin({ id : 2, name : "b", role : 0, place : "Planète de X" }), SUserLeave(9), STalk(-1, "srv", CServer, "m"),
			SNotice("mp.x", ["a", "b"]), SMode(false), SKicked(RKicked, "Alice"),
			SRecord(Bytes.ofString("r")), SPlanetData("k:3", 42, "BIMars", 2, 0, "", Bytes.ofString("e"), "Bob", 7),
			SChanges([{ key : 5, v : 9 }]), SSetResult(4, false, 3),
			SStates([{ id : 2, x : 1.5, y : 2.5, z : 3.5, yaw : 0.5, pitch : 0, flags : 3, charge : 2, hx : 1, hy : 2, hz : 3 }]), SGone(5), SReduceWater,
			SAccess(3, true, true, false, 4, [{ pub : "ab12cd34", name : "Bob", role : 1 }]),
			SForeign([{ pub : "ab12cd34", owner : "Bob", seed : 42, startSeed : 7, startBiome : "BIMars", startSize : 2, gone : [3], planets : [{ pid : 10, status : 3 }] }]),
			SPlanetLost("mp.x"), SRights(7),
			SInventory(3, { t : [{ k : 5, n : 2 }, null], charges : [{ c : 0, n : 4 }] }),
			SAddLoot({ id : 1, x : 1.5, y : 2.5, z : 3.5, vx : 0.25, vy : -0.25, vz : 0, gi : 5, n : 2, delay : 0, container : true }),
			SDeleteLoot(1), SLootCount(1, 2), SLootRest(1, 1.5, 2.5, 3.5), SChest(1, 2, 3, 4, [null, { k : 5, n : 1 }], "Bob"), SHit(20), SBomb(1.5, 2.5, 3.5),
			SPatch("credits", "120"), SShipCells([{ key : 77, v : 3 }]), SServerInfo("Mi server", true, false, true), SShipMove(12, 34)];
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
