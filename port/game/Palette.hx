import Common;
import Ui;
import IconMesh.Icons;

/**
 * Paleta del modo creativo (anadido nuestro): todos los bloques que el original vendia en la tienda (los que tienen precio),
 * en una cuadricula con paginas. Un clic pone el bloque en la casilla elegida del inventario.
 * Arriba, una busqueda por nombre (sin mayusculas ni acentos) deja solo los bloques que se llaman asi.
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
	/** letras como mucho en la busqueda */
	static inline var SEARCH_MAX = 24;
	/** alto del campo de busqueda */
	static inline var SEARCH_H = 38;

	var atlas : h3d.mat.Texture;
	/** todos los bloques de la paleta; blocks = los que deja la busqueda */
	var all = new Array<Block>();
	var blocks : Array<Block>;
	/** nombre de cada bloque de all para buscar (fold), en el idioma elegido: solo cuenta el nombre que se ve */
	var names : Array<String>;
	var page = 0;
	var grid : h2d.Object;
	var info : h2d.Text;
	var pageText : h2d.Text;
	var none : h2d.Text;
	var x0 : Float;
	var y0 : Float;

	var search : h2d.TextInput;
	var searchBg : h2d.Graphics;
	var searchW : Float;
	var placeholder : h2d.Text;
	var clearBtn : h2d.Interactive;
	/** fotograma en el que se dejo de escribir: h2d.TextInput ya ha usado ese Intro o ese Esc, que no deben contar otra vez */
	var stoppedFrame = -1;

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture ) {
		super(parent);
		this.atlas = atlas;
		// los kubes van despues de los bloques de Galaxy 55, tambien de los anadidos tras ellos (colonne en rosh...). La cantina
		// no tiene precio en los datos, pero ahora se fabrica (receta 62): tambien sale
		var kubes = [];
		for( b in Block.all )
			if( b.index > 0 && (b.basePrice != null || b.k == BChest) && b.charge == null && b.type != BTInvisible )
				(KubeData.isKube(b.k) ? kubes : all).push(b);
		for( b in kubes ) all.push(b);
		// el agua de cada planeta no se vendia; en creativo se puede poner (fluye como en Minecraft). El agua acida si tiene precio en
		// los datos y ya esta en la lista: no se repite
		for( k in [BWater, BDarkWater, BAcidWater, BWinterWater] )
			if( all.indexOf(Block.get(k)) < 0 ) all.push(Block.get(k));
		blocks = all.copy();
		names = [for( b in all ) fold(b.getName())];

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
		// la busqueda va entre el titulo y el numero de pagina
		var sx = Std.int(t.x + t.textWidth * t.scaleX + 30);
		buildSearch(sx, Std.int(py + 16), Std.int(px + w - 170 - sx));
		none = Theme.text(this, "", 2.0, Theme.DIM);
		none.visible = false;
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

	// ---------------------------------------------------------------- busqueda

	static var FOLD : Map<Int, String>;

	/** minusculas y sin acentos, para comparar nombres: "Écorce" y "ecorce" son lo mismo; oe y ae ligados pasan a dos letras */
	static function fold( s : String ) : String {
		if( FOLD == null ) {
			FOLD = new Map();
			var from = "àáâäãåçèéêëìíîïñòóôöõùúûüýÿ" + "ÀÁÂÄÃÅÇÈÉÊËÌÍÎÏÑÒÓÔÖÕÙÚÛÜÝ";
			var to = "aaaaaaceeeeiiiinooooouuuuyy" + "aaaaaaceeeeiiiinooooouuuuy";
			for( i in 0...from.length ) FOLD.set(from.charCodeAt(i), to.charAt(i));
			for( p in [["œ", "oe"], ["Œ", "oe"], ["æ", "ae"], ["Æ", "ae"], ["ß", "ss"], ["’", "'"]] ) FOLD.set(p[0].charCodeAt(0), p[1]);
		}
		var out = new StringBuf();
		for( i in 0...s.length ) {
			var c = s.charCodeAt(i);
			var f = FOLD.get(c);
			if( f != null ) out.add(f);
			else out.addChar(c >= 65 && c <= 90 ? c + 32 : c);
		}
		return out.toString();
	}

	/**
	 * Todas las palabras de la busqueda estan en el nombre, en cualquier orden ("fer" da "Fer" y "Terre fertile"): 0 si cada una
	 * empieza una palabra del nombre ("eau" en "Eau de Kube"), 1 si alguna solo esta dentro de una ("eau" en "Chapeau"); -1 = no
	 */
	static function rank( name : String, words : Array<String> ) : Int {
		var r = 0;
		for( w in words ) {
			var i = name.indexOf(w);
			if( i < 0 ) return -1;
			while( i > 0 && wordChar(name.charCodeAt(i - 1)) ) i = name.indexOf(w, i + 1);
			if( i < 0 ) r = 1;
		}
		return r;
	}

	/** letra o cifra de un nombre ya pasado por fold (lo demas separa palabras: espacio, guion, apostrofo) */
	static inline function wordChar( c : Int ) return (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c > 127;

	function buildSearch( x : Int, y : Int, w : Int ) {
		searchW = w;
		var box = new h2d.Object(this);
		box.x = x;
		box.y = y;
		searchBg = new h2d.Graphics(box);
		// un clic en cualquier parte del recuadro empieza a escribir (el del texto ademas coloca el cursor)
		var it = new h2d.Interactive(w, SEARCH_H, box);
		it.cursor = hxd.Cursor.TextInput;
		it.onClick = function(_) startSearch();
		var scale = 2.0;
		var ty = Std.int((SEARCH_H - Theme.font.lineHeight * scale) * 0.5);
		placeholder = Theme.text(box, Lang.t("palette.search"), scale, Theme.DIM, 34, ty);
		search = new h2d.TextInput(Theme.font, box);
		search.setScale(scale);
		search.textColor = Theme.TEXT;
		search.x = 34;
		search.y = ty;
		search.inputWidth = Std.int((w - 34 - SEARCH_H) / scale);
		search.onFocus = function(_) {
			// mientras se escribe no hay casilla marcada: el teclado es del campo
			focus = -1;
			drawFocus();
			drawSearch();
		};
		search.onFocusLost = function(_) {
			stoppedFrame = hxd.Timer.frameCount;
			drawSearch();
		};
		search.onChange = function() {
			if( search.text.length > SEARCH_MAX ) search.text = search.text.substr(0, SEARCH_MAX);
			applySearch();
		};
		// la cruz de la derecha vacia la busqueda y deja seguir escribiendo
		clearBtn = new h2d.Interactive(SEARCH_H, SEARCH_H, box);
		clearBtn.x = w - SEARCH_H;
		clearBtn.onClick = function(_) {
			clearSearch();
			startSearch();
		};
		clearBtn.onOver = function(_) drawSearch(true);
		clearBtn.onOut = function(_) drawSearch();
		drawSearch();
	}

	function drawSearch( overClear = false ) {
		var g = searchBg, w = searchW, h = SEARCH_H;
		var on = search.hasFocus();
		g.clear();
		Theme.rect(g, 0, 0, w, h, 0x000000, 0.35);
		var c = on ? Theme.ACCENT : 0xFFFFFF, a = on ? 0.9 : 0.15;
		Theme.rect(g, 0, 0, w, 2, c, a);
		Theme.rect(g, 0, h - 2, w, 2, c, a);
		Theme.rect(g, 0, 0, 2, h, c, a);
		Theme.rect(g, w - 2, 0, 2, h, c, a);
		// lupa
		var cx = 15, cy = 17;
		g.lineStyle(2, on ? Theme.ACCENT : Theme.DIM);
		g.drawCircle(cx, cy, 6);
		g.moveTo(cx + 4, cy + 4);
		g.lineTo(cx + 10, cy + 10);
		var empty = search.text == "";
		placeholder.visible = empty;
		clearBtn.visible = !empty;
		if( !empty ) {
			var x = w - h * 0.5, y = h * 0.5, r = 7;
			g.lineStyle(2, overClear ? Theme.ACCENT : Theme.TEXT);
			g.moveTo(x - r, y - r);
			g.lineTo(x + r, y + r);
			g.moveTo(x + r, y - r);
			g.lineTo(x - r, y + r);
		}
		g.lineStyle();
	}

	function typing() return search.hasFocus() || stoppedFrame == hxd.Timer.frameCount;

	/** clic en la busqueda o Tab: escribir, con el cursor al final */
	function startSearch() {
		search.focus();
		search.cursorIndex = search.text.length;
	}

	/** Intro, Tab o flecha abajo en la busqueda: se deja de escribir y se marca el primer bloque encontrado */
	function leaveSearch() {
		if( search.hasFocus() ) search.blur();
		focus = blocks.length > 0 ? 0 : -1;
		drawFocus();
	}

	function clearSearch() {
		search.text = "";
		if( search.hasFocus() ) search.cursorIndex = 0;
		applySearch();
	}

	/**
	 * Se rehace la lista con la busqueda y se vuelve a la primera pagina. Primero los nombres con palabras que empiezan como lo
	 * buscado, luego los que lo llevan dentro de una palabra; dentro de cada grupo, el orden de la paleta
	 */
	function applySearch() {
		var words = [for( w in fold(search.text).split(" ") ) if( w != "" ) w];
		if( words.length == 0 ) blocks = all.copy();
		else {
			var starts = [], inside = [];
			for( i in 0...all.length )
				switch( rank(names[i], words) ) {
					case 0: starts.push(all[i]);
					case 1: inside.push(all[i]);
					default:
				}
			blocks = starts.concat(inside);
		}
		page = 0;
		if( !search.hasFocus() ) focus = -1;
		show();
		drawSearch();
	}

	override function onRemove() {
		// que el campo no se quede con el teclado al cerrar la paleta escribiendo
		if( search.hasFocus() ) search.blur();
		super.onRemove();
	}

	// ---------------------------------------------------------------- cuadricula

	function pages() return Std.int(Math.max(1, Std.int((blocks.length + COLS * ROWS - 1) / (COLS * ROWS))));

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
		// sin resultados: un aviso en medio de la cuadricula
		none.visible = blocks.length == 0;
		if( none.visible ) {
			none.text = Lang.t("palette.none").split("%q%").join(search.text);
			none.x = Std.int(x0 + (COLS * CELL - none.textWidth * none.scaleX) * 0.5);
			none.y = Std.int(y0 + (ROWS * CELL - none.textHeight * none.scaleY) * 0.5);
		}
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

	/** boton abajo a la derecha, en la fila del nombre del bloque y alineado con la cuadricula (la bascula a supervivencia,
	    ModeSwitch.button) */
	public function addCornerButton( b : Ui.Widget ) {
		addChild(b);
		b.x = Std.int(x0 + COLS * CELL - b.w);
		b.y = Std.int(info.y + (info.font.lineHeight * info.scaleY - b.h) * 0.5);
	}

	/** banco de pruebas (orden palhover): el raton entra en la casilla i de la pagina (o sale de ella) */
	public function devHover( i : Int, over : Bool ) {
		var it = Std.downcast(grid.getChildAt(i).getChildAt(2), h2d.Interactive);
		if( over ) it.onOver(null) else it.onOut(null);
	}

	/** banco de pruebas (print palette) */
	public function devInfo() {
		var s = "pagina " + (page + 1) + "/" + pages() + " foco " + focus + " nombre '" + info.text + "'";
		s += " busqueda '" + search.text + "' bloques " + blocks.length + "/" + all.length + (search.hasFocus() ? " escribiendo" : "");
		if( none.visible ) s += " aviso '" + none.text + "'";
		// el centro del campo y la cruz, en la zona 1280x720 (orden mouse)
		var p = searchBg.localToGlobal(new h2d.col.Point(searchW * 0.5, SEARCH_H * 0.5));
		s += " campo " + Std.int(p.x) + "," + Std.int(p.y);
		if( clearBtn.visible ) {
			var p = clearBtn.localToGlobal(new h2d.col.Point(SEARCH_H * 0.5, SEARCH_H * 0.5));
			s += " cruz " + Std.int(p.x) + "," + Std.int(p.y);
		}
		return s;
	}

	/** banco de pruebas (print palnames): nombres de los bloques que deja la busqueda */
	public function devNames() return [for( b in blocks ) b.getName()].join(" | ");

	/** mando y teclado: cruceta/stick o flechas mueven, A/Intro pone el bloque, LB/RB cambian de pagina, B/R3/Esc/I (Keys) cierran;
	    Tab o un clic en la busqueda empiezan a escribir */
	public function update( dt : Float, pad : hxd.Pad ) {
		var K = hxd.Key;
		if( pad != null && navCooldown > 0 ) navCooldown -= dt;
		if( typing() ) {
			// escribiendo, las teclas son del campo: ni I ni las flechas ni las letras de las teclas del juego hacen nada aqui.
			// Intro, Tab o abajo (A o abajo en el mando) pasan a la cuadricula; Esc (B) vacia la busqueda o, vacia, cierra
			var toGrid = K.isPressed(K.ENTER) || K.isPressed(K.NUMPAD_ENTER) || K.isPressed(K.TAB) || K.isPressed(K.DOWN);
			var esc = K.isPressed(K.ESCAPE);
			if( pad != null ) {
				if( pad.isPressed(pad.config.A) || pad.isPressed(pad.config.dpadDown) ) toGrid = true;
				if( pad.isPressed(pad.config.B) ) esc = true;
			}
			if( esc ) {
				if( search.hasFocus() ) search.blur();
				if( search.text != "" ) clearSearch();
				else if( onClose != null ) onClose();
			} else if( toGrid )
				leaveSearch();
			return;
		}
		var dx = 0, dy = 0, pg = 0, pick = false, back = false, clear = false;
		if( K.isPressed(K.LEFT) ) dx = -1;
		if( K.isPressed(K.RIGHT) ) dx = 1;
		if( K.isPressed(K.UP) ) dy = -1;
		if( K.isPressed(K.DOWN) ) dy = 1;
		if( K.isPressed(K.ENTER) ) pick = true;
		// Esc y B vacian primero la busqueda; I (la tecla de la paleta) y R3 cierran siempre
		if( K.isPressed(K.ESCAPE) ) clear = true;
		if( Keys.pressed("palette") ) back = true;
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
			if( pad.isPressed(pad.config.LB) ) pg = -1;
			if( pad.isPressed(pad.config.RB) ) pg = 1;
			if( pad.isPressed(pad.config.A) ) pick = true;
			if( pad.isPressed(pad.config.B) ) clear = true;
			if( pad.isPressed(pad.config.ranalogClick) ) back = true;
		}
		if( clear && !back && search.text != "" ) {
			clearSearch();
			return;
		}
		if( back || clear ) {
			if( onClose != null ) onClose();
			return;
		}
		if( K.isPressed(K.TAB) ) {
			startSearch();
			return;
		}
		nav(dx, dy, pg, pick);
	}

	/** cruceta/flechas (dx, dy), LB/RB (pg) y A/Intro (pick); la orden palnav del banco de pruebas pasa por aqui */
	public function nav( dx : Int, dy : Int, pg : Int, pick : Bool ) {
		// sin resultados no hay casilla que marcar
		if( pageCount() <= 0 ) return;
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

	/** banco de pruebas (print paldup): bloques de la paleta, los que salen mas de una vez y donde estan las aguas (pagina:casilla) */
	public function devRepeated() {
		var per = COLS * ROWS;
		var rep = [for( i in 0...blocks.length ) if( blocks.indexOf(blocks[i]) < i ) blocks[i].k + " '" + blocks[i].getName() + "'"];
		var water = [for( i in 0...blocks.length ) if( blocks[i].type == BTWater ) blocks[i].k + "@" + (Std.int(i / per) + 1) + ":" + (i % per)];
		return blocks.length + " bloques en " + pages() + " paginas, " + rep.length + " repetidos" + (rep.length == 0 ? "" : " (" + rep.join(", ") + ")")
			+ " | aguas " + water.join(" ");
	}
}