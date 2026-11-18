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
		cnx.request("CREATE TABLE IF NOT EXISTS players (uid TEXT PRIMARY KEY, pseudo TEXT, display TEXT, created REAL, last REAL, record TEXT)");
		cnx.request("CREATE TABLE IF NOT EXISTS identities (kind TEXT, value TEXT, uid TEXT, PRIMARY KEY(kind, value))");
		cnx.request("CREATE INDEX IF NOT EXISTS identities_uid ON identities(uid)");
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
		cnx.request("INSERT INTO players VALUES (" + q(uid) + ", " + q(pseudo) + ", " + q(display) + ", " + now + ", " + now + ", '')");
		return uid;
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

	public function close() {
		commit();
		cnx.close();
	}
}
