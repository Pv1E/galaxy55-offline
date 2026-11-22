import Common;

/**
 * Cuentas de la tienda del robot (anadido del port para el multijugador, sacadas de Shop): lo que cabe de una mercancia, lo que
 * se lleva y quitarlo. Las usan la tienda (Shop) y el servidor (ServerEcon), asi los dos calculan igual.
 */
class ShopRules {

	/** sitio que queda para esa mercancia: hasta el maximo del contador de cargas, o pilas a medias y casillas libres */
	public static function room( inv : Inv, w : Market.Ware ) : Int {
		var room = 0;
		if( w.charge != null ) {
			var have = 0;
			for( c in inv.inv.charges ) if( c.c == Type.enumIndex(w.charge) ) have = c.n;
			room = Std.int(Math.max(0, Data.getCharge(w.charge).max - have));
		} else {
			var max = w.block.getMax(inv.inv.maxWeight);
			for( s in inv.inv.t ) {
				if( s == null ) room += max;
				else if( s.k == w.block.index ) room += Std.int(Math.max(0, max - s.n));
			}
		}
		return room;
	}

	/** cuantas lleva */
	public static function have( inv : Inv, w : Market.Ware ) : Int {
		var have = 0;
		if( w.charge != null ) {
			for( c in inv.inv.charges ) if( c.c == Type.enumIndex(w.charge) ) have = c.n;
		} else
			for( s in inv.inv.t ) if( s != null && s.k == w.block.index ) have += s.n;
		return have;
	}

	/** quita n (que las lleva: have) */
	public static function take( inv : Inv, w : Market.Ware, n : Int ) {
		if( w.charge != null ) {
			for( c in inv.inv.charges ) if( c.c == Type.enumIndex(w.charge) ) c.n -= n;
			inv.display();
		} else
			inv.useBlocks(w.block, n);
	}
}
