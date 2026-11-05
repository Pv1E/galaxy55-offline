/** Colores y utilidades de estilo del juego. */
class Theme {
	public static inline var BG = 0x070B16;
	public static inline var PANEL = 0x0E1526;
	public static inline var ACCENT = 0xFF9A1F;
	public static inline var CYAN = 0x4CC9F0;
	public static inline var TEXT = 0xE8EEF9;
	public static inline var DIM = 0x8693B3;
	public static inline var DISABLED = 0x4A5470;
	public static inline var DANGER = 0xFF5C5C;

	/** zona de diseno de la interfaz: la escena 2D usa LetterBox(W, H) (GalaxyApp) */
	public static inline var W = 1280;
	public static inline var H = 720;

	public static var font : h2d.Font;

	public static function init() {
		font = hxd.res.DefaultFont.get();
		font.tile.getTexture().filter = Nearest;
	}

	public static function text( parent : h2d.Object, str : String, scale : Float, color : Int, ?x : Float = 0, ?y : Float = 0 ) : h2d.Text {
		var t = new h2d.Text(font, parent);
		t.text = str;
		t.setScale(scale);
		t.textColor = color;
		t.x = x;
		t.y = y;
		return t;
	}

	/** centra un texto, medido con su escala, en una caja de w x h que empieza en el 0,0 de su padre */
	public static function center( t : h2d.Text, w : Float, h : Float ) {
		t.x = Std.int((w - t.textWidth * t.scaleX) * 0.5);
		t.y = Std.int((h - t.textHeight * t.scaleY) * 0.5);
	}

	public static function rect( g : h2d.Graphics, x : Float, y : Float, w : Float, h : Float, color : Int, alpha : Float = 1.0 ) {
		g.beginFill(color, alpha);
		g.drawRect(x, y, w, h);
		g.endFill();
	}

	/*
	 * Con LetterBox la zona W x H no llega a los bordes de una ventana mas ancha o mas alta que 16:9: quedan bandas a los lados o
	 * arriba y abajo. Todo lo que deba tapar la ventana entera (velos, oscurecido detras de un menu, la tienda, la
	 * paleta, el fondo del mapa de estrellas) se dibuja con fullRect o se agranda con coverWindow, nunca como un rectangulo
	 * 0, 0, W, H. Lo que deba pegarse a un borde real de la ventana se coloca con visibleArea. port/dev/fullwindow.txt lo comprueba.
	 */

	/** oscurecido o fondo de pantalla completa: 3 veces la zona W x H alrededor de ella */
	public static function fullRect( g : h2d.Graphics, color : Int, alpha : Float ) {
		rect(g, -W, -H, W * 3, H * 3, color, alpha);
	}

	/** un velo de W x H (Bitmap) agrandado 3 veces alrededor de la zona, como fullRect */
	public static function coverWindow( o : h2d.Object ) {
		o.x = -W;
		o.y = -H;
		o.setScale(3);
	}

	/** parte de la escena 2D que se ve en la ventana, en coordenadas de la zona W x H */
	public static function visibleArea() : { x : Float, y : Float, w : Float, h : Float } {
		var e = h3d.Engine.getCurrent();
		var scale = Math.min(e.width / W, e.height / H);
		var w = e.width / scale, h = e.height / scale;
		return { x : (W - w) * 0.5, y : (H - h) * 0.5, w : w, h : h };
	}
}

/** Control con foco: se navega con teclado, mando o raton. */
class Widget extends h2d.Object {
	public var w(default, null) : Int;
	public var h(default, null) : Int;
	public var enabled(default, set) = true;
	public var focused(default, set) = false;
	public var onActivate : Void -> Void;
	public var onLeft : Void -> Void;
	public var onRight : Void -> Void;
	public var onHover : Widget -> Void;
	public var onPress : Widget -> Void;
	var bg : h2d.Graphics;
	var label : h2d.Text;
	var inter : h2d.Interactive;

	public function new( parent : h2d.Object, w : Int, h : Int ) {
		super(parent);
		this.w = w;
		this.h = h;
		bg = new h2d.Graphics(this);
		label = Theme.text(this, "", 2.2, Theme.TEXT, 22, 0);
		inter = new h2d.Interactive(w, h, this);
		inter.onOver = function(_) if( enabled && onHover != null ) onHover(this);
		inter.onClick = function(_) if( enabled ) {
			if( onPress != null ) onPress(this);
			activate();
		}
		redraw();
	}

	public function activate() {
		if( enabled && onActivate != null ) onActivate();
	}

	public function setLabel( s : String ) {
		label.text = s;
		redraw();
	}

	function set_enabled( v : Bool ) {
		enabled = v;
		redraw();
		return v;
	}

	function set_focused( v : Bool ) {
		focused = v;
		redraw();
		return v;
	}

	function redraw() {
		bg.clear();
		var col = !enabled ? Theme.DISABLED : (focused ? Theme.ACCENT : Theme.TEXT);
		if( focused && enabled ) {
			Theme.rect(bg, 0, 0, w, h, Theme.ACCENT, 0.16);
			Theme.rect(bg, 0, 0, 5, h, Theme.ACCENT);
			Theme.rect(bg, 0, h - 2, w, 2, Theme.ACCENT, 0.55);
		} else {
			Theme.rect(bg, 0, 0, w, h, 0xFFFFFF, enabled ? 0.04 : 0.02);
			Theme.rect(bg, 0, h - 1, w, 1, 0xFFFFFF, 0.08);
		}
		label.textColor = col;
		label.y = (h - label.textHeight * label.scaleY) * 0.5;
	}
}

class Button extends Widget {
	public function new( parent : h2d.Object, text : String, w = 460, h = 54 ) {
		super(parent, w, h);
		setLabel(text);
	}
}

/** Elige entre varias opciones con izquierda/derecha. */
class Selector extends Widget {
	public var title : String;
	public var choices : Array<String>;
	public var index(default, set) = 0;
	public var onChange : Int -> Void;
	var value : h2d.Text;

	public function new( parent : h2d.Object, title : String, choices : Array<String>, w = 560, h = 54 ) {
		super(parent, w, h);
		this.title = title;
		this.choices = choices;
		label.text = title;
		value = Theme.text(this, "", 2.2, Theme.CYAN);
		onLeft = function() step(-1);
		onRight = function() step(1);
		onActivate = function() step(1);
		// un clic en la flecha "<" va a la opcion anterior (antes iba a la siguiente, como un clic en el resto de la fila)
		inter.onClick = function(e : hxd.Event) if( enabled ) {
			if( onPress != null ) onPress(this);
			if( e.relX >= value.x - 20 && e.relX < value.x + value.calcTextWidth("<  ") * value.scaleX ) step(-1) else activate();
		}
		refresh();
	}

	public function step( d : Int ) {
		if( !enabled || choices.length == 0 ) return;
		index = (index + d + choices.length) % choices.length;
		if( onChange != null ) onChange(index);
	}

	function set_index( v : Int ) {
		index = v;
		refresh();
		return v;
	}

	public function setChoices( c : Array<String> ) {
		choices = c;
		if( index >= c.length ) index = 0;
		refresh();
	}

	public function setTitle( t : String ) {
		title = t;
		refresh();
	}

	function refresh() {
		if( value == null ) return;
		label.text = title;
		value.text = "<  " + (choices.length > 0 ? choices[index] : "") + "  >";
		value.x = w - 22 - value.textWidth * value.scaleX;
		redraw();
	}

	override function redraw() {
		super.redraw();
		if( value == null ) return;
		value.textColor = !enabled ? Theme.DISABLED : (focused ? Theme.ACCENT : Theme.CYAN);
		value.y = (h - value.textHeight * value.scaleY) * 0.5;
	}
}

/** Valor numerico con barra. */
class Slider extends Widget {
	public var title : String;
	public var min : Float;
	public var max : Float;
	public var stepSize : Float;
	public var value(default, set) : Float;
	public var onChange : Float -> Void;
	public var unit = "";
	public var decimals = 0;
	static inline var BAR_W = 200;

	inline function barX() : Float return w - 22 - 72 - BAR_W;
	var txt : h2d.Text;
	var bar : h2d.Graphics;

	public function new( parent : h2d.Object, title : String, min : Float, max : Float, stepSize : Float, w = 560, h = 54 ) {
		super(parent, w, h);
		this.title = title;
		this.min = min;
		this.max = max;
		this.stepSize = stepSize;
		bar = new h2d.Graphics(this);
		txt = Theme.text(this, "", 2.2, Theme.CYAN);
		label.text = title;
		onLeft = function() change(-1);
		onRight = function() change(1);
		// el raton arrastra la barra
		inter.onPush = function(e) setFromMouse(e.relX);
		inter.onMove = function(e) if( hxd.Key.isDown(hxd.Key.MOUSE_LEFT) ) setFromMouse(e.relX);
		value = min;
	}

	function setFromMouse( rx : Float ) {
		if( !enabled ) return;
		var x0 = barX(), x1 = x0 + BAR_W;
		var f = (rx - x0) / (x1 - x0);
		if( f < 0 ) f = 0;
		if( f > 1 ) f = 1;
		var v = min + Math.round((f * (max - min)) / stepSize) * stepSize;
		if( v != value ) {
			value = v;
			if( onChange != null ) onChange(value);
		}
	}

	function change( d : Int ) {
		if( !enabled ) return;
		var v = value + d * stepSize;
		if( v < min ) v = min;
		if( v > max ) v = max;
		if( v != value ) {
			value = v;
			if( onChange != null ) onChange(value);
		}
	}

	public function setTitle( t : String ) {
		title = t;
		label.text = t;
	}

	function set_value( v : Float ) {
		value = v;
		if( txt != null ) refreshBar();
		return v;
	}

	function fmt( v : Float ) : String {
		if( decimals == 0 ) return "" + Math.round(v);
		var s = "" + Math.round(v * 10) / 10;
		if( s.indexOf(".") < 0 ) s += ".0";
		return s;
	}

	function refreshBar() {
		txt.text = fmt(value) + unit;
		txt.x = w - 22 - txt.textWidth * txt.scaleX;
		redraw();
	}

	override function redraw() {
		super.redraw();
		if( bar == null || txt == null ) return;
		var x0 = barX(), f = (value - min) / (max - min);
		bar.clear();
		Theme.rect(bar, x0, h * 0.5 - 3, BAR_W, 6, 0xFFFFFF, 0.12);
		Theme.rect(bar, x0, h * 0.5 - 3, BAR_W * f, 6, focused ? Theme.ACCENT : Theme.CYAN);
		Theme.rect(bar, x0 + BAR_W * f - 4, h * 0.5 - 10, 8, 20, focused ? Theme.ACCENT : Theme.CYAN);
		txt.textColor = !enabled ? Theme.DISABLED : (focused ? Theme.ACCENT : Theme.CYAN);
		txt.y = (h - txt.textHeight * txt.scaleY) * 0.5;
	}
}

/** Campo de texto editable. */
class TextField extends Widget {
	public var title : String;
	public var input : h2d.TextInput;
	public var typing(default, null) = false;
	public var maxLen = 24;
	public var numeric = false;
	public var onType : String -> Void;
	/** Intro mientras se escribe (p. ej. aceptar el nombre en la ventana de renombrar) */
	public var onEnter : Void -> Void;
	/** fotograma en el que se dejo de escribir: h2d.TextInput recibe Intro y Esc antes que Screen.update, que no debe volver a usarlos */
	public var stoppedFrame(default, null) = -1;

	public function new( parent : h2d.Object, title : String, text : String, w = 560, h = 54, inputW = 250 ) {
		super(parent, w, h);
		this.title = title;
		label.text = title;
		input = new h2d.TextInput(Theme.font, this);
		input.setScale(2.2);
		input.text = text;
		input.textColor = Theme.CYAN;
		input.x = w - 22 - inputW;
		input.y = (h - Theme.font.lineHeight * 2.2) * 0.5;
		input.inputWidth = Std.int(inputW / 2.2);
		input.backgroundColor = 0x33000000;		input.onFocus = function(_) { typing = true; focused = true; }
		input.onFocusLost = function(_) {
			typing = false;
			stoppedFrame = hxd.Timer.frameCount;
		}
		input.onChange = function() {
			if( numeric ) {
				var s = "";
				for( i in 0...input.text.length ) {
					var c = input.text.charCodeAt(i);
					if( c >= 48 && c <= 57 ) s += String.fromCharCode(c);
				}
				if( s != input.text ) input.text = s;
			}
			if( input.text.length > maxLen ) input.text = input.text.substr(0, maxLen);
			if( onType != null ) onType(input.text);
		};
		// ocupa el hueco del Interactive de la fila: un clic sobre la fila da el foco al campo
		onActivate = function() input.focus();
	}

	public function setTitle( t : String ) {
		title = t;
		label.text = t;
	}

	public function stopTyping() {
		if( typing ) {
			input.blur();
			typing = false;
		}
	}

	/** empezar a escribir con todo el texto elegido (lo que se teclee lo sustituye) */
	public function startTyping() {
		input.focus();
		input.cursorIndex = input.text.length;
		input.selectionRange = input.text.length > 0 ? { start : 0, length : input.text.length } : null;
	}

	public var text(get, set) : String;
	function get_text() return input.text;
	function set_text( v : String ) return input.text = v;
}

/** Una pantalla de menu: lista de controles con foco y navegacion. */
class Screen extends h2d.Object {
	public var widgets = new Array<Widget>();
	public var focus(default, null) = 0;
	public var onBack : Void -> Void;
	public var active = true;
	var navCooldown = 0.;
	/** punto de la ventana donde se ha dejado el puntero (holdHover) */
	var heldX = -1;
	var heldY = -1;

	public function new( parent : h2d.Object ) {
		super(parent);
	}

	/** el control que queda bajo el puntero no se lleva el foco hasta que se mueva el raton (GalaxyApp.centerMouse) */
	public function holdHover() {
		var win = hxd.Window.getInstance();
		heldX = win.mouseX;
		heldY = win.mouseY;
	}

	public function add( w : Widget, x : Float, y : Float ) : Widget {
		w.x = x;
		w.y = y;
		addChild(w);
		widgets.push(w);
		w.onHover = function(o) {
			var win = hxd.Window.getInstance();
			if( win.mouseX == heldX && win.mouseY == heldY ) return;
			heldX = -1;
			setFocus(widgets.indexOf(o));
		};
		w.onPress = function(o) setFocus(widgets.indexOf(o));
		return w;
	}

	public function setFocus( i : Int ) {
		if( i < 0 || i >= widgets.length ) return;
		for( k in 0...widgets.length ) widgets[k].focused = (k == i);
		focus = i;
	}

	public function firstEnabled() {
		for( i in 0...widgets.length )
			if( widgets[i].enabled ) {
				setFocus(i);
				return;
			}
	}

	function moveFocus( d : Int ) {
		if( widgets.length == 0 ) return;
		var i = focus;
		for( k in 0...widgets.length ) {
			i = (i + d + widgets.length) % widgets.length;
			if( widgets[i].enabled ) break;
		}
		setFocus(i);
	}

	/** el campo en el que se esta escribiendo o en el que se acaba de dejar de escribir en este fotograma (con Intro o Esc) */
	function typingField() : TextField {
		for( w in widgets )
			if( Std.isOfType(w, TextField) ) {
				var t = cast(w, TextField);
				if( t.typing || t.stoppedFrame == hxd.Timer.frameCount ) return t;
			}
		return null;
	}

	public function update( dt : Float, pad : hxd.Pad ) {
		if( !active || widgets.length == 0 ) return;
		var K = hxd.Key;
		if( navCooldown > 0 ) navCooldown -= dt;

		var up = K.isPressed(K.UP), down = K.isPressed(K.DOWN);
		var left = K.isPressed(K.LEFT), right = K.isPressed(K.RIGHT);
		var ok = K.isPressed(K.ENTER) || K.isPressed(K.NUMPAD_ENTER) || K.isPressed(K.SPACE);
		var back = K.isPressed(K.ESCAPE);
		if( pad != null ) {
			if( pad.isPressed(pad.config.dpadUp) ) up = true;
			if( pad.isPressed(pad.config.dpadDown) ) down = true;
			if( pad.isPressed(pad.config.dpadLeft) ) left = true;
			if( pad.isPressed(pad.config.dpadRight) ) right = true;
			if( pad.isPressed(pad.config.A) ) ok = true;
			if( pad.isPressed(pad.config.B) ) back = true;
			if( navCooldown <= 0 ) {
				if( pad.yAxis < -0.6 ) { up = true; navCooldown = 0.18; }
				else if( pad.yAxis > 0.6 ) { down = true; navCooldown = 0.18; }
				else if( pad.xAxis < -0.6 ) { left = true; navCooldown = 0.18; }
				else if( pad.xAxis > 0.6 ) { right = true; navCooldown = 0.18; }
			}
		}

		var field = typingField();
		if( field != null ) {
			// mientras se escribe solo Intro/Esc/flechas verticales (o A/B y la cruceta del mando) salen del campo; Esc no cierra la pantalla
			var enter = K.isPressed(K.ENTER) || K.isPressed(K.NUMPAD_ENTER);
			var padExit = pad != null && (pad.isPressed(pad.config.A) || pad.isPressed(pad.config.B) || pad.isPressed(pad.config.dpadUp) || pad.isPressed(pad.config.dpadDown));
			if( enter || padExit || K.isPressed(K.ESCAPE) || K.isPressed(K.UP) || K.isPressed(K.DOWN) || K.isPressed(K.TAB) ) {
				for( w in widgets ) if( Std.isOfType(w, TextField) ) cast(w, TextField).stopTyping();
				if( K.isPressed(K.DOWN) || (pad != null && pad.isPressed(pad.config.dpadDown)) ) moveFocus(1);
				if( K.isPressed(K.UP) || (pad != null && pad.isPressed(pad.config.dpadUp)) ) moveFocus(-1);
				if( enter && field.onEnter != null ) field.onEnter();
			}
			return;
		}

		if( up ) moveFocus(-1);
		if( down || K.isPressed(K.TAB) ) moveFocus(1);
		var cur = widgets[focus];
		if( left && cur.onLeft != null ) cur.onLeft();
		if( right && cur.onRight != null ) cur.onRight();
		if( ok ) cur.activate();
		if( back && onBack != null ) onBack();
	}
}
