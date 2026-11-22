import haxe.io.Bytes;

/** Opciones del servidor (serveur.json), las que cambian los gestionnaires (CAdmin) o el archivo a mano */
typedef ServerOptions = {
	var name : String;
	var port : Int;
	/** contrasena: SHA-256 de sal + contrasena, en hexadecimal ("" = sin contrasena) */
	var passwordHash : String;
	var passwordSalt : String;
	var lanVisible : Bool;
	var upnp : Bool;
	/** el equipo cae al morir (SaveInfo.dropOnDeath) */
	var deathDrop : Bool;
	/** ordenes de pruebas (Dev.hx) permitidas: solo para los guiones de port/dev */
	var test : Bool;
}

/**
 * Archivos del servidor (anadido del port, multijugador), en su carpeta (saves/<id>.serveur/ de una partida hospedada, o la
 * carpeta --data de un servidor dedicado):
 * - serveur.json: opciones;
 * - cle_serveur.g55: semilla de la clave Ed25519 del servidor (su huella la recuerdan los clientes);
 * - gestionnaires.txt: "proprietaire <uid> # pseudo" y una linea "<uid> # pseudo" por gestionnaire; se puede editar a mano y
 *   se vuelve a leer al cambiar (el pseudo es solo informativo, cuenta el uid);
 * - bannis.txt: una linea "<uid> # pseudo" por jugador prohibido;
 * - chat.log: todos los mensajes del chat, privados incluidos; serveur.log: conexiones, rechazos, ordenes.
 */
class ServerFiles {

	public var dir(default, null) : String;
	public var options(default, null) : ServerOptions;
	public var ownerUid(default, null) : String;
	public var managers(default, null) = new Map<String, Bool>();
	public var banned(default, null) = new Map<String, Bool>();
	var managersStamp : String = null;
	var bannedStamp : String = null;
	var checkTime = 0.;
	/** pseudos para los comentarios de los archivos */
	public var names : String -> String;

	public function new( dir : String ) {
		this.dir = dir;
		sys.FileSystem.createDirectory(dir);
		options = loadOptions();
		reloadLists(true);
	}

	// ---------------------------------------------------------------- opciones

	function defaults() : ServerOptions {
		return { name : "Galaxy 55", port : 55055, passwordHash : "", passwordSalt : "", lanVisible : true, upnp : false, deathDrop : true, test : false };
	}

	function loadOptions() : ServerOptions {
		var o = defaults();
		var path = dir + "/serveur.json";
		if( sys.FileSystem.exists(path) ) {
			try {
				var j : Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
				if( Std.isOfType(j.name, String) ) o.name = cleanName(j.name);
				if( Std.isOfType(j.port, Int) && j.port > 0 && j.port < 65536 ) o.port = j.port;
				if( Std.isOfType(j.passwordHash, String) ) o.passwordHash = j.passwordHash;
				if( Std.isOfType(j.passwordSalt, String) ) o.passwordSalt = j.passwordSalt;
				if( Std.isOfType(j.lanVisible, Bool) ) o.lanVisible = j.lanVisible;
				if( Std.isOfType(j.upnp, Bool) ) o.upnp = j.upnp;
				if( Std.isOfType(j.deathDrop, Bool) ) o.deathDrop = j.deathDrop;
				if( Std.isOfType(j.test, Bool) ) o.test = j.test;
			} catch( e : Dynamic ) log("serveur.json unreadable (" + e + "): using the default values");
		}
		options = o;
		saveOptions();
		return o;
	}

	public function saveOptions() {
		writeAtomic(dir + "/serveur.json", haxe.Json.stringify(options, null, "\t"));
	}

	public static function cleanName( s : String ) : String {
		s = StringTools.trim(s == null ? "" : s);
		var out = new StringBuf();
		for( i in 0...s.length ) {
			var c = s.charCodeAt(i);
			if( c >= 32 && c != 127 ) out.addChar(c);
		}
		var r = out.toString();
		if( r.length > Msg.SERVER_NAME_MAX ) r = r.substr(0, Msg.SERVER_NAME_MAX);
		return r == "" ? "Galaxy 55" : r;
	}

	public function setPassword( pwd : String ) {
		if( pwd == null || pwd == "" ) {
			options.passwordHash = "";
			options.passwordSalt = "";
		} else {
			options.passwordSalt = SecureRandom.bytes(16).toHex();
			options.passwordHash = haxe.crypto.Sha256.encode(options.passwordSalt + pwd);
		}
		saveOptions();
	}

	public inline function hasPassword() return options.passwordHash != "";

	public function checkPassword( pwd : String ) : Bool {
		if( !hasPassword() ) return true;
		var h = haxe.crypto.Sha256.encode(options.passwordSalt + (pwd == null ? "" : pwd));
		return Nacl.equals(Bytes.ofString(h), 0, Bytes.ofString(options.passwordHash), 0, h.length) && h.length == options.passwordHash.length;
	}

	// ---------------------------------------------------------------- clave del servidor

	/** claves Ed25519 del servidor (la semilla se crea la primera vez) */
	public function serverKeys() : { pk : Bytes, sk : Bytes } {
		var path = dir + "/cle_serveur.g55";
		var seed : Bytes = null;
		if( sys.FileSystem.exists(path) ) {
			try {
				var j : Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
				seed = haxe.crypto.Base64.decode(j.seed);
				if( seed.length != 32 ) seed = null;
			} catch( e : Dynamic ) seed = null;
			if( seed == null ) throw "cle_serveur.g55 unreadable: no new key is made (players would see another server); fix it or delete it";
		}
		if( seed == null ) {
			seed = SecureRandom.bytes(32);
			writeAtomic(path, haxe.Json.stringify({ v : 1, seed : haxe.crypto.Base64.encode(seed), warning : "Server key: never give it to anyone." }, null, "\t"));
		}
		return Nacl.signKeyPair(seed);
	}

	// ---------------------------------------------------------------- gestionnaires y prohibidos

	/** contenido del archivo ("" si no existe): se compara con el de la ultima lectura (la fecha solo tiene segundos) */
	static function stampOf( path : String ) : String {
		try return sys.FileSystem.exists(path) ? sys.io.File.getContent(path) : "" catch( e : Dynamic ) return "";
	}

	/** vuelve a leer los archivos si han cambiado (cada 2 s desde GameServer.pump); true si algo cambio */
	public function poll( dt : Float ) : Bool {
		checkTime -= dt;
		if( checkTime > 0 ) return false;
		checkTime = 2;
		return reloadLists(false);
	}

	function reloadLists( force : Bool ) : Bool {
		var changed = false;
		var mp = dir + "/gestionnaires.txt", bp = dir + "/bannis.txt";
		var ms = stampOf(mp), bs = stampOf(bp);
		if( force || ms != managersStamp ) {
			managersStamp = ms;
			ownerUid = null;
			managers = new Map();
			for( l in readLines(mp) ) {
				var f = l.split(" ");
				// "proprietaire": los archivos escritos antes de pasar el servidor al ingles
				if( (f[0] == "owner" || f[0] == "proprietaire") && f.length > 1 && isUid(f[1]) ) {
					ownerUid = f[1];
					managers.set(f[1], true);
				} else if( isUid(f[0]) ) managers.set(f[0], true);
			}
			changed = true;
		}
		if( force || bs != bannedStamp ) {
			bannedStamp = bs;
			banned = new Map();
			for( l in readLines(bp) ) {
				var f = l.split(" ");
				if( isUid(f[0]) ) banned.set(f[0], true);
			}
			changed = true;
		}
		return changed;
	}

	static function isUid( s : String ) : Bool {
		if( s == null || s.length != 16 ) return false;
		for( i in 0...16 ) {
			var c = s.charCodeAt(i);
			if( !((c >= "0".code && c <= "9".code) || (c >= "a".code && c <= "f".code)) ) return false;
		}
		return true;
	}

	static function readLines( path : String ) : Array<String> {
		if( !sys.FileSystem.exists(path) ) return [];
		var out = [];
		for( l in sys.io.File.getContent(path).split("\n") ) {
			var s = l;
			var h = s.indexOf("#");
			if( h >= 0 ) s = s.substr(0, h);
			s = StringTools.trim(s);
			if( s != "" ) out.push(s);
		}
		return out;
	}

	function nameOf( uid : String ) : String {
		var n = names == null ? null : names(uid);
		return n == null ? "?" : n;
	}

	public function setOwner( uid : String ) {
		ownerUid = uid;
		managers.set(uid, true);
		saveManagers();
	}

	public function setManager( uid : String, on : Bool ) {
		if( uid == ownerUid ) return;
		if( on ) managers.set(uid, true) else managers.remove(uid);
		saveManagers();
	}

	public function setBanned( uid : String, on : Bool ) {
		if( uid == ownerUid ) return;
		if( on ) banned.set(uid, true) else banned.remove(uid);
		var s = new StringBuf();
		s.add("# Players banned from the server: one id per line (the nickname after # is only a reminder).\n");
		for( u in banned.keys() ) s.add(u + " # " + nameOf(u) + "\n");
		writeAtomic(dir + "/bannis.txt", s.toString());
		bannedStamp = stampOf(dir + "/bannis.txt");
	}

	function saveManagers() {
		var s = new StringBuf();
		s.add("# Server managers. \"owner <id>\": the owner (can only be removed in this file).\n");
		s.add("# One id per line; the nickname after # is only a reminder.\n");
		if( ownerUid != null ) s.add("owner " + ownerUid + " # " + nameOf(ownerUid) + "\n");
		for( u in managers.keys() ) if( u != ownerUid ) s.add(u + " # " + nameOf(u) + "\n");
		writeAtomic(dir + "/gestionnaires.txt", s.toString());
		managersStamp = stampOf(dir + "/gestionnaires.txt");
	}

	// ---------------------------------------------------------------- registros

	static function now() : String return DateTools.format(Date.now(), "%Y-%m-%d %H:%M:%S");

	public function log( s : String ) {
		append("serveur.log", now() + " " + s);
		if( echo ) Sys.println(s);
	}

	/** escribir tambien el registro en la consola (servidor dedicado) */
	public var echo = false;

	public function chat( s : String ) append("chat.log", now() + " " + s);

	function append( file : String, line : String ) {
		try {
			var o = sys.io.File.append(dir + "/" + file, false);
			o.writeString(line + "\n");
			o.close();
		} catch( e : Dynamic ) {}
	}

	public static function writeAtomic( path : String, content : String ) {
		sys.io.File.saveContent(path + ".tmp", content);
		if( sys.FileSystem.exists(path) ) sys.FileSystem.deleteFile(path);
		sys.FileSystem.rename(path + ".tmp", path);
	}
}
