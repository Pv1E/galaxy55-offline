import haxe.io.Bytes;

/**
 * Prueba de SQLite en HashLink para el multijugador (anadido del port): WAL, ritmo de commits, blobs reales y coherencia tras
 * matar el proceso a mitad de una transaccion (TerminateProcess). Invariante: inventario + suelo = 1000 siempre.
 */
class SqliteSpike {

	static function open( file : String ) {
		var c = sys.db.Sqlite.open(file);
		c.request("PRAGMA journal_mode=WAL");
		c.request("PRAGMA synchronous=NORMAL");
		c.request("CREATE TABLE IF NOT EXISTS stock (k TEXT PRIMARY KEY, n INTEGER)");
		c.request("CREATE TABLE IF NOT EXISTS edits (k TEXT PRIMARY KEY, data BLOB)");
		c.request("INSERT OR IGNORE INTO stock VALUES ('inv', 1000), ('suelo', 0), ('tick', 0)");
		return c;
	}

	static function step( c : sys.db.Connection, blob : Bytes, i : Int ) {
		c.startTransaction();
		var d = (i % 7) - 3;
		c.request("UPDATE stock SET n = n - " + d + " WHERE k = 'inv'");
		blob.set(i % blob.length, i & 255);
		var s = new StringBuf();
		s.add("INSERT OR REPLACE INTO edits VALUES ('p" + (i % 4) + "', ");
		c.addValue(s, blob);
		s.add(")");
		c.request(s.toString());
		c.request("UPDATE stock SET n = n + " + d + " WHERE k = 'suelo'");
		c.request("UPDATE stock SET n = n + 1 WHERE k = 'tick'");
		c.commit();
	}

	static function check( file : String ) : String {
		var c = sys.db.Sqlite.open(file);
		var ic : String = Std.string(Reflect.field(c.request("PRAGMA integrity_check").next(), "integrity_check"));
		if( !c.request("SELECT name FROM sqlite_master WHERE name = 'stock'").hasNext() ) {
			c.close();
			return '$ic vacia (matado antes de crear las tablas)';
		}
		var inv = c.request("SELECT n FROM stock WHERE k = 'inv'").getIntResult(0);
		var suelo = c.request("SELECT n FROM stock WHERE k = 'suelo'").getIntResult(0);
		var tick = c.request("SELECT n FROM stock WHERE k = 'tick'").getIntResult(0);
		var rs = c.request("SELECT data FROM edits WHERE k = 'p0'");
		var blobLen = rs.hasNext() ? (rs.next().data : Bytes).length : 0;
		c.close();
		return '$ic inv+suelo=${inv + suelo} tick=$tick blob=$blobLen';
	}

	static function main() {
		var args = Sys.args();
		if( args[0] == "write" ) {
			var c = open(args[1]);
			var blob = Bytes.alloc(64 * 1024);
			var i = 0;
			while( true ) step(c, blob, i++);
		}
		var dir = args.length > 0 ? args[0] : "port/out/sqlite_spike";
		sys.FileSystem.createDirectory(dir);
		var file = dir + "/rate.sqlite";
		for( f in [file, file + "-wal", file + "-shm"] ) if( sys.FileSystem.exists(f) ) sys.FileSystem.deleteFile(f);
		var c = open(file);
		var blob = Bytes.alloc(64 * 1024);
		var t0 = haxe.Timer.stamp(), n = 0;
		while( haxe.Timer.stamp() - t0 < 2 ) step(c, blob, n++);
		Sys.println("commits por segundo (64 KB de blob): " + Math.round(n / 2));
		c.close();
		Sys.println("tras cerrar: " + check(file));

		var hl = Sys.programPath();
		var exe = Sys.getEnv("HL_EXE");
		if( exe == null ) exe = "hl";
		var bad = 0;
		for( k in 0...10 ) {
			var f = dir + "/kill" + k + "_" + Std.random(1000000) + ".sqlite";
			var p = new sys.io.Process(exe, [hl, "write", f]);
			Sys.sleep(0.3 + Math.random() * 0.7);
			p.kill();
			p.exitCode(true);
			p.close();
			var r = check(f);
			var ok = r.indexOf("ok inv+suelo=1000") == 0 || r.indexOf("ok vacia") == 0;
			if( !ok ) bad++;
			Sys.println("matado " + k + ": " + r + (ok ? "" : "  <-- INCOHERENTE"));
		}
		Sys.println(bad == 0 ? "FIN OK" : "FALLO: " + bad + " bases incoherentes");
	}
}
