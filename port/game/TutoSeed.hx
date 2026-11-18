import Common;
import SaveData.SaveInfo;

/**
 * Lo de TutoSetup que necesita el juego en marcha (hangar y planeta del tutorial). Separado de TutoSetup (port/core) para el
 * multijugador (anadido del port).
 */
class TutoSeed {

	/** celdas de TutoSetup.HOLES en el hangar */
	public static function hangarCells() : Array<{ x : Int, y : Int, z : Int }> {
		var d = ShipData.load(Const.DEFAULT_SHIP);
		return [for( h in TutoSetup.HOLES ) Hangar.shipCell(h[0], h[1], h[2], d.sx, d.sy)];
	}

	// ---------------------------------------------------------------- bloques del tutorial en el planeta

	/**
	 * Al primer aterrizaje: 4 citronox viejos a 9-15 bloques de la nave, fragmentos de etherium en un hueco de un risco (o de un
	 * penasco) a 14-31 y un filon de bauxita del generador a unos 28 (TutoTerrain). Se ponen con setBlock (son cambios del
	 * planeta: pasar el tutorial los quita) y los que hay que recoger se guardan en tuto.spots para seguirlos.
	 */
	public static function seedPlanet( g : GameView ) {
		// multijugador: lo pone el servidor (ServerWorlds.seedTutorial) y manda tuto.spots
		if( g.info.tuto == null || g.info.tuto.spots != null || g.ship == null || g.net != null ) return;
		TutoSetup.seedPlanet(g.world, g.info, g.ship.x, g.ship.y, Std.int(g.ship.z) - 1);
	}

	/** hangar durante el tutorial: la nave con sus agujeros (el hangar se hace con el plano, sin los shipEdits) */
	public static function holed( info : SaveInfo, d : ShipData.ShipDataInfo ) : ShipData.ShipDataInfo {
		if( info.tuto == null || info.shipData != null ) return d;
		var holes = hangarCells();
		d.cells = d.cells.filter(function(c) return !Lambda.exists(holes, function(h) return h.x == c.x && h.y == c.y && h.z == c.z));
		return d;
	}
}
