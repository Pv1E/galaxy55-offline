import Common;
import SaveData.SaveInfo;

typedef TutoTarget = { x : Int, y : Int, z : Int };

/**
 * Tutorial de la partida de aventura (anadido del port). La nave tiene el casco agujereado (TutoSetup.HOLES):
 * SPACE    aterrizar de urgencia en el planeta 0 (los demas planetas y la salida del sistema estan cerrados: Space)
 * EXIT     bajar al planeta por el teletransportador
 * HULL     explicacion: hace falta bauxita y, para minarla, cargas
 * CITRONOX 3 citronox viejos (cargas amarillas)   ETHERIUM 2 fragmentos de etherium (cargas azules)
 * BAUXITE  minar 2 bauxitas                        RETURN   volver a la nave por el rayo
 * ALU      bauxita -> aluminio en el sintetizador  PLATES   aluminio -> blindaje
 * COMPUTER ordenador de a bordo, Modificar la nave HANGAR   tapar los agujeros (solo ahi y solo blindaje)
 * LEAVE    salir del hangar con la nave estanca    DONE     la ESCorp envia cargas y creditos y se acaba
 * Mientras dura no se despega (GalaxyApp.buildComputer). El paso se guarda en SaveInfo.tuto.
 */
class Tutorial {

	public static inline var SPACE = 0;
	public static inline var EXIT = 1;
	public static inline var HULL = 2;
	public static inline var CITRONOX = 3;
	public static inline var ETHERIUM = 4;
	public static inline var BAUXITE = 5;
	public static inline var RETURN = 6;
	public static inline var ALU = 7;
	public static inline var PLATES = 8;
	public static inline var COMPUTER = 9;
	public static inline var HANGAR = 10;
	public static inline var LEAVE = 11;
	public static inline var DONE = 12;

	static inline var NEED_CITRONOX = 3;
	static inline var NEED_ETHERIUM = 2;
	/** segundos de la explicacion de HULL y de la felicitacion final */
	static inline var HULL_TIME = 9.;
	static inline var DONE_TIME = 16.;

	var hullTime = 0.;
	var doneTime = 0.;
	/** al acabar (GalaxyApp guarda la partida) */
	public var onDone : Void -> Void;

	public function new() {}

	public static inline function active( info : SaveInfo ) return info != null && info.tuto != null;

	static inline function holes() return TutoSetup.HOLES.length;

	public function update( dt : Float, g : GameView ) {
		if( doneTime > 0 ) doneTime -= dt;
		var t = g.info.tuto;
		if( t == null || g.info.mothership == true ) return;
		if( g.hangar != null ) {
			if( t.step == COMPUTER ) t.step = HANGAR;
			if( t.step == HANGAR && holesFilled(g) && g.hangarValid ) t.step = LEAVE;
			else if( t.step == LEAVE && !holesFilled(g) ) t.step = HANGAR;
			return;
		}
		if( t.spots == null && g.ship != null ) {
			TutoSetup.seedPlanet(g);
			if( t.step == SPACE ) t.step = EXIT;
		}
		switch( t.step ) {
		case EXIT: if( g.pz < World.SHIP_Z ) { t.step = HULL; hullTime = 0; }
		case HULL: if( (hullTime += dt) > HULL_TIME ) t.step = CITRONOX;
		case CITRONOX: if( broken(g, BYellowCrystalLight) >= NEED_CITRONOX ) t.step = ETHERIUM;
		case ETHERIUM: if( broken(g, BBlueCrystalLight) >= NEED_ETHERIUM ) t.step = BAUXITE;
		case BAUXITE: if( count(g, [BMinAluminium, BAluminium, BShipHull]) >= holes() ) t.step = RETURN;
		case RETURN: if( g.pz >= World.SHIP_Z ) t.step = ALU;
		case ALU: if( count(g, [BAluminium, BShipHull]) >= holes() ) t.step = PLATES;
		case PLATES: if( count(g, [BShipHull]) >= holes() ) t.step = COMPUTER;
		// guardada en el hangar: se vuelve a la nave sin el
		case HANGAR, LEAVE: t.step = COMPUTER;
		case DONE: finish(g);
		default:
		}
	}

	function finish( g : GameView ) {
		g.inv.addCharge(CBlue, TutoSetup.GIFT);
		g.inv.addCharge(CYellow, TutoSetup.GIFT);
		g.info.credits = (g.info.credits == null ? 0 : g.info.credits) + Market.START_CREDITS;
		g.info.tuto = null;
		doneTime = DONE_TIME;
		if( onDone != null ) onDone();
	}

	/** al salir del hangar con la nave guardada (valida y cambiada): se acaba en la siguiente actualizacion */
	public static function repaired( info : SaveInfo ) if( active(info) ) info.tuto.step = DONE;

	/** al salir del hangar sin guardar: hay que volver a entrar */
	public static function leftHangar( info : SaveInfo ) {
		if( active(info) && (info.tuto.step == HANGAR || info.tuto.step == LEAVE) ) info.tuto.step = COMPUTER;
	}

	/** reglas del hangar durante el tutorial (GameView.hangarRule): no se rompe nada y solo se pone blindaje en los agujeros */
	public static function hangarRule( info : SaveInfo ) : Bool -> Int -> Int -> Int -> Block -> String {
		if( !active(info) ) return null;
		var cells = TutoSetup.hangarCells();
		return function( place : Bool, x : Int, y : Int, z : Int, b : Block ) : String {
			if( !place ) return TutoText.get("nobreak");
			for( c in cells )
				if( c.x == x && c.y == y && c.z == z ) return b.k == BShipHull ? null : TutoText.get("onlyhull");
			return TutoText.get("onlyholes");
		};
	}

	// ---------------------------------------------------------------- texto y objetivos

	/** texto del objetivo (null = nada que mostrar); g es null en el espacio */
	public function text( info : SaveInfo, g : GameView ) : String {
		if( !active(info) ) return doneTime > 0 ? TutoText.get("done") : null;
		var s = info.tuto.step;
		if( g == null ) return TutoText.get("space");
		if( g.hangar != null ) return s == HANGAR ? TutoText.get("hangar", filled(g), holes()) : TutoText.get(s == LEAVE ? "leave" : "hangarearly");
		return switch( s ) {
			case EXIT, SPACE: TutoText.get("exit");
			case HULL: TutoText.get("hull");
			case CITRONOX: TutoText.get("citronox", broken(g, BYellowCrystalLight), NEED_CITRONOX);
			case ETHERIUM: TutoText.get("etherium", broken(g, BBlueCrystalLight), NEED_ETHERIUM);
			case BAUXITE: TutoText.get("bauxite", count(g, [BMinAluminium, BAluminium, BShipHull]), holes());
			case RETURN: TutoText.get("return");
			case ALU: TutoText.get(g.pz < World.SHIP_Z ? "return" : "alu", count(g, [BAluminium, BShipHull]), holes());
			case PLATES: TutoText.get(g.pz < World.SHIP_Z ? "return" : "plates", count(g, [BShipHull]), holes());
			default: TutoText.get(g.pz < World.SHIP_Z ? "return" : "computer");
		}
	}

	/** celdas marcadas con el aura (la flecha apunta a la primera) */
	public function targets( g : GameView ) return TutoTargets.of(g);

	// ---------------------------------------------------------------- recuentos

	function filled( g : GameView ) return [for( c in TutoSetup.hangarCells() ) if( TutoTargets.isHull(g.world.block(c.x, c.y, c.z)) ) c].length;

	function holesFilled( g : GameView ) return filled(g) >= holes();

	/** bloques de ese tipo puestos por el tutorial que ya no estan (recogidos) */
	static function broken( g : GameView, k : BlockKind ) : Int {
		var n = 0;
		for( s in TutoTargets.spots(g, k) ) {
			var b = g.world.block(s.x, s.y, s.z);
			if( b == null || b.k != k ) n++;
		}
		return n;
	}

	static function count( g : GameView, ks : Array<BlockKind> ) : Int {
		var n = 0;
		for( s in g.inv.inv.t )
			if( s != null )
				for( k in ks )
					if( s.k == Type.enumIndex(k) ) n += s.n;
		return n;
	}
}
