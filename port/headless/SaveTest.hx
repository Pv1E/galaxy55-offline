import Common;
import SaveData.SaveInfo;
import SaveArchive.SaveError;

/**
 * Pruebas del guardado (SaveData, SaveArchive, SaveNames), desde la raiz del repo (lee port/headless/fixtures):
 *   haxe port/savetest.hxml   y   GALAXY55_DATA=<carpeta de prueba> hl port/out/savetest.hl
 * - tablas: la de la linea de este juego es el principio de BlockKind, y las dos lineas difieren en 300..302
 * - ida y vuelta: una partida con de todo (bloques > 255, un kube del editor sin cargar, planetas, nave, nave del hangar, cantinas,
 *   stockage, equipo dejado, precios, tutorial, agua y mar) sale igual del archivo, en memoria y por disco; la lista (solo
 *   meta.json), la miniatura, el .bak y renombrar
 * - nombres desconocidos: pasan a bloques de remplazo, se cuentan, y siguen con su nombre tras jugar y guardar; cargas desconocidas
 * - migracion de los .json de antes con las dos tablas (fixtures/), a .g55 con copia en saves/backups, y otra vez con la otra tabla;
 *   campo que falta (su valor de siempre) y campo mal formado (error con su nombre, ilegible en la lista)
 * - recuperacion tras un fallo al guardar: cada combinacion de .g55, .tmp y .bak (que falta, entero o cortado)
 * La poda de los cambios (World.prune) necesita el mundo: la prueba "print prune" de devrun (port/dev/poda.txt).
 * Solo corre con GALAXY55_DATA: sin ella escribiria en las partidas de verdad (%APPDATA%). Sale con 1 si algo falla.
 */
@:access(SaveArchive)
class SaveTest {

	static var checks = 0;
	static var fails = 0;
	static var THUMB = haxe.io.Bytes.ofString("PNG de prueba");
	static var FIXTURES = "port/headless/fixtures";

	static function main() {
		var data = Sys.getEnv("GALAXY55_DATA");
		if( data == null || data == "" ) {
			Sys.println("SaveTest necesita GALAXY55_DATA (carpeta de datos de prueba, p. ej. port/out/testdata): no se toca %APPDATA%");
			Sys.exit(1);
		}
		if( !sys.FileSystem.exists(FIXTURES) ) {
			Sys.println("SaveTest se lanza desde la raiz del repo (falta " + FIXTURES + ")");
			Sys.exit(1);
		}
		// sin bucle de juego: que el centinela de hxd.System (30 s sin tick) no corte la prueba
		hxd.System.allowTimeout = false;
		var t0 = haxe.Timer.stamp(), times = [];
		for( f in [{ n : "tablas", f : tables }, { n : "ida y vuelta", f : roundTrip }, { n : "desconocidos", f : unknownNames },
			{ n : "migracion", f : migration }, { n : "recuperacion", f : recovery }] ) {
			var t = haxe.Timer.stamp();
			try f.f() catch( e : Dynamic ) check(f.n + ": sin excepciones", false, Std.string(e) + haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
			times.push(f.n + " " + Std.int((haxe.Timer.stamp() - t) * 1000));
		}
		Sys.println("SaveTest: " + checks + " comprobaciones, " + fails + " fallos (" + Std.int((haxe.Timer.stamp() - t0) * 1000) + " ms: " + times.join(", ") + ")");
		Sys.exit(fails == 0 ? 0 : 1);
	}

	// ---------------------------------------------------------------- utilidades

	static function check( what : String, ok : Bool, ?detail : String ) {
		checks++;
		if( ok ) return;
		fails++;
		Sys.println("FALLO " + what + (detail != null ? " (" + detail + ")" : ""));
	}

	static function same( what : String, a : Dynamic, b : Dynamic ) {
		var ca = canon(a), cb = canon(b);
		if( ca == cb ) {
			checks++;
			return;
		}
		var i = 0;
		while( i < ca.length && i < cb.length && ca.charAt(i) == cb.charAt(i) ) i++;
		var from = i > 80 ? i - 80 : 0;
		check(what, false, "difieren en " + i + ": ..." + ca.substr(from, 160) + "\n   frente a ..." + cb.substr(from, 160));
	}

	/** JSON con los campos en orden y sin los nulos: dos partidas iguales hechas por caminos distintos dan lo mismo */
	static function canon( v : Dynamic ) : String {
		if( v == null ) return "null";
		if( Std.isOfType(v, String) ) return haxe.Json.stringify(v);
		if( Std.isOfType(v, Bool) || Std.isOfType(v, Int) || Std.isOfType(v, Float) ) return Std.string(v);
		if( Std.isOfType(v, Array) ) return "[" + [for( x in (v : Array<Dynamic>) ) canon(x)].join(",") + "]";
		var fields = Reflect.fields(v);
		fields.sort(Reflect.compare);
		return "{" + [for( f in fields ) if( Reflect.field(v, f) != null ) f + ":" + canon(Reflect.field(v, f))].join(",") + "}";
	}

	/** la partida para comparar: sin lo que no se guarda, las celdas cambiadas como lista ordenada y la nave del hangar descomprimida */
	static function norm( info : SaveInfo ) : Dynamic {
		var o : Dynamic = haxe.Json.parse(haxe.Json.stringify(info));
		for( f in ["id", "hangar", "mothership", "unknownCharges", "listOnly", "unreadable", "inSpace", "oldGeneration", "legacy"] )
			Reflect.deleteField(o, f);
		o.edits = cellList(info.edits);
		o.shipEdits = cellList(info.shipEdits);
		if( info.uni != null ) for( i in 0...info.uni.planets.length ) o.uni.planets[i].edits = cellList(info.uni.planets[i].edits);
		if( info.shipData != null ) o.shipData = haxe.zip.Uncompress.run(haxe.crypto.Base64.decode(info.shipData)).toHex();
		return o;
	}

	static function cellList( e : Array<Int> ) : Array<String> {
		if( e == null ) return [];
		var m = new Map<Int, Int>();
		var i = 0;
		while( i + 1 < e.length ) {
			m.set(e[i], e[i + 1]);
			i += 2;
		}
		var keys = [for( k in m.keys() ) k];
		keys.sort(function(a, b) return a - b);
		return [for( k in keys ) k + "=" + m.get(k)];
	}

	/** celda de un planeta de 128 * chunks (World: (x + y * size) << ZBITS | z) */
	static inline function cell( x : Int, y : Int, z : Int, chunks = 1 ) return ((x + y * Const.SIZE * chunks) << World.ZBITS) | z;

	static inline function idx( k : BlockKind ) return Block.get(k).index;

	static function name( gi : Int ) return SaveNames.nameOfIndex(gi);

	/** el valor guardado de una celda (edits: pares [celda, bloque | nivel << 16]); null si no esta */
	static function editAt( e : Array<Int>, key : Int ) : Null<Int> {
		var r : Null<Int> = null, i = 0;
		while( i + 1 < e.length ) {
			if( e[i] == key ) r = e[i + 1];
			i += 2;
		}
		return r;
	}

	static function exists( p : String ) return sys.FileSystem.exists(p);

	// ---------------------------------------------------------------- tablas

	static function tables() {
		var names = Type.getEnumConstructs(BlockKind);
		var mine = SaveNames.legacyTable(SaveNames.lineage());
		var prefix = names.length >= mine.length;
		if( prefix ) for( i in 0...mine.length ) if( names[i] != mine[i] ) {
			prefix = false;
			check("tabla " + SaveNames.lineage() + " = BlockKind", false, i + ": " + mine[i] + " / " + names[i]);
			break;
		}
		check("la tabla de " + SaveNames.lineage() + " es el principio de BlockKind (" + mine.length + " de " + names.length + ")", prefix);
		check("upstream: 300 = BKubeMystery", SaveNames.UPSTREAM[300] == "BKubeMystery");
		check("fork: 300..302 = Grey Haven y BKubeMystery", SaveNames.FORK.slice(300, 303).join(",") == "BKubeGreyHavenTreeTrunk,BKubeGreyHavenSand,BKubeMystery");
		check("fork = upstream con los dos de Grey Haven", SaveNames.FORK.length == SaveNames.UPSTREAM.length + 2);
		var charges = Type.getEnumConstructs(ChargeKind);
		check("cargas de antes = principio de ChargeKind", charges.slice(0, SaveNames.LEGACY_CHARGES.length).join(",") == SaveNames.LEGACY_CHARGES.join(","));
		// cada bloque con su nombre y vuelta
		var bad = [for( n in names ) if( SaveNames.resolve(n).index != Type.enumIndex(Type.createEnum(BlockKind, n)) ) n];
		check("cada BlockKind se lee por su nombre", bad.length == 0, bad.join(","));
	}

	// ---------------------------------------------------------------- ida y vuelta

	/** la nave del hangar mas pequena: 2x1x2 y sus 4 celdas */
	static function tinyShip( ids : Array<Int> ) : String {
		var raw = haxe.io.Bytes.alloc(3 + ids.length * 2);
		raw.set(0, 2);
		raw.set(1, 1);
		raw.set(2, 2);
		for( i in 0...ids.length ) raw.setUInt16(3 + i * 2, ids[i]);
		return haxe.crypto.Base64.encode(haxe.zip.Compress.run(raw, 9));
	}

	/** una partida con algo en cada sitio que guarda bloques o cargas (con los valores que pone SaveData.fromObject) */
	static function rich( title : String ) : SaveInfo {
		var info = SaveData.create(title, 4242, "BIMoon", 2, true);
		var big = idx(BKubeMystery), last = Type.getEnumConstructs(BlockKind).length - 1;
		var ed = SaveNames.resolve("editor:savetest#2").index;
		info.inv.t[0] = { k : big, n : 3 };
		info.inv.t[1] = { k : last, n : 1 };
		info.inv.t[2] = { k : ed, n : 4 };
		info.inv.charges = [{ c : 1, n : 12 }, { c : 3, n : 2 }];
		info.edits = [cell(1, 2, 60, 2), idx(BLamp), cell(3, 4, 61, 2), 0, cell(5, 6, 62, 2), idx(BWater) | (5 << 16), cell(255, 255, 63, 2), big,
			-1, 40, -2, 3];
		info.shipEdits = [cell(10, 10, 5), idx(BShipHull), cell(11, 10, 5), ed];
		info.uni = { seed : 4242, planetId : 7, pos : [3, 1], start : { seed : 4242, biome : "BIMoon", size : 2 }, planets : [
				{ id : 2, edits : [cell(9, 9, 50), idx(BRock), cell(9, 9, 51), last], shipAt : { x : 30, y : 40 }, genVersion : 0, seed : 99, biome : "BIAutumn", size : 1 },
				{ id : 5, edits : [], genVersion : gen.Generator.VERSION, seed : 123, biome : "BIMoon", size : 3 },
			], licenses : [0, 2], main : 0, mainChanges : 1, abandoned : [], gone : [4], traveled : 12.5 };
		info.chests = [{ key : "p7:1,2,3", t : [{ k : big, n : 2 }, null, { k : idx(BWood), n : 9 }, null] }, { key : "s:4,5,6", t : [null, null, null, null] }];
		info.storage = StorageData.empty();
		info.storage.t[0] = { k : ed, n : 1 };
		info.storage.charges = [{ c : 0, n : 4 }];
		info.deathDrops = [{ id : 1, key : "p7", x : 10.5, y : 11.5, z : 70, t : [{ k : last, n : 2 }], charges : [{ c : 2, n : 1 }] }];
		info.market = Market.create();
		info.market.items.push({ key : "b" + big, bought : 3, sold : 1 });
		info.market.items.push({ key : "c2", bought : 1, sold : 0 });
		info.tuto = { step : 3, spots : [1, 2, 3, idx(BLamp), 4, 5, 6, big] };
		info.shipAt = { x : 12, y : 34 };
		info.shipData = tinyShip([idx(BShipHull), 0, big, ed]);
		info.playSeconds = 3600.5;
		info.px = 100.25;
		info.py = 50.5;
		info.pz = 70;
		info.life = 80;
		info.kub = Kubindex.empty();
		info.kub.seen = ["BRock"];
		info.dropOnDeath = true;
		info.upgrades = ["prueba"];
		info.contracts = @:privateAccess SaveData.readContracts(null);
		return info;
	}

	static function roundTrip() {
		var info = rich("Ida y vuelta");
		var b = SaveArchive.encode(info, THUMB);
		check("el archivo es un zip entero (check)", SaveArchive.check(b));
		var back = SaveArchive.decode(b, info.id);
		same("ida y vuelta en memoria", norm(back), norm(info));
		var o = SaveTool.toObject(b);
		var blocks : Array<String> = o.game.blocks;
		check("tabla de bloques: cada nombre una vez", [for( n in blocks ) if( blocks.indexOf(n) != blocks.lastIndexOf(n) ) n].length == 0);
		for( n in ["BEmpty", "BKubeMystery", "editor:savetest#2", Type.getEnumConstructs(BlockKind)[Type.getEnumConstructs(BlockKind).length - 1]] )
			check("tabla de bloques con " + n, blocks.indexOf(n) >= 0);
		check("precios del robot por nombre", [for( it in (o.game.market.items : Array<Dynamic>) ) it.key].indexOf("b:BKubeMystery") >= 0);
		check("entradas del zip", [for( e in (o.entries : Array<Dynamic>) ) e.name].join(",") == "meta.json,thumb.png,game.json,planets/current.bin,planets/2.bin,planets/5.bin,ship.bin,shipdata.bin",
			[for( e in (o.entries : Array<Dynamic>) ) e.name].join(","));
		// por disco
		check("guardar", SaveData.write(info, THUMB), SaveData.lastError);
		var disk = SaveData.read(info.id);
		check("leer", disk != null, SaveData.lastError);
		same("ida y vuelta por disco", norm(disk), norm(info));
		var l = [for( x in SaveData.list() ) if( x.id == info.id ) x];
		check("en la lista, solo con meta.json", l.length == 1 && l[0].listOnly == true && l[0].name == info.name && l[0].seed == 4242
			&& l[0].biome == "BIMoon" && l[0].sizeChunks == 2 && l[0].creative == true && l[0].playSeconds == info.playSeconds);
		check("miniatura", SaveData.thumb(info.id) != null && SaveData.thumb(info.id).compare(THUMB) == 0);
		// planeta actual de la version de ahora y uno visitado de la 0: Ancienne partie (meta.json y la lista)
		check("con un planeta de la version 0: antigua", SaveData.isOldGeneration(info) && l[0].oldGeneration == true);
		var fresh = SaveData.create("Nueva", 1, "BIAutumn", 1);
		check("partida nueva: no es antigua", !SaveData.isOldGeneration(fresh) && SaveArchive.meta(fresh).oldGeneration == false);
		fresh.genVersion = gen.Generator.MIN_VERSION;
		check("planeta de la version mas antigua que sigue: no es antigua", gen.Generator.MIN_VERSION < gen.Generator.VERSION
			&& !SaveData.isOldGeneration(fresh) && SaveArchive.meta(fresh).oldGeneration == false);
		// guardado automatico (sin miniatura): deja la que habia; el anterior pasa a .bak
		var before = info.playSeconds;
		info.playSeconds += 10;
		check("guardar otra vez", SaveData.write(info, null), SaveData.lastError);
		check("la miniatura se queda", SaveData.thumb(info.id).compare(THUMB) == 0);
		var path = SaveData.archivePath(info.id);
		check("el anterior en .bak", exists(path + ".bak") && SaveArchive.decode(sys.io.File.getBytes(path + ".bak"), info.id).playSeconds == before);
		check("sin .tmp", !exists(path + ".tmp"));
		// renombrar: la misma fecha, miniatura y planetas
		var prev = SaveData.read(info.id);
		check("renombrar", SaveData.edit(info.id, "Renombrada", false), SaveData.lastError);
		var after = SaveData.read(info.id);
		check("nombre y opcion nuevos", after.name == "Renombrada" && after.dropOnDeath == false);
		check("misma fecha de guardado", after.saved == prev.saved);
		check("misma miniatura", SaveData.thumb(info.id).compare(THUMB) == 0);
		after.name = prev.name;
		after.dropOnDeath = prev.dropOnDeath;
		same("renombrar no cambia lo demas", norm(after), norm(prev));
		// al jugarla (GalaxyApp.startGame): los kubes del editor de la partida, en creativo y en aventura
		for( creative in [true, false] ) {
			var p = SaveData.read(info.id);
			p.creative = creative;
			var err = try {
				EditorKubes.attach(p);
				null;
			} catch( e : Dynamic ) Std.string(e);
			check("EditorKubes.attach en " + (creative ? "creativo" : "aventura"), err == null, err);
			check("el kube del editor sin cargar sigue con su nombre (" + (creative ? "creativo" : "aventura") + ")", name(p.inv.t[2].k) == "editor:savetest#2");
		}
		// modificar una partida que ya no se puede leer (cortada, sin copias): falla y dice por que (GalaxyApp lo avisa)
		var b = sys.io.File.getBytes(path);
		sys.io.File.saveBytes(path, b.sub(0, b.length >> 1));
		for( e in [".tmp", ".bak"] ) if( exists(path + e) ) sys.FileSystem.deleteFile(path + e);
		var edited = SaveData.edit(info.id, "No deberia", true);
		check("modificar una cortada: falla con su motivo", !edited && SaveData.lastError != null && SaveData.lastError.length > 0, SaveData.lastError);
		SaveData.delete(info.id);
		check("borrada (.g55, .bak)", !exists(path) && !exists(path + ".bak"));
	}

	// ---------------------------------------------------------------- nombres desconocidos

	static function unknownNames() {
		var a = SaveNames.resolve("BDesconocidoA"), b = SaveNames.resolve("BDesconocidoB");
		check("mismo nombre, mismo bloque de remplazo", SaveNames.resolve("BDesconocidoA") == a && a != b);
		check("de remplazo, con su nombre", SaveNames.isUnknown(a) && SaveNames.placeholderName(a) == "BDesconocidoA" && name(a.index) == "BDesconocidoA");
		check("un kube del editor sin cargar no es desconocido", !SaveNames.isUnknown(SaveNames.resolve("editor:savetest#1")));
		var info = SaveData.create("Desconocidos", 5, "BIAutumn", 1, true);
		info.inv.t[0] = { k : a.index, n : 7 };
		info.edits = [cell(1, 1, 60), b.index, cell(2, 2, 61), a.index | (2 << 16)];
		info.market = Market.create();
		info.market.items.push({ key : "b" + b.index, bought : 1, sold : 0 });
		check("guardar", SaveData.write(info, null), SaveData.lastError);
		// jugarla: leerla, cambiar otras cosas y guardarla
		var p = SaveData.read(info.id);
		var r = UnknownBlocks.count(p);
		check("contados: 7 en casillas y 2 celdas", r.items == 7 && r.world == 2 && r.names.join(",") == "BDesconocidoA,BDesconocidoB",
			r.items + " " + r.world + " " + r.names.join(","));
		p.inv.t[1] = { k : idx(BWood), n : 1 };
		p.edits = p.edits.concat([cell(3, 3, 62), idx(BLamp)]);
		p.playSeconds += 60;
		check("guardar tras jugar", SaveData.write(p, null), SaveData.lastError);
		var o = SaveTool.toObject(sys.io.File.getBytes(SaveData.archivePath(info.id)));
		check("inventario: sigue con su nombre", o.game.inv.t[0].k == "BDesconocidoA" && o.game.inv.t[1].k == "BWood");
		var cur : Dynamic = [for( pl in (o.planets : Array<Dynamic>) ) if( pl.entry == "planets/current.bin" ) pl][0];
		var cells = [for( c in (cur.cells : Array<Dynamic>) ) c.x + "," + c.y + "," + c.z + "=" + c.b + (c.level != null ? "/" + c.level : "")];
		cells.sort(Reflect.compare);
		check("terreno: siguen con su nombre", cells.join(" ") == "1,1,60=BDesconocidoB 2,2,61=BDesconocidoA/2 3,3,62=BLamp", cells.join(" "));
		check("precios: sigue con su nombre", [for( it in (o.game.market.items : Array<Dynamic>) ) it.key].indexOf("b:BDesconocidoB") >= 0);
		// una carga que esta version no conoce: se quita al leer y se cuenta
		var bytes = sys.io.File.getBytes(SaveData.archivePath(info.id));
		var l = SaveArchive.items(bytes);
		var g : Dynamic = haxe.Json.parse(SaveArchive.data(bytes, SaveArchive.find(l, "game.json")).toString());
		var cn : Array<String> = g.charges;
		var first = (g.inv.charges : Array<Dynamic>)[0];
		var lostName = cn[first.c], lostN : Int = first.n;
		cn[first.c] = "CDesconocida";
		var list : Array<SaveArchive.OutItem> = [for( it in l ) it.name == "game.json"
			? { name : "game.json", deflate : true, data : haxe.io.Bytes.ofString(haxe.Json.stringify(g)) }
			: { name : it.name, raw : { item : it, from : bytes } }];
		var d = SaveArchive.decode(SaveArchive.zip(list, Date.now()), info.id);
		check("carga desconocida quitada y contada (" + lostName + " x" + lostN + ")", d.unknownCharges == lostN
			&& [for( c in d.inv.charges ) if( SaveNames.chargeName(c.c) == lostName ) c].length == 0 && UnknownBlocks.count(d).items == 7 + lostN);
		SaveData.delete(info.id);
	}

	// ---------------------------------------------------------------- migracion

	static function migration() {
		var fx = FIXTURES + "/legacy_mixta.json";
		for( lineage in ["upstream", "fork"] ) {
			var t = SaveNames.legacyTable(lineage);
			var info = SaveData.readLegacy(fx, "fx", lineage);
			var want = [t[300], t[301], t[302]];
			var what = "migrar con " + lineage + " (" + want.join(", ") + ")";
			check(what + ": inventario", [for( i in 0...3 ) name(info.inv.t[i].k)].join(",") == want.join(","), [for( i in 0...3 ) name(info.inv.t[i].k)].join(","));
			check(what + ": un bloque de siempre", name(info.inv.t[3].k) == t[5] && info.inv.t[3].n == 10);
			check(what + ": terreno", name(editAt(info.edits, 1000)) == want[0] && name(editAt(info.edits, 2000)) == want[1] && name(editAt(info.edits, 3000)) == want[2]);
			check(what + ": agua con nivel y mar", editAt(info.edits, 4000) == (idx(BWater) | (3 << 16)) && editAt(info.edits, -1) == 40 && editAt(info.edits, -2) == 3);
			check(what + ": nave", name(editAt(info.shipEdits, 500)) == want[1]);
			check(what + ": planeta visitado", name(editAt(info.uni.planets[0].edits, 10)) == want[2]);
			check(what + ": cantina", name(info.chests[0].t[0].k) == want[0]);
			check(what + ": precios", name(Std.parseInt(info.market.items[0].key.substr(1))) == want[0] && info.market.items[1].key == "c1");
			check(what + ": tutorial", name(info.tuto.spots[3]) == want[1]);
			check(what + ": cargas", [for( c in info.inv.charges ) SaveNames.chargeName(c.c) + "x" + c.n].join(",") == "CYellowx5,CBonusx2");
			check(what + ": kubes del editor (editorKubes)", name(editAt(info.edits, 5000)) == "editor:prueba#1" && name(info.inv.t[4].k) == "editor:prueba#2" && info.inv.t[4].n == 7);
			// y su .g55 sale igual
			same(what + ": ida y vuelta", norm(SaveArchive.decode(SaveArchive.encode(info, null), "fx")), norm(info));
		}
		// en la carpeta: .json y .png de antes -> .g55, con copia en saves/backups; y otra vez con la otra tabla
		var id = "savetest_migrar", mine = SaveNames.lineage(), other = mine == "fork" ? "upstream" : "fork";
		sys.io.File.copy(fx, SaveData.jsonPath(id));
		sys.io.File.saveBytes(SaveData.thumbPath(id), THUMB);
		var l = [for( x in SaveData.list() ) if( x.id == id ) x];
		check("la de antes en la lista", l.length == 1 && l[0].legacy == true && l[0].name == "Partida de antes");
		check("la de antes: antigua (version 0)", l[0].oldGeneration == true);
		var m = SaveData.read(id);
		check("migrada al leerla", m != null, SaveData.lastError);
		var bk = SaveData.backupDir();
		check(".json y .png a saves/backups", exists(SaveData.archivePath(id)) && !exists(SaveData.jsonPath(id)) && !exists(SaveData.thumbPath(id))
			&& exists(bk + "/" + id + ".json") && exists(bk + "/" + id + ".png"));
		check("con su miniatura", SaveData.thumb(id) != null && SaveData.thumb(id).compare(THUMB) == 0);
		check("con la tabla de " + mine, m != null && name(m.inv.t[0].k) == SaveNames.legacyTable(mine)[300]);
		l = [for( x in SaveData.list() ) if( x.id == id ) x];
		check("en la lista como .g55", l.length == 1 && l[0].legacy == null && l[0].listOnly == true && l[0].name == "Partida de antes");
		var m2 = try SaveData.migrate(id, other) catch( e : Dynamic ) null;
		check("otra vez con la tabla de " + other, m2 != null && name(m2.inv.t[0].k) == SaveNames.legacyTable(other)[300]);
		check("y se lee asi", name(SaveData.read(id).inv.t[0].k) == SaveNames.legacyTable(other)[300]);
		SaveData.delete(id);
		for( e in [".json", ".png"] ) if( exists(bk + "/" + id + e) ) sys.FileSystem.deleteFile(bk + "/" + id + e);
		// lo que falta toma su valor de siempre; lo mal formado es un error con el nombre del campo
		var min = SaveData.readLegacy(FIXTURES + "/legacy_minima.json", "min", mine);
		same("lo que falta: inventario inicial", min.inv, Inv.defaults());
		check("lo que falta: sin universo ni cambios", min.uni == null && min.edits.length == 0 && min.name == "min" && min.sizeChunks == 1);
		var err = try {
			SaveData.readLegacy(FIXTURES + "/legacy_mal.json", "mal", mine);
			null;
		} catch( e : SaveError ) e.msg;
		check("mal formado: error con el campo", err != null && err.indexOf("inv") >= 0, err);
		id = "savetest_mal";
		sys.io.File.copy(FIXTURES + "/legacy_mal.json", SaveData.jsonPath(id));
		l = [for( x in SaveData.list() ) if( x.id == id ) x];
		check("mal formada: ilegible en la lista", l.length == 1 && l[0].unreadable != null && l[0].unreadable.indexOf("inv") >= 0, l.length == 1 ? l[0].unreadable : null);
		check("mal formada: no se abre", SaveData.read(id) == null && SaveData.lastError.indexOf("inv") >= 0, SaveData.lastError);
		check("mal formada: no se toca", exists(SaveData.jsonPath(id)) && !exists(SaveData.archivePath(id)));
		SaveData.delete(id);
	}

	// ---------------------------------------------------------------- recuperacion

	static function recovery() {
		var id = "savetest_recuperar", path = SaveData.archivePath(id);
		// v1 en .bak (el de antes), v2 en .g55, v3 en .tmp (el ultimo, sin renombrar)
		var v = [for( i in 1...4 ) {
			var x = SaveData.create("v" + i, i, "BIAutumn", 1, true);
			x.id = id;
			SaveArchive.encode(x, null);
		}];
		var state = ["falta", "entero", "cortado"];
		for( g in 0...3 ) for( t in 0...3 ) for( k in 0...3 ) {
			if( g == 0 && t == 0 && k == 0 ) continue;
			SaveData.delete(id);
			function put( p : String, s : Int, b : haxe.io.Bytes ) {
				if( s == 1 ) sys.io.File.saveBytes(p, b) else if( s == 2 ) sys.io.File.saveBytes(p, b.sub(0, b.length >> 1));
			}
			put(path, g, v[1]);
			put(path + ".tmp", t, v[2]);
			put(path + ".bak", k, v[0]);
			var want = t == 1 ? "v3" : g == 1 ? "v2" : k == 1 ? "v1" : null;
			var what = "recuperar (.g55 " + state[g] + ", .tmp " + state[t] + ", .bak " + state[k] + ")";
			var l = [for( x in SaveData.list() ) if( x.id == id ) x];
			check(what + ": en la lista como " + (want == null ? "ilegible" : want), l.length == 1 && (want == null ? l[0].unreadable != null : l[0].name == want),
				l.length == 1 ? l[0].name + " " + l[0].unreadable : l.length + " filas");
			var r = SaveData.read(id);
			check(what + ": se lee " + (want == null ? "nada" : want), want == null ? r == null : r != null && r.name == want, r == null ? SaveData.lastError : r.name);
			if( want == null ) continue;
			var b = exists(path) ? sys.io.File.getBytes(path) : null;
			check(what + ": queda en .g55", b != null && SaveArchive.check(b) && SaveArchive.decode(b, id).name == want);
			check(what + ": sin .tmp", !exists(path + ".tmp"));
			check(what + ": se vuelve a leer igual", SaveData.read(id) != null && SaveData.read(id).name == want);
		}
		SaveData.delete(id);
	}
}
