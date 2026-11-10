import Common;

/**
 * Cosas de la tienda del robot comerciante con volumen (anadido del port): botellitas, papeles con un pergamino, pilas de monedas,
 * un frasco, y las cadenas con farolitos que cuelgan del mantel. Son modelos hechos de cajitas (como los robots), no bloques:
 * cada caja es de un color liso de la paleta de la casilla [19,60] de texture.png. Sus celdas tienen la pared invisible
 * (Mothership.shop) para que se choque con ellas; los farolitos dan luz con un bloque invisible (BShopLantern).
 */
class ShopProps {

	/** colores de la paleta (casilla [19,60]: 4x4 cuadros de 8x8) */
	static inline var RED = 0;
	static inline var GREEN = 1;
	static inline var BLUE = 2;
	static inline var CORK = 3;
	static inline var GOLD = 4;
	static inline var GOLD_DARK = 5;
	static inline var PAPER = 6;
	static inline var PAPER_DARK = 7;
	static inline var SEAL = 8;
	static inline var GLASS = 9;
	static inline var HONEY = 10;
	static inline var WOOD = 11;
	static inline var IRON = 12;
	static inline var FRAME = 13;
	static inline var GLOW = 14;

	var m : World.MeshBuf;
	var glow : World.MeshBuf;
	/** origen de la celda que se esta llenando (centro del suelo) y giro (radianes) de lo que se pone */
	var cx = 0.;
	var cy = 0.;
	var cz = 0.;

	public function new( world : World, atlas : h3d.mat.Texture, r : { x : Int, y : Int, z : Int, k : Int } ) {
		m = new World.MeshBuf();
		glow = new World.MeshBuf();
		for( g in Mothership.goods.keys() ) {
			var a = Std.int(g / 7) - 3, b = (g % 7) - 3;
			var c = Mothership.shopCell(r, a, b);
			at(c.x, c.y, r.z + 1);
			switch( Mothership.goods.get(g) ) {
			case 0: bottles();
			case 1: papers();
			case 2: coins();
			default: jar();
			}
		}
		for( c in Mothership.chains ) {
			var p = Mothership.shopCell(r, c[0], c[1]);
			at(p.x, p.y, r.z + 2);
			lantern();
		}
		var root = world.root;
		emit(root, m, atlas, world, false);
		emit(root, glow, atlas, world, true);
	}

	function at( x : Int, y : Int, z : Int ) {
		cx = x + 0.5;
		cy = y + 0.5;
		cz = z;
	}

	static function emit( root : h3d.scene.Object, b : World.MeshBuf, atlas : h3d.mat.Texture, world : World, lit : Bool ) {
		if( b.pts.length == 0 ) return;
		var poly = new h3d.prim.Polygon(b.pts, b.idx);
		poly.addNormals();
		poly.uvs = b.uvs;
		poly.colors = b.cols;
		var mat = h3d.mat.Material.create(atlas);
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		if( !lit ) mat.mainPass.addShader(new h3d.shader.VertexColor());
		mat.mainPass.addShader(world.sky.fog);
		new h3d.scene.Mesh(poly, mat, root);
	}

	/**
	 * caja de (w, d, h) con el centro de su base en (ox, oy, oz) respecto a la celda, girada rot alrededor de z, del color col.
	 * Las caras se oscurecen como las de los bloques (arriba 1, lados 0.8 y 0.65, abajo 0.5)
	 */
	function box( ox : Float, oy : Float, oz : Float, w : Float, d : Float, h : Float, col : Int, rot = 0., lit = false ) {
		var buf = lit ? glow : m;
		var ca = Math.cos(rot), sa = Math.sin(rot);
		var hw = w * 0.5, hd = d * 0.5;
		inline function P( lx : Float, ly : Float, z : Float ) return new h3d.col.Point(cx + ox + lx * ca - ly * sa, cy + oy + lx * sa + ly * ca, cz + oz + z);
		var x1 = -hw, x2 = hw, y1 = -hd, y2 = hd, z1 = 0., z2 = h;
		var u = (19 * 32 + (col & 3) * 8 + 4) / 2048, v = (60 * 32 + (col >> 2) * 8 + 4) / 2048;
		function quad( p : Array<h3d.col.Point>, shade : Float ) {
			var b = buf.pts.length;
			for( q in p ) {
				buf.pts.push(q);
				buf.uvs.push(new h3d.prim.UV(u, v));
				buf.cols.push(new h3d.col.Point(shade, shade, shade));
			}
			buf.idx.push(b); buf.idx.push(b + 1); buf.idx.push(b + 2);
			buf.idx.push(b); buf.idx.push(b + 2); buf.idx.push(b + 3);
		}
		quad([P(x1, y1, z2), P(x2, y1, z2), P(x2, y2, z2), P(x1, y2, z2)], 1.0);
		quad([P(x2, y1, z1), P(x2, y2, z1), P(x2, y2, z2), P(x2, y1, z2)], 0.8);
		quad([P(x1, y1, z1), P(x2, y1, z1), P(x2, y1, z2), P(x1, y1, z2)], 0.65);
		quad([P(x1, y2, z1), P(x2, y2, z1), P(x2, y1, z1), P(x1, y1, z1)], 0.5);
		quad([P(x1, y2, z1), P(x1, y1, z1), P(x1, y1, z2), P(x1, y2, z2)], 0.8);
		quad([P(x2, y2, z1), P(x1, y2, z1), P(x1, y2, z2), P(x2, y2, z2)], 0.65);
	}

	/** botellita: cuerpo, hombro, cuello y tapon */
	function bottle( ox : Float, oy : Float, col : Int, h : Float ) {
		box(ox, oy, 0, 0.14, 0.14, h, col);
		box(ox, oy, h, 0.1, 0.1, 0.03, col);
		box(ox, oy, h + 0.03, 0.05, 0.05, 0.09, col);
		box(ox, oy, h + 0.12, 0.065, 0.065, 0.04, CORK);
	}

	function bottles() {
		bottle(-0.24, -0.1, RED, 0.26);
		bottle(0.02, 0.14, GREEN, 0.34);
		bottle(0.25, -0.08, BLUE, 0.2);
		bottle(-0.05, -0.22, RED, 0.16);
	}

	/** hojas sueltas un poco giradas y un pergamino enrollado con su sello */
	function papers() {
		box(-0.05, 0.05, 0, 0.42, 0.3, 0.012, PAPER, 0.15);
		box(-0.02, 0.02, 0.012, 0.42, 0.3, 0.012, PAPER_DARK, -0.2);
		box(-0.06, 0.06, 0.024, 0.4, 0.28, 0.012, PAPER, 0.05);
		box(0.12, -0.22, 0, 0.36, 0.08, 0.08, PAPER_DARK, 0.4);
		box(0.12, -0.22, 0.02, 0.06, 0.09, 0.05, SEAL, 0.4);
	}

	/** tres pilas de monedas, con los cantos alternando de tono */
	function coins() {
		var piles = [[-0.2, -0.05, 5], [0.05, 0.12, 8], [0.22, -0.15, 3], [-0.02, -0.22, 1]];
		for( p in piles ) {
			var n = Std.int(p[2]);
			for( i in 0...n ) box(p[0], p[1], i * 0.028, 0.15, 0.15, 0.026, i % 2 == 0 ? GOLD : GOLD_DARK, i * 0.3);
		}
	}

	/** frasco de miel: el liquido, el cristal de arriba, la tapa de madera */
	function jar() {
		box(0, 0, 0, 0.28, 0.28, 0.24, HONEY);
		box(0, 0, 0.24, 0.28, 0.28, 0.1, GLASS);
		box(0, 0, 0.34, 0.32, 0.32, 0.05, WOOD);
		box(0, 0, 0.39, 0.12, 0.12, 0.03, WOOD);
	}

	/** farolito: base, cuatro postes, el cristal encendido, la tapa, y la cadena de eslabones hasta el mantel (1.5 por encima) */
	function lantern() {
		var b = 0.15;
		box(0, 0, b, 0.34, 0.34, 0.05, FRAME);
		for( s in [[-1, -1], [1, -1], [1, 1], [-1, 1]] ) box(s[0] * 0.14, s[1] * 0.14, b + 0.05, 0.04, 0.04, 0.4, FRAME);
		box(0, 0, b + 0.06, 0.24, 0.24, 0.38, GLOW, 0, true);
		box(0, 0, b + 0.45, 0.36, 0.36, 0.05, FRAME);
		box(0, 0, b + 0.5, 0.16, 0.16, 0.05, FRAME);
		var z = b + 0.55;
		var i = 0;
		while( z < 2.0 ) {
			box(0, 0, z, i % 2 == 0 ? 0.03 : 0.09, i % 2 == 0 ? 0.09 : 0.03, 0.11, IRON);
			z += 0.09;
			i++;
		}
	}
}
