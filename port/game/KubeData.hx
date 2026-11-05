import Common;

/** forma de un kube: tipo de bloque del juego, modelo (BFModel) y caras que usa (indices de KubeData.FACES) */
typedef KubeShape = {
	var id : String;
	var type : BlockType;
	var model : Null<BlockModel>;
	var faces : Array<Int>;
	/** caja parcial (BFSize) que se puede cambiar */
	var box : Bool;
}

/**
 * Un kube del editor de kubes (anadido del port): un bloque con el mismo formato que los del juego (DataGen: tipo, BFSize o
 * BFModel y una casilla de 32x32 del atlas por cara), dibujado pixel a pixel por el jugador para enviarlo y anadirlo al juego.
 * Se guarda en %APPDATA%\Galaxy55\kubes\<nombre>.kube: un zip sin comprimir con kube.json, un png de 32x32 por cara usada,
 * apercu.png (la miniatura de la lista) y datagen.txt (las lineas listas para DataGen.hx, con las casillas del atlas por poner).
 */
class KubeData {

	public static inline var SIZE = 32;
	public static inline var SIDE = 0;
	public static inline var UP = 1;
	public static inline var DOWN = 2;
	public static inline var FRONT = 3;
	public static inline var BACK = 4;
	public static inline var LEFT = 5;
	public static inline var RIGHT = 6;
	public static inline var OPEN = 7;
	/** nombre del png de cada cara dentro del .kube (y su indice en la tira de la vista previa) */
	public static var FACES = ["side", "up", "down", "front", "back", "left", "right", "open"];
	static inline var FORMAT = 1;

	/** las formas del juego: las de los bloques de DataGen y los modelos de Models.hx que el original tenia sin usar */
	public static var SHAPES : Array<KubeShape> = [
		{ id : "cube", type : BTFull, model : null, faces : [SIDE, UP, DOWN], box : false },
		{ id : "cube6", type : BTExtended, model : null, faces : [FRONT, BACK, LEFT, RIGHT, UP, DOWN], box : false },
		{ id : "box", type : BTReduced, model : null, faces : [SIDE, UP, DOWN], box : true },
		{ id : "door", type : BTReduced, model : null, faces : [SIDE, UP, DOWN, OPEN], box : true },
		{ id : "cross", type : BTModel2Side, model : MCross, faces : [SIDE], box : false },
		{ id : "crosssquare", type : BTModel2Side, model : MCrossSquare, faces : [SIDE], box : false },
		{ id : "plane", type : BTModel2Side, model : MPlanX, faces : [SIDE], box : false },
		{ id : "pyramid", type : BTModel2Side, model : MCrossPyramid, faces : [SIDE], box : false },
		{ id : "column", type : BTModel, model : MColumn, faces : [SIDE, UP, DOWN], box : false },
		{ id : "bigcolumn", type : BTModel, model : MBigColumn, faces : [SIDE, UP, DOWN], box : false },
		{ id : "hanging", type : BTModel, model : MMiniTop, faces : [SIDE, UP, DOWN], box : false },
		{ id : "pipe", type : BTModel, model : MPipeX, faces : [SIDE, UP, DOWN], box : false },
		{ id : "cage", type : BTModel, model : MCrossBox, faces : [SIDE, UP], box : false },
	];
	/** rendu del cubo: opaco (BTFull), calado como las hojas (BTTransp) o translucido como el cristal (BTAlpha) */
	public static var RENDERS = [BTFull, BTTransp, BTAlpha];
	/**
	 * Potencias de BFLight que se eligen en el editor (las de los bloques del juego): la luz de la celda del bloque, en la escala
	 * de World (10 = pleno dia, 15 como mucho). Cada kube de distancia le quita la caida: se apaga a potencia / caida kubes.
	 */
	public static var LIGHT_POWERS = [6., 8., 10., 12., 15.];
	public static inline var MAX_REACH = 15;
	/** cajas de ejemplo en pixeles (x1 y1 z1 x2 y2 z2): dalla, neon de techo, cofrecito, poste, puerta */
	public static var BOXES = [
		"slab" => [0, 0, 0, 32, 32, 16], "neon" => [0, 0, 28, 32, 32, 32], "small" => [8, 8, 0, 24, 24, 16],
		"post" => [13, 8, 0, 19, 24, 32], "door" => [13, 0, 0, 19, 32, 32],
	];

	public var name : String;
	public var shape : KubeShape;
	/** indice en RENDERS (solo para el cubo) */
	public var render = 0;
	/** caja en pixeles de la celda (0..32): x1 y1 z1 x2 y2 z2 */
	public var box : Array<Int>;
	public var light : Array<Float>;
	public var noCollide = false;
	/** bloque del juego del que salio (informativo, en kube.json) */
	public var base : String;
	/** .kube de donde se cargo o donde se guardo (null: nunca guardado) */
	public var file : String;
	/** las 8 caras, 32x32 en ARGB; las que no usa la forma se guardan igual en memoria (cambiar de forma y volver no las pierde) */
	public var faces : Array<haxe.ds.Vector<Int>>;

	public function new( name : String ) {
		this.name = name;
		shape = SHAPES[0];
		box = [0, 0, 0, SIZE, SIZE, SIZE];
		faces = [for( _ in FACES ) new haxe.ds.Vector<Int>(SIZE * SIZE)];
	}

	public static function dir() : String {
		var d = Settings.dir() + "/kubes";
		if( !sys.FileSystem.exists(d) ) sys.FileSystem.createDirectory(d);
		return d;
	}

	public static function shapeById( id : String ) : KubeShape {
		for( s in SHAPES ) if( s.id == id ) return s;
		return SHAPES[0];
	}

	public function blockType() : BlockType return shape.id == "cube" ? RENDERS[render] : shape.type;

	public function usesFace( f : Int ) return shape.faces.indexOf(f) >= 0;

	/** las caras que la forma usa y aun estan vacias toman la de los lados (al pasar de cubo a cubo de 6 caras o a puerta) */
	public function fillMissingFaces() {
		for( f in shape.faces )
			if( f != SIDE && isEmpty(f) )
				copyFace(SIDE, f);
	}

	public function isEmpty( f : Int ) {
		for( c in faces[f] ) if( c >>> 24 != 0 ) return false;
		return true;
	}

	public function copyFace( from : Int, to : Int ) {
		for( i in 0...SIZE * SIZE ) faces[to][i] = faces[from][i];
	}

	/** cambia la izquierda y la derecha de la cara f */
	public function mirrorFace( f : Int ) {
		var px = faces[f];
		for( y in 0...SIZE ) for( x in 0...SIZE >> 1 ) {
			var a = y * SIZE + x, b = y * SIZE + SIZE - 1 - x, c = px[a];
			px[a] = px[b];
			px[b] = c;
		}
	}

	/** BFLight(potencia, caida) que se apaga a reach kubes */
	public static function lightOf( power : Float, reach : Int ) : Array<Float> return [power, power / reach];

	/** kubes a los que se apaga la luz (caida 0 = la de World por defecto, 1 por kube) */
	public function lightReach() : Int {
		var f = light[1] > 0 ? light[1] : 1.;
		return Std.int(Math.max(1, Math.min(MAX_REACH, Math.round(light[0] / f))));
	}

	public function clone() : KubeData {
		var k = new KubeData(name);
		k.shape = shape;
		k.render = render;
		k.box = box.copy();
		k.light = light == null ? null : light.copy();
		k.noCollide = noCollide;
		k.base = base;
		k.file = file;
		for( f in 0...FACES.length ) for( i in 0...SIZE * SIZE ) k.faces[f][i] = faces[f][i];
		return k;
	}

	// ---------------------------------------------------------------- bloque de la vista previa

	/**
	 * Bloque suelto con la forma del kube y la casilla i de la tira de la vista previa en la cara FACES[i] (los mismos campos que
	 * Block.initBlocks deja en un bloque del juego). open = la puerta abierta (su modelo MDoorOpenX, como BShipDoorOpen).
	 */
	public function previewBlock( open = false ) : Block {
		var b = new Block(BEmpty);
		b.type = blockType();
		b.model = shape.model;
		b.tlr = SIDE;
		b.tu = UP;
		b.td = DOWN;
		switch( shape.id ) {
		case "cube6":
			// BFTextures: delante y detras en tlr, izquierda en tu y derecha en td, de a 12 bits
			b.tlr = (FRONT << 12) | BACK;
			b.tu = (LEFT << 12) | UP;
			b.td = (RIGHT << 12) | DOWN;
		case "box", "door":
			b.size = { x1 : box[0] / SIZE, y1 : box[1] / SIZE, z1 : box[2] / SIZE, x2 : box[3] / SIZE, y2 : box[4] / SIZE, z2 : box[5] / SIZE };
			if( open ) {
				b.type = BTModel;
				b.model = MDoorOpenX;
				b.size = null;
				b.tlr = OPEN;
			}
		default:
		}
		return b;
	}

	// ---------------------------------------------------------------- desde un bloque del juego

	/** el nombre que se ve del bloque, o el de su BlockKind para los internos sin nombre */
	public static function blockName( b : Block ) : String {
		var n = b.getName();
		if( n == null || n == "" || n == "-" || n.charAt(0) == "#" ) n = Type.enumConstructor(b.k).substr(1);
		return n;
	}

	/** forma del editor que corresponde a un bloque del juego */
	public static function shapeOf( b : Block ) : KubeShape {
		return shapeById(switch( b.type ) {
			case BTExtended: "cube6";
			case BTReduced: b.toggle != null && b.toggle.model != null ? "door" : "box";
			case BTModel, BTModel2Side, BTModelMultiTex, BTSprite:
				switch( b.model != null ? b.model : MCross ) {
					case MCross: "cross";
					case MCrossSquare: "crosssquare";
					case MPlanX, MPlanY, MPlanZ: "plane";
					case MCrossPyramid: "pyramid";
					case MColumn: "column";
					case MBigColumn: "bigcolumn";
					case MMiniTop: "hanging";
					case MPipeX, MPipeY: "pipe";
					case MCrossBox: "cage";
					case MHalf, MMini: "box";
					case MDoorOpenX, MDoorOpenY: "door";
				}
			default: "cube";
		});
	}

	/** kube con la forma, las opciones y las casillas (del atlas ya parcheado, Atlas.pixels) de un bloque del juego */
	public static function fromBlock( b : Block ) : KubeData {
		var k = new KubeData(blockName(b));
		k.base = Type.enumConstructor(b.k);
		k.shape = shapeOf(b);
		var tiles = [for( _ in FACES ) -1];
		tiles[SIDE] = b.tlr;
		tiles[UP] = b.tu;
		tiles[DOWN] = b.td;
		inline function setBox( s : { x1 : Float, y1 : Float, z1 : Float, x2 : Float, y2 : Float, z2 : Float } ) {
			if( s != null ) k.box = [for( v in [s.x1, s.y1, s.z1, s.x2, s.y2, s.z2] ) Math.round(v * SIZE)];
		}
		switch( b.type ) {
		case BTFull, BTTransp, BTAlpha, BTWater, BTInvisible:
			k.render = b.type == BTAlpha || b.type == BTWater ? 2 : b.type == BTTransp ? 1 : 0;
		case BTExtended:
			tiles[FRONT] = b.tlr >> 12;
			tiles[BACK] = b.tlr & 0xFFF;
			tiles[LEFT] = b.tu >> 12;
			tiles[UP] = b.tu & 0xFFF;
			tiles[RIGHT] = b.td >> 12;
			tiles[DOWN] = b.td & 0xFFF;
		case BTReduced:
			setBox(b.size);
			if( k.shape.id == "door" ) tiles[OPEN] = b.toggle.tlr;
		case BTModel, BTModel2Side, BTModelMultiTex, BTSprite:
			switch( b.model != null ? b.model : MCross ) {
			case MHalf: k.box = BOXES.get("slab").copy();
			case MMini: k.box = BOXES.get("small").copy();
			case MDoorOpenX, MDoorOpenY:
				// la puerta abierta: su caja y sus caras cerradas son las del bloque con el que alterna
				tiles[OPEN] = b.tlr;
				if( b.toggle != null ) {
					tiles[SIDE] = b.toggle.tlr;
					tiles[UP] = b.toggle.tu;
					tiles[DOWN] = b.toggle.td;
					setBox(b.toggle.size);
				} else
					k.box = BOXES.get("door").copy();
			default:
			}
		}
		for( f in b.flags )
			switch( f ) {
			case BFLight(pow, falloff): k.light = [pow, falloff == null ? 0. : falloff];
			default:
			}
		k.noCollide = !b.collide;
		var pix = Atlas.pixels;
		for( f in 0...FACES.length ) {
			var t = tiles[f];
			if( t < 0 || t >= 0xFFF || pix == null ) continue;
			var tx = (t & 63) * SIZE, ty = (t >> 6) * SIZE;
			for( y in 0...SIZE ) for( x in 0...SIZE ) k.faces[f][y * SIZE + x] = pix.getPixel(tx + x, ty + y);
		}
		k.fillMissingFaces();
		return k;
	}

	// ---------------------------------------------------------------- archivo .kube

	/** nombre de archivo sin acentos ni simbolos: "Néon bleu" -> "neon-bleu" */
	public static function slug( s : String ) : String {
		var from = "àáâäãåçèéêëìíîïñòóôöõùúûüýÿ", to = "aaaaaaceeeeiiiinooooouuuuyy";
		var out = new StringBuf(), dash = false, low = s.toLowerCase();
		for( p in 0...low.length ) {
			var c = low.charAt(p);
			var i = from.indexOf(c);
			if( i >= 0 ) c = to.charAt(i);
			var code = c.charCodeAt(0);
			if( (code >= 97 && code <= 122) || (code >= 48 && code <= 57) ) {
				out.add(c);
				dash = false;
			} else if( !dash && out.length > 0 ) {
				out.add("-");
				dash = true;
			}
		}
		var r = out.toString();
		while( StringTools.endsWith(r, "-") ) r = r.substr(0, r.length - 1);
		return r == "" ? "kube" : r;
	}

	/** archivo libre en la carpeta de kubes para un kube nuevo (el mismo si ya se guardo ahi) */
	public function targetPath() : String {
		if( file != null && sys.FileSystem.exists(file) && StringTools.startsWith(file, dir()) ) return file;
		var s = slug(name), p = dir() + "/" + s + ".kube", n = 2;
		while( sys.FileSystem.exists(p) ) p = dir() + "/" + s + "-" + n++ + ".kube";
		return p;
	}

	public static function facePixels( v : haxe.ds.Vector<Int>, flip : Bool ) : hxd.Pixels {
		var p = hxd.Pixels.alloc(SIZE, SIZE, BGRA);
		for( y in 0...SIZE ) for( x in 0...SIZE ) p.setPixel(x, y, v[y * SIZE + (flip ? SIZE - 1 - x : x)]);
		return p;
	}

	/**
	 * Guarda el kube (con la miniatura de la lista) y devuelve la ruta. flips: caras que el bloque ensena al reves (KubeEditor
	 * las tiene como se ven): se guardan dadas la vuelta, como iran en el atlas.
	 */
	public function save( thumb : hxd.Pixels, flips : Array<Bool> ) : String {
		var path = targetPath();
		var files = new List<haxe.zip.Entry>();
		function add( n : String, data : haxe.io.Bytes ) {
			files.add({ fileName : n, fileSize : data.length, fileTime : Date.now(), compressed : false, dataSize : data.length, data : data, crc32 : haxe.crypto.Crc32.make(data) });
		}
		add("kube.json", haxe.io.Bytes.ofString(toJson()));
		for( f in shape.faces ) add(FACES[f] + ".png", facePixels(faces[f], flips[f]).toPNG());
		if( thumb != null ) add("apercu.png", thumb.toPNG());
		add("datagen.txt", haxe.io.Bytes.ofString(dataGen()));
		var out = new haxe.io.BytesOutput();
		new haxe.zip.Writer(out).write(files);
		sys.io.File.saveBytes(path, out.getBytes());
		file = path;
		return path;
	}

	function toJson() : String {
		var o : Dynamic = {
			format : FORMAT,
			name : name,
			shape : shape.id,
			faces : [for( f in shape.faces ) FACES[f]],
			light : light,
			noCollide : noCollide,
		};
		if( shape.id == "cube" ) o.render = ["opaque", "cutout", "blend"][render];
		if( shape.box ) o.box = box;
		if( base != null ) o.base = base;
		return haxe.Json.stringify(o, null, "\t");
	}

	static function readZip( path : String ) : Map<String, haxe.io.Bytes> {
		var m = new Map();
		var input = new haxe.io.BytesInput(sys.io.File.getBytes(path));
		for( e in haxe.zip.Reader.readZip(input) ) {
			// carpetas dentro del zip (si el .kube se volvio a comprimir a mano): cuenta el nombre del archivo
			var n = e.fileName.split("/").pop().split("\\").pop().toLowerCase();
			if( n != "" ) m.set(n, haxe.zip.Reader.unzip(e));
		}
		return m;
	}

	static function decodePng( bytes : haxe.io.Bytes ) : hxd.Pixels {
		return hxd.res.Any.fromBytes("kube.png", bytes).toImage().getPixels();
	}

	/** lee un .kube; null si no se puede (archivo roto o que no es un kube) */
	public static function load( path : String ) : KubeData {
		try {
			var files = readZip(path);
			var j : Dynamic = haxe.Json.parse(files.get("kube.json").toString());
			var k = new KubeData(j.name != null ? "" + j.name : new haxe.io.Path(path).file);
			k.file = path;
			k.shape = shapeById(j.shape);
			var r : String = j.render;
			k.render = r == "cutout" ? 1 : r == "blend" ? 2 : 0;
			var bx : Array<Dynamic> = j.box;
			if( bx != null && bx.length == 6 ) k.box = [for( v in bx ) Std.int(Math.max(0, Math.min(SIZE, Std.parseInt("" + v))))];
			var l : Array<Dynamic> = j.light;
			if( l != null && l.length >= 1 ) k.light = [Std.parseFloat("" + l[0]), l.length > 1 ? Std.parseFloat("" + l[1]) : 0.];
			k.noCollide = j.noCollide == true;
			k.base = j.base;
			for( f in 0...FACES.length ) {
				var png = files.get(FACES[f] + ".png");
				if( png == null ) continue;
				var p = decodePng(png);
				// un png que no es de 32x32 (retocado a mano) se lee por su esquina de arriba a la izquierda
				for( y in 0...Std.int(Math.min(SIZE, p.height)) ) for( x in 0...Std.int(Math.min(SIZE, p.width)) )
					k.faces[f][y * SIZE + x] = p.getPixel(x, y);
			}
			k.fillMissingFaces();
			return k;
		} catch( e : Dynamic ) {
			return null;
		}
	}

	/** nombre y miniatura de un .kube para la lista, sin leer sus caras (null si no es un kube) */
	public static function peek( path : String ) : { name : String, thumb : hxd.Pixels } {
		try {
			var files = readZip(path);
			var j : Dynamic = haxe.Json.parse(files.get("kube.json").toString());
			var png = files.get("apercu.png");
			return { name : j.name != null ? "" + j.name : new haxe.io.Path(path).file, thumb : png == null ? null : decodePng(png) };
		} catch( e : Dynamic ) {
			return null;
		}
	}

	/** los .kube de la carpeta, el ultimo cambiado primero */
	public static function list() : Array<String> {
		var d = dir();
		var out = [for( f in sys.FileSystem.readDirectory(d) ) if( StringTools.endsWith(f.toLowerCase(), ".kube") ) d + "/" + f];
		out.sort(function(a, b) return Reflect.compare(sys.FileSystem.stat(b).mtime.getTime(), sys.FileSystem.stat(a).mtime.getTime()));
		return out;
	}

	// ---------------------------------------------------------------- lineas para DataGen.hx

	static function num( v : Float ) : String {
		var s = "" + Math.round(v * 100000) / 100000;
		return s.indexOf(".") < 0 ? s + ".0" : s;
	}

	/** BKube + el nombre en CamelCase: "Néon bleu" -> BKubeNeonBleu */
	public function kindName() : String {
		return "BKube" + [for( p in slug(name).split("-") ) p.charAt(0).toUpperCase() + p.substr(1)].join("");
	}

	/**
	 * Una linea de DataGen.BLOCKS. Las casillas del atlas van como [?,?] con el png al lado: hay que copiar cada png en una casilla
	 * libre de texture.png y poner su columna y su fila (de 0 a 63). Mismo orden de campos que las del juego.
	 */
	static function line( id : String, type : BlockType, tex : String, up : String, down : String, flags : Array<String>, name : String ) : String {
		return '\t\t{ id : $id, type : $type, texture : $tex, texUp : $up, texDown : $down, shadeX : null, shadeY : null, shadeUp : null, '
			+ 'shadeDown : null, power : null, weight : null, flags : [${flags.join(",")}], matter : null, name : $name, basePrice : 100 },';
	}

	public function dataGen() : String {
		inline function tile( f : Int ) return "[?,?] /*" + FACES[f] + ".png*/";
		var id = kindName();
		var quoted = '"' + StringTools.replace(name, '"', "'") + '"';
		var flags = [];
		if( light != null ) {
			flags.push("BFLight(" + num(light[0]) + (light[1] > 0 ? "," + num(light[1]) : "") + ")");
			flags.push("BFNoShade");
		}
		if( noCollide ) flags.push("BFNoCollide");
		var sz = [for( v in box ) num(v / SIZE)];
		var szY = [sz[1], sz[0], sz[2], sz[4], sz[3], sz[5]];
		var lines = [];
		switch( shape.id ) {
		case "cube":
			lines.push(line(id, blockType(), tile(SIDE), tile(UP), tile(DOWN), flags, quoted));
		case "cube6":
			// la izquierda tambien de textura base (la usa BFTextures si faltase alguna)
			var ft = "BFTextures([" + [for( f in [FRONT, BACK, LEFT, RIGHT] ) "?,? /*" + FACES[f] + ".png*/"].join(",") + "])";
			lines.push(line(id, BTExtended, tile(LEFT), tile(UP), tile(DOWN), flags.concat([ft]), quoted));
		case "box":
			lines.push(line(id, BTReduced, tile(SIDE), tile(UP), tile(DOWN), flags.concat(["BFSize(" + sz.join(",") + ")"]), quoted));
		case "door":
			// como BShipDoor: cerrada X (gira a Y con BFFlip), cerrada Y, abierta X y abierta Y; cada cerrada alterna con su abierta
			var hold = ["BFMagnet(UpDown)", "BFAnchor(Up)", "BFAnchor(Down)"];
			lines.push(line(id, BTReduced, tile(SIDE), tile(UP), tile(DOWN), flags.concat(hold).concat(["BFSize(" + sz.join(",") + ")", "BFFlip", 'BFToggle(${id}Open)']), quoted));
			lines.push(line(id + "Y", BTReduced, tile(SIDE), tile(UP), tile(DOWN), flags.concat(hold).concat(["BFSize(" + szY.join(",") + ")", 'BFToggle(${id}YOpen)']), '"-"'));
			lines.push(line(id + "Open", BTModel, tile(OPEN), "[]", "[]", flags.concat(hold).concat(["BFModel(MDoorOpenX)", "BFNoCollide"]), '"-"'));
			lines.push(line(id + "YOpen", BTModel, tile(OPEN), "[]", "[]", flags.concat(hold).concat(["BFModel(MDoorOpenY)", "BFNoCollide"]), '"-"'));
		case "plane":
			// como BWoodWindow: la X gira a la Y (la siguiente) con BFFlip
			lines.push(line(id, BTModel2Side, tile(SIDE), "[]", "[]", flags.concat(["BFModel(MPlanX)", "BFFlip"]), quoted));
			lines.push(line(id + "Y", BTModel2Side, tile(SIDE), "[]", "[]", flags.concat(["BFModel(MPlanY)"]), '"-"'));
		default:
			var multi = shape.faces.length > 1;
			lines.push(line(id, shape.type, tile(SIDE), multi ? tile(UP) : "[]", multi && usesFace(DOWN) ? tile(DOWN) : "[]", flags.concat(["BFModel(" + shape.model + ")"]), quoted));
		}
		var kinds = [for( l in lines ) l.split(",")[0].split(": ")[1]];
		return [
			"Kube \"" + name + "\" (editeur de kubes de Galaxy 55)",
			"",
			"1. Copier chaque png dans une case libre de src/G55/fla/client/gfx/texture.png (cases de 32x32, 64 colonnes x 64 lignes)",
			"   et remplacer chaque [?,?] (ou ?,? dans BFTextures) par sa colonne et sa ligne.",
			"2. Ajouter a la fin de l'enum BlockKind de src/G55/com/Common.hx : " + kinds.join(", ") + ".",
			"3. Ajouter a la fin de DataGen.BLOCKS (src/G55/com/DataGen.hx), dans le meme ordre (et une virgule apres la ligne qui",
			"   etait la derniere). Facultatif : les noms anglais et espagnols dans port/game/BlockNames.hx.",
			"",
		].concat(lines).join("\n") + "\n";
	}
}
