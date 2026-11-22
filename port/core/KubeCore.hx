import Common;

typedef KubeShape = {
	var id : String;
	var type : BlockType;
	var model : Null<BlockModel>;
	var faces : Array<Int>;
	/** caja parcial (BFSize) que se puede cambiar */
	var box : Bool;
}

/**
 * Un kube del editor tal como lo manda el servidor a los jugadores (anadido del port, multijugador): solo datos brutos de tamano
 * fijo y acotado (forma por su numero en KubeCore.SHAPES, caja, luz, nombre corto y los pixeles ARGB de las 8 caras de 32x32).
 * Ni zip, ni PNG, ni JSON, ni nombre de archivo: no hay nada que descomprimir, interpretar ni escribir en disco.
 */
typedef NetKube = {
	/** su archivo en el servidor (minusculas, letras, cifras, - _ .): solo para reconocerlo */
	var id : String;
	var name : String;
	var shape : Int;
	/** cubo: 0 opaco, 1 calado, 2 translucido */
	var render : Int;
	/** x1 y1 z1 x2 y2 z2 en pixeles (0..32) */
	var box : Array<Int>;
	/** potencia de la luz (0 = sin luz) y caida */
	var light : Float;
	var reach : Float;
	var noCollide : Bool;
	/** 8 caras x 32 x 32 pixeles ARGB (FACE_BYTES cada una), en el orden de FACES */
	var faces : haxe.io.Bytes;
}

/**
 * Lo de los kubes del editor que no dibuja (anadido del port para el multijugador, sacado de KubeData y EditorKubes): sus formas,
 * los bloques de Block.all de cada kube y como se configuran, y el formato que manda el servidor. El juego y el servidor usan los
 * mismos bloques para el kube numero i (blocksFor): asi un numero de bloque significa lo mismo en los dos.
 */
class KubeCore {

	public static inline var SIZE = 32;
	public static inline var SIDE = 0;
	public static inline var UP = 1;
	public static inline var DOWN = 2;
	public static inline var FRONT = 3;
	public static inline var BACK = 4;
	public static inline var LEFT = 5;
	public static inline var RIGHT = 6;
	public static inline var OPEN = 7;
	/** bloques de Block.all por kube */
	public static inline var PER = 4;
	/** kubes como mucho (EditorKubes.MAX) */
	public static inline var MAX = 128;
	public static inline var NAME_MAX = 24;
	public static inline var ID_MAX = 40;
	public static inline var FACE_BYTES = SIZE * SIZE * 4;
	/** nombre del png de cada cara dentro del .kube */
	public static var FACES = ["side", "up", "down", "front", "back", "left", "right", "open"];

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
		// anadido del port: tableau colgado de una pared (Painting, BFOnWall); su caja va en pixeles de la imagen vista de frente
		{ id : "painting", type : BTModel, model : null, faces : [SIDE], box : true },
	];
	/** rendu del cubo: opaco (BTFull), calado como las hojas (BTTransp) o translucido como el cristal (BTAlpha) */
	public static var RENDERS = [BTFull, BTTransp, BTAlpha];

	public static function shapeIndex( id : String ) : Int {
		for( i in 0...SHAPES.length ) if( SHAPES[i].id == id ) return i;
		return 0;
	}

	// ---------------------------------------------------------------- bloques de cada kube

	static var slots : Array<Array<Block>> = [];

	/** los PER bloques del kube numero i: se crean al final de Block.all la primera vez y son siempre los mismos */
	public static function blocksFor( i : Int ) : Array<Block> {
		while( slots.length <= i ) slots.push([for( _ in 0...PER ) newBlock()]);
		return slots[i];
	}

	/**
	 * Los bloques de los MAX kubes, ya: los que se anadan despues a Block.all (bloques de remplazo de SaveNames) van detras y el
	 * kube numero i sigue teniendo los mismos indices que en el servidor (que no tiene bloques de remplazo)
	 */
	public static function reserveAll() blocksFor(MAX - 1);

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

	/** un bloque del kube sin forma: lo que Block.new y Block.initBlocks dejan antes de leer las banderas */
	public static function reset( b : Block, name : String ) {
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

	/**
	 * Los bloques de un kube: los mismos campos que Block.initBlocks deja con las lineas de KubeData.dataGen. tile(cara) es la
	 * casilla del atlas de esa cara (0xFFF sin dibujo: el servidor). light: [potencia, caida] o null.
	 */
	public static function setup( blocks : Array<Block>, name : String, shape : KubeShape, render : Int, box : Array<Int>, light : Array<Float>,
		noCollide : Bool, tile : Int -> Int ) {
		for( b in blocks ) reset(b, name);
		var b = blocks[0];
		var flags = [];
		if( light != null ) {
			var l = light[1] > 0 ? BFLight(light[0], light[1]) : BFLight(light[0]);
			flags.push(l);
			flags.push(BFNoShade);
		}
		if( noCollide ) flags.push(BFNoCollide);
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
		var sz = { x1 : box[0] / SIZE, y1 : box[1] / SIZE, z1 : box[2] / SIZE, x2 : box[3] / SIZE, y2 : box[4] / SIZE, z2 : box[5] / SIZE };
		b.tlr = tile(SIDE);
		b.tu = tile(UP);
		b.td = tile(DOWN);
		switch( shape.id ) {
		case "cube":
			b.type = RENDERS[render < 0 || render >= RENDERS.length ? 0 : render];
			common(b, []);
		case "cube6":
			b.type = BTExtended;
			b.tlr = (tile(FRONT) << 12) | tile(BACK);
			b.tu = (tile(LEFT) << 12) | tile(UP);
			b.td = (tile(RIGHT) << 12) | tile(DOWN);
			common(b, []);
		case "box":
			b.type = BTReduced;
			b.size = sz;
			common(b, [BFSize(sz.x1, sz.y1, sz.z1, sz.x2, sz.y2, sz.z2)]);
		case "door":
			// como BShipDoor: cerrada X (gira a Y), cerrada Y y las dos abiertas; cada cerrada alterna con su abierta
			var y = blocks[1], ox = blocks[2], oy = blocks[3];
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
				o.tlr = o.tu = o.td = tile(OPEN);
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
			var sizes = Painting.sizes(box);
			for( t in 0...PER ) {
				var c = blocks[t], z = sizes[t];
				c.type = BTModel;
				c.tlr = c.tu = c.td = b.tlr;
				c.size = z;
				c.wall = t;
				common(c, [BFOnWall(t), BFSize(z.x1, z.y1, z.z1, z.x2, z.y2, z.z2), BFMagnet(None)]);
			}
		case "plane":
			// como BWoodWindow: la X gira a la Y con BFFlip
			var y = blocks[1];
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
			b.type = shape.type;
			b.model = shape.model;
			if( shape.faces.length == 1 ) b.tu = b.td = b.tlr;
			else if( shape.faces.indexOf(DOWN) < 0 ) b.td = b.tlr;
			common(b, [BFModel(shape.model)]);
		}
		// las colisiones de los modelos sin BFSize usan su propia caja (como hace World al crearse, Builder.init)
		for( x in blocks )
			if( x.model != null && x.size == null ) x.size = Models.get(x.model).box;
	}

	/** los bloques de un kube que llega del servidor (o que el servidor ha leido de un .kube) */
	public static function setupNet( blocks : Array<Block>, k : NetKube, tile : Int -> Int ) {
		setup(blocks, k.name, SHAPES[k.shape], k.render, k.box, k.light > 0 ? [k.light, k.reach] : null, k.noCollide, tile);
	}

	// ---------------------------------------------------------------- formato del servidor

	/** un kube que llega por la red vale: todo dentro de sus limites y las caras del tamano exacto */
	public static function valid( k : NetKube ) : Bool {
		if( k == null || k.id == null || k.name == null || k.box == null || k.faces == null ) return false;
		if( k.id.length == 0 || k.id.length > ID_MAX || !~/^[a-z0-9_.\-]+$/.match(k.id) ) return false;
		if( k.name.length > NAME_MAX ) return false;
		if( k.shape < 0 || k.shape >= SHAPES.length || k.render < 0 || k.render >= RENDERS.length ) return false;
		if( k.box.length != 6 ) return false;
		for( v in k.box ) if( v < 0 || v > SIZE ) return false;
		if( !(k.light >= 0 && k.light <= 15) || !(k.reach >= 0 && k.reach <= 15) ) return false;
		return k.faces.length == FACES.length * FACE_BYTES;
	}

	/** el nombre, sin lo que no se puede ensenar (caracteres de control) y corto */
	public static function cleanName( s : String ) : String {
		var out = new StringBuf();
		for( i in 0...s.length ) {
			var c = s.charCodeAt(i);
			if( c >= 32 && c != 127 ) out.addChar(c);
		}
		var r = StringTools.trim(out.toString());
		return r.length > NAME_MAX ? r.substr(0, NAME_MAX) : r;
	}

	/**
	 * Un .kube (zip con kube.json y un png de 32x32 por cara, KubeData.save) leido sin el juego: el servidor manda asi los kubes
	 * de su carpeta. null si no se puede leer. Lo leido se acota (cada archivo del zip, 1 Mo como mucho).
	 */
	public static function fromKubeFile( bytes : haxe.io.Bytes, id : String ) : NetKube {
		try {
			var files = new Map<String, haxe.io.Bytes>();
			for( e in haxe.zip.Reader.readZip(new haxe.io.BytesInput(bytes)) ) {
				if( e.fileSize > 1 << 20 ) continue;
				var n = e.fileName.split("/").pop().split("\\").pop().toLowerCase();
				if( n != "" ) files.set(n, haxe.zip.Reader.unzip(e));
			}
			var j : Dynamic = haxe.Json.parse(files.get("kube.json").toString());
			var shape = shapeIndex(Std.string(j.shape));
			var r : String = j.render;
			var box = [0, 0, 0, SIZE, SIZE, SIZE];
			var bx : Array<Dynamic> = j.box;
			if( bx != null && bx.length == 6 ) box = [for( v in bx ) Std.int(Math.max(0, Math.min(SIZE, Std.parseInt("" + v))))];
			if( SHAPES[shape].id == "painting" ) {
				box[1] = 0;
				if( box[4] < 1 ) box[4] = 1;
			}
			var l : Array<Dynamic> = j.light;
			var faces = haxe.io.Bytes.alloc(FACES.length * FACE_BYTES);
			var got = [for( _ in FACES ) false];
			for( f in 0...FACES.length ) {
				var png = files.get(FACES[f] + ".png");
				if( png == null ) continue;
				var d = new format.png.Reader(new haxe.io.BytesInput(png)).read();
				var h = format.png.Tools.getHeader(d);
				var px = format.png.Tools.extract32(d);
				// un png que no es de 32x32 (retocado a mano) se lee por su esquina de arriba a la izquierda
				for( y in 0...Std.int(Math.min(SIZE, h.height)) )
					for( x in 0...Std.int(Math.min(SIZE, h.width)) )
						faces.setInt32(f * FACE_BYTES + (y * SIZE + x) * 4, px.getInt32((y * h.width + x) * 4));
				got[f] = true;
			}
			// las caras que la forma usa y no estan toman la de los lados (KubeData.fillMissingFaces)
			for( f in SHAPES[shape].faces )
				if( !got[f] && got[SIDE] ) faces.blit(f * FACE_BYTES, faces, SIDE * FACE_BYTES, FACE_BYTES);
			var name = cleanName(j.name != null ? "" + j.name : id);
			var k : NetKube = { id : id, name : name, shape : shape, render : r == "cutout" ? 1 : r == "blend" ? 2 : 0, box : box,
				light : l != null && l.length >= 1 ? Math.max(0, Math.min(15, Std.parseFloat("" + l[0]))) : 0.,
				reach : l != null && l.length > 1 ? Math.max(0, Math.min(15, Std.parseFloat("" + l[1]))) : 0.,
				noCollide : j.noCollide == true, faces : faces };
			if( Math.isNaN(k.light) ) k.light = 0;
			if( Math.isNaN(k.reach) ) k.reach = 0;
			return valid(k) ? k : null;
		} catch( e : Dynamic ) {
			return null;
		}
	}
}
