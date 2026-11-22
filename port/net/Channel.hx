import haxe.io.Bytes;

/**
 * Tramas del multijugador sobre un Transport (anadido del port): longitud (varint) y contenido. Tras el saludo (setKeys) cada
 * trama va cifrada y firmada con secretbox (XSalsa20-Poly1305), una clave por sentido y un contador por trama como nonce: una
 * trama cambiada, repetida o fuera de orden no se abre y cierra la conexion.
 */
class Channel {

	/** mensaje mas grande que se acepta (antes de cifrar) */
	public static inline var MAX_FRAME = 4 << 20;

	public var transport(default, null) : Transport;
	var inBuf = Bytes.alloc(1 << 16);
	var inLen = 0;
	var sendKey : Bytes;
	var recvKey : Bytes;
	var sendCtr = 0;
	var recvCtr = 0;
	var header = Bytes.alloc(5);
	public var bytesIn(default, null) = 0;
	public var bytesOut(default, null) = 0;
	public var encrypted(get, never) : Bool;

	public function new( t : Transport ) {
		transport = t;
	}

	inline function get_encrypted() return sendKey != null;

	public function setKeys( send : Bytes, recv : Bytes ) {
		sendKey = send;
		recvKey = recv;
		sendCtr = 0;
		recvCtr = 0;
	}

	static function nonce( ctr : Int ) : Bytes {
		var n = Bytes.alloc(24);
		n.fill(0, 24, 0);
		n.setInt32(0, ctr);
		return n;
	}

	public function send( msg : Bytes ) {
		if( transport.closed ) return;
		if( msg.length > MAX_FRAME ) throw "frame too large: " + msg.length;
		var payload = sendKey == null ? msg : Nacl.secretbox(msg, nonce(sendCtr++), sendKey);
		var n = payload.length, h = 0;
		while( n >= 0x80 ) {
			header.set(h++, (n & 0x7F) | 0x80);
			n >>>= 7;
		}
		header.set(h++, n);
		transport.send(header.sub(0, h));
		transport.send(payload);
		bytesOut += h + payload.length;
	}

	/** el siguiente mensaje completo llegado (null si no hay); cierra la conexion si algo no cuadra */
	public function receive() : Null<Bytes> {
		// cerrada, se siguen dando las tramas ya llegadas (el aviso de cierre del servidor llega justo antes del cierre)
		var b = transport.closed ? null : transport.read();
		if( b != null ) {
			bytesIn += b.length;
			if( inLen + b.length > inBuf.length ) {
				var nb = Bytes.alloc(Std.int(Math.max(inBuf.length * 2, inLen + b.length)));
				nb.blit(0, inBuf, 0, inLen);
				inBuf = nb;
			}
			inBuf.blit(inLen, b, 0, b.length);
			inLen += b.length;
		}
		if( inLen == 0 ) return null;
		var n = 0, shift = 0, p = 0;
		while( true ) {
			if( p >= inLen ) return null;
			var c = inBuf.get(p++);
			n |= (c & 0x7F) << shift;
			if( c & 0x80 == 0 ) break;
			shift += 7;
			if( shift > 28 ) {
				inLen = 0;
				transport.close("invalid frame length");
				return null;
			}
		}
		var limit = MAX_FRAME + (recvKey != null ? Nacl.TAG : 0);
		if( n > limit || n < 0 ) {
			inLen = 0;
			transport.close("frame too large (" + n + ")");
			return null;
		}
		if( inLen - p < n ) return null;
		var payload = inBuf.sub(p, n);
		inBuf.blit(0, inBuf, p + n, inLen - p - n);
		inLen -= p + n;
		if( recvKey == null ) return payload;
		var msg = Nacl.secretboxOpen(payload, nonce(recvCtr++), recvKey);
		if( msg == null ) {
			inLen = 0;
			transport.close("frame tampered with or out of order");
			return null;
		}
		return msg;
	}

	public function flush() transport.flush();

	public function close( reason : String ) {
		transport.flush();
		transport.close(reason);
	}
}
