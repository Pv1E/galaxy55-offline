import Common;
import SaveData.SaveInfo;
import IconMesh.Icons;

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
 * - En la partida guardada van por el nombre de su archivo: "editor:<archivo>#<variante>" (SaveNames). Un kube cambiado en el
 *   editor se ve con su dibujo nuevo al cargar; uno borrado (o que ya no se puede leer), y todos en aventura, quedan en un bloque
 *   de remplazo con su nombre: vuelven cuando su archivo esta y se juega en creativo.
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
			// en aventura no hay ninguno: los de la partida pasan a bloques de remplazo, con su nombre (vuelven al jugarla en creativo)
			SaveNames.mapBlocks(info, function(k, _) return isEditor(Block.all[k]) ? SaveNames.placeholderFor(SaveNames.nameOfIndex(k)).index : k);
			for( s in slots ) s.active = false;
			skipped = 0;
			return;
		}
		refresh(usedIds(info));
		// otra vez por su nombre, ahora que estan cargados los de la partida: los que esperaban en un bloque de remplazo pasan a su
		// bloque si su archivo se ha podido cargar, y los de un archivo que ya no esta (leidos antes de refresh) a uno de remplazo
		SaveNames.mapBlocks(info, function(k, _) {
			var b = Block.all[k];
			var n = SaveNames.placeholderName(b);
			if( n == null && isEditor(b) ) n = SaveNames.nameOf(b);
			return n != null && StringTools.startsWith(n, SaveNames.EDITOR) ? SaveNames.resolve(n).index : k;
		});
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
		case "painting":
			// 4 bloques, uno por pared (Painting, BFOnWall): el primero con la pared en +y, cada uno girado un cuarto de vuelta
			var sizes = Painting.sizes(k.box);
			for( t in 0...PER ) {
				var c = s.blocks[t], z = sizes[t];
				c.type = BTModel;
				c.tlr = c.tu = c.td = b.tlr;
				c.size = z;
				c.wall = t;
				common(c, [BFOnWall(t), BFSize(z.x1, z.y1, z.z1, z.x2, z.y2, z.z2), BFMagnet(None)]);
			}
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
		b.wall = -1;
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

	/**
	 * kubes que la partida tiene en el terreno, la nave, el inventario o las cantinas: los ya cargados y los que esperan en un
	 * bloque de remplazo "editor:<archivo>#<variante>" (SaveNames)
	 */
	static function usedIds( info : SaveInfo ) : Array<String> {
		var out = [];
		SaveNames.mapBlocks(info, function(k, _) {
			var b = Block.all[k];
			var id = idOfBlock(b);
			if( id == null ) {
				var e = SaveNames.parseEditor(SaveNames.placeholderName(b));
				if( e != null ) id = e.id;
			}
			if( id != null && out.indexOf(id) < 0 ) out.push(id);
			return k;
		});
		return out;
	}

	/** variante de un bloque de un kube (0 = el bloque; la puerta, el tableau y el plano tienen mas: PER) */
	public static function variantOf( b : Block ) : Int {
		var s = slotOf(b);
		return s == null ? 0 : b.index - s.blocks[0].index;
	}

	/**
	 * el bloque de un kube cargado para un nombre guardado (SaveNames.resolve); si la forma ha cambiado en el editor y ya no tiene
	 * esa variante (una puerta abierta que ahora es un cubo), el bloque del kube. null si no esta cargado
	 */
	public static function blockOrFirst( id : String, variant : Int ) : Block {
		var s = byId.get(id.toLowerCase());
		if( s == null || !s.active ) return null;
		return s.blocks[variant < s.variants() ? variant : 0];
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
