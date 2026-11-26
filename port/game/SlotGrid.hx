import Common;
import Ui;
import IconMesh.Icons;

/**
 * Zona de casillas de un SlotGrid (anadido del port): pilas de bloques (una tabla de casillas: el inventario, una cantina) o
 * cargas (los contadores del inventario, sin casillas: la casilla i es la carga de tipo i de ChargeKind, aunque este a 0).
 */
class SlotZone {

	/** tipos de carga (CYellow, CBlue, CPink, CBonus): una casilla por tipo */
	public static inline var CHARGE_KINDS = 4;
	/** bloque de cada carga, para su icono */
	static var CHARGE_BLOCKS = [BYellowCharge, BBlueCharge, BPinkCharge, BBonusCharge];

	/** bloques: la tabla de casillas (null en una zona de cargas) */
	public var blocks(default, null) : Protocol.BlockInventory;
	/** cargas: la lista de contadores (null en una zona de bloques) */
	public var charges(default, null) : Protocol.UserCharges;
	var maxWeight = 64;
	/** cuantas cargas de cada tipo caben (-1 = sin limite) */
	var chargeMax : Array<Int>;
	/** primera casilla (arriba a la izquierda, en coordenadas de la zona W x H) y casillas por fila */
	public var x : Float;
	public var y : Float;
	public var cols : Int;
	/** cargas: el limite de cada contador debajo de su casilla, "/ 24" o "/ ∞" (Theme.limit), alineado a la derecha */
	public var showMax = false;

	function new() {}

	public static function ofBlocks( t : Protocol.BlockInventory, maxWeight : Int, x : Float, y : Float, ?cols : Int ) : SlotZone {
		var z = new SlotZone();
		z.blocks = t;
		z.maxWeight = maxWeight;
		z.x = x;
		z.y = y;
		z.cols = cols == null ? t.length : cols;
		return z;
	}

	/** max[i] = cuantas cargas de tipo i caben (-1 = sin limite) */
	public static function ofCharges( list : Protocol.UserCharges, max : Array<Int>, x : Float, y : Float ) : SlotZone {
		var z = new SlotZone();
		z.charges = list;
		z.chargeMax = max;
		z.x = x;
		z.y = y;
		z.cols = CHARGE_KINDS;
		return z;
	}

	/** los maximos de las cargas del inventario (DataGen.CHARGES: 99, 50, 10 y 99999) */
	public static function invChargeMax() : Array<Int> {
		return [for( k in 0...CHARGE_KINDS ) Data.getCharge(Type.createEnumIndex(ChargeKind, k)).max];
	}

	public var length(get, never) : Int;
	function get_length() return blocks != null ? blocks.length : CHARGE_KINDS;

	public inline function isCharges() return charges != null;

	/** lo que hay en la casilla i: el bloque (indice de Block.all) o la carga; -1 = vacia (un contador a 0 tambien) */
	public function kind( i : Int ) : Int {
		if( blocks != null ) {
			var s = blocks[i];
			return s == null || s.n <= 0 ? -1 : s.k;
		}
		return count(i) > 0 ? i : -1;
	}

	public function count( i : Int ) : Int {
		if( blocks != null ) {
			var s = blocks[i];
			return s == null ? 0 : s.n;
		}
		for( c in charges ) if( c.c == i ) return c.n;
		return 0;
	}

	/** cuantos de k caben como mucho en una casilla (una carga sin limite: el mayor entero) */
	public function max( k : Int ) : Int {
		if( blocks != null ) return Block.all[k].getMax(maxWeight);
		return chargeMax[k] < 0 ? 0x7FFFFFFF : chargeMax[k];
	}

	/** limite de la carga k que se ensena (-1 = sin limite, o una zona de bloques) */
	public function limit( k : Int ) : Int return blocks != null ? -1 : chargeMax[k];

	/** pone n de k en la casilla i (vacia o con k; quien llama mira que quepan) */
	public function add( i : Int, k : Int, n : Int ) {
		if( blocks != null ) {
			var s = blocks[i];
			if( s == null ) blocks[i] = { k : k, n : n } else s.n += n;
			return;
		}
		for( c in charges )
			if( c.c == k ) {
				c.n += n;
				return;
			}
		charges.push({ c : k, n : n });
	}

	/** quita n de la casilla i (la vacia si llega a 0) */
	public function remove( i : Int, n : Int ) {
		if( blocks != null ) {
			var s = blocks[i];
			s.n -= n;
			if( s.n <= 0 ) blocks[i] = null;
			return;
		}
		for( c in charges )
			if( c.c == i ) {
				c.n -= n;
				// como Inventory.useCharge: el contador a 0 se quita de la lista
				if( c.n <= 0 ) charges.remove(c);
				return;
			}
	}

	/** bloque que se dibuja para k */
	public function blockOf( k : Int ) : Block return blocks != null ? Block.all[k] : Block.get(CHARGE_BLOCKS[k]);

	public function nameOf( k : Int ) : String {
		return blocks != null ? Block.all[k].getName() : KubText.get("chargetag." + Type.getEnumConstructs(ChargeKind)[k]);
	}
}

/**
 * Casillas con arrastrar y soltar entre varias zonas (anadido del port): la cantina (Chest) y lo que se abra igual, con las
 * reglas de la pantalla de inventario (InvScreen):
 *   - clic izquierdo mantenido: coger la pila y arrastrarla; al soltarla sobre una casilla se deja, se junta (mismo bloque, hasta
 *     el maximo de la pila; lo que no cabe se queda en su casilla) o se intercambian las dos casillas
 *   - un clic sin moverse deja la pila en el cursor: el clic siguiente la deja, la junta o la cambia por la de esa casilla (y el
 *     cursor se queda con la otra)
 *   - clic derecho: coger la mitad (redondeando hacia arriba) o, con una pila en el cursor, dejar una unidad; arrastrando con el
 *     derecho apretado, una en cada casilla por la que se pasa
 *   - Mayus / Ctrl + clic izquierdo: la mitad / una (al coger y al dejar)
 *   - doble clic: juntar en esa casilla las otras pilas del mismo bloque, de todas las zonas, hasta el maximo
 *   - soltar o hacer clic fuera de las casillas: la pila vuelve a su casilla (aqui no se tira nada al suelo)
 *   - mando y teclado: cruceta/flechas eligen la casilla (arriba y abajo, la fila de al lado), A/Intro = clic, X = clic derecho,
 *     B/Esc = soltar la pila del cursor o, sin ella, cerrar (update devuelve true)
 * Bloques y cargas no se mezclan: una carga va siempre al contador de su tipo, se suelte en la casilla de cargas que se suelte.
 * La pila del cursor no sale de su casilla hasta dejarla (como en InvScreen): cerrar a medias no pierde nada.
 * Las zonas van en coordenadas de la zona W x H: el SlotGrid y sus padres estan en el 0,0 de la escena.
 */
class SlotGrid extends h2d.Object {

	public static inline var CELL = 60;
	/** alto de una fila de una zona de varias filas (la casilla y su texto de debajo) */
	static inline var ROW = CELL + 18;
	/** segundos entre los dos clics de un doble clic */
	static inline var DOUBLE = 0.35;
	/** una casilla se guarda como zona * ZONE + indice */
	static inline var ZONE = 100;

	public var zones(default, null) : Array<SlotZone> = [];
	/** algo ha cambiado de verdad: la barra del inventario y el Kubindex lo miran (Inv.display) */
	public var onChange : Void -> Void;
	/** nombre y cantidad de la casilla bajo el raton o marcada, o de lo que lleva el cursor ("" = nada) */
	public var onInfo : String -> Void;

	var atlas : h3d.mat.Texture;
	var cells : h2d.Object;
	/** la pila del cursor, dibujada encima de las casillas */
	var hand : h2d.Object;
	/** pila del cursor: n de k de la casilla from de la zona z (siguen en ella hasta dejarlos en otra) */
	var held : { z : Int, from : Int, k : Int, n : Int };
	/** la pila se cogio con el clic izquierdo que sigue apretado: al soltarlo en otra casilla se deja alli */
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
	var shown : String;
	var info = "";

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture ) {
		super(parent);
		this.atlas = atlas;
		cells = new h2d.Object(this);
		hand = new h2d.Object(this);
		// el raton se lee de los eventos de la ventana (como InvScreen): un clic de un solo fotograma tambien cuenta
		winEvents = onEvent;
		hxd.Window.getInstance().addEventTarget(winEvents);
	}

	override function onRemove() {
		if( winEvents != null ) {
			hxd.Window.getInstance().removeEventTarget(winEvents);
			winEvents = null;
		}
		super.onRemove();
	}

	/** anade una zona y devuelve su numero */
	public function addZone( z : SlotZone ) : Int {
		zones.push(z);
		refresh();
		return zones.length - 1;
	}

	inline function zoneOf( s : Int ) return Std.int(s / ZONE);
	inline function indexOf( s : Int ) return s % ZONE;

	// ---------------------------------------------------------------- dibujo

	function cellX( z : SlotZone, i : Int ) : Float return z.x + (i % z.cols) * CELL;
	function cellY( z : SlotZone, i : Int ) : Float return z.y + Std.int(i / z.cols) * ROW;

	/** lo que se ve en la casilla s: su pila menos lo que lleva el cursor */
	function shownCount( s : Int ) : Int {
		var n = zones[zoneOf(s)].count(indexOf(s));
		return held != null && held.z == zoneOf(s) && held.from == indexOf(s) ? n - held.n : n;
	}

	function stamp() {
		var parts = [];
		for( z in zones )
			parts.push([for( i in 0...z.length ) z.kind(i) < 0 ? "-" : z.kind(i) + "x" + z.count(i)].join(","));
		return parts.join("/") + "|" + hover + "|" + focus + "|" + (held == null ? "" : held.z + ":" + held.from + ":" + held.n);
	}

	/** "Nombre xN" (una carga con limite: "Nombre xN / max") */
	function label( z : SlotZone, k : Int, n : Int ) : String {
		var lim = z.limit(k);
		return z.nameOf(k) + " x" + n + (lim >= 0 ? " / " + lim : "");
	}

	function refresh() {
		shown = stamp();
		cells.removeChildren();
		for( zi in 0...zones.length ) {
			var z = zones[zi];
			for( i in 0...z.length ) {
				var s = zi * ZONE + i;
				var c = new h2d.Object(cells);
				c.x = cellX(z, i);
				c.y = cellY(z, i);
				var g = new h2d.Graphics(c);
				var on = s == hover || s == focus;
				Theme.rect(g, 2, 2, CELL - 4, CELL - 4, on ? Theme.ACCENT : 0xFFFFFF, on ? 0.25 : 0.07);
				if( s == focus ) frame(g, Theme.ACCENT, 1);
				var n = shownCount(s);
				// una carga se ve siempre (apagada a 0); un bloque, mientras quede algo en la casilla
				var k = z.isCharges() ? i : z.kind(i);
				if( k >= 0 && (n > 0 || z.isCharges()) ) {
					var bm = Icons.bitmap(c, z.blockOf(k), 48, atlas, true);
					bm.x = 6;
					bm.y = 3;
					if( n <= 0 ) bm.alpha = 0.3;
					count(c, n, n > 0 && n >= z.max(k), n <= 0, 5, CELL - 20);
				}
				if( z.showMax && z.isCharges() ) {
					var lim = Theme.limit(c, z.limit(i), 1.0, Theme.DIM);
					lim.x = Std.int(CELL - 2 - lim.width);
					lim.y = CELL + 1;
				}
			}
		}
		// el nombre y la cantidad de la casilla bajo el raton (o la marcada); si no hay, lo que lleva el cursor
		var sel = focus >= 0 ? focus : hover;
		var txt = "";
		if( sel >= 0 && shownCount(sel) > 0 ) {
			var z = zones[zoneOf(sel)];
			txt = label(z, z.kind(indexOf(sel)), shownCount(sel));
		} else if( held != null )
			txt = label(zones[held.z], held.k, held.n);
		if( txt != info ) {
			info = txt;
			if( onInfo != null ) onInfo(txt);
		}
		hand.removeChildren();
		if( held != null ) {
			var z = zones[held.z];
			var bm = Icons.bitmap(hand, z.blockOf(held.k), 48, atlas, true);
			bm.x = -24;
			bm.y = -27;
			count(hand, held.n, false, false, -19, 4);
		}
		placeHand();
	}

	function frame( g : h2d.Graphics, color : Int, alpha : Float ) {
		Theme.rect(g, 0, 0, CELL, 2, color, alpha);
		Theme.rect(g, 0, CELL - 2, CELL, 2, color, alpha);
		Theme.rect(g, 0, 2, 2, CELL - 4, color, alpha);
		Theme.rect(g, CELL - 2, 2, 2, CELL - 4, color, alpha);
	}

	function count( p : h2d.Object, n : Int, full : Bool, dim : Bool, x : Float, y : Float ) {
		var tf = Theme.text(p, "" + n, 1.2, full ? 0xF08080 : dim ? Theme.DIM : Theme.TEXT, x, y);
		tf.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 1 };
	}

	/** la pila del cursor sigue al raton; con el mando, encima de la casilla marcada */
	function placeHand() {
		if( focus >= 0 ) {
			var z = zones[zoneOf(focus)], i = indexOf(focus);
			hand.x = cellX(z, i) + CELL * 0.5;
			hand.y = cellY(z, i) - 16;
		} else {
			hand.x = mx;
			hand.y = my;
		}
	}

	// ---------------------------------------------------------------- raton

	/** casilla en el punto x y de la zona W x H (-1 = ninguna) */
	function slotAt( x : Float, y : Float ) : Int {
		for( zi in 0...zones.length ) {
			var z = zones[zi];
			if( x < z.x || y < z.y ) continue;
			var c = Std.int((x - z.x) / CELL), r = Std.int((y - z.y) / ROW);
			if( c >= z.cols || y - z.y - r * ROW >= CELL ) continue;
			var i = r * z.cols + c;
			if( i < z.length ) return zi * ZONE + i;
		}
		return -1;
	}

	/** banco de pruebas: centro de la casilla i de la zona z, o un punto fuera de todas (i < 0) */
	public function devPoint( z : Int, i : Int ) : h2d.col.Point {
		if( i < 0 || z < 0 || z >= zones.length ) return new h2d.col.Point(4, 4);
		var zz = zones[z];
		return new h2d.col.Point(cellX(zz, i) + CELL * 0.5, cellY(zz, i) + CELL * 0.5);
	}

	function onEvent( e : hxd.Event ) {
		switch( e.kind ) {
		case EPush, ERelease, EMove:
			// de pixeles de la ventana a la zona W x H (LetterBox), como InvScreen
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
		if( dragging && held != null && s != held.z * ZONE + held.from ) moved = true;
		if( painted != null && held != null && s >= 0 && painted.indexOf(s) < 0 ) {
			painted.push(s);
			// en una zona de cargas solo cuenta la casilla de su tipo (todas irian al mismo contador)
			var z = zones[zoneOf(s)];
			if( !z.isCharges() || indexOf(s) == held.k ) putOne(s);
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
			else cancel(); // clic fuera de las casillas: la pila del cursor vuelve a su casilla
		} else if( button == 1 && !dragging ) {
			if( s >= 0 ) rightDown(s, true);
			else cancel();
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
		if( s == held.z * ZONE + held.from && !moved ) return;
		if( s >= 0 && s != held.z * ZONE + held.from ) dropOn(s);
		else cancel(); // soltada en su casilla o fuera de las casillas: no se mueve
	}

	// ---------------------------------------------------------------- operaciones

	/** cambio de verdad: la barra del inventario se redibuja y el Kubindex lo mira */
	function changed() {
		if( onChange != null ) onChange();
		refresh();
	}

	/**
	 * Mueve hasta n de la casilla a de la zona za a la casilla b de la zona zb (vacia o con lo mismo): devuelve cuantos caben; el
	 * resto se queda en a. Bloques con bloques y cargas con cargas (b es entonces el contador de su tipo).
	 */
	function moveItems( za : Int, a : Int, zb : Int, b : Int, n : Int ) : Int {
		var A = zones[za], B = zones[zb];
		if( A.isCharges() != B.isCharges() ) return 0;
		var k = A.kind(a);
		if( k < 0 || (B.isCharges() && b != k) ) return 0;
		var d = B.kind(b);
		if( d >= 0 && d != k ) return 0;
		var m = Std.int(Math.min(Math.max(0, B.max(k) - B.count(b)), n));
		if( m <= 0 ) return 0;
		B.add(b, k, m);
		A.remove(a, m);
		return m;
	}

	/** cambia dos casillas de bloques (de la misma zona o de dos) */
	function swap( za : Int, a : Int, zb : Int, b : Int ) {
		var A = zones[za].blocks, B = zones[zb].blocks, x = A[a];
		A[a] = B[b];
		B[b] = x;
	}

	/** casilla en la que acaba lo que lleva el cursor si se suelta en s: en una zona de cargas, el contador de su tipo (-1 = no
	    vale: bloques sobre cargas o al reves) */
	function target( s : Int ) : Int {
		var z = zones[zoneOf(s)];
		if( z.isCharges() != zones[held.z].isCharges() ) return -1;
		return z.isCharges() ? zoneOf(s) * ZONE + held.k : s;
	}

	/** clic izquierdo (o A) en la casilla s */
	function leftDown( s : Int, mouse : Bool ) {
		var now = haxe.Timer.stamp();
		var dbl = s == lastLeft && now - lastLeftTime < DOUBLE;
		lastLeft = s;
		lastLeftTime = now;
		dragging = false;
		var z = zones[zoneOf(s)], i = indexOf(s);
		if( held == null ) {
			if( z.kind(i) < 0 ) return;
			held = { z : zoneOf(s), from : i, k : z.kind(i), n : amount(z.count(i)) };
			dragging = mouse;
			moved = false;
			refresh();
			return;
		}
		if( s == held.z * ZONE + held.from ) {
			// doble clic: juntar aqui; si no hay nada que juntar, el clic deja la pila donde estaba
			var got = dbl && gather(s);
			held = null;
			if( got ) changed() else refresh();
			return;
		}
		place(s, amount(held.n));
	}

	/** Mayus = la mitad (redondeando hacia arriba), Ctrl = una, como en InvScreen: cuantos de n coge o deja el clic */
	static function amount( n : Int ) : Int {
		var K = hxd.Key;
		return K.isDown(K.CTRL) ? 1 : K.isDown(K.SHIFT) ? Math.ceil(n / 2) : n;
	}

	/** con la pila del cursor: dejar n en s, juntarlos (lo que no cabe sigue en el cursor) o cambiar la pila por la de s */
	function place( s : Int, n : Int ) {
		var t = target(s);
		if( t < 0 ) return;
		var src = zones[held.z], a = held.from, tz = zoneOf(t), ti = indexOf(t);
		if( t == held.z * ZONE + a ) {
			// otra casilla de cargas de la misma zona: la carga ya esta en su contador
			held = null;
			refresh();
			return;
		}
		var d = zones[tz].kind(ti);
		if( d < 0 || d == held.k ) {
			var m = moveItems(held.z, a, tz, ti, n);
			if( m <= 0 ) return; // casilla llena
			held.n -= m;
			if( held.n <= 0 ) held = null;
		} else if( held.n >= src.count(a) ) {
			// toda la pila: se cambian las dos casillas y el cursor se queda con la otra, como en Minecraft
			swap(held.z, a, tz, ti);
			held = { z : held.z, from : a, k : src.kind(a), n : src.count(a) };
		} else {
			// parte de la pila: la de s necesita una casilla libre en la zona de la que sale; sin ella no se puede
			var e = src.blocks.indexOf(null);
			if( e < 0 ) return;
			var other = zones[tz].blocks[ti];
			src.blocks[e] = other;
			zones[tz].blocks[ti] = { k : held.k, n : held.n };
			src.remove(a, held.n);
			held = { z : held.z, from : e, k : other.k, n : other.n };
		}
		changed();
	}

	/** arrastre soltado en s: dejar, juntar (lo que no cabe se queda en su casilla) o intercambiar las dos casillas (solo con la
	    pila entera: media pila no se cambia por otro bloque) */
	function dropOn( s : Int ) {
		var t = target(s);
		if( t < 0 || t == held.z * ZONE + held.from ) {
			cancel();
			return;
		}
		var src = zones[held.z], tz = zoneOf(t), ti = indexOf(t), d = zones[tz].kind(ti);
		if( d < 0 || d == held.k ) moveItems(held.z, held.from, tz, ti, held.n);
		else if( held.n >= src.count(held.from) ) swap(held.z, held.from, tz, ti);
		held = null;
		changed();
	}

	/** clic derecho (o X) en la casilla s */
	function rightDown( s : Int, mouse : Bool ) {
		var z = zones[zoneOf(s)], i = indexOf(s);
		painted = null;
		if( held == null ) {
			if( z.kind(i) < 0 ) return;
			held = { z : zoneOf(s), from : i, k : z.kind(i), n : Math.ceil(z.count(i) / 2) };
			refresh();
			return;
		}
		if( s == held.z * ZONE + held.from ) {
			// una unidad vuelve a su casilla
			held.n--;
			if( held.n <= 0 ) held = null;
			refresh();
			return;
		}
		var t = target(s);
		if( t < 0 || t == held.z * ZONE + held.from ) return;
		var d = zones[zoneOf(t)].kind(indexOf(t));
		if( d >= 0 && d != held.k ) {
			place(s, held.n);
			return;
		}
		if( mouse ) painted = [s];
		putOne(s);
	}

	/** deja una unidad de la pila del cursor en s (vacia o con lo mismo y con sitio) */
	function putOne( s : Int ) {
		if( held == null ) return;
		var t = target(s);
		if( t < 0 || t == held.z * ZONE + held.from || moveItems(held.z, held.from, zoneOf(t), indexOf(t), 1) == 0 ) return;
		held.n--;
		if( held.n <= 0 ) held = null;
		changed();
	}

	/** doble clic: junta en s las otras pilas del mismo bloque de todas las zonas (primero las incompletas), hasta el maximo */
	function gather( s : Int ) : Bool {
		var zs = zoneOf(s), i = indexOf(s), z = zones[zs];
		if( z.isCharges() ) return false;
		var k = z.kind(i), max = z.max(k), got = false;
		for( pass in 0...2 )
			for( oz in 0...zones.length ) {
				var o = zones[oz];
				if( o.isCharges() ) continue;
				for( j in 0...o.length ) {
					if( (oz == zs && j == i) || z.count(i) >= max ) continue;
					if( o.kind(j) != k || (pass == 0 && o.count(j) >= max) ) continue;
					if( moveItems(oz, j, zs, i, o.count(j)) > 0 ) got = true;
				}
			}
		return got;
	}

	/** suelta la pila del cursor (sigue en su casilla); false si no llevaba ninguna */
	public function cancel() : Bool {
		painted = null;
		if( held == null ) return false;
		held = null;
		dragging = false;
		refresh();
		return true;
	}

	// ---------------------------------------------------------------- teclado y mando

	/** algo ha cambiado por otro lado (algo recogido, la cantina rota): la pila del cursor se ajusta a lo que queda en su casilla */
	function checkHeld() {
		if( held == null ) return;
		var z = zones[held.z];
		if( z.kind(held.from) != held.k ) {
			held = null;
			dragging = false;
		} else if( held.n > z.count(held.from) )
			held.n = z.count(held.from);
	}

	/** cada fotograma; true = B o Esc sin nada en el cursor: el panel se cierra */
	public function update( dt : Float, pad : hxd.Pad ) : Bool {
		checkHeld();
		if( stamp() != shown ) refresh();
		var K = hxd.Key;
		var dx = 0, dy = 0, a = false, x = false, back = K.isPressed(K.ESCAPE);
		if( K.isPressed(K.LEFT) ) dx = -1;
		if( K.isPressed(K.RIGHT) ) dx = 1;
		if( K.isPressed(K.UP) ) dy = -1;
		if( K.isPressed(K.DOWN) ) dy = 1;
		if( K.isPressed(K.ENTER) || K.isPressed(K.NUMPAD_ENTER) ) a = true;
		if( pad != null ) {
			if( pad.isPressed(pad.config.dpadLeft) ) dx = -1;
			if( pad.isPressed(pad.config.dpadRight) ) dx = 1;
			if( pad.isPressed(pad.config.dpadUp) ) dy = -1;
			if( pad.isPressed(pad.config.dpadDown) ) dy = 1;
			if( pad.isPressed(pad.config.A) ) a = true;
			if( pad.isPressed(pad.config.X) ) x = true;
			if( pad.isPressed(pad.config.B) ) back = true;
		}
		if( back ) return !cancel();
		nav(dx, dy, a, x);
		return false;
	}

	/** flechas o cruceta (dx, dy), A/Intro (a) y X (x); la orden slots nav del banco de pruebas pasa por aqui */
	public function nav( dx : Int, dy : Int, a : Bool, x : Bool ) {
		if( dx != 0 || dy != 0 ) {
			focus = focus < 0 ? (hover >= 0 ? hover : 0) : neighbour(focus, dx, dy);
			hover = -1;
			refresh();
		}
		if( focus < 0 ) return;
		if( a ) leftDown(focus, false);
		if( x ) rightDown(focus, false);
	}

	/** casilla de al lado: en la misma fila (dando la vuelta) o en la fila mas cercana de arriba o de abajo, la mas cercana en x */
	function neighbour( s : Int, dx : Int, dy : Int ) : Int {
		var all = [for( zi in 0...zones.length ) for( i in 0...zones[zi].length ) zi * ZONE + i];
		inline function cx( t : Int ) return cellX(zones[zoneOf(t)], indexOf(t));
		inline function cy( t : Int ) return cellY(zones[zoneOf(t)], indexOf(t));
		if( dy != 0 ) {
			var best = s, bestD = 1e12;
			for( t in all ) {
				var d = (cy(t) - cy(s)) * dy;
				if( d <= 0 ) continue;
				var score = d * 10000 + Math.abs(cx(t) - cx(s));
				if( score < bestD ) {
					bestD = score;
					best = t;
				}
			}
			return best;
		}
		var row = [for( t in all ) if( cy(t) == cy(s) ) t];
		row.sort(function(a, b) return Reflect.compare(cx(a), cx(b)));
		var j = (row.indexOf(s) + dx + row.length) % row.length;
		return row[j];
	}

	/** banco de pruebas: marca una casilla como con el mando */
	public function devFocus( z : Int, i : Int ) {
		focus = z * ZONE + i;
		hover = -1;
		refresh();
	}

	/** banco de pruebas (print slots): lo que se ve en cada zona y el cursor */
	public function devInfo() : String {
		var parts = [];
		for( zi in 0...zones.length ) {
			var z = zones[zi];
			parts.push(zi + "[" + [for( i in 0...z.length ) {
				var n = shownCount(zi * ZONE + i);
				var k = z.isCharges() ? i : z.kind(i);
				n <= 0 ? "-" : (z.isCharges() ? Type.getEnumConstructs(ChargeKind)[k] : Block.all[k].k + "") + "x" + n;
			}].join(" ") + "]");
		}
		var c = held == null ? "-" : (zones[held.z].isCharges() ? Type.getEnumConstructs(ChargeKind)[held.k] : Block.all[held.k].k + "") + "x" + held.n + " de " + held.z + ":" + held.from;
		return parts.join(" ") + "  cursor=" + c + " arrastre=" + dragging + " raton=" + slotName(hover) + " foco=" + slotName(focus) + " info='" + info + "'";
	}

	function slotName( s : Int ) return s < 0 ? "-" : zoneOf(s) + ":" + indexOf(s);
}
