import haxe.io.Bytes;

/**
 * Identidad del jugador en el multijugador (anadido del port), sin cuenta: un secreto de 32 bytes en identite.g55, en la carpeta
 * de datos del juego. Copiar ese archivo a otro PC es llevarse la identidad; quien lo tenga puede jugar como el, asi que no se
 * da a nadie. Para cada servidor se saca del secreto una clave Ed25519 distinta (HMAC-SHA256 con la clave publica del
 * servidor): dos servidores no pueden saber que es el mismo jugador ni usar lo que han visto en otro. El servidor solo guarda la
 * clave publica: cambiar de pseudo no cambia nada.
 * Mas adelante (EternalTwin) una cuenta se podra enlazar a la misma ficha del servidor.
 */
class Identity {

	public static inline var FILE = "identite.g55";
	static inline var LABEL = "g55-id-v1";

	var secret : Bytes;

	function new( secret : Bytes ) {
		this.secret = secret;
	}

	/** la identidad de la carpeta dir; la crea si no hay (y avisa en created) */
	public static function load( dir : String ) : { id : Identity, created : Bool } {
		var path = dir + "/" + FILE;
		if( sys.FileSystem.exists(path) ) {
			try {
				var o : Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
				var s = haxe.crypto.Base64.decode(o.secret);
				if( s.length == 32 ) return { id : new Identity(s), created : false };
			} catch( e : Dynamic ) {}
			// archivo roto: se guarda aparte, no se pisa
			try sys.FileSystem.rename(path, path + ".roto-" + Std.int(Sys.time())) catch( e : Dynamic ) {}
		}
		var id = new Identity(SecureRandom.bytes(32));
		sys.FileSystem.createDirectory(dir);
		var o = { v : 1, secret : haxe.crypto.Base64.encode(id.secret), aviso : "Identite multijoueur de Galaxy 55 : ne la donnez a personne. Copiez ce fichier pour la garder sur un autre PC." };
		sys.io.File.saveContent(path + ".tmp", haxe.Json.stringify(o, null, "\t"));
		if( sys.FileSystem.exists(path) ) sys.FileSystem.deleteFile(path);
		sys.FileSystem.rename(path + ".tmp", path);
		return { id : id, created : true };
	}

	/** identidad sin archivo (pruebas, bots) */
	public static function fromSecret( secret : Bytes ) return new Identity(secret);

	/** claves Ed25519 de esta identidad para el servidor de clave publica serverPk */
	public function keysFor( serverPk : Bytes ) : { pk : Bytes, sk : Bytes } {
		var msg = new haxe.io.BytesBuffer();
		msg.add(Bytes.ofString(LABEL));
		msg.add(serverPk);
		var seed = new haxe.crypto.Hmac(SHA256).make(secret, msg.getBytes());
		return Nacl.signKeyPair(seed);
	}
}
