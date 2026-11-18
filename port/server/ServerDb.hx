/** Planeta guardado en el servidor: su propietario (el descubridor o a quien se lo cedio), la galaxia y el id con que se genera, y
    el sitio de la nave y los accesos (JSON) */
typedef PlanetRow = {
	var gkey : String;
	var owner : String;
	var galaxy : String;
	var pid : Int;
	var seed : Int;
	var biome : String;
	var size : Int;
	var gen : Int;
	var shipAt : String;
	var access : String;
}

/** Ficha de un jugador del servidor */
typedef PlayerRow = {
	var uid : String;
	/** pseudo que pidio la ultima vez */
	var pseudo : String;
	/** nombre que ven los demas (pseudo, o pseudo#2 si otro jugador ya lo usaba) */
	var display : String;
	var created : Float;
	var last : Float;
	/** su partida en este servidor (SaveInfo en JSON; "" hasta que entre en el mundo) */
	var record : String;
}

/**
 * Base de datos del servidor (anadido del port, multijugador): SQLite (sqlite.hdll) en modo WAL, una transaccion por paso con
 * cambios (port/spike/SqliteSpike.hx: tras matar el proceso a mitad, nunca queda a medias). De momento jugadores e identidades;
 * los planetas, cofres e inventarios llegan con el mundo compartido.
 * Lo que da HashLink: getResult de una cadena sale mal (bytes leidos como UTF-16), asi que se lee con next() y sus campos.
 */
class ServerDb {

	var cnx : sys.db.Connection;
	var inTx = false;

	public function new( path : String ) {
		cnx = sys.db.Sqlite.open(path);
		cnx.request("PRAGMA journal_mode=WAL");
		cnx.request("PRAGMA synchronous=NORMAL");
		cnx.request("CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT)");
		cnx.request("CREATE TABLE IF NOT EXISTS players (uid TEXT PRIMARY KEY, pseudo TEXT, display TEXT, created REAL, last REAL, record TEXT, pub TEXT)");
		cnx.request("CREATE UNIQUE INDEX IF NOT EXISTS players_pub ON players(pub)");
		cnx.request("CREATE TABLE IF NOT EXISTS identities (kind TEXT, value TEXT, uid TEXT, PRIMARY KEY(kind, value))");
		cnx.request("CREATE INDEX IF NOT EXISTS identities_uid ON identities(uid)");
		cnx.request("CREATE TABLE IF NOT EXISTS planets (gkey TEXT PRIMARY KEY, owner TEXT, galaxy TEXT, pid INTEGER, seed INTEGER, biome TEXT, size INTEGER, gen INTEGER, shipAt TEXT, access TEXT)");
		cnx.request("CREATE TABLE IF NOT EXISTS planet_edits (gkey TEXT, chunk INTEGER, data BLOB, PRIMARY KEY(gkey, chunk))");
		cnx.request("CREATE TABLE IF NOT EXISTS planet_chests (gkey TEXT, ckey TEXT, data TEXT, PRIMARY KEY(gkey, ckey))");
		cnx.request("CREATE TABLE IF NOT EXISTS planet_loot (gkey TEXT, id INTEGER, data TEXT, PRIMARY KEY(gkey, id))");
		if( meta("version") == null ) setMeta("version", "1");
	}

	inline function q( s : String ) return cnx.quote(s);

	public function begin() {
		if( inTx ) return;
		cnx.startTransaction();
		inTx = true;
	}

	public function commit() {
		if( !inTx ) return;
		cnx.commit();
		inTx = false;
	}

	public function meta( k : String ) : Null<String> {
		var rs = cnx.request("SELECT v FROM meta WHERE k = " + q(k));
		return rs.hasNext() ? Std.string(rs.next().v) : null;
	}

	public function setMeta( k : String, v : String ) {
		cnx.request("INSERT OR REPLACE INTO meta VALUES (" + q(k) + ", " + q(v) + ")");
	}

	/** jugador de una identidad (kind: "ed25519" con la clave publica en hexadecimal; mas adelante "etwin") */
	public function findIdentity( kind : String, value : String ) : Null<String> {
		var rs = cnx.request("SELECT uid FROM identities WHERE kind = " + q(kind) + " AND value = " + q(value));
		return rs.hasNext() ? Std.string(rs.next().uid) : null;
	}

	public function addIdentity( kind : String, value : String, uid : String ) {
		cnx.request("INSERT OR REPLACE INTO identities VALUES (" + q(kind) + ", " + q(value) + ", " + q(uid) + ")");
	}

	/** jugador nuevo con un uid al azar (16 cifras hexadecimales) */
	public function createPlayer( pseudo : String, display : String ) : String {
		var uid = null;
		do uid = SecureRandom.bytes(8).toHex() while( getPlayer(uid) != null );
		var now = Sys.time();
		var pub = null;
		do pub = SecureRandom.bytes(4).toHex() while( uidOfPub(pub) != null );
		cnx.request("INSERT INTO players VALUES (" + q(uid) + ", " + q(pseudo) + ", " + q(display) + ", " + now + ", " + now + ", '', " + q(pub) + ")");
		return uid;
	}

	/** id publico del jugador (8 cifras hexadecimales): lo que ven los demas de el y de su galaxia, nunca su uid */
	public function pubOf( uid : String ) : Null<String> {
		var rs = cnx.request("SELECT pub FROM players WHERE uid = " + q(uid));
		return rs.hasNext() ? Std.string(rs.next().pub) : null;
	}

	public function uidOfPub( pub : String ) : Null<String> {
		var rs = cnx.request("SELECT uid FROM players WHERE pub = " + q(pub));
		return rs.hasNext() ? Std.string(rs.next().uid) : null;
	}

	/** todos los planetas guardados (para los accesos: pocos por jugador) */
	public function allPlanets() : Array<PlanetRow> {
		var out = [];
		for( o in cnx.request("SELECT gkey FROM planets") ) {
			var p = getPlanet(Std.string(o.gkey));
			if( p != null ) out.push(p);
		}
		return out;
	}

	public function getPlayer( uid : String ) : Null<PlayerRow> {
		var rs = cnx.request("SELECT uid, pseudo, display, created, last, record FROM players WHERE uid = " + q(uid));
		if( !rs.hasNext() ) return null;
		var o : Dynamic = rs.next();
		return { uid : Std.string(o.uid), pseudo : Std.string(o.pseudo), display : Std.string(o.display), created : o.created, last : o.last, record : o.record == null ? "" : Std.string(o.record) };
	}

	public function setNames( uid : String, pseudo : String, display : String ) {
		cnx.request("UPDATE players SET pseudo = " + q(pseudo) + ", display = " + q(display) + ", last = " + Sys.time() + " WHERE uid = " + q(uid));
	}

	public function setRecord( uid : String, json : String ) {
		cnx.request("UPDATE players SET record = " + q(json) + " WHERE uid = " + q(uid));
	}

	/** otro jugador (no exceptUid) ya se llama asi */
	public function displayTaken( display : String, exceptUid : String ) : Bool {
		var rs = cnx.request("SELECT uid FROM players WHERE display = " + q(display) + " AND uid <> " + q(exceptUid == null ? "" : exceptUid) + " LIMIT 1");
		return rs.hasNext();
	}

	public function displayOf( uid : String ) : Null<String> {
		var p = getPlayer(uid);
		return p == null ? null : p.display;
	}

	public function playerCount() : Int {
		var rs = cnx.request("SELECT COUNT(*) AS n FROM players");
		return rs.hasNext() ? Std.int(rs.next().n) : 0;
	}


	// ---------------------------------------------------------------- planetas

	/** planeta guardado (gkey = galaxia del descubridor + ":" + id del planeta), null si nadie ha aterrizado aun */
	public function getPlanet( gkey : String ) : Null<PlanetRow> {
		var rs = cnx.request("SELECT gkey, owner, galaxy, pid, seed, biome, size, gen, shipAt, access FROM planets WHERE gkey = " + q(gkey));
		if( !rs.hasNext() ) return null;
		var o : Dynamic = rs.next();
		return { gkey : Std.string(o.gkey), owner : Std.string(o.owner), galaxy : Std.string(o.galaxy), pid : Std.int(o.pid), seed : Std.int(o.seed),
			biome : Std.string(o.biome), size : Std.int(o.size), gen : Std.int(o.gen), shipAt : o.shipAt == null ? "" : Std.string(o.shipAt),
			access : o.access == null ? "" : Std.string(o.access) };
	}

	public function putPlanet( p : PlanetRow ) {
		cnx.request("INSERT OR REPLACE INTO planets VALUES (" + q(p.gkey) + ", " + q(p.owner) + ", " + q(p.galaxy) + ", " + p.pid + ", " + p.seed + ", "
			+ q(p.biome) + ", " + p.size + ", " + p.gen + ", " + q(p.shipAt) + ", " + q(p.access) + ")");
	}

	public function deletePlanet( gkey : String ) {
		cnx.request("DELETE FROM planets WHERE gkey = " + q(gkey));
		cnx.request("DELETE FROM planet_edits WHERE gkey = " + q(gkey));
		cnx.request("DELETE FROM planet_chests WHERE gkey = " + q(gkey));
		cnx.request("DELETE FROM planet_loot WHERE gkey = " + q(gkey));
	}

	/** cambios del terreno de un planeta: pares [celda, valor] de todos sus trozos */
	public function loadEdits( gkey : String ) : Array<Int> {
		var out = [];
		var rs = cnx.request("SELECT data FROM planet_edits WHERE gkey = " + q(gkey));
		for( o in rs ) {
			var b : haxe.io.Bytes = o.data;
			if( b == null ) continue;
			var a = NetZip.unpackInts(b, 1 << 24);
			for( v in a ) out.push(v);
		}
		return out;
	}

	/** reescribe los cambios de un trozo (pares [celda, valor]; vacio = se borra) */
	public function saveEditChunk( gkey : String, chunk : Int, pairs : Array<Int> ) {
		if( pairs.length == 0 ) {
			cnx.request("DELETE FROM planet_edits WHERE gkey = " + q(gkey) + " AND chunk = " + chunk);
			return;
		}
		var s = new StringBuf();
		s.add("INSERT OR REPLACE INTO planet_edits VALUES (" + q(gkey) + ", " + chunk + ", ");
		cnx.addValue(s, NetZip.packInts(pairs));
		s.add(")");
		cnx.request(s.toString());
	}

	/** cantinas de un planeta: clave "x,y,z" -> contenido (Protocol.BlockInventory en JSON) */
	public function loadChests( gkey : String ) : Map<String, String> {
		var out = new Map<String, String>();
		for( o in cnx.request("SELECT ckey, data FROM planet_chests WHERE gkey = " + q(gkey)) ) out.set(Std.string(o.ckey), Std.string(o.data));
		return out;
	}

	/** guarda una cantina (data null = ya no existe) */
	public function saveChest( gkey : String, ckey : String, data : Null<String> ) {
		if( data == null ) cnx.request("DELETE FROM planet_chests WHERE gkey = " + q(gkey) + " AND ckey = " + q(ckey));
		else cnx.request("INSERT OR REPLACE INTO planet_chests VALUES (" + q(gkey) + ", " + q(ckey) + ", " + q(data) + ")");
	}

	/** contenedores del equipo dejado al morir en un planeta (DeathDrops.DeathDropInfo en JSON) */
	public function loadLoot( gkey : String ) : Map<Int, String> {
		var out = new Map<Int, String>();
		for( o in cnx.request("SELECT id, data FROM planet_loot WHERE gkey = " + q(gkey)) ) out.set(Std.int(o.id), Std.string(o.data));
		return out;
	}

	public function saveLoot( gkey : String, id : Int, data : Null<String> ) {
		if( data == null ) cnx.request("DELETE FROM planet_loot WHERE gkey = " + q(gkey) + " AND id = " + id);
		else cnx.request("INSERT OR REPLACE INTO planet_loot VALUES (" + q(gkey) + ", " + id + ", " + q(data) + ")");
	}

	public function close() {
		commit();
		cnx.close();
	}
}
