import Common;
import Ui;
import SlotGrid;
import StorageData.StorageInfo;


/**
 * Stockage de la nave (anadido del port). En el original lo llevaba el servidor y se ha perdido: el cliente solo tiene
 * Const.STORAGE_PRICE y Const.AUTO_STORAGE (com/Common.hx), que no usa en ningun sitio. Se abre desde el ordenador de a bordo
 * (tambien en creativo; no durante el tutorial) y, en la nave nodriza, desde el ordenador de tu nave aparcada. Dos zonas:
 *   - bloques: tantas casillas como un Conteneur ESCorp (BChest, BFContainer(4)), con las pilas del inventario; las gemas son
 *     bloques y van aqui
 *   - cargas: un contador por tipo, sin casillas (como en el inventario); amarillas, azules y rosas hasta la cuarta parte del
 *     maximo del inventario (24, 12 y 5), las de hexalita sin limite
 * Uno por partida (solo hay una nave): no cambia al modificar la nave en el hangar. Se mueve con arrastrar y soltar (SlotGrid):
 * zona 0 = los bloques guardados, 1 = las cargas guardadas, 2 = el inventario, 3 = las cargas del inventario. Lo que sale va al
 * inventario: la barra y el Kubindex lo ven (Inv.display).
 */
class ShipStorage extends h2d.Object {

	public var onClose : Void -> Void;
	public var grid(default, null) : SlotGrid;
	public var store(default, null) : StorageInfo;

	static inline var CELL = SlotGrid.CELL;

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture, inv : Inv, store : StorageInfo ) {
		super(parent);
		this.store = store;
		var maxWeight = inv.inv.maxWeight;
		var w = 940;
		// la ayuda va abajo a todo lo ancho, partida entre sus partes (InvScreen.hintLines), y el panel crece lo que ocupe
		var hint = Theme.text(null, "", 1.3, Theme.DIM);
		hint.text = InvScreen.hintLines(hint, Lang.t("storage.hint") + "   " + Lang.t("slots.hint"), w - 48).join("\n");
		var hy = 344;
		var h = Std.int(hy + hint.textHeight * hint.scaleY + 18);
		var px = Std.int((Theme.W - w) * 0.5), py = Std.int((Theme.H - h) * 0.5);
		var bg = new h2d.Graphics(this);
		Theme.fullRect(bg, 0x000000, 0.35);
		Theme.rect(bg, px, py, w, h, Theme.PANEL, 0.96);
		Theme.rect(bg, px, py, w, 4, Theme.ACCENT);
		Theme.text(this, Lang.t("storage.title"), 2.4, Theme.TEXT, px + 24, py + 18);
		// columna de las cargas, a la derecha de las casillas del inventario
		var cx = px + 24 + inv.inv.t.length * CELL + 48;
		Theme.text(this, Lang.t("storage.blocks"), 1.6, Theme.DIM, px + 24, py + 68);
		Theme.text(this, Lang.t("storage.charges"), 1.6, Theme.DIM, cx, py + 68);
		Theme.text(this, Lang.t("chest.yours"), 1.6, Theme.DIM, px + 24, py + 190);
		Theme.text(this, Lang.t("storage.yourcharges"), 1.6, Theme.DIM, cx, py + 190);
		// Cerrar, a la derecha de la linea del nombre
		var close = new h2d.Interactive(140, 34, this);
		close.x = px + w - 164;
		close.y = py + 296;
		var cg = new h2d.Graphics(close);
		Theme.rect(cg, 0, 0, 140, 34, 0xFFFFFF, 0.08);
		Theme.center(Theme.text(close, Lang.t("shop.close"), 1.7, Theme.TEXT), 140, 34);
		close.onOver = function(_) {
			cg.clear();
			Theme.rect(cg, 0, 0, 140, 34, Theme.ACCENT, 0.3);
		};
		close.onOut = function(_) {
			cg.clear();
			Theme.rect(cg, 0, 0, 140, 34, 0xFFFFFF, 0.08);
		};
		close.onClick = function(_) if( onClose != null ) onClose();
		var info = Theme.text(this, "", 1.6, Theme.CYAN, px + 24, py + 300);
		info.maxWidth = (close.x - 20 - info.x) / info.scaleX;
		hint.x = px + 24;
		hint.y = py + hy;
		addChild(hint);
		// las casillas al final: la pila del cursor se dibuja encima de todo
		grid = new SlotGrid(this, atlas);
		var smax = StorageData.chargeMax(), imax = SlotZone.invChargeMax();
		inline function below( max : Array<Int> ) return function(i : Int) return max[i] < 0 ? Lang.t("storage.nolimit") : "max " + max[i];
		grid.addZone(SlotZone.ofBlocks(store.t, maxWeight, px + 24, py + 96));
		var z = SlotZone.ofCharges(store.charges, smax, cx, py + 96);
		z.below = below(smax);
		grid.addZone(z);
		grid.addZone(SlotZone.ofBlocks(inv.inv.t, maxWeight, px + 24, py + 218));
		z = SlotZone.ofCharges(inv.inv.charges, imax, cx, py + 218);
		z.below = below(imax);
		grid.addZone(z);
		grid.onChange = function() inv.display();
		grid.onInfo = function(s) info.text = s;
	}

	/** cada fotograma: SlotGrid.update; B/Esc sin nada en el cursor lo cierran */
	public function update( dt : Float, pad : hxd.Pad ) {
		if( grid.update(dt, pad) && onClose != null ) onClose();
	}

	// ---------------------------------------------------------------- datos

	/** banco de pruebas (print storage): bloques y cargas guardados */
	public static function devInfo( s : StorageInfo ) : String {
		if( s == null ) return "sin stockage";
		var cs = s.charges.copy();
		cs.sort(function(a, b) return a.c - b.c);
		return "bloques [" + [for( v in s.t ) v == null ? "-" : EditorKubes.label(Block.all[v.k]) + "x" + v.n].join(" ") + "] cargas ["
			+ [for( c in cs ) Type.getEnumConstructs(ChargeKind)[c.c] + "x" + c.n].join(" ") + "]";
	}
}
