import haxe.io.Bytes;

/**
 * Transporte de bytes del multijugador (anadido del port): TCP (TcpTransport) o en memoria (LocalTransport: el servidor dentro
 * del juego y su propio jugador). Sin hilos: send apunta, flush manda lo que se pueda y read devuelve lo que haya llegado.
 */
interface Transport {
	/** cerrado (por este lado, por el otro o por un error); closeReason dice por que */
	var closed(get, never) : Bool;
	var closeReason(get, never) : String;
	/** direccion del otro lado para los registros ("127.0.0.1:1234", "local") */
	function peerName() : String;
	function send( b : Bytes ) : Void;
	/** manda lo pendiente sin bloquear */
	function flush() : Void;
	/** bytes llegados desde la ultima vez (null si nada) */
	function read() : Null<Bytes>;
	/** bytes aun por mandar */
	function pending() : Int;
	function close( reason : String ) : Void;
}

/** TCP no bloqueante sobre sys.net.Socket (port/spike/SockSpike.hx) */
class TcpTransport implements Transport {

	public var closed(get, never) : Bool;
	public var closeReason(get, never) : String;
	var sock : sys.net.Socket;
	var out = new haxe.io.BytesBuffer();
	var outBytes : Bytes;
	var outPos = 0;
	var tmp = Bytes.alloc(1 << 16);
	var reason : String;
	var peer : String;

	public function new( s : sys.net.Socket ) {
		sock = s;
		s.setBlocking(false);
		try s.setFastSend(true) catch( e : Dynamic ) {}
		try {
			var p = s.peer();
			peer = p.host.toString() + ":" + p.port;
		} catch( e : Dynamic ) peer = "?";
	}

	function get_closed() return reason != null;
	function get_closeReason() return reason;

	public function peerName() return peer;

	public function send( b : Bytes ) {
		if( reason != null ) return;
		out.add(b);
	}

	public function pending() : Int return (outBytes == null ? 0 : outBytes.length - outPos) + out.length;

	public function flush() {
		if( reason != null ) return;
		while( true ) {
			if( outBytes == null || outPos >= outBytes.length ) {
				if( out.length == 0 ) {
					outBytes = null;
					return;
				}
				outBytes = out.getBytes();
				out = new haxe.io.BytesBuffer();
				outPos = 0;
			}
			try {
				var n = sock.output.writeBytes(outBytes, outPos, outBytes.length - outPos);
				if( n <= 0 ) return;
				outPos += n;
			} catch( e : haxe.io.Error ) {
				if( e == Blocked ) return;
				close("envio: " + e);
				return;
			} catch( e : Dynamic ) {
				close("envio: " + e);
				return;
			}
		}
	}

	public function read() : Null<Bytes> {
		if( reason != null ) return null;
		var acc : haxe.io.BytesBuffer = null;
		while( true ) {
			var n = 0;
			try n = sock.input.readBytes(tmp, 0, tmp.length) catch( e : haxe.io.Error ) {
				if( e == Blocked ) break;
				close("lectura: " + e);
				break;
			} catch( e : haxe.io.Eof ) {
				close("cerrada por el otro lado");
				break;
			} catch( e : Dynamic ) {
				close("lectura: " + e);
				break;
			}
			if( n <= 0 ) break;
			if( acc == null ) acc = new haxe.io.BytesBuffer();
			acc.addBytes(tmp, 0, n);
			if( acc.length > 1 << 22 ) break;
		}
		return acc == null ? null : acc.getBytes();
	}

	public function close( r : String ) {
		if( reason != null ) return;
		reason = r;
		try sock.close() catch( e : Dynamic ) {}
	}

	/** el socket, para Socket.select (servidor dedicado) */
	public function socket() return sock;
}

/** Dos extremos en memoria: lo que manda uno lo lee el otro (con un retraso de pruebas opcional, --netlag=ms) */
class LocalTransport implements Transport {

	public var closed(get, never) : Bool;
	public var closeReason(get, never) : String;
	var other : LocalTransport;
	var inbox = new Array<{ at : Float, b : Bytes }>();
	var reason : String;
	var name : String;
	public static var lag = 0.;
	public static var jitter = 0.;

	function new( name : String ) {
		this.name = name;
	}

	/** [extremo del cliente, extremo del servidor] */
	public static function pair() : Array<LocalTransport> {
		var a = new LocalTransport("local"), b = new LocalTransport("local");
		a.other = b;
		b.other = a;
		return [a, b];
	}

	function get_closed() return reason != null;
	function get_closeReason() return reason;

	public function peerName() return name;

	public function send( b : Bytes ) {
		if( reason != null || other.reason != null ) return;
		var at = lag <= 0 && jitter <= 0 ? 0. : haxe.Timer.stamp() + (lag + Math.random() * jitter) / 1000;
		other.inbox.push({ at : at, b : b });
	}

	public function flush() {}

	public function pending() return 0;

	public function read() : Null<Bytes> {
		if( reason != null ) return null;
		if( inbox.length == 0 ) {
			if( other.reason != null ) reason = "cerrada por el otro lado";
			return null;
		}
		var now = haxe.Timer.stamp();
		var acc : haxe.io.BytesBuffer = null;
		while( inbox.length > 0 && inbox[0].at <= now ) {
			if( acc == null ) acc = new haxe.io.BytesBuffer();
			acc.add(inbox.shift().b);
		}
		return acc == null ? null : acc.getBytes();
	}

	public function close( r : String ) {
		if( reason != null ) return;
		reason = r;
		inbox = [];
	}
}
