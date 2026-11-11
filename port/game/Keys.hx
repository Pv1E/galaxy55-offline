import hxd.Key as K;

typedef KeyAction = {
	var id : String;
	/** seccion de la pantalla de teclas (keys.group.*) */
	var group : String;
	/** FOOT y/o PILOT: dos acciones solo chocan si se usan en el mismo sitio */
	var where : Int;
	var def : Array<Int>;
}

/**
 * Teclas del juego (anadido del port): cada accion tiene hasta SLOTS teclas o botones del raton, que se cambian en
 * Opciones > Controles > Configurar teclas (KeysScreen) y se guardan en settings.json (Settings). Por defecto son las de siempre.
 * Esc, las teclas de dentro de los menus (flechas, Intro, Espacio, Tab, Mayus y Ctrl en la cantina y la tienda, 1-9 con el robot,
 * el editor de kubes), la rueda del raton y el mando no cambian.
 *
 * Una tecla es su codigo de hxd.Key (los botones del raton son 0, 1 y 2); con Mayus, Ctrl o Alt mantenidos (Mayus+K) lleva
 * ademas MOD_SHIFT, MOD_CTRL o MOD_ALT. Sin modificador vale aunque haya uno pulsado: se anda con W mientras se excava con Mayus.
 */
class Keys {

	public static inline var SLOTS = 4;
	public static inline var NONE = -1;
	public static inline var MOD_SHIFT = 0x10000;
	public static inline var MOD_CTRL = 0x20000;
	public static inline var MOD_ALT = 0x40000;
	static inline var MODS = MOD_SHIFT | MOD_CTRL | MOD_ALT;
	static inline var CODE = 0xFFFF;

	static inline var FOOT = 1;
	static inline var PILOT = 2;

	/** los rellena build, antes que ACTIONS */
	static var byId : Map<String, KeyAction>;
	static var cur : Map<String, Array<Int>>;
	/** textos con las teclas ya puestas (fill): se vacia al cambiar una tecla */
	static var filled = new Map<String, String>();

	public static var GROUPS = ["move", "action", "slots", "interface", "pilot"];
	public static var ACTIONS : Array<KeyAction> = build();
	/** casillas 1 a 10, en el orden de GameView.updateAction */
	public static var SLOT_IDS = [for( i in 1...11 ) "slot" + i];

	static function build() : Array<KeyAction> {
		inline function a( id, group, where, def ) : KeyAction return { id : id, group : group, where : where, def : def };
		var l = [
			a("forward", "move", FOOT | PILOT, [K.W, K.Z, K.UP, K.NUMPAD_8]),
			a("back", "move", FOOT | PILOT, [K.S, K.DOWN, K.NUMPAD_2]),
			a("left", "move", FOOT | PILOT, [K.A, K.Q, K.LEFT, K.NUMPAD_4]),
			a("right", "move", FOOT | PILOT, [K.D, K.RIGHT, K.NUMPAD_6]),
			// X tambien hace avanzar (GameView.update): es "avanzar despacio"
			a("slow", "move", FOOT, [K.X]),
			a("jump", "move", FOOT, [K.SPACE, K.CTRL]),
			a("action", "action", FOOT, [K.MOUSE_LEFT, K.E, K.SHIFT]),
			a("synth", "action", FOOT, [K.MOUSE_RIGHT]),
			a("copy", "action", FOOT, [K.MOUSE_MIDDLE]),
			a("drop", "action", FOOT, [K.R, K.DELETE]),
			a("digger", "action", FOOT, [K.TAB]),
			a("ship", "action", FOOT, [K.K | MOD_SHIFT]),
		];
		for( i in 1...11 ) l.push(a("slot" + i, "slots", FOOT, [K.NUMBER_0 + i % 10]));
		l = l.concat([
			a("helmet", "interface", FOOT | PILOT, [K.H]),
			a("fps", "interface", FOOT | PILOT, [K.F]),
			a("palette", "interface", FOOT, [K.I]),
			a("save", "interface", FOOT | PILOT, [K.F5]),
			a("screenshot", "interface", FOOT | PILOT, [K.F2]),
			a("leave", "pilot", PILOT, [K.E]),
		]);
		byId = [for( x in l ) x.id => x];
		cur = [for( x in l ) x.id => padded(x.def)];
		return l;
	}

	static function padded( keys : Array<Int> ) : Array<Int> {
		return [for( i in 0...SLOTS ) i < keys.length ? keys[i] : NONE];
	}

	// ---------------------------------------------------------------- en el juego

	/** con la cantina abierta (menuKeys = false) las flechas e Intro son de su ventana (Chest.update) y no cuentan */
	public static function down( id : String, menuKeys = true ) : Bool {
		for( k in cur.get(id) )
			if( k != NONE && K.isDown(k & CODE) && modsDown(k) && (menuKeys || !isMenuKey(k)) ) return true;
		return false;
	}

	public static function pressed( id : String, menuKeys = true ) : Bool {
		for( k in cur.get(id) )
			if( k != NONE && K.isPressed(k & CODE) && modsDown(k) && (menuKeys || !isMenuKey(k)) ) return true;
		return false;
	}

	static function modsDown( k : Int ) : Bool {
		return (k & MOD_SHIFT == 0 || K.isDown(K.SHIFT)) && (k & MOD_CTRL == 0 || K.isDown(K.CTRL)) && (k & MOD_ALT == 0 || K.isDown(K.ALT));
	}

	static function isMenuKey( k : Int ) : Bool {
		var c = k & CODE;
		return c == K.UP || c == K.DOWN || c == K.LEFT || c == K.RIGHT || c == K.ENTER || c == K.NUMPAD_ENTER;
	}

	public static function isModifier( code : Int ) : Bool {
		return code == K.SHIFT || code == K.CTRL || code == K.ALT;
	}

	/** modificadores pulsados ahora (para una combinacion), sin contar la propia tecla */
	public static function heldMods( code : Int ) : Int {
		var m = 0;
		if( code != K.SHIFT && K.isDown(K.SHIFT) ) m |= MOD_SHIFT;
		if( code != K.CTRL && K.isDown(K.CTRL) ) m |= MOD_CTRL;
		if( code != K.ALT && K.isDown(K.ALT) ) m |= MOD_ALT;
		return m;
	}

	// ---------------------------------------------------------------- cambiar y guardar

	public static function get( id : String ) : Array<Int> return cur.get(id).copy();

	/** pone la tecla k (o NONE) en la casilla slot; si ya estaba en otra casilla de la misma accion, se quita de alli */
	public static function set( id : String, slot : Int, k : Int ) {
		var l = cur.get(id);
		if( l == null || slot < 0 || slot >= SLOTS ) return;
		if( k != NONE ) for( i in 0...SLOTS ) if( l[i] == k ) l[i] = NONE;
		l[slot] = k;
		filled = new Map();
	}

	public static function reset() {
		for( a in ACTIONS ) cur.set(a.id, padded(a.def));
		filled = new Map();
	}

	public static function isDefault() : Bool {
		for( a in ACTIONS ) if( !same(cur.get(a.id), padded(a.def)) ) return false;
		return true;
	}

	static function same( x : Array<Int>, y : Array<Int> ) : Bool {
		for( i in 0...SLOTS ) if( x[i] != y[i] ) return false;
		return true;
	}

	/** settings.json: solo las acciones cambiadas, asi una accion nueva o un valor por defecto nuevo llegan a todos */
	public static function save() : Dynamic {
		var o = {};
		for( a in ACTIONS ) {
			var l = cur.get(a.id);
			if( !same(l, padded(a.def)) ) Reflect.setField(o, a.id, l.copy());
		}
		return o;
	}

	public static function load( o : Dynamic ) {
		reset();
		if( o == null ) return;
		for( id in Reflect.fields(o) ) {
			var v : Dynamic = Reflect.field(o, id);
			if( !byId.exists(id) || !Std.isOfType(v, Array) ) continue;
			var src : Array<Dynamic> = v;
			var l = [for( i in 0...SLOTS ) i < src.length ? code(src[i]) : NONE];
			cur.set(id, l);
		}
		filled = new Map();
	}

	/** un numero del json (entero o no) o NONE */
	static function code( v : Dynamic ) : Int {
		if( !Std.isOfType(v, Int) && !Std.isOfType(v, Float) ) return NONE;
		var n = Std.int(v);
		return n >= 0 && n & CODE < 256 ? n : NONE;
	}

	// ---------------------------------------------------------------- conflictos

	/** otras acciones que se usan en el mismo sitio y que salen con la tecla k (Mayus+K tambien hace K) */
	public static function conflicts( id : String, k : Int ) : Array<String> {
		var out = [];
		if( k == NONE ) return out;
		var where = byId.get(id).where;
		for( a in ACTIONS ) {
			if( a.id == id || a.where & where == 0 ) continue;
			for( o in cur.get(a.id) )
				if( o != NONE && clash(k, o) ) {
					out.push(a.id);
					break;
				}
		}
		return out;
	}

	static function clash( x : Int, y : Int ) : Bool {
		if( x & CODE != y & CODE ) return false;
		var mx = x & MODS, my = y & MODS;
		return mx == my || mx == 0 || my == 0;
	}

	// ---------------------------------------------------------------- nombres

	/** nombre de la accion en la pantalla de teclas */
	public static function label( id : String ) : String {
		if( StringTools.startsWith(id, "slot") ) return Lang.t("key.slot").split("%n%").join(id.substr(4));
		return Lang.t("key." + id);
	}

	/** nombre de una tecla (short: el de la ayuda en pantalla, "Clic" en vez de "Clic izquierdo") */
	public static function name( k : Int, short = false ) : String {
		if( k == NONE ) return "";
		var s = "";
		if( k & MOD_CTRL != 0 ) s += "Ctrl+";
		if( k & MOD_ALT != 0 ) s += "Alt+";
		if( k & MOD_SHIFT != 0 ) s += Lang.t("keyname.shift") + "+";
		return s + codeName(k & CODE, short);
	}

	static function codeName( c : Int, short : Bool ) : String {
		inline function t( key : String ) return Lang.t("keyname." + key);
		return switch( c ) {
		case K.MOUSE_LEFT: short ? t("mouse1.short") : t("mouse1");
		case K.MOUSE_RIGHT: t("mouse2");
		case K.MOUSE_MIDDLE: t("mouse3");
		case K.MOUSE_BACK: t("mouse4");
		case K.MOUSE_FORWARD: t("mouse5");
		case K.SPACE: t("space");
		case K.SHIFT: t("shift");
		case K.ENTER: t("enter");
		case K.NUMPAD_ENTER: t("numenter");
		case K.BACKSPACE: t("backspace");
		case K.DELETE: t("delete");
		case K.INSERT: t("insert");
		case K.HOME: t("home");
		case K.END: t("end");
		case K.PGUP: t("pgup");
		case K.PGDOWN: t("pgdown");
		case K.UP: t("up");
		case K.DOWN: t("down");
		case K.LEFT: t("left");
		case K.RIGHT: t("right");
		case K.ESCAPE: t("esc");
		case K.CAPS_LOCK: t("capslock");
		case K.NUMPAD_ADD: t("numpad").split("%n%").join("+");
		case K.NUMPAD_SUB: t("numpad").split("%n%").join("-");
		case K.NUMPAD_MULT: t("numpad").split("%n%").join("*");
		case K.NUMPAD_DIV: t("numpad").split("%n%").join("/");
		case K.NUMPAD_DOT: t("numpad").split("%n%").join(".");
		// signos: hxd.Key los nombra por su sitio en un teclado QWERTY
		case K.QWERTY_SEMICOLON: ";";
		case K.QWERTY_EQUALS: "=";
		case K.QWERTY_COMMA: ",";
		case K.QWERTY_MINUS: "-";
		case K.QWERTY_PERIOD: ".";
		case K.QWERTY_SLASH: "/";
		case K.QWERTY_TILDE: "`";
		case K.QWERTY_BRACKET_LEFT: "[";
		case K.QWERTY_BACKSLASH: "\\";
		case K.QWERTY_BRACKET_RIGHT: "]";
		case K.QWERTY_QUOTE: "'";
		case K.AZERTY_EXCLAM: "!";
		case K.INTL_BACKSLASH: "<";
		default:
			if( c >= K.NUMPAD_0 && c <= K.NUMPAD_9 ) t("numpad").split("%n%").join("" + (c - K.NUMPAD_0));
			else {
				var n = K.getKeyName(c);
				n != null ? n : "#" + c;
			}
		}
	}

	/** primera tecla de una accion, para la ayuda en pantalla */
	public static function first( id : String ) : String {
		for( k in cur.get(id) ) if( k != NONE ) return name(k, true);
		return "?";
	}

	/** todas las teclas de una accion, "Clic / E / Mayus" */
	public static function all( id : String ) : String {
		var l = [for( k in cur.get(id) ) if( k != NONE ) name(k, true)];
		return l.length == 0 ? "?" : l.join(" / ");
	}

	/** las cuatro direcciones juntas ("WASD", "ZQSD") o separadas por / si alguna no es una sola letra */
	static function moveKeys() : String {
		var l = [for( id in ["forward", "left", "back", "right"] ) first(id)];
		var arrows = [for( id in ["up", "left", "down", "right"] ) Lang.t("keyname." + id)];
		if( l.join("|") == arrows.join("|") ) return Lang.t("keyname.arrows");
		for( s in l ) if( s.length != 1 ) return l.join("/");
		return l.join("");
	}

	/**
	 * Pone las teclas elegidas en un texto de ayuda: %move% (las cuatro direcciones), %action% (todas las de excavar o colocar),
	 * %slots% (casillas 1 a 10, "1-0") y %id% (la primera tecla de esa accion).
	 */
	public static function fill( s : String ) : String {
		var r = filled.get(s);
		if( r != null ) return r;
		r = ~/%([a-z0-9]+)%/g.map(s, function(e) {
			var id = e.matched(1);
			return switch( id ) {
				case "move": moveKeys();
				case "action": all("action");
				case "slots": first("slot1") + "-" + first("slot10");
				default: byId.exists(id) ? first(id) : e.matched(0);
			}
		});
		filled.set(s, r);
		return r;
	}

	/** "haz clic" del tutorial: con el clic izquierdo para excavar o colocar se queda; si no, "pulsa E" o "haz clic derecho" */
	public static function clickVerb() : String {
		var l = [for( k in cur.get("action") ) if( k != NONE ) k];
		if( l.indexOf(K.MOUSE_LEFT) >= 0 || l.length == 0 ) return Lang.t("key.click");
		return switch( l[0] ) {
			case K.MOUSE_RIGHT: Lang.t("key.click.right");
			case K.MOUSE_MIDDLE: Lang.t("key.click.middle");
			default: Lang.t("key.press").split("%k%").join(name(l[0]));
		}
	}
}
