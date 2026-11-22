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

	/** los maximos de las cargas del inventario (DataGen.CHARGES: 99, 50, 20 y 99999; SlotZone.invChargeMax) */
	public static function invChargeMax() : Array<Int> {
		return [for( k in 0...CHARGE_KINDS ) Data.getCharge(Type.createEnumIndex(ChargeKind, k)).max];
	}

	/** casillas de bloques: las de un Conteneur ESCorp (BFContainer de BChest) */
	public static function blockSlots() : Int {
		for( f in Block.get(BChest).flags ) switch( f ) { case BFContainer(s): return s; default: }
		return 4;
	}

	/** cuantas cargas de cada tipo caben: la cuarta parte del maximo del inventario (24, 12 y 5), las de hexalita sin limite (-1) */
	public static function chargeMax() : Array<Int> {
		var inv = invChargeMax();
		return [for( k in 0...CHARGE_KINDS ) Type.createEnumIndex(ChargeKind, k) == CBonus ? -1 : Std.int(inv[k] / 4)];
	}

	public static function empty() : StorageInfo {
		return { t : [for( i in 0...blockSlots() ) null], charges : [] };
	}

	/** el stockage de la partida; se crea vacio la primera vez (las partidas de antes no lo tienen) */
	public static function ensure( info : SaveData.SaveInfo ) : StorageInfo {
		if( info.storage == null ) info.storage = empty();
		// si un dia cambia el numero de casillas, las que falten se anaden vacias
		while( info.storage.t.length < blockSlots() ) info.storage.t.push(null);
		return info.storage;
	}

}
