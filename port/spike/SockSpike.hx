import sys.net.Socket;
import sys.net.Host;
import haxe.io.Bytes;

/**
 * Prueba de sockets de HashLink para el multijugador (anadido del port): servidor y cliente TCP no bloqueantes en el mismo
 * proceso, conexion en un hilo, mensajes a 20 Hz, envio de 4 MB por partes (Blocked) y UDP. Solo 127.0.0.1 (sin cortafuegos).
 */
class SockSpike {

	static var PORT = 55077;

	static function now() return haxe.Timer.stamp();

	static function main() {
		var server = new Socket();
		server.bind(new Host("127.0.0.1"), PORT);
		server.listen(8);
		server.setBlocking(false);

		var connected : Socket = null;
		var connectError : String = null;
		var lock = new sys.thread.Lock();
		sys.thread.Thread.create(function() {
			try {
				var c = new Socket();
				c.connect(new Host("127.0.0.1"), PORT);
				connected = c;
			} catch( e : Dynamic ) connectError = Std.string(e);
			lock.release();
		});

		var peer : Socket = null;
		var t0 = now();
		while( peer == null && now() - t0 < 5 ) {
			peer = server.accept();
			if( peer == null ) Sys.sleep(0.001);
		}
		lock.wait(5);
		if( peer == null || connected == null ) fail("accept/connect: " + connectError);
		var client = connected;
		client.setBlocking(false);
		client.setFastSend(true);
		peer.setBlocking(false);
		peer.setFastSend(true);
		Sys.println("conexion ok en " + Math.round((now() - t0) * 1000) + " ms");

		var cin = new Buf(), pin = new Buf();
		var sentC = 0, sentP = 0, gotC = 0, gotP = 0;
		var t1 = now(), next = t1;
		while( now() - t1 < 2 ) {
			if( now() >= next ) {
				next += 0.05;
				sendAll(client, frame(Bytes.ofString("estado " + sentC++)));
				sendAll(peer, frame(Bytes.ofString("estados " + sentP++)));
			}
			pin.pull(peer);
			cin.pull(client);
			while( pin.frame() != null ) gotP++;
			while( cin.frame() != null ) gotC++;
			Socket.select([peer, client], null, null, 0.005);
		}
		Sys.println('20 Hz: cliente envio $sentC (servidor recibio $gotP), servidor envio $sentP (cliente recibio $gotC)');
		if( gotP < sentC - 1 || gotC < sentP - 1 ) fail("mensajes perdidos");

		var big = Bytes.alloc(4 * 1024 * 1024);
		var seed = 12345;
		for( i in 0...big.length ) {
			seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
			big.set(i, seed >> 16);
		}
		var want = haxe.crypto.Adler32.make(big);
		var out = frame(big);
		var pos = 0, blocked = 0, partial = 0;
		var t2 = now();
		var got : Bytes = null;
		while( got == null && now() - t2 < 10 ) {
			if( pos < out.length ) {
				try {
					var n = peer.output.writeBytes(out, pos, out.length - pos);
					if( n < out.length - pos ) partial++;
					pos += n;
				} catch( e : haxe.io.Error ) {
					if( e != Blocked ) throw e;
					blocked++;
				}
			}
			cin.pull(client);
			got = cin.frame();
			if( got == null ) Socket.select([client], pos < out.length ? [peer] : null, null, 0.005);
		}
		if( got == null ) fail("4 MB no llegaron");
		var ok = haxe.crypto.Adler32.make(got) == want;
		Sys.println('4 MB: ${Math.round((now() - t2) * 1000)} ms, envios parciales $partial, Blocked $blocked, adler ' + (ok ? "ok" : "MAL"));
		if( !ok ) fail("datos corruptos");

		client.close();
		var t3 = now(), eof = false;
		while( !eof && now() - t3 < 2 ) {
			try {
				var b = Bytes.alloc(16);
				peer.input.readBytes(b, 0, 16);
			} catch( e : haxe.io.Eof ) {
				eof = true;
			} catch( e : Dynamic ) {
				Sys.sleep(0.002);
			}
		}
		Sys.println("cierre del cliente visto por el servidor: " + (eof ? "Eof" : "NO"));
		peer.close();
		server.close();

		var u1 = new sys.net.UdpSocket(), u2 = new sys.net.UdpSocket();
		u1.bind(new Host("127.0.0.1"), PORT);
		u1.setBlocking(false);
		u2.setBroadcast(true);
		var addr = new sys.net.Address();
		addr.host = new Host("127.0.0.1").ip;
		addr.port = PORT;
		var probe = Bytes.ofString("G55?");
		u2.sendTo(probe, 0, probe.length, addr);
		var rb = Bytes.alloc(64), from = new sys.net.Address(), n = -1;
		var t4 = now();
		while( n < 0 && now() - t4 < 2 ) {
			try n = u1.readFrom(rb, 0, 64, from) catch( e : Dynamic ) Sys.sleep(0.002);
		}
		Sys.println("UDP: " + (n == 4 && rb.getString(0, 4) == "G55?" ? "ok" : "MAL (" + n + ")"));
		u1.close();
		u2.close();

		var bad = new Socket();
		var t5 = now(), refused = false;
		try bad.connect(new Host("127.0.0.1"), PORT + 1) catch( e : Dynamic ) refused = true;
		Sys.println("conexion rechazada: " + (refused ? "excepcion" : "NO") + " en " + Math.round((now() - t5) * 1000) + " ms");
		Sys.println("FIN OK");
	}

	static function frame( b : Bytes ) : Bytes {
		var o = Bytes.alloc(b.length + 4);
		o.setInt32(0, b.length);
		o.blit(4, b, 0, b.length);
		return o;
	}

	static function sendAll( s : Socket, b : Bytes ) {
		var pos = 0;
		while( pos < b.length ) {
			try pos += s.output.writeBytes(b, pos, b.length - pos) catch( e : haxe.io.Error ) {
				if( e != Blocked ) throw e;
				Sys.sleep(0.001);
			}
		}
	}

	static function fail( msg : String ) {
		Sys.println("FALLO: " + msg);
		Sys.exit(1);
	}
}

private class Buf {
	var data = Bytes.alloc(1 << 16);
	var len = 0;
	var tmp = Bytes.alloc(1 << 16);

	public function new() {}

	public function pull( s : Socket ) {
		while( true ) {
			var n = 0;
			try n = s.input.readBytes(tmp, 0, tmp.length) catch( e : haxe.io.Error ) {
				if( e == Blocked ) return;
				throw e;
			}
			if( n <= 0 ) return;
			if( len + n > data.length ) {
				var nd = Bytes.alloc(Std.int(Math.max(data.length * 2, len + n)));
				nd.blit(0, data, 0, len);
				data = nd;
			}
			data.blit(len, tmp, 0, n);
			len += n;
		}
	}

	public function frame() : Null<Bytes> {
		if( len < 4 ) return null;
		var n = data.getInt32(0);
		if( len < 4 + n ) return null;
		var out = data.sub(4, n);
		data.blit(0, data, 4 + n, len - 4 - n);
		len -= 4 + n;
		return out;
	}
}
