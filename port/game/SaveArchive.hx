import Common;
import SaveData.SaveInfo;
import SaveData.UniPlanet;

/** error al leer una partida guardada: que parte y que tiene mal (la lista la muestra como ilegible) */
class SaveError {
	public var msg(default, null) : String;
	public function new( msg : String ) this.msg = msg;
	public function toString() return msg;
}

/** una entrada del zip: su nombre, como va (0 tal cual, 8 deflate), su CRC-32, sus tamanos y donde empiezan sus datos */
typedef ZipItem = { name : String, method : Int, crc : Int, csize : Int, usize : Int, offset : Int };

/** una entrada para SaveArchive.zip: datos sin comprimir (los comprime si deflate) o ya comprimidos de otro archivo (raw) */
typedef OutItem = { name : String, ?data : haxe.io.Bytes, ?deflate : Bool, ?raw : { item : ZipItem, from : haxe.io.Bytes } };

/** tabla de nombres de un archivo: cada nombre una vez, en el orden en que aparece */
private class NameTable {
	public var names(default, null) : Array<String> = [];
	var map = new Map<String, Int>();
	public function new() {}
	public function pos( name : String ) : Int {
		var p = map.get(name);
		if( p == null ) {
			p = names.length;
			names.push(name);
			map.set(name, p);
		}
		return p;
	}
}

/**
 * Partida guardada en un archivo (anadido del port): saves/<id>.g55, un zip con
 *   meta.json            lo de la lista de partidas (SaveArchive.meta: nombre, fechas, versiones del juego, tiempo jugado, planeta
 *                        actual, modo, espacio, oldGeneration), para no tener que leer lo demas
 *   thumb.png            la miniatura (tal cual: ya es un PNG)
 *   game.json            el resto de la partida, sin espacios, con las tablas de nombres blocks (SaveNames) y charges: en las
 *                        casillas (inv, chests, storage, deathDrops: k y c) y en tuto.spots va la posicion en esas tablas; el
 *                        robot comerciante usa "b:<nombre>" y "c:<nombre>" (contracts.done / abandoned siguen siendo posiciones
 *                        en el tablero del periodo, que cambia entero cada periodo)
 *   planets/current.bin  cambios del terreno del planeta actual, planets/<id>.bin los de cada planeta visitado: una cabecera
 *                        (semilla, bioma, tamano, version del generador, donde se dejo la nave, nivel del mar e inundacion) y las
 *                        celdas en orden (planetBytes)
 *   ship.bin             cambios de la nave (shipEdits), igual sin cabecera
 *   shipdata.bin         la nave del hangar (shipData) con la posicion en la tabla de cada celda
 * Se escribe entero cada vez (unos ms) y sin pisar el anterior hasta el final (writeFile). La lista de partidas solo lee
 * meta.json y la miniatura (readMeta, readThumb).
 */
class SaveArchive {

	/** formato de los archivos (meta.json) */
	public static inline var FORMAT = 1;
	static inline var CELLS = 1;

	// ---------------------------------------------------------------- zip

	static inline var LOCAL = 0x04034B50;
	static inline var CENTRAL = 0x02014B50;
	static inline var END = 0x06054B50;

	/**
	 * Las entradas de un zip, leidas de su directorio central (al final del archivo). Error si el archivo no acaba como un zip
	 * (cortado al escribirlo) o el directorio no cuadra
	 */
	public static function items( b : haxe.io.Bytes ) : Array<ZipItem> {
		if( b == null || b.length < 22 ) throw new SaveError("archivo vacio o cortado");
		var e = b.length - 22;
		var stop = e - 65535 > 0 ? e - 65535 : 0;
		while( e >= stop && b.getInt32(e) != END ) e--;
		if( e < stop ) throw new SaveError("no termina como un zip (cortado)");
		var n = b.getUInt16(e + 10), size = b.getInt32(e + 12), at = b.getInt32(e + 16);
		if( at < 0 || size < 0 || at + size > e ) throw new SaveError("directorio del zip fuera del archivo");
		var out = [];
		for( i in 0...n ) {
			if( at + 46 > e || b.getInt32(at) != CENTRAL ) throw new SaveError("directorio del zip mal formado");
			var method = b.getUInt16(at + 10), crc = b.getInt32(at + 16), csize = b.getInt32(at + 20), usize = b.getInt32(at + 24);
			var nl = b.getUInt16(at + 28), xl = b.getUInt16(at + 30), cl = b.getUInt16(at + 32), local = b.getInt32(at + 42);
			var name = b.getString(at + 46, nl);
			at += 46 + nl + xl + cl;
			if( local < 0 || local + 30 > b.length || b.getInt32(local) != LOCAL ) throw new SaveError(name + ": cabecera perdida");
			var offset = local + 30 + b.getUInt16(local + 26) + b.getUInt16(local + 28);
			if( csize < 0 || offset + csize > b.length ) throw new SaveError(name + ": datos cortados");
			out.push({ name : name, method : method, crc : crc, csize : csize, usize : usize, offset : offset });
		}
		return out;
	}

	public static function find( items : Array<ZipItem>, name : String ) : ZipItem {
		for( i in items ) if( i.name == name ) return i;
		return null;
	}

	/** los datos de una entrada, descomprimidos y con su CRC comprobado (Reader.unzip no lo hace) */
	public static function data( b : haxe.io.Bytes, it : ZipItem ) : haxe.io.Bytes {
		var raw = b.sub(it.offset, it.csize), out : haxe.io.Bytes;
		switch( it.method ) {
		case 0:
			out = raw;
		case 8:
			out = haxe.io.Bytes.alloc(it.usize);
			var u = new haxe.zip.Uncompress(-15);
			var r = try u.execute(raw, 0, out, 0) catch( e : Dynamic ) null;
			u.close();
			if( r == null || r.write != it.usize ) throw new SaveError(it.name + ": no se puede descomprimir");
		default:
			throw new SaveError(it.name + ": compresion " + it.method + " desconocida");
		}
		if( out.length != it.usize || haxe.crypto.Crc32.make(out) != it.crc ) throw new SaveError(it.name + ": CRC distinto (danado)");
		return out;
	}

	/** el archivo es un zip entero y cada entrada tiene su CRC (para elegir que recuperar: writeFile, recover) */
	public static function check( b : haxe.io.Bytes ) : Bool {
		try {
			var l = items(b);
			if( find(l, "meta.json") == null || find(l, "game.json") == null ) return false;
			for( it in l ) data(b, it);
			return true;
		} catch( e : Dynamic ) {
			return false;
		}
	}

	static function zip( list : Array<OutItem>, time : Date ) : haxe.io.Bytes {
		var out = new haxe.io.BytesOutput();
		var w = new haxe.zip.Writer(out);
		var entries = new haxe.ds.List<haxe.zip.Entry>();
		for( o in list ) {
			var e : haxe.zip.Entry;
			if( o.raw != null ) {
				var it = o.raw.item;
				e = { fileName : o.name, fileSize : it.usize, fileTime : time, compressed : it.method == 8, dataSize : it.csize,
					data : o.raw.from.sub(it.offset, it.csize), crc32 : it.crc };
			} else {
				e = { fileName : o.name, fileSize : o.data.length, fileTime : time, compressed : false, dataSize : o.data.length,
					data : o.data, crc32 : haxe.crypto.Crc32.make(o.data) };
				if( o.deflate ) haxe.zip.Tools.compress(e, 6);
			}
			entries.add(e);
		}
		w.write(entries);
		return out.getBytes();
	}

	// ---------------------------------------------------------------- celdas cambiadas (planetas y nave)

	static function writeVar( o : haxe.io.BytesOutput, v : Int ) {
		while( v >= 0x80 || v < 0 ) {
			o.writeByte((v & 0x7F) | 0x80);
			v >>>= 7;
		}
		o.writeByte(v);
	}

	static function readVar( i : haxe.io.BytesInput ) : Int {
		var v = 0, shift = 0;
		while( true ) {
			var c = i.readByte();
			v |= (c & 0x7F) << shift;
			if( c < 0x80 ) return v;
			shift += 7;
			if( shift > 28 ) throw new SaveError("numero mal formado");
		}
	}

	static function writeStr( o : haxe.io.BytesOutput, s : String ) {
		var b = haxe.io.Bytes.ofString(s == null ? "" : s);
		writeVar(o, b.length);
		o.write(b);
	}

	static function readStr( i : haxe.io.BytesInput ) : String {
		var n = readVar(i);
		return n == 0 ? null : i.readString(n);
	}

	/**
	 * Celdas cambiadas (pares [celda, bloque | nivel del agua << 16] de World.editsFlat; las claves negativas son del mar y van en
	 * la cabecera del planeta): cuantas, y por cada una en orden la distancia a la anterior, la posicion de su bloque en la tabla
	 * (por 2, mas 1 si lleva nivel de agua) y el nivel
	 */
	static function writeCells( o : haxe.io.BytesOutput, edits : Array<Int>, table : NameTable ) {
		var cells = new Map<Int, Int>();
		var i = 0;
		if( edits != null )
			while( i + 1 < edits.length ) {
				if( edits[i] >= 0 ) cells.set(edits[i], edits[i + 1]);
				i += 2;
			}
		var keys = [for( k in cells.keys() ) k];
		keys.sort(function(a, b) return a - b);
		writeVar(o, keys.length);
		var prev = 0;
		for( k in keys ) {
			var v = cells.get(k), lvl = v >>> 16;
			writeVar(o, k - prev);
			prev = k;
			writeVar(o, (table.pos(SaveNames.nameOfIndex(v & 0xFFFF)) << 1) | (lvl > 0 ? 1 : 0));
			if( lvl > 0 ) o.writeByte(lvl);
		}
	}

	/** las celdas de writeCells en pares [celda, posicion en la tabla | nivel << 16] (las posiciones se cambian despues por bloques) */
	static function readCells( i : haxe.io.BytesInput, out : Array<Int> ) {
		var n = readVar(i), k = 0;
		for( _ in 0...n ) {
			k += readVar(i);
			var v = readVar(i);
			var lvl = v & 1 != 0 ? i.readByte() : 0;
			out.push(k);
			out.push((v >> 1) | (lvl << 16));
		}
	}

	/** nivel del mar y su contador de inundacion de unos cambios (World.SEA_LEVEL = -1, SEA_FLOOD = -2); null si no los hay */
	static function seaOf( edits : Array<Int> ) : { level : Int, flood : Int } {
		var level : Null<Int> = null, flood = 0, i = 0;
		if( edits != null )
			while( i + 1 < edits.length ) {
				if( edits[i] == -1 ) level = edits[i + 1];
				else if( edits[i] == -2 ) flood = edits[i + 1];
				i += 2;
			}
		return level == null ? null : { level : level, flood : flood };
	}

	/** un planeta: cabecera y celdas (ver la clase) */
	static function planetBytes( p : { id : Int, seed : Null<Int>, biome : String, size : Null<Int>, genVersion : Null<Int>, shipAt : { x : Int, y : Int }, edits : Array<Int> }, table : NameTable ) : haxe.io.Bytes {
		var o = new haxe.io.BytesOutput();
		o.writeByte(CELLS);
		o.writeInt32(p.id);
		o.writeByte(p.seed != null ? 1 : 0);
		o.writeInt32(p.seed != null ? p.seed : 0);
		writeStr(o, p.biome);
		writeVar(o, p.size != null ? p.size : 0);
		writeVar(o, SaveData.genVersion(p.genVersion));
		o.writeByte(p.shipAt != null ? 1 : 0);
		o.writeInt32(p.shipAt != null ? p.shipAt.x : 0);
		o.writeInt32(p.shipAt != null ? p.shipAt.y : 0);
		var sea = seaOf(p.edits);
		o.writeByte(sea != null ? 1 : 0);
		o.writeInt32(sea != null ? sea.level : 0);
		o.writeInt32(sea != null ? sea.flood : 0);
		writeCells(o, p.edits, table);
		return o.getBytes();
	}

	static function readPlanet( name : String, b : haxe.io.Bytes ) {
		try {
			var i = new haxe.io.BytesInput(b);
			if( i.readByte() != CELLS ) throw "formato desconocido";
			var id = i.readInt32();
			var hasSeed = i.readByte() == 1, seed = i.readInt32();
			var biome = readStr(i), size = readVar(i), genVersion = readVar(i);
			var hasShip = i.readByte() == 1, sx = i.readInt32(), sy = i.readInt32();
			var hasSea = i.readByte() == 1, level = i.readInt32(), flood = i.readInt32();
			var edits = [];
			readCells(i, edits);
			if( hasSea ) edits = edits.concat([-1, level, -2, flood]);
			return { id : id, seed : hasSeed ? (seed : Null<Int>) : null, biome : biome, size : size > 0 ? (size : Null<Int>) : null,
				genVersion : genVersion, shipAt : hasShip ? { x : sx, y : sy } : null, edits : edits };
		} catch( e : SaveError ) {
			throw new SaveError(name + ": " + e.msg);
		} catch( e : Dynamic ) {
			throw new SaveError(name + ": " + Std.string(e));
		}
	}

	// ---------------------------------------------------------------- partida -> archivo

	/** lo que lee la lista de partidas (SaveData.list): sin abrir game.json */
	public static function meta( info : SaveInfo ) : Dynamic {
		var old = info.genVersion != null && info.genVersion < gen.Generator.VERSION;
		if( info.uni != null && info.uni.planets != null )
			for( p in info.uni.planets ) if( SaveData.genVersion(p.genVersion) < gen.Generator.VERSION ) old = true;
		return {
			format : FORMAT, name : info.name, created : info.created, saved : info.saved, createdWith : info.createdWith,
			savedWith : info.savedWith, playSeconds : info.playSeconds, seed : info.seed, biome : info.biome,
			sizeChunks : info.sizeChunks, creative : info.creative == true, survival : info.survival == true,
			dropOnDeath : info.dropOnDeath != false, space : info.uni != null && info.uni.space == true, inMother : info.inMother != null,
			oldGeneration : old,
		};
	}

	/**
	 * La partida en un archivo. thumb: la miniatura nueva, o null para dejar la del archivo `keep` (el que hay en disco: las
	 * guardadas automaticas no la cambian)
	 */
	public static function encode( info : SaveInfo, thumb : haxe.io.Bytes, ?keep : haxe.io.Bytes ) : haxe.io.Bytes {
		var table = new NameTable(), charges = new NameTable();
		table.pos("BEmpty");
		inline function bpos( k : Int ) return table.pos(SaveNames.nameOfIndex(k));
		inline function cpos( c : Int ) return charges.pos(SaveNames.chargeName(c));
		function slots( t : Protocol.BlockInventory ) : Array<Dynamic> return t == null ? null : [for( s in t ) s == null ? null : { k : bpos(s.k), n : s.n }];
		function ch( c : Protocol.UserCharges ) : Array<Dynamic> return c == null ? null : [for( x in c ) { c : cpos(x.c), n : x.n }];
		var list : Array<OutItem> = [];
		var g : Dynamic = Reflect.copy(info);
		for( f in ["id", "edits", "shipEdits", "shipData", "hangar", "mothership", "unknownCharges", "listOnly", "unreadable", "inSpace", "oldGeneration", "legacy"] )
			Reflect.deleteField(g, f);
		if( info.inv != null ) g.inv = { maxWeight : info.inv.maxWeight, t : slots(info.inv.t), charges : ch(info.inv.charges) };
		if( info.chests != null ) g.chests = [for( c in info.chests ) { key : c.key, t : slots(c.t) }];
		if( info.storage != null ) g.storage = { t : slots(info.storage.t), charges : ch(info.storage.charges) };
		if( info.deathDrops != null )
			g.deathDrops = [for( d in info.deathDrops ) { id : d.id, key : d.key, x : d.x, y : d.y, z : d.z, t : slots(d.t), charges : ch(d.charges) }];
		if( info.market != null )
			g.market = { time : info.market.time, items : [for( it in info.market.items ) {
				var key = it.key;
				var n = key != null && key.length > 1 ? Std.parseInt(key.substr(1)) : null;
				if( n != null && key.charAt(0) == "b" ) key = "b:" + SaveNames.nameOfIndex(n);
				else if( n != null && key.charAt(0) == "c" ) key = "c:" + SaveNames.chargeName(n);
				{ key : key, bought : it.bought, sold : it.sold };
			}] };
		if( info.tuto != null )
			g.tuto = { step : info.tuto.step, spots : info.tuto.spots == null ? null : [for( i in 0...info.tuto.spots.length ) i & 3 == 3 ? bpos(info.tuto.spots[i]) : info.tuto.spots[i]] };
		// planeta actual y visitados: sus celdas van en planets/; en game.json, el resto de cada uno
		list.push({ name : "planets/current.bin", deflate : true, data : planetBytes({ id : info.uni != null ? info.uni.planetId : -1, seed : info.seed,
			biome : info.biome, size : info.sizeChunks, genVersion : info.genVersion, shipAt : info.shipAt, edits : info.edits }, table) });
		if( info.uni != null ) {
			var u : Dynamic = Reflect.copy(info.uni);
			u.planets = [for( p in info.uni.planets ) { id : p.id, shipAt : p.shipAt, genVersion : p.genVersion, seed : p.seed, biome : p.biome, size : p.size }];
			g.uni = u;
			for( p in info.uni.planets ) list.push({ name : "planets/" + p.id + ".bin", deflate : true, data : planetBytes(p, table) });
		}
		if( info.shipEdits != null && info.shipEdits.length > 0 ) {
			var o = new haxe.io.BytesOutput();
			o.writeByte(CELLS);
			writeCells(o, info.shipEdits, table);
			list.push({ name : "ship.bin", deflate : true, data : o.getBytes() });
		}
		if( info.shipData != null ) {
			var raw = try haxe.zip.Uncompress.run(haxe.crypto.Base64.decode(info.shipData)) catch( e : Dynamic ) null;
			if( raw != null && raw.length >= 3 ) {
				var cells = raw.get(0) * raw.get(1) * raw.get(2);
				for( i in 0...cells ) {
					var p = 3 + i * 2;
					if( p + 1 >= raw.length ) break;
					var id = raw.get(p) | (raw.get(p + 1) << 8);
					var n = bpos(id);
					raw.set(p, n & 0xFF);
					raw.set(p + 1, n >> 8);
				}
				list.push({ name : "shipdata.bin", deflate : true, data : raw });
			}
		}
		g.blocks = table.names;
		g.charges = charges.names;
		list.unshift({ name : "game.json", deflate : true, data : haxe.io.Bytes.ofString(haxe.Json.stringify(g)) });
		list.unshift({ name : "meta.json", deflate : true, data : haxe.io.Bytes.ofString(haxe.Json.stringify(meta(info))) });
		if( thumb != null ) list.insert(1, { name : "thumb.png", data : thumb });
		else if( keep != null ) {
			var it = try find(items(keep), "thumb.png") catch( e : Dynamic ) null;
			if( it != null ) list.insert(1, { name : "thumb.png", raw : { item : it, from : keep } });
		}
		return zip(list, zipTime(info.saved));
	}

	/** fecha de las entradas del zip: la de guardado (el formato del zip no va antes de 1980) */
	static function zipTime( t : Float ) : Date {
		var min = new Date(1980, 0, 2, 0, 0, 0).getTime();
		return Date.fromTime(t > min ? t : min);
	}

	/** otro nombre y opciones (Continuar > Modificar): meta.json y game.json con ellos, el resto (miniatura, planetas) tal cual */
	public static function rewrite( b : haxe.io.Bytes, name : String, dropOnDeath : Bool ) : haxe.io.Bytes {
		var l = items(b);
		var mi = find(l, "meta.json"), gi = find(l, "game.json");
		if( mi == null || gi == null ) throw new SaveError("faltan meta.json o game.json");
		var m : Dynamic = haxe.Json.parse(data(b, mi).toString());
		var g : Dynamic = haxe.Json.parse(data(b, gi).toString());
		m.name = g.name = name;
		m.dropOnDeath = g.dropOnDeath = dropOnDeath;
		var list : Array<OutItem> = [
			{ name : "meta.json", deflate : true, data : haxe.io.Bytes.ofString(haxe.Json.stringify(m)) },
			{ name : "game.json", deflate : true, data : haxe.io.Bytes.ofString(haxe.Json.stringify(g)) },
		];
		for( it in l ) if( it.name != "meta.json" && it.name != "game.json" ) list.push({ name : it.name, raw : { item : it, from : b } });
		return zip(list, zipTime(m.saved));
	}

	/**
	 * Solo algunas entradas de un archivo (la lista de partidas: meta.json, thumb.png), sin leerlo entero: el final (el
	 * directorio central) y los datos de cada una. Error si no se puede (el archivo esta cortado o danado)
	 */
	public static function readParts( path : String, names : Array<String> ) : Map<String, haxe.io.Bytes> {
		var f = try sys.io.File.read(path, true) catch( e : Dynamic ) throw new SaveError("no se puede abrir: " + e);
		try {
			var size = sys.FileSystem.stat(path).size;
			var tail = size < 66000 ? size : 66000;
			f.seek(size - tail, SeekBegin);
			var t = f.read(tail);
			// el directorio central y lo que le sigue, con las posiciones del archivo entero
			var e = t.length - 22;
			while( e >= 0 && t.getInt32(e) != END ) e--;
			if( e < 0 ) throw new SaveError("no termina como un zip (cortado)");
			var cdSize = t.getInt32(e + 12), cdAt = t.getInt32(e + 16);
			var base = size - tail;
			var cd = if( cdAt >= base ) t.sub(cdAt - base, t.length - (cdAt - base)) else {
				f.seek(cdAt, SeekBegin);
				f.read(size - cdAt);
			};
			// un zip con solo el directorio central y el final: items() lee sus entradas (offset del archivo entero)
			var n = t.getUInt16(e + 10);
			var out = new Map<String, haxe.io.Bytes>();
			var at = 0;
			for( i in 0...n ) {
				if( at + 46 > cd.length || cd.getInt32(at) != CENTRAL ) throw new SaveError("directorio del zip mal formado");
				var method = cd.getUInt16(at + 10), crc = cd.getInt32(at + 16), csize = cd.getInt32(at + 20), usize = cd.getInt32(at + 24);
				var nl = cd.getUInt16(at + 28), xl = cd.getUInt16(at + 30), cl = cd.getUInt16(at + 32), local = cd.getInt32(at + 42);
				var name = cd.getString(at + 46, nl);
				at += 46 + nl + xl + cl;
				if( names.indexOf(name) < 0 ) continue;
				f.seek(local, SeekBegin);
				var h = f.read(30);
				if( h.getInt32(0) != LOCAL ) throw new SaveError(name + ": cabecera perdida");
				f.seek(local + 30 + h.getUInt16(26) + h.getUInt16(28), SeekBegin);
				var raw = f.read(csize);
				out.set(name, data(raw, { name : name, method : method, crc : crc, csize : csize, usize : usize, offset : 0 }));
			}
			f.close();
			for( n in names ) if( !out.exists(n) && n != "thumb.png" ) throw new SaveError("falta " + n);
			return out;
		} catch( e : Dynamic ) {
			f.close();
			throw Std.isOfType(e, SaveError) ? e : new SaveError(Std.string(e));
		}
	}

	// ---------------------------------------------------------------- archivo -> partida

	/** meta.json de un archivo (la lista de partidas) */
	public static function readMeta( b : haxe.io.Bytes ) : Dynamic {
		var l = items(b);
		var m = find(l, "meta.json");
		if( m == null ) throw new SaveError("falta meta.json");
		var o : Dynamic = try haxe.Json.parse(data(b, m).toString()) catch( e : SaveError ) throw e catch( e : Dynamic ) throw new SaveError("meta.json: " + e);
		if( o.format == null || o.name == null ) throw new SaveError("meta.json incompleto");
		if( Std.int(o.format) > FORMAT ) throw new SaveError("formato " + o.format + " de una version mas reciente");
		return o;
	}

	/** la miniatura (null si no tiene) */
	public static function readThumb( b : haxe.io.Bytes ) : haxe.io.Bytes {
		var it = find(items(b), "thumb.png");
		return it == null ? null : data(b, it);
	}

	/**
	 * La partida entera, con los numeros de Block.all (SaveNames.resolve: los kubes del editor y los nombres que no se conocen,
	 * en bloques de remplazo hasta EditorKubes.attach). Error con lo que esta mal si algo esta mal formado
	 */
	public static function decode( b : haxe.io.Bytes, id : String ) : SaveInfo {
		var l = items(b);
		var gi = find(l, "game.json");
		if( gi == null ) throw new SaveError("falta game.json");
		readMeta(b);
		var g : Dynamic = try haxe.Json.parse(data(b, gi).toString()) catch( e : SaveError ) throw e catch( e : Dynamic ) throw new SaveError("game.json: " + e);
		var names : Array<String> = g.blocks, cnames : Array<String> = g.charges;
		if( !Std.isOfType(names, Array) || !Std.isOfType(cnames, Array) ) throw new SaveError("game.json: faltan las tablas de nombres");
		var blocks = [for( n in names ) SaveNames.resolve(Std.string(n)).index];
		var lost = 0;
		function block( p : Int ) : Int {
			if( p < 0 || p >= blocks.length ) throw new SaveError("bloque " + p + " fuera de la tabla");
			return blocks[p];
		}
		var info = SaveData.fromObject(g, id);
		// las posiciones de la tabla pasan a bloques; las cargas que esta version no conoce se quitan (UnknownBlocks las cuenta)
		SaveNames.mapBlocks(info, function(p, _) return block(p));
		function charges( c : Protocol.UserCharges ) : Protocol.UserCharges {
			if( c == null ) return null;
			var out = [];
			for( x in c ) {
				if( x.c < 0 || x.c >= cnames.length ) throw new SaveError("carga " + x.c + " fuera de la tabla");
				var k = SaveNames.resolveCharge(Std.string(cnames[x.c]));
				if( k < 0 ) lost += x.n else out.push({ c : k, n : x.n });
			}
			return out;
		}
		if( info.inv != null ) info.inv.charges = charges(info.inv.charges);
		if( info.storage != null ) info.storage.charges = charges(info.storage.charges);
		if( info.deathDrops != null ) for( d in info.deathDrops ) d.charges = charges(d.charges);
		if( info.market != null )
			info.market.items = [for( it in info.market.items ) {
				var key = it.key;
				if( key != null && StringTools.startsWith(key, "b:") ) key = "b" + SaveNames.resolve(key.substr(2)).index;
				else if( key != null && StringTools.startsWith(key, "c:") ) {
					var c = SaveNames.resolveCharge(key.substr(2));
					key = c < 0 ? null : "c" + c;
				}
				if( key == null ) continue;
				{ key : key, bought : it.bought, sold : it.sold };
			}];
		if( lost > 0 ) info.unknownCharges = lost;
		// planetas
		var planets = new Map<Int, UniPlanet>();
		if( info.uni != null ) for( p in info.uni.planets ) planets.set(p.id, p);
		var current = false;
		for( it in l ) {
			if( !StringTools.startsWith(it.name, "planets/") ) continue;
			var p = readPlanet(it.name, data(b, it));
			for( i in 0...p.edits.length >> 1 ) if( p.edits[i * 2] >= 0 ) p.edits[i * 2 + 1] = (p.edits[i * 2 + 1] & ~0xFFFF) | block(p.edits[i * 2 + 1] & 0xFFFF);
			if( it.name == "planets/current.bin" ) {
				info.edits = p.edits;
				current = true;
				continue;
			}
			var u = planets.get(p.id);
			if( u == null ) throw new SaveError(it.name + ": planeta que no esta en uni.planets");
			u.edits = p.edits;
		}
		if( !current ) throw new SaveError("falta planets/current.bin");
		for( p in planets ) if( p.edits == null ) throw new SaveError("faltan los cambios del planeta " + p.id);
		var si = find(l, "ship.bin");
		info.shipEdits = [];
		if( si != null ) {
			var i = new haxe.io.BytesInput(data(b, si));
			if( i.readByte() != CELLS ) throw new SaveError("ship.bin: formato desconocido");
			readCells(i, info.shipEdits);
			for( k in 0...info.shipEdits.length >> 1 ) info.shipEdits[k * 2 + 1] = (info.shipEdits[k * 2 + 1] & ~0xFFFF) | block(info.shipEdits[k * 2 + 1] & 0xFFFF);
		}
		var sd = find(l, "shipdata.bin");
		info.shipData = null;
		if( sd != null ) {
			var raw = data(b, sd);
			var cells = raw.length >= 3 ? raw.get(0) * raw.get(1) * raw.get(2) : 0;
			for( i in 0...cells ) {
				var p = 3 + i * 2;
				if( p + 1 >= raw.length ) break;
				var n = block(raw.get(p) | (raw.get(p + 1) << 8));
				raw.set(p, n & 0xFF);
				raw.set(p + 1, n >> 8);
			}
			info.shipData = haxe.crypto.Base64.encode(haxe.zip.Compress.run(raw, 9));
		}
		return info;
	}

	// ---------------------------------------------------------------- disco

	/**
	 * Escribe un archivo sin perder el anterior si algo falla: <path>.tmp, luego fuera el .bak, el que habia pasa a .bak (en Windows
	 * renombrar sobre un archivo que existe falla) y el .tmp a su nombre. Cada paso se reintenta un rato si el archivo esta
	 * ocupado (OneDrive, el antivirus). Error si no se pudo (SaveData.write lo dice siempre). El archivo se comprueba en memoria
	 * y el .tmp por su tamano: volver a leer un archivo recien escrito puede esperar al antivirus (hasta segundos con un zip)
	 */
	public static function writeFile( path : String, b : haxe.io.Bytes ) {
		if( !check(b) ) throw new SaveError("archivo mal formado, no se escribe: " + path);
		var tmp = path + ".tmp", bak = path + ".bak";
		retry("escribir " + tmp, function() sys.io.File.saveBytes(tmp, b));
		var size = try sys.FileSystem.stat(tmp).size catch( e : Dynamic ) -1;
		if( size != b.length ) throw new SaveError("el archivo escrito no esta entero (" + size + " de " + b.length + " bytes): " + tmp);
		if( sys.FileSystem.exists(bak) ) retry("borrar " + bak, function() sys.FileSystem.deleteFile(bak));
		if( sys.FileSystem.exists(path) ) retry("renombrar " + path, function() sys.FileSystem.rename(path, bak));
		retry("renombrar " + tmp, function() sys.FileSystem.rename(tmp, path));
	}

	static function retry( what : String, f : Void -> Void ) {
		var n = 0;
		while( true ) {
			try {
				f();
				return;
			} catch( e : Dynamic ) {
				if( ++n >= 20 ) throw new SaveError("no se pudo " + what + ": " + e);
				Sys.sleep(0.1);
			}
		}
	}

	/**
	 * Lo que se puede leer de una partida tras un fallo al guardar (writeFile): el .tmp entero es lo ultimo que se guardo, si no el
	 * .g55 y si no el .bak. fix: deja el elegido en su sitio (.g55) y borra un .tmp cortado. null si no queda ninguno entero
	 */
	public static function recover( path : String, fix : Bool ) : haxe.io.Bytes {
		inline function load( p : String ) : haxe.io.Bytes return sys.FileSystem.exists(p) ? (try sys.io.File.getBytes(p) catch( e : Dynamic ) null) : null;
		var tmp = load(path + ".tmp");
		if( tmp != null && check(tmp) ) {
			// writeFile lo vuelve a escribir en .tmp y lo renombra a .g55
			if( fix ) try writeFile(path, tmp) catch( e : Dynamic ) {}
			return tmp;
		}
		// un .tmp cortado no sirve: el guardado no llego a terminar
		if( tmp != null && fix ) try sys.FileSystem.deleteFile(path + ".tmp") catch( e : Dynamic ) {}
		var cur = load(path);
		if( cur != null && check(cur) ) return cur;
		var bak = load(path + ".bak");
		if( bak != null && check(bak) ) {
			if( fix ) try writeFile(path, bak) catch( e : Dynamic ) {}
			return bak;
		}
		return null;
	}
}
