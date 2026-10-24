import Common;
import SaveData.SaveInfo;

/** Un contrato: entregar `n` bloques a cambio de `reward` creditos. */
typedef Contract = {
	var block : Block;
	var n : Int;
	var reward : Int;
}

/** Contratos de la partida (SaveInfo.contracts): el periodo y los contratos ya entregados en el (indices del tablero). */
typedef ContractsInfo = {
	var slot : Int;
	var done : Array<Int>;
}

/** Cantidad pedida de un bloque y cargas que cuesta conseguir cada uno (amarillas, azules). */
typedef ContractSpec = {
	var k : BlockKind;
	var n : Int;
	var y : Int;
	var b : Int;
}

/**
 * Contratos de la ESCorp: entregar bloques a cambio de creditos. Del original solo queda la lista de los contratos de base
 * (Data.BASIC_BLOCKS en com/Common.hx: "blocs that can be considered as trivial to find, serves for base escorp contracts");
 * lo demas lo hacia el servidor (pagina /trade/contracts, nunca publicada).
 * Anadido del port: los encargos, las cantidades, las recompensas y el cambio de tablero.
 * - 3 contratos a la vez: 1 de base (BASIC_BLOCKS) y 2 encargos, sin repetir bloque.
 * - El tablero cambia cada PERIOD segundos de hora real UTC (a en punto y a y media) y sale de un sorteo con el numero del
 *   periodo como semilla: todos los jugadores con la misma version tienen el mismo tablero a la vez.
 * - Recompensa: 1,5 veces lo que el robot paga como mucho por esos bloques (Market), mas 2 creditos por carga amarilla y
 *   5 por carga azul que cuesta conseguirlos.
 * - Se entrega la cantidad entera de una vez; lo entregado queda marcado hasta el cambio de tablero.
 */
class Contracts {

	public static inline var PERIOD = 1800;
	public static inline var COUNT = 3;
	static inline var YELLOW_BONUS = 2;
	static inline var BLUE_BONUS = 5;

	/** solo pruebas (Dev "contracts slot N"): periodo impuesto */
	public static var devSlot : Null<Int>;

	/** todo cabe en una casilla del inventario (64 de peso maximo) */
	static var SPECS : Array<ContractSpec> = [
		// contratos de base: los bloques de Data.BASIC_BLOCKS
		spec(BSoil, 64), spec(BWood, 48), spec(BAluminium, 8, 0, 1), spec(BWinterSoil, 64), spec(BMarsSoil, 64),
		// encargos: bloques naturales
		spec(BMoonSoil, 64), spec(BAcidSoil, 64), spec(BMoonSand, 48), spec(BAutumnStraw, 32), spec(BWinterWood, 48),
		spec(BAcidWood, 48), spec(BGreenLeaves, 48), spec(BCactus, 24), spec(BChampiLight, 12), spec(BAcidTreeSap, 12),
		// pirita (carga azul)
		spec(BMinIron, 12, 0, 1),
		// muros de roca: 4 rocas dan 2 muros
		spec(BRockWall, 12, 2), spec(BWinterWall, 12, 2), spec(BMarsWall, 12, 2), spec(BAcidWall, 12, 2), spec(BHardRockWall, 12, 0, 2),
		// otros fabricados
		spec(BWoodPlank, 32), spec(BGlass, 16), spec(BIron, 8, 0, 1), spec(BLamp, 6),
	];

	static function spec( k : BlockKind, n : Int, y = 0, b = 0 ) : ContractSpec return { k : k, n : n, y : y, b : b };

	static function specOf( k : BlockKind ) : ContractSpec {
		for( s in SPECS ) if( s.k == k ) return s;
		throw "contrato sin cantidad: " + k;
	}

	/** periodo actual (hora real UTC) */
	public static function slot() : Int return devSlot != null ? devSlot : Math.floor(Sys.time() / PERIOD);

	/** segundos que faltan para el siguiente tablero */
	public static function remaining() : Float {
		var now = Sys.time();
		return (Math.ffloor(now / PERIOD) + 1) * PERIOD - now;
	}

	/** el tablero de un periodo: el mismo para todos */
	public static function board( slot : Int ) : Array<Contract> {
		var r = new mt.Rand(Const.quickHash(slot, 55, 0));
		for( i in 0...3 ) r.random(2);
		var base = Data.BASIC_BLOCKS[r.random(Data.BASIC_BLOCKS.length)];
		var list = [make(specOf(base))];
		var orders = [for( s in SPECS ) if( Data.BASIC_BLOCKS.indexOf(s.k) < 0 ) s];
		while( list.length < COUNT )
			list.push(make(orders.splice(r.random(orders.length), 1)[0]));
		return list;
	}

	static function make( s : ContractSpec ) : Contract {
		var b = Block.get(s.k);
		var best = Std.int(Market.wareOfBlock(b).base * 0.5);
		return { block : b, n : s.n, reward : Std.int(s.n * best * 1.5) + s.n * (s.y * YELLOW_BONUS + s.b * BLUE_BONUS) };
	}

	/** lo entregado en el periodo actual (se vacia al cambiar de periodo) */
	public static function state( info : SaveInfo ) : ContractsInfo {
		var s = slot();
		if( info.contracts == null || info.contracts.slot != s ) info.contracts = { slot : s, done : [] };
		return info.contracts;
	}

	public static function isDone( info : SaveInfo, i : Int ) : Bool return state(info).done.indexOf(i) >= 0;

	/** cuantos bloques de ese tipo llevas */
	public static function have( inv : Inv, b : Block ) : Int {
		var n = 0;
		for( s in inv.inv.t ) if( s != null && s.k == b.index ) n += s.n;
		return n;
	}

	/** entrega el contrato i del tablero actual: quita los bloques y suma la recompensa */
	public static function deliver( info : SaveInfo, inv : Inv, i : Int ) : Bool {
		var c = board(slot())[i];
		if( c == null || isDone(info, i) || !inv.useBlocks(c.block, c.n) ) return false;
		info.credits = (info.credits == null ? Market.START_CREDITS : info.credits) + c.reward;
		state(info).done.push(i);
		return true;
	}
}
