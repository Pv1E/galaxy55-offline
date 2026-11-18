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

	/** tipos de carga (amarilla, azul, rosa, bonus; SlotZone.CHARGE_KINDS) */
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

	/** cuantas cargas de cada tipo caben: la cuarta parte del maximo del inventario (24, 12 y 5), las de bonus sin limite (-1) */
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

	/** stockage guardado; null si no hay o esta mal formado (lo que no se entiende se salta) */
	public static function read( o : Dynamic ) : StorageInfo {
		try {
			if( o == null ) return null;
			var s = empty();
			if( o.t != null ) {
				var a : Array<Dynamic> = o.t;
				for( i in 0...a.length ) {
					var v = a[i];
					if( v == null || v.k == null || v.n == null || Std.int(v.n) <= 0 ) continue;
					if( i < s.t.length ) s.t[i] = { k : Std.int(v.k), n : Std.int(v.n) } else s.t.push({ k : Std.int(v.k), n : Std.int(v.n) });
				}
			}
			if( o.charges != null )
				for( c in (o.charges : Array<Dynamic>) )
					if( c != null && c.c != null && c.n != null && Std.int(c.c) >= 0 && Std.int(c.c) < CHARGE_KINDS && Std.int(c.n) > 0 )
						s.charges.push({ c : Std.int(c.c), n : Std.int(c.n) });
			return s;
		} catch( e : Dynamic ) {
			return null;
		}
	}

}
