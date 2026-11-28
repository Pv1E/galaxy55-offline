import SaveArchive.SaveError;

/** Un planeta ya visitado del universo: sus cambios de terreno (los de la nave y el inventario son de toda la partida). */
typedef UniPlanet = {
	var id : Int;
	var edits : Array<Int>;
	/** donde se dejo la nave pilotandola (anadido del port); null = el sitio de aterrizaje de siempre */
	@:optional var shipAt : { x : Int, y : Int };
	/** version del generador del planeta (anadido del port, SaveInfo.genVersion); null = 0 */
	@:optional var genVersion : Null<Int>;
	/**
	 * semilla, bioma y tamano con los que se genero (anadido del port, en su cabecera de SaveArchive): al volver se generan con
	 * ellos y no con los del mapa, asi sus celdas guardadas no se mezclan si el universo cambiara. null en los de antes
	 */
	@:optional var seed : Null<Int>;
	@:optional var biome : String;
	@:optional var size : Null<Int>;
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
	/** licencias de la ESCorp (Licenses, anadido del port): planetas escaneados, el principal incluido */
	@:optional var licenses : Array<Int>;
	/** planeta principal; null = aun ninguno (antes del primer escaneo o con el tutorial en curso) */
	@:optional var main : Null<Int>;
	/** hora real (s) del ultimo cambio de planeta principal y cuantos cambios se han hecho (el primero es gratis) */
	@:optional var mainTime : Null<Float>;
	@:optional var mainChanges : Null<Int>;
	/** planetas abandonados: ya no se puede ir a ellos */
	@:optional var abandoned : Array<Int>;
	/** sistemas que desaparecieron (todos sus planetas abandonados), en orden: cada uno dejo otro cerca (ExpOffline.replaceSystem) */
	@:optional var gone : Array<Int>;
	/** cometas ya visitadas (Comets, añadido del port): pares [sistema, franja] */
	@:optional var comets : Array<Int>;
}

/** Cometa en la que estas (Comets, añadido del port): su sistema, su franja y los segundos que quedan en ella. */
typedef CometInfo = {
	var sys : Int;
	var slot : Int;
	var left : Float;
}

/** Tutorial en curso (Tutorial, anadido del port): el paso y los bloques puestos para el en el planeta. */
typedef TutoInfo = {
	var step : Int;
	/** x, y, z y bloque de cada uno, de 4 en 4 (null hasta el primer aterrizaje: TutoSetup.seedPlanet) */
	@:optional var spots : Array<Int>;
}

/** donde estaba el jugador dentro de la nave nodriza al guardar (SaveInfo.inMother) */
typedef MotherPos = { x : Float, y : Float, z : Float, yaw : Float, pitch : Float };

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
	/** version del juego que creo la partida (GameVersion.VERSION, anadido del port); null en las partidas de antes */
	@:optional var createdWith : String;
	/** version del juego que la guardo por ultima vez (va con saved); null si no se ha guardado desde entonces */
	@:optional var savedWith : String;
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
	/**
	 * version del generador del planeta actual (anadido del port, gen.Generator.VERSION): la que habia al visitarlo por primera
	 * vez, para que el terreno bajo edits no cambie. null = 0 (las partidas de antes, generadas como la version 0)
	 */
	@:optional var genVersion : Null<Int>;
	/** cambios en la nave (bloques puestos en las zonas de sintetizador, puertas abiertas): igual que edits pero en el volumen de la nave */
	@:optional var shipEdits : Array<Int>;
	/** modo creativo: bloques sin limite, rotura instantanea y jetpack infinito (no existe en el original) */
	@:optional var creative : Bool;
	/** partida creativa jugada ahora en supervivencia (GameView.setSurvival, anadido del port); null = en creativo */
	@:optional var survival : Null<Bool>;
	/** aventura: se eligio jugar el tutorial al crear la partida (null en las partidas antiguas) */
	@:optional var tutorial : Null<Bool>;
	/** universo (mapa de estrellas); las partidas antiguas no lo tienen y se crea al abrir el mapa */
	@:optional var uni : UniInfo;
	/** creditos (tienda del robot comerciante) */
	@:optional var credits : Int;
	/** precios y existencias del robot comerciante (Market) */
	@:optional var market : Market.MarketInfo;
	/** contratos de la ESCorp: lineas entregadas y abandonadas en el periodo actual, y contratos en curso (Contracts) */
	@:optional var contracts : Contracts.ContractsInfo;
	/** contrato especial de la ESCorp (Contracts, anadido del port); null = sin empezar (y en las partidas antiguas) */
	@:optional var special : Contracts.SpecialInfo;
	/** mejoras de la ESCorp desbloqueadas (EscorpUpgrades, anadido del port): sus id; null = ninguna (y en las partidas de antes) */
	@:optional var upgrades : Array<String>;
	/** nave editada en el hangar (zlib en base64); null = la de serie */
	@:optional var shipData : String;
	/** solo mientras se esta en el hangar (no se guarda) */
	@:optional var hangar : Bool;
	/** solo mientras se esta en la nave nodriza (no se guarda) */
	@:optional var mothership : Bool;
	/**
	 * se guardo estando dentro de la nave nodriza (la partida es la del espacio, acoplada al robot): donde estaba el jugador. Al
	 * cargarla se vuelve a entrar y se aparece ahi
	 */
	@:optional var inMother : MotherPos;
	/** contenido de las cantinas (cofres): clave "s:x,y,z" en la nave o "p<planeta>:x,y,z" en un planeta */
	@:optional var chests : Array<{ key : String, t : Protocol.BlockInventory }>;
	/** equipo dejado al morir o con Mayus+K (DeathDrops, anadido del port): un Conteneur ESCorp pequeno en el sitio, sin caducar */
	@:optional var deathDrops : Array<DeathDrops.DeathDropInfo>;
	/** opcion de la partida (Nueva partida > Personalizar, Continuar > Modificar): false = morir y Mayus+K no dejan el equipo en
	    el suelo; null en las partidas de antes = si lo dejan (DeathDrops.enabled) */
	@:optional var dropOnDeath : Null<Bool>;
	/** tutorial en curso (null: sin tutorial, terminado o pasado) */
	@:optional var tuto : TutoInfo;
	/** donde se dejo la nave en el planeta actual pilotandola (anadido del port); null = el sitio de aterrizaje de siempre */
	@:optional var shipAt : { x : Int, y : Int };
	/** cometa en la que estas (añadido del port); null en un planeta o en el espacio */
	@:optional var comet : CometInfo;
	/** lo que sabe la Base de datos ESCorp (Kubindex, añadido del port); null en las partidas antiguas */
	@:optional var kub : Kubindex.KubInfo;
	/** stockage de la nave (ShipStorage, anadido del port): bloques y cargas guardados; null = aun vacio (y en las partidas de antes) */
	@:optional var storage : StorageData.StorageInfo;
	/**
	 * Kubes del editor de kubes por su archivo (KubeSaveData, anadido del port para el multijugador): solo en la partida que el
	 * anfitrion lleva a su servidor (EditorKubes.encodeForServer, ServerWorlds.importHost), donde los campos de siempre tienen aire o
	 * una casilla vacia en su sitio. No va en los archivos: alli los kubes van por su nombre (SaveNames)
	 */
	@:optional var editorKubes : KubeSaveData.EditorKubesSave;
	/** cargas que esta version no conoce, quitadas al leer la partida (no se guarda: UnknownBlocks las cuenta) */
	@:optional var unknownCharges : Int;
	/**
	 * Solo en la lista de partidas (SaveData.list, no se guarda): la partida no se ha leido entera (listOnly: lo de meta.json);
	 * en el espacio (inSpace); generada en parte con un generador anterior (oldGeneration); no se puede leer (unreadable: por que);
	 * todavia es un .json de antes (legacy)
	 */
	@:optional var listOnly : Bool;
	@:optional var inSpace : Bool;
	@:optional var oldGeneration : Bool;
	@:optional var unreadable : String;
	@:optional var legacy : Bool;
}

/**
 * Guardado en disco: %APPDATA%\Galaxy55\saves\<id>.g55 (SaveArchive: un zip con la partida, su miniatura y los cambios de cada
 * planeta, los bloques por su nombre). Las partidas de antes (<id>.json y <id>.png, con numeros de bloque) se migran al leerlas
 * (migrate): el .json y su .png pasan a saves/backups.
 */
class SaveData {

	public static inline var VERSION = 1;

	/**
	 * Multijugador (anadido del port): la partida que el juego manda a su servidor (CSaveRecord). El juego pone
	 * EditorKubes.encodeForServer (los kubes del editor van aparte, por su archivo); sin el juego (pruebas de red), la misma
	 */
	public static var serverEncode : SaveInfo -> SaveInfo = function( i ) return i;

	/** por que fallo la ultima escritura (write, edit), para el aviso */
	public static var lastError(default, null) : String;

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
			created : now, saved : now, createdWith : GameVersion.VERSION, savedWith : GameVersion.VERSION, playSeconds : 0, px : -1, py : -1, pz : -1, yaw : 0, pitch : 0, fly : false, inv : creative ? Inv.defaults() : Inv.empty(), edits : [], shipEdits : [], creative : creative, credits : Market.START_CREDITS,
			genVersion : gen.Generator.VERSION,
		};
	}

	/**
	 * Una partida de un generador que ya no existe (anadido del port): un planeta suyo (el actual o uno ya visitado) es de una
	 * version anterior a gen.Generator.MIN_VERSION. Se genera con esa: sus cambios siguen, pero el terreno de alrededor puede
	 * no cuadrar. La lista la marca ("Ancienne partie") y se avisa cada vez que se abre (GalaxyApp.playSave). Un planeta de una
	 * version que sigue (de MIN_VERSION a VERSION) se genera con la suya: no cuenta
	 */
	public static function isOldGeneration( info : SaveInfo ) : Bool {
		if( genVersion(info.genVersion) < gen.Generator.MIN_VERSION ) return true;
		if( info.uni != null && info.uni.planets != null )
			for( p in info.uni.planets ) if( genVersion(p.genVersion) < gen.Generator.MIN_VERSION ) return true;
		return false;
	}

	/** version del generador guardada (SaveInfo.genVersion, UniPlanet.genVersion, tambien recien leida del json): null = 0 */
	public static function genVersion( v : Dynamic ) : Int {
		return v == null ? 0 : Std.int(v);
	}

	public static function archivePath( id : String ) return dir() + "/" + id + ".g55";
	/** las partidas de antes */
	public static function jsonPath( id : String ) return dir() + "/" + id + ".json";
	public static function thumbPath( id : String ) return dir() + "/" + id + ".png";
	public static function backupDir() : String {
		var d = dir() + "/" + UnknownBlocks.BACKUPS;
		if( !sys.FileSystem.exists(d) ) sys.FileSystem.createDirectory(d);
		return d;
	}

	// ---------------------------------------------------------------- lectura de los campos (los dos formatos)

	/** lee un campo; si esta pero no se entiende, error con su nombre (antes se ponia uno por defecto sin decir nada) */
	static function field<T>( name : String, f : Void -> T ) : T {
		try {
			return f();
		} catch( e : SaveError ) {
			throw new SaveError(name + ": " + e.msg);
		} catch( e : Dynamic ) {
			throw new SaveError(name + " mal formado (" + Std.string(e) + ")");
		}
	}

	static inline function int( v : Dynamic ) : Int {
		if( !Std.isOfType(v, Int) && !Std.isOfType(v, Float) ) throw "numero esperado";
		return Std.int(v);
	}

	static inline function num( v : Dynamic ) : Float {
		if( !Std.isOfType(v, Int) && !Std.isOfType(v, Float) ) throw "numero esperado";
		return (v : Float);
	}

	static inline function arr( v : Dynamic ) : Array<Dynamic> {
		if( !Std.isOfType(v, Array) ) throw "lista esperada";
		return v;
	}

	/** lista de enteros guardada; null si no la hay */
	static function ints( o : Dynamic ) : Array<Int> {
		return o == null ? null : [for( v in arr(o) ) int(v)];
	}

	static function readUni( o : Dynamic ) : UniInfo {
		if( o == null ) return null;
		if( o.seed == null || o.planetId == null || o.pos == null || o.start == null || o.planets == null ) throw "faltan seed, planetId, pos, start o planets";
		return {
			seed : int(o.seed), planetId : int(o.planetId), pos : ints(o.pos),
			start : { seed : int(o.start.seed), biome : Std.string(o.start.biome), size : int(o.start.size) },
			planets : [for( p in arr(o.planets) ) {
				id : int(p.id), edits : ints(p.edits), shipAt : readSpot(p.shipAt), genVersion : genVersion(p.genVersion),
				seed : p.seed != null ? int(p.seed) : null, biome : p.biome != null ? Std.string(p.biome) : null, size : p.size != null ? int(p.size) : null,
			}],
			robot : o.robot != null ? { x : num(o.robot.x), y : num(o.robot.y) } : null,
			space : o.space == true ? true : null,
			ship : o.ship != null ? { x : num(o.ship.x), y : num(o.ship.y) } : null,
			traveled : o.traveled != null ? num(o.traveled) : 0,
			licenses : ints(o.licenses),
			main : o.main != null ? int(o.main) : null,
			mainTime : o.mainTime != null ? num(o.mainTime) : null,
			mainChanges : o.mainChanges != null ? int(o.mainChanges) : 0,
			abandoned : ints(o.abandoned),
			gone : ints(o.gone),
			comets : ints(o.comets),
		};
	}

	/** donde estaba el jugador al guardar dentro de la nave nodriza: null si no estaba dentro */
	static function readMotherPos( o : Dynamic ) : MotherPos {
		if( o == null ) return null;
		return { x : num(o.x), y : num(o.y), z : num(o.z), yaw : o.yaw != null ? num(o.yaw) : 0, pitch : o.pitch != null ? num(o.pitch) : 0 };
	}

	/** sitio de la nave pilotada (anadido del port): null si no hay */
	static function readSpot( o : Dynamic ) : { x : Int, y : Int } {
		if( o == null ) return null;
		return { x : int(o.x), y : int(o.y) };
	}

	static function readMarket( o : Dynamic ) : Market.MarketInfo {
		if( o == null ) return null;
		return { time : o.time != null ? num(o.time) : 0, items : [for( i in arr(o.items) ) { key : Std.string(i.key), bought : i.bought != null ? num(i.bought) : null, sold : i.sold != null ? num(i.sold) : null }] };
	}

	/** contratos de la ESCorp; las partidas antiguas no tienen ni abandonados ni contratos en curso, y un contrato en curso de un
	    bloque que ya no existe se salta (su bloque va por nombre) */
	static function readContracts( o : Dynamic ) : Contracts.ContractsInfo {
		if( o == null ) return null;
		var active : Array<Contracts.ActiveContract> = [];
		if( o.active != null )
			for( a in arr(o.active) ) {
				if( a.block == null || a.n == null || a.reward == null ) throw "contrato en curso sin block, n o reward";
				if( Contracts.kindOf(Std.string(a.block)) == null ) continue;
				active.push({ block : Std.string(a.block), n : int(a.n), reward : int(a.reward), given : a.given != null ? int(a.given) : 0,
					slot : a.slot != null ? int(a.slot) : 0, index : a.index != null ? int(a.index) : -1 });
			}
		return { slot : int(o.slot), done : o.done != null ? ints(o.done) : [], abandoned : o.abandoned != null ? ints(o.abandoned) : [], active : active };
	}

	/** contrato especial; null si no hay */
	static function readSpecial( o : Dynamic ) : Contracts.SpecialInfo {
		if( o == null ) return null;
		return { given : o.given != null ? int(o.given) : 0, done : o.done == true };
	}

	static function strs( o : Dynamic ) : Array<String> {
		return o == null ? null : [for( v in arr(o) ) Std.string(v)];
	}

	static function readSlots( o : Dynamic ) : Protocol.BlockInventory {
		return [for( s in arr(o) ) s == null ? null : { k : int(s.k), n : int(s.n) }];
	}

	static function readCharges( o : Dynamic ) : Protocol.UserCharges {
		return o == null ? [] : [for( c in arr(o) ) { c : int(c.c), n : int(c.n) }];
	}

	static function readChests( o : Dynamic ) : Array<{ key : String, t : Protocol.BlockInventory }> {
		if( o == null ) return [];
		return [for( c in arr(o) ) { key : Std.string(c.key), t : readSlots(c.t) }];
	}

	static function readComet( o : Dynamic ) : CometInfo {
		if( o == null ) return null;
		return { sys : int(o.sys), slot : int(o.slot), left : o.left != null ? num(o.left) : 0 };
	}

	/** Base de datos ESCorp guardada; lo que falte se deja vacio */
	static function readKub( o : Dynamic ) : Kubindex.KubInfo {
		var k = Kubindex.empty();
		if( o == null ) return k;
		inline function list( a : Dynamic ) : Array<String> return a == null ? [] : strs(a);
		k.seen = list(o.seen);
		k.got = list(o.got);
		k.fresh = list(o.fresh);
		if( o.stats != null )
			k.stats = [for( s in arr(o.stats) ) {
				var st : Kubindex.KubStat = { k : Std.string(s.k), p : int(s.p), b : int(s.b) };
				if( s.r != null ) st.r = int(s.r);
				st;
			}];
		if( o.planets != null ) k.planets = [for( p in arr(o.planets) ) { id : int(p.id), b : Std.string(p.b) }];
		if( o.comets != null ) k.comets = [for( c in arr(o.comets) ) { sys : int(c.sys), slot : int(c.slot), b : Std.string(c.b) }];
		if( o.crafts != null ) k.crafts = [for( c in arr(o.crafts) ) { id : int(c.id), n : int(c.n) }];
		k.anomalies = list(o.anomalies);
		return k;
	}

	static function readTuto( o : Dynamic ) : TutoInfo {
		if( o == null ) return null;
		return { step : int(o.step), spots : ints(o.spots) };
	}

	/** inventario guardado; si falta (partidas de antes del inventario), el inicial */
	static function readInv( o : Dynamic ) : Protocol.InventoryInfos {
		if( o == null ) return Inv.defaults();
		return { maxWeight : o.maxWeight != null ? int(o.maxWeight) : 64, t : readSlots(o.t), charges : readCharges(o.charges) };
	}

	static function readStorage( o : Dynamic ) : StorageData.StorageInfo {
		if( o == null ) return null;
		var s = StorageData.empty();
		var t = readSlots(o.t);
		for( i in 0...t.length ) {
			var v = t[i];
			if( v == null || v.n <= 0 ) continue;
			if( i < s.t.length ) s.t[i] = v else s.t.push(v);
		}
		s.charges = [for( c in readCharges(o.charges) ) if( c.n > 0 ) c];
		return s;
	}

	static function readDrops( o : Dynamic ) : Array<DeathDrops.DeathDropInfo> {
		if( o == null ) return null;
		var out = [];
		for( d in arr(o) ) {
			if( d.key == null || d.t == null ) throw "equipo dejado sin key o t";
			out.push({ id : d.id != null ? int(d.id) : out.length + 1, key : Std.string(d.key), x : num(d.x), y : num(d.y), z : num(d.z),
				t : readSlots(d.t), charges : readCharges(d.charges) });
		}
		return out;
	}

	/**
	 * Una partida de un objeto JSON: el game.json de un archivo o un .json de antes. Los numeros de bloque y de carga quedan como
	 * estan (posiciones en las tablas o indices de antes): los cambia quien llama. Un campo que falta toma su valor de siempre
	 * (partidas de antes); uno que esta y no se entiende es un error con su nombre
	 */
	public static function fromObject( o : Dynamic, id : String ) : SaveInfo {
		if( o == null || o.version == null || o.seed == null || o.biome == null ) throw new SaveError("faltan version, seed o biome");
		var uni = field("uni", function() return readUni(o.uni));
		var tuto = field("tuto", function() return readTuto(o.tuto));
		if( uni != null ) Licenses.migrate(uni, tuto != null);
		return field("partida", function() : SaveInfo return {
			version : int(o.version), id : id, name : o.name != null ? Std.string(o.name) : id, seed : int(o.seed), biome : Std.string(o.biome),
			sizeChunks : o.sizeChunks != null ? int(o.sizeChunks) : 1,
			created : o.created != null ? num(o.created) : 0, saved : o.saved != null ? num(o.saved) : 0,
			createdWith : o.createdWith != null ? Std.string(o.createdWith) : null, savedWith : o.savedWith != null ? Std.string(o.savedWith) : null,
			playSeconds : o.playSeconds != null ? num(o.playSeconds) : 0,
			px : o.px != null ? num(o.px) : -1, py : o.py != null ? num(o.py) : -1, pz : o.pz != null ? num(o.pz) : -1,
			yaw : o.yaw != null ? num(o.yaw) : 0, pitch : o.pitch != null ? num(o.pitch) : 0, fly : o.fly == true, life : o.life != null ? num(o.life) : 100,
			creative : o.creative == true, tutorial : o.tutorial == null ? null : o.tutorial == true,
			inv : field("inv", function() return readInv(o.inv)), uni : uni,
			credits : o.credits != null ? int(o.credits) : Market.START_CREDITS,
			market : field("market", function() return readMarket(o.market)),
			contracts : field("contracts", function() return readContracts(o.contracts)),
			special : field("special", function() return readSpecial(o.special)),
			chests : field("chests", function() return readChests(o.chests)),
			shipData : o.shipData != null ? Std.string(o.shipData) : null,
			upgrades : field("upgrades", function() return strs(o.upgrades)),
			shipEdits : field("shipEdits", function() return o.shipEdits != null ? ints(o.shipEdits) : []),
			edits : field("edits", function() return o.edits != null ? ints(o.edits) : []),
			genVersion : genVersion(o.genVersion),
			deathDrops : field("deathDrops", function() return readDrops(o.deathDrops)), dropOnDeath : o.dropOnDeath != false,
			survival : o.creative == true && o.survival == true ? true : null,
			tuto : tuto, shipAt : field("shipAt", function() return readSpot(o.shipAt)), comet : field("comet", function() return readComet(o.comet)),
			kub : field("kub", function() return readKub(o.kub)),
			inMother : field("inMother", function() return readMotherPos(o.inMother)),
			storage : field("storage", function() return readStorage(o.storage)),
		});
	}

	/**
	 * Multijugador (anadido del port): la partida de un JSON del servidor (la de cada jugador, la que manda al juego, la que el
	 * juego le manda) con sus numeros de bloque tal cual, y los kubes del editor que traiga aparte (editorKubes); null si no es
	 * una partida o algo esta mal formado
	 */
	public static function parse( o : Dynamic, id : String ) : SaveInfo {
		try {
			var info = fromObject(o, id);
			if( o.editorKubes != null ) info.editorKubes = KubeSaveData.read(o.editorKubes);
			return info;
		} catch( e : Dynamic ) {
			return null;
		}
	}

	// ---------------------------------------------------------------- lista

	/** una fila de la lista desde meta.json (SaveArchive.meta) */
	static function fromMeta( m : Dynamic, id : String ) : SaveInfo {
		return {
			version : VERSION, id : id, name : Std.string(m.name), seed : int(m.seed), biome : Std.string(m.biome), sizeChunks : int(m.sizeChunks),
			created : num(m.created), saved : num(m.saved), createdWith : m.createdWith, savedWith : m.savedWith,
			playSeconds : num(m.playSeconds), px : -1, py : -1, pz : -1, yaw : 0, pitch : 0, fly : false,
			creative : m.creative == true, survival : m.survival == true ? true : null, dropOnDeath : m.dropOnDeath != false,
			inSpace : m.space == true, oldGeneration : m.oldGeneration == true, listOnly : true,
		};
	}

	/** una fila de una partida que no se puede leer: con su fecha de archivo para ordenarla */
	static function unreadable( id : String, path : String, why : String ) : SaveInfo {
		var t = try sys.FileSystem.stat(path).mtime.getTime() catch( e : Dynamic ) 0.;
		return {
			version : VERSION, id : id, name : id, seed : 0, biome : "BIAutumn", sizeChunks : 1, created : t, saved : t, playSeconds : 0,
			px : -1, py : -1, pz : -1, yaw : 0, pitch : 0, fly : false, listOnly : true, unreadable : why,
		};
	}

	/**
	 * Las partidas de la carpeta, de la mas reciente a la mas antigua: de cada .g55 solo meta.json (SaveArchive.readParts); los
	 * .json de antes, enteros (todavia no migrados). Si hay un .g55 y un .json con el mismo id, el .g55. Una que no se puede leer
	 * sale igual, como ilegible (unreadable). Para jugarla, read(id)
	 */
	public static function list() : Array<SaveInfo> {
		var out = [], ids = new Map<String, Bool>();
		var files = try sys.FileSystem.readDirectory(dir()) catch( e : Dynamic ) [];
		// tambien las que solo tienen .g55.tmp o .g55.bak: un guardado cortado entre los dos renombres (SaveArchive.writeFile)
		var archives = [];
		for( f in files )
			for( ext in [".g55", ".g55.tmp", ".g55.bak"] )
				if( StringTools.endsWith(f, ext) ) {
					var id = f.substr(0, f.length - ext.length);
					if( !ids.exists(id) ) archives.push(id);
					ids.set(id, true);
				}
		for( id in archives ) {
			var path = archivePath(id);
			try {
				// con un .tmp (guardado sin terminar) o sin .g55, la que se leera al jugarla (SaveArchive.recover): el archivo entero
				var meta = null;
				if( sys.FileSystem.exists(path) && !sys.FileSystem.exists(path + ".tmp") )
					meta = try SaveArchive.readParts(path, ["meta.json"]).get("meta.json") catch( e : SaveError ) null;
				if( meta == null ) {
					var b = SaveArchive.recover(path, false);
					if( b == null ) throw new SaveError("ni la partida ni sus copias (.tmp, .bak) se pueden leer");
					meta = SaveArchive.data(b, SaveArchive.find(SaveArchive.items(b), "meta.json"));
				}
				var m : Dynamic = haxe.Json.parse(meta.toString());
				out.push(fromMeta(m, id));
			} catch( e : Dynamic ) {
				out.push(unreadable(id, path, Std.string(e)));
			}
		}
		for( f in files ) {
			if( !StringTools.endsWith(f, ".json") ) continue;
			var id = f.substr(0, f.length - 5);
			if( ids.exists(id) ) continue;
			try {
				var info = readLegacy(jsonPath(id), id, SaveNames.lineage());
				info.listOnly = true;
				info.legacy = true;
				info.oldGeneration = isOldGeneration(info);
				info.inSpace = info.uni != null && info.uni.space == true;
				out.push(info);
			} catch( e : Dynamic ) {
				out.push(unreadable(id, jsonPath(id), Std.string(e)));
			}
		}
		out.sort(function(a, b) return a.saved < b.saved ? 1 : (a.saved > b.saved ? -1 : 0));
		return out;
	}

	// ---------------------------------------------------------------- lectura y escritura

	/**
	 * La partida entera (para jugarla): del .g55, o del .tmp / .bak si el ultimo guardado no acabo (SaveArchive.recover); una de
	 * antes (.json) se migra ahora. null si no se puede leer (lastError dice por que)
	 */
	public static function read( id : String ) : SaveInfo {
		lastError = null;
		try {
			var path = archivePath(id);
			var exists = sys.FileSystem.exists(path) || sys.FileSystem.exists(path + ".tmp") || sys.FileSystem.exists(path + ".bak");
			if( !exists ) return sys.FileSystem.exists(jsonPath(id)) ? migrate(id, SaveNames.lineage()) : null;
			var b = sys.FileSystem.exists(path + ".tmp") ? null : (try sys.io.File.getBytes(path) catch( e : Dynamic ) null);
			var info = b == null ? null : try SaveArchive.decode(b, id) catch( e : SaveError ) null;
			if( info == null ) {
				var r = SaveArchive.recover(path, true);
				if( r == null ) throw new SaveError("ni la partida ni sus copias (.tmp, .bak) se pueden leer");
				info = SaveArchive.decode(r, id);
			}
			return info;
		} catch( e : Dynamic ) {
			lastError = Std.string(e);
			return null;
		}
	}

	/**
	 * La partida entera sin migrarla (pruebas: print saves, print unknown): una de antes (.json) se lee con la tabla de este juego y
	 * se queda como esta. null si no se puede leer (lastError)
	 */
	public static function peek( id : String ) : SaveInfo {
		var a = archivePath(id);
		if( sys.FileSystem.exists(a) || sys.FileSystem.exists(a + ".tmp") || sys.FileSystem.exists(a + ".bak") || !sys.FileSystem.exists(jsonPath(id)) )
			return read(id);
		lastError = null;
		try {
			return readLegacy(jsonPath(id), id, SaveNames.lineage());
		} catch( e : Dynamic ) {
			lastError = Std.string(e);
			return null;
		}
	}

	/**
	 * Escribe la partida (SaveArchive.writeFile: sin perder la anterior si falla). thumbPng null deja la miniatura que tenia.
	 * touch = false deja la fecha y la version de guardado como estaban (renombrar no cambia el orden de la lista). false si no se
	 * pudo (lastError dice por que)
	 */
	public static function write( info : SaveInfo, thumbPng : haxe.io.Bytes, touch = true ) : Bool {
		lastError = null;
		try {
			if( touch ) {
				info.saved = Date.now().getTime();
				info.savedWith = GameVersion.VERSION;
			}
			var path = archivePath(info.id);
			var keep = sys.FileSystem.exists(path) ? (try sys.io.File.getBytes(path) catch( e : Dynamic ) null) : null;
			if( thumbPng == null && keep == null && sys.FileSystem.exists(thumbPath(info.id)) ) thumbPng = sys.io.File.getBytes(thumbPath(info.id));
			SaveArchive.writeFile(path, SaveArchive.encode(info, thumbPng, keep));
			return true;
		} catch( e : Dynamic ) {
			lastError = Std.string(e);
			return false;
		}
	}

	/**
	 * Continuar > Modificar: cambia el nombre y las opciones de la partida; la fecha de guardado, la miniatura y los planetas no se
	 * tocan (SaveArchive.rewrite: se copian tal cual)
	 */
	public static function edit( id : String, name : String, dropOnDeath : Bool ) : Bool {
		lastError = null;
		try {
			var path = archivePath(id);
			if( !sys.FileSystem.exists(path) && read(id) == null ) throw new SaveError(lastError);
			var b = SaveArchive.recover(path, true);
			if( b == null ) throw new SaveError("la partida no se puede leer");
			SaveArchive.writeFile(path, SaveArchive.rewrite(b, name, dropOnDeath));
			return true;
		} catch( e : Dynamic ) {
			lastError = Std.string(e);
			return false;
		}
	}

	public static function delete( id : String ) {
		for( p in [archivePath(id), archivePath(id) + ".tmp", archivePath(id) + ".bak", jsonPath(id), thumbPath(id)] )
			try if( sys.FileSystem.exists(p) ) sys.FileSystem.deleteFile(p) catch( e : Dynamic ) {}
	}

	/** la miniatura (sin leer la partida) */
	public static function thumb( id : String ) : haxe.io.Bytes {
		var path = archivePath(id);
		if( sys.FileSystem.exists(path) )
			return try SaveArchive.readParts(path, ["thumb.png"]).get("thumb.png") catch( e : Dynamic ) null;
		var p = thumbPath(id);
		return sys.FileSystem.exists(p) ? sys.io.File.getBytes(p) : null;
	}

	// ---------------------------------------------------------------- partidas de antes (.json)

	/**
	 * Una partida .json de antes, con sus numeros de bloque pasados a nombres con la tabla de su linea (SaveNames.legacyTable) y sus
	 * kubes del editor (editorKubes) a "editor:<archivo>#<variante>" donde los campos de siempre tienen aire o una casilla vacia
	 */
	public static function readLegacy( path : String, id : String, lineage : String ) : SaveInfo {
		var o : Dynamic = try haxe.Json.parse(sys.io.File.getContent(path)) catch( e : Dynamic ) throw new SaveError("no es JSON: " + e);
		var info = fromObject(o, id);
		var table = SaveNames.legacyTable(lineage);
		var cache = new Map<Int, Int>();
		SaveNames.mapBlocks(info, function(k, _) {
			if( k == 0 ) return 0;
			var b = cache.get(k);
			if( b == null ) cache.set(k, b = SaveNames.resolve(k > 0 && k < table.length ? table[k] : "#" + k).index);
			return b;
		});
		function charges( c : Protocol.UserCharges ) : Protocol.UserCharges {
			if( c == null ) return null;
			var out = [];
			for( x in c ) {
				var k = x.c >= 0 && x.c < SaveNames.LEGACY_CHARGES.length ? SaveNames.resolveCharge(SaveNames.LEGACY_CHARGES[x.c]) : -1;
				if( k < 0 ) info.unknownCharges = (info.unknownCharges == null ? 0 : info.unknownCharges) + x.n else out.push({ c : k, n : x.n });
			}
			return out;
		}
		if( info.inv != null ) info.inv.charges = charges(info.inv.charges);
		if( info.storage != null ) info.storage.charges = charges(info.storage.charges);
		if( info.deathDrops != null ) for( d in info.deathDrops ) d.charges = charges(d.charges);
		var raw = field("editorKubes", function() return readEditorKubes(o.editorKubes));
		if( raw != null ) mergeEditorKubes(info, raw);
		return info;
	}

	/**
	 * Migra una partida .json de antes a .g55 con la tabla de una linea ("upstream" o "fork"): el .json y su .png pasan a
	 * saves/backups (de alli se vuelve a migrar con la otra linea: orden de pruebas migrate)
	 */
	public static function migrate( id : String, lineage : String ) : SaveInfo {
		var src = jsonPath(id), png = thumbPath(id);
		var fromBackup = !sys.FileSystem.exists(src);
		if( fromBackup ) {
			src = backupDir() + "/" + id + ".json";
			png = backupDir() + "/" + id + ".png";
		}
		var info = readLegacy(src, id, lineage);
		var thumb = sys.FileSystem.exists(png) ? sys.io.File.getBytes(png) : null;
		SaveArchive.writeFile(archivePath(id), SaveArchive.encode(info, thumb));
		if( !fromBackup ) {
			var dst = backupDir() + "/" + id + ".json";
			if( sys.FileSystem.exists(dst) ) sys.FileSystem.deleteFile(dst);
			sys.FileSystem.rename(src, dst);
			if( sys.FileSystem.exists(png) ) {
				var dpng = backupDir() + "/" + id + ".png";
				if( sys.FileSystem.exists(dpng) ) sys.FileSystem.deleteFile(dpng);
				sys.FileSystem.rename(png, dpng);
			}
		}
		return SaveArchive.decode(sys.io.File.getBytes(archivePath(id)), id);
	}

	static function readEditorKubes( o : Dynamic ) : KubeSaveData.EditorKubesSave {
		if( o == null ) return null;
		var r : KubeSaveData.EditorKubesSave = { ids : [for( v in arr(o.ids) ) Std.string(v).toLowerCase()] };
		r.edits = ints(o.edits);
		r.shipEdits = ints(o.shipEdits);
		r.inv = ints(o.inv);
		if( o.drops != null ) r.drops = [for( d in arr(o.drops) ) { id : int(d.id), t : ints(d.t) }];
		if( o.planets != null ) r.planets = [for( p in arr(o.planets) ) { id : int(p.id), edits : ints(p.edits) }];
		if( o.chests != null ) r.chests = [for( c in arr(o.chests) ) { key : Std.string(c.key), t : ints(c.t) }];
		r.storage = ints(o.storage);
		return r;
	}

	/** los kubes del editor de un .json de antes pasan a los campos de siempre, donde estos tienen aire o una casilla vacia */
	static function mergeEditorKubes( info : SaveInfo, raw : KubeSaveData.EditorKubesSave ) {
		KubeSaveData.merge(info, raw, function( n ) {
			var i = n >> 2, v = n & 3;
			return i < 0 || i >= raw.ids.length ? null : SaveNames.resolve(SaveNames.EDITOR + raw.ids[i] + "#" + v);
		});
	}
}
