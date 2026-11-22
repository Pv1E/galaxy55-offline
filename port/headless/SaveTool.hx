import Common;
import SaveArchive.SaveError;

/**
 * Herramienta de partidas guardadas (anadido del port):
 *   haxe port/savetool.hxml
 *   hl port/out/savetool.hl dump <partida.g55>                    la partida en JSON legible
 *   hl port/out/savetool.hl dump <partida.json> [upstream|fork]   una de antes, como quedaria al migrarla (con la tabla de esa linea;
 *                                                                  sin linea, la de este juego: SaveNames.lineage)
 * En el JSON van los nombres de los bloques y las cargas en vez de sus posiciones en las tablas, y las celdas de cada planeta y de
 * la nave como x, y, z. No escribe nada.
 */
@:access(SaveArchive)
class SaveTool {

	static function main() {
		var a = Sys.args();
		if( a.length < 2 || a[0] != "dump" ) {
			Sys.println("uso: savetool dump <partida.g55 | partida.json [upstream|fork]>");
			Sys.exit(1);
		}
		try {
			Sys.println(dump(a[1], a[2]));
		} catch( e : Dynamic ) {
			Sys.println("no se puede leer " + a[1] + ": " + e);
			Sys.exit(2);
		}
	}

	/** la partida de un archivo en JSON legible (ver la clase) */
	public static function dump( path : String, ?lineage : String ) : String {
		var b = if( StringTools.endsWith(path, ".json") ) {
			var id = haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(path));
			SaveArchive.encode(SaveData.readLegacy(path, id, lineage != null ? lineage : SaveNames.lineage()), null);
		} else sys.io.File.getBytes(path);
		return haxe.Json.stringify(toObject(b), null, "  ");
	}

	/** un archivo .g55 como objeto: meta, entradas del zip, game.json con nombres, planetas, nave y nave del hangar */
	public static function toObject( b : haxe.io.Bytes ) : Dynamic {
		var l = SaveArchive.items(b);
		function entry( name : String ) : haxe.io.Bytes {
			var it = SaveArchive.find(l, name);
			if( it == null ) throw new SaveError("falta " + name);
			return SaveArchive.data(b, it);
		}
		var g : Dynamic = haxe.Json.parse(entry("game.json").toString());
		var blocks : Array<String> = g.blocks, charges : Array<String> = g.charges;
		function bn( p : Int ) : String return p >= 0 && p < blocks.length ? blocks[p] : "#" + p;
		function cn( p : Int ) : String return p >= 0 && p < charges.length ? charges[p] : "#" + p;
		function slots( t : Array<Dynamic> ) : Array<Dynamic> return t == null ? null : [for( s in t ) s == null ? null : { k : bn(s.k), n : s.n }];
		function ch( c : Array<Dynamic> ) : Array<Dynamic> return c == null ? null : [for( x in c ) { c : cn(x.c), n : x.n }];
		if( g.inv != null ) {
			g.inv.t = slots(g.inv.t);
			g.inv.charges = ch(g.inv.charges);
		}
		if( g.chests != null ) for( c in (g.chests : Array<Dynamic>) ) c.t = slots(c.t);
		if( g.storage != null ) {
			g.storage.t = slots(g.storage.t);
			g.storage.charges = ch(g.storage.charges);
		}
		if( g.deathDrops != null )
			for( d in (g.deathDrops : Array<Dynamic>) ) {
				d.t = slots(d.t);
				d.charges = ch(d.charges);
			}
		if( g.tuto != null && g.tuto.spots != null ) {
			var s : Array<Dynamic> = g.tuto.spots;
			g.tuto.spots = [for( i in 0...s.length ) i & 3 == 3 ? (bn(s[i]) : Dynamic) : s[i]];
		}
		// celdas: [celda, posicion | nivel << 16] -> { x, y, z, b, nivel }
		function cells( edits : Array<Int>, width : Int ) : Array<Dynamic> {
			var out : Array<Dynamic> = [];
			for( i in 0...edits.length >> 1 ) {
				var k = edits[i * 2], v = edits[i * 2 + 1];
				if( k < 0 ) continue;
				var c : Dynamic = { x : (k >> World.ZBITS) % width, y : Std.int((k >> World.ZBITS) / width), z : k & ((1 << World.ZBITS) - 1), b : bn(v & 0xFFFF) };
				if( v >>> 16 != 0 ) c.level = v >>> 16;
				out.push(c);
			}
			return out;
		}
		var planets : Array<Dynamic> = [];
		for( it in l ) {
			if( !StringTools.startsWith(it.name, "planets/") ) continue;
			var p = SaveArchive.readPlanet(it.name, SaveArchive.data(b, it));
			var sea = SaveArchive.seaOf(p.edits);
			var size = p.size != null ? p.size : 1;
			var width = Comets.isComet(p.biome) ? Comets.SIZE : Const.SIZE * size;
			planets.push({ entry : it.name, id : p.id, seed : p.seed, biome : p.biome, size : p.size, genVersion : p.genVersion, shipAt : p.shipAt,
				seaLevel : sea != null ? sea.level : null, flood : sea != null ? sea.flood : null, cells : cells(p.edits, width) });
		}
		var out : Dynamic = { meta : haxe.Json.parse(entry("meta.json").toString()) };
		out.entries = [for( it in l ) { name : it.name, size : it.usize, packed : it.csize }];
		out.game = g;
		out.planets = planets;
		if( SaveArchive.find(l, "ship.bin") != null ) {
			var i = new haxe.io.BytesInput(entry("ship.bin"));
			if( i.readByte() != SaveArchive.CELLS ) throw new SaveError("ship.bin: formato desconocido");
			var e = [];
			SaveArchive.readCells(i, e);
			out.ship = cells(e, Const.SIZE);
		}
		if( SaveArchive.find(l, "shipdata.bin") != null ) {
			// la nave del hangar: medidas y sus celdas no vacias (orden de ShipData.load: y, x, z)
			var raw = entry("shipdata.bin");
			var sx = raw.get(0), sy = raw.get(1), sz = raw.get(2), pos = 3;
			var c : Array<Dynamic> = [];
			for( y in 0...sy )
				for( x in 0...sx )
					for( z in 0...sz ) {
						var v = raw.get(pos) | (raw.get(pos + 1) << 8);
						pos += 2;
						if( v != 0 ) c.push({ x : x, y : y, z : z, b : bn(v) });
					}
			out.shipData = { w : sx, l : sy, h : sz, cells : c };
		}
		return out;
	}
}
