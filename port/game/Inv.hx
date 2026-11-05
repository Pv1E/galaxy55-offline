import Common;
import Protocol;

/**
 * Inventario del jugador: reutiliza la logica del original (com/Inventory.hx) y avisa a la interfaz cuando cambia.
 * Casilla 0 = el excavador (mano vacia); las casillas 1... son los bloques (blockIndex - 1 en la tabla).
 */
class Inv extends Inventory {

	public var onChange : Void -> Void;
	/** el contenido ha cambiado (Base de datos ESCorp: lo que entra queda recuperado, Kubindex.scan) */
	public var onContent : Void -> Void;

	public function new( i : InventoryInfos ) {
		super(i);
		blockIndex = 0;
	}

	override public function display() {
		if( onContent != null ) onContent();
		if( onChange != null ) onChange();
	}

	override function redraw() {
		if( onContent != null ) onContent();
		if( onChange != null ) onChange();
	}

	public function select( index : Int ) {
		if( index < 0 ) index = 0;
		if( index > inv.t.length ) index = inv.t.length;
		blockIndex = index;
		if( onChange != null ) onChange();
	}

	/** rueda del raton (InterfInvent.scrollInventory) */
	public function scroll( delta : Int ) {
		var index = blockIndex;
		if( delta < 0 ) index++ else index--;
		select(index);
	}

	/** Inventario inicial del original (Main.gameInfos): 10 casillas, 64 de peso maximo y 30 cargas de cada tipo. */
	public static function defaults() : InventoryInfos {
		var inv : InventoryInfos = { maxWeight : 64, t : [], charges : [] };
		for( b in [BLamp, BFreezer, BMinIron, BMinAluminium, BIron, BHealPlant, BCascadeSource, BBonusMedium, BChest] )
			inv.t.push({ k : Type.enumIndex(b), n : 50 });
		for( c in [CYellow, CBlue, CPink, CBonus] )
			inv.charges.push({ c : Type.enumIndex(c), n : 30 });
		while( inv.t.length < 10 )
			inv.t.push(null);
		return inv;
	}

	/** Inventario inicial del modo aventura del port: las mismas 10 casillas y peso maximo, sin bloques ni cargas. */
	public static function empty() : InventoryInfos {
		return { maxWeight : 64, t : [for( i in 0...10 ) null], charges : [] };
	}

	/** copia profunda (el guardado y el juego no comparten estructuras) */
	public static function copy( i : InventoryInfos ) : InventoryInfos {
		return {
			maxWeight : i.maxWeight,
			t : [for( s in i.t ) s == null ? null : { k : s.k, n : s.n }],
			charges : [for( c in i.charges ) { c : c.c, n : c.n }],
		};
	}
}
