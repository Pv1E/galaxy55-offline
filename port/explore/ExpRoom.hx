import flash.display.BitmapData;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.geom.ColorTransform;
import mt.deepnight.Color;
import ExpData;

/** Funciones de Color.hx de deepnight que solo existen con flash9 (copiadas tal cual). */
class ExpColor {
	public static inline function addAlphaChannel( rgb : Int, a : Int ) : Int return (a << 24) | (rgb & 0xFFFFFF);

	public static function getContrastFilter( ratio : Float ) {
		var m = 1 + ratio * 1.5;
		var o = -64 * ratio;
		return new flash.filters.ColorMatrixFilter([m, 0, 0, 0, o, 0, m, 0, 0, o, 0, 0, m, 0, o, 0, 0, 0, 1, 0]);
	}

	/** -1 (desaturar) .. 1 (saturar) */
	public static function getSaturationFilter( ratio : Float ) {
		if( ratio > 0 )
			return new flash.filters.ColorMatrixFilter([1 + ratio, -ratio, 0, 0, 0, -ratio, 1 + ratio, 0, 0, 0, 0, -ratio, 1 + ratio, 0, 0, 0, 0, 0, 1, 0]);
		var t = -ratio;
		var l = function( a : Float, b : Float ) return a + (b - a) * t;
		return new flash.filters.ColorMatrixFilter([
			l(1, .3), l(0, .59), l(0, .11), 0, 0,
			l(0, .3), l(1, .59), l(0, .11), 0, 0,
			l(0, .3), l(0, .59), l(1, .11), 0, 0,
			0, 0, 0, 1, 0]);
	}

	public static function makeNicePalette( col : Int, dark = 0x0, ?light : Int ) : Array<Int> {
		var c = Color.intToRgb(col);
		if( light == null ) light = Color.rgbToInt(Color.offsetColor(c, 100));
		var d = Color.intToRgb(dark);
		var l = Color.intToRgb(light);
		var pal = [];
		var lightLimit = 200;
		var lightRange = 256 - lightLimit;
		for( i in 0...256 )
			pal[i] = i < lightLimit ? Color.rgbToInt(Color.interpolate(d, c, i / lightLimit)) : Color.rgbToInt(Color.interpolate(c, l, (i - lightLimit) / lightRange));
		return pal;
	}

	/** Color.paintBitmap: los pixeles rojos, verdes o azules puros se repintan con la paleta de su canal */
	public static function paintBitmap( bd : flash.display.BitmapData, red : Array<Int>, green : Array<Int>, blue : Array<Int> ) {
		for( i in 0...bd.width * bd.height ) {
			var c = bd.px[i];
			var a = (c >>> 24) & 0xFF;
			if( a == 0 ) continue;
			var r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF;
			if( r == g && g == b ) continue;
			var res = if( g == 0 && b == 0 ) red[r] else if( r == 0 && b == 0 ) green[g] else if( r == 0 && g == 0 ) blue[b] else 0xff00ff;
			bd.px[i] = (a << 24) | (res & 0xFFFFFF);
		}
	}

	public static inline function getColorizeMatrixFilter( col : Int, ?ratioNewColor = 1.0, ?ratioOldColor = 1.0 ) {
		var rgb = Color.intToRgb(col);
		var r = ratioNewColor * rgb.r / 255;
		var g = ratioNewColor * rgb.g / 255;
		var b = ratioNewColor * rgb.b / 255;
		var matrix = [
			ratioOldColor + r, r, r, 0, 0,
			g, ratioOldColor + g, g, 0, 0,
			b, b, ratioOldColor + b, 0, 0,
			0, 0, 0, 1.0, 0,
		];
		return new flash.filters.ColorMatrixFilter(matrix);
	}
}

/** Un planeta del sistema solar ya dibujado: imagen, posicion y estado (Room.addPlanet) */
typedef ExpPlanetView = {
	var infos : ExpData.ExpPlanet;
	var x : Float;
	var y : Float;
	var bd : BitmapData;
	var scale : Float;
	var icon : Int;
	var iconX : Float;
	var iconY : Float;
	var showName : Bool;
}

/** Una capa con paralaje (ZLayer del original, sin la lista de visualizacion de Flash). */
class ExpLayer {
	public var bd : BitmapData;
	public var z : Float;
	public var repeat : Bool;
	public var scaleX : Float;
	public var scaleY : Float;
	public var xOffset = 0.;
	public var yOffset = 0.;
	/** se mezcla en aditivo (por defecto) o normal (las estrellas) */
	public var additive = true;
	/** mezcla SCREEN (los soles) */
	public var screen = false;
	/** zoom del paralaje (ZLayer.zoom): se amplia mas cuanto mas cerca esta la capa */
	public var zoom = 0.;
	/** la capa se mueve con la camara pero no se redondea a pixeles (rocas) */
	public var snap = true;
	public var alpha = 1.;
	public var hideZoom = false;
	public var texWid : Int;
	public var texHei : Int;

	public function new( room : ExpRoom, tex : BitmapData, z : Float, repeat = false, scaleX = 1., ?scaleY : Float ) {
		this.z = z;
		this.repeat = repeat;
		this.scaleX = scaleX;
		this.scaleY = scaleY == null ? scaleX : scaleY;
		texWid = tex.width;
		texHei = tex.height;
		if( repeat ) {
			// el original rellena un bitmap mayor que la pantalla con copias de la textura
			var w = Math.ceil(1 + room.viewW / texWid), h = Math.ceil(1 + room.viewH / texHei);
			bd = new BitmapData(texWid * w, texHei * h, true, 0);
			for( x in 0...w )
				for( y in 0...h )
					bd.copyPixels(tex, tex.rect, new Point(x * texWid, y * texHei));
			tex.dispose();
		} else
			bd = tex;
		room.layers.push(this);
	}
}

/**
 * Habitacion del explorador (Room.hx del original): genera los fondos de un sector. Las funciones de bitmaps (estrellas, nubes,
 * galaxias) son copia de las originales; solo cambia donde se dibuja el resultado.
 */
class ExpRoom {
	public static var STAR_COLORS = [0xE1BD7B, 0xF1B49E, 0xFFFFBB, 0xFFB0B0];
	public static var BG_COLORS = [0x368189, 0x326C89, 0x3D4285, 0xC16233, 0x77559F, 0xAB6FAC, 0x8B3F3F, 0x916339];
	public static var GALAXY_COLORS = [0xAB7154, 0xAA0000, 0xCC6133, 0xAD942C, 0x8A56A9, 0xBE4183, 0x314E79, 0x6480CA, 0x2D99AC];
	public static var GRID_WID = 32;

	public var seed : Int;
	public var rseed : mt.Rand;
	public var pt0 : Point;
	public var quality = 1.;
	public var viewW : Int;
	public var viewH : Int;
	public var width : Int;
	public var height : Int;
	public var center : Point;
	public var starColor : Int;
	public var bgColor : Int;
	public var galaxyColors : Array<Int>;
	public var layers : Array<ExpLayer> = [];
	public var randValues : Array<Float>;
	/** hoja de graficos del explorador (tiles.png) */
	public static var tiles : BitmapData;
	public var sunColor = 0xFF7900;
	public var entrance : Point;
	public var exitDist = -1;
	public var orbitalObjects : Array<Bool> = [];
	public var planetViews : Array<ExpPlanetView> = [];
	public var sunLayer : ExpLayer;
	public static var SUN_COLORS = [0xFF7900, 0xD6A229, 0xFF0000, 0x00A6FF, 0xE38FEF, 0x99D807];
	public static var REACTOR_COLOR = 0xA482FF;

	public function new( s : Int, viewW = 900, viewH = 450 ) {
		seed = s;
		this.viewW = viewW;
		this.viewH = viewH;
		rseed = new mt.Rand(seed);
		rseed.initSeed(seed);
		pt0 = new Point(0, 0);
		setSize(2200, 2200);
		starColor = STAR_COLORS[rseed.random(STAR_COLORS.length)];
		bgColor = BG_COLORS[rseed.random(BG_COLORS.length)];
		initRandom();
		randValues = [];
		for( i in 0...150 ) randValues[i] = rseed.rand();
	}

	function setSize( w : Int, h : Int ) {
		width = height = w;
		center = new Point(width * 0.5, height * 0.5);
	}

	/** posicion en el mapa de una casilla de la rejilla (Room.gridToMap) */
	public function gridToMap( gx : Int, gy : Int ) {
		return {
			x : Std.int(gx * GRID_WID + GRID_WID * 0.5 + randValues[(gx * 2 + gy) % randValues.length] * GRID_WID * 0.40),
			y : Std.int(gy * GRID_WID + GRID_WID * 0.5 + randValues[(gx + gy * 2) % randValues.length] * GRID_WID * 0.40),
		};
	}

	function initRandom( ?seed2 = 0.0 ) {
		rseed.initSeed(seed + Std.int(seed2));
	}

	// ---------------------------------------------------------------- fondos

	function makeStarfield( bd : BitmapData, density : Float, wid : Int, margin : Int ) {
		var n = Std.int(density * 0.0015 * bd.width * bd.height * 1 / quality);
		for( i in 0...n )
			bd.fillRect(new Rectangle(margin + rseed.random(bd.width - margin * 2), margin + rseed.random(bd.height - margin * 2), wid, wid), ExpColor.addAlphaChannel(0x808080, rseed.random(64) + 192));
	}

	public function initStars( density : Float ) {
		initRandom();
		var w = 450;
		var zmin = 0.1;
		var zmax = 0.4;
		var n = Math.ceil(6 * quality);
		var zeds = [];
		for( i in 0...n )
			zeds.push(Math.round((zmin + (i / (n - 1)) * (zmax - zmin)) * 100) / 100);
		for( z in zeds ) {
			var sf = new BitmapData(w, w, true, 0x0);
			makeStarfield(sf, density * (0.1 + 1 - z / zmax), Math.round(2 * z / zmax), 4);
			// los filtros se aplican a la pieza antes de repetirla (el original los aplicaba a la imagen ya repetida: el
			// resultado es el mismo, porque las estrellas dejan un margen de 4 px, y es unas 6 veces mas rapido)
			var bd = sf;
			bd.colorTransform(bd.rect, new ColorTransform(1, 1, 1, z / (zmax * 1.3)));
			var c = Color.interpolateInt(bgColor, starColor, z / zmax);
			bd.applyFilter(bd, bd.rect, pt0, ExpColor.getColorizeMatrixFilter(c, 1, 0));
			bd.applyFilter(bd, bd.rect, pt0, new flash.filters.GlowFilter(c, 1, 2, 2, 2, 2));
			bd.applyFilter(bd, bd.rect, pt0, new flash.filters.GlowFilter(c, z / zmax, 8, 8, 2, 2));
			var l = new ExpLayer(this, sf, z, true);
			l.additive = false;
		}
	}

	public function initClouds( col : Int, zeds : Array<Float> ) {
		initRandom(col);
		var w = Std.int(200 + 250 * 1 / 1);
		var noise = new BitmapData(w, w, true, 0x0);
		noise.noise(1, 0x60, 0xb0, 7, true);
		noise.colorTransform(noise.rect, new ColorTransform(1, 1, 1, 0.15 + rseed.rand() * 0.15));
		for( z in zeds ) {
			var perlin = new BitmapData(w, w, true, 0x0);
			var pw = Std.int(w * 0.2 + w * 0.3 * z);
			perlin.perlinNoise(pw, pw, 2, rseed.random(99999), true, true, 1, true);
			perlin.draw(noise, null, new ColorTransform(1, 1, 1, 0.3));
			var cut = 0.5;
			var thr = Color.rgbaToInt({ r : Std.int(255 * cut), g : 0, b : 0, a : 255 });
			perlin.threshold(perlin, perlin.rect, pt0, "<=", thr, 0x0, 0xffff0000, true);
			perlin.colorTransform(perlin.rect, new ColorTransform(1, 1, 1, 1, -255 * cut, -255 * cut, -255 * cut));
			var f = ExpColor.getColorizeMatrixFilter(col, 0.5, 0);
			perlin.applyFilter(perlin, perlin.rect, new Point(0, 0), f);
			new ExpLayer(this, perlin, z, true);
		}
		noise.dispose();
	}

	function safePerlinSeed( rseed : mt.Rand ) {
		var bug = [346, 514, 1155, 1519, 1690, 1977, 2327, 2337, 2399, 2860, 2999, 3099, 4777, 4952, 5673, 6265, 7185, 7259, 7371, 7383, 7717, 7847, 8032, 8350, 8676, 8963, 8997, 9080, 9403, 9615, 9685];
		var h = new Map<Int, Bool>();
		for( b in bug ) h.set(b, true);
		var s = rseed.random(9999);
		while( h.exists(s) ) s = rseed.random(9999);
		return s;
	}

	public function makeGalaxyCloud( size : Float ) {
		var w = Math.ceil(500 * size);
		var h = Math.ceil(500 * size);
		var disp = Std.int(size * (rseed.random(64) + 64));

		// base
		var galaxy = new BitmapData(w, h, true, 0x0);
		var s = safePerlinSeed(rseed);
		var pw = size * (rseed.random(32) + 16);
		galaxy.perlinNoise(pw, pw, 3, s, false, true, 7, true);
		var distort = new BitmapData(w, h, false, 0xffffff);
		var pw = size * (rseed.random(16) + 32);
		distort.perlinNoise(pw, pw, 1, safePerlinSeed(rseed), false, true, 7, true);
		galaxy.applyFilter(galaxy, galaxy.rect, new Point(0, 0), new flash.filters.DisplacementMapFilter(distort, pt0, flash.display.BitmapDataChannel.RED, flash.display.BitmapDataChannel.RED, rseed.random(32), rseed.random(32), flash.filters.DisplacementMapFilterMode.WRAP));
		distort.dispose();

		// mascara de base
		var mask = new BitmapData(w, h, true, 0x0);
		var sp = new flash.display.Sprite();
		var g = sp.graphics;
		var blur = Std.int(size * (rseed.random(48) + 16));
		var margin = Std.int(0.5 * (blur + disp));
		for( i in 0...Math.ceil(size * 15) ) {
			g.clear();
			g.beginFill(0xffffff, 0.2 + rseed.rand() * 0.8);
			var r = Math.ceil(size * (rseed.random(16) + 32));
			g.drawCircle(margin + r + rseed.random(mask.width - r * 2 - margin * 2), margin + r + rseed.random(mask.height - r * 2 - margin * 2), r);
			mask.draw(sp);
		}
		mask.applyFilter(mask, mask.rect, pt0, new flash.filters.BlurFilter(blur, blur, 2));

		// distorsion
		var distort = new BitmapData(w, h, false, 0xffffff);
		var pw = size * (rseed.random(16) + 32);
		distort.perlinNoise(pw, pw, 1, safePerlinSeed(rseed), false, true, 7, true);
		mask.applyFilter(mask, mask.rect, new Point(0, 0), new flash.filters.DisplacementMapFilter(distort, pt0, flash.display.BitmapDataChannel.RED, flash.display.BitmapDataChannel.RED, disp, disp, flash.filters.DisplacementMapFilterMode.WRAP));
		distort.dispose();

		// enmascarado
		galaxy.copyChannel(mask, mask.rect, pt0, flash.display.BitmapDataChannel.ALPHA, flash.display.BitmapDataChannel.ALPHA);
		mask.dispose();

		// ruido
		var noise = new BitmapData(w, h, true, 0x0);
		noise.noise(1, 0x60, 0xb0, 7, true);
		noise.colorTransform(noise.rect, new ColorTransform(1, 1, 1, 0.15 + rseed.rand() * 0.15));
		galaxy.copyPixels(noise, galaxy.rect, pt0, galaxy, pt0, true);
		noise.dispose();

		var gcol = galaxyColors.splice(rseed.random(galaxyColors.length), 1)[0];
		galaxy.applyFilter(galaxy, galaxy.rect, pt0, ExpColor.getColorizeMatrixFilter(gcol, 0.6, 0.4));
		return galaxy;
	}

	/** fondo del sector: estrellas, nubes y tres capas de galaxia (Room.generateSector, parte de fondos) */
	public function generateSectorBackground( widthCells = 50, heightCells = 50 ) {
		setSize(widthCells * GRID_WID, heightCells * GRID_WID);
		initStars(1);
		initClouds(bgColor, [0.7, 0.4]);
		initRandom();
		galaxyColors = GALAXY_COLORS.copy();
		var size = quality * 0.8 + 0.2;
		var scale = rseed.rand() * 1 + 1.25;
		scale += 1 / size - 1;
		for( z in [1, 0.75, 0.65] ) {
			var g = makeGalaxyCloud(size + rseed.rand() * 0.3);
			g.colorTransform(g.rect, new ColorTransform(1, 1, 1, 0.6 + (1 - quality) * 0.3));
			var l = new ExpLayer(this, g, z, false, scale);
			l.xOffset = center.x;
			l.yOffset = center.y;
		}
	}

	// ---------------------------------------------------------------- sistema solar (Room.generateSolarSystem y compania)

	inline function getOrbitDist( orbitId : Int ) return Std.int(160 + orbitId * 80 + randValues[orbitId] * 20);

	inline function getOrbitAng( orbitId : Int ) return randValues[0] * Math.PI * 2 + orbitId * Math.PI * 0.8 + randValues[orbitId] * Math.PI * 0.4;

	public function getOrbitCoord( orbitId : Int ) {
		var a = getOrbitAng(orbitId), d = getOrbitDist(orbitId);
		return { x : center.x + Math.cos(a) * d, y : center.y + Math.sin(a) * d };
	}

	/** estrellas y nubes del fondo del sistema solar (Room.generateSolarStars) */
	/** Room.generateCommon: fondo comun del sector y de los sistemas; un remolino (60 %) */
	public function generateCommon() {
		exitDist = -1;
		initRandom();
		if( rseed.random(100) < 60 ) {
			var l = makeMaelstrom(rseed.rand() * 0.3 + 0.9, starColor, 6, 0.5, 0.2);
			l.xOffset = rseed.random(width);
			l.yOffset = rseed.random(height);
		}
	}

	/** Room.makeMaelstromBitmap: un brazo en espiral pintado con el pincel "brush" (tiles.png 0,368 208x64) */
	function makeMaelstromBitmap( size : Float, color : Int, rotate : Float, turns : Float, thickness : Float, dir : Int ) {
		var bd = new BitmapData(Std.int(size * 500), Std.int(size * 500), true, 0x0);
		var alphaPerlin = bd.clone();
		alphaPerlin.perlinNoise(128, 128, 1, safePerlinSeed(rseed), false, false, 7, true);
		var brush = frameBmp(0, 368, 208, 64);
		if( size < 1 ) thickness *= size;
		var cx = bd.width * 0.5;
		var cy = bd.height * 0.5;
		var steps = 200;
		var baseAng = rotate * Math.PI * 2;
		var radiusX = bd.width * (rseed.rand() * 0.10 + 0.40);
		var radiusY = bd.height * (rseed.rand() * 0.10 + 0.40);
		for( i in 0...steps ) {
			var step = i / steps;
			var ang = baseAng + dir * step * (turns * Math.PI * 2);
			var x = cx + Math.cos(ang) * (step * radiusX);
			var y = cy + Math.sin(ang) * (step * radiusY);
			var s = thickness * (1 + (Math.sin(step * Math.PI)) * rseed.rand() * 1);
			// el pincel esta centrado (setCenter(0.5, 0.5))
			var m = new flash.geom.Matrix();
			m.translate(-brush.width * 0.5, -brush.height * 0.5);
			if( rseed.random(100) < 50 ) m.scale(-1, 1);
			if( rseed.random(100) < 50 ) m.scale(1, -1);
			m.scale(s * 0.6, s);
			m.rotate(ang + Math.PI * (0.50 + 0.10 * thickness));
			m.translate(x, y);
			m.translate((rseed.random(2) * 2 - 1) * rseed.random(3), (rseed.random(2) * 2 - 1) * rseed.random(6));
			var ct = new ColorTransform();
			ct.color = color;
			var p : Int = alphaPerlin.getPixel(Std.int(x), Std.int(y));
			ct.alphaMultiplier = Math.max(0., p / 0xffffff) * (1 - step);
			bd.draw(brush, m, ct, flash.display.BlendMode.NORMAL);
		}
		alphaPerlin.dispose();
		brush.dispose();
		return bd;
	}

	/** Room.makeMaelstrom */
	function makeMaelstrom( size : Float, color : Int, count : Int, thickness : Float, z : Float ) {
		var size = quality * size;
		initRandom();
		var r = rseed.rand();
		var dir = rseed.sign();
		var bd = new BitmapData(Std.int(size * 500), Std.int(size * 500), true, 0x0);
		for( i in 0...count ) {
			var r = (i + 1) / count;
			var bd2 = makeMaelstromBitmap(size, color, r, 1.5 + rseed.rand() * 0.5, thickness * (0.55 + rseed.rand() * 0.65), dir);
			var ct = new ColorTransform();
			ct.alphaMultiplier = rseed.rand() * 0.5 + 0.4;
			bd.draw(bd2, null, ct, flash.display.BlendMode.ADD);
			bd2.dispose();
		}
		var scale = 1 / size;
		var l = new ExpLayer(this, bd, z, false, scale);
		l.xOffset = center.x;
		l.yOffset = center.y;
		l.additive = true;
		return l;
	}

	public function generateSolarStars() {
		exitDist = -1;
		initRandom();
		initStars(0.4);
		initClouds(bgColor, [0.7, 0.3]);
	}

	function frameBmp( x : Int, y : Int, w : Int, h : Int, padding = 0 ) : BitmapData {
		var bd = new BitmapData(w + padding * 2, h + padding * 2, true, 0);
		bd.copyPixels(tiles, new Rectangle(x, y, w, h), new Point(padding, padding), null, null, true);
		return bd;
	}

	function makeSunBitmap( col : Int, size : Float ) {
		var wid = Math.ceil(size * 80);
		var filterRadius = Math.ceil(size * 96);
		var totalWid = wid + filterRadius * 2;
		var core = new flash.display.Sprite();
		core.graphics.beginFill(0x0, 1);
		core.graphics.drawCircle(filterRadius + wid * 0.5, filterRadius + wid * 0.5, wid * 0.5);

		var sun = new BitmapData(totalWid, totalWid, true, 0x0);
		sun.draw(core);

		var disp = new BitmapData(totalWid, totalWid, true, 0x0);
		disp.perlinNoise(6, 6, 2, safePerlinSeed(rseed), false, true, 7, true);

		var mask = new BitmapData(totalWid, totalWid, true, 0x0);
		mask.draw(core);
		mask.applyFilter(mask, mask.rect, pt0, new flash.filters.BlurFilter(8, 8, 2));
		mask.applyFilter(mask, mask.rect, pt0, new flash.filters.DisplacementMapFilter(disp, pt0, 1, 0, size * 10, size * 10));

		var tex = new BitmapData(totalWid, totalWid, true, 0x0);
		tex.perlinNoise(size * 8, size * 8, 1, safePerlinSeed(rseed), false, false, 7, true);
		tex.copyChannel(mask, mask.rect, pt0, flash.display.BitmapDataChannel.ALPHA, flash.display.BitmapDataChannel.ALPHA);

		sun.fillRect(sun.rect, 0xffffffff);
		sun.copyChannel(mask, mask.rect, pt0, 8, 8);
		sun.applyFilter(sun, sun.rect, pt0, new flash.filters.GlowFilter(Color.lighten(col, 0.4), 1, size * 32, size * 32, 1, 1, true));
		sun.draw(tex, null, new ColorTransform(1, 1, 1, 0.05 + rseed.rand() * 0.15), flash.display.BlendMode.NORMAL);
		sun.applyFilter(sun, sun.rect, pt0, new flash.filters.GlowFilter(Color.lighten(col, 0.4), 0.7, size * 16, size * 16, 1, 2));
		sun.applyFilter(sun, sun.rect, pt0, new flash.filters.GlowFilter(Color.lighten(col, 0.4), 1, size * 96, size * 96, 2, 2));
		sun.applyFilter(sun, sun.rect, pt0, ExpColor.getContrastFilter(0.2));
		disp.dispose();
		mask.dispose();
		tex.dispose();
		return sun;
	}

	function makeSun( col : Int, size : Float, z : Float ) {
		initRandom(col + size);
		var bd = makeSunBitmap(col, size);
		var l = new ExpLayer(this, bd, z, false);
		l.xOffset = center.x;
		l.yOffset = center.y;
		l.additive = false;
		l.screen = true;
		return l;
	}

	function addRocks( n : Int, size : Float, ?color : Int, posFunc : Void -> { x : Float, y : Float, z : Float } ) {
		if( color == null ) color = Color.desaturateInt(Color.getRainbowColor(Math.random()), 0.7);
		for( i in 0...Std.int(n * quality) ) {
			var pos = posFunc();
			rseed.random(1); // getRandomFrame("asteroid"): una sola imagen
			var rot = rseed.random(360);
			// la roca es la imagen "asteroid" (tiles.png, 32x32) girada y coloreada
			var src = frameBmp(0, 64, 32, 32, 8);
			var rb = new BitmapData(src.width, src.height, true, 0);
			var m = new flash.geom.Matrix();
			m.translate(-src.width * 0.5, -src.height * 0.5);
			m.rotate(rot * Math.PI / 180);
			m.translate(src.width * 0.5, src.height * 0.5);
			rb.draw(src, m);
			rb.applyFilter(rb, rb.rect, pt0, ExpColor.getColorizeMatrixFilter(color, 0.5, 0.8));
			rb.applyFilter(rb, rb.rect, pt0, ExpColor.getColorizeMatrixFilter(bgColor, 1 - pos.z, pos.z));
			var l = new ExpLayer(this, rb, pos.z, false, 0.05 * size + pos.z * size * 0.95);
			l.xOffset = pos.x;
			l.yOffset = pos.y;
			l.snap = false;
			l.additive = false;
		}
	}

	function addRocksAround( color : Int, x : Float, y : Float, minDist : Int, maxDist : Int ) {
		addRocks(2 + rseed.random(20), 0.20, Color.desaturateInt(color, 0.7), function() {
			var a = rseed.rand() * Math.PI * 2;
			var d = minDist + rseed.random(maxDist - minDist);
			return { x : x + Math.cos(a) * d, y : y + Math.sin(a) * d, z : rseed.rand() * 0.1 + 0.9 };
		});
	}

	function makeRockCloud( n : Int ) {
		// el original elige el patron 3 (nube excentrada); los demas estan desactivados
		// randomPoint(100): dos tiradas distintas para x e y, como en el original
		var a0 = rseed.rand() * Math.PI * 2;
		var pt = { x : center.x + Math.cos(a0) * (100 + rseed.rand() * (exitDist - 100)), y : center.y + Math.sin(a0) * (100 + rseed.rand() * (exitDist - 100)) };
		var z = rseed.rand() * 0.6 + 0.4;
		addRocks(n, rseed.rand() * 0.20 + 0.30, function() {
			var a = rseed.rand() * Math.PI * 2;
			var d = 50 + rseed.random(150);
			return { x : pt.x + Math.cos(a) * d, y : pt.y + Math.sin(a) * d, z : z - rseed.rand() * 0.29 };
		});
	}

	function addPlanet( infos : ExpPlanet ) {
		var orbitId = infos.distance;
		initRandom(orbitId);
		var c0r = Color.getRainbowColor(rseed.rand());
		var pv = planetView(infos, rseed.random(3));
		if( rseed.random(100) < 15 ) addRocksAround(c0r, pv.x, pv.y, 20, 60);
		orbitalObjects[orbitId] = true;
		planetViews.push(pv);
	}

	/** la imagen del planeta otra vez, con su estado de ahora (al abandonarlo con el sistema abierto: Licenses, anadido del port) */
	public function repaintPlanet( infos : ExpPlanet ) : ExpPlanetView {
		initRandom(infos.distance);
		rseed.rand();
		return planetView(infos, rseed.random(3));
	}

	/** la imagen del planeta (frame = una de las 3 de tiles.png) y su icono segun el estado */
	function planetView( infos : ExpPlanet, frame : Int ) : ExpPlanetView {
		var size = switch( infos.size ) {
			case 1: 0.07;
			case 2: 0.25;
			case 3: 0.50;
			case 4: 1.00;
			default: 0.5;
		}
		var orbitId = infos.distance;
		var ang = getOrbitAng(orbitId), d = getOrbitDist(orbitId);
		var bd = frameBmp(frame * 64, 5 * 32, 64, 64, 16);
		var scale = size + 0.5;
		var biome = Common.Data.getBiome(Type.createEnum(Common.BiomeKind, infos.biome));
		// la Ciudad muerta no salia en el mapa del original y no tiene exploreColors: como planeta de salida (Nueva partida) se
		// pinta con los colores de su niebla en vez de negro
		var cols = biome.exploreColors.length > 0 ? biome.exploreColors : biome.fog.slice(1);
		var c0 = cols.length >= 1 ? cols[0] : 0x0;
		var c1 = cols.length >= 2 ? cols[1] : c0;
		var c2 = cols.length >= 3 ? cols[2] : c1;
		ExpColor.paintBitmap(bd, ExpColor.makeNicePalette(c0), ExpColor.makeNicePalette(c1), ExpColor.makeNicePalette(c2));
		bd.applyFilter(bd, bd.rect, pt0, new flash.filters.DropShadowFilter(5, -45, 0x0, 0.4, 4, 4, 1, 1, true));
		var pv : ExpPlanetView = {
			infos : infos,
			x : center.x + Math.cos(ang) * d,
			y : center.y + Math.sin(ang) * d,
			bd : bd,
			scale : scale,
			icon : 2,
			iconX : Std.int(bd.width * scale * 0.2),
			iconY : Std.int(-bd.height * scale * 0.2),
			showName : false,
		};
		var halo = Color.brightnessInt(bgColor, 0.5);
		switch( infos.status ) {
		case PAbandonned, PForbidden:
			pv.icon = 1;
			pv.iconX = pv.iconY = 0;
			bd.applyFilter(bd, bd.rect, pt0, ExpColor.getSaturationFilter(-0.9));
			bd.applyFilter(bd, bd.rect, pt0, ExpColor.getColorizeMatrixFilter(0x0, 0.5, 0.5));
			bd.applyFilter(bd, bd.rect, pt0, new flash.filters.GlowFilter(Color.brightnessInt(bgColor, -0.7), 0.7, 16, 16, 1, 2));
		case PActive, PInvited:
			pv.icon = 3;
			pv.showName = true;
			bd.applyFilter(bd, bd.rect, pt0, new flash.filters.GlowFilter(halo, 0.9, 8, 8, 1));
			bd.applyFilter(bd, bd.rect, pt0, new flash.filters.GlowFilter(halo, 0.7, 32, 32, 1));
		case PUnexplored:
			pv.icon = 2;
			bd.applyFilter(bd, bd.rect, pt0, new flash.filters.GlowFilter(halo, 0.9, 8, 8, 1));
			bd.applyFilter(bd, bd.rect, pt0, new flash.filters.GlowFilter(halo, 0.7, 32, 32, 1));
		}
		return pv;
	}

	public function generateSolarSystem( infos : ExpSystem ) {
		exitDist = 500;
		var a = rseed.rand() * Math.PI * 2;
		entrance = new Point(center.x + 200 * Math.cos(a), center.y + 200 * Math.sin(a));
		bgColor = Color.getRainbowColor(rseed.rand(), 0.25 + rseed.rand() * 0.35, 0.15 + rseed.rand() * 0.4);

		// gran sol
		sunColor = SUN_COLORS[rseed.random(SUN_COLORS.length)];
		sunLayer = makeSun(sunColor, 0.6 + rseed.rand() * 0.9, 0.85);

		// soles secundarios
		var extraSuns = new mt.deepnight.RandList<Int>();
		extraSuns.add(0, 150);
		extraSuns.add(1, 45);
		extraSuns.add(2, 10);
		extraSuns.add(3, 1);
		extraSuns.add(4, 1);
		var nsuns = extraSuns.draw(rseed.random);
		for( i in 0...nsuns ) {
			var z = rseed.rand() * 0.4 + 0.4;
			var s = makeSun(SUN_COLORS[rseed.random(SUN_COLORS.length)], z * (rseed.rand() * 0.2 + 0.4), z);
			var a = rseed.rand() * Math.PI * 2;
			var d = rseed.rand() * 350 + 100;
			s.xOffset = center.x + Math.cos(a) * d;
			s.yOffset = center.y + Math.sin(a) * d;
		}

		for( p in infos.planets ) addPlanet(p);

		// escombros espaciales
		initRandom();
		if( rseed.random(100) < 50 ) makeRockCloud(rseed.random(60) + 20);

		// galaxia
		initRandom();
		if( rseed.random(100) < 70 ) {
			var size = quality * 0.8 + 0.2;
			var scale = rseed.rand() * 1 + 0.50;
			scale += 1 / size - 1;
			var bz = rseed.rand() * 0.4 + 0.2;
			var pt = { x : center.x + rseed.rand() * 100 * (rseed.random(2) * 2 - 1), y : center.y + rseed.rand() * 100 * (rseed.random(2) * 2 - 1) };
			var zeds = nsuns < 2 ? [bz + 0.15, bz] : [bz];
			galaxyColors = [];
			var base = Color.saturationInt(bgColor, 0.3);
			for( i in 0...zeds.length ) galaxyColors.push(Color.hueInt(base, rseed.rand() * 0.3 * (rseed.random(2) * 2 - 1)));
			for( z in zeds ) {
				var g = makeGalaxyCloud(size);
				g.colorTransform(g.rect, new ColorTransform(1, 1, 1, 0.5));
				var l = new ExpLayer(this, g, z, false, scale);
				l.xOffset = pt.x;
				l.yOffset = pt.y;
			}
		}
		finalizeSolar();
	}

	/** circulos de orbita y anillo de salida (Room.finalize) */
	function finalizeSolar() {
		var last = -1;
		for( i in 0...orbitalObjects.length ) if( orbitalObjects[i] ) last = i;
		if( last >= 0 ) exitDist = getOrbitDist(last) + 100;
		if( exitDist > 0 ) {
			var wid = 600;
			var fullWid = wid + 32 * 2;
			var disc = new flash.display.Sprite();
			disc.graphics.lineStyle(1, REACTOR_COLOR, 0.5);
			disc.graphics.drawCircle(0, 0, wid * 0.5);
			var bd = new BitmapData(fullWid, fullWid, true, 0x0);
			var m = new flash.geom.Matrix();
			m.translate(bd.width * 0.5, bd.height * 0.5);
			bd.draw(disc, m);
			var stripes = new flash.display.Sprite();
			var g = stripes.graphics;
			g.lineStyle(10, 0xffffff, 1);
			for( i in 0...100 ) {
				var a = Math.PI * 2 * (i / 100);
				g.moveTo(fullWid * 0.5, fullWid * 0.5);
				g.lineTo(fullWid * 0.5 + Math.cos(a) * fullWid * 0.5, fullWid * 0.5 + Math.sin(a) * fullWid * 0.5);
			}
			bd.draw(stripes, null, null, flash.display.BlendMode.ERASE);
			bd.applyFilter(bd, bd.rect, pt0, new flash.filters.GlowFilter(REACTOR_COLOR, 1, 8, 8, 3, 2));
			bd.applyFilter(bd, bd.rect, pt0, new flash.filters.BlurFilter(2, 2, 2));
			var l = new ExpLayer(this, bd, 1, false, (exitDist * 2) / wid);
			l.xOffset = center.x;
			l.yOffset = center.y;
		}
		if( last >= 0 ) {
			var maxR = getOrbitDist(last);
			var w = (maxR + 4) * 2;
			var oc = new flash.display.Sprite();
			oc.graphics.lineStyle(1, bgColor, 1);
			for( i in 0...orbitalObjects.length )
				if( orbitalObjects[i] ) oc.graphics.drawCircle(0, 0, getOrbitDist(i));
			var bd = new BitmapData(w, w, true, 0x0);
			var m = new flash.geom.Matrix();
			m.translate(w * 0.5, w * 0.5);
			bd.draw(oc, m);
			var l = new ExpLayer(this, bd, 1, false);
			l.xOffset = center.x;
			l.yOffset = center.y;
		}
	}

	// ---------------------------------------------------------------- composicion (ZLayer.update + snapshot) para pruebas

	/** dibuja las capas como se verian con la camara en (vx, vy) */
	public function compose( out : BitmapData, vx : Float, vy : Float ) {
		var sorted = layers.copy();
		sorted.sort(function(a, b) return Reflect.compare(a.z, b.z));
		for( l in sorted ) {
			var z = l.z;
			var x = viewW * 0.5 * (1 - z) - l.texWid * 0.5 + (viewW * 0.5 + l.xOffset - vx) * z;
			var y = viewH * 0.5 * (1 - z) - l.texHei * 0.5 + (viewH * 0.5 + l.yOffset - vy) * z;
			var m = new flash.geom.Matrix();
			if( l.repeat ) {
				while( x > 0 ) x -= l.texWid;
				while( x + l.texWid < 0 ) x += l.texWid;
				while( y > 0 ) y -= l.texHei;
				while( y + l.texHei < 0 ) y += l.texHei;
				m.translate(Math.round(x), Math.round(y));
			} else {
				// escala alrededor del centro del bitmap, como en ZLayer
				m.translate(-l.bd.width * 0.5, -l.bd.height * 0.5);
				m.scale(l.scaleX, l.scaleY);
				m.translate(l.bd.width * 0.5, l.bd.height * 0.5);
				m.translate(Math.round(x), Math.round(y));
			}
			out.draw(l.bd, m, null, l.additive ? flash.display.BlendMode.ADD : flash.display.BlendMode.NORMAL);
		}
	}
}
