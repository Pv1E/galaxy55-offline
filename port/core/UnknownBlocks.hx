import SaveData.SaveInfo;

/** Cuantos bloques desconocidos tiene una partida y donde (UnknownBlocks). */
typedef UnknownReport = {
	/** celdas del terreno (el planeta actual y los ya visitados) y bloques del tutorial */
	var world : Int;
	/** celdas de la nave: los cambios a bordo y la nave hecha en el hangar */
	var ship : Int;
	/** bloques del inventario, de las cantinas, del stockage de la nave y del equipo dejado, y cargas desconocidas (unidades) */
	var items : Int;
	/** nombres desconocidos, en orden */
	var names : Array<String>;
}

/**
 * Bloques que esta version no conoce (anadido del port), por su nombre: los de una partida guardada por una version con mas
 * bloques. Al leerla pasan a bloques de remplazo (SaveNames) que se vuelven a escribir con su nombre: no se pierden aunque se
 * juegue y se guarde. Al elegirla en la lista se cuentan (count) y se avisa (GalaxyApp.playSave). Los kubes del editor que no
 * estan cargados no cuentan (vuelven al cargar su archivo). Las cargas desconocidas si se quitan al leerla (no hay donde ponerlas).
 */
class UnknownBlocks {

	/** subcarpeta de las partidas con las copias (los .json de antes, al migrarlos: SaveData.migrate) */
	public static inline var BACKUPS = "backups";

	public static function total( r : UnknownReport ) : Int return r.world + r.ship + r.items;

	/** cuantos bloques desconocidos tiene la partida (no la cambia) */
	public static function count( info : SaveInfo ) : UnknownReport {
		var r : UnknownReport = { world : 0, ship : 0, items : 0, names : [] };
		function unknown( k : Int ) : Bool {
			var b = Block.all[k];
			if( !SaveNames.isUnknown(b) ) return false;
			var n = SaveNames.placeholderName(b);
			if( r.names.indexOf(n) < 0 ) r.names.push(n);
			return true;
		}
		function slots( t : Protocol.BlockInventory ) {
			if( t != null ) for( s in t ) if( s != null && unknown(s.k) ) r.items += s.n;
		}
		if( info.inv != null ) slots(info.inv.t);
		if( info.chests != null ) for( c in info.chests ) slots(c.t);
		if( info.storage != null ) slots(info.storage.t);
		if( info.deathDrops != null ) for( d in info.deathDrops ) slots(d.t);
		// celdas, nave del hangar y bloques del tutorial (las casillas ya se han contado por unidades)
		SaveNames.mapBlocks(info, function(k, where) {
			if( where == "items" ) return k;
			if( unknown(k) ) {
				if( where == "ship" ) r.ship++ else r.world++;
			}
			return k;
		});
		if( info.unknownCharges != null ) r.items += info.unknownCharges;
		r.names.sort(Reflect.compare);
		return r;
	}

	/** lo que no es cero, en una linea: "39 en el terreno, 256 en el inventario y las cantinas" */
	public static function where( r : UnknownReport ) : String {
		var parts = [];
		for( p in [{ n : r.world, key : "unknown.world" }, { n : r.ship, key : "unknown.ship" }, { n : r.items, key : "unknown.items" }] )
			if( p.n > 0 ) parts.push(Lang.t(p.key).split("%n%").join("" + p.n));
		return parts.join(", ");
	}
}
