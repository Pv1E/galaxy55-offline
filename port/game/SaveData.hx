/** Un planeta ya visitado del universo: sus cambios de terreno (los de la nave y el inventario son de toda la partida). */
typedef UniPlanet = {
	var id : Int;
	var edits : Array<Int>;
	/** donde se dejo la nave pilotandola (anadido del port); null = el sitio de aterrizaje de siempre */
	@:optional var shipAt : { x : Int, y : Int };
}

/**
 * Universo de la partida: el sector del mapa de estrellas, el planeta en el que estas y donde esta la nave en el mapa.
 * `start` es el planeta con el que empezo la partida (sistema 0, planeta 0 del mapa).
 */
typedef UniInfo = {
	/** semilla del sector */
	var seed : Int;
	/** id del planeta actual (0 = el inicial) */
	var planetId : Int;
	/** posicion de la nave en el mapa: [0, x, y] en el sector, [1, sistema] en un sistema, [2, planeta] junto a un planeta */
	var pos : Array<Int>;
	var start : { seed : Int, biome : String, size : Int };
	/** planetas visitados distintos del actual, con sus cambios */
	var planets : Array<UniPlanet>;
	/** donde esta el robot comerciante en el sector (anadido del port) */
	@:optional var robot : { x : Float, y : Float };
	/** la partida esta en el espacio (despegaste y no has aterrizado): al cargarla se abre el mapa */
	@:optional var space : Bool;
	/** en el espacio, fuera de un sistema: donde esta la nave en el sector */
	@:optional var ship : { x : Float, y : Float };
	/** distancia recorrida en el mapa (Space.travel; base para el combustible y otras ideas del viaje) */
	@:optional var traveled : Float;
}

/** Tutorial en curso (Tutorial, anadido del port): el paso y los bloques puestos para el en el planeta. */
typedef TutoInfo = {
	var step : Int;
	/** x, y, z y bloque de cada uno, de 4 en 4 (null hasta el primer aterrizaje: TutoSetup.seedPlanet) */
	@:optional var spots : Array<Int>;
}

/** Datos de una partida guardada. Los cambios de terreno, inventario y creditos se anadiran aqui. */
typedef SaveInfo = {
	var version : Int;
	var id : String;
	var name : String;
	var seed : Int;
	var biome : String;
	var sizeChunks : Int;
	var created : Float;
	var saved : Float;
	var playSeconds : Float;
	var px : Float;
	var py : Float;
	var pz : Float;
	var yaw : Float;
	var pitch : Float;
	var fly : Bool;
	/** vida (0..100, Hero.life; se guarda como en el original). Las partidas antiguas no la tienen: 100 */
	@:optional var life : Float;
	/** inventario (null = el inicial del original) */
	@:optional var inv : Protocol.InventoryInfos;
	/** cambios del terreno: pares [celda, bloque global]; con clave negativa, el nivel del mar y su contador (World.SEA_LEVEL) */
	@:optional var edits : Array<Int>;
	/** cambios en la nave (bloques puestos en las zonas de sintetizador, puertas abiertas): igual que edits pero en el volumen de la nave */
	@:optional var shipEdits : Array<Int>;
	/** modo creativo: bloques sin limite, rotura instantanea y jetpack infinito (no existe en el original) */
	@:optional var creative : Bool;
	/** aventura: se eligio jugar el tutorial al crear la partida (null en las partidas antiguas) */
	@:optional var tutorial : Null<Bool>;
	/** universo (mapa de estrellas); las partidas antiguas no lo tienen y se crea al abrir el mapa */
	@:optional var uni : UniInfo;
	/** creditos (tienda del robot comerciante) */
	@:optional var credits : Int;
	/** precios y existencias del robot comerciante (Market) */
	@:optional var market : Market.MarketInfo;
	/** contratos de la ESCorp entregados en el periodo actual (Contracts) */
	@:optional var contracts : Contracts.ContractsInfo;
	/** nave editada en el hangar (zlib en base64); null = la de serie */
	@:optional var shipData : String;
	/** solo mientras se esta en el hangar (no se guarda) */
	@:optional var hangar : Bool;
	/** solo mientras se esta en la nave nodriza (no se guarda) */
	@:optional var mothership : Bool;
	/** contenido de las cantinas (cofres): clave "s:x,y,z" en la nave o "p<planeta>:x,y,z" en un planeta */
	@:optional var chests : Array<{ key : String, t : Protocol.BlockInventory }>;
	/** tutorial en curso (null: sin tutorial, terminado o pasado) */
	@:optional var tuto : TutoInfo;
	/** donde se dejo la nave en el planeta actual pilotandola (anadido del port); null = el sitio de aterrizaje de siempre */
	@:optional var shipAt : { x : Int, y : Int };
}

/** Guardado en disco: %APPDATA%\Galaxy55\saves\<id>.json (+ <id>.png con la miniatura). */
class SaveData {

	public static inline var VERSION = 1;

	public static function dir() : String {
		var d = Settings.dir() + "/saves";
		if( !sys.FileSystem.exists(d) ) sys.FileSystem.createDirectory(d);
		return d;
	}

	public static function newId() : String {
		var d = Date.now();
		var p = function(n : Int) return StringTools.lpad("" + n, "0", 2);
		return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + "_" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds()) + "_" + Std.random(1000);
	}

	/** partida nueva: en creativo con el inventario inicial del original; en aventura con el inventario vacio */
	public static function create( name : String, seed : Int, biome : String, sizeChunks : Int, creative = false ) : SaveInfo {
		var now = Date.now().getTime();
		return {
			version : VERSION, id : newId(), name : name, seed : seed, biome : biome, sizeChunks : sizeChunks,
			created : now, saved : now, playSeconds : 0, px : -1, py : -1, pz : -1, yaw : 0, pitch : 0, fly : false, inv : creative ? Inv.defaults() : Inv.empty(), edits : [], shipEdits : [], creative : creative, credits : Market.START_CREDITS,
		};
	}

	static function readUni( o : Dynamic ) : UniInfo {
		try {
			if( o == null || o.seed == null ) return null;
			return {
				seed : Std.int(o.seed), planetId : Std.int(o.planetId), pos : [for( v in (o.pos : Array<Dynamic>) ) Std.int(v)],
				start : { seed : Std.int(o.start.seed), biome : o.start.biome, size : Std.int(o.start.size) },
				planets : [for( p in (o.planets : Array<Dynamic>) ) { id : Std.int(p.id), edits : [for( v in (p.edits : Array<Dynamic>) ) Std.int(v)], shipAt : readSpot(p.shipAt) }],
				robot : o.robot != null ? { x : (o.robot.x : Float), y : (o.robot.y : Float) } : null,
				space : o.space == true ? true : null,
				ship : o.ship != null ? { x : (o.ship.x : Float), y : (o.ship.y : Float) } : null,
				traveled : o.traveled != null ? (o.traveled : Float) : 0,
			};
		} catch( e : Dynamic ) {
			return null;
		}
	}

	/** sitio de la nave pilotada (anadido del port): null si no hay o no es valido */
	static function readSpot( o : Dynamic ) : { x : Int, y : Int } {
		try {
			if( o == null || o.x == null || o.y == null ) return null;
			return { x : Std.int(o.x), y : Std.int(o.y) };
		} catch( e : Dynamic ) {
			return null;
		}
	}

	static function readMarket( o : Dynamic ) : Market.MarketInfo {
		try {
			if( o == null || o.items == null ) return null;
			return { time : o.time != null ? o.time : 0, items : [for( i in (o.items : Array<Dynamic>) ) { key : Std.string(i.key), bought : i.bought != null ? (i.bought : Float) : null, sold : i.sold != null ? (i.sold : Float) : null }] };
		} catch( e : Dynamic ) {
			return null;
		}
	}

	static function readContracts( o : Dynamic ) : Contracts.ContractsInfo {
		try {
			if( o == null || o.slot == null ) return null;
			return { slot : Std.int(o.slot), done : [for( v in (o.done : Array<Dynamic>) ) Std.int(v)] };
		} catch( e : Dynamic ) {
			return null;
		}
	}

	static function readChests( o : Dynamic ) : Array<{ key : String, t : Protocol.BlockInventory }> {
		try {
			if( o == null ) return [];
			return [for( c in (o : Array<Dynamic>) ) { key : Std.string(c.key), t : [for( s in (c.t : Array<Dynamic>) ) s == null ? null : { k : Std.int(s.k), n : Std.int(s.n) }] }];
		} catch( e : Dynamic ) {
			return [];
		}
	}

	static function readTuto( o : Dynamic ) : TutoInfo {
		try {
			if( o == null || o.step == null ) return null;
			return { step : Std.int(o.step), spots : o.spots != null ? [for( v in (o.spots : Array<Dynamic>) ) Std.int(v)] : null };
		} catch( e : Dynamic ) {
			return null;
		}
	}

	/** inventario guardado; si falta o esta mal formado se usa el inicial */
	static function readInv( o : Dynamic ) : Protocol.InventoryInfos {
		try {
			if( o == null || o.t == null ) return Inv.defaults();
			var inv : Protocol.InventoryInfos = { maxWeight : o.maxWeight != null ? o.maxWeight : 64, t : [], charges : [] };
			for( s in (o.t : Array<Dynamic>) )
				inv.t.push(s == null ? null : { k : Std.int(s.k), n : Std.int(s.n) });
			if( o.charges != null )
				for( c in (o.charges : Array<Dynamic>) )
					inv.charges.push({ c : Std.int(c.c), n : Std.int(c.n) });
			return inv;
		} catch( e : Dynamic ) {
			return Inv.defaults();
		}
	}

	public static function jsonPath( id : String ) return dir() + "/" + id + ".json";
	public static function thumbPath( id : String ) return dir() + "/" + id + ".png";

	public static function list() : Array<SaveInfo> {
		var out = [];
		for( f in sys.FileSystem.readDirectory(dir()) ) {
			if( !StringTools.endsWith(f, ".json") ) continue;
			var info = read(f.substr(0, f.length - 5));
			if( info != null ) out.push(info);
		}
		out.sort(function(a, b) return a.saved < b.saved ? 1 : (a.saved > b.saved ? -1 : 0));
		return out;
	}

	public static function read( id : String ) : SaveInfo {
		try {
			var o : Dynamic = haxe.Json.parse(sys.io.File.getContent(jsonPath(id)));
			if( o.version == null || o.seed == null || o.biome == null ) return null;
			return {
				version : o.version, id : id, name : o.name != null ? o.name : id, seed : o.seed, biome : o.biome,
				sizeChunks : o.sizeChunks != null ? o.sizeChunks : 1,
				created : o.created != null ? o.created : 0, saved : o.saved != null ? o.saved : 0,
				playSeconds : o.playSeconds != null ? o.playSeconds : 0,
				px : o.px != null ? o.px : -1, py : o.py != null ? o.py : -1, pz : o.pz != null ? o.pz : -1,
				yaw : o.yaw != null ? o.yaw : 0, pitch : o.pitch != null ? o.pitch : 0, fly : o.fly == true, life : o.life != null ? o.life : 100,
					creative : o.creative == true, tutorial : o.tutorial == null ? null : o.tutorial == true, inv : readInv(o.inv), uni : readUni(o.uni), credits : o.credits != null ? Std.int(o.credits) : Market.START_CREDITS, market : readMarket(o.market), contracts : readContracts(o.contracts), chests : readChests(o.chests), shipData : o.shipData,
					shipEdits : o.shipEdits != null ? [for( v in (o.shipEdits : Array<Dynamic>) ) Std.int(v)] : [], edits : o.edits != null ? [for( v in (o.edits : Array<Dynamic>) ) Std.int(v)] : [],
					tuto : readTuto(o.tuto), shipAt : readSpot(o.shipAt),
			};
		} catch( e : Dynamic ) {
			return null;
		}
	}

	/** Escribe la partida; se guarda primero a un archivo temporal para no corromperla si falla a medias.
	    touch = false deja la fecha de guardado como estaba (renombrar no cambia el orden de la lista). */
	public static function write( info : SaveInfo, thumbPng : haxe.io.Bytes, touch = true ) : Bool {
		try {
			if( touch ) info.saved = Date.now().getTime();
			var path = jsonPath(info.id);
			sys.io.File.saveContent(path + ".tmp", haxe.Json.stringify(info, null, "  "));
			if( sys.FileSystem.exists(path) ) sys.FileSystem.deleteFile(path);
			sys.FileSystem.rename(path + ".tmp", path);
			if( thumbPng != null ) sys.io.File.saveBytes(thumbPath(info.id), thumbPng);
			return true;
		} catch( e : Dynamic ) {
			return false;
		}
	}

	/** cambia solo el nombre de la partida: la fecha de guardado y la miniatura no se tocan */
	public static function rename( id : String, name : String ) : Bool {
		var info = read(id);
		if( info == null ) return false;
		info.name = name;
		return write(info, null, false);
	}

	public static function delete( id : String ) {
		try {
			if( sys.FileSystem.exists(jsonPath(id)) ) sys.FileSystem.deleteFile(jsonPath(id));
			if( sys.FileSystem.exists(thumbPath(id)) ) sys.FileSystem.deleteFile(thumbPath(id));
		} catch( e : Dynamic ) {}
	}

	public static function thumb( id : String ) : haxe.io.Bytes {
		var p = thumbPath(id);
		return sys.FileSystem.exists(p) ? sys.io.File.getBytes(p) : null;
	}
}
