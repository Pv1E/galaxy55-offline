import Common;
import Msg;

/** Mundo del servidor: los datos de WorldData y la lista de celdas cambiadas (para mandarlas y guardarlas) */
class ServerWorld extends WorldData {
	/** celdas cambiadas desde el ultimo envio */
	public var changed = new Array<Int>();
	/** trozo de cada celda cambiada, para guardar solo los trozos tocados */
	public var dirty = new Map<Int, Bool>();
	/** celdas cambiadas de cada trozo (para reescribir un trozo sin recorrer todos los cambios) */
	public var chunkKeys = new Map<Int, Map<Int, Bool>>();

	public function chunkOf( key : Int ) : Int {
		if( key < 0 ) return -1;
		var col = key >> WorldData.ZBITS;
		var x = col % size, y = Std.int(col / size);
		return (x >> 4) | ((y >> 4) << 8);
	}

	function note( key : Int ) {
		changed.push(key);
		var c = chunkOf(key);
		dirty.set(c, true);
		var m = chunkKeys.get(c);
		if( m == null ) chunkKeys.set(c, m = new Map());
		m.set(key, true);
	}

	override function cellChanged( x : Int, y : Int, z : Int, key : Int ) note(key);

	override function levelChanged( x : Int, y : Int ) {}

	/** setWater con el mismo bloque cambia solo el nivel: tambien hay que mandarlo */
	override public function setWater( x : Int, y : Int, z : Int, b : Block, level : Int ) {
		super.setWater(x, y, z, b, level);
		if( z >= 1 && z < WorldData.HEIGHT - 1 ) note(((wrapC(x) + wrapC(y) * size) << WorldData.ZBITS) | z);
	}

	/** valor de la celda para los clientes: el de editMap (bloque global | nivel << 16), o el del terreno generado */
	public function valueAt( key : Int ) : Int {
		var v = editMap.get(key);
		if( v != null ) return v;
		var id = cell(key);
		return id == 0 ? 0 : gen.blocks[id].index;
	}

	public function blockAtKey( key : Int ) : Block {
		var id = cell(key);
		return id == 0 ? null : gen.blocks[id];
	}

	/** las claves de los trozos tocados con sus pares [celda, valor] para guardar */
	public function takeDirty() : Map<Int, Array<Int>> {
		var out = new Map<Int, Array<Int>>();
		for( c in dirty.keys() ) {
			var pairs = [];
			if( c == -1 ) {
				var flat = editsFlat();
				var i = 0;
				while( i + 1 < flat.length ) {
					if( flat[i] < 0 ) { pairs.push(flat[i]); pairs.push(flat[i + 1]); }
					i += 2;
				}
			} else {
				var m = chunkKeys.get(c);
				if( m != null )
					for( k in m.keys() ) {
						var v = editMap.get(k);
						if( v != null ) { pairs.push(k); pairs.push(v); }
					}
			}
			out.set(c, pairs);
		}
		dirty = new Map();
		return out;
	}

	/** el mar o su contador han cambiado: el trozo -1 (claves negativas de editsFlat) se guarda */
	public function seaDirty() dirty.set(-1, true);

	/** carga: los cambios guardados ya estan en sus trozos */
	public function indexSaved() {
		for( k in editMap.keys() ) {
			var c = chunkOf(k);
			var m = chunkKeys.get(c);
			if( m == null ) chunkKeys.set(c, m = new Map());
			m.set(k, true);
		}
	}
}

/**
 * Un planeta cargado en el servidor (anadido del port, multijugador): su mundo (ServerWorld, generado por pasos igual que en el
 * cliente), el proceso del mundo (liquidos, hierba, soportes: solo aqui, los clientes reciben lo que hace) y quien esta en el.
 * Se descarga cuando lleva un rato vacio; lo que cambia se guarda por trozos en la base de datos (GameServer.commit).
 */
class PlanetInstance {

	public var key(default, null) : String;
	public var row : ServerDb.PlanetRow;
	public var world(default, null) : ServerWorld;
	public var process(default, null) : WorldProcess;
	public var players = new Array<GameServer.Session>();
	public var emptySince = 0.;
	/** peticiones de jugadores (romper, poner) que esperan a que el mundo este generado */
	public var waiting = new Array<{ s : GameServer.Session, m : ClientMsg }>();
	/** sueltos, cantinas y bombas del planeta (ServerItems) */
	public var items = new ServerItems.PlanetItems();
	var lastFlood = 0;
	var lastSea = 0;
	var t0 = 0.;

	/** onBreak: lo que rompe el proceso del mundo (liquidos, soportes), para que suelte lo suyo; onLavaBomb: la lava alcanza una bomba */
	public function new( row : ServerDb.PlanetRow, edits : Array<Int>, onBreak : Int -> Int -> Int -> Block -> Void, onLavaBomb : Int -> Int -> Int -> Block -> Void ) {
		this.row = row;
		key = row.gkey;
		world = new ServerWorld(row.seed, row.biome, row.size, edits, null, row.gen);
		process = new WorldProcess(world, function( x, y, z, b ) {
			world.setBlock(x, y, z, null);
			onBreak(x, y, z, b);
		});
		process.lavaBombFn = onLavaBomb;
		t0 = haxe.Timer.stamp();
	}

	/** listo: generado (en otro hilo o tomado del anfitrion) y preparado en este (finishGen); hasta entonces nadie toca el mundo */
	public inline function ready() return isReady;
	var isReady = false;

	/**
	 * el juego del anfitrion esta generando este mismo planeta (ha entrado y aun no esta listo): hasta esta hora no se genera
	 * aqui, se espera su terreno (ServerWorlds.adoptTerrain). Generarlo a la vez costaba ~55 ms por fotograma al anfitrion.
	 */
	public var hostWaitUntil = 0.;

	/** la generacion en otro hilo: empezada, acabada (lo escribe ese hilo) y su error si fallo */
	var genStarted = false;
	var genDone = false;
	public var genError(default, null) : String;

	public inline function generating() return genStarted && !isReady;

	/**
	 * Genera el mundo en otro hilo (cambio del port: en el mismo, cada paso del generador, unos 55 ms, paraba el juego del
	 * anfitrion y el bucle del servidor dedicado). El generador comparte su memoria global con los demas (WorldData.genLock).
	 * Se llama en cada vuelta: true cuando esta listo (lo ultimo, finishGen, se hace en este hilo).
	 */
	public function generateAsync() : Bool {
		if( isReady ) return true;
		if( genDone ) {
			if( genError != null ) return false;
			finishGen();
			return true;
		}
		if( !genStarted ) {
			genStarted = true;
			var w = world;
			sys.thread.Thread.create(function() {
				try {
					while( !cancelled && !w.genStep(haxe.Timer.stamp(), 30) ) {}
				} catch( e : Dynamic ) {
					genError = Std.string(e);
				}
				genDone = !cancelled;
			});
		}
		return false;
	}

	/** descargado o servidor parado: el hilo deja de generar (si no, seguia con el cerrojo del generador y frenaba los demas) */
	var cancelled = false;
	public function cancel() cancelled = true;

	/** el terreno que el juego del anfitrion acaba de generar (WorldData.adoptGenerated); true si era este planeta */
	public function adopt( src : WorldData ) : Bool {
		if( isReady || genStarted || !world.adoptGenerated(src) ) return false;
		finishGen();
		return true;
	}

	function finishGen() {
		world.indexSaved();
		world.changed = [];
		world.dirty = new Map();
		lastFlood = world.waterFlood;
		lastSea = world.waterLevel();
		isReady = true;
	}

	/** un paso del mundo (dt en segundos); devuelve si el mar ha bajado una capa */
	public function tick( dt : Float ) : Bool {
		if( !ready() ) return false;
		var hx = 0., hy = 0., hz = -1000.;
		if( players.length > 0 ) {
			var p = players[0].pos;
			if( p != null ) { hx = p.x; hy = p.y; hz = p.z + 0.8; }
		}
		process.update(dt, hx, hy, hz);
		var dropped = false;
		if( world.floodFlag ) {
			world.reduceWater();
			dropped = true;
		}
		if( world.waterFlood != lastFlood || world.waterLevel() != lastSea ) {
			lastFlood = world.waterFlood;
			lastSea = world.waterLevel();
			world.seaDirty();
		}
		return dropped;
	}

	/** cambios pendientes de mandar (y se olvidan) */
	public function takeChanges() : Array<NetChange> {
		if( world.changed.length == 0 ) return null;
		var seen = new Map<Int, Bool>();
		var out = [];
		for( k in world.changed ) {
			if( seen.exists(k) ) continue;
			seen.set(k, true);
			out.push({ key : k, v : world.valueAt(k) });
		}
		world.changed = [];
		return out;
	}
}
