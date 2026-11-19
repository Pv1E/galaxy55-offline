import Common;
import SaveData.SaveInfo;
import IconMesh.Icons;
import KubeSaveData.EditorKubesSave;


/** un kube del editor cargado en la sesion: sus bloques de Block.all no cambian de indice mientras dura */
private class Slot {
	public var id : String;
	public var path : String;
	/** fecha del archivo (el orden de la paleta) y su contenido (si ha cambiado, se vuelve a leer) */
	public var stamp : Float = -1;
	public var crc = 0;
	public var kube : KubeData;
	/** PER bloques seguidos de Block.all: el bloque, su giro (Y), y la puerta abierta en X y en Y; o los 4 de un tableau */
	public var blocks : Array<Block>;
	public var active = false;
	/** casilla del atlas de cada cara de KubeData.FACES (-1 = la forma no la usa) */
	public var tiles : Array<Int>;

	public function new( id : String, blocks : Array<Block> ) {
		this.id = id;
		this.blocks = blocks;
		tiles = [for( _ in KubeData.FACES ) -1];
	}

	/**
	 * variantes que tiene la forma: la puerta 4 (cerrada X, cerrada Y, abierta X, abierta Y), el tableau 4 (uno por pared), el plano 2
	 * (X e Y), el resto 1
	 */
	public function variants() : Int {
		if( kube == null ) return 0;
		return switch( kube.shape.id ) { case "door", "painting": 4; case "plane": 2; default: 1; };
	}
}

/**
 * Kubes del editor de kubes puestos en el mundo (anadido del port), solo en las partidas creativas: los .kube de la carpeta
 * kubes (los creados en el editor y los que el jugador deja alli) salen al final de la paleta y se ponen como cualquier bloque.
 * - Cada kube tiene PER bloques al final de Block.all, todos con BlockKind BKubeEditor, que se dan de alta la primera vez que
 *   hacen falta y guardan su indice toda la sesion. El mundo los distingue por su indice (World.localId).
 * - Sus caras van a casillas libres del atlas (transparentes y sin bloque), desde el final; Atlas.updateTiles las sube.
 * - Como mucho MAX kubes: primero los que tiene la partida, luego los mas recientes de la carpeta.
 * - En la partida guardada van por el nombre de su archivo (EditorKubesSave), en un campo aparte. Un kube cambiado en el
 *   editor se ve con su dibujo nuevo al cargar; uno borrado (o que ya no se puede leer) desaparece: aire y casilla vacia.
 * - En supervivencia de una partida creativa son bloques como los demas; en aventura no se cargan (ni paleta, ni nada).
 */
class EditorKubes {

	public static inline var MAX = 128;
	/** bloques de Block.all por kube (Slot.blocks) */
	public static inline var PER = 4;

	static var slots = new Array<Slot>();
	static var byId = new Map<String, Slot>();
	/** casillas libres del atlas, desde el final (las de los kubes cargados son las primeras) */
	static var free : Array<Int>;
	/** casillas puestas en el atlas por la ultima carga (para limpiarlas si ya no se usan) */
	static var drawn = new Array<Int>();
	/** kubes de la carpeta que no caben (mas de MAX) en la ultima carga */
	public static var skipped(default, null) = 0;
	/** la partida en curso los usa (creativa) */
	public static var enabled(default, null) = false;

	public static inline function isEditor( b : Block ) : Bool return b != null && b.k == BKubeEditor;

	/** kube de un archivo: su nombre sin la extension, en minusculas */
	public static function idOf( path : String ) : String return new haxe.io.Path(path).file.toLowerCase();

	static function slotOf( b : Block ) : Slot {
		if( !isEditor(b) ) return null;
		for( s in slots ) if( b.index >= s.blocks[0].index && b.index < s.blocks[0].index + PER ) return s;
		return null;
	}

	/** archivo del kube de b (null si no es un kube del editor) */
	public static function idOfBlock( b : Block ) : String {
		var s = slotOf(b);
		return s == null ? null : s.id;
	}

	/** el bloque de un kube cargado (null si no lo esta) */
	public static function block( id : String, variant = 0 ) : Block {
		var s = byId.get(id.toLowerCase());
		return s == null || !s.active || variant >= s.variants() ? null : s.blocks[variant];
	}

	/** los kubes de la paleta: el bloque de cada kube cargado, en el orden de la carpeta (el mas reciente primero) */
	public static function palette() : Array<Block> {
		if( !enabled ) return [];
		var out = [for( s in slots ) if( s.active ) s];
		out.sort(function(a, b) return a.stamp < b.stamp ? 1 : a.stamp > b.stamp ? -1 : 0);
		return [for( s in out ) s.blocks[0]];
	}


	// ---------------------------------------------------------------- multijugador: los kubes del servidor

	/** en una partida multijugador: los kubes son los del servidor (useServer), no los de la carpeta */
	public static var serverMode(default, null) = false;

	/**
	 * Partida multijugador (anadido del port): los kubes del servidor (list[i] = su kube numero i, null si ese numero ya no
	 * tiene) toman los bloques de los numeros 0..n-1 (KubeCore.blocksFor, los mismos que el servidor), solo en memoria; los de la
	 * carpeta se dejan hasta useLocal. Se ven en todas las partidas del servidor y salen en la paleta en creativo.
	 */
	public static function useServer( list : Array<KubeCore.NetKube>, n : Int ) {
		serverMode = true;
		enabled = true;
		byId = new Map();
		for( i in 0...Std.int(Math.max(n, slots.length)) ) {
			if( i >= slots.length ) slots.push(new Slot("", KubeCore.blocksFor(i)));
			var s = slots[i], k = i < n ? list[i] : null;
			s.kube = k == null ? null : KubeData.fromNet(k);
			s.active = s.kube != null;
			s.id = k == null ? "" : "srv:" + k.id;
			s.path = null;
			s.crc = 0;
			s.stamp = -1;
			if( s.active ) byId.set(s.id, s);
		}
		skipped = 0;
		rebuild();
	}

	/** fin de la partida multijugador: los kubes del servidor se olvidan; los de la carpeta vuelven con la proxima partida (attach) */
	public static function useLocal() {
		if( !serverMode ) return;
		serverMode = false;
		for( s in slots ) {
			s.active = false;
			s.kube = null;
			s.id = "";
		}
		byId = new Map();
		rebuild();
	}
	// ---------------------------------------------------------------- carga

	/**
	 * Al empezar a jugar una partida (GalaxyApp.startGame): en creativo se cargan los kubes (los cambiados desde la ultima vez) y
	 * los de la partida guardada pasan a sus bloques; en aventura no queda ninguno disponible.
	 */
	public static function attach( info : SaveInfo ) {
		// multijugador: los del servidor, siempre (las partidas del servidor llevan sus numeros tal cual)
		if( serverMode ) {
			enabled = true;
			return;
		}
		enabled = info.creative == true;
		if( !enabled ) {
			for( s in slots ) s.active = false;
			skipped = 0;
			return;
		}
		var raw = info.editorKubes;
		var wanted = raw != null ? raw.ids.copy() : [];
		for( id in usedIds(info) ) if( wanted.indexOf(id) < 0 ) wanted.push(id);
		refresh(wanted);
		if( raw != null ) {
			merge(info, raw);
			info.editorKubes = null;
		}
	}

	/**
	 * Vuelve a leer la carpeta: los kubes de wanted primero, luego los demas del mas reciente al mas antiguo, hasta MAX. Los
	 * archivos cambiados se vuelven a leer; si algo ha cambiado, se rehacen sus bloques, sus casillas del atlas y sus iconos.
	 */
	public static function refresh( ?wanted : Array<String> ) {
		if( serverMode ) return;
		var files = new Map<String, String>();
		var order = [];
		for( p in KubeData.list() ) {
			var id = idOf(p);
			if( files.exists(id) ) continue;
			files.set(id, p);
			order.push(id);
		}
		var chosen = [];
		if( wanted != null ) for( id in wanted ) if( files.exists(id) && chosen.indexOf(id) < 0 ) chosen.push(id);
		for( id in order ) if( chosen.indexOf(id) < 0 ) chosen.push(id);
		skipped = chosen.length > MAX ? chosen.length - MAX : 0;
		if( chosen.length > MAX ) chosen = chosen.slice(0, MAX);
		var changed = false;
		for( s in slots )
			if( s.active && chosen.indexOf(s.id) < 0 ) {
				s.active = false;
				changed = true;
			}
		for( id in chosen ) {
			var path = files.get(id);
			var stamp = try sys.FileSystem.stat(path).mtime.getTime() catch( e : Dynamic ) -1.;
			// la fecha del archivo va por segundos: un kube guardado dos veces en el mismo segundo se reconoce por su contenido
			var crc = try haxe.crypto.Crc32.make(sys.io.File.getBytes(path)) catch( e : Dynamic ) 0;
			var s = byId.get(id);
			if( s == null ) {
				// el kube numero i usa siempre los mismos bloques (KubeCore.blocksFor: los del servidor del mismo proceso tambien)
				s = new Slot(id, KubeCore.blocksFor(slots.length));
				slots.push(s);
				byId.set(id, s);
			}
			s.stamp = stamp;
			if( s.active && s.path == path && s.crc == crc ) continue;
			s.path = path;
			s.crc = crc;
			s.kube = KubeData.load(path);
			s.active = s.kube != null;
			changed = true;
		}
		if( changed ) rebuild();
	}

	/** casillas, bloques e iconos de todos los kubes cargados */
	static function rebuild() {
		if( free == null ) free = freeTiles();
		var used = [], next = 0;
		for( s in slots ) {
			for( f in 0...s.tiles.length ) s.tiles[f] = -1;
			if( !s.active ) continue;
			var faces = s.kube.shape.faces;
			if( next + faces.length > free.length ) {
				// el atlas no da para mas (no deberia pasar con MAX kubes): este no se carga
				s.active = false;
				skipped++;
				continue;
			}
			for( f in faces ) {
				s.tiles[f] = free[next++];
				used.push(s.tiles[f]);
			}
		}
		var pix = Atlas.pixels;
		var touched = [];
		// las casillas que ya no usa nadie quedan otra vez transparentes
		for( t in drawn )
			if( used.indexOf(t) < 0 ) {
				fillTile(pix, t, null);
				touched.push(t);
			}
		for( s in slots ) {
			if( s.active )
				for( f in s.kube.shape.faces ) {
					fillTile(pix, s.tiles[f], s.kube.faces[f]);
					touched.push(s.tiles[f]);
				}
			setup(s);
			for( b in s.blocks ) Icons.forget(b);
		}
		drawn = used;
		Atlas.updateTiles(touched);
	}

	static function fillTile( pix : hxd.Pixels, t : Int, face : haxe.ds.Vector<Int> ) {
		var tx = (t & 63) << 5, ty = (t >> 6) << 5, n = KubeData.SIZE;
		for( y in 0...n ) for( x in 0...n ) pix.setPixel(tx + x, ty + y, face == null ? 0 : face[y * n + x]);
	}

	/**
	 * Casillas del atlas que no son de ningun bloque y no tienen nada dibujado (alfa 0), desde la ultima: las de los colores
	 * planos (BFColor, desde 4094) ya son de sus bloques. Bastan MAX kubes de 8 caras.
	 */
	static function freeTiles() : Array<Int> {
		var mine = new Map<Int, Bool>();
		for( b in Block.all ) {
			if( isEditor(b) ) continue;
			for( t in [b.tlr, b.tu, b.td] ) {
				mine.set(t & 0xFFF, true);
				mine.set((t >> 12) & 0xFFF, true);
			}
		}
		var pix = Atlas.pixels, bytes = pix.bytes, out = [], want = MAX * KubeData.FACES.length;
		var t = 4094;
		while( t > 0 && out.length < want ) {
			if( !mine.exists(t) ) {
				var tx = (t & 63) << 5, ty = (t >> 6) << 5, clear = true;
				for( y in 0...32 ) {
					var p = pix.offset + ((ty + y) * pix.width + tx) * 4 + 3;
					for( x in 0...32 ) if( bytes.get(p + x * 4) != 0 ) { clear = false; break; }
					if( !clear ) break;
				}
				if( clear ) out.push(t);
			}
			t--;
		}
		return out;
	}

	/** los bloques de un kube: los mismos campos que Block.initBlocks deja con las lineas de KubeData.dataGen */
	static function setup( s : Slot ) {
		if( !s.active || s.kube == null ) {
			for( b in s.blocks ) KubeCore.reset(b, s.kube == null ? "-" : s.kube.name);
			return;
		}
		var k = s.kube;
		// lo que no es dibujo esta en KubeCore (el servidor configura los mismos bloques, sin casillas)
		KubeCore.setup(s.blocks, k.name, k.shape, k.render, k.box, k.light, k.noCollide, function( f ) return s.tiles[f] < 0 ? 0xFFF : s.tiles[f]);
	}

	/** un bloque del kube sin forma (KubeCore.reset) */
	static inline function reset( b : Block, name : String ) KubeCore.reset(b, name);

	// ---------------------------------------------------------------- partida guardada

	/** kubes que la partida (ya con sus bloques) tiene en el terreno, la nave, el inventario o las cantinas */
	static function usedIds( info : SaveInfo ) : Array<String> {
		var out = [];
		function note( gi : Int ) {
			var id = idOfBlock(Block.all[gi & 0xFFFF]);
			if( id != null && out.indexOf(id) < 0 ) out.push(id);
		}
		function edits( e : Array<Int> ) {
			if( e == null ) return;
			var i = 0;
			while( i + 1 < e.length ) {
				if( e[i] >= 0 ) note(e[i + 1]);
				i += 2;
			}
		}
		function slotsOf( t : Protocol.BlockInventory ) if( t != null ) for( s in t ) if( s != null ) note(s.k);
		edits(info.edits);
		edits(info.shipEdits);
		if( info.uni != null && info.uni.planets != null ) for( p in info.uni.planets ) edits(p.edits);
		if( info.deathDrops != null ) for( d in info.deathDrops ) slotsOf(d.t);
		if( info.inv != null ) slotsOf(info.inv.t);
		if( info.chests != null ) for( c in info.chests ) slotsOf(c.t);
		if( info.storage != null ) slotsOf(info.storage.t);
		return out;
	}

	/** bloque de un numero de la partida guardada (null: el kube ya no esta o la variante no existe en su forma de ahora) */
	static function decode( raw : EditorKubesSave, n : Int ) : Block {
		var i = n >> 2, v = n & 3;
		if( i < 0 || i >= raw.ids.length ) return null;
		var s = byId.get(raw.ids[i]);
		if( s == null || !s.active ) return null;
		// la forma ha cambiado en el editor (una puerta abierta que ahora es un cubo): el bloque del kube
		return s.blocks[v < s.variants() ? v : 0];
	}

	/** los kubes de la partida guardada pasan a los campos de siempre (KubeSaveData.merge: el servidor hace lo mismo) */
	static function merge( info : SaveInfo, raw : EditorKubesSave ) KubeSaveData.merge(info, raw, function( n ) return decode(raw, n));

	/**
	 * Lo que SaveData.write escribe: sin kubes del editor en los campos de siempre, la misma partida; si no, una copia con aire y
	 * casillas vacias en su sitio y los kubes en editorKubes. La partida en juego no cambia.
	 */
	public static function encode( info : SaveInfo ) : SaveInfo {
		if( usedIds(info).length == 0 ) return info;
		var out : SaveInfo = Reflect.copy(info);
		var raw : EditorKubesSave = { ids : [] };
		function num( b : Block ) : Int {
			var s = slotOf(b);
			if( s == null || !s.active ) return -1;
			var i = raw.ids.indexOf(s.id);
			if( i < 0 ) {
				i = raw.ids.length;
				raw.ids.push(s.id);
			}
			return (i << 2) | (b.index - s.blocks[0].index);
		}
		// pares de celdas: los kubes del editor pasan a aire y a la lista aparte
		function edits( e : Array<Int>, put : Array<Int> -> Void ) : Array<Int> {
			if( e == null ) return null;
			var copy = e.copy(), mine = [];
			var i = 0;
			while( i + 1 < copy.length ) {
				var b = copy[i] >= 0 ? Block.all[copy[i + 1] & 0xFFFF] : null;
				if( isEditor(b) ) {
					var n = num(b);
					if( n >= 0 ) {
						mine.push(copy[i]);
						mine.push(n);
					}
					copy[i + 1] = 0;
				}
				i += 2;
			}
			if( mine.length > 0 ) put(mine);
			return copy;
		}
		function slotsOf( t : Protocol.BlockInventory, put : Array<Int> -> Void ) : Protocol.BlockInventory {
			if( t == null ) return null;
			var copy = [for( s in t ) s == null ? null : { k : s.k, n : s.n }], mine = [];
			for( i in 0...copy.length ) {
				var s = copy[i];
				if( s == null || !isEditor(Block.all[s.k]) ) continue;
				var n = num(Block.all[s.k]);
				if( n >= 0 ) {
					mine.push(i);
					mine.push(n);
					mine.push(s.n);
				}
				copy[i] = null;
			}
			if( mine.length > 0 ) put(mine);
			return copy;
		}
		out.edits = edits(info.edits, function(m) raw.edits = m);
		out.shipEdits = edits(info.shipEdits, function(m) raw.shipEdits = m);
		if( info.uni != null && info.uni.planets != null ) {
			out.uni = Reflect.copy(info.uni);
			out.uni.planets = [for( p in info.uni.planets ) {
				var c : SaveData.UniPlanet = Reflect.copy(p);
				c.edits = edits(p.edits, function(m) {
					if( raw.planets == null ) raw.planets = [];
					raw.planets.push({ id : p.id, edits : m });
				});
				c;
			}];
		}
		if( info.deathDrops != null )
			out.deathDrops = [for( d in info.deathDrops ) {
				var c : DeathDrops.DeathDropInfo = Reflect.copy(d);
				c.t = slotsOf(d.t, function(m) {
					if( raw.drops == null ) raw.drops = [];
					raw.drops.push({ id : d.id, t : m });
				});
				c;
			}];
		if( info.inv != null ) {
			out.inv = Inv.copy(info.inv);
			out.inv.t = slotsOf(info.inv.t, function(m) raw.inv = m);
		}
		if( info.chests != null )
			out.chests = [for( c in info.chests ) { key : c.key, t : slotsOf(c.t, function(m) {
				if( raw.chests == null ) raw.chests = [];
				raw.chests.push({ key : c.key, t : m });
			}) }];
		if( info.storage != null )
			out.storage = { t : slotsOf(info.storage.t, function(m) raw.storage = m), charges : [for( c in info.storage.charges ) { c : c.c, n : c.n }] };
		out.editorKubes = raw.ids.length > 0 ? raw : null;
		return out;
	}

	/** editorKubes de una partida leida de disco; null si no hay o esta mal formado */
	public static function readSave( o : Dynamic ) : EditorKubesSave return KubeSaveData.read(o);

	// ---------------------------------------------------------------- pruebas (Dev)

	/** orden `print edkubes`: kubes cargados (archivo, nombre, forma, primer bloque, casillas); los de lote (lot-N) solo se cuentan */
	public static function devInfo() : String {
		var lots = 0, l = [];
		for( s in slots ) {
			if( StringTools.startsWith(s.id, "lot-") ) {
				if( s.active ) lots++;
				continue;
			}
			l.push(s.id + (s.active ? "" : " (no cargado)") + (s.kube == null ? "" : " '" + s.kube.name + "' " + s.kube.shape.id + " " + s.kube.blockType())
				+ " #" + s.blocks[0].index + " casillas " + [for( t in s.tiles ) if( t >= 0 ) t].join(","));
		}
		return "kubes del editor: " + (enabled ? "activos" : "inactivos") + ", " + [for( s in slots ) if( s.active ) s].length + " cargados, " + skipped
			+ " de mas, paleta " + palette().length + (lots > 0 ? ", " + lots + " lot-N cargados" : "") + (l.length > 0 ? "\n  " + l.join("\n  ") : "");
	}

	/** un kube del editor con su nombre de archivo: `print block` y los inventarios de Dev */
	public static function label( b : Block ) : String {
		var id = idOfBlock(b);
		return id == null ? "" + b.k : "kube:" + id + (b.index - slotOf(b).blocks[0].index > 0 ? "/" + (b.index - slotOf(b).blocks[0].index) : "");
	}
}
