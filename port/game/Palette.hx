import Common;
import Ui;
import IconMesh.Icons;

/**
 * Paleta del modo creativo (anadido nuestro): todos los bloques que el original vendia en la tienda (los que tienen precio),
 * en una cuadricula con paginas. Un clic pone el bloque en la casilla elegida del inventario.
 */
class Palette extends h2d.Object {

	public var onPick : Block -> Void;
	public var onClose : Void -> Void;
	/** casilla elegida con el mando o el teclado (-1 = ninguna, se usa el raton): aparece al primer movimiento, como en el cofre y la tienda */
	var focus = -1;
	var navCooldown = 0.;
	var cellBgs = new Array<h2d.Graphics>();

	static inline var COLS = 14;
	static inline var ROWS = 8;
	static inline var CELL = 56;
	static inline var PX = Theme.W;
	static inline var PY = Theme.H;

	var atlas : h3d.mat.Texture;
	var blocks = new Array<Block>();
	var page = 0;
	var grid : h2d.Object;
	var info : h2d.Text;
	var pageText : h2d.Text;
	var x0 : Float;
	var y0 : Float;

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture ) {
		super(parent);
		this.atlas = atlas;
		// los kubes van despues de los bloques de Galaxy 55, tambien de los anadidos tras ellos (colonne en rosh...). La cantina
		// no tiene precio en los datos, pero ahora se fabrica (receta 62): tambien sale
		var kubes = [];
		for( b in Block.all )
			if( b.index > 0 && (b.basePrice != null || b.k == BChest) && b.charge == null && b.type != BTInvisible )
				(KubeData.isKube(b.k) ? kubes : blocks).push(b);
		for( b in kubes ) blocks.push(b);
		// el agua de cada planeta no se vendia; en creativo se puede poner (fluye como en Minecraft)
		for( k in [BWater, BDarkWater, BAcidWater, BWinterWater] )
			blocks.push(Block.get(k));

		var w = COLS * CELL + 40, h = ROWS * CELL + 150;
		var px = (PX - w) * 0.5, py = (PY - h) * 0.5;
		x0 = px + 20;
		y0 = py + 70;
		// la ayuda no cabia en una linea (en frances se salia del panel): se parte entre sus partes y el panel crece hacia abajo
		// lo que ocupen las lineas de mas (hacia arriba taparia los numeros de la barra del inventario)
		var hint = Theme.text(null, "", 1.5, Theme.DIM, px + 24, py + h - 34);
		var lines = hintLines(hint, Keys.fill(Lang.t("palette.hint")), w - 48);
		hint.text = lines.join("\n");
		var more = (lines.length - 1) * (hint.font.lineHeight + hint.lineSpacing) * hint.scaleY;
		var bg = new h2d.Graphics(this);
		Theme.fullRect(bg, 0x000000, 0.5);
		Theme.rect(bg, px, py, w, h + more, Theme.PANEL, 0.96);
		Theme.rect(bg, px, py, w, 4, Theme.ACCENT);
		var t = Theme.text(this, Lang.t("palette.title"), 2.6, Theme.TEXT, px + 24, py + 22);
		pageText = Theme.text(this, "", 1.8, Theme.DIM, px + w - 150, py + 30);
		info = Theme.text(this, "", 2.0, Theme.CYAN, px + 24, py + h - 66);
		addChild(hint);
		grid = new h2d.Object(this);
		show();
	}

	/** parte la ayuda entre sus partes (separadas por 3 espacios) para que ninguna linea pase de maxW */
	static function hintLines( t : h2d.Text, s : String, maxW : Float ) {
		var lines : Array<String> = [];
		for( part in s.split("   ") ) {
			var n = lines.length;
			if( n > 0 && t.calcTextWidth(lines[n - 1] + "   " + part) * t.scaleX <= maxW ) lines[n - 1] += "   " + part;
			else lines.push(part);
		}
		return lines;
	}

	function pages() return Std.int((blocks.length + COLS * ROWS - 1) / (COLS * ROWS));

	public function scroll( delta : Float ) {
		page += delta > 0 ? 1 : -1;
		var n = pages();
		if( page < 0 ) page = n - 1;
		if( page >= n ) page = 0;
		show();
	}

	function show() {
		grid.removeChildren();
		cellBgs = [];
		pageText.text = (page + 1) + " / " + pages();
		var per = COLS * ROWS;
		for( i in 0...per ) {
			var bi = page * per + i;
			if( bi >= blocks.length ) break;
			var b = blocks[bi];
			var cx = x0 + (i % COLS) * CELL, cy = y0 + Std.int(i / COLS) * CELL;
			var cell = new h2d.Object(grid);
			cell.x = cx;
			cell.y = cy;
			var g = new h2d.Graphics(cell);
			cellBgs.push(g);
			Theme.rect(g, 1, 1, CELL - 2, CELL - 2, 0xFFFFFF, 0.06);
			// como en la Base de datos ESCorp: liso y con los translucidos (cristal, hielo, agua, gemas de Kube) bien hechos
			var bm = Icons.bitmap(cell, b, 48, atlas);
			bm.x = 4;
			bm.y = 4;
			var it = new h2d.Interactive(CELL - 2, CELL - 2, cell);
			it.onOver = function(_) {
				g.clear();
				Theme.rect(g, 1, 1, CELL - 2, CELL - 2, Theme.ACCENT, 0.3);
				info.text = b.getName();
			};
			it.onOut = function(_) drawFocus();
			it.onClick = function(_) {
				if( onPick != null ) onPick(b);
			};
		}
		drawFocus();
	}

	function pageCount() {
		var per = COLS * ROWS;
		return Std.int(Math.min(per, blocks.length - page * per));
	}

	function drawFocus() {
		for( i in 0...cellBgs.length ) {
			var g = cellBgs[i];
			g.clear();
			if( i == focus ) {
				// marco claro bien visible alrededor de la casilla elegida
				Theme.rect(g, 0, 0, CELL, CELL, 0xFFFFFF, 0.95);
				Theme.rect(g, 3, 3, CELL - 6, CELL - 6, Theme.ACCENT, 0.6);
			} else
				Theme.rect(g, 1, 1, CELL - 2, CELL - 2, 0xFFFFFF, 0.06);
		}
		// sin casilla elegida no queda abajo el nombre del ultimo bloque que tuvo el raton encima
		info.text = focus >= 0 && focus < pageCount() ? blocks[page * COLS * ROWS + focus].getName() : "";
	}

	/** banco de pruebas (orden palhover): el raton entra en la casilla i de la pagina (o sale de ella) */
	public function devHover( i : Int, over : Bool ) {
		var it = Std.downcast(grid.getChildAt(i).getChildAt(2), h2d.Interactive);
		if( over ) it.onOver(null) else it.onOut(null);
	}

	/** banco de pruebas (print palette) */
	public function devInfo() return "pagina " + (page + 1) + " foco " + focus + " nombre '" + info.text + "'";

	/** mando y teclado: cruceta/stick o flechas mueven, A/Intro pone el bloque, LB/RB cambian de pagina, B/R3/Esc/I (Keys) cierran */
	public function update( dt : Float, pad : hxd.Pad ) {
		var K = hxd.Key;
		var dx = 0, dy = 0, pg = 0, pick = false, back = false;
		if( K.isPressed(K.LEFT) ) dx = -1;
		if( K.isPressed(K.RIGHT) ) dx = 1;
		if( K.isPressed(K.UP) ) dy = -1;
		if( K.isPressed(K.DOWN) ) dy = 1;
		if( K.isPressed(K.ENTER) ) pick = true;
		if( K.isPressed(K.ESCAPE) || Keys.pressed("palette") ) back = true;
		if( pad != null ) {
			if( navCooldown > 0 ) navCooldown -= dt;
			if( pad.isPressed(pad.config.dpadLeft) ) dx = -1;
			if( pad.isPressed(pad.config.dpadRight) ) dx = 1;
			if( pad.isPressed(pad.config.dpadUp) ) dy = -1;
			if( pad.isPressed(pad.config.dpadDown) ) dy = 1;
			if( navCooldown <= 0 ) {
				if( pad.xAxis < -0.6 ) { dx = -1; navCooldown = 0.18; }
				else if( pad.xAxis > 0.6 ) { dx = 1; navCooldown = 0.18; }
				else if( pad.yAxis < -0.6 ) { dy = -1; navCooldown = 0.18; }
				else if( pad.yAxis > 0.6 ) { dy = 1; navCooldown = 0.18; }
			}
			if( pad.isPressed(pad.config.LB) ) pg = -1;
			if( pad.isPressed(pad.config.RB) ) pg = 1;
			if( pad.isPressed(pad.config.A) ) pick = true;
			if( pad.isPressed(pad.config.B) || pad.isPressed(pad.config.ranalogClick) ) back = true;
		}
		if( back ) {
			if( onClose != null ) onClose();
			return;
		}
		nav(dx, dy, pg, pick);
	}

	/** cruceta/flechas (dx, dy), LB/RB (pg) y A/Intro (pick); la orden palnav del banco de pruebas pasa por aqui */
	public function nav( dx : Int, dy : Int, pg : Int, pick : Bool ) {
		if( pg != 0 ) {
			scroll(pg);
			if( focus >= pageCount() ) focus = pageCount() - 1;
			drawFocus();
		}
		if( dx != 0 || dy != 0 ) {
			if( focus < 0 ) focus = 0;
			else {
				var cx = focus % COLS + dx, cy = Std.int(focus / COLS) + dy;
				if( cx < 0 ) cx = COLS - 1;
				if( cx >= COLS ) cx = 0;
				if( cy < 0 ) cy = ROWS - 1;
				if( cy >= ROWS ) cy = 0;
				var n = cx + cy * COLS;
				if( n < pageCount() ) focus = n;
			}
			drawFocus();
		}
		if( pick && focus >= 0 && focus < pageCount() && onPick != null ) onPick(blocks[page * COLS * ROWS + focus]);
	}
}