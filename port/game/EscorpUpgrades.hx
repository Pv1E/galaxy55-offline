import Common;
import SaveData.SaveInfo;

/**
 * Una mejora de la ESCorp: se desbloquea una vez por partida pagando `cost` cargas de bonus. Su nombre en la pantalla es la
 * clave de Lang "upgrade.<id>"; lo que hace lo mira el juego con EscorpUpgrades.has(info, id).
 */
typedef EscorpUpgrade = { id : String, cost : Int };

/**
 * Mejoras de la ESCorp (anadido del port): se desbloquean desde el ordenador de a bordo (Contactar con la ESCorp, Mejoras
 * ESCorp; pantalla GalaxyApp.buildUpgrades) a cambio de cargas de bonus, las verdes (CBonus), que no sirven para el laser.
 * Las desbloqueadas se guardan en SaveInfo.upgrades (sus id). Por ahora no hay ninguna: la pantalla lo dice.
 */
class EscorpUpgrades {

	/** verde de las cargas de bonus (KubDraw.chargeColor) */
	public static inline var COLOR = 0x7CE85A;

	/** todas las mejoras, en el orden de la pantalla (ninguna por ahora) */
	public static var ALL : Array<EscorpUpgrade> = [];

	/** cargas de bonus del inventario */
	public static function bonus( inv : Inv ) : Int {
		var k = Type.enumIndex(CBonus);
		for( c in inv.inv.charges ) if( c.c == k ) return c.n;
		return 0;
	}

	/** icono de 16 px de las cargas de bonus, el de la barra del inventario (InvBar) */
	public static function icon() : h2d.Tile {
		var icons = hxd.res.Any.fromBytes("icons.png", Res.bytes("icons.png")).toTile();
		return icons.sub(Type.enumIndex(CBonus) * 16, 0, 16, 16);
	}

	public static function has( info : SaveInfo, id : String ) : Bool return info.upgrades != null && info.upgrades.indexOf(id) >= 0;

	/** se puede desbloquear: aun no lo esta, fuera del tutorial y con las cargas de bonus de su precio */
	public static function canBuy( info : SaveInfo, inv : Inv, u : EscorpUpgrade ) : Bool {
		return Tutorial.upgradesAllowed(info) && !has(info, u.id) && bonus(inv) >= u.cost;
	}

	/** la desbloquea: se pagan sus cargas de bonus y queda en la partida */
	public static function buy( info : SaveInfo, inv : Inv, u : EscorpUpgrade ) : Bool {
		if( !canBuy(info, inv, u) ) return false;
		for( i in 0...u.cost ) inv.useCharge(CBonus);
		if( info.upgrades == null ) info.upgrades = [];
		info.upgrades.push(u.id);
		return true;
	}
}
