import Common;

/** Contenido del stockage de la nave (SaveInfo.storage): bloques en casillas y cargas en contadores, sin casillas. */
typedef StorageInfo = {
	var t : Protocol.BlockInventory;
	var charges : Protocol.UserCharges;
}

/**
 * Datos del stockage de la nave (ShipStorage), sin nada de interfaz: separados para el multijugador (anadido del port), que
 * guarda el stockage en el servidor.
 */
class StorageData {

	/** tipos de carga (amarilla, azul, rosa, hexalita; SlotZone.CHARGE_KINDS) */
	public static inline var CHARGE_KINDS = 4;

	/** los maximos de las cargas del inventario (DataGen.CHARGES: 99, 50, 10 y 99999; SlotZone.invChargeMax) */
	public static function invChargeMax() : Array<Int> {
		return [for( k in 0...CHARGE_KINDS ) Data.getCharge(Type.createEnumIndex(ChargeKind, k)).max];
	}

	/** casillas de bloques sin mejoras: las de un Conteneur ESCorp (BFContainer de BChest) */
	public static function baseSlots() : Int {
		for( f in Block.get(BChest).flags ) switch( f ) { case BFContainer(s): return s; default: }
		return 4;
	}

	/** casillas de bloques que se ganan con cada nivel de EscorpUpgrades.STORAGE_SLOTS (8 niveles: de 4 a 20, dos filas de 10) */
	public static inline var SLOTS_PER_LEVEL = 2;

	/** casillas de bloques del stockage de la partida: las de serie y las de la mejora */
	public static function blockSlots( info : SaveData.SaveInfo ) : Int {
		return baseSlots() + SLOTS_PER_LEVEL * EscorpUpgrades.level(info, EscorpUpgrades.STORAGE_SLOTS);
	}

	/**
	 * cuantas cargas de cada tipo caben sin mejoras: amarillas, azules, rosas y hexalita (-1 = sin limite). Antes era la cuarta
	 * parte del maximo del inventario (24, 12 y 5); con 10 rosas en el inventario, 2 en el stockage. Cada nivel de
	 * EscorpUpgrades.STORAGE_CHARGES suma otro tanto
	 */
	public static var BASE_CHARGES = [24, 12, 2, -1];

	/** cuantas cargas de cada tipo caben en el stockage de la partida (-1 = sin limite) */
	public static function chargeMax( info : SaveData.SaveInfo ) : Array<Int> {
		var n = EscorpUpgrades.level(info, EscorpUpgrades.STORAGE_CHARGES);
		return [for( b in BASE_CHARGES ) b < 0 ? -1 : b * (1 + n)];
	}

	/** un stockage vacio con las casillas de serie (ensure anade las de la mejora) */
	public static function empty() : StorageInfo {
		return { t : [for( i in 0...baseSlots() ) null], charges : [] };
	}

	/** el stockage de la partida; se crea vacio la primera vez (las partidas de antes no lo tienen) */
	public static function ensure( info : SaveData.SaveInfo ) : StorageInfo {
		if( info.storage == null ) info.storage = empty();
		// las casillas que faltan (una mejora comprada, un numero de serie distinto) se anaden vacias
		while( info.storage.t.length < blockSlots(info) ) info.storage.t.push(null);
		return info.storage;
	}

}
