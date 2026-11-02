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

/** Cantidad pedida de un bloque, cargas que cuesta conseguir cada uno (amarillas, azules) y recompensa fija (null = calculada). */
typedef ContractSpec = {
	var k : BlockKind;
	var n : Int;
	var y : Int;
	var b : Int;
	var reward : Null<Int>;
}

/** contracts.json ya leido */
typedef ContractsConfig = {
	var period : Int;
	var count : Int;
	var rewardFactor : Float;
	var yellowBonus : Int;
	var blueBonus : Int;
	var base : Array<ContractSpec>;
	var orders : Array<ContractSpec>;
}

/**
 * Contratos de la ESCorp: entregar bloques a cambio de creditos. Del original solo queda la lista de los contratos de base
 * (Data.BASIC_BLOCKS en com/Common.hx: "blocs that can be considered as trivial to find, serves for base escorp contracts");
 * lo demas lo hacia el servidor (pagina /trade/contracts, nunca publicada).
 * Anadido del port: los encargos, las cantidades, las recompensas y el cambio de tablero. Todo eso esta en contracts.json
 * (junto a los graficos, ver Res), que se edita sin recompilar; su lista "base" es la de Data.BASIC_BLOCKS.
 * - Un contrato de base y count - 1 encargos, sin repetir bloque.
 * - El tablero cambia cada `period` segundos de hora real UTC y sale de un sorteo con el numero del periodo como semilla:
 *   todos los jugadores con el mismo contracts.json tienen el mismo tablero a la vez.
 * - Recompensa (si el archivo no la fija): rewardFactor veces lo que el robot paga como mucho por esos bloques (Market), mas
 *   yellowBonus creditos por carga amarilla y blueBonus por carga azul que cuesta conseguirlos.
 * - Se entrega la cantidad entera de una vez; lo entregado queda marcado hasta el cambio de tablero.
 */
class Contracts {

	/** solo pruebas (Dev "contracts slot N"): periodo impuesto */
	public static var devSlot : Null<Int>;

	public static var config(get, null) : ContractsConfig;

	static function get_config() {
		if( config == null ) config = load(Res.path("contracts.json"));
		return config;
	}

	/** lee el archivo; lo que no vale se avisa por stderr y se salta (sin archivo no hay contratos) */
	public static function load( path : String ) : ContractsConfig {
		var o : Dynamic = try haxe.Json.parse(sys.io.File.getContent(path)) catch( e : Dynamic ) {
			warn(path + ": " + e);
			{};
		};
		inline function num( v : Dynamic, def : Float ) : Float return v == null ? def : (v : Float);
		return {
			period : Std.int(Math.max(60, num(o.period, 1800))),
			count : Std.int(num(o.count, 3)),
			rewardFactor : num(o.rewardFactor, 1.5),
			yellowBonus : Std.int(num(o.yellowBonus, 0)),
			blueBonus : Std.int(num(o.blueBonus, 0)),
			base : specs(o.base, "base"),
			orders : specs(o.orders, "orders"),
		};
	}

	static function specs( a : Dynamic, list : String ) : Array<ContractSpec> {
		var out : Array<ContractSpec> = [];
		if( a == null ) return out;
		for( e in (a : Array<Dynamic>) ) {
			var k : BlockKind = try Type.createEnum(BlockKind, e.block) catch( _ : Dynamic ) null;
			var n = e.n == null ? 0 : Std.int(e.n);
			var reward : Null<Int> = e.reward == null ? null : Std.int(e.reward);
			if( k == null || n <= 0 ) {
				warn(list + ": " + e.block + " no vale (bloque desconocido o cantidad <= 0)");
				continue;
			}
			if( reward == null && Market.wareOfBlock(Block.get(k)) == null ) {
				warn(list + ": " + e.block + " no tiene precio en Market: hace falta reward");
				continue;
			}
			out.push({ k : k, n : n, y : e.yellow == null ? 0 : Std.int(e.yellow), b : e.blue == null ? 0 : Std.int(e.blue), reward : reward });
		}
		return out;
	}

	static function warn( msg : String ) Sys.stderr().writeString("contracts.json: " + msg + "\n");

	/** periodo actual (hora real UTC) */
	public static function slot() : Int return devSlot != null ? devSlot : Math.floor(Sys.time() / config.period);

	/** segundos que faltan para el siguiente tablero */
	public static function remaining() : Float {
		var now = Sys.time(), p = config.period;
		return (Math.ffloor(now / p) + 1) * p - now;
	}

	/** el tablero de un periodo: el mismo para todos */
	public static function board( slot : Int ) : Array<Contract> {
		var c = config;
		var r = new mt.Rand(Const.quickHash(slot, 55, 0));
		for( i in 0...3 ) r.random(2);
		var list = [];
		if( c.base.length > 0 ) list.push(make(c.base[r.random(c.base.length)]));
		var orders = [for( s in c.orders ) if( list.length == 0 || s.k != list[0].block.k ) s];
		while( list.length < c.count && orders.length > 0 )
			list.push(make(orders.splice(r.random(orders.length), 1)[0]));
		return list;
	}

	static function make( s : ContractSpec ) : Contract {
		var b = Block.get(s.k);
		var reward = s.reward;
		if( reward == null ) {
			var c = config;
			var best = Std.int(Market.wareOfBlock(b).base * 0.5);
			reward = Std.int(s.n * best * c.rewardFactor) + s.n * (s.y * c.yellowBonus + s.b * c.blueBonus);
		}
		return { block : b, n : s.n, reward : reward };
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
