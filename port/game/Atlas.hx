import Common;

/**
 * Atlas de texturas con los mismos parches que Render.init() del original:
 * - BFColor: los bloques sin textura reciben una casilla del final del atlas (4095, 4094, ...) rellena con su color.
 * - BFAlpha: se multiplica la opacidad de las casillas del bloque (una vez por casilla distinta).
 * Los bloques liquidos con BFAlpha usan la misma cascada de opacidad que el original.
 */
class Atlas {

	static inline var LIQUID_ALPHA = 0.55;
	static var patched = false;

	/** pixeles del ultimo atlas construido: para apuntar a las plantas por lo que se ve (GameView.modelHit) */
	public static var pixels(default, null) : hxd.Pixels;

	/**
	 * Copia con mipmaps para los trozos del mundo, como el original (Render.initTextures: tex.uploadMipMap(Data.TEXTURE, true);
	 * DefShader, TransShader, SpriteShader y WaterShader1 muestrean con nearest, mm_linear): sin ellos el terreno lejano parpadea
	 * al moverse. El hielo y el cristal (AlphaShader1), la mano y los objetos sueltos (DummyShader), las particulas (PartShader)
	 * y los iconos (IconShader) no usan mipmaps en el original: siguen con la textura que devuelve build().
	 */
	public static var mipped(default, null) : h3d.mat.Texture;
	/** segundos que tardaron los mipmaps (orden `print mips` de Dev) */
	public static var mipTime(default, null) = 0.;

	/**
	 * Niveles de 2048 a 64 px: 1 texel por casilla en el ultimo. Cambio del port: el original seguia hasta 1x1 y, por debajo de
	 * 64x64, cada texel mezclaba casillas vecinas (colores de otros bloques en el terreno lejano).
	 */
	static inline var MIP_LEVELS = 6;

	public static function build( png : haxe.io.Bytes ) : h3d.mat.Texture {
		var pix = hxd.res.Any.fromBytes("texture.png", png).toImage().getPixels();
		if( !patched ) {
			patched = true;
			patch(pix);
		} else
			patch(pix, true);
		pix.convert(RGBA); // DirectX no acepta BGRA
		pixels = pix;
		var t = h3d.mat.Texture.fromPixels(pix);
		t.filter = Nearest;
		t.mipMap = None;
		var t0 = haxe.Timer.stamp();
		mipped = buildMips(pix);
		mipTime = haxe.Timer.stamp() - t0;
		return t;
	}

	static function buildMips( pix : hxd.Pixels ) : h3d.mat.Texture {
		// por casilla: 1 = algun texel visible, 2 = algun texel no opaco; solo las mixtas (3) necesitan fillClear y keepCoverage
		var kinds = new haxe.ds.Vector<Int>((pix.width >> 5) * (pix.height >> 5));
		var levels = [pix.clone()];
		for( l in 1...MIP_LEVELS )
			levels.push(halve(levels[l - 1], l == 1 ? kinds : null));
		for( i in 0...kinds.length )
			if( kinds[i] == 3 ) {
				fillClear(levels, i & 63, i >> 6);
				keepCoverage(levels, i & 63, i >> 6);
			}
		var t = new h3d.mat.Texture(pix.width, pix.height, [MipMapped, ManualMipMapGen, NoAlloc], pix.format);
		@:privateAccess t.customMipLevels = MIP_LEVELS;
		t.alloc();
		for( l in 0...MIP_LEVELS )
			t.uploadPixels(levels[l], l);
		// nearest dentro de cada nivel y lineal entre niveles (nearest, mm_linear del original)
		t.filter = Nearest;
		t.mipMap = Linear;
		return t;
	}

	/**
	 * Nivel siguiente: media de cada 2x2 pesada por el alfa (el dibujo suavizado de Flash trabaja con alfa premultiplicado), asi
	 * los huecos no oscurecen ni aclaran los bordes. `kinds` (solo del nivel 0 al 1) recibe que hay en cada casilla.
	 */
	static function halve( src : hxd.Pixels, kinds : haxe.ds.Vector<Int> ) : hxd.Pixels {
		var w = src.width >> 1, h = src.height >> 1;
		var dst = hxd.Pixels.alloc(w, h, src.format);
		// hl.Bytes: sin comprobar los limites en cada acceso (haxe.io.Bytes hacia que tardase varias veces mas)
		var sb = hl.Bytes.fromBytes(src.bytes), db = hl.Bytes.fromBytes(dst.bytes), row = src.width << 2, dp = dst.offset;
		for( y in 0...h ) {
			var sp = src.offset + y * 2 * row;
			for( x in 0...w ) {
				var c0 = sb.getI32(sp), c1 = sb.getI32(sp + 4), c2 = sb.getI32(sp + row), c3 = sb.getI32(sp + row + 4);
				// canales rojo y azul, verde y alfa: dos sumas de 4 bytes por entero, sin desbordar
				var rb = (c0 & 0xFF00FF) + (c1 & 0xFF00FF) + (c2 & 0xFF00FF) + (c3 & 0xFF00FF);
				var ga = ((c0 >>> 8) & 0xFF00FF) + ((c1 >>> 8) & 0xFF00FF) + ((c2 >>> 8) & 0xFF00FF) + ((c3 >>> 8) & 0xFF00FF);
				var sa = ga >>> 16;
				if( kinds != null ) kinds[(y >> 4) * (w >> 4) + (x >> 4)] |= sa == 0 ? 2 : (sa == 1020 ? 1 : 3);
				if( sa == 1020 || sa == 0 )
					db.setI32(dp, (((rb + 0x20002) >> 2) & 0xFF00FF) | ((((ga + 0x20002) >> 2) & 0xFF00FF) << 8));
				else {
					var a0 = c0 >>> 24, a1 = c1 >>> 24, a2 = c2 >>> 24, a3 = c3 >>> 24;
					var a = a0 + a1 + a2 + a3;
					inline function ch( s : Int ) {
						var v0 = (c0 >> s) & 0xFF, v1 = (c1 >> s) & 0xFF, v2 = (c2 >> s) & 0xFF, v3 = (c3 >> s) & 0xFF;
						return a == 0 ? (v0 + v1 + v2 + v3 + 2) >> 2 : Std.int((v0 * a0 + v1 * a1 + v2 * a2 + v3 * a3 + (a >> 1)) / a);
					}
					db.setI32(dp, (((a + 2) >> 2) << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0));
				}
				sp += 8;
				dp += 4;
			}
		}
		return dst;
	}

	static inline function pos( p : hxd.Pixels, x : Int, y : Int ) return p.offset + ((y * p.width + x) << 2);

	/**
	 * Los texeles transparentes de la casilla toman el color del nivel siguiente (la media de lo que se ve alrededor): al mezclar
	 * dos niveles no salen bordes claros ni oscuros (el png tiene colores sueltos, casi siempre blanco, en los huecos). Solo cambia
	 * lo que el corte de alfa ya oculta.
	 */
	static function fillClear( levels : Array<hxd.Pixels>, tx : Int, ty : Int ) {
		var l = levels.length - 2;
		while( l >= 0 ) {
			var p = levels[l], q = levels[l + 1], s = 32 >> l;
			var pb = hl.Bytes.fromBytes(p.bytes), qb = hl.Bytes.fromBytes(q.bytes);
			for( y in ty * s...(ty + 1) * s )
				for( x in tx * s...(tx + 1) * s ) {
					var i = pos(p, x, y);
					if( pb[i + 3] == 0 )
						pb.setI32(i, qb.getI32(pos(q, x >> 1, y >> 1)) & 0xFFFFFF);
				}
			l--;
		}
	}

	/**
	 * Cambio del port: con la media del alfa, las hierbas y demas casillas recortadas (killAlpha 0.5) se iban borrando de lejos.
	 * En cada nivel se escala el alfa de la casilla para que pase el corte la misma parte que en el nivel 0.
	 */
	static function keepCoverage( levels : Array<hxd.Pixels>, tx : Int, ty : Int ) {
		var base = levels[0], bb = hl.Bytes.fromBytes(base.bytes), full = 0;
		for( y in ty << 5...(ty + 1) << 5 )
			for( x in tx << 5...(tx + 1) << 5 )
				if( bb[pos(base, x, y) + 3] >= 128 ) full++;
		// sin nada que pase el corte, o todo: la media ya deja pasar lo mismo que el nivel 0
		if( full == 0 || full == 1024 ) return;
		var hist = new haxe.ds.Vector<Int>(256);
		for( l in 1...levels.length ) {
			var p = levels[l], pb = hl.Bytes.fromBytes(p.bytes), s = 32 >> l;
			for( i in 0...256 ) hist[i] = 0;
			for( y in ty * s...(ty + 1) * s )
				for( x in tx * s...(tx + 1) * s )
					hist[pb[pos(p, x, y) + 3]]++;
			// alfa minimo de los texeles que deben pasar el corte (256 = ninguno)
			var want = Math.round(full * s * s / 1024), cut = 256, n = 0;
			while( n < want && cut > 1 ) n += hist[--cut];
			for( y in ty * s...(ty + 1) * s )
				for( x in tx * s...(tx + 1) * s ) {
					var i = pos(p, x, y) + 3, a = pb[i];
					pb[i] = cut == 256 ? (a < 128 ? a : 127) : a >= cut ? Std.int(Math.min(255, Math.max(128, a * 128 / cut + 0.5))) : Std.int(a * 128 / cut);
				}
		}
	}

	static function fillTile( pix : hxd.Pixels, tile : Int, argb : Int ) {
		var tx = (tile & 63) << 5, ty = (tile >> 6) << 5;
		for( y in 0...32 )
			for( x in 0...32 )
				pix.setPixel(tx + x, ty + y, argb);
	}

	static function scaleTile( pix : hxd.Pixels, b : Block, alpha : Float ) {
		var done = [];
		for( t in [b.tu, b.td, b.tlr] ) {
			if( t < 0 || t > 4095 || done.indexOf(t) >= 0 ) continue;
			done.push(t);
			var tx = (t & 63) << 5, ty = (t >> 6) << 5;
			for( y in 0...32 )
				for( x in 0...32 ) {
					var c = pix.getPixel(tx + x, ty + y);
					var a = Std.int((c >>> 24) * alpha);
					pix.setPixel(tx + x, ty + y, (a << 24) | (c & 0xFFFFFF));
				}
		}
	}

	/** Si ya se asignaron las casillas de color (segunda vez), solo se repinta el atlas nuevo con las mismas casillas. */
	/**
	 * Texturas de los bloques de la nave nodriza (anadido del port): versiones en gris de casillas del original,
	 * pintadas en casillas vacias del atlas (las que indica DataGen para BMother*).
	 */
	static function motherTiles( pix : hxd.Pixels ) {
		inline function tileOf( k : BlockKind ) return Block.get(k).tlr;
		var jobs = [
			{ dst : tileOf(BMotherHull), src : tileOf(BShedWall), k : 1.25, add : 8 },
			{ dst : tileOf(BMotherPanel), src : tileOf(BShipHull), k : 0.95, add : 0 },
			{ dst : tileOf(BMotherDark), src : tileOf(BShedWall), k : 0.6, add : 18 }, // gris oscuro como la pizarra profunda de Minecraft (antes se veia negro)
		];
		// blindaje amarillo y negro (para franjas de peligro): el mismo metal del casco, teñido
		var tints = [
			{ dst : tileOf(BMotherYellow), r : 1.0, g : 0.78, b : 0.08, k : 1.15, add : 40 },
			{ dst : tileOf(BMotherBlack), r : 1.0, g : 1.0, b : 1.04, k : 0.28, add : 6 },
		];
		var src = tileOf(BShipHull);
		for( t in tints ) {
			var sx = (src & 63) << 5, sy = (src >> 6) << 5;
			var dx = (t.dst & 63) << 5, dy = (t.dst >> 6) << 5;
			for( y in 0...32 )
				for( x in 0...32 ) {
					var c = pix.getPixel(sx + x, sy + y);
					var l = (((c >> 16) & 0xFF) * 0.3 + ((c >> 8) & 0xFF) * 0.59 + (c & 0xFF) * 0.11) * t.k + t.add;
					inline function ch( v : Float ) return Std.int(Math.max(0, Math.min(255, v)));
					pix.setPixel(dx + x, dy + y, 0xFF000000 | (ch(l * t.r) << 16) | (ch(l * t.g) << 8) | ch(l * t.b));
				}
		}
		// campo de fuerza de los hangares (añadido del port): deja pasar las naves pero no el vacio. Azul translucido con
		// rayos laser horizontales; las lineas son solo horizontales para que no se vean juntas de bloque
		var ft = tileOf(BMotherField);
		var fx0 = (ft & 63) << 5, fy0 = (ft >> 6) << 5;
		for( y in 0...32 )
			for( x in 0...32 ) {
				var c = switch( y & 7 ) {
					case 0: 0xC8B4F0FF;            // rayo
					case 1, 7: 0x7050C8FF;         // halo del rayo
					default: 0x302878E0;           // campo
				};
				pix.setPixel(fx0 + x, fy0 + y, c);
			}
		for( j in jobs ) {
			var sx = (j.src & 63) << 5, sy = (j.src >> 6) << 5;
			var dx = (j.dst & 63) << 5, dy = (j.dst >> 6) << 5;
			for( y in 0...32 )
				for( x in 0...32 ) {
					var c = pix.getPixel(sx + x, sy + y);
					var r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF;
					var l = Std.int(Math.min(255, (r * 0.3 + g * 0.59 + b * 0.11) * j.k + j.add));
					// un toque azulado, como el metal de las naves
					var lb = Std.int(Math.min(255, l * 1.06));
					pix.setPixel(dx + x, dy + y, 0xFF000000 | (l << 16) | (l << 8) | lb);
				}
		}
	}

	/** luminosidad del fondo (0x2D0D4C) y de las vetas (0x8B23D6) del cristal de la vitre teintee */
	static inline var GLASS_LO = 29.5;
	static inline var GLASS_HI = 86.;
	/** opacidad de las vitres de gema respecto a la teintee (mas claras: se ve a traves) y la de sus vetas, antes de esa escala */
	static inline var GEM_GLASS_ALPHA = 0.75;
	static inline var GEM_GLASS_STREAK = 230;

	/**
	 * Vitres blindees de gema (anadido del port): la vitre teintee (marco, brillos y vetas) con el cristal del color de la gema, del
	 * fondo (lo) a las vetas (hi), y mas transparente. El marco y los brillos blancos, iguales en la vitre blindee, no cambian.
	 */
	static function gemGlassTiles( pix : hxd.Pixels ) {
		inline function tileOf( k : BlockKind ) return Block.get(k).tlr;
		var tinted = tileOf(BShipGlassBlack), clear = tileOf(BShipGlass);
		var sx = (tinted & 63) << 5, sy = (tinted >> 6) << 5, cx = (clear & 63) << 5, cy = (clear >> 6) << 5;
		var gems = [
			{ dst : tileOf(BShipGlassRed), lo : 0xB0102A, hi : 0xFF6A80 },
			{ dst : tileOf(BShipGlassBlue), lo : 0x1848C0, hi : 0x7AB0FF },
			{ dst : tileOf(BShipGlassGreen), lo : 0x109030, hi : 0x70E890 },
			// rosa y no violeta: que no se confunda con la teintee
			{ dst : tileOf(BShipGlassPink), lo : 0xE0308C, hi : 0xFF9ACB },
		];
		for( t in gems ) {
			var dx = (t.dst & 63) << 5, dy = (t.dst >> 6) << 5;
			for( y in 0...32 )
				for( x in 0...32 ) {
					var c = pix.getPixel(sx + x, sy + y);
					if( c == pix.getPixel(cx + x, cy + y) ) {
						pix.setPixel(dx + x, dy + y, c);
						continue;
					}
					var l = ((c >> 16) & 0xFF) * 0.3 + ((c >> 8) & 0xFF) * 0.59 + (c & 0xFF) * 0.11;
					var f = Math.max(0, Math.min(1, (l - GLASS_LO) / (GLASS_HI - GLASS_LO)));
					inline function ch( s : Int ) return Std.int(((t.lo >> s) & 0xFF) * (1 - f) + ((t.hi >> s) & 0xFF) * f);
					var a = (c >>> 24) + (GEM_GLASS_STREAK - (c >>> 24)) * f;
					pix.setPixel(dx + x, dy + y, (Std.int(Math.min(255, a * GEM_GLASS_ALPHA)) << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0));
				}
		}
	}

	static function patch( pix : hxd.Pixels, again = false ) {
		motherTiles(pix);
		gemGlassTiles(pix);
		// el original empieza en 4095, que coincide con el valor "sin textura" (0xFFF) del mallador y dejaba invisible el primer bloque
		var lastTex = 4094;
		for( b in Block.all )
			for( f in b.flags )
				switch( f ) {
				case BFAlpha(alpha):
					if( b.hasFlag(BFLiquid) )
						alpha = switch( b.k ) {
							case BCascadeSource: 0.70;
							case BCascadeFall: 0.58;
							case BCascadeFall2: 0.46;
							case BCascadeFall3: 0.34;
							case BCascadeFall4: 0.22;
							default: LIQUID_ALPHA;
						};
					scaleTile(pix, b, alpha);
				case BFColor(color, _):
					var use = false;
					if( b.tlr == 0xFFF || (again && b.tlr <= 4095 && b.tlr > 4000) ) use = true;
					if( b.tu == 0xFFF || (again && b.tu <= 4095 && b.tu > 4000) ) use = true;
					if( b.td == 0xFFF || (again && b.td <= 4095 && b.td > 4000) ) use = true;
					if( use ) {
						if( b.tlr == 0xFFF ) b.tlr = lastTex;
						if( b.tu == 0xFFF ) b.tu = lastTex;
						if( b.td == 0xFFF ) b.td = lastTex;
						fillTile(pix, lastTex, 0xFF000000 | color);
						lastTex--;
					}
				default:
				}
	}
}
