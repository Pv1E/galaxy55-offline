import Common;

/** Estado de una mercancia del comerciante. */
typedef MarketItem = {
	/** clave: "b<indice de bloque>" o "c<indice de carga>" */
	var key : String;
	/** cuanto se le ha comprado ultimamente; COMPARTIDO entre los jugadores del sector (sube el precio de compra, con tope) */
	@:optional var bought : Float;
	/** cuanto le ha vendido ESTE jugador ultimamente; PERSONAL (baja lo que te paga, hasta 0) */
	@:optional var sold : Float;
}

/** Mercado guardado en la partida (todo es serializable a JSON, pensado para que un servidor pueda compartirlo luego). */
typedef MarketInfo = {
	/** segundos de juego del ultimo calculo (para que los precios se recuperen con el tiempo) */
	var time : Float;
	var items : Array<MarketItem>;
}

/** Una mercancia tal como la ve la tienda. */
typedef Ware = {
	var key : String;
	var block : Block;
	/** carga (null = bloque) */
	var charge : Null<ChargeKind>;
	var base : Int;
}

/**
 * Comercio dinamico con el robot comerciante (anadido del port; el original tenia una tienda web con precios fijos).
 * Pensado para que nadie se frustre ni pueda perjudicar a otro jugador:
 * - El robot NUNCA se queda sin nada: siempre se puede comprar.
 * - Comprar cuesta el precio base. Cada REF unidades compradas suben `bought` en 1 y el precio un 50 %, con tope del
 *   doble (MAX_BUY). En multijugador `bought` lo comparte el sector: lo peor que hace otro es encarecer algo un rato.
 * - Vender da la mitad del precio base. Cada REF unidades vendidas suben `sold` en 1 y bajan lo que te paga un 30 %;
 *   llega a 0 (contra el farmeo de cosas comunes) y entonces el robot no lo acepta. `sold` es personal: lo que vendes
 *   tu no baja el precio a los demas.
 * - Vender siempre da menos que comprar, asi que comprar y revender pierde dinero.
 * - Las dos cosas se reducen a la mitad cada HALF_LIFE segundos de juego.
 */
class Market {

	/** creditos de salida: en aventura los envia la ESCorp al acabar el tutorial (TutoSetup.grant, Tutorial.finish) */
	public static inline var START_CREDITS = 200;
	static inline var REF = 20.;
	static inline var HALF_LIFE = 600.;
	static inline var MAX_BUY = 2.;

	/**
	 * Precios propios del port (cambio respecto al original): en los datos casi todo vale 100. Se agrupan por lo comun
	 * que es cada bloque; lo que no aparece aqui conserva su precio de los datos.
	 */
	static var PRICES : Map<String, Int> = {
		var m = new Map();
		inline function set( p : Int, l : String ) for( k in l.split(" ") ) m.set(k, p);
		// suelo y roca: lo que sale al cavar
		set(4, "BSoil BSoilCover BRock BMoonSoil BMoonSoilCover BMoonRock BMoonSand BAcidSoil BAcidRock BWinterSoil BWinterRock BMarsSoil BMarsSoil2 BMarsRock BMarsCraterRock BPlantSoil BPlantRock BAlienRock BMoonBrokenRock BMarsQuickSand");
		set(8, "BHardRock BMarsHardRock BFrozenRock BLavaRock BIce BAcidWater BCoal");
		// plantas
		set(6, "BWood BGreenLeaves BPurpleLeaves BBrownLeaves BPinkLeaves BAcidLeaves BAcidLeaves2 BWinterLeaves BAutumnStraw BVines BCactus BCactusBase BAcidWood BWinterWood BMarsCactus BHighHerb1 BHighHerb2 BHighHerb3 BHighHerb4 BHighHerb5 BHighHerb6 BAcidHerb1 BAcidHerb2 BAcidHerbCeil BCavePlantCeil BMush BBigMushTrunk BBigMushHead BCoral1 BCoral2");
		set(15, "BPinkFlower BCactusFlower BAcidWoodHole BAcidWoodBubble BAcidLeavesBubble BAcidLeaves2Bubble BAcidMush BAcidFruit BAcidTreeSap BLeavesCurtain BChampiLight BFreezerPlant BHealPlant BMoonLight BMoonLightDead BBlackIce");
		// tintes en bruto y minerales
		set(20, "BRaw BRawRed BRawPurple BRawWhite BRawOrange BRawGreen BMarsRockFossil BMarsCactusFossil BCoalHot");
		set(35, "BMinIron BMinAluminium BYellowCrystalDense BBlueCrystalDense BBlackIceLight BBlackLight");
		set(60, "BYellowCrystalLight BBlueCrystalLight BLava");
		// construccion (fabricado)
		set(12, "BWoodPlank BWoodPlate BWoodColumn BWoodWindow BRockWall BRockWallSquare BHardRockColumn BHardRockWall BMoonRockColumn BMoonLightColumn BVineColumn BMarsWall BWinterWall BAcidWall");
		set(25, "BStainEmpty BStainPurple BStainRed BStainWhite BStainOrange BStainGreen BShiningWoodPlank BWoodScrew BGlass");
		set(50, "BIron BAluminium BIronFence BLight BLamp BIronLight BJumper BCascadeSource BFreezer");
		// nave y aparatos
		set(80, "BShipPlate BShipWire BShipTubes BShipGlass2 BShipGlassBlack BShipLight");
		set(150, "BShipHull BShipGlass BShipDoor BCircuit BCamera BHealBox");
		set(400, "BShipEngine BCrafter BMiningGenerator BArtiBomb");
		set(900, "BShipComputer BCrafterComputer BShipEntry BAlienTreasure");
		// cargas
		set(40, "BBlueCharge");
		set(120, "BYellowCharge");
		m;
	};

	public static var wares(get, null) : Array<Ware>;
	static var byKey : Map<String, Ware>;

	static function get_wares() {
		if( wares == null ) {
			wares = [];
			byKey = new Map();
			for( b in Block.all ) {
				if( b.index <= 0 || b.basePrice == null || b.basePrice <= 0 || b.type == BTInvisible ) continue;
				var base = PRICES.exists(Std.string(b.k)) ? PRICES.get(Std.string(b.k)) : b.basePrice;
				var w : Ware = b.charge != null
					? { key : "c" + Type.enumIndex(b.charge), block : b, charge : b.charge, base : base }
					: { key : "b" + b.index, block : b, charge : null, base : base };
				if( byKey.exists(w.key) ) continue;
				wares.push(w);
				byKey.set(w.key, w);
			}
		}
		return wares;
	}

	public static function ware( key : String ) : Ware {
		get_wares();
		return byKey.get(key);
	}

	public static function wareOfBlock( b : Block ) : Ware return ware("b" + b.index);
	public static function wareOfCharge( c : ChargeKind ) : Ware return ware("c" + Type.enumIndex(c));

	public static function create() : MarketInfo {
		return { time : 0, items : [] };
	}

	/** copia aparte (la Market la cambia en su sitio) */
	public static function copy( info : MarketInfo ) : MarketInfo {
		if( info == null ) return null;
		return { time : info.time, items : [for( i in info.items ) { key : i.key, bought : i.bought, sold : i.sold }] };
	}

	public var info(default, null) : MarketInfo;
	var items = new Map<String, MarketItem>();

	public function new( info : MarketInfo ) {
		if( info == null ) info = create();
		this.info = info;
		// partidas antiguas: tenian stock y pressure, se descartan
		info.items = [for( i in info.items ) if( i.bought != null || i.sold != null ) i];
		for( i in info.items ) items.set(i.key, i);
	}

	/** el tiempo de juego avanza: los precios vuelven poco a poco a lo normal */
	public function advance( now : Float ) {
		var dt = now - info.time;
		info.time = now;
		if( dt <= 0 ) return;
		var k = Math.pow(0.5, dt / HALF_LIFE);
		for( it in info.items ) {
			it.bought *= k;
			it.sold *= k;
			if( it.bought < 0.01 ) it.bought = 0;
			if( it.sold < 0.01 ) it.sold = 0;
		}
		info.items = [for( it in info.items ) if( it.bought > 0 || it.sold > 0 ) it];
		items = [for( it in info.items ) it.key => it];
	}

	public function item( w : Ware ) : MarketItem {
		var it = items.get(w.key);
		if( it == null ) {
			it = { key : w.key, bought : 0., sold : 0. };
			items.set(w.key, it);
			info.items.push(it);
		}
		return it;
	}

	/** lo que cuesta comprarle 1 unidad ahora */
	public function buyPrice( w : Ware ) : Int {
		var f = Math.min(MAX_BUY, 1 + 0.5 * item(w).bought);
		return Std.int(Math.max(1, Math.round(w.base * f)));
	}

	/** lo que te paga por 1 unidad ahora (puede ser 0; siempre menos de lo que cuesta comprarla) */
	public function sellPrice( w : Ware ) : Int {
		var f = Math.max(0, 1 - 0.3 * item(w).sold);
		var p = Std.int(Math.floor(w.base * 0.5 * f));
		return Std.int(Math.min(p, buyPrice(w) - 1));
	}

	/** compra `n` unidades (o las que se puedan pagar); devuelve cuantas y lo que costaron */
	public function buy( w : Ware, n : Int, credits : Int ) : { n : Int, cost : Int } {
		var it = item(w);
		var done = 0, cost = 0;
		while( done < n ) {
			var p = buyPrice(w);
			if( cost + p > credits ) break;
			cost += p;
			it.bought += 1 / REF;
			done++;
		}
		return { n : done, cost : cost };
	}

	/** vende hasta `n` unidades (para si ya no paga nada); devuelve cuantas y lo que cobraste */
	public function sell( w : Ware, n : Int ) : { n : Int, gain : Int } {
		var it = item(w);
		var done = 0, gain = 0;
		while( done < n ) {
			var p = sellPrice(w);
			if( p <= 0 ) break;
			gain += p;
			it.sold += 1 / REF;
			done++;
		}
		return { n : done, gain : gain };
	}
}
