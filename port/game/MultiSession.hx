import Msg;
import NetClient.NetEvent;

/**
 * Partida multijugador en curso en el juego (anadido del port): el cliente (NetClient) y, si este juego hospeda, su servidor
 * (GameServer, en el mismo hilo, con el jugador del anfitrion conectado en memoria). GalaxyApp la bombea en cada fotograma, en
 * todos los estados: el mundo de los demas no se para nunca.
 */
class MultiSession {

	public var server(default, null) : GameServer;
	public var client(default, null) : NetClient;
	public var players = new Map<Int, NetPlayer>();
	public var chat = new Array<{ from : Int, name : String, chan : Int, msg : String }>();
	public var myId(default, null) = -1;
	public var myName(default, null) = "";
	public var role(default, null) : Role = Player;
	public var creative(default, null) = false;
	public var firstTime(default, null) = false;
	public var serverName(default, null) = "";
	public var fingerprint(default, null) : String;
	/** por que se acabo (null mientras dura): clave de Lang "mp.refuse.*" o texto */
	public var ended(default, null) : String;
	public var endReason(default, null) : Null<RefuseReason>;
	/** avisos para la pantalla (claves de Lang y sus valores) */
	public var notices = new Array<{ key : String, args : Array<String> }>();
	/** opciones del servidor (solo a los gestionnaires, SServerInfo) */
	public var serverInfo : { name : String, lan : Bool, deathDrop : Bool, password : Bool };
	public var onMessage : ServerMsg -> Void;
	/** jugador nuevo en el servidor: empezar sin preguntar (false = sin tutorial; pruebas). null = la interfaz pregunta */
	public var autoNewGame : Null<Bool>;
	/** galaxias de otros con planetas abiertos para este jugador (SForeign: se anaden al mapa) */
	public var foreign : Array<NetForeign> = [];

	function new() {}

	static function identity() : Identity {
		SecureRandom.init(Settings.dir());
		return Identity.load(Settings.dir()).id;
	}

	/** hospedar: servidor con sus archivos en dir; listenPort > 0 abre ese puerto en bindHost (0.0.0.0 = red local e Internet) */
	/** hospedar con los archivos del servidor en dir (listenPort 0: sin red, solo este juego); save: la partida guardada de la que se
	    crea (la del anfitrion en el servidor la primera vez) */
	public static function host( dir : String, listenPort : Int, bindHost = "0.0.0.0", ?save : SaveData.SaveInfo ) : MultiSession {
		var m = new MultiSession();
		var id = identity();
		// pruebas: --mpseed=N, la galaxia de los jugadores nuevos (la de siempre, para repetir un caso)
		for( a in Sys.args() ) if( StringTools.startsWith(a, "--mpseed=") ) ServerWorlds.fixedSeed = Std.parseInt(a.substr(9));
		m.server = new GameServer(dir);
		m.server.hostSave = save;
		if( listenPort > 0 ) m.server.listen(bindHost, listenPort);
		m.client = new NetClient(id, Settings.myPseudo(), "", 0, m.server.fingerprint);
		m.client.connectLocal(m.server.connectLocal());
		return m;
	}

	/** unirse a la partida de host:port; expectedFp: huella recordada (null la primera vez) */
	public static function join( host : String, port : Int, password : String, expectedFp : Null<String>, tuto = -1 ) : MultiSession {
		var m = new MultiSession();
		m.client = new NetClient(identity(), Settings.myPseudo(), password, tuto, expectedFp);
		m.client.connectTcp(host, port);
		return m;
	}

	public inline function isPlaying() return client != null && client.isPlaying();

	public inline function isManager() return role == Manager || role == Owner;

	public function pump( dt : Float ) {
		if( server != null ) server.pump(dt);
		if( client == null ) return;
		client.pump();
		while( client.events.length > 0 ) event(client.events.shift());
		// lo que el cliente acaba de mandar llega al servidor en el mismo fotograma
		if( server != null ) server.pump(0);
	}

	function event( e : NetEvent ) {
		switch( e ) {
		case EServer(name, fp, _):
			serverName = name;
			fingerprint = fp;
		case EKeyChanged(_, got):
			fingerprint = got;
			end("mp.keychanged", null);
		case EWelcome(id, name, r, c, first):
			myId = id;
			Clock.offset = client.clockOffset;
			myName = name;
			role = r;
			creative = c;
			firstTime = first;
			if( first && autoNewGame != null ) client.send(CNewGame(autoNewGame));
		case ERefused(r, detail):
			end("mp.refuse." + r, r);
		case EKicked(r, detail):
			end("mp.refuse." + r, r);
		case EClosed(why):
			if( ended == null ) end("mp.closed", null);
		case EMessage(m):
			switch( m ) {
			case SPlayers(list):
				players = new Map();
				for( p in list ) players.set(p.id, p);
			case SUserJoin(p):
				var known = players.exists(p.id);
				players.set(p.id, p);
				if( p.id == myId ) role = p.role;
				if( !known ) chat.push({ from : -1, name : p.name, chan : CServer, msg : "join" });
			case SUserLeave(id):
				var p = players.get(id);
				players.remove(id);
				if( p != null ) chat.push({ from : -1, name : p.name, chan : CServer, msg : "leave" });
			case STalk(from, name, chan, msg):
				chat.push({ from : from, name : name, chan : chan, msg : msg });
			case SNotice(key, args):
				notices.push({ key : key, args : args });
			case SForeign(l):
				foreign = l;
			case SMode(c):
				creative = c;
			case SServerInfo(name, lan, dd, pw):
				serverInfo = { name : name, lan : lan, deathDrop : dd, password : pw };
			default:
			}
			if( onMessage != null ) onMessage(m);
		}
	}

	function end( key : String, r : Null<RefuseReason> ) {
		if( ended != null ) return;
		Clock.offset = 0;
		ended = key;
		endReason = r;
	}

	public function say( text : String, chan : ChatChan = CWorld, to = 0 ) {
		client.send(CTalk(chan, to, text));
	}

	/** salir: el cliente se despide y, si hospedaba, el servidor avisa a todos y se para */
	public function close() {
		Clock.offset = 0;
		if( client != null ) client.close();
		if( server != null ) {
			server.pump(0);
			server.stop();
		}
		if( ended == null ) ended = "mp.closed";
	}

	/** resumen para las pruebas (print mp) */
	public function devInfo() : String {
		var ps = [for( p in players ) p.name + "(" + p.role + ")"];
		ps.sort(Reflect.compare);
		var last = chat.length == 0 ? "-" : chat[chat.length - 1].name + ": " + chat[chat.length - 1].msg;
		return 'mp ${isPlaying() ? "jugando" : "no"} yo=$myName papel=$role creativo=$creative servidor="$serverName" jugadores=[${ps.join(",")}] chat=${chat.length} ultimo=$last fin=$ended';
	}
}
