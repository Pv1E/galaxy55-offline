import Common;
import SaveData.SaveInfo;
import IconMesh.Icons;

/**
 * Kubes del editor de una partida guardada (SaveInfo.editorKubes). Los campos de siempre (edits, inv, chests...) llevan aire o
 * una casilla vacia en su sitio: una version sin los kubes del editor los ignora sin mas (y los pierde si guarda la partida).
 * Cada kube va como un numero n = posicion en ids * 4 + variante (0 = el bloque; la puerta y el plano tienen mas, EditorKubes.PER).
 */
typedef EditorKubesSave = {
	/** archivo de cada kube (nombre del .kube sin la extension, en minusculas) */
	var ids : Array<String>;
	/** planeta actual: pares [celda, n] */
	@:optional var edits : Array<Int>;
	/** nave: pares [celda, n] */
	@:optional var shipEdits : Array<Int>;
	/** planetas visitados (uni.planets): sus pares [celda, n] */
	@:optional var planets : Array<{ id : Int, edits : Array<Int> }>;
	/** inventario: [casilla, n, cantidad, ...] */
	@:optional var inv : Array<Int>;
	/** cantinas (clave de SaveInfo.chests): [casilla, n, cantidad, ...] */
	@:optional var chests : Array<{ key : String, t : Array<Int> }>;
	/** stockage de la nave (SaveInfo.storage): [casilla, n, cantidad, ...] */
	@:optional var storage : Array<Int>;
}

/** un kube del editor cargado en la sesion: sus bloques de Block.all no cambian de indice mientras dura */
private class Slot {
	public var id : String;
	public var path : String;
	/** fecha del archivo (el orden de la paleta) y su contenido (si ha cambiado, se vuelve a leer) */
	public var stamp : Float = -1;
	public var crc = 0;
	public var kube : KubeData;
	/** PER bloques seguidos de Block.all: el bloque, su giro (Y), y la puerta abierta en X y en Y */
	public var blocks : Array<Block>;
	public var active = false;
	/** casilla del atlas de cada cara de KubeData.FACES (-1 = la forma no la usa) */
	public var tiles : Array<Int>;

	public function new( id : String, blocks : Array<Block> ) {
		this.id = id;
		this.blocks = blocks;
		tiles = [for( _ in KubeData.FACES ) -1];
	}

	/** variantes que tiene la forma: la puerta 4 (cerrada X, cerrada Y, abierta X, abierta Y), el plano 2 (X e Y), el resto 1 */
	public function variants() : Int return kube == null ? 0 : kube.shape.id == "door" ? 4 : kube.shape.id == "plane" ? 2 : 1;
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

	// ---------------------------------------------------------------- carga

	/**
	 * Al empezar a jugar una partida (GalaxyApp.startGame): en creativo se cargan los kubes (los cambiados desde la ultima vez) y
	 * los de la partida guardada pasan a sus bloques; en aventura no queda ninguno disponible.
	 */
	public static function attach( info : SaveInfo ) {
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
				s = new Slot(id, [for( _ in 0...PER ) newBlock()]);
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

	/** un bloque mas al final de Block.all, con el BlockKind de los kubes del editor */
	static function newBlock() : Block {
		var b = new Block(BKubeEditor);
		b.index = Block.all.length;
		b.flags = [];
		b.type = BTFull;
		b.tlr = b.tu = b.td = 0xFFF;
		b.matter = b;
		Block.all.push(b);
		return b;
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
		for( b in s.blocks ) reset(b, s.kube == null ? "-" : s.kube.name);
		if( !s.active ) return;
		var k = s.kube;
		inline function tile( f : Int ) return s.tiles[f] < 0 ? 0xFFF : s.tiles[f];
		var b = s.blocks[0];
		var flags = [];
		if( k.light != null ) {
			var l = k.light[1] > 0 ? BFLight(k.light[0], k.light[1]) : BFLight(k.light[0]);
			flags.push(l);
			flags.push(BFNoShade);
		}
		if( k.noCollide ) flags.push(BFNoCollide);
		function common( x : Block, f : Array<BlockFlag> ) {
			x.flags = flags.concat(f);
			for( fl in x.flags )
				switch( fl ) {
				case BFLight(_): x.special = fl;
				case BFNoCollide: x.props.unset(PCollide);
				case BFMagnet(m):
					if( x.magnets == 7 ) x.magnets = 0;
					x.magnets |= Type.enumIndex(m);
				case BFAnchor(a): x.anchors |= Type.enumIndex(a);
				default:
				}
		}
		var sz = { x1 : k.box[0] / KubeData.SIZE, y1 : k.box[1] / KubeData.SIZE, z1 : k.box[2] / KubeData.SIZE, x2 : k.box[3] / KubeData.SIZE, y2 : k.box[4] / KubeData.SIZE, z2 : k.box[5] / KubeData.SIZE };
		b.tlr = tile(KubeData.SIDE);
		b.tu = tile(KubeData.UP);
		b.td = tile(KubeData.DOWN);
		switch( k.shape.id ) {
		case "cube":
			b.type = k.blockType();
			common(b, []);
		case "cube6":
			b.type = BTExtended;
			b.tlr = (tile(KubeData.FRONT) << 12) | tile(KubeData.BACK);
			b.tu = (tile(KubeData.LEFT) << 12) | tile(KubeData.UP);
			b.td = (tile(KubeData.RIGHT) << 12) | tile(KubeData.DOWN);
			common(b, []);
		case "box":
			b.type = BTReduced;
			b.size = sz;
			common(b, [BFSize(sz.x1, sz.y1, sz.z1, sz.x2, sz.y2, sz.z2)]);
		case "door":
			// como BShipDoor: cerrada X (gira a Y), cerrada Y y las dos abiertas; cada cerrada alterna con su abierta
			var y = s.blocks[1], ox = s.blocks[2], oy = s.blocks[3];
			var hold = [BFMagnet(UpDown), BFAnchor(Up), BFAnchor(Down)];
			var szY = { x1 : sz.y1, y1 : sz.x1, z1 : sz.z1, x2 : sz.y2, y2 : sz.x2, z2 : sz.z2 };
			for( c in [b, y] ) {
				c.type = BTReduced;
				c.tlr = b.tlr;
				c.tu = b.tu;
				c.td = b.td;
			}
			b.size = sz;
			y.size = szY;
			// la pareja de BFFlip y BFToggle va en flip y toggle (BFToggle nombra un BlockKind: el de todos estos es el mismo)
			common(b, hold.concat([BFSize(sz.x1, sz.y1, sz.z1, sz.x2, sz.y2, sz.z2), BFFlip]));
			common(y, hold.concat([BFSize(szY.x1, szY.y1, szY.z1, szY.x2, szY.y2, szY.z2)]));
			for( o in [ox, oy] ) {
				o.type = BTModel;
				o.tlr = o.tu = o.td = tile(KubeData.OPEN);
				o.props.unset(PCollide);
			}
			ox.model = MDoorOpenX;
			oy.model = MDoorOpenY;
			common(ox, hold.concat([BFModel(MDoorOpenX), BFNoCollide]));
			common(oy, hold.concat([BFModel(MDoorOpenY), BFNoCollide]));
			b.flip = y;
			y.flip = b;
			b.toggle = ox;
			ox.toggle = b;
			y.toggle = oy;
			oy.toggle = y;
		case "plane":
			// como BWoodWindow: la X gira a la Y con BFFlip
			var y = s.blocks[1];
			for( c in [b, y] ) {
				c.type = BTModel2Side;
				c.tu = c.td = c.tlr = b.tlr;
			}
			b.model = MPlanX;
			y.model = MPlanY;
			common(b, [BFModel(MPlanX), BFFlip]);
			common(y, [BFModel(MPlanY)]);
			b.flip = y;
			y.flip = b;
		default:
			b.type = k.shape.type;
			b.model = k.shape.model;
			if( k.shape.faces.length == 1 ) b.tu = b.td = b.tlr;
			else if( !k.usesFace(KubeData.DOWN) ) b.td = b.tlr;
			common(b, [BFModel(k.shape.model)]);
		}
		// las colisiones de los modelos sin BFSize usan su propia caja (como hace World al crearse, Builder.init)
		for( x in s.blocks )
			if( x.model != null && x.size == null ) x.size = Models.get(x.model).box;
	}

	/** un bloque del kube sin forma: lo que Block.new y Block.initBlocks dejan antes de leer las banderas */
	static function reset( b : Block, name : String ) {
		b.type = BTFull;
		b.flags = [];
		b.special = null;
		b.model = null;
		b.size = null;
		b.flip = null;
		b.toggle = null;
		b.covered = null;
		b.uncover = null;
		b.propagate = null;
		b.anchors = 0;
		b.magnets = 7;
		b.props = new haxe.EnumFlags<Block.BlockProp>();
		b.props.set(PCanPick);
		b.props.set(PCollide);
		b.tlr = b.tu = b.td = 0xFFF;
		b.basePrice = null;
		b.weight = 1;
		b.matter = b;
		@:privateAccess b.name = name;
	}

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

	/** los kubes de la partida guardada pasan a los campos de siempre, donde los campos de siempre tienen aire o una casilla vacia */
	static function merge( info : SaveInfo, raw : EditorKubesSave ) {
		function edits( e : Array<Int>, add : Array<Int> ) : Array<Int> {
			if( add == null ) return e;
			if( e == null ) e = [];
			var at = new Map<Int, Int>();
			var i = 0;
			while( i + 1 < e.length ) {
				if( e[i] >= 0 ) at.set(e[i], i + 1);
				i += 2;
			}
			i = 0;
			while( i + 1 < add.length ) {
				var cell = add[i], b = decode(raw, add[i + 1]);
				i += 2;
				if( cell < 0 || b == null ) continue;
				var p = at.get(cell);
				if( p == null ) {
					e.push(cell);
					e.push(b.index);
				} else if( (e[p] & 0xFFFF) == 0 )
					e[p] = b.index;
			}
			return e;
		}
		function slotsOf( t : Protocol.BlockInventory, add : Array<Int> ) {
			if( t == null || add == null ) return;
			var i = 0;
			while( i + 2 < add.length ) {
				var c = add[i], b = decode(raw, add[i + 1]), n = add[i + 2];
				i += 3;
				if( b != null && c >= 0 && c < t.length && t[c] == null && n > 0 ) t[c] = { k : b.index, n : n };
			}
		}
		info.edits = edits(info.edits, raw.edits);
		info.shipEdits = edits(info.shipEdits, raw.shipEdits);
		if( raw.planets != null && info.uni != null && info.uni.planets != null )
			for( rp in raw.planets )
				for( p in info.uni.planets )
					if( p.id == rp.id ) p.edits = edits(p.edits, rp.edits);
		if( info.inv != null ) slotsOf(info.inv.t, raw.inv);
		if( raw.chests != null && info.chests != null )
			for( rc in raw.chests )
				for( c in info.chests )
					if( c.key == rc.key ) slotsOf(c.t, rc.t);
		if( info.storage != null ) slotsOf(info.storage.t, raw.storage);
	}

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
	public static function readSave( o : Dynamic ) : EditorKubesSave {
		try {
			if( o == null || o.ids == null ) return null;
			inline function ints( a : Dynamic ) : Array<Int> return a == null ? null : [for( v in (a : Array<Dynamic>) ) Std.int(v)];
			var r : EditorKubesSave = { ids : [for( v in (o.ids : Array<Dynamic>) ) Std.string(v).toLowerCase()] };
			r.edits = ints(o.edits);
			r.shipEdits = ints(o.shipEdits);
			r.inv = ints(o.inv);
			if( o.planets != null ) r.planets = [for( p in (o.planets : Array<Dynamic>) ) { id : Std.int(p.id), edits : ints(p.edits) }];
			if( o.chests != null ) r.chests = [for( c in (o.chests : Array<Dynamic>) ) { key : Std.string(c.key), t : ints(c.t) }];
			r.storage = ints(o.storage);
			return r;
		} catch( e : Dynamic ) {
			return null;
		}
	}

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
