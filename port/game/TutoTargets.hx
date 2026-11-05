import Common;
import Tutorial.TutoTarget;

/** Lo que el tutorial marca con el aura y la flecha en cada paso (Tutorial, TutoGuide), y los bloques que puso en el planeta. */
class TutoTargets {

	/** celdas marcadas con el aura (la flecha apunta a la primera); coordenadas del mundo de la partida */
	public static function of( g : GameView ) : Array<TutoTarget> {
		if( g == null || !Tutorial.active(g.info) || g.info.mothership == true ) return [];
		var s = g.info.tuto.step;
		if( g.hangar != null ) {
			if( s == Tutorial.LEAVE ) return g.hangar.spawnCell == null ? [] : [g.hangar.spawnCell];
			return [for( c in TutoSetup.hangarCells() ) if( !isHull(g.world.block(c.x, c.y, c.z)) ) c];
		}
		var ship = g.ship;
		var inShip = g.pz >= World.SHIP_Z;
		return switch( s ) {
			case Tutorial.EXIT, Tutorial.SPACE: [{ x : ship.x, y : ship.y, z : Std.int(ship.start.z) - 1 }];
			case Tutorial.CITRONOX: nearest(g, BYellowCrystalLight);
			case Tutorial.ETHERIUM: nearest(g, BBlueCrystalLight);
			case Tutorial.BAUXITE: nearest(g, BMinAluminium);
			case Tutorial.ALU, Tutorial.PLATES if( inShip ): craftTarget(g);
			case Tutorial.COMPUTER, Tutorial.DATABASE if( inShip ): computerCell(g);
			case Tutorial.HULL: [];
			// la base del rayo de luz
			default: inShip ? [] : [{ x : ship.x, y : ship.y, z : Std.int(ship.z) }];
		}
	}

	/** zona del sintetizador vacia: la zona; con algo puesto: el ordenador del sintetizador */
	static function craftTarget( g : GameView ) : Array<TutoTarget> {
		var c = g.ship.crafts[0];
		var dx = g.world.shipDX, dy = g.world.shipDY;
		if( c.curCraft != null && c.out != null ) return [{ x : c.out.x + dx, y : c.out.y + dy, z : c.out.z + World.SHIP_Z }];
		return [{ x : c.x + dx, y : c.y + dy, z : c.z + World.SHIP_Z }];
	}

	static function computerCell( g : GameView ) : Array<TutoTarget> {
		for( c in ShipData.load(Hangar.currentShip(g.info)).cells )
			if( c.id == Type.enumIndex(BShipComputer) ) return [{ x : c.x + g.world.shipDX, y : c.y + g.world.shipDY, z : c.z + World.SHIP_Z }];
		return [];
	}

	public static inline function isHull( b : Block ) return b != null && b.k == BShipHull;

	/** bloques de ese tipo puestos por el tutorial en el planeta (TutoSetup.seedPlanet) */
	public static function spots( g : GameView, k : BlockKind ) : Array<TutoTarget> {
		var a = g.info.tuto.spots, out = [];
		if( a == null ) return out;
		var i = 0;
		while( i + 3 < a.length ) {
			if( a[i + 3] == Type.enumIndex(k) ) out.push({ x : a[i], y : a[i + 1], z : a[i + 2] });
			i += 4;
		}
		return out;
	}

	/** el que queda mas cerca del jugador */
	static function nearest( g : GameView, k : BlockKind ) : Array<TutoTarget> {
		var best = null, bd = 1e9;
		for( s in spots(g, k) ) {
			var b = g.world.block(s.x, s.y, s.z);
			if( b == null || b.k != k ) continue;
			var dx = g.wrapDist(s.x + 0.5 - g.px), dy = g.wrapDist(s.y + 0.5 - g.py);
			var d = dx * dx + dy * dy;
			if( d < bd ) {
				bd = d;
				best = s;
			}
		}
		return best == null ? [] : [best];
	}
}
