import Common;
import World.MeshBuf;

/**
 * Geometria suelta de un bloque (iconos del inventario y objetos que caen al romper).
 * Cada cara usa la textura del atlas y el sombreado fijo por cara del original (sqrt de shadeX/shadeY/shadeUp/shadeDown).
 */
class IconMesh {

	static inline var TE = 0.999;

	/** caja parcial en curso (x1, y1, x2, y2, z2): sus caras muestran un recorte de la casilla, como en el mundo */
	static var rb : Array<Float> = null;
	/** con las 6 caras: primero las de atras (-x, +y, abajo), para mezclar bien las translucidas sin escribir profundidad */
	static var backFirst = false;

	static function quad( m : MeshBuf, p : Array<Float>, tile : Int, shade : Float, face = -1 ) {
		if( tile < 0 || tile >= 0xFFF ) return;
		var tx = tile & 63, ty = tile >> 6;
		var u0 = tx / 64 + (1 - TE) / 128, v0 = ty / 64 + (1 - TE) / 128;
		var u1 = u0 + TE / 64, v1 = v0 + TE / 64;
		var b = m.pts.length;
		for( k in 0...4 ) m.pts.push(new h3d.col.Point(p[k * 3], p[k * 3 + 1], p[k * 3 + 2]));
		if( face >= 0 && rb != null ) {
			for( k in 0...4 ) {
				var px = p[k * 3], py = p[k * 3 + 1], pz = p[k * 3 + 2];
				var u : Float, v : Float;
				switch( face ) {
				case 0, 1: u = py - rb[1]; v = rb[2] - px;
				case 2: u = py - rb[1]; v = rb[4] - pz;
				case 3: u = rb[3] - py; v = rb[4] - pz;
				case 4: u = rb[2] - px; v = rb[4] - pz;
				default: u = px - rb[0]; v = rb[4] - pz;
				}
				m.uvs.push(new h3d.prim.UV((tx + u * TE) / 64, (ty + v * TE) / 64));
			}
		} else {
			m.uvs.push(new h3d.prim.UV(u0, v1));
			m.uvs.push(new h3d.prim.UV(u1, v1));
			m.uvs.push(new h3d.prim.UV(u1, v0));
			m.uvs.push(new h3d.prim.UV(u0, v0));
		}
		for( i in 0...4 ) m.cols.push(new h3d.col.Point(shade, shade, shade));
		m.idx.push(b); m.idx.push(b + 1); m.idx.push(b + 2);
		m.idx.push(b); m.idx.push(b + 2); m.idx.push(b + 3);
	}

	/** caja con una textura por cara; all=false solo dibuja las 3 caras que ve la camara isometrica (+x, -y, +z) */
	static function box( m : MeshBuf, b : Block, x1 : Float, y1 : Float, z1 : Float, x2 : Float, y2 : Float, z2 : Float, all : Bool, red = false ) {
		var su = Math.sqrt(b.shadeUp), sd = Math.sqrt(b.shadeDown), sx = Math.sqrt(b.shadeX), sy = Math.sqrt(b.shadeY);
		var tu = b.tu, td = b.td, tlr = b.tlr;
		if( b.type == BTExtended ) {
			quad(m, [x1, y1, z2, x2, y1, z2, x2, y2, z2, x1, y2, z2], b.tu & 0xFFF, su);
			quad(m, [x2, y1, z1, x2, y2, z1, x2, y2, z2, x2, y1, z2], b.tlr >> 12, sx);
			quad(m, [x1, y1, z1, x2, y1, z1, x2, y1, z2, x1, y1, z2], b.tu >> 12, sy);
			if( all ) {
				quad(m, [x1, y2, z1, x2, y2, z1, x2, y1, z1, x1, y1, z1], b.td & 0xFFF, sd);
				quad(m, [x1, y2, z1, x1, y1, z1, x1, y1, z2, x1, y2, z2], b.tlr & 0xFFF, sx);
				quad(m, [x2, y2, z1, x1, y2, z1, x1, y2, z2, x2, y2, z2], b.td >> 12, sy);
			}
			return;
		}
		rb = red ? [x1, y1, x2, y2, z2] : null;
		var back = function() {
			quad(m, [x1, y2, z1, x2, y2, z1, x2, y1, z1, x1, y1, z1], td, sd, 1);
			quad(m, [x1, y2, z1, x1, y1, z1, x1, y1, z2, x1, y2, z2], tlr, sx, 2);
			quad(m, [x2, y2, z1, x1, y2, z1, x1, y2, z2, x2, y2, z2], tlr, sy, 5);
		};
		if( all && backFirst ) back();
		quad(m, [x1, y1, z2, x2, y1, z2, x2, y2, z2, x1, y2, z2], tu, su, 0);
		quad(m, [x2, y1, z1, x2, y2, z1, x2, y2, z2, x2, y1, z2], tlr, sx, 3);
		quad(m, [x1, y1, z1, x2, y1, z1, x2, y1, z2, x1, y1, z2], tlr, sy, 4);
		if( all && !backFirst ) back();
		rb = null;
	}

	static function model( m : MeshBuf, b : Block ) {
		var mk = b.model != null ? b.model : MCross;
		var md = Models.get(mk);
		var v = md.v;
		for( q in 0...Std.int(v.length / 24) ) {
			var sel = Std.int(v[q * 24 + 3]);
			var tile = !md.multi || sel == 0 ? b.tlr : (sel == 1 ? b.tu : b.td);
			if( tile < 0 || tile >= 0xFFF ) continue;
			var tx = tile & 63, ty = tile >> 6;
			var base = m.pts.length;
			for( k in 0...4 ) {
				var o = q * 24 + k * 6;
				var u = v[o + 3];
				var s = v[o + 5];
				m.pts.push(new h3d.col.Point(v[o], v[o + 1], v[o + 2]));
				m.uvs.push(new h3d.prim.UV(tx / 64 + (1 - TE) / 128 + (u - Std.int(u)), ty / 64 + (1 - TE) / 128 + v[o + 4]));
				m.cols.push(new h3d.col.Point(s, s, s));
			}
			m.idx.push(base); m.idx.push(base + 1); m.idx.push(base + 2);
			m.idx.push(base + 2); m.idx.push(base + 1); m.idx.push(base + 3);
		}
	}

	/** cubo unidad con una casilla del atlas en todas las caras (efecto de "no se puede romper") */
	public static function cube( tile : Int ) : h3d.prim.Polygon {
		var m = new MeshBuf();
		quad(m, [0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1], tile, 1);
		quad(m, [0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0], tile, 1);
		quad(m, [0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1], tile, 1);
		quad(m, [1, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1], tile, 1);
		quad(m, [0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1], tile, 1);
		quad(m, [1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1], tile, 1);
		var poly = new h3d.prim.Polygon(m.pts, m.idx);
		poly.addNormals(); // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
		poly.uvs = m.uvs;
		poly.colors = m.cols;
		return poly;
	}

	/**
	 * Malla de un bloque en la celda (0..1). all=true dibuja todas las caras (objetos sueltos);
	 * scale/centro: se reduce alrededor del centro de la celda.
	 */
	public static function polygon( b : Block, all : Bool, scale = 1.0, backFaces = false ) : h3d.prim.Polygon {
		backFirst = backFaces;
		var m = new MeshBuf();
		switch( b.type ) {
		case BTModel, BTModel2Side, BTSprite:
			model(m, b);
		case BTReduced:
			var s = b.size;
			if( s == null ) box(m, b, 0, 0, 0, 1, 1, 1, all) else box(m, b, s.x1, s.y1, s.z1, s.x2, s.y2, s.z2, all, true);
		case BTInvisible:
			return null;
		default:
			box(m, b, 0, 0, 0, 1, 1, 1, all);
		}
		backFirst = false;
		if( m.pts.length == 0 ) return null;
		if( scale != 1.0 )
			for( p in m.pts ) {
				p.x = 0.5 + (p.x - 0.5) * scale;
				p.y = 0.5 + (p.y - 0.5) * scale;
				p.z = 0.5 + (p.z - 0.5) * scale;
			}
		var poly = new h3d.prim.Polygon(m.pts, m.idx);
		poly.addNormals(); // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
		poly.uvs = m.uvs;
		poly.colors = m.cols;
		return poly;
	}
}

/** Iconos 3D de los bloques para el inventario (Render.renderBlock del original: vista isometrica). */
class Icons {

	static var cache = new Map<Int, h2d.Tile>();
	static var hiresCache = new Map<Int, h2d.Tile>();
	static var scene : h3d.scene.Scene;
	public static inline var SIZE = 90;
	/** iconos grandes (Base de datos ESCorp): 256 px con mipmaps, para dibujarlos lisos a cualquier tamano */
	public static inline var HIRES = 256;

	/**
	 * Iconos grandes por hacer (anadido del port): hacer los 167 de golpe al abrir la Base de datos ESCorp la congelaba varios
	 * segundos. Se hacen unos pocos por fotograma (pump): primero los pedidos para verlos (asked), luego los de reserva (spare)
	 */
	static var asked : Array<Block> = [];
	static var spare : Array<Block> = [];
	static var waiting = new Map<Int, Array<h2d.Tile -> Void>>();
	static var hiresAtlas : h3d.mat.Texture;
	/** texturas de trabajo de cada tamano (el bloque sin contorno y la suma en fila de su alfa), para no crearlas cada vez */
	static var drawTex = new Map<Int, h3d.mat.Texture>();
	static var sumTex = new Map<Int, h3d.mat.Texture>();
	static var sumFx : h3d.pass.ScreenFx<IconAlphaSum>;
	static var outlineFx : h3d.pass.ScreenFx<IconOutline>;

	public static function get( b : Block, atlas : h3d.mat.Texture ) : h2d.Tile {
		var t = cache.get(b.index);
		if( t != null ) return t;
		var tex = new h3d.mat.Texture(SIZE, SIZE, [Target]);
		tex.filter = Linear;
		render(b, atlas, tex);
		t = h2d.Tile.fromTexture(tex);
		cache.set(b.index, t);
		return t;
	}

	/**
	 * Icono de HIRES px con mipmaps (anadido del port, Base de datos ESCorp). Dibujado con smooth = true se reduce o se agranda
	 * sin los pixeles desiguales de get() (90 px estirados con el filtro nearest de h2d). Lo hace ya; hiresLater espera su turno.
	 */
	public static function hires( b : Block, atlas : h3d.mat.Texture ) : h2d.Tile {
		var t = hiresCache.get(b.index);
		if( t != null ) return t;
		asked.remove(b);
		spare.remove(b);
		var tex = new h3d.mat.Texture(HIRES, HIRES, [Target, MipMapped]);
		tex.filter = Linear;
		tex.mipMap = Linear;
		render(b, atlas, tex);
		h3d.Engine.getCurrent().driver.generateMipMaps(tex);
		t = h2d.Tile.fromTexture(tex);
		hiresCache.set(b.index, t);
		var w = waiting.get(b.index);
		if( w != null ) {
			waiting.remove(b.index);
			for( f in w ) f(t);
		}
		return t;
	}

	/** el icono grande de b si ya esta hecho; si no, null */
	public static function hiresNow( b : Block ) : h2d.Tile {
		return hiresCache.get(b.index);
	}

	/** pide el icono grande de b para verlo: f lo recibe en cuanto este hecho (enseguida si ya lo estaba) */
	public static function hiresLater( b : Block, atlas : h3d.mat.Texture, f : h2d.Tile -> Void ) {
		var t = hiresCache.get(b.index);
		if( t != null ) {
			f(t);
			return;
		}
		hiresAtlas = atlas;
		var w = waiting.get(b.index);
		if( w == null ) waiting.set(b.index, w = []);
		w.push(f);
		if( spare.remove(b) || asked.indexOf(b) < 0 ) asked.push(b);
	}

	/** iconos grandes de reserva (los de la Base de datos ESCorp, antes de abrirla): pump los hace despues de los pedidos */
	public static function warm( list : Array<Block>, atlas : h3d.mat.Texture ) {
		hiresAtlas = atlas;
		for( b in list )
			if( !hiresCache.exists(b.index) && spare.indexOf(b) < 0 && asked.indexOf(b) < 0 ) spare.push(b);
	}

	/** queda algun icono grande por hacer (withSpare: tambien de reserva) */
	public static function busy( withSpare : Bool ) : Bool {
		return asked.length > 0 || (withSpare && spare.length > 0);
	}

	/** shaders de los iconos ya compilados por pump (warmShaders) */
	static var warmed = 0;

	/**
	 * La primera vez, pump compila los tres shaders de los iconos (el del bloque, IconAlphaSum, IconOutline) uno por llamada,
	 * con un icono de prueba por partes: los tres en la misma imagen paraban la pantalla de carga ~140 ms
	 */
	static function warmShaders( b : Block ) {
		var src = drawTex.get(HIRES);
		if( src == null ) {
			drawTex.set(HIRES, src = new h3d.mat.Texture(HIRES, HIRES, [Target]));
			sumTex.set(HIRES, new h3d.mat.Texture(HIRES, HIRES, [Target], R32F));
		}
		if( sumFx == null ) {
			sumFx = new h3d.pass.ScreenFx(new IconAlphaSum());
			outlineFx = new h3d.pass.ScreenFx(new IconOutline());
		}
		var engine = h3d.Engine.getCurrent();
		switch( warmed++ ) {
		case 0:
			draw(b, hiresAtlas, src);
		case 1:
			sumFx.shader.src = src;
			engine.pushTarget(sumTex.get(HIRES));
			sumFx.render();
			engine.popTarget();
		default:
			var tmp = new h3d.mat.Texture(HIRES, HIRES, [Target]);
			outlineFx.shader.src = src;
			outlineFx.shader.sums = sumTex.get(HIRES);
			engine.pushTarget(tmp);
			outlineFx.render();
			engine.popTarget();
			tmp.dispose();
		}
	}

	/** hace iconos grandes durante unos budgetMs (al menos uno): los pedidos y, con withSpare, los de reserva */
	public static function pump( budgetMs : Float, withSpare : Bool ) {
		if( warmed < 3 ) {
			var b = asked.length > 0 ? asked[0] : withSpare && spare.length > 0 ? spare[0] : null;
			if( b != null ) warmShaders(b);
			return;
		}
		var t0 = haxe.Timer.stamp();
		do {
			var b = asked.length > 0 ? asked.shift() : withSpare && spare.length > 0 ? spare.shift() : null;
			if( b == null ) break;
			hires(b, hiresAtlas);
		} while( (haxe.Timer.stamp() - t0) * 1000 < budgetMs );
	}

	/** termina ya los iconos grandes pedidos (antes de una captura de pantalla: que salgan todos) */
	public static function flush() {
		while( asked.length > 0 ) hires(asked[0], hiresAtlas);
	}

	/**
	 * Dibuja el icono de b en tex (Target, del tamano del icono): el bloque y luego su contorno negro (IconAlphaSum e
	 * IconOutline), todo en la GPU. Antes el contorno se hacia en la CPU: leer la imagen esperaba a la tarjeta (~20 ms por
	 * icono) y el GlowFilter del shim tardaba otros ~14 ms en uno grande
	 */
	static function render( b : Block, atlas : h3d.mat.Texture, tex : h3d.mat.Texture ) {
		var size = tex.width;
		var engine = h3d.Engine.getCurrent();
		var src = drawTex.get(size);
		if( src == null ) {
			drawTex.set(size, src = new h3d.mat.Texture(size, size, [Target]));
			sumTex.set(size, new h3d.mat.Texture(size, size, [Target], R32F));
		}
		if( !draw(b, atlas, src) ) {
			// sin malla (bloques invisibles): vacio
			engine.pushTarget(tex);
			engine.clear(0x00000000);
			engine.popTarget();
			return;
		}
		// Render.renderBlock: contorno negro, GlowFilter(0x0, 1, 2, 2, 1) sobre el icono de 45 px; aqui es de 90 px:
		// 5 en lugar de 4 porque la caja del shim solo esta centrada con un tamano impar (a otro tamano, lo mismo en proporcion)
		var blur = size == SIZE ? 5 : (Std.int(5 * size / SIZE) | 1);
		if( sumFx == null ) {
			sumFx = new h3d.pass.ScreenFx(new IconAlphaSum());
			outlineFx = new h3d.pass.ScreenFx(new IconOutline());
		}
		var sum = sumTex.get(size);
		sumFx.shader.src = src;
		sumFx.shader.size = size;
		sumFx.shader.radius = blur >> 1;
		engine.pushTarget(sum);
		sumFx.render();
		engine.popTarget();
		var s = outlineFx.shader;
		s.src = src;
		s.sums = sum;
		s.size = size;
		s.radius = blur >> 1;
		s.blur = blur;
		s.translucent = size != SIZE && (b.type == BTAlpha || b.type == BTWater) ? 1 : 0;
		engine.pushTarget(tex);
		outlineFx.render();
		engine.popTarget();
		if( Sys.args().indexOf("--dumpicons") >= 0 )
			sys.io.File.saveBytes("port/out/icon_" + b.k + (size == SIZE ? "" : "_" + size) + ".png", tex.capturePixels().toPNG());
	}

	/** dibuja el bloque, sin contorno, en tex (false si no tiene malla) */
	static function draw( b : Block, atlas : h3d.mat.Texture, tex : h3d.mat.Texture ) : Bool {
		// iconos grandes (Base de datos ESCorp) de bloques translucidos: alfa bien acumulado y sin el contorno por dentro (IconOutline)
		var translucent = tex.width != SIZE && (b.type == BTAlpha || b.type == BTWater);
		// los bloques translucidos dibujan sus 6 caras: se ve a traves el cubo entero (en los grandes, las de atras primero)
		var poly = IconMesh.polygon(b, b.type == BTAlpha, 1.0, translucent);
		if( poly == null ) return false;
		// IconShader del original: tshade = shade < 1 ? shade * shade : shade (las caras de los lados, mas oscuras que en el mundo)
		for( c in poly.colors )
			if( c.x < 1 ) {
				c.x *= c.x;
				c.y *= c.y;
				c.z *= c.z;
			}
		var engine = h3d.Engine.getCurrent();
		if( scene == null ) scene = new h3d.scene.Scene();
		var mat = h3d.mat.Material.create(atlas);
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		mat.mainPass.addShader(new h3d.shader.VertexColor());
		if( b.type == BTAlpha || b.type == BTWater ) {
			// cristal, hielo, agua: se ven translucidos, no solo sus marcos (el original los dibuja con alfa)
			mat.blendMode = Alpha;
			if( translucent ) {
				// el blend Alpha de Heaps usa SrcAlpha tambien para el alfa: sobre el fondo vacio queda a * a (casi invisible) y
				// el color premultiplicado (oscuro). Aqui el alfa se suma como debe (One, OneMinusSrcAlpha) y el color se
				// despremultiplica en IconOutline; sin escribir profundidad y con las caras de atras dibujadas antes que las de delante
				mat.mainPass.blendAlphaSrc = One;
				mat.mainPass.blendAlphaDst = OneMinusSrcAlpha;
				mat.mainPass.depthWrite = false;
			}
		} else {
			mat.textureShader.killAlpha = true;
			mat.textureShader.killAlphaThreshold = 0.5;
		}
		var mesh = new h3d.scene.Mesh(poly, mat, scene);
		var cam = scene.camera;
		// vista isometrica aproximada: perspectiva con angulo muy estrecho, desde +x, -y y arriba
		cam.orthoBounds = null;
		cam.fovY = 18;
		cam.screenRatio = 1;
		cam.zNear = 0.5;
		cam.zFar = 30;
		cam.target.set(0.5, 0.5, 0.5);
		cam.pos.set(0.5 + 4.1, 0.5 - 4.1, 0.5 + 3.4);
		cam.up.set(0, 0, 1);
		engine.pushTarget(tex);
		engine.clear(0x00000000, 1, 0);
		scene.render(engine);
		engine.popTarget();
		mesh.remove();
		poly.dispose();
		return true;
	}
}

/**
 * Contorno negro de los iconos (Render.renderBlock del original: GlowFilter(0x0, 1, blur, blur, 1)), en la GPU, primera pasada:
 * en cada pixel, la suma de los alfas (en bytes) de su fila entre x - radius y x + radius (fuera de la imagen, 0)
 */
private class IconAlphaSum extends h3d.shader.ScreenShader {

	static var SRC = {
		@param var src : Sampler2D;
		@param var size : Float;
		@param var radius : Float;

		function fragment() {
			var p = floor(fragCoord.xy);
			var sum = 0.;
			// radius es 2 o 7: un solo shader para los dos tamanos (y poco que compilar)
			for( i in 0...15 ) {
				var x = p.x + float(i) - 7.;
				if( abs(float(i) - 7.) <= radius && x >= 0. && x < size ) sum += floor(src.fetch(ivec2(vec2(x, p.y))).a * 255. + 0.5);
			}
			pixelColor = vec4(sum, 0., 0., 0.);
		}
	};
}

/**
 * Segunda pasada del contorno: suma en columna de las sumas de IconAlphaSum (la caja de blur x blur) y el icono encima. Hace lo
 * mismo que el GlowFilter del shim (BitmapData.glowCommon y over): las sumas son de enteros y, con blur impar, el redondeo del
 * alfa del contorno nunca cae en el medio; los colores se redondean con enteros. Sale igual que en la CPU, salvo algun pixel
 * cuyo color exacto cae justo en x.5: los doubles del shim lo redondeaban a un lado u otro (1/255 de diferencia).
 * Los bloques translucidos llegan premultiplicados: se despremultiplican y el contorno va solo alrededor.
 */
private class IconOutline extends h3d.shader.ScreenShader {

	static var SRC = {
		@param var src : Sampler2D;
		@param var sums : Sampler2D;
		@param var size : Float;
		@param var radius : Float;
		@param var blur : Float;
		@param var translucent : Float;

		function fragment() {
			var p = floor(fragCoord.xy);
			var sum = 0.;
			for( i in 0...15 ) {
				var y = p.y + float(i) - 7.;
				if( abs(float(i) - 7.) <= radius && y >= 0. && y < size ) sum += sums.fetch(ivec2(vec2(p.x, y))).r;
			}
			// alfa del contorno: round(sum / blur^2), como clamp255(ga * 255 + 0.5) en el shim
			var k = blur * blur;
			var g = floor((2. * sum + k) / (2. * k));
			// el icono (bytes) encima del contorno
			var c = floor(src.fetch(ivec2(p)) * 255. + 0.5);
			var a = c.a;
			var o = c;
			if( a == 0. ) o = vec4(0., 0., 0., g);
			else if( translucent > 0. ) {
				// BitmapData.unpremultiply: int(min(255, v * 255 / a))
				if( a < 255. ) o = vec4(min(vec3(255.), idiv(c.rgb * 255., a)), a);
			} else if( a < 255. && g > 0. ) {
				// BitmapData.over(contorno negro, icono): oa * 255 = d / 255 y cada color, round(v * 255 * a / d), v * 255 * a < 2^24
				var d = 255. * a + g * (255. - a);
				var n = c.rgb * a * 255.;
				var q = idiv(n, d);
				o = vec4(q + step(vec3(d), 2. * (n - q * d)), floor((2. * d + 255.) / 510.));
			}
			// + 0.25: el byte sale igual tanto si la tarjeta redondea como si trunca
			pixelColor = (o + 0.25) / 255.;
		}

		/**
		 * floor(n / d) exacto en los tres colores, con enteros positivos de menos de 2^24 (en float, exactos): la division de la
		 * tarjeta puede quedarse a un ulp y la entera no siempre es exacta; se corrige con el resto (una sola vez para los tres:
		 * menos que compilar)
		 */
		function idiv( n : Vec3, d : Float ) : Vec3 {
			var q = floor(n / d);
			var r = n - q * d;
			return q + step(vec3(d), r) - (1. - step(vec3(0.), r));
		}
	};
}
