import SaveData.SaveInfo;

/** Cuantos bloques desconocidos tiene una partida y donde (UnknownBlocks). */
typedef UnknownReport = {
	/** celdas del terreno: el planeta actual y los ya visitados */
	var world : Int;
	/** celdas de la nave: los cambios a bordo y la nave hecha en el hangar */
	var ship : Int;
	/** bloques del inventario y de las cantinas (unidades) */
	var items : Int;
	/** numeros de bloque desconocidos, de menor a mayor */
	var ids : Array<Int>;
}

/**
 * Bloques que esta version no conoce (anadido del port). Una partida guardada por una version con mas bloques (numeros de
 * bloque, indices de Block.all, mas alla del ultimo) hacia fallar la carga: InvBar.refresh pedia el icono de un bloque nulo.
 * Al elegirla en la lista se cuentan (count) y se pregunta (GalaxyApp.playSave); si se acepta, se copia la partida (backup) y
 * se borran (clear): las celdas del terreno y de la nave pasan a aire y las casillas del inventario y de las cantinas se vacian.
 * Lo que guarda el numero de un bloque: inv, chests, edits, uni.planets[].edits, shipEdits, shipData y las claves "b<numero>"
 * de market. La Base de datos ESCorp (kub) guarda nombres, no numeros: no se toca.
 */
class UnknownBlocks {

	/** subcarpeta de las partidas con las copias: SaveData.list solo mira los .json de la carpeta, no los de dentro */
	public static inline var BACKUPS = "backups";

	/** cuantos bloques desconocidos tiene la partida (no la cambia) */
	public static function count( info : SaveInfo ) : UnknownReport return walk(info, false);

	/** borra los bloques desconocidos de la partida (en memoria; guardarla es cosa de quien llama) y dice cuantos eran */
	public static function clear( info : SaveInfo ) : UnknownReport return walk(info, true);

	public static function total( r : UnknownReport ) : Int return r.world + r.ship + r.items;

	static function known( id : Int ) : Bool return id >= 0 && id < Block.all.length;

	static function walk( info : SaveInfo, fix : Bool ) : UnknownReport {
		var r : UnknownReport = { world : 0, ship : 0, items : 0, ids : [] };
		function note( id : Int ) if( r.ids.indexOf(id) < 0 ) r.ids.push(id);
		// casillas (inventario y cantinas): el numero del bloque es k; la casilla se vacia
		function slots( t : Protocol.BlockInventory ) {
			if( t == null ) return;
			for( i in 0...t.length ) {
				var s = t[i];
				if( s == null || known(s.k) ) continue;
				note(s.k);
				r.items += s.n;
				if( fix ) t[i] = null;
			}
		}
		// cambios de celdas: pares [celda, bloque | nivel del agua << 16] (World.applySaved); las claves negativas son del mar
		function edits( e : Array<Int> ) : Int {
			if( e == null ) return 0;
			var n = 0, i = 0;
			while( i + 1 < e.length ) {
				var b = e[i + 1] & 0xFFFF;
				if( e[i] >= 0 && !known(b) ) {
					note(b);
					n++;
					// aire, sin nivel de agua
					if( fix ) e[i + 1] = 0;
				}
				i += 2;
			}
			return n;
		}
		if( info.inv != null ) slots(info.inv.t);
		if( info.chests != null ) for( c in info.chests ) slots(c.t);
		r.world += edits(info.edits);
		if( info.uni != null && info.uni.planets != null ) for( p in info.uni.planets ) r.world += edits(p.edits);
		r.ship += edits(info.shipEdits);
		r.ship += shipCells(info, fix, note);
		// precios del robot comerciante: sin su bloque no sirven de nada (no se cuentan)
		if( fix && info.market != null && info.market.items != null )
			info.market.items = info.market.items.filter(function(it) {
				if( it.key == null || it.key.charAt(0) != "b" ) return true;
				var id = Std.parseInt(it.key.substr(1));
				return id == null || known(id);
			});
		r.ids.sort(function(a, b) return a - b);
		return r;
	}

	/** la nave hecha en el hangar (ShipData: zlib de sx, sy, sz y 2 bytes por celda): sus celdas desconocidas pasan a vacias */
	static function shipCells( info : SaveInfo, fix : Bool, note : Int -> Void ) : Int {
		if( info.shipData == null ) return 0;
		try {
			var raw = haxe.zip.Uncompress.run(haxe.crypto.Base64.decode(info.shipData));
			var cells = raw.get(0) * raw.get(1) * raw.get(2), n = 0;
			for( i in 0...cells ) {
				var p = 3 + i * 2;
				if( p + 1 >= raw.length ) break;
				var id = raw.get(p) | (raw.get(p + 1) << 8);
				if( id == 0 || known(id) ) continue;
				note(id);
				n++;
				if( fix ) {
					raw.set(p, 0);
					raw.set(p + 1, 0);
				}
			}
			if( fix && n > 0 ) info.shipData = haxe.crypto.Base64.encode(haxe.zip.Compress.run(raw, 9));
			return n;
		} catch( e : Dynamic ) {
			// ilegible: Hangar.currentShip ya usa entonces la nave de serie
			return 0;
		}
	}

	/** lo que no es cero, en una linea: "39 en el terreno, 256 en el inventario y las cantinas" */
	public static function where( r : UnknownReport ) : String {
		var parts = [];
		for( p in [{ n : r.world, key : "unknown.world" }, { n : r.ship, key : "unknown.ship" }, { n : r.items, key : "unknown.items" }] )
			if( p.n > 0 ) parts.push(Lang.t(p.key).split("%n%").join("" + p.n));
		return parts.join(", ");
	}

	/** copia la partida (su .json y su miniatura) en saves/backups; devuelve la ruta del .json copiado o null si no se pudo */
	public static function backup( id : String ) : String {
		try {
			var dir = SaveData.dir() + "/" + BACKUPS;
			if( !sys.FileSystem.exists(dir) ) sys.FileSystem.createDirectory(dir);
			// otra copia de la misma partida no pisa la anterior
			var name = id, n = 1;
			while( sys.FileSystem.exists(dir + "/" + name + ".json") ) name = id + "_" + (++n);
			sys.io.File.copy(SaveData.jsonPath(id), dir + "/" + name + ".json");
			if( sys.FileSystem.exists(SaveData.thumbPath(id)) ) sys.io.File.copy(SaveData.thumbPath(id), dir + "/" + name + ".png");
			return dir + "/" + name + ".json";
		} catch( e : Dynamic ) {
			return null;
		}
	}
}
