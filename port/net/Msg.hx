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
 * Operaciones de la progresion (CEcon): el cliente las hace en su copia de la partida con las reglas del core (lo ve al momento)
 * y el servidor las repite sobre la de verdad; despues manda los campos que han cambiado (SPatch) y el inventario.
 */
enum abstract EconOp(Int) to Int from Int {
	/** comprar n de la mercancia a (Market.ware) */
	var EBuy = 0;
	var ESell = 1;
	/** entregar al contrato n del tablero (Contracts.deliver) */
	var EDeliver = 2;
	/** dar lo que se lleve al contrato en curso n (Contracts.give) */
	var EGive = 3;
	/** abandonar el contrato en curso n */
	var EAbandonContract = 4;
	/** dar tierra roja al contrato especial */
	var EGiveSpecial = 5;
	/** comprar la mejora ESCorp a */
	var EUpgrade = 6;
	/** planeta n como planeta principal */
	var EMainPlanet = 7;
	/** fin del tutorial: el envio de la ESCorp (TutoSetup.grant) y su planeta pasa a principal */
	var EEndTutorial = 8;
	/** pasar el tutorial: la partida como si se hubiera empezado sin el (TutoSetup.skip) */
	var ESkipTutorial = 9;
	public static inline var MAX = 9;
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

/** derechos de un jugador en un planeta (SPlanetData.rights) */
enum abstract Rights(Int) to Int from Int {
	var REnter = 1;
	/** romper y poner (propietario e invitados exploradores) */
	var RBuild = 2;
	var RChests = 4;
	var RActivate = 8;
	var RPickup = 16;
	/** propietario: accesos, mover la nave, ceder, abandonar */
	var ROwner = 32;
	/** visitante: no pierde el equipo al morir aqui */
	var RVisitor = 64;
	public static inline var ALL = 1 | 2 | 4 | 8 | 16 | 32;
	public static inline var EXPLORER = 1 | 2 | 4 | 8 | 16;
}

/** papel de un invitado en un planeta */
enum abstract GuestRole(Int) to Int from Int {
	var GExplorer = 0;
	var GVisitor = 1;
}

/** invitado de un planeta (id publico del jugador, su ultimo pseudo, su papel) */
typedef NetGuest = { pub : String, name : String, role : Int };

/** planeta de otra galaxia al que el jugador tiene acceso y su estado para el (ExpData: PInvited, PVisit, PForbidden...) */
typedef NetForeignPlanet = { pid : Int, status : Int };

/** galaxia de otro jugador con planetas a los que el jugador tiene acceso: lo que hace falta para dibujar su sistema */
typedef NetForeign = { pub : String, owner : String, seed : Int, startSeed : Int, startBiome : String, startSize : Int, gone : Array<Int>, planets : Array<NetForeignPlanet> };

/** inventario (Protocol.InventoryInfos): casillas (bloque global y cantidad, null = vacia) y cargas */
typedef NetInv = { t : Array<Null<{ k : Int, n : Int }>>, charges : Array<{ c : Int, n : Int }> };

/**
 * Bloque suelto en el mundo (Drops), del servidor: id, posicion, velocidad, bloque y cantidad, retraso antes de verse (s) y si es
 * el contenedor del equipo dejado al morir (DeathDrops; container: se ve como una cantina y lo que lleva lo sabe el servidor)
 */
typedef NetLoot = { id : Int, x : Float, y : Float, z : Float, vx : Float, vy : Float, vz : Float, gi : Int, n : Int, delay : Float, container : Bool };

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
	/** propietario: abrir o cerrar su planeta pid, todos los invitados visitantes, visita para todo el servidor (gestionnaires) y
	    lo que pueden hacer los visitantes (Rights: RChests, RActivate, RPickup) */
	CAccess( pid : Int, open : Bool, allVisitors : Bool, serverVisit : Bool, visitorRights : Int );
	/** propietario: invitar a un jugador conectado (id de sesion) con un papel (GuestRole) */
	CInvite( pid : Int, target : Int, role : Int );
	/** propietario: cambiar el papel de un invitado (role) o quitarlo (role = -1) */
	CGuest( pid : Int, pub : String, role : Int );
	/** propietario: ceder el titulo a un jugador conectado */
	CTransfer( pid : Int, target : Int );
	CAbandon( pid : Int );
	/** pedir los accesos de un planeta propio (SAccess) */
	CGetAccess( pid : Int );
	/** ha gastado una carga (ChargeKind) al excavar */
	CCharge( c : Int );
	/** recoger el suelto id (que esta a su lado) */
	CPick( seq : Int, id : Int );
	/** tirar n de la casilla slot (R, pantalla de inventario) */
	CThrow( seq : Int, slot : Int, n : Int );
	/** nuevo orden del inventario (pantalla de inventario): mismas cosas, en otras casillas */
	CInvLayout( seq : Int, inv : NetInv );
	/** ha muerto (o Mayus+K, manual): su equipo va a un contenedor donde esta */
	CDeath( manual : Bool );
	/** creativo: pone n del bloque gi en la casilla slot (paleta) */
	CCreative( seq : Int, slot : Int, gi : Int, n : Int );
	/** abrir la cantina de (x, y, z) */
	CChestOpen( x : Int, y : Int, z : Int );
	/** nuevo contenido de la cantina abierta y del inventario (lo que se ha movido entre los dos), sobre la version ver */
	CChestMove( x : Int, y : Int, z : Int, ver : Int, chest : Array<Null<{ k : Int, n : Int }>>, inv : NetInv );
	CChestClose;
	/** activar el bloque de (x, y, z): puerta, bomba... */
	CActivate( x : Int, y : Int, z : Int );
	/** progresion: la operacion op (EconOp) con sus argumentos */
	CEcon( seq : Int, op : Int, a : String, n : Int );
	/** su nave: donde esta en el planeta (shipDX, shipDY), para pasar sus coordenadas a las del planeta (sueltos de la nave) */
	CShipOffset( dx : Int, dy : Int );
	/** su nave: poner (gi) o quitar (gi = 0) en (x, y, z) de la nave, donde habia expect, desde la casilla slot */
	CShipSet( seq : Int, x : Int, y : Int, z : Int, expect : Int, gi : Int, slot : Int );
	/** su nave: el ordenador del sintetizador de (x, y, z) de la nave */
	CShipCraft( x : Int, y : Int, z : Int );
	/** su nave: nuevo contenido del stockage y del inventario (lo movido entre los dos) */
	CStorage( seq : Int, store : NetInv, inv : NetInv );
	/** al salir del hangar con una nave valida: la nave (comprimida, como Hangar.shipBytes) y el inventario tal como quedan */
	CSaveShip( seq : Int, ship : haxe.io.Bytes, inv : NetInv );
	/** el propietario ha aterrizado su nave en (x, y) de su planeta: el punto de aterrizaje de todos */
	CShipMove( x : Int, y : Int );
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
	/** accesos de un planeta propio (para su pantalla) */
	SAccess( pid : Int, open : Bool, allVisitors : Bool, serverVisit : Bool, visitorRights : Int, guests : Array<NetGuest> );
	/** galaxias de otros con planetas accesibles para el jugador (se anaden a su mapa) */
	SForeign( list : Array<NetForeign> );
	/** el jugador ya no puede estar en el planeta donde esta (cerrado, abandonado, retirado): vuelve al espacio */
	SPlanetLost( reason : String );
	/** sus derechos en este planeta han cambiado (Rights) */
	SRights( rights : Int );
	/** el inventario del jugador (lo lleva el servidor); ack: ultima peticion suya ya hecha (para rehacer encima lo que espera) */
	SInventory( ack : Int, inv : NetInv );
	SAddLoot( l : NetLoot );
	SDeleteLoot( id : Int );
	/** al suelto id le quedan n (se ha recogido una parte) */
	SLootCount( id : Int, n : Int );
	/** el suelto id se ha parado aqui (corrige la fisica del cliente) */
	SLootRest( id : Int, x : Float, y : Float, z : Float );
	/** contenido de una cantina abierta (version ver); busy: el pseudo de quien la tiene abierta si no se puede abrir */
	SChest( x : Int, y : Int, z : Int, ver : Int, t : Array<Null<{ k : Int, n : Int }>>, busy : String );
	/** dano al jugador (bomba) */
	SHit( dmg : Float );
	/** una bomba ha explotado en (x, y, z): efecto y temblor */
	SBomb( x : Float, y : Float, z : Float );
	/** un campo de la partida tal como lo tiene el servidor (credits, market, contracts, special, upgrades, licenses), en JSON */
	SPatch( key : String, json : String );
	/** su nave: celdas cambiadas por el servidor (clave de la nave, como SChanges) */
	SShipCells( list : Array<NetChange> );
	/** a los gestionnaires: las opciones del servidor (para Pausa > Opciones multijugador) */
	SServerInfo( name : String, lan : Bool, deathDrop : Bool, password : Bool );
	/** el propietario ha llevado su nave a (x, y): cada uno lleva alli la suya */
	SShipMove( x : Int, y : Int );
	/** al entrar: el kube del editor numero i del servidor, en bruto (KubeCore.NetKube: nada que descomprimir ni guardar) */
	SKubeDef( i : Int, k : KubeCore.NetKube );
	/** fin de los kubes del servidor: hay n numeros (los que no han llegado no tienen kube) */
	SKubesEnd( n : Int );
}

/**
 * Protocolo del multijugador (anadido del port): mensajes del cliente (ClientMsg) y del servidor (ServerMsg), escritos a mano
 * con NetWriter/NetReader. Cada campo tiene su limite al leer (cadenas, listas, rangos): un mensaje que no cuadra lanza NetError.
 * PROTOCOL sube con cualquier cambio de un mensaje.
 */
class Msg {

	public static inline var PROTOCOL = 8;
	/** cambios de celdas en un mensaje, y bytes de un terreno descomprimido */
	public static inline var CHANGES_MAX = 1 << 16;
	public static inline var EDITS_MAX = 64 << 20;
	public static inline var NAME_MAX = 24;
	/** SPatch: un campo de la partida en JSON */
	public static inline var PATCH_MAX = 1 << 20;
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

	/** casillas de bloques: cantidad, y por casilla el bloque global (0 = vacia) y su cantidad */
	static function writeSlots( w : NetWriter, t : Array<Null<{ k : Int, n : Int }>> ) {
		w.uint(t.length);
		for( s in t ) {
			if( s == null || s.n <= 0 ) { w.uint(0); continue; }
			w.uint(s.k);
			w.uint(s.n);
		}
	}

	static function readSlots( r : NetReader ) : Array<Null<{ k : Int, n : Int }>> {
		var n = r.count(256, 1);
		var out : Array<Null<{ k : Int, n : Int }>> = [];
		for( _ in 0...n ) {
			var k = r.uintIn(0, 0xFFFF);
			if( k == 0 ) { out.push(null); continue; }
			var c = r.uintIn(1, 1 << 20);
			out.push({ k : k, n : c });
		}
		return out;
	}

	static function writeInv( w : NetWriter, i : NetInv ) {
		writeSlots(w, i.t);
		w.uint(i.charges.length);
		for( c in i.charges ) { w.uint(c.c); w.uint(c.n); }
	}

	static function readInv( r : NetReader ) : NetInv {
		var t = readSlots(r);
		var n = r.count(16, 2);
		var charges = [for( _ in 0...n ) { var c = r.uintIn(0, 15); var k = r.uintIn(0, 1 << 20); { c : c, n : k }; }];
		return { t : t, charges : charges };
	}

	static function writeLoot( w : NetWriter, l : NetLoot ) {
		w.uint(l.id); w.float(l.x); w.float(l.y); w.float(l.z); w.float(l.vx); w.float(l.vy); w.float(l.vz);
		w.uint(l.gi); w.uint(l.n); w.float(l.delay); w.bool(l.container);
	}

	static function readLoot( r : NetReader ) : NetLoot {
		var id = r.uint(); var x = r.floatIn(-1e5, 1e5); var y = r.floatIn(-1e5, 1e5); var z = r.floatIn(-1e3, 1e4);
		var vx = r.floatIn(-100, 100); var vy = r.floatIn(-100, 100); var vz = r.floatIn(-100, 100);
		var gi = r.uintIn(0, 0xFFFF); var n = r.uintIn(0, 1 << 20); var delay = r.floatIn(0, 1000); var c = r.bool();
		return { id : id, x : x, y : y, z : z, vx : vx, vy : vy, vz : vz, gi : gi, n : n, delay : delay, container : c };
	}

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
		case CAccess(pid, open, allVisitors, serverVisit, vr):
			w.uint(pid); w.bool(open); w.bool(allVisitors); w.bool(serverVisit); w.uint(vr);
		case CInvite(pid, target, role):
			w.uint(pid); w.uint(target); w.uint(role);
		case CGuest(pid, pub, role):
			w.uint(pid); w.string(pub); w.int(role);
		case CTransfer(pid, target):
			w.uint(pid); w.uint(target);
		case CAbandon(pid):
			w.uint(pid);
		case CGetAccess(pid):
			w.uint(pid);
		case CCharge(c):
			w.uint(c);
		case CPick(seq, id):
			w.uint(seq); w.uint(id);
		case CThrow(seq, slot, n):
			w.uint(seq); w.uint(slot); w.uint(n);
		case CInvLayout(seq, inv):
			w.uint(seq); writeInv(w, inv);
		case CDeath(manual):
			w.bool(manual);
		case CCreative(seq, slot, gi, n):
			w.uint(seq); w.uint(slot); w.uint(gi); w.uint(n);
		case CChestOpen(x, y, z):
			w.uint(x); w.uint(y); w.uint(z);
		case CChestMove(x, y, z, ver, chest, inv):
			w.uint(x); w.uint(y); w.uint(z); w.uint(ver); writeSlots(w, chest); writeInv(w, inv);
		case CChestClose:
		case CActivate(x, y, z):
			w.uint(x); w.uint(y); w.uint(z);
		case CEcon(seq, op, a, n):
			w.uint(seq); w.uint(op); w.string(a); w.uint(n);
		case CShipOffset(dx, dy):
			w.int(dx); w.int(dy);
		case CShipSet(seq, x, y, z, expect, gi, slot):
			w.uint(seq); w.uint(x); w.uint(y); w.uint(z); w.uint(expect); w.uint(gi); w.uint(slot);
		case CShipCraft(x, y, z):
			w.uint(x); w.uint(y); w.uint(z);
		case CStorage(seq, store, inv):
			w.uint(seq); writeInv(w, store); writeInv(w, inv);
		case CSaveShip(seq, ship, inv):
			w.uint(seq); w.bytes(ship); writeInv(w, inv);
		case CShipMove(x, y):
			w.uint(x); w.uint(y);
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
		case 14:
			var pid = r.uintIn(0, 1 << 20); var open = r.bool(); var av = r.bool(); var sv = r.bool(); var vr = r.uintIn(0, 0xFF);
			CAccess(pid, open, av, sv, vr);
		case 15:
			var pid = r.uintIn(0, 1 << 20); var t = r.uint(); var role = r.uintIn(0, 1);
			CInvite(pid, t, role);
		case 16:
			var pid = r.uintIn(0, 1 << 20); var pub = r.string(16); var role = r.intIn(-1, 1);
			CGuest(pid, pub, role);
		case 17:
			var pid = r.uintIn(0, 1 << 20); var t = r.uint();
			CTransfer(pid, t);
		case 18: CAbandon(r.uintIn(0, 1 << 20));
		case 19: CGetAccess(r.uintIn(0, 1 << 20));
		case 20: CCharge(r.uintIn(0, 15));
		case 21:
			var seq = r.uint(); var id = r.uint();
			CPick(seq, id);
		case 22:
			var seq = r.uint(); var slot = r.uintIn(0, 255); var n = r.uintIn(1, 1 << 20);
			CThrow(seq, slot, n);
		case 23:
			var seq = r.uint(); var inv = readInv(r);
			CInvLayout(seq, inv);
		case 24: CDeath(r.bool());
		case 25:
			var seq = r.uint(); var slot = r.uintIn(0, 255); var gi = r.uintIn(0, 0xFFFF); var n = r.uintIn(0, 1 << 20);
			CCreative(seq, slot, gi, n);
		case 26:
			var x = r.uintIn(0, COORD_MAX); var y = r.uintIn(0, COORD_MAX); var z = r.uintIn(0, Z_MAX);
			CChestOpen(x, y, z);
		case 27:
			var x = r.uintIn(0, COORD_MAX); var y = r.uintIn(0, COORD_MAX); var z = r.uintIn(0, Z_MAX); var ver = r.uint();
			var chest = readSlots(r); var inv = readInv(r);
			CChestMove(x, y, z, ver, chest, inv);
		case 28: CChestClose;
		case 29:
			var x = r.uintIn(0, COORD_MAX); var y = r.uintIn(0, COORD_MAX); var z = r.uintIn(0, Z_MAX);
			CActivate(x, y, z);
		case 30:
			var seq = r.uint(); var op = r.uintIn(0, EconOp.MAX); var a = r.string(64); var n = r.uintIn(0, 1 << 20);
			CEcon(seq, op, a, n);
		case 31:
			var dx = r.intIn(-COORD_MAX, COORD_MAX); var dy = r.intIn(-COORD_MAX, COORD_MAX);
			CShipOffset(dx, dy);
		case 32:
			var seq = r.uint(); var x = r.uintIn(0, COORD_MAX); var y = r.uintIn(0, COORD_MAX); var z = r.uintIn(0, Z_MAX);
			var expect = r.uintIn(0, 0xFFFF); var gi = r.uintIn(0, 0xFFFF); var slot = r.uintIn(0, 255);
			CShipSet(seq, x, y, z, expect, gi, slot);
		case 33:
			var x = r.uintIn(0, COORD_MAX); var y = r.uintIn(0, COORD_MAX); var z = r.uintIn(0, Z_MAX);
			CShipCraft(x, y, z);
		case 34:
			var seq = r.uint(); var store = readInv(r); var inv = readInv(r);
			CStorage(seq, store, inv);
		case 35:
			var seq = r.uint(); var ship = r.bytes(1 << 16); var inv = readInv(r);
			CSaveShip(seq, ship, inv);
		case 36:
			var x = r.uintIn(0, COORD_MAX); var y = r.uintIn(0, COORD_MAX);
			CShipMove(x, y);
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
		case SAccess(pid, open, allVisitors, serverVisit, vr, guests):
			w.uint(pid); w.bool(open); w.bool(allVisitors); w.bool(serverVisit); w.uint(vr);
			w.uint(guests.length);
			for( g in guests ) { w.string(g.pub); w.string(g.name); w.uint(g.role); }
		case SForeign(list):
			w.uint(list.length);
			for( f in list ) {
				w.string(f.pub); w.string(f.owner); w.int(f.seed); w.int(f.startSeed); w.string(f.startBiome); w.uint(f.startSize);
				w.uint(f.gone.length);
				for( g in f.gone ) w.uint(g);
				w.uint(f.planets.length);
				for( p in f.planets ) { w.uint(p.pid); w.uint(p.status); }
			}
		case SRights(r):
			w.uint(r);
		case SInventory(ack, inv):
			w.uint(ack); writeInv(w, inv);
		case SAddLoot(l):
			writeLoot(w, l);
		case SDeleteLoot(id):
			w.uint(id);
		case SLootCount(id, n):
			w.uint(id); w.uint(n);
		case SLootRest(id, x, y, z):
			w.uint(id); w.float(x); w.float(y); w.float(z);
		case SChest(x, y, z, ver, t, busy):
			w.uint(x); w.uint(y); w.uint(z); w.int(ver); writeSlots(w, t); w.string(busy);
		case SHit(dmg):
			w.float(dmg);
		case SBomb(x, y, z):
			w.float(x); w.float(y); w.float(z);
		case SPatch(key, json):
			w.string(key); w.string(json);
		case SShipCells(list):
			w.uint(list.length);
			for( c in list ) { w.uint(c.key); w.uint(c.v); }
		case SServerInfo(name, lan, deathDrop, password):
			w.string(name); w.bool(lan); w.bool(deathDrop); w.bool(password);
		case SShipMove(x, y):
			w.uint(x); w.uint(y);
		case SKubeDef(i, k):
			w.uint(i); w.string(k.id); w.string(k.name); w.uint(k.shape); w.uint(k.render);
			for( v in k.box ) w.uint(v);
			w.float(k.light); w.float(k.reach); w.bool(k.noCollide); w.bytes(k.faces);
		case SKubesEnd(n):
			w.uint(n);
		case SPlanetLost(reason):
			w.string(reason);
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
		case 18:
			var pid = r.uintIn(0, 1 << 20); var open = r.bool(); var av = r.bool(); var sv = r.bool(); var vr = r.uintIn(0, 0xFF);
			var n = r.count(PLAYERS_MAX, 3);
			var guests = [for( _ in 0...n ) { var pub = r.string(16); var name = r.string(NAME_MAX + 8); var role = r.uintIn(0, 1); { pub : pub, name : name, role : role }; }];
			SAccess(pid, open, av, sv, vr, guests);
		case 19:
			var n = r.count(PLAYERS_MAX, 8);
			var list = [for( _ in 0...n ) {
				var pub = r.string(16); var owner = r.string(NAME_MAX + 8); var seed = r.int(); var ss = r.int(); var sb = r.string(32);
				var sz = r.uintIn(0, 8);
				var ng = r.count(1024, 1);
				var gone = [for( _ in 0...ng ) r.uint()];
				var np = r.count(1024, 2);
				var planets = [for( _ in 0...np ) { var pid = r.uint(); var st = r.uintIn(0, 15); { pid : pid, status : st }; }];
				{ pub : pub, owner : owner, seed : seed, startSeed : ss, startBiome : sb, startSize : sz, gone : gone, planets : planets };
			}];
			SForeign(list);
		case 20: SPlanetLost(r.string(64));
		case 21: SRights(r.uintIn(0, 0xFFFF));
		case 22:
			var ack = r.uint(); var inv = readInv(r);
			SInventory(ack, inv);
		case 23: SAddLoot(readLoot(r));
		case 24: SDeleteLoot(r.uint());
		case 25:
			var id = r.uint(); var n = r.uint();
			SLootCount(id, n);
		case 26:
			var id = r.uint(); var x = r.floatIn(-1e5, 1e5); var y = r.floatIn(-1e5, 1e5); var z = r.floatIn(-1e3, 1e4);
			SLootRest(id, x, y, z);
		case 27:
			var x = r.uintIn(0, COORD_MAX); var y = r.uintIn(0, COORD_MAX); var z = r.uintIn(0, Z_MAX); var ver = r.intIn(-1, 1 << 30);
			var t = readSlots(r); var busy = r.string(NAME_MAX + 8);
			SChest(x, y, z, ver, t, busy);
		case 28: SHit(r.floatIn(0, 10000));
		case 29:
			var x = r.floatIn(-1e5, 1e5); var y = r.floatIn(-1e5, 1e5); var z = r.floatIn(-1e3, 1e4);
			SBomb(x, y, z);
		case 30:
			var key = r.string(16); var json = r.string(PATCH_MAX);
			SPatch(key, json);
		case 31:
			var n = r.count(CHANGES_MAX, 2);
			SShipCells([for( _ in 0...n ) { var k = r.uint(); var v = r.uint(); { key : k, v : v }; }]);
		case 32:
			var name = r.string(SERVER_NAME_MAX); var lan = r.bool(); var dd = r.bool(); var pw = r.bool();
			SServerInfo(name, lan, dd, pw);
		case 33:
			var x = r.uintIn(0, COORD_MAX); var y = r.uintIn(0, COORD_MAX);
			SShipMove(x, y);
		case 34:
			var i = r.uintIn(0, KubeCore.MAX - 1); var id = r.string(KubeCore.ID_MAX); var name = r.string(KubeCore.NAME_MAX * 4);
			var shape = r.uintIn(0, KubeCore.SHAPES.length - 1); var render = r.uintIn(0, KubeCore.RENDERS.length - 1);
			var box = [for( _ in 0...6 ) r.uintIn(0, KubeCore.SIZE)];
			var light = r.floatIn(0, 15); var reach = r.floatIn(0, 15); var nc = r.bool(); var faces = r.bytes(KubeCore.FACES.length * KubeCore.FACE_BYTES);
			var k : KubeCore.NetKube = { id : id, name : KubeCore.cleanName(name), shape : shape, render : render, box : box, light : light, reach : reach, noCollide : nc, faces : faces };
			if( !KubeCore.valid(k) ) throw new NetReader.NetError("kube no valido");
			SKubeDef(i, k);
		case 35: SKubesEnd(r.uintIn(0, KubeCore.MAX));
		case k: throw new NetReader.NetError("mensaje de servidor desconocido " + k);
		}
		r.done();
		return m;
	}
}
