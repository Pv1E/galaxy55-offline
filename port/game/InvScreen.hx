import Common;
import Ui;
import IconMesh.Icons;

/**
 * Pantalla de inventario del modo aventura y de la supervivencia de una partida creativa (anadido del port), como la de
 * Minecraft: las casillas de la barra de arriba (las mismas, en grande) con el raton libre. La barra sigue a la vista y cambia
 * a la vez: el orden elegido aqui es el de la barra.
 *   - clic izquierdo mantenido: coger la pila y arrastrarla; al soltarla sobre una casilla se deja, se junta (mismo bloque, hasta
 *     el maximo de la pila; lo que no cabe se queda en su casilla) o se intercambian las dos casillas
 *   - un clic sin moverse deja la pila en el cursor (como en Minecraft): el clic siguiente la deja, la junta o la cambia por la de
 *     esa casilla (y el cursor se queda con esa otra)
 *   - clic derecho: coger la mitad de una pila (redondeando hacia arriba) o, con una en el cursor, dejar una unidad; arrastrando
 *     con el derecho apretado, una en cada casilla por la que se pasa
 *   - Mayus + clic izquierdo: la mitad; Ctrl + clic izquierdo: una (al coger y al dejar), como en la cantina (Chest)
 *   - doble clic: juntar en esa casilla las otras pilas del mismo bloque, hasta el maximo
 *   - soltar fuera del panel, o hacer clic fuera con una pila en el cursor: tirarla al suelo, como R; clic derecho fuera: una unidad
 *   - 1-0 (Keys) sobre una casilla: cambiarla con esa casilla; R (Keys "drop") sobre una casilla: tirar su pila
 *   - mando y teclado: cruceta/flechas eligen la casilla, A/Intro = clic, X = clic derecho, Y = tirar, B/Esc/I = cerrar
 *   - en la supervivencia de una partida creativa, arriba a la derecha el boton para volver a creativo (addCornerButton,
 *     ModeSwitch; Select del mando lo pulsa, GalaxyApp)
 * La pila del cursor no sale del inventario: sigue en su casilla (que aqui se ve con lo que queda) hasta que se deja en otra o se
 * tira. Asi el guardado, los cambios de mundo y el Kubindex ven siempre el inventario entero, y al cerrar no hay nada que devolver.
 * La casilla elegida de la barra (blockIndex) es una posicion, como en Minecraft: no sigue al bloque que se mueve.
 */
class InvScreen extends h2d.Object {

	public var onClose : Void -> Void;
	/** tirar n bloques b delante del jugador (GameView.throwStack) */
	public var onThrow : Block -> Int -> Void;
	/** boton de arriba a la derecha (addCornerButton): la bascula creativo / supervivencia de una partida creativa */
	public var corner(default, null) : Ui.Widget;

	public static inline var CELL = 60;
	static inline var BTN_H = 34;
	/** segundos entre los dos clics de un doble clic */
	static inline var DOUBLE = 0.35;

	var atlas : h3d.mat.Texture;
	var inv : Inv;
	var panel : h2d.col.Bounds;
	var grid : h2d.Object;
	var info : h2d.Text;
	/** la pila del cursor, dibujada encima de todo */
	var hand : h2d.Object;
	var x0 : Float;
	var y0 : Float;
	var shown : String;
	/** pila del cursor: n bloques k de la casilla from (siguen en ella hasta dejarlos en otra) */
	var held : { from : Int, k : Int, n : Int };
	/** la pila del cursor se cogio con el clic izquierdo que sigue apretado: al soltarlo en otra casilla se deja alli */
	var dragging = false;
	/** durante el arrastre el raton ha salido de la casilla en la que se cogio */
	var moved = false;
	/** clic derecho apretado con una pila en el cursor: casillas en las que ya se dejo una unidad */
	var painted : Array<Int>;
	var lastLeft = -1;
	var lastLeftTime = 0.;
	var hover = -1;
	/** casilla marcada con el mando o las flechas (-1 = solo raton) */
	var focus = -1;
	var mx = -1000.;
	var my = -1000.;
	var winEvents : hxd.Event -> Void;
	/** altura del centro del titulo: el boton de arriba a la derecha se centra con el */
	var titleMid = 0.;

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture, inv : Inv ) {
		super(parent);
		this.atlas = atlas;
		this.inv = inv;
		var n = inv.inv.t.length;
		var w = Math.max(760, n * CELL + 100);
		// la ayuda va abajo a todo lo ancho, partida entre sus partes (nunca en medio de una), y el panel crece lo que ocupe
		var hint = Theme.text(null, "", 1.3, Theme.DIM);
		hint.text = hintLines(hint, Keys.fill(Lang.t("invscreen.hint")), w - 48).join("\n");
		var hy = 206;
		var h = hy + hint.textHeight * hint.scaleY + 18;
		var px = Std.int((Theme.W - w) * 0.5), py = Std.int((Theme.H - h) * 0.5);
		panel = h2d.col.Bounds.fromValues(px, py, w, h);
		var bg = new h2d.Graphics(this);
		Theme.fullRect(bg, 0x000000, 0.35);
		Theme.rect(bg, px, py, w, h, Theme.PANEL, 0.96);
		Theme.rect(bg, px, py, w, 4, Theme.ACCENT);
		var title = Theme.text(this, Lang.t("invscreen.title"), 2.4, Theme.TEXT, px + 24, py + 18);
		titleMid = title.y + title.font.lineHeight * title.scaleY * 0.5;
		x0 = px + (w - n * CELL) * 0.5;
		y0 = py + 74;
		grid = new h2d.Object(this);
		info = Theme.text(this, "", 1.6, Theme.CYAN, px + 24, y0 + CELL + 26);
		hint.x = px + 24;
		hint.y = py + hy;
		addChild(hint);
		// Cerrar, a la derecha de la linea del nombre
		var close = button(this, Lang.t("shop.close"), 140, function() if( onClose != null ) onClose());
		close.x = px + w - 24 - 140;
		close.y = y0 + CELL + 22;
		hand = new h2d.Object(this);
		// el raton se lee de los eventos de la ventana (y no de hxd.Key en update): un clic de un solo fotograma tambien cuenta
		winEvents = onEvent;
		hxd.Window.getInstance().addEventTarget(winEvents);
		refresh();
	}

	override function onRemove() {
		if( winEvents != null ) {
			hxd.Window.getInstance().removeEventTarget(winEvents);
			winEvents = null;
		}
		super.onRemove();
	}

	/** parte la ayuda entre sus partes (separadas por 3 espacios) para que ninguna linea pase de maxW (como Palette.hintLines) */
	static function hintLines( t : h2d.Text, s : String, maxW : Float ) : Array<String> {
		var lines : Array<String> = [];
		for( part in s.split("   ") ) {
			var n = lines.length;
			if( n > 0 && t.calcTextWidth(lines[n - 1] + "   " + part) * t.scaleX <= maxW ) lines[n - 1] += "   " + part;
			else lines.push(part);
		}
		return lines;
	}

	function button( parent : h2d.Object, label : String, w : Int, cb : Void -> Void ) : h2d.Interactive {
		var it = new h2d.Interactive(w, BTN_H, parent);
		var g = new h2d.Graphics(it);
		var draw = function(on : Bool) {
			g.clear();
			Theme.rect(g, 0, 0, w, BTN_H, on ? Theme.ACCENT : 0xFFFFFF, on ? 0.3 : 0.08);
		};
		draw(false);
		Theme.center(Theme.text(it, label, 1.7, Theme.TEXT), w, BTN_H);
		it.onOver = function(_) draw(true);
		it.onOut = function(_) draw(false);
		it.onClick = function(_) cb();
		return it;
	}

	/** boton arriba a la derecha, centrado con el titulo (como Palette.addCornerButton): la bascula creativo / supervivencia
	    (ModeSwitch.button). Va debajo de la pila del cursor */
	public function addCornerButton( b : Ui.Widget ) {
		addChildAt(b, getChildIndex(hand));
		b.x = Std.int(panel.xMax - 24 - b.w);
		b.y = Std.int(titleMid - b.h * 0.5);
		corner = b;
	}

	// ---------------------------------------------------------------- dibujo

	inline function maxOf( k : Int ) return Block.all[k].getMax(inv.inv.maxWeight);

	/** lo que se ve en la casilla i: su pila menos lo que lleva el cursor */
	function shownCount( i : Int ) : Int {
		var s = inv.inv.t[i];
		if( s == null ) return 0;
		return held != null && held.from == i ? s.n - held.n : s.n;
	}

	function stamp() {
		return [for( s in inv.inv.t ) s == null ? "-" : s.k + "x" + s.n].join(",") + "|" + inv.blockIndex + "|" + hover + "|" + focus
			+ "|" + (held == null ? "" : held.from + ":" + held.n);
	}

	function refresh() {
		shown = stamp();
		grid.removeChildren();
		var t = inv.inv.t;
		for( i in 0...t.length ) {
			var c = new h2d.Object(grid);
			c.x = x0 + i * CELL;
			c.y = y0;
			var g = new h2d.Graphics(c);
			var on = i == hover || i == focus;
			Theme.rect(g, 2, 2, CELL - 4, CELL - 4, on ? Theme.ACCENT : 0xFFFFFF, on ? 0.25 : 0.07);
			// la casilla elegida de la barra (la que se usa al jugar), con un marco blanco; la del mando, con uno naranja
			if( i == inv.blockIndex - 1 ) frame(g, 0xFFFFFF, 0.85);
			if( i == focus ) frame(g, Theme.ACCENT, 1);
			var n = shownCount(i);
			if( n > 0 ) {
				var b = Block.all[t[i].k];
				var bm = Icons.bitmap(c, b, 48, atlas, true);
				bm.x = 6;
				bm.y = 3;
				count(c, n, b, 5, CELL - 20);
			}
			var key = Theme.text(c, Keys.fill("%slot" + (i + 1) + "%"), 1.0, Theme.DIM);
			key.x = Std.int((CELL - key.textWidth * key.scaleX) * 0.5);
			key.y = CELL + 1;
		}
		// abajo, el nombre y la cantidad de la casilla bajo el raton (o la marcada); si no hay, lo que lleva el cursor
		var sel = focus >= 0 ? focus : hover;
		if( sel >= 0 && shownCount(sel) > 0 ) info.text = Block.all[t[sel].k].getName() + " x" + shownCount(sel);
		else info.text = held != null ? Block.all[held.k].getName() + " x" + held.n : "";
		hand.removeChildren();
		if( held != null ) {
			var b = Block.all[held.k];
			var bm = Icons.bitmap(hand, b, 48, atlas, true);
			bm.x = -24;
			bm.y = -27;
			count(hand, held.n, b, -19, 4);
		}
		placeHand();
	}

	function frame( g : h2d.Graphics, color : Int, alpha : Float ) {
		Theme.rect(g, 0, 0, CELL, 2, color, alpha);
		Theme.rect(g, 0, CELL - 2, CELL, 2, color, alpha);
		Theme.rect(g, 0, 2, 2, CELL - 4, color, alpha);
		Theme.rect(g, CELL - 2, 2, 2, CELL - 4, color, alpha);
	}

	function count( p : h2d.Object, n : Int, b : Block, x : Float, y : Float ) {
		var tf = Theme.text(p, "" + n, 1.2, n >= b.getMax(inv.inv.maxWeight) ? 0xF08080 : Theme.TEXT, x, y);
		tf.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 1 };
	}

	/** la pila del cursor sigue al raton; con el mando, encima de la casilla marcada */
	function placeHand() {
		if( focus >= 0 ) {
			hand.x = x0 + focus * CELL + CELL * 0.5;
			hand.y = y0 - 16;
		} else {
			hand.x = mx;
			hand.y = my;
		}
	}

	// ---------------------------------------------------------------- raton

	/** casilla en el punto x y de la zona W x H (-1 = ninguna) */
	function slotAt( x : Float, y : Float ) : Int {
		if( y < y0 || y >= y0 + CELL || x < x0 ) return -1;
		var i = Std.int((x - x0) / CELL);
		return i < inv.inv.t.length ? i : -1;
	}

	inline function inPanel( x : Float, y : Float ) return panel.contains(new h2d.col.Point(x, y));

	/** banco de pruebas: centro de la casilla i, un punto fuera del panel (i = -1) o dentro sin casilla (i = -2) */
	public function devPoint( i : Int ) : h2d.col.Point {
		if( i == -1 ) return new h2d.col.Point(panel.xMin - 80, panel.yMin + 40);
		if( i == -2 ) return new h2d.col.Point(panel.xMin + 40, panel.yMin + 40);
		return new h2d.col.Point(x0 + i * CELL + CELL * 0.5, y0 + CELL * 0.5);
	}

	function onEvent( e : hxd.Event ) {
		switch( e.kind ) {
		case EPush, ERelease, EMove:
			// de pixeles de la ventana a la zona W x H (LetterBox), como la orden mouse del banco de pruebas al reves
			var area = Theme.visibleArea(), eng = h3d.Engine.getCurrent();
			mx = area.x + e.relX * area.w / eng.width;
			my = area.y + e.relY * area.h / eng.height;
			switch( e.kind ) {
			case EPush: mouseDown(e.button);
			case ERelease: mouseUp(e.button);
			default: mouseMove();
			}
		case EReleaseOutside:
			// el boton se solto sin que la ventana lo viera (p. ej. al perder el foco): se anula el arrastre
			if( dragging ) {
				dragging = false;
				held = null;
				refresh();
			}
			painted = null;
		default:
		}
	}

	function mouseMove() {
		var s = slotAt(mx, my);
		if( dragging && held != null && s != held.from ) moved = true;
		if( painted != null && held != null && s >= 0 && painted.indexOf(s) < 0 ) {
			painted.push(s);
			if( inv.inv.t[s] == null || inv.inv.t[s].k == held.k ) putOne(s);
		}
		if( s != hover ) {
			hover = s;
			if( s >= 0 ) focus = -1;
			refresh();
		} else
			placeHand();
	}

	function mouseDown( button : Int ) {
		var s = slotAt(mx, my);
		if( button == 0 ) {
			painted = null;
			if( s >= 0 ) leftDown(s, true);
			// clic fuera del panel con una pila en el cursor: al suelo (Minecraft); dentro del panel sin casilla, nada
			else if( held != null && !inPanel(mx, my) ) throwHeld(held.n);
		} else if( button == 1 && !dragging ) {
			if( s >= 0 ) rightDown(s, true);
			else if( held != null && !inPanel(mx, my) ) throwHeld(1);
		}
	}

	function mouseUp( button : Int ) {
		if( button == 1 ) {
			painted = null;
			return;
		}
		if( button != 0 || !dragging ) return;
		dragging = false;
		if( held == null ) return;
		var s = slotAt(mx, my);
		// clic sin arrastrar: la pila se queda en el cursor
		if( s == held.from && !moved ) return;
		if( s >= 0 && s != held.from ) dropOn(s);
		else if( s < 0 && !inPanel(mx, my) ) throwHeld(held.n);
		else {
			// soltada en su casilla o en el panel: no se mueve
			held = null;
			refresh();
		}
	}

	// ---------------------------------------------------------------- operaciones

	/** cambio de verdad en el inventario: la barra se redibuja y el Kubindex lo mira (Inv.onChange / onContent) */
	function changed() {
		inv.display();
		refresh();
	}

	/** quita n de la casilla i (la vacia si llega a 0) */
	function take( i : Int, n : Int ) {
		var s = inv.inv.t[i];
		s.n -= n;
		if( s.n <= 0 ) inv.inv.t[i] = null;
	}

	/** mueve hasta n bloques de la casilla a a la b (vacia o del mismo bloque): devuelve cuantos caben; el resto se queda en a */
	function moveItems( a : Int, b : Int, n : Int ) : Int {
		var t = inv.inv.t, k = t[a].k, d = t[b];
		var m = d == null ? n : d.k == k ? Std.int(Math.max(0, Math.min(maxOf(k) - d.n, n))) : 0;
		if( m <= 0 ) return 0;
		if( d == null ) t[b] = { k : k, n : m } else d.n += m;
		take(a, m);
		return m;
	}

	function swap( a : Int, b : Int ) {
		var t = inv.inv.t, x = t[a];
		t[a] = t[b];
		t[b] = x;
	}

	/** clic izquierdo (o A) en la casilla s */
	function leftDown( s : Int, mouse : Bool ) {
		var t = inv.inv.t;
		var now = haxe.Timer.stamp();
		var dbl = s == lastLeft && now - lastLeftTime < DOUBLE;
		lastLeft = s;
		lastLeftTime = now;
		dragging = false;
		if( held == null ) {
			if( t[s] == null ) return;
			held = { from : s, k : t[s].k, n : amount(t[s].n) };
			dragging = mouse;
			moved = false;
			refresh();
			return;
		}
		if( s == held.from ) {
			// doble clic: juntar aqui; si no hay nada que juntar, el clic deja la pila donde estaba
			var got = dbl && gather(s);
			held = null;
			if( got ) changed() else refresh();
			return;
		}
		place(s, amount(held.n));
	}

	/** Mayus = la mitad (redondeando hacia arriba), Ctrl = una, como en la cantina (Chest.click): cuantos de n coge o deja el clic */
	static function amount( n : Int ) : Int {
		var K = hxd.Key;
		return K.isDown(K.CTRL) ? 1 : K.isDown(K.SHIFT) ? Math.ceil(n / 2) : n;
	}

	/** con la pila del cursor: dejar n en s, juntarlos (lo que no cabe sigue en el cursor) o cambiar la pila por la de s */
	function place( s : Int, n : Int ) {
		var t = inv.inv.t, a = held.from, d = t[s];
		if( d == null || d.k == held.k ) {
			var m = moveItems(a, s, n);
			if( m <= 0 ) return; // casilla llena
			held.n -= m;
			if( held.n <= 0 ) held = null;
		} else if( held.n >= t[a].n ) {
			// toda la pila: se cambian las dos casillas y el cursor se queda con la otra, como en Minecraft
			swap(a, s);
			held = { from : a, k : t[a].k, n : t[a].n };
		} else {
			// parte de la pila (clic derecho): la de s necesita una casilla libre; sin ella no se puede
			var e = t.indexOf(null);
			if( e < 0 ) return;
			t[e] = d;
			t[s] = { k : held.k, n : held.n };
			take(a, held.n);
			held = { from : e, k : d.k, n : d.n };
		}
		changed();
	}

	/** arrastre soltado en s: dejar, juntar (lo que no cabe se queda en su casilla) o intercambiar las dos casillas (solo con la
	    pila entera: media pila, con Mayus, no se cambia por otro bloque) */
	function dropOn( s : Int ) {
		var t = inv.inv.t, a = held.from, d = t[s];
		if( d == null || d.k == held.k ) moveItems(a, s, held.n);
		else if( held.n >= t[a].n ) swap(a, s);
		held = null;
		changed();
	}

	/** clic derecho (o X) en la casilla s */
	function rightDown( s : Int, mouse : Bool ) {
		var t = inv.inv.t, d = t[s];
		painted = null;
		if( held == null ) {
			if( d == null ) return;
			held = { from : s, k : d.k, n : Math.ceil(d.n / 2) };
			refresh();
			return;
		}
		if( s == held.from ) {
			// una unidad vuelve a su casilla
			held.n--;
			if( held.n <= 0 ) held = null;
			refresh();
			return;
		}
		if( d != null && d.k != held.k ) {
			place(s, held.n);
			return;
		}
		if( mouse ) painted = [s];
		putOne(s);
	}

	/** deja una unidad de la pila del cursor en s (vacia o del mismo bloque con sitio) */
	function putOne( s : Int ) {
		if( held == null || s == held.from || moveItems(held.from, s, 1) == 0 ) return;
		held.n--;
		if( held.n <= 0 ) held = null;
		changed();
	}

	/** doble clic: junta en s las otras pilas del mismo bloque (primero las incompletas), hasta el maximo */
	function gather( s : Int ) : Bool {
		var t = inv.inv.t, k = t[s].k, max = maxOf(k), got = false;
		for( pass in 0...2 )
			for( i in 0...t.length ) {
				if( i == s || t[s].n >= max ) continue;
				var o = t[i];
				if( o == null || o.k != k || (pass == 0 && o.n >= max) ) continue;
				if( moveItems(i, s, o.n) > 0 ) got = true;
			}
		return got;
	}

	/** tira n bloques de la pila del cursor */
	function throwHeld( n : Int ) {
		if( held == null ) return;
		if( n > held.n ) n = held.n;
		take(held.from, n);
		if( onThrow != null ) onThrow(Block.all[held.k], n);
		held.n -= n;
		if( held.n <= 0 ) held = null;
		changed();
	}

	/** tira la pila entera de la casilla s (R sobre ella, o Y del mando sin nada en el cursor) */
	function throwSlot( s : Int ) {
		var d = inv.inv.t[s];
		if( d == null ) return;
		inv.inv.t[s] = null;
		if( onThrow != null ) onThrow(Block.all[d.k], d.n);
		changed();
	}

	// ---------------------------------------------------------------- teclado y mando

	/** el inventario ha cambiado por otro lado (algo recogido): la pila del cursor se ajusta a lo que queda en su casilla */
	function checkHeld() {
		if( held == null ) return;
		var s = inv.inv.t[held.from];
		if( s == null || s.k != held.k ) {
			held = null;
			dragging = false;
		} else if( held.n > s.n )
			held.n = s.n;
	}

	public function update( dt : Float, pad : hxd.Pad ) {
		checkHeld();
		if( stamp() != shown ) refresh();
		var K = hxd.Key;
		if( K.isPressed(K.ESCAPE) || Keys.pressed("palette") ) {
			if( onClose != null ) onClose();
			return;
		}
		var dx = 0, a = false, x = false, y = false;
		if( K.isPressed(K.LEFT) ) dx = -1;
		if( K.isPressed(K.RIGHT) ) dx = 1;
		if( K.isPressed(K.ENTER) || K.isPressed(K.NUMPAD_ENTER) ) a = true;
		if( pad != null ) {
			if( pad.isPressed(pad.config.dpadLeft) || pad.isPressed(pad.config.LB) ) dx = -1;
			if( pad.isPressed(pad.config.dpadRight) || pad.isPressed(pad.config.RB) ) dx = 1;
			if( pad.isPressed(pad.config.A) ) a = true;
			if( pad.isPressed(pad.config.X) ) x = true;
			if( pad.isPressed(pad.config.Y) ) y = true;
			if( pad.isPressed(pad.config.B) || pad.isPressed(pad.config.ranalogClick) ) {
				if( onClose != null ) onClose();
				return;
			}
		}
		nav(dx, a, x, y);
		// sobre una casilla: 1-0 la cambian con esa casilla (sin nada en el cursor), R / Supr tiran su pila (o la del cursor)
		var over = focus >= 0 ? focus : hover;
		if( over < 0 ) return;
		if( Keys.pressed("drop") ) {
			if( held != null ) throwHeld(held.n) else throwSlot(over);
		} else if( held == null ) {
			for( i in 0...Std.int(Math.min(Keys.SLOT_IDS.length, inv.inv.t.length)) )
				if( i != over && Keys.pressed(Keys.SLOT_IDS[i]) ) {
					swap(over, i);
					changed();
					break;
				}
		}
	}

	/** flechas o cruceta (dx), A/Intro (a), X (x) e Y (y); la orden invscreen nav del banco de pruebas pasa por aqui */
	public function nav( dx : Int, a : Bool, x : Bool, y : Bool ) {
		var n = inv.inv.t.length;
		if( dx != 0 ) {
			focus = focus < 0 ? Std.int(Math.max(0, inv.blockIndex - 1)) : (focus + dx + n) % n;
			hover = -1;
			refresh();
		}
		if( focus < 0 ) return;
		if( a ) leftDown(focus, false);
		if( x ) rightDown(focus, false);
		if( y ) {
			if( held != null ) throwHeld(held.n) else throwSlot(focus);
		}
	}

	/** banco de pruebas (print invscreen) */
	public function devInfo() : String {
		var cells = [for( i in 0...inv.inv.t.length ) shownCount(i) == 0 ? "-" : Block.all[inv.inv.t[i].k].k + "x" + shownCount(i)];
		return "pantalla: " + cells.join(" ") + "  cursor=" + (held == null ? "-" : Block.all[held.k].k + "x" + held.n + " de " + held.from)
			+ " arrastre=" + dragging + " raton=" + hover + " foco=" + focus + " info='" + info.text + "'";
	}
}
