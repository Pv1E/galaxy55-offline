import Common;
import Ui;
import Market;
import IconMesh.Icons;

/**
 * Tienda del robot comerciante (anadido del port): a la izquierda lo que llevas (clic = vender), a la derecha lo que
 * tiene el robot (clic = comprar). Mayus + clic = 10 unidades. Los precios cambian con cada operacion (ver Market).
 */
class Shop extends h2d.Object {

	public var onClose : Void -> Void;
	/** se llama tras cada compra o venta con el saldo nuevo */
	public var onCredits : Int -> Void;

	static inline var CELL = 56;
	static inline var PX = Theme.W;
	static inline var PY = Theme.H;
	static inline var RCOLS = 10;
	static inline var RROWS = 6;

	var atlas : h3d.mat.Texture;
	var market : Market;
	var inv : Inv;
	public var credits(default, null) : Int;
	var page = 0;
	var left : h2d.Object;
	var right : h2d.Object;
	var info : h2d.Text;
	/** borde de abajo de la linea de informacion (encima de la ayuda) */
	var infoBottom = 0.;
	var creditsText : h2d.Text;
	var pageText : h2d.Text;
	var hover : Ware;
	var hoverSell = false;
	/** casillas de cada lado (0 = lo que llevas, 7 columnas; 1 = el robot, RCOLS columnas) para moverse con mando/teclado */
	var cells : Array<Array<{ x : Float, y : Float, w : Ware, sell : Bool, name : String }>> = [[], []];
	/** casilla marcada con el mando o las flechas [lado, indice] (null = solo raton) */
	var focus : Array<Int>;
	var focusG : h2d.Graphics;
	var navCooldown = 0.;

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture, market : Market, inv : Inv, credits : Int ) {
		super(parent);
		this.atlas = atlas;
		this.market = market;
		this.inv = inv;
		this.credits = credits;

		var w = 1180, h = 600;
		var px = (PX - w) * 0.5, py = (PY - h) * 0.5;
		var bg = new h2d.Graphics(this);
		Theme.fullRect(bg, 0x000000, 0.55);
		Theme.rect(bg, px, py, w, h, Theme.PANEL, 0.96);
		Theme.rect(bg, px, py, w, 4, Theme.ACCENT);
		Theme.text(this, Lang.t("shop.title"), 2.6, Theme.TEXT, px + 24, py + 20);
		creditsText = Theme.text(this, "", 2.4, Theme.ACCENT, px + w - 330, py + 22);
		Theme.text(this, Lang.t("shop.yours"), 1.8, Theme.DIM, px + 24, py + 70);
		Theme.text(this, Lang.t("shop.robot"), 1.8, Theme.DIM, px + 470, py + 70);
		pageText = Theme.text(this, "", 1.6, Theme.DIM, px + w - 110, py + 70);
		info = Theme.text(this, "", 1.9, Theme.CYAN, px + 24, py + h - 70);
		var hint = Theme.text(this, Lang.t("shop.hint"), 1.4, Theme.DIM, px + 24, py + h - 36);
		var close = new h2d.Interactive(160, 36, this);
		close.x = px + w - 184;
		close.y = py + h - 52;
		var cg = new h2d.Graphics(close);
		Theme.rect(cg, 0, 0, 160, 36, 0xFFFFFF, 0.08);
		Theme.center(Theme.text(close, Lang.t("shop.close"), 1.8, Theme.TEXT), 160, 36);
		close.onClick = function(_) if( onClose != null ) onClose();
		// la ayuda no cabe en una linea (pisaba el boton): se parte antes del boton y se centra con el. La informacion
		// se queda en la columna de la izquierda (a la derecha estan los precios del robot) y crece hacia arriba
		hint.maxWidth = (close.x - 20 - hint.x) / hint.scaleX;
		hint.y = Math.round(close.y + 18 - hint.textHeight * hint.scaleY * 0.5);
		left = new h2d.Object(this);
		left.x = px + 24;
		left.y = py + 100;
		right = new h2d.Object(this);
		right.x = px + 470;
		right.y = py + 100;
		info.maxWidth = (right.x - 24 - info.x) / info.scaleX;
		infoBottom = hint.y - 4;
		focusG = new h2d.Graphics(this);
		refresh();
	}

	/**
	 * Mando y teclado (añadido del port; los botones son los de la tienda de la version Flash, input/Pad.hx): cruceta/stick
	 * o flechas eligen casilla (al pasar el borde se cambia de lado), A/Intro = 1 unidad, X = 10, LB/RB = pagina, B/Esc = cerrar.
	 */
	public function update( dt : Float, pad : hxd.Pad ) {
		var K = hxd.Key;
		if( navCooldown > 0 ) navCooldown -= dt;
		var dx = 0, dy = 0, page = 0;
		if( K.isPressed(K.LEFT) ) dx = -1;
		if( K.isPressed(K.RIGHT) ) dx = 1;
		if( K.isPressed(K.UP) ) dy = -1;
		if( K.isPressed(K.DOWN) ) dy = 1;
		var one = K.isPressed(K.ENTER) || K.isPressed(K.NUMPAD_ENTER), ten = false, back = K.isPressed(K.ESCAPE);
		if( pad != null ) {
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
			if( pad.isPressed(pad.config.LB) ) page = -1;
			if( pad.isPressed(pad.config.RB) ) page = 1;
			if( pad.isPressed(pad.config.A) ) one = true;
			if( pad.isPressed(pad.config.X) ) ten = true;
			if( pad.isPressed(pad.config.B) ) back = true;
		}
		if( back ) {
			if( onClose != null ) onClose();
			return;
		}
		if( page != 0 ) scroll(page);
		if( dx != 0 || dy != 0 ) {
			if( focus == null ) focus = [1, 0];
			else moveFocus(dx, dy);
			drawFocus();
		}
		if( focus != null && (one || ten) ) {
			var c = cells[focus[0]][focus[1]];
			if( c != null && c.w != null ) {
				if( c.sell ) doSell(c.w, ten ? 10 : 1) else doBuy(c.w, ten ? 10 : 1);
			}
		}
	}

	/** solo pruebas (Dev "shopnav"): como pulsar la cruceta (dx, dy) y, si buy, el boton A */
	public function devNav( dx : Int, dy : Int, buy : Bool ) {
		if( focus == null ) focus = [1, 0] else if( dx != 0 || dy != 0 ) moveFocus(dx, dy);
		drawFocus();
		var c = cells[focus[0]][focus[1]];
		if( buy && c != null && c.w != null ) { if( c.sell ) doSell(c.w, 1) else doBuy(c.w, 1); }
	}

	function moveFocus( dx : Int, dy : Int ) {
		var side = focus[0], i = focus[1];
		var cols = side == 0 ? 7 : RCOLS;
		var n = cells[side].length;
		if( n == 0 ) { focus = [1 - side, 0]; return; }
		var cx = i % cols, cy = Std.int(i / cols);
		cx += dx;
		cy += dy;
		// al pasar el borde, al otro lado (misma fila)
		if( cx < 0 || cx >= cols ) {
			var other = 1 - side;
			var ocols = other == 0 ? 7 : RCOLS;
			if( cells[other].length > 0 ) {
				var ox = dx > 0 ? 0 : ocols - 1;
				var oi = Std.int(Math.min(cells[other].length - 1, cy * ocols + ox));
				focus = [other, oi];
			}
			return;
		}
		var rows = Std.int((n + cols - 1) / cols);
		if( cy < 0 ) cy = rows - 1 else if( cy >= rows ) cy = 0;
		var ni = cy * cols + cx;
		if( ni >= n ) ni = n - 1;
		focus = [side, ni];
	}

	function drawFocus() {
		focusG.clear();
		if( focus == null ) return;
		if( focus[1] >= cells[focus[0]].length ) focus[1] = cells[focus[0]].length - 1;
		if( focus[1] < 0 ) { focus = null; return; }
		var c = cells[focus[0]][focus[1]];
		var o = focus[0] == 0 ? left : right;
		var x = o.x + c.x, y = o.y + c.y;
		Theme.rect(focusG, x - 1, y - 1, CELL + 2, 3, Theme.ACCENT);
		Theme.rect(focusG, x - 1, y + CELL - 2, CELL + 2, 3, Theme.ACCENT);
		Theme.rect(focusG, x - 1, y - 1, 3, CELL + 2, Theme.ACCENT);
		Theme.rect(focusG, x + CELL - 2, y - 1, 3, CELL + 2, Theme.ACCENT);
		if( c.w != null ) {
			hover = c.w;
			hoverSell = c.sell;
			showInfo();
		} else if( c.name != null )
			setInfo(c.name, Lang.t("shop.nosale"));
		else
			setInfo("");
	}

	function pages() return Std.int((Market.wares.length + RCOLS * RROWS - 1) / (RCOLS * RROWS));

	public function scroll( delta : Float ) {
		page += delta > 0 ? 1 : -1;
		var n = pages();
		if( page < 0 ) page = n - 1;
		if( page >= n ) page = 0;
		refresh();
	}

	function refresh() {
		creditsText.text = Lang.t("shop.credits") + " " + credits;
		pageText.text = (page + 1) + " / " + pages();
		// lo que llevas: todas las casillas del inventario, una por una (las que el robot no compra salen apagadas), y las cargas
		left.removeChildren();
		cells = [[], []];
		var i = 0;
		for( st in inv.inv.t ) {
			var x = (i % 7) * CELL, y = Std.int(i / 7) * (CELL + 18);
			i++;
			if( st == null ) {
				emptyCell(left, x, y);
				cells[0].push({ x : x, y : y, w : null, sell : true, name : null });
				continue;
			}
			var b = Block.all[st.k];
			var w = Market.wareOfBlock(b);
			if( w == null ) noSaleCell(left, x, y, b, st.n);
			else cell(left, x, y, w, st.n, market.sellPrice(w), true);
			cells[0].push({ x : x, y : y, w : w, sell : true, name : b.getName() });
		}
		for( c in inv.inv.charges ) {
			if( c.n <= 0 ) continue;
			var w = Market.wareOfCharge(Type.createEnumIndex(ChargeKind, c.c));
			if( w == null ) continue;
			var x = (i % 7) * CELL, y = Std.int(i / 7) * (CELL + 18);
			cell(left, x, y, w, c.n, market.sellPrice(w), true);
			cells[0].push({ x : x, y : y, w : w, sell : true, name : null });
			i++;
		}
		// lo que tiene el robot
		right.removeChildren();
		var per = RCOLS * RROWS;
		for( i in 0...per ) {
			var wi = page * per + i;
			if( wi >= Market.wares.length ) break;
			var w = Market.wares[wi];
			var x = (i % RCOLS) * CELL, y = Std.int(i / RCOLS) * (CELL + 18);
			cell(right, x, y, w, -1, market.buyPrice(w), false);
			cells[1].push({ x : x, y : y, w : w, sell : false, name : null });
		}
		showInfo();
		if( focus != null ) drawFocus();
	}

	function cell( parent : h2d.Object, x : Float, y : Float, w : Ware, n : Int, price : Int, sell : Bool ) {
		var c = new h2d.Object(parent);
		c.x = x;
		c.y = y;
		var g = new h2d.Graphics(c);
		var empty = sell ? price <= 0 : false;
		var draw = function(on : Bool) {
			g.clear();
			Theme.rect(g, 1, 1, CELL - 2, CELL - 2, on ? Theme.ACCENT : 0xFFFFFF, on ? 0.3 : 0.06);
		};
		draw(false);
		var bm = Icons.bitmap(c, w.block, 44, atlas);
		bm.x = 6;
		bm.y = 4;
		if( empty ) bm.alpha = 0.3;
		if( n >= 0 ) Theme.text(c, "" + n, 1.2, Theme.TEXT, 3, CELL - 20);
		Theme.text(c, "" + price, 1.2, sell ? Theme.CYAN : Theme.ACCENT, 3, CELL + 1);
		var it = new h2d.Interactive(CELL - 2, CELL - 2, c);
		it.enableRightButton = true;
		it.onOver = function(_) {
			draw(true);
			hover = w;
			hoverSell = sell;
			showInfo();
		};
		it.onOut = function(_) draw(false);
		it.onClick = function(e) {
			var k = hxd.Key.isDown(hxd.Key.SHIFT) ? 10 : 1;
			if( sell ) doSell(w, k) else doBuy(w, k);
		};
	}

	function emptyCell( parent : h2d.Object, x : Float, y : Float ) {
		var g = new h2d.Graphics(parent);
		g.x = x;
		g.y = y;
		Theme.rect(g, 1, 1, CELL - 2, CELL - 2, 0xFFFFFF, 0.03);
	}

	/** algo que llevas pero el robot no compra (sin precio en los datos) */
	function noSaleCell( parent : h2d.Object, x : Float, y : Float, b : Block, n : Int ) {
		var c = new h2d.Object(parent);
		c.x = x;
		c.y = y;
		var g = new h2d.Graphics(c);
		Theme.rect(g, 1, 1, CELL - 2, CELL - 2, 0xFFFFFF, 0.03);
		var bm = Icons.bitmap(c, b, 44, atlas);
		bm.x = 6;
		bm.y = 4;
		bm.alpha = 0.3;
		Theme.text(c, "" + n, 1.2, Theme.DIM, 3, CELL - 20);
		Theme.text(c, "-", 1.2, Theme.DIM, 3, CELL + 1);
		var it = new h2d.Interactive(CELL - 2, CELL - 2, c);
		it.onOver = function(_) {
			hover = null;
			setInfo(b.getName(), Lang.t("shop.nosale"));
		};
	}

	function showInfo() {
		if( hover == null ) {
			setInfo("");
			return;
		}
		var w = hover;
		var name = w.block.getName();
		var sp = market.sellPrice(w);
		setInfo(name, Lang.t("shop.buy") + " " + market.buyPrice(w) + "   "
			+ (sp > 0 ? Lang.t("shop.sell") + " " + sp : Lang.t("shop.full")));
	}

	/** linea de informacion: si el nombre y los precios no caben juntos, el nombre va encima; el borde de abajo no se mueve */
	function setInfo( name : String, ?rest : String ) {
		var s = rest == null ? name : name + "   " + rest;
		if( rest != null && info.splitText(s).indexOf("\n") >= 0 ) s = name + "\n" + rest;
		info.text = s;
		info.y = Math.round(infoBottom - info.textHeight * info.scaleY);
	}

	/** compra hasta `n`, limitado por los creditos, las existencias y el sitio del inventario */
	public function doBuy( w : Ware, n : Int ) {
		var room = 0;
		if( w.charge != null ) {
			var have = 0;
			for( c in inv.inv.charges ) if( c.c == Type.enumIndex(w.charge) ) have = c.n;
			room = Std.int(Math.max(0, Data.getCharge(w.charge).max - have));
		} else {
			// sitio que queda para ese bloque (pilas a medias y casillas libres)
			var max = w.block.getMax(inv.inv.maxWeight);
			for( s in inv.inv.t ) {
				if( s == null ) room += max;
				else if( s.k == w.block.index ) room += Std.int(Math.max(0, max - s.n));
			}
		}
		var r = market.buy(w, Std.int(Math.min(n, room)), credits);
		if( r.n <= 0 ) return;
		credits -= r.cost;
		if( w.charge != null ) inv.addCharge(w.charge, r.n) else inv.addBlocks(w.block, r.n);
		if( onCredits != null ) onCredits(credits);
		refresh();
	}

	public function doSell( w : Ware, n : Int ) {
		var have = 0;
		if( w.charge != null ) {
			for( c in inv.inv.charges ) if( c.c == Type.enumIndex(w.charge) ) have = c.n;
		} else
			for( s in inv.inv.t ) if( s != null && s.k == w.block.index ) have += s.n;
		n = Std.int(Math.min(n, have));
		if( n <= 0 ) return;
		var r = market.sell(w, n);
		n = r.n;
		if( n <= 0 ) return;
		if( w.charge != null ) {
			for( c in inv.inv.charges ) if( c.c == Type.enumIndex(w.charge) ) c.n -= n;
			inv.display();
		} else
			inv.useBlocks(w.block, n);
		credits += r.gain;
		if( onCredits != null ) onCredits(credits);
		refresh();
	}
}
