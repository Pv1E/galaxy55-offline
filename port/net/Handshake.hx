import haxe.io.Bytes;

/**
 * Calculos del saludo del multijugador (anadido del port), iguales en el cliente y el servidor:
 * 1. CHello (sin cifrar): clave X25519 efimera del cliente;
 * 2. SServerHello (sin cifrar): clave X25519 efimera del servidor y su clave Ed25519 de siempre, con la firma de la
 *    transcripcion T = SHA-512("g55-hs-v1", efimera del cliente, efimera del servidor, clave del servidor). El cliente comprueba
 *    la firma y la huella que recordaba de ese servidor;
 * 3. los dos sacan del secreto X25519 una clave por sentido (keys) y desde aqui todo va cifrado (Channel.setKeys);
 * 4. CLogin: la clave publica del jugador para este servidor (Identity.keysFor) y su firma de loginMessage(T). Quien escucha
 *    la red no ve nada; quien no tiene el archivo de identidad no puede firmar.
 */
class Handshake {

	public static function ephemeral() : { pk : Bytes, sk : Bytes } {
		var sk = SecureRandom.bytes(32);
		return { pk : Nacl.scalarmultBase(sk), sk : sk };
	}

	public static function transcript( clientEph : Bytes, serverEph : Bytes, serverPk : Bytes ) : Bytes {
		var b = new haxe.io.BytesBuffer();
		b.add(Bytes.ofString("g55-hs-v1"));
		b.add(clientEph);
		b.add(serverEph);
		b.add(serverPk);
		return Nacl.sha512(b.getBytes());
	}

	/** claves cliente->servidor y servidor->cliente a partir del intercambio X25519 */
	public static function keys( mySk : Bytes, theirPk : Bytes, t : Bytes ) : { c2s : Bytes, s2c : Bytes } {
		var k = Nacl.boxBeforenm(theirPk, mySk);
		function derive( label : String ) {
			var b = new haxe.io.BytesBuffer();
			b.add(k);
			b.add(Bytes.ofString(label));
			b.add(t);
			return Nacl.sha512(b.getBytes()).sub(0, 32);
		}
		return { c2s : derive("c2s"), s2c : derive("s2c") };
	}

	public static function loginMessage( t : Bytes ) : Bytes {
		var b = new haxe.io.BytesBuffer();
		b.add(t);
		b.add(Bytes.ofString("g55-login"));
		return b.getBytes();
	}

	/** huella corta de una clave publica de servidor (la que se ensena y se recuerda) */
	public static function fingerprint( pk : Bytes ) : String {
		return haxe.crypto.Sha256.make(pk).toHex().substr(0, 16);
	}
}

/** Limite de ritmo: rate fichas por segundo, como mucho burst guardadas */
class TokenBucket {
	var rate : Float;
	var burst : Float;
	var tokens : Float;
	var last : Float;

	public function new( rate : Float, burst : Float ) {
		this.rate = rate;
		this.burst = burst;
		tokens = burst;
		last = haxe.Timer.stamp();
	}

	/** gasta una ficha; false si no quedan (demasiado deprisa) */
	public function take( n = 1. ) : Bool {
		var now = haxe.Timer.stamp();
		tokens = Math.min(burst, tokens + (now - last) * rate);
		last = now;
		if( tokens < n ) return false;
		tokens -= n;
		return true;
	}
}
