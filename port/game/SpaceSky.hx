/**
 * Cielo de espacio profundo de la nave nodriza (anadido del port): un cubo alrededor de la camara con 6 texturas
 * generadas una vez (Via Lactea con polvo oscuro y nucleo calido, nebulosas de gas de varios colores, decenas de miles
 * de estrellas con el color de su temperatura y algunas galaxias lejanas). Se guardan en la carpeta de datos
 * (space_v1_<cara>.png) para no tener que generarlas cada vez.
 */
class SpaceSky {

	static inline var N = 1024;     // resolucion de cada cara
	static inline var NN = 256;     // resolucion del campo de gas (se interpola)
	static inline var VERSION = 2;

	// caras del cubo: direccion central F y ejes U (columnas) y V (filas)
	static var FACES = [
		[1., 0, 0, 0, 1, 0, 0, 0, -1], [-1., 0, 0, 0, -1, 0, 0, 0, -1],
		[0., 1, 0, -1, 0, 0, 0, 0, -1], [0., -1, 0, 1, 0, 0, 0, 0, -1],
		[0., 0, 1, 1, 0, 0, 0, 1, 0], [0., 0, -1, 1, 0, 0, 0, -1, 0],
	];

	/**
	 * Pone el cubo del cielo en parent y devuelve la tarea que pinta sus caras. De una vez, leerlas paraba la carga de la nave
	 * nodriza ~180 ms y generarlas la primera vez ~6 s (4 s de calculo y 2 de PNG). Cada llamada a la tarea hace un trozo (una
	 * cara leida, unas filas calculadas, una cara guardada) y devuelve false al acabar; las caras que faltan son negras. Los
	 * mismos calculos en el mismo orden: el mismo cielo
	 */
	public static function build( parent : h3d.scene.Object ) : Void -> Bool {
		var root = new h3d.scene.Object(parent);
		var H = 350.;
		var mats = [];
		for( f in 0...6 ) {
			var d = FACES[f];
			var F = new h3d.col.Point(d[0], d[1], d[2]), U = new h3d.col.Point(d[3], d[4], d[5]), V = new h3d.col.Point(d[6], d[7], d[8]);
			inline function corner( u : Float, v : Float ) return new h3d.col.Point((F.x + U.x * u + V.x * v) * H, (F.y + U.y * u + V.y * v) * H, (F.z + U.z * u + V.z * v) * H);
			var pts = [corner(-1, -1), corner(1, -1), corner(1, 1), corner(-1, 1)];
			var idx = new hxd.IndexBuffer();
			for( i in [0, 1, 2, 0, 2, 3] ) idx.push(i);
			var poly = new h3d.prim.Polygon(pts, idx);
			poly.addNormals(); // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
			poly.uvs = [new h3d.prim.UV(0, 0), new h3d.prim.UV(1, 0), new h3d.prim.UV(1, 1), new h3d.prim.UV(0, 1)];
			var mat = h3d.mat.Material.create(h3d.mat.Texture.fromColor(0));
			mat.shadows = false;
			mat.mainPass.enableLights = false;
			mat.mainPass.culling = None;
			mat.mainPass.depthWrite = false;
			new h3d.scene.Mesh(poly, mat, root);
			mats.push(mat);
		}
		function show( f : Int, px : hxd.Pixels ) {
			px.convert(RGBA); // toPNG la deja en BGRA y DirectX no la acepta
			var tex = h3d.mat.Texture.fromPixels(px);
			tex.filter = Linear;
			tex.wrap = Clamp;
			mats[f].texture = tex;
		}
		for( f in 0...6 )
			if( !sys.FileSystem.exists(path(f)) ) return generate(show);
		// guardadas: una cara por llamada (si una no se puede leer, se generan todas)
		var f = 0, gen : Void -> Bool = null;
		return function() {
			if( gen != null ) return gen();
			var px = load(f);
			if( px == null ) {
				gen = generate(show);
				return true;
			}
			show(f, px);
			return ++f < 6;
		};
	}

	static function path( f : Int ) return Settings.dir() + "/space_v" + VERSION + "_" + f + ".png";

	static function load( f : Int ) : hxd.Pixels {
		try {
			var px = hxd.res.Any.fromBytes("s.png", sys.io.File.getBytes(path(f))).toImage().getPixels();
			px.convert(RGBA);
			return px;
		} catch( e : Dynamic ) return null;
	}

	// ---------------------------------------------------------------- ruido 3D (sin costuras entre caras)

	static var perm : haxe.ds.Vector<Int>;

	static function initNoise( seed : Int ) {
		perm = new haxe.ds.Vector(512);
		var r = new hxd.Rand(seed);
		var p = [for( i in 0...256 ) i];
		for( i in 0...256 ) {
			var j = r.random(256);
			var t = p[i]; p[i] = p[j]; p[j] = t;
		}
		for( i in 0...512 ) perm[i] = p[i & 255];
	}

	static inline function fade( t : Float ) return t * t * (3 - 2 * t);

	static function noise( x : Float, y : Float, z : Float ) : Float {
		var xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
		var xf = x - xi, yf = y - yi, zf = z - zi;
		var X = xi & 255, Y = yi & 255, Z = zi & 255;
		inline function h( a : Int, b : Int, c : Int ) return perm[perm[perm[(X + a) & 255] + ((Y + b) & 255)] + ((Z + c) & 255)] / 255.;
		var u = fade(xf), v = fade(yf), w = fade(zf);
		var x00 = h(0, 0, 0) + (h(1, 0, 0) - h(0, 0, 0)) * u;
		var x10 = h(0, 1, 0) + (h(1, 1, 0) - h(0, 1, 0)) * u;
		var x01 = h(0, 0, 1) + (h(1, 0, 1) - h(0, 0, 1)) * u;
		var x11 = h(0, 1, 1) + (h(1, 1, 1) - h(0, 1, 1)) * u;
		var y0 = x00 + (x10 - x00) * v, y1 = x01 + (x11 - x01) * v;
		return y0 + (y1 - y0) * w;
	}

	static function fbm( x : Float, y : Float, z : Float, oct : Int ) : Float {
		var s = 0., a = 0.5, f = 1., n = 0.;
		for( i in 0...oct ) {
			s += noise(x * f, y * f, z * f) * a;
			n += a;
			a *= 0.5;
			f *= 2.03;
		}
		return s / n;
	}

	// ---------------------------------------------------------------- generacion

	static function dirOf( f : Int, u : Float, v : Float, out : Array<Float> ) {
		var d = FACES[f];
		var x = d[0] + d[3] * u + d[6] * v, y = d[1] + d[4] * u + d[7] * v, z = d[2] + d[5] * u + d[8] * v;
		var l = Math.sqrt(x * x + y * y + z * z);
		out[0] = x / l; out[1] = y / l; out[2] = z / l;
	}

	/**
	 * Genera las 6 caras a trozos (ver build): cada llamada a la tarea hace una fila del gas, 16 filas del gas interpolado o del
	 * paso a pixeles, 2000 estrellas, una galaxia o guarda una cara; show recibe cada cara en cuanto esta. Las etapas, el orden de
	 * las filas y el del azar son los de antes
	 */
	static function generate( show : Int -> hxd.Pixels -> Void ) : Void -> Bool {
		initNoise(5555);
		var rnd = new hxd.Rand(7777);
		inline function norm( a : Array<Float> ) { var l = Math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]); a[0] /= l; a[1] /= l; a[2] /= l; return a; }
		// plano de la galaxia (inclinado) y direccion de su nucleo
		var gN = norm([0.25, -0.35, 0.9]);
		var gC = norm([0.9, 0.3, -0.05]);
		// quitar a gC su componente normal para que el nucleo este en la banda
		var k = gC[0] * gN[0] + gC[1] * gN[1] + gC[2] * gN[2];
		gC = norm([gC[0] - gN[0] * k, gC[1] - gN[1] * k, gC[2] - gN[2] * k]);
		// nebulosas: direccion, tamano angular y dos colores (gas ionizado rojo/rosa, oxigeno verde-azulado, reflexion azul)
		var nebCols = [[[0.85, 0.18, 0.32], [0.25, 0.75, 0.8]], [[0.3, 0.45, 1.0], [0.75, 0.35, 0.9]], [[0.95, 0.35, 0.25], [1.0, 0.75, 0.4]],
			[[0.2, 0.8, 0.65], [0.35, 0.3, 0.95]], [[0.9, 0.25, 0.6], [0.4, 0.2, 0.7]]];
		var nebs : Array<Neb> = [];
		for( i in 0...6 ) {
			var z = rnd.srand() * 0.85, a = rnd.rand() * Math.PI * 2, r = Math.sqrt(1 - z * z);
			nebs.push({ d : [Math.cos(a) * r, Math.sin(a) * r, z], size : 0.35 + rnd.rand() * 0.35, c : nebCols[i % nebCols.length], seed : rnd.rand() * 100 });
		}

		var gas = [for( f in 0...6 ) new haxe.ds.Vector<Float>(NN * NN * 3)];
		var img = [for( f in 0...6 ) new haxe.ds.Vector<Float>(N * N * 3)];
		var out = new Array<hxd.Pixels>();
		var d = [0., 0, 0];
		var stage = 0, f = 0, j = 0, s = 0, gi = 0;
		return function() {
			switch( stage ) {
			case 0:
				// 1) gas y polvo a baja resolucion, por cara (r, g, b en 0..)
				gasRow(f, j, gas[f], d, gN, gC, nebs);
				if( ++j == NN ) {
					j = 0;
					if( ++f == 6 ) { f = 0; stage = 1; }
				}
			case 1:
				// 2) a resolucion completa: gas interpolado
				for( k in 0...16 ) interpRow(j + k, gas[f], img[f]);
				j += 16;
				if( j == N ) {
					j = 0;
					if( ++f == 6 ) { f = 0; stage = 2; }
				}
			case 2:
				// 3) estrellas: repartidas por la esfera y muchas mas en la banda de la galaxia
				var end = s + 2000 < 60000 ? s + 2000 : 60000;
				while( s < end ) {
					star(s, rnd, gN, gC, img);
					s++;
				}
				if( s == 60000 ) stage = 3;
			case 3:
				// 4) galaxias lejanas: elipses pequenas con nucleo y brazos tenues
				galaxy(rnd, img);
				if( ++gi == 7 ) stage = 4;
			case 4:
				// 5) a pixeles (curva suave para que lo brillante no se queme)
				if( j == 0 ) out[f] = hxd.Pixels.alloc(N, N, BGRA);
				for( k in 0...16 ) toneRow(j + k, img[f], out[f]);
				j += 16;
				if( j == N ) {
					out[f].convert(RGBA); // DirectX no acepta BGRA
					show(f, out[f]);
					j = 0;
					if( ++f == 6 ) { f = 0; stage = 5; }
				}
			default:
				// se guardan para no generarlas la proxima vez, una cara por llamada; con la compresion mas rapida (los mismos
				// pixeles; con la maxima, ~330 ms por cara)
				try sys.io.File.saveBytes(path(f), out[f].toPNG(1)) catch( e : Dynamic ) {}
				out[f] = null;
				return ++f < 6;
			}
			return true;
		};
	}

	static function gasRow( f : Int, j : Int, g : haxe.ds.Vector<Float>, d : Array<Float>, gN : Array<Float>, gC : Array<Float>, nebs : Array<Neb> ) {
		for( i in 0...NN ) {
			dirOf(f, (i + 0.5) / NN * 2 - 1, (j + 0.5) / NN * 2 - 1, d);
			var x = d[0], y = d[1], z = d[2];
			var r = 0.004, gg = 0.004, b = 0.012; // fondo: casi negro, un pelo azulado
			// Via Lactea
			var lat = Math.asin(Math.max(-1, Math.min(1, x * gN[0] + y * gN[1] + z * gN[2])));
			var band = Math.exp(-(lat * lat) / (0.2 * 0.2));
			if( band > 0.01 ) {
				var cd = Math.acos(Math.max(-1, Math.min(1, x * gC[0] + y * gC[1] + z * gC[2])));
				var core = Math.exp(-(cd * cd) / 0.35) * Math.exp(-(lat * lat) / (0.12 * 0.12));
				var cloud = fbm(x * 6 + 11, y * 6, z * 6, 6);
				var dens = band * (0.25 + 0.75 * cloud * cloud * 1.6) * (0.35 + 0.65 * Math.exp(-(cd * cd) / 2.5));
				// polvo oscuro: franjas finas cerca del plano
				var dust = 1 - Math.abs(fbm(x * 9 + 3, y * 9 + 7, z * 9, 6) * 2 - 1); // crestas: filamentos de polvo
				var lane = Math.exp(-((lat - 0.02) * (lat - 0.02)) / (0.08 * 0.08));
				var absorb = Math.max(0, Math.min(0.9, (dust - 0.72) * 4.0 * lane + lane * 0.2));
				var lum = (dens * 0.26 + core * 0.55) * (1 - absorb);
				r += lum * (0.95 + core * 0.25);
				gg += lum * (0.88 + core * 0.05);
				b += lum * (0.8 - core * 0.35);
			}
			// nebulosas
			for( n in nebs ) {
				var dot = x * n.d[0] + y * n.d[1] + z * n.d[2];
				if( dot < 0.4 ) continue;
				var ang = Math.acos(Math.min(1, dot));
				var fall = Math.max(0, 1 - ang / n.size);
				if( fall <= 0 ) continue;
				fall = fall * fall * (3 - 2 * fall);
				// deformacion del dominio para formas de gas
				var s = 4.0 / n.size;
				var wx = fbm(x * s + n.seed, y * s, z * s, 4), wy = fbm(x * s, y * s + n.seed, z * s + 5, 4);
				var q = fbm(x * s + wx * 2.2 + n.seed, y * s + wy * 2.2, z * s + n.seed * 0.5, 6);
				var dens = Math.max(0, q - 0.33) * 2.6 * fall;
				var mix = fbm(x * s * 0.7 + 40, y * s * 0.7 + n.seed, z * s * 0.7, 3);
				mix = Math.max(0, Math.min(1, (mix - 0.35) * 3));
				var c0 = n.c[0], c1 = n.c[1];
				var dd = dens * dens * 1.1 + dens * 0.05;
				r += dd * (c0[0] * (1 - mix) + c1[0] * mix);
				gg += dd * (c0[1] * (1 - mix) + c1[1] * mix);
				b += dd * (c0[2] * (1 - mix) + c1[2] * mix);
			}
			var p = (i + j * NN) * 3;
			g[p] = r; g[p + 1] = gg; g[p + 2] = b;
		}
	}

	static function interpRow( j : Int, g : haxe.ds.Vector<Float>, o : haxe.ds.Vector<Float> ) {
		for( i in 0...N ) {
			var fx = (i + 0.5) / N * NN - 0.5, fy = (j + 0.5) / N * NN - 0.5;
			var x0 = Std.int(Math.max(0, Math.floor(fx))), y0 = Std.int(Math.max(0, Math.floor(fy)));
			var x1 = x0 + 1 < NN ? x0 + 1 : x0, y1 = y0 + 1 < NN ? y0 + 1 : y0;
			var tx = Math.max(0, Math.min(1, fx - x0)), ty = Math.max(0, Math.min(1, fy - y0));
			var p = (i + j * N) * 3;
			for( c in 0...3 ) {
				var a = g[(x0 + y0 * NN) * 3 + c] + (g[(x1 + y0 * NN) * 3 + c] - g[(x0 + y0 * NN) * 3 + c]) * tx;
				var bb = g[(x0 + y1 * NN) * 3 + c] + (g[(x1 + y1 * NN) * 3 + c] - g[(x0 + y1 * NN) * 3 + c]) * tx;
				o[p + c] = a + (bb - a) * ty;
			}
		}
	}

	static function plot( img : Array<haxe.ds.Vector<Float>>, dx : Float, dy : Float, dz : Float, r : Float, g : Float, b : Float, glow : Float ) {
		var ax = Math.abs(dx), ay = Math.abs(dy), az = Math.abs(dz);
		var f = ax >= ay && ax >= az ? (dx > 0 ? 0 : 1) : (ay >= az ? (dy > 0 ? 2 : 3) : (dz > 0 ? 4 : 5));
		var F = FACES[f];
		var t = dx * F[0] + dy * F[1] + dz * F[2];
		var u = (dx * F[3] + dy * F[4] + dz * F[5]) / t, v = (dx * F[6] + dy * F[7] + dz * F[8]) / t;
		var px = (u + 1) * 0.5 * N - 0.5, py = (v + 1) * 0.5 * N - 0.5;
		var o = img[f];
		var ix = Math.floor(px), iy = Math.floor(py);
		var fx = px - ix, fy = py - iy;
		// punto repartido en 2x2 (sin escalones) y halo para las brillantes
		var rad = glow > 0 ? Std.int(Math.ceil(glow * 3)) : 0;
		for( oy in -rad...rad + 2 ) for( ox in -rad...rad + 2 ) {
			var X = ix + ox, Y = iy + oy;
			if( X < 0 || Y < 0 || X >= N || Y >= N ) continue;
			var w = 0.;
			if( ox >= 0 && ox <= 1 && oy >= 0 && oy <= 1 ) w = (ox == 0 ? 1 - fx : fx) * (oy == 0 ? 1 - fy : fy);
			if( glow > 0 ) {
				var ddx = X - px, ddy = Y - py;
				w += Math.exp(-(ddx * ddx + ddy * ddy) / (glow * glow)) * 0.35;
			}
			if( w <= 0 ) continue;
			var p = (X + Y * N) * 3;
			o[p] += r * w; o[p + 1] += g * w; o[p + 2] += b * w;
		}
	}

	// color segun temperatura: azules, blancas, amarillas, naranjas y rojas (las frias son mas comunes)
	static var TEMPS = [[0.65, 0.75, 1.0], [0.85, 0.9, 1.0], [1.0, 1.0, 1.0], [1.0, 0.95, 0.82], [1.0, 0.82, 0.6], [1.0, 0.65, 0.45]];
	static var TW = [0.06, 0.14, 0.24, 0.24, 0.2, 0.12];

	static function starColor( rnd : hxd.Rand ) {
		var x = rnd.rand(), i = 0;
		while( i < TW.length - 1 && x > TW[i] ) { x -= TW[i]; i++; }
		return TEMPS[i];
	}

	/** la estrella numero s (las 26000 primeras repartidas por la esfera, las demas en la banda de la galaxia) */
	static function star( s : Int, rnd : hxd.Rand, gN : Array<Float>, gC : Array<Float>, img : Array<haxe.ds.Vector<Float>> ) {
		var x, y, z;
		if( s < 26000 ) {
			var zz = rnd.srand(), a = rnd.rand() * Math.PI * 2, r = Math.sqrt(1 - zz * zz);
			x = Math.cos(a) * r; y = Math.sin(a) * r; z = zz;
		} else {
			// en la banda: latitud gaussiana alrededor del plano gN
			var a = rnd.rand() * Math.PI * 2;
			var lat = (rnd.rand() + rnd.rand() + rnd.rand() - 1.5) * 0.22;
			// base del plano
			var e1 = gC, e2 = [gN[1] * gC[2] - gN[2] * gC[1], gN[2] * gC[0] - gN[0] * gC[2], gN[0] * gC[1] - gN[1] * gC[0]];
			var c = Math.cos(lat);
			x = (e1[0] * Math.cos(a) + e2[0] * Math.sin(a)) * c + gN[0] * Math.sin(lat);
			y = (e1[1] * Math.cos(a) + e2[1] * Math.sin(a)) * c + gN[1] * Math.sin(lat);
			z = (e1[2] * Math.cos(a) + e2[2] * Math.sin(a)) * c + gN[2] * Math.sin(lat);
		}
		// brillo: muchas debiles, pocas brillantes (ley de potencias)
		var m = Math.pow(rnd.rand(), 9.0);
		var bright = 0.07 + m * 2.2;
		var col = starColor(rnd);
		var glow = m > 0.55 ? 0.7 + m * 1.4 : 0.;
		plot(img, x, y, z, col[0] * bright, col[1] * bright, col[2] * bright, glow);
	}

	static function galaxy( rnd : hxd.Rand, img : Array<haxe.ds.Vector<Float>> ) {
		var zz = rnd.srand(), a = rnd.rand() * Math.PI * 2, r = Math.sqrt(1 - zz * zz);
		var cx = Math.cos(a) * r, cy = Math.sin(a) * r, cz = zz;
		// base tangente
		var ux = -cy, uy = cx, uz = 0.;
		var ul = Math.sqrt(ux * ux + uy * uy);
		if( ul < 1e-4 ) { ux = 1; uy = 0; ul = 1; }
		ux /= ul; uy /= ul;
		var vx = cy * uz - cz * uy, vy = cz * ux - cx * uz, vz = cx * uy - cy * ux;
		var size = 0.012 + rnd.rand() * 0.02, tilt = 0.3 + rnd.rand() * 0.6, rot = rnd.rand() * Math.PI;
		var tint = rnd.random(2) == 0 ? [1.0, 0.92, 0.8] : [0.8, 0.88, 1.0];
		for( k in 0...900 ) {
			var t = Math.pow(rnd.rand(), 0.8);
			var arm = rnd.random(2) * Math.PI;
			var ang = arm + t * 5.5 + rnd.srand() * 0.45;
			var rr = t * size;
			var ex = Math.cos(ang) * rr, ey = Math.sin(ang) * rr * tilt;
			var qx = ex * Math.cos(rot) - ey * Math.sin(rot), qy = ex * Math.sin(rot) + ey * Math.cos(rot);
			var b = 0.05 * (1.2 - t);
			plot(img, cx + ux * qx + vx * qy, cy + uy * qx + vy * qy, cz + uz * qx + vz * qy, tint[0] * b, tint[1] * b, tint[2] * b, 0);
		}
		plot(img, cx, cy, cz, tint[0] * 0.6, tint[1] * 0.6, tint[2] * 0.6, 1.4);
	}

	static inline function tone( v : Float ) return Std.int(Math.min(255, Math.pow(1 - Math.exp(-v * 1.6), 0.85) * 255));

	static function toneRow( j : Int, o : haxe.ds.Vector<Float>, px : hxd.Pixels ) {
		for( i in 0...N ) {
			var p = (i + j * N) * 3;
			px.setPixel(i, j, 0xFF000000 | (tone(o[p]) << 16) | (tone(o[p + 1]) << 8) | tone(o[p + 2]));
		}
	}
}

/** una nebulosa del cielo: direccion, tamano angular, sus dos colores y su semilla de ruido */
private typedef Neb = { d : Array<Float>, size : Float, c : Array<Array<Float>>, seed : Float };
