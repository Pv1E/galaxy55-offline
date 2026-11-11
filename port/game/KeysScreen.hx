import Ui;

/**
 * Fila de la pantalla de teclas (KeysScreen): el nombre de la accion y sus Keys.SLOTS casillas. Izquierda/derecha (o el raton)
 * eligen la casilla; Intro o un clic en ella esperan una tecla nueva.
 */
class KeyRow extends Widget {
	public static inline var W = 1040;
	public static inline var H = 38;
	static inline var CELL_X = 420;
	static inline var CELL_W = 146;
	static inline var CELL_GAP = 8;

	public var id(default, null) : String;
	public var slot(default, set) = 0;
	/** la casilla elegida espera una tecla (KeysScreen.listen) */
	public var waiting(default, set) = false;
	public var onSlot : Void -> Void;
	var cellBg : h2d.Graphics;
	var cells : Array<h2d.Text>;
	var keys : Array<Int>;
	var bad : Array<Bool>;

	public function new( parent : h2d.Object, id : String ) {
		super(parent, W, H);
		this.id = id;
		label.setScale(1.9);
		label.text = Keys.label(id);
		cellBg = new h2d.Graphics(this);
		cells = [for( i in 0...Keys.SLOTS ) Theme.text(this, "", 1.7, Theme.CYAN)];
		onLeft = function() if( slot > 0 ) slot--;
		onRight = function() if( slot < Keys.SLOTS - 1 ) slot++;
		// un clic en una casilla la cambia; en el nombre solo da el foco
		inter.onClick = function(e : hxd.Event) if( enabled ) {
			if( onPress != null ) onPress(this);
			var s = slotAt(e.relX);
			if( s < 0 ) return;
			slot = s;
			activate();
		};
		inter.onMove = function(e : hxd.Event) {
			var s = slotAt(e.relX);
			if( focused && s >= 0 && s != slot ) slot = s;
		};
		refresh();
	}

	static inline function cellX( i : Int ) : Float return CELL_X + i * (CELL_W + CELL_GAP);

	function slotAt( x : Float ) : Int {
		for( i in 0...Keys.SLOTS ) if( x >= cellX(i) && x < cellX(i) + CELL_W ) return i;
		return -1;
	}

	function set_slot( v : Int ) {
		slot = v;
		redraw();
		if( onSlot != null ) onSlot();
		return v;
	}

	function set_waiting( v : Bool ) {
		waiting = v;
		refresh();
		return v;
	}

	public function hasConflict() : Bool {
		if( bad != null ) for( b in bad ) if( b ) return true;
		return false;
	}

	/** vuelve a leer las teclas de Keys y sus conflictos */
	public function refresh() {
		if( cells == null ) return;
		keys = Keys.get(id);
		bad = [for( k in keys ) k != Keys.NONE && Keys.conflicts(id, k).length > 0];
		for( i in 0...Keys.SLOTS ) {
			var t = cells[i];
			t.text = waiting && i == slot ? "..." : keys[i] == Keys.NONE ? "-" : Keys.name(keys[i]);
			// que quepa en la casilla
			var tw = t.calcTextWidth(t.text), sc = 1.7;
			if( tw * sc > CELL_W - 12 ) sc = (CELL_W - 12) / tw;
			t.setScale(sc);
			t.x = cellX(i) + Std.int((CELL_W - tw * sc) * 0.5);
			t.y = Std.int((H - t.textHeight * sc) * 0.5);
		}
		redraw();
	}

	override function redraw() {
		super.redraw();
		if( cells == null || keys == null ) return;
		cellBg.clear();
		for( i in 0...Keys.SLOTS ) {
			var on = focused && i == slot, x = cellX(i);
			if( on && waiting ) Theme.rect(cellBg, x, 4, CELL_W, H - 8, Theme.ACCENT, 0.55);
			else if( on ) Theme.rect(cellBg, x, 4, CELL_W, H - 8, Theme.ACCENT, 0.28);
			else Theme.rect(cellBg, x, 4, CELL_W, H - 8, bad[i] ? Theme.DANGER : 0xFFFFFF, bad[i] ? 0.14 : 0.06);
			if( on ) Theme.rect(cellBg, x, H - 6, CELL_W, 2, Theme.ACCENT);
			cells[i].textColor = bad[i] ? Theme.DANGER : on ? Theme.TEXT : keys[i] == Keys.NONE ? Theme.DISABLED : Theme.CYAN;
		}
		if( !focused && hasConflict() ) label.textColor = Theme.DANGER;
	}
}

/**
 * Opciones > Controles > Configurar teclas (anadido del port): las acciones de Keys por secciones, en una lista que se desplaza
 * (rueda, flechas, Re Pag / Av Pag, mando). Intro o un clic en una casilla espera una tecla o un boton del raton, con Mayus, Ctrl
 * o Alt si se mantienen (Esc o B cancelan); Supr o Retroceso la borran. Una tecla que otra accion ya usa en el mismo sitio se
 * queda en las dos, en rojo, y abajo se dice cual es la otra. Cada cambio se guarda en settings.json.
 */
class KeysScreen extends Screen {
	/** lineas a la vista: el panel (GalaxyApp.buildKeys) mide TOP + VISIBLE * STEP + BOTTOM y no llega al inventario de arriba */
	public static inline var VISIBLE = 10;
	public static inline var STEP = 40;
	public static inline var TOP = 88;
	public static inline var BOTTOM = 110;

	public var rows = new Array<KeyRow>();
	/** boton Restablecer (GalaxyApp pide confirmacion y llama a resetDone) */
	public var onReset : Void -> Void;
	/** titulos de seccion (h2d.Text) y filas, en orden */
	var lines = new Array<h2d.Object>();
	var lineOf = new Array<Int>();
	var top = 0;
	var listX = 0.;
	var listY = 0.;
	var bar : h2d.Graphics;
	var info : h2d.Text;
	var capture : KeyRow;
	var captureFrame = -1;
	/** tapa los controles mientras se espera una tecla: el clic que se elige no debe pulsar un boton (se quita al soltarlo) */
	var shield : h2d.Interactive;
	/** mensaje hasta que se mueve el foco (teclas restablecidas) */
	var note : String;
	/** se espera una tecla: las del juego (F2 captura) no deben hacer nada mientras */
	public var capturing(get, never) : Bool;
	inline function get_capturing() return capture != null;

	/** despues del fondo del panel (GalaxyApp.buildKeys): la lista empieza en x, y; debajo, el mensaje y los botones */
	public function build( x : Float, y : Float, leave : Void -> Void ) {
		listX = x;
		listY = y;
		for( g in Keys.GROUPS ) {
			lines.push(Theme.text(this, Lang.t("keys.group." + g), 1.6, Theme.ACCENT));
			for( a in Keys.ACTIONS ) {
				if( a.group != g ) continue;
				var r = new KeyRow(this, a.id);
				add(r, x, 0);
				r.onActivate = function() startCapture(r);
				r.onSlot = function() if( focus < rows.length && rows[focus] == r ) showInfo();
				lineOf.push(lines.length);
				lines.push(r);
				rows.push(r);
			}
		}
		bar = new h2d.Graphics(this);
		var by = y + VISIBLE * STEP;
		info = Theme.text(this, "", 1.6, Theme.DIM, x, by + 6);
		var reset = new Button(this, Lang.t("keys.reset"), 620, 50);
		add(reset, x, by + 38);
		reset.onActivate = function() if( onReset != null ) onReset();
		var back = new Button(this, Lang.t("back"), 300, 50);
		add(back, x + KeyRow.W - 300, by + 38);
		back.onActivate = leave;
		onBack = leave;
		layout();
		showInfo();
	}

	/** tras restablecer las teclas por defecto */
	public function resetDone() {
		for( r in rows ) r.refresh();
		note = Lang.t("keys.reset.done");
		showInfo();
	}

	override function setFocus( i : Int ) {
		super.setFocus(i);
		if( i >= 0 && i < rows.length ) {
			var l = lineOf[i];
			// la primera fila de una seccion se ve con su titulo
			var first = Std.isOfType(lines[l - 1], KeyRow) ? l : l - 1;
			if( first < top ) top = first;
			if( l >= top + VISIBLE ) top = l - VISIBLE + 1;
			layout();
		}
		note = null;
		showInfo();
	}

	/** rueda del raton: desplaza la lista; si la fila con el foco sale de la vista, el foco pasa a la mas cercana */
	public function scroll( d : Int ) {
		if( capture != null ) return;
		var t = top + d * 2, max = lines.length - VISIBLE;
		if( t > max ) t = max;
		if( t < 0 ) t = 0;
		if( t == top ) return;
		top = t;
		if( focus < rows.length ) {
			var l = lineOf[focus];
			if( l < top || l >= top + VISIBLE ) {
				var best = -1;
				for( i in 0...rows.length ) {
					var li = lineOf[i];
					if( li >= top && li < top + VISIBLE && (best < 0 || Math.abs(li - l) < Math.abs(lineOf[best] - l)) ) best = i;
				}
				if( best >= 0 ) super.setFocus(best);
			}
		}
		layout();
		showInfo();
	}

	function layout() {
		for( i in 0...lines.length ) {
			var o = lines[i];
			o.visible = i >= top && i < top + VISIBLE;
			var ly = listY + (i - top) * STEP;
			if( Std.isOfType(o, KeyRow) ) {
				o.x = listX;
				o.y = ly + 1;
			} else {
				var t : h2d.Text = cast o;
				t.x = listX + 8;
				t.y = ly + Std.int((STEP - t.textHeight * t.scaleY) * 0.5) + 4;
			}
		}
		bar.clear();
		if( lines.length > VISIBLE ) {
			var bx = listX + KeyRow.W + 12, h = VISIBLE * STEP - 4;
			var th = h * VISIBLE / lines.length;
			Theme.rect(bar, bx, listY, 6, h, 0xFFFFFF, 0.08);
			Theme.rect(bar, bx, listY + (h - th) * top / (lines.length - VISIBLE), 6, th, Theme.ACCENT, 0.8);
		}
	}

	override function update( dt : Float, pad : hxd.Pad ) {
		if( !active ) return;
		if( capture != null ) {
			listen(pad);
			return;
		}
		var K = hxd.Key;
		if( shield != null && !K.isDown(K.MOUSE_LEFT) && !K.isDown(K.MOUSE_RIGHT) && !K.isDown(K.MOUSE_MIDDLE) ) {
			shield.remove();
			shield = null;
		}
		if( focus < rows.length ) {
			var page = K.isPressed(K.PGDOWN) ? 1 : K.isPressed(K.PGUP) ? -1 : 0;
			if( page != 0 ) {
				var i = focus + page * (VISIBLE - 2);
				setFocus(i < 0 ? 0 : i >= rows.length ? rows.length - 1 : i);
			}
			if( K.isPressed(K.DELETE) || K.isPressed(K.BACKSPACE) ) assign(rows[focus], Keys.NONE);
		}
		super.update(dt, pad);
	}

	function startCapture( r : KeyRow ) {
		if( capture != null ) return;
		capture = r;
		captureFrame = hxd.Timer.frameCount;
		r.waiting = true;
		if( shield == null ) {
			shield = new h2d.Interactive(Theme.W * 3, Theme.H * 3, this);
			shield.x = -Theme.W;
			shield.y = -Theme.H;
			shield.enableRightButton = true;
			shield.cursor = Default;
		}
		showInfo();
	}

	function stopCapture() {
		if( capture == null ) return;
		var r = capture;
		capture = null;
		r.waiting = false;
		showInfo();
	}

	/** la primera tecla o boton que se pulse (Mayus, Ctrl y Alt solos, al soltarlos); Esc o B cancelan */
	function listen( pad : hxd.Pad ) {
		var K = hxd.Key;
		if( hxd.Timer.frameCount == captureFrame ) return;
		if( K.isPressed(K.ESCAPE) || (pad != null && pad.isPressed(pad.config.B)) ) {
			stopCapture();
			return;
		}
		for( c in 0...256 ) {
			if( c == K.MOUSE_WHEEL_UP || c == K.MOUSE_WHEEL_DOWN || c == K.ESCAPE || Keys.isModifier(c) || !K.isPressed(c) ) continue;
			var r = capture;
			stopCapture();
			assign(r, c | Keys.heldMods(c));
			return;
		}
		for( m in [K.SHIFT, K.CTRL, K.ALT] )
			if( K.isReleased(m) ) {
				var r = capture;
				stopCapture();
				assign(r, m);
				return;
			}
	}

	function assign( r : KeyRow, k : Int ) {
		Keys.set(r.id, r.slot, k);
		Settings.save();
		for( o in rows ) o.refresh();
		note = null;
		showInfo();
	}

	/** abajo: lo que se espera, la otra accion de una tecla en rojo o la ayuda */
	function showInfo() {
		if( info == null ) return;
		var s = Lang.t("keys.hint"), col = Theme.DIM;
		if( capture != null ) {
			s = Lang.t("keys.press").split("%a%").join(Keys.label(capture.id));
			col = Theme.ACCENT;
		} else if( note != null ) {
			s = note;
			col = Theme.CYAN;
		} else if( focus < rows.length ) {
			var r = rows[focus];
			var others = Keys.conflicts(r.id, Keys.get(r.id)[r.slot]);
			if( others.length > 0 ) {
				s = Lang.t("keys.conflict").split("%a%").join([for( id in others ) Keys.label(id)].join(", "));
				col = Theme.DANGER;
			}
		}
		info.text = s;
		info.textColor = col;
		var tw = info.calcTextWidth(s), sc = 1.6;
		if( tw * sc > KeyRow.W ) sc = KeyRow.W / tw;
		info.setScale(sc);
		info.x = listX + Std.int((KeyRow.W - tw * sc) * 0.5);
	}
}
