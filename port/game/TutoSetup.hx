import Common;
import SaveData.SaveInfo;

/**
 * Partida nueva de aventura y preparacion del tutorial (anadido del port; el original empezaba en el espacio, sin tutorial):
 * - newGame: la partida empieza en el espacio, en el sistema 0, con el inventario vacio (SaveData.create en aventura). Con tutorial, el planeta 0 del
 *   sistema es Terres Rouges pequeno; sin el, el sistema es el aleatorio de ExpOffline y la ESCorp envia las cargas y los
 *   creditos (con el, llegan al acabar: hasta entonces no hay creditos).
 * - la nave del tutorial tiene dos agujeros en el techo, encima de las losas del sintetizador (HOLES). Se quitan con shipEdits
 *   y no en el plano: la zona del sintetizador se mide en el plano y llegaria hasta el agujero (se taparia desde dentro).
 * - seedPlanet: al primer aterrizaje se ponen cerca de la nave los citronox viejos, el etherium y la bauxita del tutorial.
 * - skip: la partida queda como sin tutorial (planeta y nave de serie, inventario vacio mas el envio de la ESCorp).
 */
class TutoSetup {

	/** planeta del tutorial: el 0 del sistema 0 */
	public static inline var PLANET = 0;
	/** agujeros del casco (x, y, z en el plano de la nave de serie): el techo encima de las losas del sintetizador */
	public static var HOLES = [[4, 7, 4], [5, 7, 4]];
	/** cargas azules y amarillas que envia la ESCorp al acabar o pasar el tutorial */
	public static inline var GIFT = 30;

	public static function newGame( name : String, seed : Int, tutorial : Bool ) : SaveInfo {
		var start = tutorial ? { seed : seed, biome : "BIAutumn", size : 1 } : null;
		var p = ExpData.ExpOffline.make(seed, start).systems[0].planets[PLANET];
		var info = SaveData.create(name, p.seed, p.biome, p.size);
		info.tutorial = tutorial;
		info.uni = { seed : seed, planetId : PLANET, pos : [1, 0], start : { seed : p.seed, biome : p.biome, size : p.size }, planets : [], space : true };
		info.credits = 0;
		if( tutorial ) {
			info.tuto = { step : 0 };
			info.shipEdits = holeEdits();
		} else
			grant(info);
		return info;
	}

	/** el envio de la ESCorp: las cargas y los creditos de salida */
	public static function grant( info : SaveInfo ) {
		var i = new Inv(info.inv);
		i.addCharge(CBlue, GIFT);
		i.addCharge(CYellow, GIFT);
		info.credits = (info.credits == null ? 0 : info.credits) + Market.START_CREDITS;
	}

	/** la partida como si se hubiera empezado sin tutorial: se vuelve al espacio, junto al planeta del tutorial */
	public static function skip( info : SaveInfo ) {
		var uni = info.uni;
		info.tuto = null;
		info.inv = Inv.empty();
		info.credits = 0;
		grant(info);
		info.shipData = null;
		info.shipEdits = [];
		info.edits = [];
		uni.planets = uni.planets.filter(function(p) return p.id != PLANET);
		if( info.chests != null ) info.chests = info.chests.filter(function(c) return !StringTools.startsWith(c.key, "p" + PLANET + ":"));
		uni.planetId = PLANET;
		uni.pos = [1, 0];
		uni.space = true;
		uni.ship = null;
		info.seed = uni.start.seed;
		info.biome = uni.start.biome;
		info.sizeChunks = uni.start.size;
		info.px = info.py = info.pz = -1;
		info.life = 100;
	}

	// ---------------------------------------------------------------- agujeros de la nave

	/** shipEdits que quitan los bloques de HOLES (claves de World.setBlock en el volumen de la nave, bloque 0 = aire) */
	public static function holeEdits() : Array<Int> {
		var out = [];
		for( c in shipCells() ) {
			out.push(((c.x + c.y * Const.SIZE) << World.ZBITS) | c.z);
			out.push(0);
		}
		return out;
	}

	/** celdas de HOLES en el volumen de la nave (ShipData.load: centrada, 1 de margen abajo) */
	public static function shipCells() : Array<{ x : Int, y : Int, z : Int }> {
		var d = ShipData.load(Const.DEFAULT_SHIP);
		var dx = (Const.SIZE - d.sx) >> 1, dy = (Const.SIZE - d.sy) >> 1;
		return [for( h in HOLES ) { x : h[0] + dx, y : h[1] + dy, z : h[2] + 1 }];
	}

	/** hangar durante el tutorial: la nave con sus agujeros (el hangar se hace con el plano, sin los shipEdits) */
	public static function holed( info : SaveInfo, d : ShipData.ShipDataInfo ) : ShipData.ShipDataInfo {
		if( info.tuto == null || info.shipData != null ) return d;
		var holes = hangarCells();
		d.cells = d.cells.filter(function(c) return !Lambda.exists(holes, function(h) return h.x == c.x && h.y == c.y && h.z == c.z));
		return d;
	}

	/** celdas de HOLES en el hangar */
	public static function hangarCells() : Array<{ x : Int, y : Int, z : Int }> {
		var d = ShipData.load(Const.DEFAULT_SHIP);
		return [for( h in HOLES ) Hangar.shipCell(h[0], h[1], h[2], d.sx, d.sy)];
	}

	// ---------------------------------------------------------------- bloques del tutorial en el planeta

	/**
	 * Al primer aterrizaje: 4 citronox viejos a 9-15 bloques de la nave, fragmentos de etherium en un hueco de un risco (o de un
	 * penasco) a 14-31 y un filon de bauxita del generador a unos 28 (TutoTerrain). Se ponen con setBlock (son cambios del
	 * planeta: pasar el tutorial los quita) y los que hay que recoger se guardan en tuto.spots para seguirlos.
	 */
	public static function seedPlanet( g : GameView ) {
		var t = g.info.tuto;
		if( t == null || t.spots != null || g.ship == null ) return;
		var w = g.world, sx = g.ship.x, sy = g.ship.y, gz = Std.int(g.ship.z) - 1;
		var spots = [];
		function put( x : Int, y : Int, z : Int, k : BlockKind ) {
			x = TutoTerrain.wrap(w, x);
			y = TutoTerrain.wrap(w, y);
			w.setBlock(x, y, z, Block.get(k));
			for( v in [x, y, z, Type.enumIndex(k)] ) spots.push(v);
		}
		for( i in 0...4 ) {
			var s = TutoTerrain.ground(w, sx, sy, gz, i * Math.PI / 2 + 0.4, 9 + i * 2);
			put(s.x, s.y, s.z + 1, BYellowCrystalLight);
		}
		TutoTerrain.etheriumCave(w, sx, sy, gz, put);
		TutoTerrain.bauxiteVein(w, sx, sy, gz, put);
		t.spots = spots;
	}
}
