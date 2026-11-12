import Common;
import SaveData.SaveInfo;

/** Un contrato: entregar `n` bloques a cambio de `reward` creditos. */
typedef Contract = {
	var block : Block;
	var n : Int;
	var reward : Int;
}

/**
 * Contrato en curso (anadido del port): se empezo dando parte de los bloques. Ya no caduca con el tablero: se termina dando
 * el resto o se abandona (los bloques dados se pierden). Guarda una copia del contrato por si cambia contracts.json.
 */
typedef ActiveContract = {
	/** bloque (nombre de BlockKind, que no depende del orden de los bloques) */
	var block : String;
	var n : Int;
	var reward : Int;
	/** bloques ya dados */
	var given : Int;
	/** periodo y linea del tablero de los que salio */
	var slot : Int;
	var index : Int;
}

/** Contratos de la partida (SaveInfo.contracts): el periodo, sus lineas entregadas y abandonadas, y los contratos en curso. */
typedef ContractsInfo = {
	var slot : Int;
	var done : Array<Int>;
	/** lineas del tablero abandonadas en el periodo (las partidas antiguas no lo tienen) */
	@:optional var abandoned : Array<Int>;
	/** contratos en curso, de este periodo o de otros (las partidas antiguas no lo tienen) */
	@:optional var active : Array<ActiveContract>;
}

/** Contrato especial de la partida (SaveInfo.special, anadido del port): bloques ya dados y si ya se cobro. */
typedef SpecialInfo = {
	var given : Int;
	var done : Bool;
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
 * - Con todos los bloques, el contrato se entrega de una vez. Con parte, se dan los que haya y queda en curso (ActiveContract):
 *   ya no caduca: se le dan mas bloques cuando se quiera hasta terminarlo, o se abandona (con confirmacion; los bloques dados
 *   se pierden). La recompensa se cobra entera al dar el ultimo bloque.
 * - Cada contrato en curso ocupa una linea del tablero: se ofrecen tantos contratos nuevos como lineas quedan libres.
 * - Una linea entregada o abandonada queda bloqueada hasta el cambio de tablero.
 * - Aparte del tablero, el contrato especial: una vez por partida y sin plazo (ver mas abajo).
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

	/** el periodo actual: sus lineas entregadas y abandonadas se vacian al cambiar de periodo; los contratos en curso siguen */
	public static function state( info : SaveInfo ) : ContractsInfo {
		var s = slot(), c = info.contracts;
		if( c == null || c.slot != s ) info.contracts = c = { slot : s, done : [], abandoned : [], active : c == null ? null : c.active };
		if( c.abandoned == null ) c.abandoned = [];
		if( c.active == null ) c.active = [];
		return c;
	}

	/** contratos en curso */
	public static function active( info : SaveInfo ) : Array<ActiveContract> return state(info).active;

	public static function isDone( info : SaveInfo, i : Int ) : Bool return state(info).done.indexOf(i) >= 0;

	public static function isAbandoned( info : SaveInfo, i : Int ) : Bool return state(info).abandoned.indexOf(i) >= 0;

	/** la linea i del tablero actual esta en curso */
	public static function isActive( info : SaveInfo, i : Int ) : Bool {
		var st = state(info);
		for( a in st.active ) if( a.slot == st.slot && a.index == i ) return true;
		return false;
	}

	/** lineas del tablero actual que se ofrecen (entregadas y abandonadas incluidas): las que no estan en curso, tantas como
	    lineas dejan libres los contratos en curso */
	public static function offered( info : SaveInfo ) : Array<Int> {
		var st = state(info), b = board(st.slot);
		var free = b.length - st.active.length, out = [];
		for( i in 0...b.length ) if( out.length < free && !isActive(info, i) ) out.push(i);
		return out;
	}

	/** bloque de ese nombre (BlockKind); null si no existe */
	public static function kindOf( name : String ) : BlockKind return try Type.createEnum(BlockKind, name) catch( _ : Dynamic ) null;

	public static function blockOf( a : ActiveContract ) : Block return Block.get(kindOf(a.block));

	/** el contrato en curso como uno del tablero */
	public static function contractOf( a : ActiveContract ) : Contract return { block : blockOf(a), n : a.n, reward : a.reward };

	/** cuantos bloques de ese tipo llevas */
	public static function have( inv : Inv, b : Block ) : Int {
		var n = 0;
		for( s in inv.inv.t ) if( s != null && s.k == b.index ) n += s.n;
		return n;
	}

	/** bloques que se darian ahora a la linea i del tablero actual (0 = no se puede: no se ofrece, entregada, abandonada o sin bloques) */
	public static function canDeliver( info : SaveInfo, inv : Inv, i : Int ) : Int {
		var c = board(slot())[i];
		if( c == null || isDone(info, i) || isAbandoned(info, i) || offered(info).indexOf(i) < 0 ) return 0;
		return Std.int(Math.min(have(inv, c.block), c.n));
	}

	/** bloques que se darian ahora al contrato en curso a */
	public static function canGive( inv : Inv, a : ActiveContract ) : Int return Std.int(Math.min(have(inv, blockOf(a)), a.n - a.given));

	/** da lo que llevas a la linea i del tablero actual: con todos los bloques se entrega y se cobra; con parte queda en curso */
	public static function deliver( info : SaveInfo, inv : Inv, i : Int ) : Bool {
		var st = state(info), c = board(st.slot)[i], n = canDeliver(info, inv, i);
		if( n <= 0 || !inv.useBlocks(c.block, n) ) return false;
		if( n >= c.n ) {
			pay(info, c.reward);
			st.done.push(i);
		} else
			st.active.push({ block : Type.enumConstructor(c.block.k), n : c.n, reward : c.reward, given : n, slot : st.slot, index : i });
		return true;
	}

	/** da lo que llevas (hasta lo que falta) al contrato en curso a; con el ultimo bloque se cobra y sale de los contratos en
	    curso (su linea queda entregada si el tablero sigue siendo el suyo) */
	public static function give( info : SaveInfo, inv : Inv, a : ActiveContract ) : Bool {
		var st = state(info), n = st.active.indexOf(a) < 0 ? 0 : canGive(inv, a);
		if( n <= 0 || !inv.useBlocks(blockOf(a), n) ) return false;
		a.given += n;
		if( a.given >= a.n ) {
			pay(info, a.reward);
			st.active.remove(a);
			if( a.slot == st.slot ) st.done.push(a.index);
		}
		return true;
	}

	/** abandona el contrato en curso a: los bloques dados se pierden y no se cobra nada; su linea queda bloqueada si el tablero
	    sigue siendo el suyo */
	public static function abandon( info : SaveInfo, a : ActiveContract ) : Bool {
		var st = state(info);
		if( !st.active.remove(a) ) return false;
		if( a.slot == st.slot ) st.abandoned.push(a.index);
		return true;
	}

	static function pay( info : SaveInfo, n : Int ) {
		info.credits = (info.credits == null ? Market.START_CREDITS : info.credits) + n;
	}

	// ---------------------------------------------------------------- contrato especial

	/*
	 * Contrato especial (anadido del port): SPECIAL_N bloques de tierra roja a cambio de un Conteneur ESCorp, sin creditos. Va
	 * aparte del tablero: no cambia con el periodo, no caduca y se cumple una sola vez por partida (SaveInfo.special). Se le dan
	 * bloques poco a poco, como a un contrato en curso, pero no se abandona. Sale en aventura y en creativo; en el tutorial,
	 * desde su paso (Tutorial.contractsAllowed). Con el ultimo bloque, si el conteneur no cabe en el inventario no se da nada.
	 */

	public static inline var SPECIAL_N = 16;
	/** se ha cobrado el contrato especial (GalaxyApp: aviso arriba a la derecha, specialNews) */
	public static var onSpecial : Void -> Void;

	public static function specialBlock() : Block return Block.get(BSoil);

	public static function specialReward() : Block return Block.get(BChest);

	public static function specialGiven( info : SaveInfo ) : Int return info.special == null ? 0 : info.special.given;

	public static function specialDone( info : SaveInfo ) : Bool return info.special != null && info.special.done;

	/** bloques que se darian ahora al contrato especial (0 = cumplido o sin tierra roja) */
	public static function canGiveSpecial( info : SaveInfo, inv : Inv ) : Int {
		if( specialDone(info) ) return 0;
		return Std.int(Math.min(have(inv, specialBlock()), SPECIAL_N - specialGiven(info)));
	}

	/** el conteneur cabe en el inventario despues de dar n bloques de tierra (se prueba en una copia) */
	public static function specialRoom( inv : Inv, n : Int ) : Bool {
		var t = new Inventory(Inv.copy(inv.inv));
		return t.useBlocks(specialBlock(), n) && t.canAddBlock(specialReward());
	}

	/** da lo que llevas (hasta lo que falta) al contrato especial; con el ultimo bloque se cobra el conteneur */
	public static function giveSpecial( info : SaveInfo, inv : Inv ) : Bool {
		var n = canGiveSpecial(info, inv);
		if( n <= 0 ) return false;
		var last = specialGiven(info) + n >= SPECIAL_N;
		if( last && !specialRoom(inv, n) ) return false;
		if( !inv.useBlocks(specialBlock(), n) ) return false;
		if( info.special == null ) info.special = { given : 0, done : false };
		info.special.given += n;
		if( last ) {
			info.special.done = true;
			inv.addBlock(specialReward());
			if( onSpecial != null ) onSpecial();
		}
		return true;
	}

	/** aviso del conteneur cobrado: para que sirve y como se fabrica */
	public static function specialNews() : KubNotify.KubNews {
		return { title : Lang.t("contracts.special.got"), name : specialReward().getName(), block : specialReward(), text : Lang.t("contracts.special.info"), time : 12 };
	}
}
