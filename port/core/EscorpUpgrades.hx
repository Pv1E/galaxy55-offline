import Common;
import SaveData.SaveInfo;

/** como se compra una mejora de la ESCorp */
enum abstract UpgradeKind(Int) {
	/** una vez por partida */
	var KOnce = 0;
	/** por niveles: cada compra sube uno; el precio depende del nivel que se compra, con o sin tope */
	var KLevels = 1;
	/** una vez, y despues se enciende y se apaga gratis y sin confirmacion; al comprarla queda encendida */
	var KSwitch = 2;
	/** cada compra suma uno a una reserva que se gasta, sin tope */
	var KCounter = 3;
}

/** lo que se hace con una mejora (en multijugador va en CEcon EUpgrade: a = su id, n = la accion) */
enum abstract UpgradeAction(Int) from Int to Int {
	var UBuy = 0;
	/** encender un interruptor ya comprado */
	var UOn = 1;
	/** apagarlo */
	var UOff = 2;
}

/**
 * Una mejora de la ESCorp. Su nombre en la pantalla es la clave de Lang "upgrade.<id>" y su descripcion "upgrade.<id>.desc".
 * Precio del nivel n (1 = el primero; el unico en las demas): cost, o cost * n con rising.
 */
typedef EscorpUpgrade = {
	var id : String;
	var kind : UpgradeKind;
	var cost : Int;
	/** niveles: el nivel n cuesta cost * n (200, 400, 600...) */
	@:optional var rising : Bool;
	/** niveles: cuantos como mucho (null = sin tope) */
	@:optional var max : Null<Int>;
}

/**
 * Donde se mira una mejora: el modo de juego en el que esta el jugador (en creativo no se pierde el equipo) y si es
 * gestionnaire del servidor (multijugador: licencias sin limite)
 */
typedef UpgradeCtx = { creative : Bool, manager : Bool };

/**
 * Mejoras de la ESCorp (anadido del port): se compran desde el ordenador de a bordo (Contactar con la ESCorp, Mejoras ESCorp;
 * pantalla GalaxyApp.buildUpgrades) a cambio de hexalita, la carga verde (CBonus) que no sirve para el laser. Cuatro clases
 * (UpgradeKind): por niveles, interruptores, contadores y de una vez. Las reglas estan aqui, en el core, para que el servidor
 * (ServerEcon, sobre Session.record) las repita igual que el juego: el cliente hace la operacion en su copia y manda CEcon
 * EUpgrade con el id y la accion (UpgradeAction).
 * En la partida (campos opcionales: las partidas de antes no tienen ninguno y se leen con todo a 0):
 *   - upgrades: las de una vez y los interruptores comprados (sus id)
 *   - upgradeLevels: el nivel de cada mejora por niveles (id -> nivel; sin el id, 0)
 *   - upgradesOff: los interruptores comprados que estan apagados (sin el id, encendido)
 * Se paga con la hexalita del inventario, descontada de una vez (los precios llegan a varios miles).
 */
class EscorpUpgrades {

	/** verde de la hexalita (KubDraw.chargeColor) */
	public static inline var COLOR = 0x7CE85A;

	/** todas las mejoras, en el orden de la pantalla */
	public static var ALL : Array<EscorpUpgrade> = [];

	public static function get( id : String ) : EscorpUpgrade {
		for( u in ALL ) if( u.id == id ) return u;
		return null;
	}

	/** las mejoras se abren fuera del tutorial (en el tutorial el boton se ve, desactivado: Tutorial.upgradesAllowed) */
	public static inline function open( info : SaveInfo ) return info != null && info.tuto == null;

	// ---------------------------------------------------------------- hexalita

	/** hexalita del inventario (la carga CBonus) */
	public static function hexalite( inv : Inv ) : Int {
		var k = Type.enumIndex(CBonus);
		for( c in inv.inv.charges ) if( c.c == k ) return c.n;
		return 0;
	}

	/** quita n de hexalita de una vez (no carga a carga: los precios llegan a varios miles); quien llama mira que las haya */
	static function pay( inv : Inv, n : Int ) {
		var k = Type.enumIndex(CBonus), cs = inv.inv.charges;
		for( c in cs.copy() )
			if( c.c == k ) {
				c.n -= n;
				// como Inventory.useCharge: el contador a 0 sale de la lista
				if( c.n <= 0 ) cs.remove(c);
			}
		inv.display();
	}

	// ---------------------------------------------------------------- estado

	/** comprada (de una vez o interruptor) */
	public static function has( info : SaveInfo, id : String ) : Bool return info.upgrades != null && info.upgrades.indexOf(id) >= 0;

	/** interruptor comprado y encendido */
	public static function isOn( info : SaveInfo, id : String ) : Bool {
		return has(info, id) && (info.upgradesOff == null || info.upgradesOff.indexOf(id) < 0);
	}

	/** nivel de una mejora por niveles; la reserva de un contador (0 sin comprar) */
	public static function level( info : SaveInfo, id : String ) : Int {
		if( info.upgradeLevels == null ) return 0;
		var n = info.upgradeLevels.get(id);
		return n == null || n < 0 ? 0 : n;
	}

	static function setLevel( info : SaveInfo, id : String, n : Int ) {
		if( info.upgradeLevels == null ) info.upgradeLevels = new haxe.DynamicAccess<Int>();
		info.upgradeLevels.set(id, n);
	}

	// ---------------------------------------------------------------- compra

	/** se ve en esta partida: las que no pueden servir no salen en la pantalla y el servidor no las vende */
	public static function shown( info : SaveInfo, u : EscorpUpgrade, ctx : UpgradeCtx ) : Bool {
		return u != null;
	}

	/**
	 * Por que no se puede comprar aunque haya hexalita (clave de Lang, la pantalla la pone en lugar de la descripcion), o null.
	 */
	public static function blocked( info : SaveInfo, u : EscorpUpgrade ) : String {
		return null;
	}

	/** precio de la siguiente compra; -1 = no queda nada que comprar (tope de niveles, ya comprada) */
	public static function price( info : SaveInfo, u : EscorpUpgrade ) : Int {
		return switch( u.kind ) {
		case KOnce, KSwitch: has(info, u.id) ? -1 : u.cost;
		case KCounter: u.cost;
		case KLevels:
			var next = level(info, u.id) + 1;
			u.max != null && next > u.max ? -1 : (u.rising == true ? u.cost * next : u.cost);
		}
	}

	/** se puede comprar ahora: fuera del tutorial, se ve, no esta bloqueada, queda algo que comprar y llega la hexalita */
	public static function canBuy( info : SaveInfo, inv : Inv, u : EscorpUpgrade, ctx : UpgradeCtx ) : Bool {
		var p = price(info, u);
		return open(info) && shown(info, u, ctx) && blocked(info, u) == null && p >= 0 && hexalite(inv) >= p;
	}

	/** la compra: se paga y queda en la partida (un interruptor, encendido). false si no se podia (nada cambia) */
	public static function buy( info : SaveInfo, inv : Inv, u : EscorpUpgrade, ctx : UpgradeCtx ) : Bool {
		if( !canBuy(info, inv, u, ctx) ) return false;
		pay(inv, price(info, u));
		switch( u.kind ) {
		case KOnce, KSwitch:
			if( info.upgrades == null ) info.upgrades = [];
			info.upgrades.push(u.id);
			if( info.upgradesOff != null ) info.upgradesOff.remove(u.id);
		case KLevels, KCounter:
			setLevel(info, u.id, level(info, u.id) + 1);
		}
		return true;
	}

	/** encender o apagar un interruptor comprado (gratis). false si no lo es o ya estaba asi */
	public static function setOn( info : SaveInfo, u : EscorpUpgrade, on : Bool, ctx : UpgradeCtx ) : Bool {
		if( u.kind != KSwitch || !open(info) || !has(info, u.id) || !shown(info, u, ctx) || isOn(info, u.id) == on ) return false;
		if( on ) info.upgradesOff.remove(u.id);
		else {
			if( info.upgradesOff == null ) info.upgradesOff = [];
			info.upgradesOff.push(u.id);
		}
		return true;
	}

	/** la accion `action` sobre la mejora id (la pantalla y ServerEcon): false si no vale */
	public static function apply( info : SaveInfo, inv : Inv, id : String, action : UpgradeAction, ctx : UpgradeCtx ) : Bool {
		var u = get(id);
		if( u == null ) return false;
		return switch( action ) {
		case UBuy: buy(info, inv, u, ctx);
		case UOn: setOn(info, u, true, ctx);
		case UOff: setOn(info, u, false, ctx);
		default: false;
		}
	}

	// ---------------------------------------------------------------- multijugador

	/** lo que el servidor manda tras una mejora (SPatch "escorp") */
	public static function state( info : SaveInfo ) : Dynamic {
		return { upgrades : info.upgrades, levels : info.upgradeLevels, off : info.upgradesOff };
	}

	/** SPatch "escorp": la partida queda como la tiene el servidor */
	public static function applyState( info : SaveInfo, v : Dynamic ) {
		if( v == null ) return;
		info.upgrades = v.upgrades;
		info.upgradeLevels = v.levels;
		info.upgradesOff = v.off;
	}
}
