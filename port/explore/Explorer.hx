import Ui;
import ExpData;
import ExpRoom;
import ExpFx;

/** Entidad del mapa (Entity.hx del original): posicion, velocidad y viaje hacia un objetivo. */
class ExpEntity {
	public var x = 0.;
	public var y = 0.;
	public var dx = 0.1;
	public var dy = 0.1;
	public var rotation = 0.;
	public var scale = 1.;
	public var speed = 0.19;
	public var zoom = 0.;
	public var target : { x : Float, y : Float };
	public var onArrive : Void -> Void;
	public var onArriveDist = 0;
	public var dataId = -1;
	/** alfa del dibujo (spr.alpha del original) */
	public var alpha = 1.;

	public function new() {}

	public inline function getAngleRad() return (dx == 0 && dy == 0) ? rotation * Math.PI / 180 : Math.atan2(dy, dx);
	public inline function getScreenSpeed() return Math.sqrt(dx * dx + dy * dy);
	public inline function getTargetDist() return target == null ? 0. : Math.sqrt((target.x - x) * (target.x - x) + (target.y - y) * (target.y - y));

	/** Entity.update */
	public function update( tmod : Float ) {
		var d = target == null ? 0. : getTargetDist();
		if( target != null ) {
			var max = 3 * speed;
			var ang = Math.atan2(target.y - y, target.x - x);
			var s = d * (0.01 + 0.001 * speed);
			if( s < -max ) s = -max;
			if( s > max ) s = max;
			// el original iba a 30 fps fijos (tmod 1): sin tmod, a 60 fps empuja el doble, se pasa del destino y al volver gira la nave
			dx += Math.cos(ang) * s * tmod;
			dy += Math.sin(ang) * s * tmod;
		}
		x += dx * tmod;
		y += dy * tmod;
		dx *= Math.pow(0.83, tmod);
		dy *= Math.pow(0.83, tmod);
		if( target != null ) {
			if( d <= onArriveDist && onArrive != null ) {
				var cb = onArrive;
				onArrive = null;
				cb();
			}
			if( target != null && d <= 1 && getScreenSpeed() <= 0.1 ) {
				x = target.x;
				y = target.y;
				target = null;
				dx = 0;
				dy = 0;
				var cb = onArrive;
				onArrive = null;
				if( cb != null ) cb();
			}
		}
		if( Math.abs(dx) <= 0.001 ) dx = 0;
		if( Math.abs(dy) <= 0.001 ) dy = 0;
	}
}

/** Un objeto pulsable del mapa: sistema (en el sector) o planeta (en el sistema solar). */
private class Spot {
	public var e = new ExpEntity();
	public var obj : h2d.Object;
	public var half = 20.;
	public var system : ExpSystem;
	public var planet : ExpPlanet;
	public function new() {}
}

/** Una escena del mapa: una habitacion (fondos con paralaje) y sus capas ya como imagenes. */
private class View {
	public var room : ExpRoom;
	public var root : h2d.Object;
	public var layers : Array<{ l : ExpLayer, b : h2d.Bitmap }> = [];
	public var viewX = 0.;
	public var viewY = 0.;
	public function new() {}
}

/**
 * Mapa del explorador (Manager.hx del original): vista del sector y de cada sistema solar, con la nave, el viaje con clic y la
 * ventana de cada planeta. Se dibuja en un lienzo de 900x450 que se escala a la ventana.
 */
class Explorer extends h2d.Object {
	public static inline var VW = 900;
	public static inline var VH = 450;

	public var infos(default, null) : ExpInfos;
	/** Esc sin ventana abierta: menu de pausa del mapa (anadido del port: en el original el mapa era una pagina aparte) */
	public dynamic function onPause() {}
	/** con el menu de pausa abierto el mapa se para */
	public var paused = false;
	/** el jugador quiere aterrizar en un planeta */
	public dynamic function onLand( p : ExpPlanet, s : ExpSystem ) {}
	/** la nave ha cambiado de sitio en el mapa: [0, x, y] sector, [1, sistema], [2, planeta] (para guardarlo) */
	public dynamic function onPos( pos : Array<Int> ) {}
	/** acoplarse al robot comerciante (anadido del port): se entra en su nave, con la tienda */
	public dynamic function onDock() {}
	/** la nave ha avanzado `dist` (en el sector o dentro de un sistema): para Space */
	public dynamic function onTravel( dist : Float, inSystem : Bool ) {}
	/** antes de aterrizar o escanear: false = no se puede (Space) */
	public dynamic function canLand( p : ExpPlanet ) : Bool return true;
	/** antes de salir del sistema solar: false = la nave se para en el borde (Space; el tutorial no deja salir) */
	public dynamic function canLeave() : Bool return true;
	/** antes de escanear: false = no queda licencia libre (Space, Licenses; anadido del port) */
	public dynamic function canScan( p : ExpPlanet ) : Bool return true;
	/** la ventana del planeta tiene el boton Abandonar (Space) */
	public dynamic function canAbandon( p : ExpPlanet ) : Bool return false;
	/** boton Abandonar: el juego pide confirmacion y, si se abandona, llama a abandoned */
	public dynamic function onAbandon( p : ExpPlanet, s : ExpSystem ) {}
	/** el planeta principal de la partida (se indica en su ventana) */
	public dynamic function isMain( p : ExpPlanet ) : Bool return false;
	/** planeta al que lleva el tutorial (flecha del GPS aunque no se haya visitado); -1 = ninguno */
	public var tutoTarget = -1;
	/** boton del candado de un sistema cerrado (el original lo abria pagando la licencia): para Space */
	public dynamic function onUnlock( s : ExpSystem ) {}
	/** posicion guardada del robot comerciante (la pone el juego antes de abrir el mapa; null = en un sistema al azar) */
	public static var robotStart : { x : Float, y : Float } = null;
	/** al volver de la nave del robot: la nave aparece donde se acoplo (en el sector) */
	public static var shipStart : { x : Float, y : Float } = null;

	var content : h2d.Object;
	var bgBmp : h2d.Bitmap;
	var sector : View;
	var solar : View;
	var solarStars : View;
	var current : View;
	var inSolar = false;
	var curSystem : ExpSystem;
	var tiles : h2d.Tile;
	var ship = new ExpEntity();
	var shipObj : h2d.Graphics;
	var shipBmp : h2d.Bitmap;
	var shipTiles : Array<h2d.Tile>;
	var shipFrames : Array<flash.display.BitmapData>;
	var shipWorld : h2d.Object;
	/** Manager.gps: flechas verdes alrededor de la nave hacia los planetas activos (en el port, los visitados) o hacia los
	    sistemas que los tienen; se rehacen al cambiar de vista */
	var gps : Array<{ arrow : h2d.Graphics, target : ExpEntity }> = [];
	var gpsLayer : h2d.Object;
	var gpsView : View;
	var gpsCount = -1;
	/** robot comerciante (anadido del port): una nave que viaja despacio entre los sistemas abiertos del sector; al pulsarla
	    se para y te espera, y al llegar a su lado te puedes acoplar */
	var robot : Spot;
	var robotWait = 0.;
	var robotStopped = false;
	var cursor : h2d.Graphics;
	var cursorE = new ExpEntity();
	var cursorAlpha = 1.;
	var cursorRot = 0.;
	var worldSector : h2d.Object;
	var worldSolar : h2d.Object;
	var sectorSpots : Array<Spot> = [];
	var solarSpots : Array<Spot> = [];
	var targetSpot : Spot;
	var down : Spot;
	var downOnBg = false;
	var fade : h2d.Bitmap;
	var fadeAlpha = 1.;
	var locked = false;
	var burn : h2d.Bitmap;
	var overlay : h2d.Object;
	// ventana de planeta
	var win : h2d.Object;
	var winSpot : Spot;
	var winButtons : Array<{ o : h2d.Interactive, g : h2d.Graphics, cb : Void -> Void }> = [];
	var zoomT = 0.;
	var zoomGoal = 0.;
	// transiciones del original (Manager.gotoSolar, gotoSector, hyperjump*)
	var tw = new ExpTweens();
	var common : View;
	var fxLayer : h2d.Object;
	var zoomCache : h2d.Bitmap;
	var overdrive : h2d.Bitmap;
	var oldBg : h2d.Bitmap;
	var bar : h2d.Graphics;
	var spinner : h2d.Graphics;
	var serverLock = false;
	var lockCamera = false;
	var shipVisible = true;
	var shipAlpha = 1.;
	var sectorEntrance = { x : 0., y : 0. };
	var spawnAcc = 0.;
	/** sistemas que se estan generando en segundo plano (cambio del port: el original congelaba la pantalla al generarlos) */
	var jobs = new Map<Int, { room : ExpRoom, stars : ExpRoom, done : Bool }>();
	static inline var COMMON_LOW_ALPHA = 0.5;
	static inline var COMMON_HIGH_ALPHA = 0.85;
	static inline var ANIM_SECTOR_ZOOM = 60;
	static inline var ANIM_COMMON_ZOOM = 100;
	static inline var ANIM_SOLARSTAR_ZOOM = 10;
	static inline var REACTOR_COLOR = 0xA482FF;

	public function new( parent : h2d.Object, infos : ExpInfos, ?frames : Array<flash.display.BitmapData> ) {
		super(parent);
		this.infos = infos;
		// fondo negro de toda la ventana: el mapa se ajusta a la zona W x H y, en una ventana que no es 16:9, en las bandas de
		// los lados (o de arriba y abajo) se veia el mundo 3D detras
		Theme.fullRect(new h2d.Graphics(this), 0x000000, 1);
		content = new h2d.Object(this);
		bgBmp = new h2d.Bitmap(h2d.Tile.fromColor(0), content);
		oldBg = new h2d.Bitmap(h2d.Tile.fromColor(0), content);
		oldBg.visible = false;

		// graficos del explorador
		var png = hxd.res.Any.fromBytes("tiles.png", Res.exploreBytes("tiles.png")).toImage();
		var px = png.getPixels();
		px.convert(BGRA);
		ExpRoom.tiles = new flash.display.BitmapData(px.width, px.height, true, 0);
		for( i in 0...px.width * px.height ) ExpRoom.tiles.px[i] = px.bytes.getInt32(i * 4);
		var img = hxd.res.Any.fromBytes("tiles.png", Res.exploreBytes("tiles.png")).toTile();
		img.getTexture().filter = Nearest;
		tiles = img;

		// fondo comun (Room.generateCommon), con alfa COMMON_LOW_ALPHA
		common = makeView(new ExpRoom(infos.sector.seed, VW, VH));
		common.room.generateCommon();
		buildLayers(common);
		for( o in common.layers ) o.b.alpha = COMMON_LOW_ALPHA;

		// sector
		sector = makeView(new ExpRoom(infos.sector.seed, VW, VH));
		sector.room.generateSectorBackground(infos.sector.width, infos.sector.height);
		buildLayers(sector);
		worldSector = new h2d.Object(content);
		for( si in infos.systems ) addSystem(si);
		addRobot();

		// nave y cursor
		shipWorld = new h2d.Object(content);
		shipObj = new h2d.Graphics(shipWorld);
		shipObj.lineStyle(1, 0x495776, 0.8);
		shipObj.beginFill(0xACB6CC, 1);
		shipObj.moveTo(-8, -5);
		shipObj.lineTo(8, 0);
		shipObj.lineTo(-8, 5);
		shipObj.endFill();
		if( frames != null && frames.length > 0 ) {
			shipTiles = [];
			shipFrames = frames;
			for( bd in frames ) shipTiles.push(bmpTile(bd, true).center());
			shipBmp = new h2d.Bitmap(shipTiles[0], shipWorld);
			shipBmp.setScale(128 / frames[0].width);
			shipObj.visible = false;
		}
		cursor = new h2d.Graphics(shipWorld);
		cursor.lineStyle(3, 0xC8D9F2, 1);
		var w = 8.;
		cursor.moveTo(-w, 0);
		for( i in 1...9 ) cursor.lineTo(-Math.cos(i / 8 * Math.PI / 2) * w, -Math.sin(i / 8 * Math.PI / 2) * w);
		cursor.moveTo(w, 0);
		for( i in 1...9 ) cursor.lineTo(Math.cos(i / 8 * Math.PI / 2) * w, Math.sin(i / 8 * Math.PI / 2) * w);

		// efectos en pantalla (externalSprites del original) y la imagen del sistema que crece o se encoge (zoomCache)
		zoomCache = new h2d.Bitmap(null, content);
		zoomCache.visible = false;
		fxLayer = new h2d.Object(content);
		gpsLayer = new h2d.Object(content);

		// calor del sol (burn) y destello de la llegada (overdriveBurn)
		burn = new h2d.Bitmap(h2d.Tile.fromColor(0xFFFFFF, VW, VH), content);
		burn.blendMode = Add;
		burn.visible = false;
		overdrive = new h2d.Bitmap(h2d.Tile.fromColor(0xFFFFFF, VW, VH), content);
		overdrive.blendMode = Add;
		overdrive.color.set(0xFF / 255, 0xBE / 255, 0x28 / 255, 1);
		overdrive.visible = false;

		// bordes oscuros (initBorders)
		var bpx = hxd.Pixels.alloc(VW, VH, BGRA);
		for( y in 0...VH )
			for( x in 0...VW ) {
				var d = Math.min(Math.min(x, VW - 1 - x), Math.min(y, VH - 1 - y));
				var a = Math.max(0, 1 - d / 30);
				bpx.bytes.setInt32((x + y * VW) * 4, (Std.int(a * a * 0.9 * 255) << 24));
			}
		var btex = new h3d.mat.Texture(VW, VH);
		btex.uploadPixels(bpx);
		new h2d.Bitmap(h2d.Tile.fromTexture(btex), content);

		// lineas de barrido (Buffer.makeScanline): una linea oscura cada 3 pixeles
		var spx = hxd.Pixels.alloc(1, VH, BGRA);
		for( y in 0...VH ) spx.bytes.setInt32(y * 4, (y % 3 == 2) ? (Std.int(0.22 * 255) << 24) : 0);
		var stex = new h3d.mat.Texture(1, VH);
		stex.uploadPixels(spx);
		var scan = new h2d.Bitmap(h2d.Tile.fromTexture(stex), content);
		scan.scaleX = VW;

		overlay = new h2d.Object(content);

		fade = new h2d.Bitmap(h2d.Tile.fromColor(0x000000, VW, VH), content);
		// los textos grandes (popString) van por encima de la mascara negra, como en el original (DP_INTERF, creados despues)
		content.addChild(overlay);
		// barra de progreso (showBar) e icono de carga que gira arriba a la derecha (loadingAnim)
		bar = new h2d.Graphics(content);
		bar.visible = false;
		spinner = new h2d.Graphics(content);
		spinner.x = VW - 20;
		spinner.y = 20;
		spinner.lineStyle(5, 0x282E44, 0.7);
		spinner.drawCircle(0, 0, 10);
		spinner.lineStyle();
		for( i in 0...5 ) {
			var a = i * 0.45;
			spinner.beginFill(0xCCD8EC, 0.8 * i / 5 + 0.2);
			spinner.drawCircle(Math.cos(a) * 10, Math.sin(a) * 10, 2);
			spinner.endFill();
		}
		spinner.visible = false;
		loading(true);

		// posicion inicial de la nave
		current = sector;
		setBg(sector.room.bgColor);
		switch( infos.shipPos ) {
		case PInSector(x, y):
			var pt = sector.room.gridToMap(x, y);
			ship.x = pt.x;
			ship.y = pt.y;
		default:
			ship.x = sector.room.center.x;
			ship.y = sector.room.center.y;
		}
		if( shipStart != null ) {
			ship.x = shipStart.x;
			ship.y = shipStart.y;
			shipStart = null;
		}
		sector.viewX = ship.x;
		sector.viewY = ship.y;
		sectorEntrance.x = ship.x;
		sectorEntrance.y = ship.y;
		ship.speed = shipSpeed();
		// la nave estaba en un sistema o junto a un planeta (Manager.start)
		switch( infos.shipPos ) {
		case PPlanet(id):
			for( si in infos.systems )
				for( p in si.planets )
					if( p.id == id ) {
						buildSolar(si, 0, id);
						popString(si.name);
					}
		case PInSystem(id):
			for( si in infos.systems )
				if( si.id == id ) {
					buildSolar(si, 0, -1);
					popString(si.name);
				}
		default:
			popString(infos.sector.name);
		}
		layout();
		update(0);
		// Manager.start: la mascara negra se desvanece en 1 s y el icono de carga se va
		fadeAlpha = 1;
		tw.create(this, "fadeAlpha", 0, TEaseIn, 1000);
		loading(false);
	}

	/** nave de la partida (la editada en el hangar); null = la de serie */
	public static var shipBytes : haxe.io.Bytes;

	/** Const.shipSpeed(motores, peso): motores y bloques de la nave de la partida */
	function shipSpeed() : Float {
		var data = ShipData.load(shipBytes != null ? shipBytes : Common.Const.DEFAULT_SHIP);
		var engines = 0;
		for( c in data.cells ) if( c.id == Type.enumIndex(Common.BlockKind.BShipEngine) ) engines++;
		return Common.Const.shipSpeed(engines, data.cells.length);
	}

	// ---------------------------------------------------------------- imagenes y fondo

	function bmpTile( bd : flash.display.BitmapData, linear = false, premultiply = false ) : h2d.Tile {
		var px = hxd.Pixels.alloc(bd.width, bd.height, BGRA);
		for( i in 0...bd.width * bd.height ) {
			var c = bd.px[i];
			if( premultiply ) {
				// la mezcla SCREEN de Heaps espera el color ya multiplicado por el alfa
				var a = (c >>> 24) & 0xFF;
				c = (a << 24) | (Std.int(((c >> 16) & 0xFF) * a / 255) << 16) | (Std.int(((c >> 8) & 0xFF) * a / 255) << 8) | Std.int((c & 0xFF) * a / 255);
			}
			px.bytes.setInt32(i * 4, c);
		}
		var tex = new h3d.mat.Texture(bd.width, bd.height);
		tex.uploadPixels(px);
		tex.filter = linear ? Linear : Nearest;
		return h2d.Tile.fromTexture(tex);
	}

	function makeView( room : ExpRoom ) : View {
		var v = new View();
		v.room = room;
		v.root = new h2d.Object(content);
		return v;
	}

	function buildLayers( v : View ) {
		for( l in v.room.layers ) {
			var b = new h2d.Bitmap(bmpTile(l.bd, false, l.screen), v.root);
			b.blendMode = l.screen ? Screen : (l.additive ? Add : Alpha);
			v.layers.push({ l : l, b : b });
		}
		v.layers.sort(function(a, b) return Reflect.compare(a.l.z, b.l.z));
		for( o in v.layers ) v.root.addChild(o.b);
	}

	function disposeView( v : View ) {
		if( v == null ) return;
		for( o in v.layers ) o.b.tile.getTexture().dispose();
		v.root.remove();
	}

	function bgTile( col : Int ) : h2d.Tile {
		// Manager.setBg: se limita el brillo y el degradado va hacia un tono mas oscuro
		col = mt.deepnight.Color.capBrightnessInt(col, 0.3);
		var dark = mt.deepnight.Color.brightnessInt(col, -0.2);
		var px = hxd.Pixels.alloc(1, VH, BGRA);
		for( y in 0...VH ) px.bytes.setInt32(y * 4, 0xFF000000 | mt.deepnight.Color.interpolateInt(col, dark, y / (VH - 1)));
		var tex = new h3d.mat.Texture(1, VH);
		tex.uploadPixels(px);
		return h2d.Tile.fromTexture(tex);
	}

	var bgColor = -1;

	/** Manager.setBg: con fadeDuration el fondo anterior se desvanece por encima */
	function setBg( col : Int, fadeDuration = 0 ) {
		var old = bgColor;
		bgColor = col;
		tw.terminate(oldBg);
		var prev = bgBmp.tile;
		bgBmp.tile = bgTile(col);
		bgBmp.scaleX = VW;
		if( oldBg.tile != null && oldBg.tile.getTexture() != null ) oldBg.tile.getTexture().dispose();
		oldBg.tile = null;
		oldBg.visible = false;
		if( fadeDuration > 0 && old >= 0 ) {
			oldBg.tile = prev;
			oldBg.scaleX = VW;
			oldBg.visible = true;
			oldBg.alpha = 1;
			tw.create(oldBg, "alpha", 0, TEaseIn, fadeDuration).onEnd = function() oldBg.visible = false;
		} else if( prev != null && prev.getTexture() != null )
			prev.getTexture().dispose();
	}

	function frame( i : Int, size = 32 ) : h2d.Tile return tiles.sub(i * size, 32, size, size, -size * 0.5, -size * 0.5);

	function label( parent : h2d.Object, str : String, scale : Float, col : Int ) {
		var t = Theme.text(parent, str, scale, col, 0, 0);
		t.dropShadow = { dx : 1, dy : 1, color : 0x0D1118, alpha : 1 };
		return t;
	}

	/** etiquetas centradas cuyo texto depende del idioma: se rehacen en relabel (las del sistema abierto van aparte: se borran con el) */
	var relabels : Array<Void -> Void> = [];
	var solarRelabels : Array<Void -> Void> = [];

	function nameLabel( parent : h2d.Object, text : Void -> String, scale : Float, col : Int, solar = false ) {
		var t = label(parent, text(), scale, col);
		var set = function() {
			t.text = text();
			t.x = -Std.int(t.textWidth * t.scaleX * 0.5);
		};
		set();
		(solar ? solarRelabels : relabels).push(set);
		return t;
	}

	/** cambio de idioma con el mapa abierto: solo se cambian los textos (nombres y la ventana abierta), sin rehacer el mapa */
	public function relabel() {
		ExpOffline.relabel(infos);
		for( f in relabels ) f();
		for( f in solarRelabels ) f();
		if( win != null && winSpot != null ) showWindow(winSpot);
	}

	// ---------------------------------------------------------------- robot comerciante

	function openSystems() return [for( sp in sectorSpots ) if( sp.system != null && sp.system.status == SOpen ) sp];

	/** los objetos del sector en los saltos (sector.entities del original): los sistemas y el robot, que no entra en los sistemas */
	function sectorEntities() return robot == null ? sectorSpots : sectorSpots.concat([robot]);

	function addRobot() {
		var open = openSystems();
		if( open.length == 0 ) return;
		robot = new Spot();
		robot.half = 20;
		robot.e.speed = 0.08;
		var obj = new h2d.Object(worldSector);
		robot.obj = obj;
		// la nave del robot es la nave nodriza (la Hades): su forma vista desde arriba; si no se puede leer, una flecha
		var g = new h2d.Object(obj);
		var top = hadesTop();
		if( top != null ) {
			var b = new h2d.Bitmap(top.tile, g);
			b.smooth = true;
			b.setScale(HADES_ICON / top.len);
			b.rotation = top.angle;
			g.filter = new h2d.filter.Glow(0x000000, 1, 2, 2, 1, true);
		} else {
			var a = new h2d.Graphics(g);
			a.lineStyle(1, 0x7A3A10, 0.9);
			a.beginFill(0xFFA040, 1);
			a.moveTo(-10, -7);
			a.lineTo(11, 0);
			a.lineTo(-10, 7);
			a.lineTo(-6, 0);
			a.lineTo(-10, -7);
			a.endFill();
			a.filter = new h2d.filter.Glow(0xFFA040, 0.5, 3, 1, 1, false);
		}
		robot.e.alpha = 1;
		var name = nameLabel(obj, function() return Lang.t("exp.robot"), 1.0, 0xFFC890);
		name.y = top != null ? Std.int(HADES_ICON * 0.25) + 4 : 12;
		robotGfx = g;
		if( robotStart != null ) {
			robot.e.x = robotStart.x;
			robot.e.y = robotStart.y;
		} else {
			var sp = open[Std.random(open.length)];
			robot.e.x = sp.e.x + 36;
			robot.e.y = sp.e.y - 40;
		}
		robotWait = 10;
	}
	var robotGfx : h2d.Object;

	/** largo del icono de la nave del robot en el mapa (px) */
	static inline var HADES_ICON = 64;
	static var hadesCache : { tile : h2d.Tile, len : Float, angle : Float };

	/**
	 * La nave nodriza vista desde arriba, a un pixel por bloque: el bloque mas alto de cada columna, con el color medio de su
	 * textura y mas claro cuanto mas alto. angle gira la imagen para que la proa mire a +x (la cola es donde estan los motores).
	 */
	static function hadesTop() {
		if( hadesCache != null ) return hadesCache;
		var d = try Mothership.data() catch( e : Dynamic ) null;
		var pix = Atlas.pixels;
		if( d == null || d.cells.length == 0 ) return null;
		var x0 = 99999, y0 = 99999, x1 = -1, y1 = -1, z0 = 99999, z1 = -1;
		for( c in d.cells ) {
			if( c.x < x0 ) x0 = c.x; if( c.x > x1 ) x1 = c.x;
			if( c.y < y0 ) y0 = c.y; if( c.y > y1 ) y1 = c.y;
			if( c.z < z0 ) z0 = c.z; if( c.z > z1 ) z1 = c.z;
		}
		var w = x1 - x0 + 1, h = y1 - y0 + 1;
		var topZ = new haxe.ds.Vector<Int>(w * h), topId = new haxe.ds.Vector<Int>(w * h);
		for( i in 0...w * h ) topZ[i] = -1;
		var gx = 0., gy = 0., ex = 0., ey = 0., en = 0;
		var engine = Type.enumIndex(Common.BlockKind.BShipEngine);
		for( c in d.cells ) {
			var i = (c.x - x0) + (c.y - y0) * w;
			if( c.z > topZ[i] ) { topZ[i] = c.z; topId[i] = c.id; }
			gx += c.x; gy += c.y;
			if( c.id == engine ) { ex += c.x; ey += c.y; en++; }
		}
		// color medio de la textura de cada bloque (cara de arriba)
		var cols = new Map<Int, Int>();
		function colorOf( id : Int ) : Int {
			var c = cols.get(id);
			if( c != null ) return c;
			c = 0x8890A0;
			var b = Block.all[id];
			if( b != null && pix != null && b.tu >= 0 && b.tu < 0xFFF ) {
				var ts = Std.int(pix.width / 64), tx = (b.tu & 0xFFF & 63) * ts, ty = ((b.tu & 0xFFF) >> 6) * ts;
				var r = 0., g = 0., bl = 0., n = 0;
				for( yy in 0...ts )
					for( xx in 0...ts ) {
						var p = pix.getPixel(tx + xx, ty + yy);
						if( (p >>> 24) < 128 ) continue;
						// RGBA: el entero lleva R en el byte bajo
						r += p & 0xFF; g += (p >> 8) & 0xFF; bl += (p >> 16) & 0xFF; n++;
					}
				if( n > 0 ) c = (Std.int(r / n) << 16) | (Std.int(g / n) << 8) | Std.int(bl / n);
			}
			cols.set(id, c);
			return c;
		}
		var out = hxd.Pixels.alloc(w, h, BGRA);
		for( y in 0...h )
			for( x in 0...w ) {
				var i = x + y * w;
				if( topZ[i] < 0 ) { out.setPixel(x, y, 0); continue; }
				var c = colorOf(topId[i]);
				var k = 0.55 + 0.6 * (topZ[i] - z0) / Math.max(1, z1 - z0);
				inline function ch( v : Int ) return Std.int(Math.min(255, v * k));
				out.setPixel(x, y, 0xFF000000 | (ch((c >> 16) & 0xFF) << 16) | (ch((c >> 8) & 0xFF) << 8) | ch(c & 0xFF));
			}
		var tile = h2d.Tile.fromPixels(out).center();
		// proa: lejos de los motores; sin motores, a lo largo del eje mas largo
		gx /= d.cells.length; gy /= d.cells.length;
		var angle = w >= h ? 0. : -Math.PI / 2;
		if( en > 0 ) {
			var fx = gx - ex / en, fy = gy - ey / en;
			if( Math.abs(fx) + Math.abs(fy) > 0.5 ) angle = -Math.atan2(fy, fx);
		}
		return hadesCache = { tile : tile, len : Math.max(w, h), angle : angle };
	}

	/** donde esta el robot (para guardarlo) */
	public function robotPos() return robot == null ? null : { x : robot.e.x, y : robot.e.y };
	/** donde esta la nave en el sector (null dentro de un sistema) */
	public function shipPos() return inSolar ? null : { x : ship.x, y : ship.y };

	/** viaja de un sistema abierto a otro y se para un rato en cada uno; parado si lo estas siguiendo */
	function updateRobot( tmod : Float, dt : Float ) {
		if( robot == null ) return;
		var e = robot.e;
		if( robotStopped ) {
			e.target = null;
			e.onArrive = null;
		} else if( e.target == null ) {
			robotWait -= dt;
			if( robotWait <= 0 ) {
				var open = openSystems();
				var choices = [for( sp in open ) if( Math.abs(sp.e.x - e.x) + Math.abs(sp.e.y - e.y) > 80 ) sp];
				if( choices.length == 0 ) choices = open;
				var sp = choices[Std.random(choices.length)];
				e.target = { x : sp.e.x + 36, y : sp.e.y - 40 };
				e.onArriveDist = 0;
				e.onArrive = function() robotWait = 6 + Math.random() * 8;
			}
		}
		e.update(tmod);
		if( e.getScreenSpeed() > 0.05 ) e.rotation = e.getAngleRad() * 180 / Math.PI;
		if( robotGfx != null ) robotGfx.rotation = e.rotation * Math.PI / 180;
	}

	/** pruebas: pulsar el robot y saber donde esta */
	public function devClickRobot() if( robot != null && !inSolar ) moveShip(robot);
	public function devWindowOpen() return win != null;

	public function devRobotInfo() return robot == null ? "sin robot" : "robot en " + Std.int(robot.e.x) + "," + Std.int(robot.e.y) + " parado=" + robotStopped + " nave=" + Std.int(ship.x) + "," + Std.int(ship.y) + " ventana=" + (win != null)
		+ " dibujo=" + (worldSector.visible ? Std.int(robot.obj.x) + "," + Std.int(robot.obj.y) + " escala=" + Std.int(robot.obj.scaleX * 100) / 100 + " alfa=" + Std.int(robot.obj.alpha * 100) / 100 : "oculto");

	/** pruebas: pulsar el sistema abierto mas cercano al robot */
	public function devClickRobotSystem() {
		if( robot == null || inSolar ) return;
		var best : Spot = null, bd = 1e9;
		for( sp in openSystems() ) {
			var d = Math.abs(sp.e.x - robot.e.x) + Math.abs(sp.e.y - robot.e.y);
			if( d < bd ) {
				bd = d;
				best = sp;
			}
		}
		if( best != null ) moveShip(best);
	}

	/** boton Acoplarse de la ventana del robot */
	function dockRobot() {
		if( locked ) return;
		closeWindow();
		locked = true;
		serverLock = true;
		stopShip();
		loading(true);
		tw.delay(800, function() onDock());
	}

	// ---------------------------------------------------------------- sector

	function addSystem( si : ExpSystem ) {
		var pt = sector.room.gridToMap(si.x, si.y);
		var sp = new Spot();
		sp.system = si;
		sp.e.dataId = si.id;
		sp.e.x = pt.x;
		sp.e.y = pt.y;
		var obj = new h2d.Object(worldSector);
		sp.obj = obj;
		switch( si.status ) {
		case SLocked(_):
			new h2d.Bitmap(frame(2), obj);
			sp.half = 16 + 10;
		case SOpen:
			var unexp = 0, active = 0;
			for( p in si.planets ) {
				if( p.status == PUnexplored ) unexp++;
				if( p.status == PActive ) active++;
			}
			var icon = new h2d.Bitmap(frame(active > 0 ? 1 : 0), obj);
			icon.setScale(2);
			if( unexp > 0 ) {
				// el contador es hijo del icono en el original, por eso sale al doble de tamano
				var c = new h2d.Bitmap(tiles.sub(4 * 16, 0, 16, 16, -8, -8), icon);
				c.x = 7;
				c.y = 4;
				var t = Theme.text(c, "" + unexp, 0.8, 0xFFFFFF);
				t.dropShadow = { dx : 0, dy : 1, color : 0, alpha : 1 };
				// centrado en el circulo (9 px, medio pixel a la izquierda y abajo del centro de la imagen), como en el original
				t.x = -0.5 - t.textWidth * t.scaleX * 0.5;
				t.y = 0.5 - t.textHeight * t.scaleY * 0.5;
			}
			var name = nameLabel(obj, function() return si.name, 1.1, 0xCCD6EC);
			name.y = 16;
			sp.half = 32 + 15;
		}
		sectorSpots.push(sp);
	}

	// ---------------------------------------------------------------- sistema solar

	/** Manager.onReachSystem: centrar la camara (200 ms), esperar al "servidor" y saltar al sistema */
	function onReachSystem( sp : Spot ) {
		locked = true;
		centerView(200, function() {
			sendAction(function() gotoSolar(sp.system, true));
		});
	}

	/** Manager.gotoSolar */
	function gotoSolar( si : ExpSystem, anim : Bool ) {
		closeWindow();
		if( !anim ) {
			prepareSolar(si);
			finishSolar(si);
			centerView();
			return;
		}
		// si el sistema aun se esta generando en segundo plano, se espera (con el icono de carga girando)
		var job = jobs.get(si.id);
		if( job != null && !job.done ) {
			loading(true);
			tw.delay(50, function() gotoSolar(si, true));
			return;
		}
		loading(false);
		prepareSolar(si);
		solar.root.visible = false;
		worldSolar.visible = false;
		solarStars.root.visible = false;
		hyperjumpFx3D(function() solarZoomAnim(si));
	}

	function solarZoomAnim( si : ExpSystem ) {
		var total = 1300;
		stopShip(true);
		locked = true;
		lockCamera = true;
		shipVisible = false;
		shipAlpha = 1;
		var arrivalAng = (180 + ship.rotation) * Math.PI / 180;
		tw.create(this, "cursorAlpha", 0, TEaseIn, 300);

		// se guarda el punto de entrada en el sector
		sectorEntrance.x = ship.x;
		sectorEntrance.y = ship.y;

		// progresion general: lineas de hiperespacio entre el 10 % y el 60 % (el original crea n por fotograma a 30 por segundo)
		var zoomProgress = { t : 0.0 };
		var a = tw.create(zoomProgress, "t", 1, TLinear, total);
		a.onUpdateT = function(t) {
			if( t >= 0.10 && t <= 0.60 ) {
				var ratio = 1 - (t - 0.10) / 0.50;
				spawnAcc += (ratio * 10 + Std.random(10)) * lastTmod;
				while( spawnAcc >= 1 ) {
					spawnAcc -= 1;
					makeHyperspacePart(ratio);
				}
			}
		};
		a.onEnd = function() {
			popString(si.name);
			finishSolar(si);
			ship.rotation = 180 + arrivalAng * 180 / Math.PI;
			centerView(Std.int(total * 0.8));
			hyperjumpArrivalFx(10);
		};

		var room = solar.room;
		setBg(room.bgColor, total);
		room.entrance.x = room.center.x + Math.cos(arrivalAng) * Math.min(250, room.exitDist - 10);
		room.entrance.y = room.center.y + Math.sin(arrivalAng) * Math.min(250, room.exitDist - 10);
		solar.viewX = solarStars.viewX = room.entrance.x;
		solar.viewY = solarStars.viewY = room.entrance.y;

		// imagen del sistema para el zoom
		var t2 = haxe.Timer.stamp();
		setCache(snapshot());
		if( Dev.trace ) Sys.println("tiempos: snapshot=" + Std.int((haxe.Timer.stamp() - t2) * 1000) + "ms");

		// color del calor del sol
		var c = mt.deepnight.Color.interpolateInt(room.sunColor, 0xF46800, 0.3);
		burn.color.set(((c >> 16) & 0xFF) / 255, ((c >> 8) & 0xFF) / 255, (c & 0xFF) / 255, 1);

		// destello a la llegada (overdriveBurn)
		var oc = mt.deepnight.Color.brightnessInt(room.bgColor, 0.6);
		oc = mt.deepnight.Color.rgbToInt(mt.deepnight.Color.saturation(mt.deepnight.Color.intToRgb(oc), -0.3));
		overdrive.color.set(((oc >> 16) & 0xFF) / 255, ((oc >> 8) & 0xFF) / 255, (oc & 0xFF) / 255, 1);
		overdrive.visible = false;
		tw.delay(total * 0.4, function() {
			overdrive.visible = true;
			overdrive.alpha = 0;
			tw.create(overdrive, "alpha", 0.7, TEaseIn, total * 0.6).onEnd = function() {
				tw.create(overdrive, "alpha", 0, TEaseOut, total * 0.4).onEnd = function() overdrive.visible = false;
			};
		});

		// fondo de estrellas del sistema de llegada
		solarStars.root.visible = true;
		for( o in solarStars.layers ) {
			o.l.zoom = 0;
			o.b.alpha = 0;
			tw.create(o.l, "zoom", ANIM_SOLARSTAR_ZOOM, TEaseOut, total);
			tw.create(o.b, "alpha", 1, TEaseOut, total);
		}

		// fondo comun
		for( o in common.layers ) {
			tw.create(o.l, "zoom", ANIM_COMMON_ZOOM, TEase, total);
			tw.create(o.b, "alpha", COMMON_HIGH_ALPHA, TEase, total);
		}

		// el sistema crece desde un punto
		var d = total * 0.9;
		zoomCache.visible = true;
		zoomCache.alpha = 0.5;
		cacheScale = 0.01;
		tw.delay(total * 0.1, function() {
			tw.create(this, "cacheScale", 1, TEase, d);
			tw.create(zoomCache, "alpha", 1, TEaseOut, 500);
		});

		// el sector se aleja
		var d = total * 0.8;
		for( o in sector.layers ) {
			var o = o;
			o.l.zoom = 0;
			tw.create(o.l, "zoom", ANIM_SECTOR_ZOOM, TEaseIn, d).onUpdateT = function(t) o.b.alpha = 1 - t;
		}
		for( sp in sectorEntities() ) {
			var e = sp.e;
			e.zoom = 0;
			tw.create(e, "zoom", ANIM_SECTOR_ZOOM * 0.2, TEaseIn, d * 0.4).onUpdateT = function(t) e.alpha = 1 - t;
		}
	}

	/** Manager.generateSolar: crea la vista del sistema (oculta hasta finishSolar) */
	function prepareSolar( si : ExpSystem ) {
		curSystem = si;
		disposeView(solar);
		disposeView(solarStars);
		for( s in solarSpots ) s.obj.remove();
		solarSpots = [];
		solarRelabels = [];
		if( worldSolar != null ) worldSolar.remove();

		var job = jobs.get(si.id);
		var room : ExpRoom, stars : ExpRoom;
		if( job != null && job.done ) {
			room = job.room;
			stars = job.stars;
		} else {
			var t0 = haxe.Timer.stamp();
			var g = generateSystem(si);
			room = g.room;
			stars = g.stars;
			if( Dev.trace ) Sys.println("tiempos: sistema y fondo=" + Std.int((haxe.Timer.stamp() - t0) * 1000) + "ms (sin segundo plano)");
		}
		jobs.remove(si.id);
		solar = makeView(room);
		solarStars = makeView(stars);
		buildLayers(solarStars);
		buildLayers(solar);
		content.addChildAt(solarStars.root, content.getChildIndex(sector.root) + 1);
		content.addChildAt(solar.root, content.getChildIndex(solarStars.root) + 1);
		worldSolar = new h2d.Object(content);
		content.addChildAt(worldSolar, content.getChildIndex(shipWorld));
		for( pv in room.planetViews ) addPlanet(pv);
		solar.viewX = solarStars.viewX = room.entrance.x;
		solar.viewY = solarStars.viewY = room.entrance.y;
	}

	/** Room.generateSolarSystem + generateSolarStars: solo calcula imagenes (BitmapData por software), se puede hacer en otro hilo */
	static function generateSystem( si : ExpSystem ) {
		var room = new ExpRoom(si.seed, VW, VH);
		room.generateSolarSystem(si);
		var stars = new ExpRoom(si.seed, VW, VH);
		stars.bgColor = room.bgColor;
		stars.generateSolarStars();
		return { room : room, stars : stars };
	}

	/** empieza a generar un sistema en segundo plano (mientras la nave vuela hacia el) */
	function pregen( si : ExpSystem ) {
		if( jobs.exists(si.id) ) return;
		var job = { room : null, stars : null, done : false };
		jobs.set(si.id, job);
		sys.thread.Thread.create(function() {
			var t0 = haxe.Timer.stamp();
			var g = generateSystem(si);
			job.room = g.room;
			job.stars = g.stars;
			job.done = true;
			if( Dev.trace ) Sys.println("tiempos: sistema generado en segundo plano en " + Std.int((haxe.Timer.stamp() - t0) * 1000) + "ms");
		});
	}

	/** processEnd de Manager.gotoSolar */
	function finishSolar( si : ExpSystem ) {
		sector.root.visible = false;
		worldSector.visible = false;
		solarStars.root.visible = true;
		solar.root.visible = true;
		worldSolar.visible = true;
		setBg(solar.room.bgColor);
		current = solar;
		inSolar = true;
		ship.x = solar.room.entrance.x;
		ship.y = solar.room.entrance.y;
		locked = false;
		setCache(null);
		for( o in solarStars.layers ) {
			o.l.zoom = ANIM_SOLARSTAR_ZOOM;
			o.b.alpha = 1;
		}
		for( o in common.layers ) {
			o.l.zoom = ANIM_COMMON_ZOOM;
			o.b.alpha = COMMON_HIGH_ALPHA;
		}
		onPos([1, si.id]);
	}

	/** inicio junto a un planeta o dentro de un sistema (Manager.start: gotoSolar sin animacion) */
	function buildSolar( si : ExpSystem, arrival : Float, planetId : Int ) {
		prepareSolar(si);
		var room = solar.room;
		room.entrance.x = room.center.x + Math.cos(arrival) * Math.min(250, room.exitDist - 10);
		room.entrance.y = room.center.y + Math.sin(arrival) * Math.min(250, room.exitDist - 10);
		if( planetId >= 0 )
			for( pv in room.planetViews )
				if( pv.infos.id == planetId ) {
					room.entrance.x = pv.x + 32;
					room.entrance.y = pv.y;
				}
		finishSolar(si);
		solar.viewX = solarStars.viewX = ship.x;
		solar.viewY = solarStars.viewY = ship.y;
		ship.rotation = planetId >= 0 ? 180 : 180 + arrival * 180 / Math.PI;
		ship.dx = ship.dy = 0;
		cursorAlpha = 0;
	}

	function addPlanet( pv : ExpPlanetView ) : Spot {
		var sp = new Spot();
		sp.planet = pv.infos;
		sp.e.dataId = pv.infos.id;
		sp.e.x = pv.x;
		sp.e.y = pv.y;
		var obj = new h2d.Object(worldSolar);
		sp.obj = obj;
		var bmp = new h2d.Bitmap(bmpTile(pv.bd, true).center(), obj);
		bmp.setScale(pv.scale);
		if( pv.icon > 0 ) {
			var ic = new h2d.Bitmap(tiles.sub(pv.icon * 16, 0, 16, 16, -8, -8), obj);
			ic.x = pv.iconX;
			ic.y = pv.iconY;
		}
		if( pv.showName ) {
			var p = pv.infos;
			var t = nameLabel(obj, function() return p.name, 1.1, 0xFFFFFF, true);
			t.y = Std.int(pv.bd.height * pv.scale * 0.3);
		}
		sp.half = pv.bd.width * pv.scale * 0.5 - 10;
		solarSpots.push(sp);
		return sp;
	}

	/** Manager.gotoSector (con animacion) */
	function gotoSector( from : ExpSystem ) {
		closeWindow();
		var pt = sector.room.gridToMap(from.x, from.y);
		sectorEntrance.x = pt.x;
		sectorEntrance.y = pt.y;
		locked = true;
		hyperjumpFxHorizontal(function() sectorZoomAnim(from));
	}

	function sectorZoomAnim( from : ExpSystem ) {
		stopShip();
		locked = true;
		curSystem = null;
		var total = 800;
		shipVisible = false;
		shipAlpha = 1;
		var arrivalAng = ship.rotation;

		var zoomProgress = { t : 0.0 };
		tw.create(zoomProgress, "t", 1, TLinear, total).onEnd = function() {
			// processEnd
			locked = false;
			setCache(null);
			ship.rotation = arrivalAng;
			hyperjumpArrivalFx(6);
		};

		setCache(snapshot());
		zoomCache.visible = true;
		zoomCache.alpha = 1;
		cacheScale = 1;

		ship.x = sectorEntrance.x + Math.cos(arrivalAng * Math.PI / 180) * 20;
		ship.y = sectorEntrance.y + Math.sin(arrivalAng * Math.PI / 180) * 20;
		ship.dx = ship.dy = 0;

		// el sistema se encoge hasta un punto
		var d = total * 1.;
		var e = TBurnIn;
		for( s in solarSpots ) s.obj.remove();
		solarSpots = [];
		solarRelabels = [];
		disposeView(solar);
		solar = null;
		if( worldSolar != null ) worldSolar.remove();
		worldSolar = null;
		inSolar = false;
		tw.create(this, "cacheScale", 0.01, e, d);
		tw.delay(d * 0.5, function() tw.create(zoomCache, "alpha", 0, TEaseIn, d * 0.5));
		tw.create(burn, "alpha", 0, TEaseIn, d).onEnd = function() burn.visible = false;

		// destello de la salida
		overdrive.visible = true;
		overdrive.alpha = 0.6;
		tw.create(overdrive, "alpha", 0, TEaseOut, 800).onEnd = function() overdrive.visible = false;

		// fondo de estrellas del sistema
		var stars = solarStars;
		for( o in solarStars.layers ) {
			tw.create(o.l, "zoom", 0, e, d);
			tw.create(o.b, "alpha", 0, e, d);
		}
		tw.delay(d, function() {
			if( solarStars == stars ) {
				disposeView(solarStars);
				solarStars = null;
			}
		});

		// fondo comun
		for( o in common.layers ) {
			tw.create(o.l, "zoom", 0, TEaseOut, total);
			tw.create(o.b, "alpha", COMMON_LOW_ALPHA, e, d);
		}

		// el sector vuelve
		var d = total;
		current = sector;
		sector.root.visible = true;
		worldSector.visible = true;
		centerView();
		for( o in sector.layers ) {
			o.b.alpha = 0;
			o.l.zoom = ANIM_SECTOR_ZOOM;
			tw.create(o.l, "zoom", 0, TEaseOut, d);
			tw.create(o.b, "alpha", 1, TEaseIn, d);
		}
		for( sp in sectorEntities() ) {
			var e = sp.e;
			e.alpha = 0;
			e.zoom = ANIM_SECTOR_ZOOM * 0.2;
			tw.delay(d * 0.5, function() {
				tw.create(e, "zoom", 0, TEaseOut, d * 0.5).onUpdateT = function(t) e.alpha = t;
			});
		}
		setBg(sector.room.bgColor, d);
		onPos([0, from.x, from.y]);
	}

	// ---------------------------------------------------------------- efectos (Manager.hyperjump*, novaFx, makeHyperspacePart)

	var lastTmod = 1.;
	var cacheScale(default, set) = 1.;
	function set_cacheScale( s : Float ) {
		cacheScale = s;
		if( zoomCache != null && zoomCache.tile != null ) {
			zoomCache.setScale(s);
			zoomCache.x = VW * 0.5 - zoomCache.tile.width * 0.5 * s;
			zoomCache.y = VH * 0.5 - zoomCache.tile.height * 0.5 * s;
		}
		return s;
	}

	function setCache( t : h2d.Tile ) {
		if( zoomCache.tile != null && zoomCache.tile.getTexture() != null ) zoomCache.tile.getTexture().dispose();
		zoomCache.tile = t;
		zoomCache.visible = false;
		cacheScale = cacheScale;
	}

	/**
	 * Room.snapshot: el sistema entero (capas sin hideZoom y planetas) visto con una ventana del tamano de la habitacion,
	 * centrada donde esta la camara, en una sola imagen.
	 */
	function snapshot() : h2d.Tile {
		var w = solar.room.width, h = solar.room.height;
		var holder = new h2d.Object();
		var i1 = content.getChildIndex(solar.root);
		var oldVis = solar.root.visible, oldVis2 = worldSolar.visible;
		holder.addChild(solar.root);
		var i2 = content.getChildIndex(worldSolar);
		holder.addChild(worldSolar);
		solar.root.visible = worldSolar.visible = true;
		updateLayers(solar, solar.viewX, solar.viewY, 0, w, h);
		for( o in solar.layers ) if( o.l.hideZoom ) o.b.visible = false;
		for( sp in solarSpots ) {
			sp.obj.setPosition(Std.int(w * 0.5 + sp.e.x - solar.viewX), Std.int(h * 0.5 + sp.e.y - solar.viewY));
			sp.obj.setScale(1);
			sp.obj.alpha = 1;
		}
		var tex = new h3d.mat.Texture(w, h, [Target]);
		tex.clear(0, 0);
		holder.drawTo(tex);
		for( o in solar.layers ) o.b.visible = true;
		solar.root.visible = oldVis;
		worldSolar.visible = oldVis2;
		content.addChildAt(solar.root, i1);
		content.addChildAt(worldSolar, i2);
		return h2d.Tile.fromTexture(tex);
	}

	inline function shipScreenX() return screenX(ship.x, current.viewX, zoomT);
	inline function shipScreenY() return screenY(ship.y, current.viewY, zoomT);

	/** Manager.hyperjumpFx3D: lineas que convergen en la nave y destello que absorbe */
	function hyperjumpFx3D( cb : Void -> Void ) {
		tw.delay(50, cb);
		shipVisible = false;
		var px = shipScreenX(), py = shipScreenY();
		for( i in 0...10 ) {
			var a = (i / 15) * Math.PI * 8 + Math.random() * 0.05;
			var d = Math.random() * 5 + 15;
			var x = px + Math.cos(a) * d;
			var y = py + Math.sin(a) * d;
			var a = Math.atan2(py - y, px - x);
			var s = 2 + Math.random() * 0.5;
			var p = new ExpPart(fxLayer, x, y);
			p.drawBox(15, 2, 0xFFFFFF, 1, REACTOR_COLOR);
			p.setLife(15 + Std.random(5));
			p.rotation = a;
			p.frictX = p.frictY = 0.95;
			p.alpha = Math.random() * 0.9 + 0.1;
			p.onUpdate = function() p.setScale(1 - p.time());
			p.dx = Math.cos(a) * s;
			p.dy = Math.sin(a) * s;
		}
		novaFx(px, py, 40, true);
	}

	/** Manager.hyperjumpFxHorizontal: rayas hacia delante (y unas pocas hacia atras) y destello que crece */
	function hyperjumpFxHorizontal( cb : Void -> Void ) {
		tw.delay(300, cb);
		shipVisible = false;
		var px = shipScreenX(), py = shipScreenY();
		for( i in 0...15 ) {
			var back = i <= 5;
			var a = (ship.rotation + (back ? 180 : 0)) * Math.PI / 180;
			var s = back ? Math.random() * 4 + 1 : Math.random() * 5 + 5;
			var p = new ExpPart(fxLayer, px + Math.random() * 7 * (Std.random(2) * 2 - 1), py + Math.random() * 7 * (Std.random(2) * 2 - 1));
			p.drawBox(Std.random(5) + 2, Std.random(2) + 1, 0xFFFFFF, 1, REACTOR_COLOR);
			p.setLife(10 + Std.random(10));
			p.rotation = a;
			p.frictX = p.frictY = 0.80 + Math.random() * 0.10;
			p.alpha = Math.random() * 0.9 + 0.1;
			var scale = (back ? 3 : 7) * (0.7 + Math.random() * 0.3);
			p.onUpdate = function() p.scaleX = (p.getSpeed() / s) * scale;
			p.dx = Math.cos(a) * s;
			p.dy = Math.sin(a) * s;
		}
		novaFx(px, py, 25, false);
	}

	/** Manager.hyperjumpArrivalFx: la nave sale disparada, rayas rectas y destello detras */
	function hyperjumpArrivalFx( speed : Float ) {
		var a = ship.getAngleRad();
		ship.dx = Math.cos(a) * speed;
		ship.dy = Math.sin(a) * speed;
		var px = shipScreenX(), py = shipScreenY();
		shipVisible = true;
		shipAlpha = 0;
		tw.create(this, "shipAlpha", 1, TEaseIn, 500);
		for( i in 0...15 ) {
			var a = ship.rotation * Math.PI / 180;
			var s = Math.random() * 5 + 4;
			var p = new ExpPart(fxLayer, px + Math.random() * 7 * (Std.random(2) * 2 - 1) - Math.cos(a) * 40, py + Math.random() * 7 * (Std.random(2) * 2 - 1) - Math.sin(a) * 40);
			p.drawBox(Std.random(5) + 2, Std.random(2) + 1, 0xFFFFFF, 1, REACTOR_COLOR);
			p.setLife(10 + Std.random(10));
			p.rotation = a;
			p.frictX = p.frictY = 0.80 + Math.random() * 0.10;
			p.alpha = Math.random() * 0.9 + 0.1;
			var scale = 7 * (0.7 + Math.random() * 0.3);
			p.onUpdate = function() p.scaleX = (p.getSpeed() / s) * scale;
			p.dx = Math.cos(a) * s;
			p.dy = Math.sin(a) * s;
		}
		novaFx(px - Math.cos(a) * 40, py - Math.sin(a) * 40, 30, true);
	}

	/** Manager.novaFx */
	function novaFx( x : Float, y : Float, radius : Float, absorb : Bool ) {
		var nova = new h2d.Bitmap(ExpNova.tile(Std.int(radius), REACTOR_COLOR), fxLayer);
		nova.blendMode = Add;
		nova.x = x;
		nova.y = y;
		var holder = { s : absorb ? 1. : 0.3 };
		nova.setScale(holder.s);
		nova.alpha = 0.5;
		var a = tw.create(holder, "s", absorb ? 0.3 : 1, TBurnIn, 500);
		a.onUpdateT = function(t) {
			nova.setScale(holder.s);
			nova.alpha = 0.5 * (1 - t);
		};
		a.onEnd = function() nova.remove();
	}

	/** Manager.makeHyperspacePart: lineas que salen del centro de la pantalla y se aceleran */
	function makeHyperspacePart( size : Float ) {
		var col = mt.deepnight.Color.brightnessInt(current.room.starColor, 0.4);
		var a = Math.random() * Math.PI * 2;
		var s = Math.random() * 3 + 3;
		var p = new ExpPart(fxLayer, VW * 0.5, VH * 0.5);
		p.dx = Math.cos(a) * s;
		p.dy = Math.sin(a) * s;
		var n = 2 + Math.random() * 40;
		p.rx += p.dx * n;
		p.ry += p.dy * n;
		p.drawLine(1.5, col, current.room.starColor);
		p.setLife(20);
		p.rotation = a;
		p.onUpdate = function() p.scaleX = size * p.getSpeed() * 0.8;
		p.alpha = Math.random() * 0.8 + 0.2;
		p.frictX = p.frictY = 1.15;
	}

	// ---------------------------------------------------------------- servidor, camara, fondo y textos

	/** ServerCall.sendAction en modo local: responde a los 500 ms, con el icono de carga */
	function sendAction( cb : Void -> Void ) {
		loading(true);
		serverLock = true;
		tw.delay(500, function() {
			loading(false);
			serverLock = false;
			cb();
		});
	}

	/** Manager.loading */
	function loading( b : Bool ) {
		tw.terminate(spinner);
		if( b ) {
			spinner.visible = true;
			spinner.alpha = 1;
		} else
			tw.create(spinner, "alpha", 0, TLinear, 500).onEnd = function() spinner.visible = false;
	}

	/** Manager.showBar */
	function showBar( f : Float ) {
		if( f < 0 ) f = 0;
		if( f > 1 ) f = 1;
		bar.visible = true;
		if( f < 1 ) tw.create(bar, "alpha", 1, TEaseOut, 500);
		else tw.create(bar, "alpha", 0, TEaseIn, 500).onEnd = function() bar.visible = false;
		var col = 0xB6AEC6;
		bar.clear();
		bar.beginFill(0, 1);
		bar.drawRect(-2, -2, 304, 7);
		bar.beginFill(mt.deepnight.Color.brightnessInt(col, -0.7), 1);
		bar.drawRect(0, 0, 300, 3);
		bar.beginFill(col, 1);
		bar.drawRect(0, 0, 300 * f, 3);
		bar.endFill();
		bar.x = Std.int(VW * 0.5 - 150);
		bar.y = Std.int(VH * 0.5 - 1.5) + 50;
	}

	/** Manager.centerView: la camara va a la nave (con duracion, en curva TEase) */
	function centerView( duration = 0, ?cb : Void -> Void ) {
		if( duration > 0 && (current.viewX != ship.x || current.viewY != ship.y) ) {
			var n = 2;
			var end = function() {
				if( --n == 0 ) {
					lockCamera = false;
					if( cb != null ) cb();
				}
			};
			lockCamera = true;
			tw.create(current, "viewX", ship.x, TEase, duration).onEnd = end;
			tw.create(current, "viewY", ship.y, TEase, duration).onEnd = end;
		} else {
			current.viewX = ship.x;
			current.viewY = ship.y;
			lockCamera = false;
			if( cb != null ) cb();
		}
	}

	// ---------------------------------------------------------------- transiciones, texto y ventana

	/** Manager.popString: nombre grande que aparece (500 ms) y se desvanece (2,5 s) pasado un rato */
	function popString( s : String, col = 0xFFFFFF, fadeOut = true ) {
		var tf = label(overlay, s, 4., col);
		tf.x = Std.int(VW * 0.5 - tf.textWidth * tf.scaleX * 0.5);
		tf.y = Std.int(VH * 0.25);
		tf.alpha = 0;
		tw.create(tf, "alpha", 1, TEase, 500);
		if( fadeOut )
			tw.delay(1000 + s.length * 20, function() {
				tw.create(tf, "alpha", 0, TEaseIn, 2500).onEnd = function() tf.remove();
			});
		return tf;
	}

	function closeWindow() {
		if( win != null ) {
			win.remove();
			win = null;
		}
		winButtons = [];
		winSpot = null;
		zoomGoal = 0;
	}

	/** ventana del robot, de un sistema cerrado o de un planeta, con los textos en el idioma actual */
	function showWindow( sp : Spot ) {
		if( sp == robot ) {
			openWindow(sp, Lang.t("exp.robot"), "ESCorp", Lang.t("exp.dock"), dockRobot);
			return;
		}
		if( sp.planet == null ) {
			switch( sp.system.status ) {
			case SLocked(cost): openWindow(sp, sp.system.name, sp.system.x + "," + sp.system.y, "" + cost, function() onUnlock(sp.system));
			case SOpen:
			}
			return;
		}
		var p = sp.planet;
		var bname = ExpOffline.biomeName(p.biome);
		// anadido del port (Licenses): la ventana dice si es el principal o esta abandonado, y ofrece abandonarlo
		if( p.status == PAbandonned ) bname += "  ·  " + Lang.t("exp.abandoned");
		else if( isMain(p) ) bname += "  ·  " + Lang.t("exp.main");
		var abandon = canAbandon(p) ? { label : Lang.t("exp.abandon"), cb : function() onAbandon(p, curSystem) } : null;
		switch( p.status ) {
		case PUnexplored:
			openWindow(sp, p.name, bname, Lang.t("exp.scan"), function() startScan(p), abandon);
		case PActive, PInvited:
			openWindow(sp, p.name, bname, Lang.t("exp.land"), function() landPlanet(p), abandon);
		case PAbandonned, PForbidden:
			openWindow(sp, p.name, bname, null, function() {});
		}
	}

	/** Manager.setWindow + addButton: barra superior con el nombre, barra inferior con el boton (y el de abandonar al lado) */
	function openWindow( sp : Spot, title : String, subtitle : String, buttonLabel : String, cb : Void -> Void, ?second : { label : String, cb : Void -> Void } ) {
		closeWindow();
		winSpot = sp;
		win = new h2d.Object(content);
		var col = 0x726DBC;
		var dark = mt.deepnight.Color.capBrightnessInt(col, 0.2);
		var top = new h2d.Bitmap(h2d.Tile.fromColor(dark, VW, 70, 0.6), win);
		var t = label(top, title, 4., 0xFFFFFF);
		t.x = Std.int(VW * 0.5 - t.textWidth * t.scaleX * 0.5);
		t.y = 14;
		if( subtitle != null ) {
			var st = label(win, subtitle, 1.6, 0xFFFFFF);
			st.x = Std.int(VW * 0.5 - st.textWidth * st.scaleX * 0.5);
			st.y = 76;
		}
		var bottom = new h2d.Bitmap(h2d.Tile.fromColor(dark, VW, 70, 0.6), win);
		bottom.y = VH - 70;
		if( buttonLabel != null ) addButton(buttonLabel, cb);
		if( second != null ) addButton(second.label, second.cb, 0xFF5C5C);
		// los botones, uno al lado del otro y centrados
		var total = -16.;
		for( b in winButtons ) total += b.o.width + 16;
		var bx = VW * 0.5 - total * 0.5;
		for( b in winButtons ) {
			b.g.x = Std.int(bx);
			bx += b.o.width + 16;
		}
		zoomGoal = 0.6;
	}

	function addButton( text : String, cb : Void -> Void, col = 0x18E7DC ) {
		var w = Math.max(128, text.length * 14);
		var g = new h2d.Graphics(win);
		g.beginFill(col, 0.3);
		g.drawRect(0, 0, w, 24);
		g.endFill();
		g.lineStyle(1, col, 1);
		g.drawRect(0, 0, w, 24);
		// cambio del port: en el centro de la barra de abajo (el original lo pegaba a su borde de arriba)
		g.y = VH - 70 + (70 - 24) * 0.5;
		// centrado tambien en alto: el y fijo del original (4) era para su fuente, la de Heaps deja hueco arriba y lo bajaba
		Theme.center(label(g, text, 1.4, 0xFFFFFF), w, 24);
		var it = new h2d.Interactive(w, 24, g);
		it.onOver = function(_) g.alpha = 1.0;
		it.onOut = function(_) g.alpha = 0.8;
		g.alpha = 0.8;
		it.onClick = function(_) {
			g.alpha = 0.5;
			cb();
		};
		winButtons.push({ o : it, g : g, cb : cb });
	}

	// ---------------------------------------------------------------- viaje

	function stopShip( brake = false ) {
		if( brake ) ship.dx = ship.dy = 0;
		targetSpot = null;
		ship.target = null;
	}

	/** Manager.moveShip: hacia un objeto del mapa o hacia un punto libre */
	function moveShip( ?sp : Spot, ?pt : { x : Float, y : Float } ) {
		stopShip();
		if( win != null && (sp == null || sp != winSpot) ) closeWindow();
		// el robot se para y te espera mientras lo sigues; si vas a otro sitio, sigue su camino
		robotStopped = sp != null && sp == robot;
		if( robotStopped ) {
			targetSpot = sp;
			ship.target = { x : sp.e.x, y : sp.e.y };
			cursorAlpha = 1;
			cursorE.scale = 4;
			ship.onArriveDist = 30;
			ship.onArrive = function() {
				if( winSpot != sp ) showWindow(sp);
			};
			return;
		}
		if( sp != null ) {
			targetSpot = sp;
			ship.target = { x : sp.e.x, y : sp.e.y };
			cursorAlpha = 1;
			cursorE.scale = 4;
			if( !inSolar ) {
				switch( sp.system.status ) {
				case SOpen:
					pregen(sp.system);
					ship.onArriveDist = 0;
					ship.onArrive = function() onReachSystem(sp);
				case SLocked(_):
					ship.onArriveDist = 30;
					ship.onArrive = function() {
						if( winSpot != sp ) showWindow(sp);
					};
				}
			} else {
				ship.onArriveDist = 30;
				ship.onArrive = function() {
					if( winSpot != sp ) showWindow(sp);
				};
			}
		}
		if( pt != null ) {
			var room = current.room;
			var x = Math.max(0, Math.min(room.width - 1, pt.x));
			var y = Math.max(0, Math.min(room.height - 1, pt.y));
			ship.onArrive = null;
			targetSpot = null;
			ship.target = { x : x, y : y };
			cursorE.x = x;
			cursorE.y = y;
			cursorE.scale = 1.5;
			cursorAlpha = 1;
		}
	}

	/**
	 * Entrar en un planeta (botones Escanear y Aterrizar). Cambio del port: el original fundia a negro y mostraba una barra
	 * mientras su servidor generaba el planeta. Aqui se cierra la ventana, la camara se acerca al planeta mientras la pantalla
	 * se oscurece un poco, sale el nombre una vez y se pasa a la pantalla de carga del juego (que tiene la barra de verdad).
	 */
	function landPlanet( p : ExpPlanet ) {
		if( locked || !canLand(p) ) return;
		var sp = winSpot;
		closeWindow();
		locked = true;
		serverLock = true;
		stopShip();
		loading(true);
		if( sp != null ) {
			lockCamera = true;
			tw.create(current, "viewX", sp.e.x, TEase, 700);
			tw.create(current, "viewY", sp.e.y, TEase, 700);
		}
		zoomGoal = 0;
		var z = { v : zoomT };
		tw.create(z, "v", 2.5, TEaseIn, 900).onUpdateT = function(_) zoomT = z.v;
		fade.visible = true;
		tw.create(this, "fadeAlpha", 0.55, TEaseIn, 900);
		popString(p.name);
		tw.delay(1000, function() onLand(p, curSystem));
	}

	/** Escanear: como el original, sin licencia libre sale "Pas de licence" en amarillo y no pasa nada mas */
	function startScan( p : ExpPlanet ) {
		if( locked ) return;
		if( !canScan(p) ) {
			popString(Lang.t("exp.nolicense"), 0xFFC600);
			return;
		}
		landPlanet(p);
	}

	/**
	 * Un planeta abandonado (anadido del port, Licenses.abandon): se repinta apagado y su ventana se queda sin botones. Si
	 * con el desaparecio el sistema (goneId), en el sector se quita y aparece newSystem en su lugar; si no, se rehace su icono.
	 */
	public function abandoned( p : ExpPlanet, ?goneId : Int, ?newSystem : ExpSystem ) {
		p.status = PAbandonned;
		for( i in 0...solarSpots.length ) {
			var old = solarSpots[i];
			if( old.planet.id != p.id ) continue;
			old.obj.remove();
			var sp = addPlanet(solar.room.repaintPlanet(p));
			solarSpots.pop();
			solarSpots[i] = sp;
			if( winSpot == old ) showWindow(sp);
			break;
		}
		var sysId = goneId != null ? goneId : curSystem.id;
		for( sp in sectorSpots.copy() )
			if( sp.system.id == sysId ) {
				sp.obj.remove();
				sectorSpots.remove(sp);
				if( goneId == null ) addSystem(sp.system);
			}
		if( newSystem != null ) addSystem(newSystem);
		rebuildGps();
	}

	// ---------------------------------------------------------------- bucle

	function mouseInMap() : { x : Float, y : Float } {
		var p = new h2d.col.Point(getScene().mouseX, getScene().mouseY);
		content.globalToLocal(p);
		return { x : p.x - VW * 0.5 + current.viewX, y : p.y - VH * 0.5 + current.viewY };
	}

	function hit( pt : { x : Float, y : Float } ) : Spot {
		if( !inSolar && robot != null && Math.abs(pt.x - robot.e.x) <= robot.half && Math.abs(pt.y - robot.e.y) <= robot.half ) return robot;
		var list = inSolar ? solarSpots : sectorSpots;
		for( sp in list )
			if( Math.abs(pt.x - sp.e.x) <= sp.half && Math.abs(pt.y - sp.e.y) <= sp.half ) return sp;
		return null;
	}

	public function layout() {
		var s = getScene();
		var w = s != null ? s.width : 1280., h = s != null ? s.height : 720.;
		var k = Math.max(w / VW, h / VH);
		content.setScale(k);
		content.x = (w - VW * k) * 0.5;
		content.y = (h - VH * k) * 0.5;
	}

	/** ZLayer.update: posicion y escala de cada capa segun la camara y el zoom */
	function updateLayers( v : View, vx : Float, vy : Float, zoomAdd : Float, VW = 900, VH = 450 ) {
		for( o in v.layers ) {
			var l = o.l;
			var z = l.z;
			var zoom = (l.zoom + zoomAdd) * z * z;
			var s = 1 + zoom * z;
			var x = VW * 0.5 * (1 - z) - l.texWid * 0.5 + (VW * 0.5 + l.xOffset - vx) * z;
			var y = VH * 0.5 * (1 - z) - l.texHei * 0.5 + (VH * 0.5 + l.yOffset - vy) * z;
			var tx = -VW * 0.5 * s + VW * 0.5 + x * (zoom * z) + x;
			var ty = -VH * 0.5 * s + VH * 0.5 + y * (zoom * z) + y;
			if( l.repeat ) {
				while( tx > 0 ) tx -= l.texWid * s;
				while( tx + l.texWid * s < 0 ) tx += l.texWid * s;
				while( ty > 0 ) ty -= l.texHei * s;
				while( ty + l.texHei * s < 0 ) ty += l.texHei * s;
				o.b.setScale(s);
				o.b.setPosition(Math.round(tx), Math.round(ty));
			} else {
				// la imagen se escala primero alrededor de su centro (escala propia de la capa) y despues se aplica el zoom
				var ox = l.bd.width * 0.5 * (1 - l.scaleX), oy = l.bd.height * 0.5 * (1 - l.scaleY);
				var px = tx + ox * s, py = ty + oy * s;
				o.b.setScale(l.scaleX * s);
				if( l.snap ) o.b.setPosition(Math.round(px), Math.round(py)) else o.b.setPosition(px, py);
			}
		}
	}

	/** posicion en pantalla de algo del mundo, con zoom (Entity.update) */
	inline function screenX( x : Float, vx : Float, zoom : Float ) {
		var xm = VW * 0.5 + x - vx;
		return VW * 0.5 + (xm - VW * 0.5) * (1 + zoom);
	}

	inline function screenY( y : Float, vy : Float, zoom : Float ) {
		var ym = VH * 0.5 + y - vy;
		return VH * 0.5 + (ym - VH * 0.5) * (1 + zoom);
	}

	/** Manager.gpsArrow: punta de flecha verde de 1 px con brillo */
	function gpsArrow( c = 0x80FF00 ) : h2d.Graphics {
		var g = new h2d.Graphics(gpsLayer);
		g.lineStyle(1, c, 1);
		g.moveTo(0, -8);
		g.lineTo(5, 0);
		g.lineTo(0, 8);
		g.filter = new h2d.filter.Glow(c, 0.5, 3, 1, 1, false);
		return g;
	}

	function clearGps() {
		for( g in gps ) g.arrow.remove();
		gps = [];
	}

	inline function isActive( p : ExpPlanet ) return p.status == PActive || p.status == PInvited;

	/** gotoSolar: una flecha por planeta activo; gotoSector (processEnd): una por sistema abierto con alguno */
	function rebuildGps() {
		clearGps();
		var list = inSolar ? solarSpots : sectorSpots;
		for( sp in list ) {
			var on = false;
			if( inSolar ) on = sp.planet != null && (isActive(sp.planet) || sp.planet.id == tutoTarget);
			else on = sp.system != null && sp.system.status == SOpen && Lambda.exists(sp.system.planets, isActive);
			if( on ) gps.push({ arrow : gpsArrow(), target : sp.e });
		}
		// el robot comerciante, con una flecha naranja (anadido del port)
		if( !inSolar && robot != null ) gps.push({ arrow : gpsArrow(0xFFA040), target : robot.e });
		gpsView = current;
		gpsCount = list.length;
	}

	/** Esc (o Start del mando): cierra la ventana abierta o abre el menu de pausa. No durante un viaje animado */
	public function escape() {
		if( paused || locked || serverLock ) return;
		if( win != null ) {
			closeWindow();
			targetSpot = null;
		} else onPause();
	}

	public function update( dt : Float ) {
		// en pausa el mapa se sigue dibujando (y recolocando, y termina su animacion de entrada), pero no hay entrada y
		// ni la nave ni el robot avanzan
		var tmod = dt * 30;
		lastTmod = tmod;
		if( getScene() != null ) layout();
		tw.update(tmod);
		ExpPart.updateAll(tmod);
		if( spinner.visible && spinner.alpha > 0 ) spinner.rotation += 25 * Math.PI / 180 * tmod;

		// entrada: clic en un objeto o en un punto libre (Manager.onMouseDown / onMouseUp)
		if( !paused && !locked && !serverLock && getScene() != null ) {
			var K = hxd.Key;
			var m = mouseInMap();
			var overButton = false;
			for( b in winButtons ) if( b.o.isOver() ) overButton = true;
			if( K.isPressed(K.MOUSE_LEFT) && !overButton ) {
				down = hit(m);
				downOnBg = down == null;
			}
			if( K.isReleased(K.MOUSE_LEFT) && !overButton ) {
				var h = hit(m);
				if( h != null && h == down ) moveShip(h);
				else if( h == null && downOnBg ) moveShip(null, m);
				down = null;
			}
			if( K.isPressed(K.ESCAPE) ) escape();
		}

		if( !paused ) {
			var ox = ship.x, oy = ship.y;
			ship.update(tmod);
			var d = Math.sqrt((ship.x - ox) * (ship.x - ox) + (ship.y - oy) * (ship.y - oy));
			if( d > 0 ) onTravel(d, inSolar);
		}
		if( ship.getScreenSpeed() > 0.3 ) ship.rotation = ship.getAngleRad() * 180 / Math.PI;

		// salida del sistema solar por los bordes (Manager.main). La respuesta del "servidor" tarda 500 ms y el salto otros 300:
		// mientras, la nave sigue, cruza el anillo (exitDist) y se para en el.
		if( inSolar && !locked && !paused ) {
			var room = solar.room;
			var d = Math.sqrt((ship.x - room.center.x) * (ship.x - room.center.x) + (ship.y - room.center.y) * (ship.y - room.center.y));
			if( ship.target != null && !serverLock ) {
				var td = Math.sqrt((ship.target.x - room.center.x) * (ship.target.x - room.center.x) + (ship.target.y - room.center.y) * (ship.target.y - room.center.y));
				if( d >= room.exitDist - 30 && td >= room.exitDist ) {
					var from = curSystem;
					if( canLeave() ) sendAction(function() gotoSector(from));
					else stopShip(true);
				}
			}
			if( d >= room.exitDist ) stopShip();
		}

		// cursor
		if( ship.target != null ) {
			cursorE.x = ship.target.x;
			cursorE.y = ship.target.y;
		}
		var d = ship.getTargetDist();
		if( targetSpot == null && d < 25 && cursorAlpha > 0 ) cursorAlpha -= 0.1 * tmod;
		if( d >= 25 && cursorAlpha < 1 ) cursorAlpha += 0.1 * tmod;
		if( cursorAlpha < 0 ) cursorAlpha = 0;
		if( cursorE.scale > 1.5 ) cursorE.scale += (1.5 - cursorE.scale) * Math.min(1, 0.25 * tmod);
		cursorRot += 7 * tmod;
		if( cursorRot >= 360 ) cursorRot -= 360;

		// zoom de la ventana (setZoom: 0.6 con la ventana abierta)
		if( !serverLock ) zoomT += (zoomGoal - zoomT) * Math.min(1, 0.12 * tmod);

		// camara (Manager.main: scrolling)
		var spd = 1 - Math.pow(0.9, tmod);
		if( !lockCamera ) {
			current.viewX += (ship.x - current.viewX) * spd;
			current.viewY += (ship.y - current.viewY) * spd;
		}
		if( inSolar ) {
			solarStars.viewX = current.viewX;
			solarStars.viewY = current.viewY;
		}

		// capas con paralaje
		updateLayers(common, sector.viewX, sector.viewY, 0);
		updateLayers(sector, sector.viewX, sector.viewY, inSolar ? 0 : zoomT);
		if( solarStars != null ) updateLayers(solarStars, solarStars.viewX, solarStars.viewY, 0);
		if( inSolar && solar != null ) updateLayers(solar, solar.viewX, solar.viewY, zoomT);

		// objetos: pantalla = centro + (posicion - camara), con zoom
		var vx = current.viewX, vy = current.viewY;
		var list = inSolar ? solarSpots : sectorSpots;
		for( sp in list ) {
			var z = zoomT + sp.e.zoom;
			sp.obj.setPosition(Std.int(screenX(sp.e.x, vx, z)), Std.int(screenY(sp.e.y, vy, z)));
			sp.obj.setScale(1 + z);
			sp.obj.alpha = sp.e.alpha;
		}
		if( !paused ) updateRobot(tmod, dt);
		if( robot != null && !inSolar ) {
			var z = zoomT + robot.e.zoom;
			robot.obj.setPosition(Std.int(screenX(robot.e.x, vx, z)), Std.int(screenY(robot.e.y, vy, z)));
			robot.obj.setScale(1 + z);
			robot.obj.alpha = robot.e.alpha;
			// si lo sigues y se para en un punto, el cursor va con el
			if( robotStopped && targetSpot == robot && ship.target != null ) {
				ship.target.x = robot.e.x;
				ship.target.y = robot.e.y;
			}
		}
		var sx = Std.int(screenX(ship.x, vx, zoomT)), sy = Std.int(screenY(ship.y, vy, zoomT));
		shipObj.setPosition(sx, sy);
		shipObj.alpha = shipAlpha;
		shipObj.rotation = ship.rotation * Math.PI / 180;
		if( shipBmp != null ) {
			// Manager.main: fotograma segun el rumbo y el resto como giro suave
			var n = shipTiles.length;
			var r = 1 - ((360 + 90 + ship.rotation) % 360) / 360;
			var f = Math.floor((n - 1) * r);
			if( f < 0 ) f = 0;
			if( f > n - 1 ) f = n - 1;
			var delta = n * r - f;
			shipBmp.tile = shipTiles[f];
			shipBmp.rotation = -delta * (360 / n) * Math.PI / 180;
			shipBmp.setPosition(sx, sy);
			shipBmp.visible = shipVisible;
			shipBmp.alpha = shipAlpha;
		}
		// GPS (Manager.main): la flecha gira alrededor de la nave a 64 px y se apaga al llegar (de 100 a 50 de distancia)
		var list = inSolar ? solarSpots : sectorSpots;
		if( gpsView != current || gpsCount != list.length ) rebuildGps();
		gpsLayer.visible = !locked && shipVisible;
		for( g in gps ) {
			var a = Math.atan2(g.target.y - ship.y, g.target.x - ship.x);
			var d = Math.sqrt((g.target.x - ship.x) * (g.target.x - ship.x) + (g.target.y - ship.y) * (g.target.y - ship.y));
			var k = Math.min(1, Math.max(0, (d - 50) / 50));
			g.arrow.alpha = k;
			g.arrow.setPosition(sx + Math.cos(a) * 64 * k, sy + Math.sin(a) * 64 * k);
			g.arrow.rotation = a;
		}
		cursor.setPosition(Std.int(screenX(cursorE.x, vx, zoomT)), Std.int(screenY(cursorE.y, vy, zoomT)));
		cursor.rotation = cursorRot * Math.PI / 180;
		cursor.setScale(Math.max(1, cursorE.scale) * (1 + zoomT));
		cursor.alpha = Math.max(0, Math.min(1, cursorAlpha));

		// calor del sol (burn)
		if( inSolar && !locked ) {
			var room = solar.room;
			var r = 1 - Math.sqrt((ship.x - room.center.x) * (ship.x - room.center.x) + (ship.y - room.center.y) * (ship.y - room.center.y)) / 140;
			if( r > 0 ) {
				var c = mt.deepnight.Color.interpolateInt(room.sunColor, 0xF46800, 0.3);
				burn.color.set(((c >> 16) & 0xFF) / 255, ((c >> 8) & 0xFF) / 255, (c & 0xFF) / 255, 1);
				burn.alpha = Math.min(r, 0.9) + Math.random() * r * 0.1;
			}
			burn.visible = r > 0;
		}

		fade.alpha = fadeAlpha;
		fade.visible = fadeAlpha > 0;
	}

	// ---------------------------------------------------------------- pruebas (banco de pruebas Dev)

	public function devClickSystem( id : Int ) {
		if( inSolar ) return;
		for( sp in sectorSpots ) if( sp.system.id == id ) moveShip(sp);
	}

	public function devClickPlanet( id : Int ) {
		if( !inSolar ) return;
		for( sp in solarSpots ) if( sp.planet.id == id ) moveShip(sp);
	}

	/** boton i de la ventana abierta (0 = Escanear o Aterrizar, 1 = Abandonar) */
	public function devPressButton( i = 0 ) {
		if( winButtons.length > i ) winButtons[i].cb();
	}

	public function devClickPoint( x : Float, y : Float, rel = false ) moveShip(null, rel ? { x : ship.x + x, y : ship.y + y } : { x : x, y : y });

	/** solo pruebas: rumbo de la nave (grados), fotograma de su imagen, velocidad y distancia al destino */
	public function devShipAngle() : String {
		var f = shipBmp == null ? -1 : shipTiles.indexOf(shipBmp.tile);
		return "nave=" + Std.int(ship.x) + "," + Std.int(ship.y) + " angulo=" + Math.round(ship.rotation) + " fotograma=" + f + "/" + shipTiles.length
			+ " vel=" + Std.int(ship.getScreenSpeed() * 100) / 100 + " destino=" + (ship.target == null ? "-" : "" + Std.int(ship.getTargetDist()));
	}

	public function devInfo() : String {
		var s = (inSolar ? "SISTEMA SOLAR " + curSystem.name : "SECTOR") + " nave=" + Std.int(ship.x) + "," + Std.int(ship.y) + " vel=" + Std.int(ship.getScreenSpeed() * 100) / 100
			+ " camara=" + Std.int(current.viewX) + "," + Std.int(current.viewY) + " bloqueado=" + locked + " ventana=" + (win != null);
		var list = inSolar ? solarSpots : sectorSpots;
		for( sp in list )
			s += "\n  " + (sp.system != null ? "sistema " + sp.system.id + " " + sp.system.name : "planeta " + sp.planet.id + " " + sp.planet.name + " " + sp.planet.biome + " (" + ExpOffline.biomeName(sp.planet.biome) + ") tam=" + sp.planet.size) + " en " + Std.int(sp.e.x) + "," + Std.int(sp.e.y);
		return s;
	}

	/** solo pruebas: hoja con los primeros fotogramas de la nave */
	public function devDumpShip( path : String ) {
		if( shipFrames == null ) return;
		var n = 8, w = shipFrames[0].width;
		var sheet = new flash.display.BitmapData(w * n, w, true, 0xFF404060);
		for( i in 0...n ) sheet.copyPixels(shipFrames[i * 4], shipFrames[i * 4].rect, new flash.geom.Point(i * w, 0), null, null, true);
		sys.io.File.saveBytes(path, BmpPng.encode(sheet));
	}

	public function dispose() {
		tw.clear();
		ExpPart.clearAll();
		disposeView(common);
		disposeView(sector);
		disposeView(solar);
		disposeView(solarStars);
		remove();
	}
}
