import Common;
import Ui;
import SlotGrid;

/**
 * Cantina de ESCorp (BChest, BFContainer(4)): cofre de 4 casillas, copiado de ent/Chest.hx del original. En el original se
 * cogia una casilla con un clic y se dejaba con otro; aqui se arrastra y se suelta como en la pantalla de inventario (SlotGrid:
 * clic derecho = la mitad o una, Mayus / Ctrl = la mitad / una, doble clic = juntar). En el original el contenido lo guardaba el
 * servidor; aqui va en la partida (SaveInfo.chests).
 * No es modal, como el original: el juego sigue y la ventana se cierra si el jugador se aleja (far).
 */
class Chest extends h2d.Object {

	public var onClose : Void -> Void;

	static inline var CELL = SlotGrid.CELL;

	var inv : Inv;
	public var box(default, null) : Protocol.BlockInventory;
	/** casillas: zona 0 = la cantina, zona 1 = el inventario */
	public var grid(default, null) : SlotGrid;
	var info : h2d.Text;
	/** posicion del jugador al abrirla (Chest.hpos del original) */
	var hpos : { x : Float, y : Float, z : Float };
	/** zona del panel: un clic fuera de ella mueve la vista (GalaxyApp) */
	var panel : h2d.col.Bounds;

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture, inv : Inv, box : Protocol.BlockInventory, hpos : { x : Float, y : Float, z : Float } ) {
		super(parent);
		this.inv = inv;
		this.box = box;
		this.hpos = hpos;
		var maxWeight = inv.inv.maxWeight;
		var w = 700;
		// la ayuda va abajo a todo lo ancho, partida entre sus partes (InvScreen.hintLines), y el panel crece lo que ocupe
		var hint = Theme.text(null, "", 1.3, Theme.DIM);
		hint.text = InvScreen.hintLines(hint, Lang.t("slots.hint"), w - 48).join("\n");
		var hy = 296;
		var h = Std.int(hy + hint.textHeight * hint.scaleY + 18);
		var px = (Theme.W - w) * 0.5, py = 120.;
		panel = h2d.col.Bounds.fromValues(px, py, w, h);
		// sin oscurecer el fondo: no es modal (el original solo ponia el inventario del cofre arriba, sobre el juego)
		var bg = new h2d.Graphics(this);
		Theme.rect(bg, px, py, w, h, Theme.PANEL, 0.96);
		Theme.rect(bg, px, py, w, 4, Theme.ACCENT);
		Theme.text(this, Block.get(BChest).getName(), 2.4, Theme.TEXT, px + 24, py + 18);
		Theme.text(this, Lang.t("chest.yours"), 1.6, Theme.DIM, px + 24, py + 150);
		// Cerrar, a la derecha de la linea del nombre (debajo del inventario)
		var close = new h2d.Interactive(140, 34, this);
		close.x = px + w - 164;
		close.y = py + 246;
		var cg = new h2d.Graphics(close);
		Theme.rect(cg, 0, 0, 140, 34, 0xFFFFFF, 0.08);
		Theme.center(Theme.text(close, Lang.t("shop.close"), 1.7, Theme.TEXT), 140, 34);
		close.onClick = function(_) if( onClose != null ) onClose();
		info = Theme.text(this, "", 1.6, Theme.CYAN, px + 24, py + 250);
		info.maxWidth = (close.x - 20 - info.x) / info.scaleX;
		hint.x = px + 24;
		hint.y = py + hy;
		addChild(hint);
		// las casillas al final: la pila del cursor se dibuja encima de todo
		grid = new SlotGrid(this, atlas);
		var gw = w - 48, n = inv.inv.t.length;
		grid.addZone(SlotZone.ofBlocks(box, maxWeight, px + 24 + (gw - box.length * CELL) * 0.5, py + 70));
		grid.addZone(SlotZone.ofBlocks(inv.inv.t, maxWeight, px + 24 + (gw - n * CELL) * 0.5, py + 180));
		grid.onChange = function() inv.display();
		grid.onInfo = function(s) info.text = s;
	}

	/** Chest.update del original: se cierra si el jugador se aleja mas de 0.5 de donde la abrio (girar o mirar no cuenta) */
	public function far( g : GameView ) : Bool {
		var dx = g.wrapDist(hpos.x - g.px), dy = g.wrapDist(hpos.y - g.py), dz = hpos.z - g.pz;
		return Math.sqrt(dx * dx + dy * dy + dz * dz) > 0.5;
	}

	/** el punto (de la escena 2D) esta sobre el panel */
	public function isOver( x : Float, y : Float ) : Bool {
		return panel.contains(new h2d.col.Point(x, y));
	}

	/** banco de pruebas (orden chestfocus): marca una casilla como con el mando (0 = la cantina, 1 = el inventario) */
	public function devFocus( side : Int, idx : Int ) {
		grid.devFocus(side, idx);
	}

	/** Mando y teclado (anadido del port; el original solo tenia raton): SlotGrid.update; B/Esc sin nada en el cursor la cierran.
	 * La palanca izquierda mueve al jugador (la ventana no es modal); las flechas, en cambio, son de la ventana (GameView.actionKeys). */
	public function update( dt : Float, pad : hxd.Pad ) {
		if( grid.update(dt, pad) && onClose != null ) onClose();
	}
}
