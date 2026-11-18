import haxe.io.Bytes;
import Msg;

enum NetEvent {
	/** el servidor ha contestado al saludo: su nombre y su huella (la primera vez se guarda; si cambia llega EKeyChanged) */
	EServer( name : String, fingerprint : String, password : Bool );
	/** la huella del servidor no es la que se recordaba: se ha cortado (otro servidor en esa direccion, o alguien en medio) */
	EKeyChanged( expected : String, got : String );
	EWelcome( id : Int, name : String, role : Role, creative : Bool, firstTime : Bool );
	ERefused( reason : RefuseReason, detail : String );
	EKicked( reason : RefuseReason, detail : String );
	/** conexion perdida o imposible (motivo para el registro) */
	EClosed( why : String );
	/** cualquier otro mensaje del servidor, ya en juego */
	EMessage( m : ServerMsg );
}

private enum ClientState {
	CConnecting;
	CHelloSent;
	CLoginSent;
	CPlaying;
	CDone;
}

/**
 * Cliente del multijugador (anadido del port): conecta (TCP en un hilo, porque en Windows una conexion rechazada tarda ~2 s; o en
 * memoria con el servidor del anfitrion), hace el saludo cifrado y entra con la identidad del jugador. Sin hilos despues: pump()
 * en cada fotograma; lo que pasa sale como NetEvent en events.
 */
class NetClient {

	public var events(default, null) = new Array<NetEvent>();
	var channel : Channel;
	var state = CConnecting;
	var identity : Identity;
	var pseudo : String;
	var password : String;
	var tuto : Int;
	var expectedFp : Null<String>;
	var eph : { pk : Bytes, sk : Bytes };
	var connecting : sys.thread.Deque<Dynamic>;
	var connectStart = 0.;
	public var serverName(default, null) = "";
	public var fingerprint(default, null) : String;
	public var myId(default, null) = -1;
	/** diferencia entre la hora del servidor y la de aqui (s) */
	public var clockOffset(default, null) = 0.;
	public var ping(default, null) = 0.;
	var pingTime = 0.;
	static inline var CONNECT_TIMEOUT = 15.;

	/** expectedFp: huella recordada de ese servidor (null = primera vez); tuto: -1 preguntar, 0 no, 1 si */
	public function new( identity : Identity, pseudo : String, password : String, tuto : Int, expectedFp : Null<String> ) {
		this.identity = identity;
		this.pseudo = pseudo;
		this.password = password == null ? "" : password;
		this.tuto = tuto;
		this.expectedFp = expectedFp;
	}

	public function connectTcp( host : String, port : Int ) {
		connecting = new sys.thread.Deque();
		connectStart = haxe.Timer.stamp();
		var q = connecting;
		sys.thread.Thread.create(function() {
			try {
				var s = new sys.net.Socket();
				s.setTimeout(CONNECT_TIMEOUT);
				s.connect(new sys.net.Host(host), port);
				q.add(s);
			} catch( e : Dynamic ) q.add("error: " + Std.string(e));
		});
	}

	public function connectLocal( t : Transport ) {
		start(t);
	}

	function start( t : Transport ) {
		channel = new Channel(t);
		eph = Handshake.ephemeral();
		channel.send(Msg.encodeClient(CHello(Msg.PROTOCOL, GameVersion.VERSION, GameVersion.contentHash(), eph.pk)));
		channel.flush();
		state = CHelloSent;
	}

	public inline function isPlaying() return state == CPlaying;
	public inline function isDone() return state == CDone;

	public function send( m : ClientMsg ) {
		if( state != CPlaying ) return;
		channel.send(Msg.encodeClient(m));
	}

	public function pump() {
		if( state == CDone ) return;
		if( state == CConnecting ) {
			if( connecting == null ) return;
			var r : Dynamic = connecting.pop(false);
			if( r == null ) {
				if( haxe.Timer.stamp() - connectStart > CONNECT_TIMEOUT + 2 ) finish("sin respuesta");
				return;
			}
			if( Std.isOfType(r, String) ) {
				finish(r);
				return;
			}
			start(new Transport.TcpTransport(r));
		}
		var n = 0;
		while( state != CDone && n++ < 500 ) {
			var b = channel.receive();
			if( b == null ) break;
			var m : ServerMsg;
			try m = Msg.decodeServer(b) catch( e : Dynamic ) {
				finish("mensaje del servidor invalido: " + e);
				return;
			}
			handle(m);
		}
		if( state != CDone && channel.transport.closed ) finish(channel.transport.closeReason);
		if( state == CPlaying && haxe.Timer.stamp() - pingTime > 2 ) {
			pingTime = haxe.Timer.stamp();
			send(CPing(pingTime));
		}
		if( channel != null ) channel.flush();
	}

	function handle( m : ServerMsg ) {
		switch( [state, m] ) {
		case [CHelloSent, SServerHello(name, pk, seph, sig, needPwd)]:
			var t = Handshake.transcript(eph.pk, seph, pk);
			if( !Nacl.verify(t, sig, pk) ) {
				finish("firma del servidor invalida");
				return;
			}
			fingerprint = Handshake.fingerprint(pk);
			serverName = name;
			if( expectedFp != null && expectedFp != fingerprint ) {
				events.push(EKeyChanged(expectedFp, fingerprint));
				finish("huella del servidor cambiada");
				return;
			}
			events.push(EServer(name, fingerprint, needPwd));
			var k = Handshake.keys(eph.sk, seph, t);
			channel.setKeys(k.c2s, k.s2c);
			var me = identity.keysFor(pk);
			var loginSig = Nacl.sign(Handshake.loginMessage(t), me.sk);
			channel.send(Msg.encodeClient(CLogin(me.pk, loginSig, pseudo, password, tuto)));
			state = CLoginSent;
		case [_, SRefuse(reason, detail)]:
			events.push(ERefused(reason, detail));
			finish("rechazado");
		case [CLoginSent, SWelcome(id, name, role, creative, clock, firstTime)]:
			myId = id;
			clockOffset = clock - Sys.time();
			state = CPlaying;
			events.push(EWelcome(id, name, role, creative, firstTime));
		case [CPlaying, SKicked(reason, detail)]:
			events.push(EKicked(reason, detail));
			finish("expulsado");
		case [CPlaying, SPong(t, st)]:
			ping = haxe.Timer.stamp() - t;
			clockOffset = st + ping * 0.5 - Sys.time();
		case [CPlaying, _]:
			events.push(EMessage(m));
		default:
			finish("mensaje fuera de lugar: " + Type.enumConstructor(m));
		}
	}

	/** hora del servidor (contratos, cometas, precios) */
	public inline function serverTime() return Sys.time() + clockOffset;

	function finish( why : String ) {
		if( state == CDone ) return;
		state = CDone;
		if( channel != null ) channel.close(why);
		events.push(EClosed(why));
	}

	/** salir (avisa al servidor) */
	public function close() {
		if( state == CPlaying ) {
			channel.send(Msg.encodeClient(CBye));
			channel.flush();
		}
		finish("salida");
	}
}
