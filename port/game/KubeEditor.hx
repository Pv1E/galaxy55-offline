import Common;
import Ui;
import IconMesh.Icons;

/** boton del editor de kubes: mas pequeno que los del menu, con estado elegido (herramienta, cara, pestana) */
private class KButton extends h2d.Object {
	public var w(default, null) : Int;
	public var h(default, null) : Int;
	public var selected(default, set) = false;
	public var enabled(default, set) = true;
	public var onClick : Void -> Void;
	var bg : h2d.Graphics;
	var txt : h2d.Text;
	var it : h2d.Interactive;
	var over = false;

	public function new( parent : h2d.Object, label : String, w : Int, h = 30, scale = 1.4 ) {
		super(parent);
		this.w = w;
		this.h = h;
		bg = new h2d.Graphics(this);
		txt = Theme.text(this, label, scale, Theme.TEXT);
		it = new h2d.Interactive(w, h, this);
		it.onOver = function(_) { over = true; redraw(); };
		it.onOut = function(_) { over = false; redraw(); };
		it.onClick = function(_) if( enabled && onClick != null ) onClick();
		redraw();
	}

	public function setLabel( s : String ) {
		txt.text = s;
		redraw();
	}

	public function resize( w : Int ) {
		this.w = w;
		it.width = w;
		redraw();
	}

	function set_selected( v : Bool ) {
		selected = v;
		redraw();
		return v;
	}

	function set_enabled( v : Bool ) {
		enabled = v;
		redraw();
		return v;
	}

	function redraw() {
		bg.clear();
		if( selected ) {
			Theme.rect(bg, 0, 0, w, h, Theme.ACCENT, 0.25);
			Theme.rect(bg, 0, h - 2, w, 2, Theme.ACCENT);
		} else
			Theme.rect(bg, 0, 0, w, h, 0xFFFFFF, over && enabled ? 0.12 : 0.05);
		txt.textColor = !enabled ? Theme.DISABLED : selected ? Theme.ACCENT : over ? 0xFFFFFF : Theme.TEXT;
		Theme.center(txt, w, h);
	}
}

/** fila "titulo   <  valor  >": un clic en la flecha de la izquierda va a la opcion anterior, en el resto a la siguiente */
private class KChoice extends h2d.Object {
	public var index(default, null) = 0;
	public var enabled(default, set) = true;
	public var onChange : Int -> Void;
	var choices : Array<String>;
	var w : Int;
	var h : Int;
	var bg : h2d.Graphics;
	var title : h2d.Text;
	var value : h2d.Text;

	public function new( parent : h2d.Object, label : String, choices : Array<String>, w : Int, h = 30 ) {
		super(parent);
		this.choices = choices;
		this.w = w;
		this.h = h;
		bg = new h2d.Graphics(this);
		Theme.rect(bg, 0, 0, w, h, 0xFFFFFF, 0.05);
		title = Theme.text(this, label, 1.4, Theme.DIM, 10, 0);
		value = Theme.text(this, "", 1.4, Theme.CYAN);
		var it = new h2d.Interactive(w, h, this);
		it.onClick = function(e : hxd.Event) if( enabled ) step(e.relX < value.x + 24 ? -1 : 1);
		refresh();
	}

	public function step( d : Int ) {
		index = (index + d + choices.length) % choices.length;
		refresh();
		if( onChange != null ) onChange(index);
	}

	/** elige sin avisar; label sustituye el texto de la opcion (un valor que no esta en la lista) */
	public function set( i : Int, ?label : String ) {
		index = i;
		refresh(label);
	}

	function set_enabled( v : Bool ) {
		enabled = v;
		refresh();
		return v;
	}

	function refresh( ?label : String ) {
		value.text = enabled ? "<  " + (label != null ? label : choices[index]) + "  >" : "-";
		value.textColor = enabled ? Theme.CYAN : Theme.DISABLED;
		value.x = w - 10 - value.textWidth * value.scaleX;
		value.y = title.y = Std.int((h - value.textHeight * value.scaleY) * 0.5);
	}
}

/**
 * Editor de kubes (anadido del port, Menu principal > Editor de Kubes): dibujar pixel a pixel las caras de un bloque con una
 * de las formas del juego y verlo en 3D tal como lo pinta el mundo (IconMesh, la misma geometria que World). Carga cualquier
 * bloque del juego o un kube guardado para partir de su forma y sus caras; guarda .kube para enviarlos (KubeData).
 * Es una pantalla del menu (show("kubes")): al volver al menu y entrar otra vez sigue el kube que se estaba haciendo.
 */
class KubeEditor extends Screen {

	static inline var W = Theme.W;
	static inline var S = KubeData.SIZE;
	// lista de kubes (izquierda)
	static inline var LX = 16;
	static inline var LY = 104;
	static inline var COLS = 5;
	static inline var ROWS = 10;
	static inline var CELL = 56;
	// herramientas, lienzo (pixeles de 14) y columna derecha
	static inline var TX = 312;
	static inline var TW = 116;
	static inline var CX = 440;
	static inline var CY = 104;
	static inline var PX = 14;
	static inline var RX = 904;
	static inline var RW = 360;
	static inline var PV = 206;
	static inline var PVY = 390;
	/** formas cerradas cuyos lados el mundo pinta del derecho o del reves segun la cara (ver computeCover) */
	static var ORIENTED = ["cube", "cube6", "box", "door", "column", "bigcolumn", "hanging", "pipe"];
	static inline var PENCIL = 0;
	static inline var ERASER = 1;
	static inline var FILL = 2;
	static inline var PICKER = 3;
	static inline var HISTORY = 200;
	/** pasos del zoom de la vista previa (rueda): 1 = el kube o el mosaico entero en la vista */
	static var ZOOMS = [0.5, 0.67, 0.8, 1., 1.25, 1.5, 2., 2.5, 3., 4., 5., 6.];
	static inline var ZOOM1 = 3;
	/** DB32 (DawnBringer): una paleta clasica de pixel art */
	static var PALETTE = [0x000000, 0x222034, 0x45283C, 0x663931, 0x8F563B, 0xDF7126, 0xD9A066, 0xEEC39A, 0xFBF236, 0x99E550, 0x6ABE30,
		0x37946E, 0x4B692F, 0x524B24, 0x323C39, 0x3F3F74, 0x306082, 0x5B6EE1, 0x639BFF, 0x5FCDE4, 0xCBDBFC, 0xFFFFFF, 0x9BADB7, 0x847E87,
		0x696A6A, 0x595652, 0x76428A, 0xAC3232, 0xD95763, 0xD77BBA, 0x8F974A, 0x8A6F30];

	public var onClose : Void -> Void;
	public var kube(default, null) : KubeData;
	var atlas : h3d.mat.Texture;
	var face = KubeData.SIDE;
	var tool = PENCIL;
	var mirror = false;
	var showGrid = true;
	var hue = 0.;
	var sat = 0.;
	var val = 0.;
	var opacity = 1.;
	var color = 0xFF000000;
	var undoStack = new Array<Array<{ f : Int, px : haxe.ds.Vector<Int> }>>();
	var redoStack = new Array<Array<{ f : Int, px : haxe.ds.Vector<Int> }>>();
	public var dirty(default, null) = false;
	/** confirmacion de una accion que pierde cambios: se repite el mismo clic antes de 3 s */
	var pendingKey : String;
	var pendingTime = 0.;

	// tira de 8 casillas (una por cara, en el orden de KubeData.FACES): textura del lienzo y de la vista previa
	var stripPix : hxd.Pixels;
	var strip : h3d.mat.Texture;
	var stripDirty = false;
	/** pixeles de cada cara que la forma muestra, en la casilla del atlas (los demas se oscurecen en el lienzo) */
	var cover : Array<haxe.ds.Vector<Bool>>;
	/**
	 * Caras que el bloque ensena al reves (izquierda y derecha cambiadas) respecto a su casilla del atlas. Las caras del kube se
	 * guardan en memoria como se ven en el bloque (lo que se dibuja en el lienzo es lo que sale en el juego) y se dan la vuelta
	 * al pasar a la tira, al guardar y al cargar. Cambiar de forma conserva asi lo que se ve.
	 */
	var flipView = [for( _ in KubeData.FACES ) false];

	// lienzo
	var art : h2d.Bitmap;
	var veil : h2d.Graphics;
	var gridG : h2d.Graphics;
	var hoverG : h2d.Graphics;
	var posText : h2d.Text;
	var painting = false;
	var paintButton = 0;
	var lastX = -1;
	var lastY = -1;
	var faceTabs : h2d.Object;
	var faceButtons = new Array<KButton>();
	var toolButtons = new Array<KButton>();
	var mirrorButton : KButton;
	var gridButton : KButton;

	// color
	var swatch : h2d.Graphics;
	var hexText : h2d.Text;
	var opacityText : h2d.Text;
	var bars = new Array<h2d.Graphics>();
	var kubeColors : h2d.Object;

	// columna derecha
	var nameInput : h2d.TextInput;
	var typing = false;
	var shapeChoice : KChoice;
	var renderChoice : KChoice;
	var lightChoice : KChoice;
	var reachChoice : KChoice;
	var collideButton : KButton;
	/** bloques del juego con la forma elegida (en el hueco de la caja, cuando la forma no tiene caja) */
	var shapeInfo : h2d.Text;
	var boxRoot : h2d.Object;
	var boxBars = new Array<h2d.Graphics>();
	var boxTexts = new Array<h2d.Text>();
	var doorButton : KButton;
	var tileButton : KButton;
	var spinButton : KButton;
	var deleteButton : KButton;
	var msgText : h2d.Text;
	var helpText : h2d.Text;
	var msgTime = 0.;

	// vista previa 3D (se pinta en una textura, como los iconos)
	var scene : h3d.scene.Scene;
	/** las otras pasadas de previewMesh (cristal y hielo: pixeles solidos y profundidad), con su misma primitiva */
	var previewPasses = new Array<h3d.scene.Mesh>();
	var previewTex : h3d.mat.Texture;
	var previewMesh : h3d.scene.Mesh;
	/** contorno de la celda (del mosaico entero si lo hay) */
	var cellBox : h3d.scene.Graphics;
	var yaw = -Math.PI / 4;
	var pitch = 0.53;
	var spin = true;
	var doorOpen = false;
	/** mosaico: n x n x n kubes iguales pegados, para ver como casan sus caras de lado, de arriba y de abajo (1 = el kube solo) */
	var tiles = 1;
	var zoomIndex = ZOOM1;
	/** punto que mira la camara: el centro del mosaico, o el que se acerco con la rueda */
	var lookAt = new h3d.col.Point(0.5, 0.5, 0.5);
	var zoomText : h2d.Text;
	var zoomBack : h2d.Graphics;
	var previewOver = false;

	// lista de kubes
	var tab = 0;
	var tabButtons = new Array<KButton>();
	/** las dos listas se crean una vez dentro de una mascara: la rueda solo las desplaza (los iconos ya pintados se quedan) */
	var listMask : h2d.Mask;
	var gameList : h2d.Object;
	var mineList : h2d.Object;
	var listInfo : h2d.Text;
	/** desplazamiento de cada pestana en pixeles: el que se ve, que va hacia el pedido */
	var scrollPos = [0., 0.];
	var scrollTarget = [0., 0.];
	var gameBlocks : Array<Block>;
	var mine : Array<{ path : String, name : String, thumb : h2d.Tile }>;

	/** arrastre en curso (barras, vista previa): recibe el raton en coordenadas de la zona W x H */
	var drag : Float -> Float -> Void;

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture ) {
		super(parent);
		this.atlas = atlas;
		gameBlocks = [for( b in Block.all ) if( listed(b) ) b];

		stripPix = hxd.Pixels.alloc(S * KubeData.FACES.length, S, RGBA);
		strip = h3d.mat.Texture.fromPixels(stripPix);
		strip.filter = Nearest;
		scene = new h3d.scene.Scene();
		previewTex = new h3d.mat.Texture(PV, PV, [Target]);
		previewTex.depthBuffer = new h3d.mat.Texture(PV, PV, [Target], Depth24Stencil8);
		cellBox = new h3d.scene.Graphics(scene);
		cellBox.lineStyle(1, Theme.CYAN, 0.35);
		for( e in [[0, 0, 0, 1, 0, 0], [1, 0, 0, 1, 1, 0], [1, 1, 0, 0, 1, 0], [0, 1, 0, 0, 0, 0], [0, 0, 1, 1, 0, 1], [1, 0, 1, 1, 1, 1],
			[1, 1, 1, 0, 1, 1], [0, 1, 1, 0, 0, 1], [0, 0, 0, 0, 0, 1], [1, 0, 0, 1, 0, 1], [1, 1, 0, 1, 1, 1], [0, 1, 0, 0, 1, 1]] ) {
			cellBox.moveTo(e[0], e[1], e[2]);
			cellBox.lineTo(e[3], e[4], e[5]);
		}

		build();
		pickColor(0xFF9BADB7);
		setKube(blank(), false, false);
		showTab(0);
	}

	/** bloques de la lista del juego: todos los que se ven, sin las variantes giradas o abiertas (salen con su bloque) */
	static function listed( b : Block ) : Bool {
		if( b.index == 0 || b.type == BTInvisible || b.type == BTWater || b.propagate != null ) return false;
		if( b.flip != null && b.flip.index < b.index ) return false;
		if( b.toggle != null && b.toggle.index < b.index ) return false;
		return true;
	}

	/** kube nuevo: un cubo gris claro con el borde oscuro */
	function blank() : KubeData {
		var k = new KubeData(Lang.t("kube.newname"));
		for( y in 0...S ) for( x in 0...S )
			k.faces[KubeData.SIDE][y * S + x] = x == 0 || y == 0 || x == S - 1 || y == S - 1 ? 0xFF696A6A : 0xFF9BADB7;
		k.fillMissingFaces();
		return k;
	}

	// ---------------------------------------------------------------- construccion

	function build() {
		var bg = new h2d.Graphics(this);
		Theme.fullRect(bg, Theme.BG, 1);
		Theme.rect(bg, 0, 0, W, 4, Theme.ACCENT);
		Theme.rect(bg, LX - 6, 60, COLS * CELL + 12, 644, Theme.PANEL, 0.9);
		Theme.rect(bg, TX - 6, 60, TW + 12, 644, Theme.PANEL, 0.9);
		Theme.rect(bg, CX - 6, 60, S * PX + 12, 644, Theme.PANEL, 0.9);
		Theme.rect(bg, RX - 6, 60, RW + 12, 644, Theme.PANEL, 0.9);
		Theme.text(this, Lang.t("kube.title"), 2.4, Theme.TEXT, LX, 18);
		// la ayuda y los mensajes (la ruta de un kube guardado es larga) se parten en dos lineas si no caben
		helpText = Theme.text(this, Lang.t("kube.help"), 1.2, Theme.DIM, TX, 16);
		msgText = Theme.text(this, "", 1.3, Theme.ACCENT, TX, 16);
		for( t in [helpText, msgText] ) t.maxWidth = (W - TX - 16) / t.scaleX;
		msgText.visible = false;

		buildList();
		buildTools();
		buildCanvas();
		buildColors();
		buildSide();
	}

	function buildList() {
		for( i in 0...2 ) {
			var b = new KButton(this, Lang.t(i == 0 ? "kube.tab.game" : "kube.tab.mine"), 138, 32);
			b.x = LX + i * 142;
			b.y = 66;
			b.onClick = function() showTab(i);
			tabButtons.push(b);
		}
		var area = new h2d.Interactive(COLS * CELL, ROWS * CELL, this);
		area.x = LX;
		area.y = LY;
		area.cursor = Default;
		area.propagateEvents = true;
		area.onWheel = function(e : hxd.Event) scrollList(e.wheelDelta > 0 ? CELL : -CELL);
		listMask = new h2d.Mask(COLS * CELL, ROWS * CELL, this);
		listMask.setPosition(LX, LY);
		gameList = new h2d.Object(listMask);
		mineList = new h2d.Object(listMask);
		listInfo = Theme.text(this, "", 1.3, Theme.CYAN, LX, 672);
	}

	function buildTools() {
		var y = 66;
		function add( key : String, ?gap = 0 ) : KButton {
			y += gap;
			var b = new KButton(this, Lang.t(key), TW, 30, 1.3);
			b.x = TX;
			b.y = y;
			y += 34;
			return b;
		}
		for( i in 0...4 ) {
			var b = add(["kube.tool.pencil", "kube.tool.eraser", "kube.tool.fill", "kube.tool.picker"][i]);
			b.onClick = function() setTool(i);
			toolButtons.push(b);
		}
		mirrorButton = add("kube.tool.mirror", 8);
		mirrorButton.onClick = function() { mirror = !mirror; mirrorButton.selected = mirror; };
		gridButton = add("kube.tool.grid");
		gridButton.selected = showGrid;
		gridButton.onClick = function() { showGrid = !showGrid; gridButton.selected = showGrid; gridG.visible = showGrid; };
		add("kube.tool.undo", 8).onClick = undo;
		add("kube.tool.redo").onClick = redo;
		add("kube.tool.flip", 8).onClick = function() transformFace(function(x, y) return (S - 1 - x) + y * S);
		add("kube.tool.rotate").onClick = function() transformFace(function(x, y) return y + (S - 1 - x) * S);
		add("kube.tool.clear").onClick = clearFace;
		add("kube.tool.copyall").onClick = copyToAll;
		var hint = Theme.text(this, Lang.t("kube.tool.hint"), 1.1, Theme.DIM, TX, y + 12);
		hint.maxWidth = TW / hint.scaleX;
	}

	function buildCanvas() {
		faceTabs = new h2d.Object(this);
		faceTabs.x = CX;
		faceTabs.y = 66;
		var check = hxd.Pixels.alloc(S, S, RGBA);
		for( y in 0...S ) for( x in 0...S ) check.setPixel(x, y, (x + y) & 1 == 0 ? 0xFF2A303C : 0xFF363D4B);
		var cb = new h2d.Bitmap(h2d.Tile.fromPixels(check), this);
		cb.setPosition(CX, CY);
		cb.setScale(PX);
		art = new h2d.Bitmap(h2d.Tile.fromTexture(strip).sub(0, 0, S, S), this);
		art.setPosition(CX, CY);
		art.setScale(PX);
		art.smooth = false;
		cb.smooth = false;
		veil = new h2d.Graphics(this);
		veil.setPosition(CX, CY);
		gridG = new h2d.Graphics(this);
		gridG.setPosition(CX, CY);
		for( i in 0...S + 1 ) {
			var a = i % 8 == 0 ? 0.28 : 0.09;
			Theme.rect(gridG, i * PX, 0, 1, S * PX, 0xFFFFFF, a);
			Theme.rect(gridG, 0, i * PX, S * PX, 1, 0xFFFFFF, a);
		}
		hoverG = new h2d.Graphics(this);
		hoverG.setPosition(CX, CY);
		posText = Theme.text(this, "", 1.2, Theme.DIM, CX, CY + S * PX + 4);
		var it = new h2d.Interactive(S * PX, S * PX, this);
		it.setPosition(CX, CY);
		it.enableRightButton = true;
		it.cursor = Default;
		it.onPush = function(e : hxd.Event) canvasPush(Std.int(e.relX / PX), Std.int(e.relY / PX), e.button);
	}

	function buildColors() {
		var y0 = 574;
		swatch = new h2d.Graphics(this);
		swatch.setPosition(CX, y0);
		hexText = Theme.text(this, "", 1.2, Theme.DIM, CX, y0 + 58);
		var labels = ["kube.color.h", "kube.color.s", "kube.color.v", "kube.color.a"];
		for( i in 0...4 ) {
			Theme.text(this, Lang.t(labels[i]), 1.2, Theme.DIM, CX + 64, y0 + i * 24 + 2);
			var g = new h2d.Graphics(this);
			g.setPosition(CX + 126, y0 + i * 24);
			bars.push(g);
			var it = new h2d.Interactive(180, 18, g);
			it.onPush = function(e : hxd.Event) {
				setBar(i, e.relX / 180);
				drag = function(mx, _) setBar(i, (mx - g.x) / 180);
			};
		}
		var px0 = CX + 320, cs = 16;
		// el % de la opacidad a la derecha de su barra, alineado con la paleta (bajo el codigo de color tapaba "Lumin.")
		opacityText = Theme.text(this, "", 1.2, Theme.DIM, px0, y0 + 3 * 24 + 2);
		var g = new h2d.Graphics(this);
		for( i in 0...PALETTE.length ) {
			var cx = px0 + (i % 8) * cs, cy = y0 + Std.int(i / 8) * cs;
			Theme.rect(g, cx, cy, cs, cs, PALETTE[i]);
			var it = new h2d.Interactive(cs, cs, this);
			it.setPosition(cx, cy);
			var c = PALETTE[i];
			it.onClick = function(_) pickColor(0xFF000000 | c);
		}
		Theme.text(this, Lang.t("kube.color.kube"), 1.2, Theme.DIM, CX, 680);
		kubeColors = new h2d.Object(this);
		kubeColors.setPosition(CX + 128, 676);
	}

	function buildSide() {
		Theme.text(this, Lang.t("name"), 1.4, Theme.DIM, RX + 10, 72);
		nameInput = new h2d.TextInput(Theme.font, this);
		nameInput.setScale(1.6);
		nameInput.textColor = Theme.CYAN;
		nameInput.backgroundColor = 0x33000000;
		nameInput.x = RX + 90;
		nameInput.y = 70;
		nameInput.inputWidth = Std.int((RW - 100) / 1.6);
		nameInput.onFocus = function(_) typing = true;
		nameInput.onFocusLost = function(_) typing = false;
		nameInput.onChange = function() {
			if( nameInput.text.length > 32 ) nameInput.text = nameInput.text.substr(0, 32);
			if( kube.name != nameInput.text ) {
				kube.name = nameInput.text;
				dirty = true;
			}
		};

		shapeChoice = new KChoice(this, Lang.t("kube.shape"), [for( s in KubeData.SHAPES ) Lang.t("kube.shape." + s.id)], RW);
		shapeChoice.setPosition(RX, 102);
		shapeChoice.onChange = function(i) {
			var s = KubeData.SHAPES[i];
			if( s.id == "door" && kube.shape.id != "door" ) kube.box = KubeData.BOXES.get("door").copy();
			kube.shape = s;
			kube.fillMissingFaces();
			if( !kube.usesFace(face) ) face = s.faces[0];
			changed();
			refreshAll();
		};
		renderChoice = new KChoice(this, Lang.t("kube.render"), [for( i in 0...3 ) Lang.t("kube.render." + i)], RW);
		renderChoice.setPosition(RX, 136);
		renderChoice.onChange = function(i) {
			kube.render = i;
			changed();
			rebuildPreview();
			refreshShapeInfo();
		};
		// la luz del bloque (BFLight potencia, caida): la potencia es la luz de su celda (10 = pleno dia) y cada kube de distancia
		// le quita la caida, asi que se apaga a potencia / caida kubes; aqui se eligen la potencia y ese alcance
		var powers = [Lang.t("kube.light.none")];
		for( i in 0...KubeData.LIGHT_POWERS.length ) powers.push(Lang.t("kube.light." + i) + " (" + KubeData.LIGHT_POWERS[i] + ")");
		lightChoice = new KChoice(this, Lang.t("kube.light"), powers, RW);
		lightChoice.setPosition(RX, 170);
		lightChoice.onChange = function(i) {
			var reach = kube.light == null ? 4 : kube.lightReach();
			kube.light = i == 0 ? null : KubeData.lightOf(KubeData.LIGHT_POWERS[i - 1], reach);
			changed();
			refreshLight();
		};
		reachChoice = new KChoice(this, Lang.t("kube.reach"), [for( r in 1...KubeData.MAX_REACH + 1 ) StringTools.replace(Lang.t(r == 1 ? "kube.reach.one" : "kube.reach.n"), "%n%", "" + r)], RW);
		reachChoice.setPosition(RX, 204);
		reachChoice.onChange = function(i) {
			if( kube.light == null ) return;
			kube.light = KubeData.lightOf(kube.light[0], i + 1);
			changed();
		};
		collideButton = new KButton(this, Lang.t("kube.passable"), RW, 26, 1.3);
		collideButton.setPosition(RX, 238);
		collideButton.onClick = function() {
			kube.noCollide = !kube.noCollide;
			collideButton.selected = kube.noCollide;
			changed();
		};

		shapeInfo = Theme.text(this, "", 1.2, Theme.DIM, RX + 10, 276);
		shapeInfo.maxWidth = (RW - 20) / shapeInfo.scaleX;
		boxRoot = new h2d.Object(this);
		Theme.text(boxRoot, Lang.t("kube.box"), 1.2, Theme.DIM, RX + 10, 270);
		for( a in 0...3 ) {
			var y = 286 + a * 24;
			Theme.text(boxRoot, ["X", "Y", "Z"][a], 1.4, Theme.TEXT, RX + 10, y + 3);
			var g = new h2d.Graphics(boxRoot);
			g.setPosition(RX + 40, y);
			boxBars.push(g);
			boxTexts.push(Theme.text(boxRoot, "", 1.3, Theme.CYAN, RX + 290, y + 3));
			var it = new h2d.Interactive(240, 22, g);
			it.onPush = function(e : hxd.Event) {
				// el extremo mas cercano al clic sigue al raton
				var v = Math.round(e.relX / 240 * S);
				var lo = Math.abs(v - kube.box[a]) <= Math.abs(v - kube.box[a + 3]);
				if( kube.box[a] == kube.box[a + 3] ) lo = v < kube.box[a];
				var set = function(mx : Float, _ : Float) {
					var v = Math.round((mx - g.x) / 240 * S);
					if( lo ) v = Std.int(Math.max(0, Math.min(kube.box[a + 3] - 1, v))) else v = Std.int(Math.max(kube.box[a] + 1, Math.min(S, v)));
					var i = lo ? a : a + 3;
					if( kube.box[i] != v ) {
						kube.box[i] = v;
						changed();
						rebuildPreview();
						drawBox();
					}
				};
				set(g.x + e.relX, 0.);
				drag = set;
			};
		}
		var presets = ["slab", "neon", "small", "post", "door"];
		for( i in 0...presets.length ) {
			var b = new KButton(boxRoot, Lang.t("kube.box." + presets[i]), 68, 22, 1.2);
			b.setPosition(RX + i * 73, 360);
			b.onClick = function() {
				kube.box = KubeData.BOXES.get(presets[i]).copy();
				changed();
				rebuildPreview();
				drawBox();
			};
		}

		var pv = new h2d.Bitmap(h2d.Tile.fromTexture(previewTex), this);
		pv.setPosition(RX + (RW - PV) * 0.5, PVY);
		var it = new h2d.Interactive(PV, PV, pv);
		it.onPush = function(e : hxd.Event) {
			spin = false;
			spinButton.selected = false;
			var sx = pv.x + e.relX, sy = pv.y + e.relY, y0 = yaw, p0 = pitch;
			drag = function(mx, my) {
				// el kube sigue al raton, como si se cogiera: a la derecha, la cara de delante se va a la derecha
				yaw = y0 + (mx - sx) * 0.012;
				pitch = Math.max(-1.4, Math.min(1.4, p0 + (my - sy) * 0.012));
			};
		};
		// la rueda acerca o aleja el punto que esta bajo el raton
		it.onWheel = function(e : hxd.Event) zoomBy(e.wheelDelta > 0 ? -1 : 1, e.relX / PV * 2 - 1, 1 - e.relY / PV * 2);
		it.onOver = function(_) { previewOver = true; refreshZoomText(); };
		it.onOut = function(_) { previewOver = false; refreshZoomText(); };
		zoomBack = new h2d.Graphics(this);
		zoomText = Theme.text(this, "", 1.1, Theme.TEXT, 0, PVY + PV - 18);
		// la casilla de la izquierda: el mosaico, que deja sitio al boton de la puerta cuando la forma es una puerta
		tileButton = new KButton(this, "", 176, 24, 1.2);
		tileButton.setPosition(RX, 602);
		tileButton.onClick = function() setTiles(tiles % 3 + 1);
		doorButton = new KButton(this, Lang.t("kube.preview.open"), 120, 24, 1.2);
		doorButton.setPosition(RX + 56, 602);
		doorButton.onClick = function() {
			doorOpen = !doorOpen;
			doorButton.selected = doorOpen;
			rebuildPreview();
		};
		spinButton = new KButton(this, Lang.t("kube.preview.spin"), 176, 24, 1.2);
		spinButton.setPosition(RX + RW - 176, 602);
		spinButton.selected = spin;
		spinButton.onClick = function() {
			spin = !spin;
			spinButton.selected = spin;
		};

		var save = new KButton(this, Lang.t("kube.save"), 176, 30, 1.4);
		save.setPosition(RX, 634);
		save.onClick = saveKube;
		var folder = new KButton(this, Lang.t("kube.folder"), 176, 30, 1.4);
		folder.setPosition(RX + RW - 176, 634);
		folder.onClick = openFolder;
		var nw = new KButton(this, Lang.t("kube.new"), 114, 30, 1.4);
		nw.setPosition(RX, 670);
		nw.onClick = newKube;
		deleteButton = new KButton(this, Lang.t("kube.delete"), 114, 30, 1.4);
		deleteButton.setPosition(RX + 123, 670);
		deleteButton.onClick = deleteKube;
		var back = new KButton(this, Lang.t("back"), 114, 30, 1.4);
		back.setPosition(RX + RW - 114, 670);
		back.onClick = close;
	}

	// ---------------------------------------------------------------- kube actual

	/**
	 * Pasa a editar k (nuevo, cargado o copiado de un bloque del juego); fromFile = viene de un .kube. atlas = sus caras estan
	 * como en las casillas del atlas (un bloque del juego o un .kube): las que el bloque ensena al reves se dan la vuelta.
	 */
	public function setKube( k : KubeData, fromFile : Bool, atlas : Bool ) {
		kube = k;
		if( !fromFile ) kube.file = null;
		computeCover();
		if( atlas )
			for( f in 0...KubeData.FACES.length )
				if( flipView[f] ) kube.mirrorFace(f);
		face = kube.shape.faces[0];
		undoStack = [];
		redoStack = [];
		dirty = false;
		doorOpen = false;
		doorButton.selected = false;
		nameInput.text = kube.name;
		refreshStrip();
		refreshAll();
		drawMine();
	}

	function refreshAll() {
		var si = KubeData.SHAPES.indexOf(kube.shape);
		shapeChoice.set(si);
		renderChoice.enabled = kube.shape.id == "cube";
		renderChoice.set(kube.render);
		refreshLight();
		collideButton.selected = kube.noCollide;
		boxRoot.visible = kube.shape.box;
		shapeInfo.visible = !kube.shape.box;
		refreshShapeInfo();
		doorButton.visible = kube.shape.id == "door";
		refreshTileButton();
		deleteButton.enabled = kube.file != null;
		drawBox();
		drawFaceTabs();
		selectFace(face);
		rebuildPreview();
		refreshKubeColors();
		setTool(tool);
	}

	function changed() {
		dirty = true;
	}

	function refreshLight() {
		var l = kube.light;
		if( l == null ) lightChoice.set(0);
		else {
			// una potencia de un bloque del juego que no esta en la lista se ensena tal cual
			var i = KubeData.LIGHT_POWERS.indexOf(l[0]);
			if( i < 0 ) lightChoice.set(0, "" + l[0]) else lightChoice.set(i + 1);
		}
		reachChoice.enabled = l != null;
		if( l != null ) reachChoice.set(kube.lightReach() - 1);
	}

	function newKube() confirmLoss("new", function() setKube(blank(), false, false));

	/**
	 * Bloques del juego con la misma forma y, en un cubo opaco con pixeles vacios, el aviso de que el mundo los pinta negros
	 * (BTFull no recorta por el alfa: un hueco, como un dessous vacio con los lados llenos, pide el rendu calado o translucido).
	 */
	function refreshShapeInfo() {
		var same = [];
		for( b in gameBlocks )
			if( KubeData.shapeOf(b) == kube.shape && (kube.shape.id != "cube" || KubeData.RENDERS.indexOf(b.type) == kube.render) ) {
				var n = KubeData.blockName(b);
				if( same.indexOf(n) < 0 ) same.push(n);
			}
		var s = same.length == 0 ? Lang.t("kube.shape.unused") : StringTools.replace(Lang.t("kube.shape.examples"), "%l%", same.slice(0, 6).join(", ") + (same.length > 6 ? "..." : ""));
		var holes = false;
		if( kube.blockType() == BTFull )
			for( f in kube.shape.faces ) for( c in kube.faces[f] ) if( c >>> 24 < 128 ) holes = true;
		shapeInfo.text = holes ? s + "\n\n" + Lang.t("kube.opaqueholes") : s;
		shapeInfo.textColor = holes ? Theme.ACCENT : Theme.DIM;
	}

	function drawFaceTabs() {
		faceTabs.removeChildren();
		faceButtons = [];
		var n = kube.shape.faces.length, w = Std.int((S * PX - (n - 1) * 4) / n);
		for( i in 0...n ) {
			var f = kube.shape.faces[i];
			var b = new KButton(faceTabs, faceLabel(f), w, 32, n > 4 ? 1.2 : 1.4);
			b.x = i * (w + 4);
			b.onClick = function() selectFace(f);
			faceButtons.push(b);
		}
	}

	/** nombre de la cara en esta forma: el motivo de las plantas, los extremos del tubo, la cruz de la jaula... */
	function faceLabel( f : Int ) : String {
		var id = kube.shape.id;
		var key = switch( f ) {
			case KubeData.SIDE if( kube.shape.faces.length == 1 ): "pattern";
			case KubeData.SIDE if( id == "door" ): "closed";
			case KubeData.UP if( id == "pipe" ): "end1";
			case KubeData.DOWN if( id == "pipe" ): "end2";
			case KubeData.UP if( id == "cage" ): "inner";
			default: KubeData.FACES[f];
		}
		return Lang.t("kube.face." + key);
	}

	function selectFace( f : Int ) {
		face = f;
		for( i in 0...faceButtons.length ) faceButtons[i].selected = kube.shape.faces[i] == f;
		// la puerta abierta se dibuja en la vista previa al pintar su cara
		if( kube.shape.id == "door" && (f == KubeData.OPEN) != doorOpen ) {
			doorOpen = f == KubeData.OPEN;
			doorButton.selected = doorOpen;
			rebuildPreview();
		}
		refreshCanvas();
	}

	function setTool( t : Int ) {
		tool = t;
		for( i in 0...toolButtons.length ) toolButtons[i].selected = i == t;
	}

	function drawBox() {
		for( a in 0...3 ) {
			var g = boxBars[a], lo = kube.box[a], hi = kube.box[a + 3];
			g.clear();
			Theme.rect(g, 0, 9, 240, 4, 0xFFFFFF, 0.12);
			for( i in 1...S ) Theme.rect(g, i * 240 / S, i % 8 == 0 ? 5 : 8, 1, i % 8 == 0 ? 12 : 6, 0xFFFFFF, 0.15);
			Theme.rect(g, lo * 240 / S, 8, (hi - lo) * 240 / S, 6, Theme.CYAN, 0.8);
			Theme.rect(g, lo * 240 / S - 3, 2, 6, 18, Theme.ACCENT);
			Theme.rect(g, hi * 240 / S - 3, 2, 6, 18, Theme.ACCENT);
			boxTexts[a].text = lo + " - " + hi;
		}
	}

	// ---------------------------------------------------------------- textura y vista previa

	/** la cara f en la tira, como en el atlas (dada la vuelta si el bloque la ensena al reves) */
	function refreshStripFace( f : Int ) {
		var px = kube.faces[f], flip = flipView[f];
		for( y in 0...S ) for( x in 0...S ) stripPix.setPixel(f * S + x, y, px[y * S + (flip ? S - 1 - x : x)]);
		stripDirty = true;
	}

	function refreshStrip() {
		for( f in 0...KubeData.FACES.length ) refreshStripFace(f);
	}

	/** la malla del bloque con la forma actual (la misma que dibuja el mundo), con la tira de caras en lugar del atlas */
	function rebuildPreview() {
		if( previewMesh != null ) {
			for( m in previewPasses ) m.remove();
			previewPasses = [];
			previewMesh.remove();
			previewMesh.primitive.dispose();
			previewMesh = null;
		}
		// otra forma puede ensenar las caras al otro derecho: la tira se rehace para que el bloque se siga viendo igual
		if( computeCover() ) refreshStrip();
		refreshCanvas();
		var b = kube.previewBlock(doorOpen && kube.shape.id == "door");
		cellBox.setScale(tiles);
		var poly = IconMesh.tiled(b, tiles);
		if( poly == null ) return;
		// casilla i de la fila 0 del atlas (64 de ancho) -> casilla i de la tira (8 de ancho)
		var n = KubeData.FACES.length;
		for( uv in poly.uvs ) {
			uv.u *= 64 / n;
			uv.v *= 64;
		}
		function material( culling : h3d.mat.Data.Face, killAlpha : Float ) {
			var mat = h3d.mat.Material.create(strip);
			mat.shadows = false;
			mat.mainPass.enableLights = false;
			mat.mainPass.culling = culling;
			mat.mainPass.addShader(new h3d.shader.VertexColor());
			if( killAlpha > 0 ) {
				mat.textureShader.killAlpha = true;
				mat.textureShader.killAlphaThreshold = killAlpha;
			}
			return mat;
		}
		// como World.emitMesh: lo opaco tal cual, lo translucido mezclado y el resto recortado por el alfa
		switch( b.type ) {
		case BTFull:
			previewMesh = new h3d.scene.Mesh(poly, material(None, 0), scene);
		case BTAlpha:
			// las tres pasadas del cristal y del hielo del mundo, todas sin la cara de atras: los pixeles solidos (marcos) opacos,
			// la profundidad de la cara translucida mas cercana y despues su color. Mezcladas sin mas, las caras de atras se
			// pintaban encima de las de delante (los marcos del fondo sobre los de delante)
			// las tres con el mismo programa, como en el mundo (World.AlphaCut): solo cambia el umbral del recorte por el alfa
			function cut( threshold : Float ) {
				var mat = material(Back, 0);
				mat.mainPass.addShader(new World.AlphaCut(threshold));
				return mat;
			}
			previewPasses.push(new h3d.scene.Mesh(poly, cut(0.9), scene));
			var depth = cut(0.25);
			depth.mainPass.setPassName("alpha");
			World.keepColor(depth.mainPass);
			depth.mainPass.layer = World.LAYER_ALPHA_DEPTH;
			previewPasses.push(new h3d.scene.Mesh(poly, depth, scene));
			var mat = cut(0);
			mat.blendMode = Alpha;
			mat.mainPass.depthWrite = false;
			mat.mainPass.setPassName("alpha");
			mat.mainPass.depthTest = LessEqual;
			mat.mainPass.layer = World.LAYER_ALPHA;
			previewMesh = new h3d.scene.Mesh(poly, mat, scene);
		default:
			previewMesh = new h3d.scene.Mesh(poly, material(None, 0.5), scene);
		}
	}

	/**
	 * Que pixeles de cada cara se ven con la forma (los UV de cada cara de la malla: una caja parcial solo muestra un recorte) y
	 * que caras salen al reves (flipView). Las caras verticales de un cubo entero o de 6 caras se ven con la izquierda y la
	 * derecha cambiadas respecto a su casilla, las de una caja no (sus UV van al contrario, Builder.addCustomQuad del original):
	 * mirando una cara desde fuera, con la camara de Heaps (mano izquierda), sale al derecho si el determinante de sus UV es
	 * positivo. Devuelve true si flipView ha cambiado.
	 */
	function computeCover() : Bool {
		cover = [for( _ in KubeData.FACES ) new haxe.ds.Vector<Bool>(S * S)];
		var seen = [for( _ in KubeData.FACES ) 0.], mirrored = [for( _ in KubeData.FACES ) 0.];
		var blocks = [kube.previewBlock(false)];
		if( kube.shape.id == "door" ) blocks.push(kube.previewBlock(true));
		for( b in blocks ) {
			var poly = IconMesh.polygon(b, true);
			if( poly == null ) continue;
			var uvs = poly.uvs, pts = poly.points, q = 0;
			while( q + 3 < uvs.length ) {
				// normal hacia fuera (orden de los vertices) y orientacion de la casilla en la cara; solo cuentan las verticales
				var n = pts[q + 1].sub(pts[q]).cross(pts[q + 2].sub(pts[q])), area = n.length();
				var tq = Std.int(uvs[q].u * 64 + 0.001);
				if( area > 1e-6 && Math.abs(n.z) < area * 0.5 && tq >= 0 && tq < seen.length ) {
					var det = (uvs[q + 1].u - uvs[q].u) * (uvs[q + 2].v - uvs[q].v) - (uvs[q + 2].u - uvs[q].u) * (uvs[q + 1].v - uvs[q].v);
					seen[tq] += area;
					if( det < 0 ) mirrored[tq] += area;
				}
				var u0 = 1e9, u1 = -1e9, v0 = 1e9, v1 = -1e9;
				for( k in 0...4 ) {
					var uv = uvs[q + k];
					u0 = Math.min(u0, uv.u * 64);
					u1 = Math.max(u1, uv.u * 64);
					v0 = Math.min(v0, uv.v * 64);
					v1 = Math.max(v1, uv.v * 64);
				}
				var t = Std.int((u0 + u1) * 0.5);
				if( t >= 0 && t < KubeData.FACES.length ) {
					inline function px( v : Float, up : Bool ) return Std.int(Math.max(0, Math.min(S, up ? Math.ceil(v * S - 0.05) : Math.floor(v * S + 0.05))));
					var x0 = px(u0 - t, false), x1 = px(u1 - t, true), y0 = px(v0, false), y1 = px(v1, true);
					for( y in y0...y1 ) for( x in x0...x1 ) cover[t][y * S + x] = true;
				}
				q += 4;
			}
			poly.dispose();
		}
		// las plantas, paneles y jaulas se ven por los dos lados: se dejan como en el atlas, igual que arriba y abajo
		var oriented = ORIENTED.indexOf(kube.shape.id) >= 0, changed = false;
		for( f in 0...flipView.length ) {
			var v = oriented && f != KubeData.UP && f != KubeData.DOWN && seen[f] > 0 && mirrored[f] > seen[f] * 0.6;
			if( v != flipView[f] ) changed = true;
			flipView[f] = v;
		}
		return changed;
	}

	function refreshCanvas() {
		veil.clear();
		// el lienzo ensena la cara como se ve en el bloque: la casilla de la tira dada la vuelta si hace falta
		var flip = flipView[face];
		art.tile = h2d.Tile.fromTexture(strip).sub(face * S, 0, S, S);
		art.scaleX = flip ? -PX : PX;
		art.x = flip ? CX + S * PX : CX;
		if( cover == null ) return;
		var c = cover[face];
		inline function shown( x : Int, y : Int ) return c[y * S + (flip ? S - 1 - x : x)];
		for( y in 0...S ) {
			var x = 0;
			while( x < S ) {
				if( shown(x, y) ) { x++; continue; }
				var x0 = x;
				while( x < S && !shown(x, y) ) x++;
				Theme.rect(veil, x0 * PX, y * PX, (x - x0) * PX, PX, 0x05070D, 0.62);
			}
		}
	}

	/**
	 * Camara de la vista previa: gira alrededor de lookAt, a una distancia proporcional al mosaico (el mosaico entero ocupa la vista
	 * como el kube solo). Para acercar se cierra el angulo, asi la camara no entra en el mosaico; para alejar se aleja.
	 */
	function setupCamera() {
		var cam = scene.camera, z = ZOOMS[zoomIndex];
		cam.orthoBounds = null;
		cam.fovY = 2 * Math.atan(Math.tan(15 * Math.PI / 180) / Math.max(1, z)) * 180 / Math.PI;
		cam.screenRatio = 1;
		cam.zNear = 0.1;
		cam.zFar = 50;
		var d = 3.4 * tiles / Math.min(1, z);
		cam.target.set(lookAt.x, lookAt.y, lookAt.z);
		cam.pos.set(lookAt.x + d * Math.cos(pitch) * Math.cos(yaw), lookAt.y + d * Math.cos(pitch) * Math.sin(yaw), lookAt.z + d * Math.sin(pitch));
		cam.up.set(0, 0, 1);
		cam.update();
	}

	function renderPreview() {
		setupCamera();
		var engine = h3d.Engine.getCurrent();
		engine.pushTarget(previewTex);
		engine.clear(0xFF101828, 1, 0);
		scene.render(engine);
		engine.popTarget();
	}

	/** mosaico de n x n x n: el zoom se queda, la camara vuelve a mirar al centro */
	function setTiles( n : Int ) {
		tiles = n;
		lookAt.set(n * 0.5, n * 0.5, n * 0.5);
		refreshTileButton();
		rebuildPreview();
	}

	/** "Mosaique 2x2" en la casilla entera; con una puerta, solo "2x2" y el boton de la puerta al lado */
	function refreshTileButton() {
		var door = kube.shape.id == "door", n = tiles + "×" + tiles;
		tileButton.resize(door ? 52 : 176);
		tileButton.setLabel(door ? n : Lang.t("kube.preview.tile") + "  " + n);
		tileButton.selected = tiles > 1;
	}

	/** un paso de zoom (d = +1 acerca); sx, sy: punto de la vista previa (-1..1, y hacia arriba) que se queda en su sitio */
	function zoomBy( d : Int, sx = 0., sy = 0. ) {
		var i = Std.int(Math.max(0, Math.min(ZOOMS.length - 1, zoomIndex + d)));
		if( i == zoomIndex ) return;
		setupCamera();
		var before = focusPlane(sx, sy);
		zoomIndex = i;
		var c = tiles * 0.5;
		if( ZOOMS[i] <= 1 )
			lookAt.set(c, c, c);
		else {
			setupCamera();
			var after = focusPlane(sx, sy);
			// mover la camara y su punto juntos traslada la vista: el punto de antes vuelve bajo el raton (sin salir del mosaico)
			inline function clamp( v : Float ) return Math.max(0, Math.min(tiles, v));
			lookAt.set(clamp(lookAt.x + before.x - after.x), clamp(lookAt.y + before.y - after.y), clamp(lookAt.z + before.z - after.z));
		}
		refreshZoomText();
	}

	/** punto que se ve en sx, sy de la vista previa, en el plano que pasa por lookAt de frente a la camara (setupCamera antes) */
	function focusPlane( sx : Float, sy : Float ) : h3d.col.Point {
		var cam = scene.camera;
		var a = cam.unproject(sx, sy, 0), b = cam.unproject(sx, sy, 1);
		var nx = cam.pos.x - lookAt.x, ny = cam.pos.y - lookAt.y, nz = cam.pos.z - lookAt.z;
		var dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z;
		var t = (nx * (lookAt.x - a.x) + ny * (lookAt.y - a.y) + nz * (lookAt.z - a.z)) / (nx * dx + ny * dy + nz * dz);
		return new h3d.col.Point(a.x + dx * t, a.y + dy * t, a.z + dz * t);
	}

	/** abajo en la vista previa, sobre una banda oscura: la ayuda de la rueda con el raton encima y el zoom si no es el de partida */
	function refreshZoomText() {
		var pct = Math.round(ZOOMS[zoomIndex] * 100) + "%";
		zoomText.text = previewOver ? Lang.t("kube.preview.zoom") + (zoomIndex != ZOOM1 ? "  ·  " + pct : "") : zoomIndex != ZOOM1 ? pct : "";
		var w = Std.int(zoomText.textWidth * zoomText.scaleX);
		zoomText.x = Std.int(RX + (RW - w) * 0.5);
		zoomBack.clear();
		if( zoomText.text != "" ) Theme.rect(zoomBack, zoomText.x - 6, PVY + PV - 20, w + 12, 20, 0x05070D, 0.75);
	}

	/** miniatura de la lista "Mis kubes": la vista de los iconos del inventario (desde +x, -y y arriba), del kube solo */
	function thumbPixels() : hxd.Pixels {
		var y0 = yaw, p0 = pitch, t0 = tiles, z0 = zoomIndex, f0 = lookAt.clone();
		yaw = -Math.PI / 4;
		pitch = 0.53;
		zoomIndex = ZOOM1;
		lookAt.set(0.5, 0.5, 0.5);
		if( t0 != 1 ) {
			tiles = 1;
			rebuildPreview();
		}
		renderPreview();
		yaw = y0;
		pitch = p0;
		zoomIndex = z0;
		lookAt.load(f0);
		if( t0 != 1 ) {
			tiles = t0;
			rebuildPreview();
		}
		var full = previewTex.capturePixels();
		var out = hxd.Pixels.alloc(64, 64, BGRA);
		var k = PV / 64;
		for( y in 0...64 ) for( x in 0...64 ) out.setPixel(x, y, full.getPixel(Std.int(x * k), Std.int(y * k)));
		return out;
	}

	// ---------------------------------------------------------------- pintar

	function canvasPush( x : Int, y : Int, button : Int ) {
		if( x < 0 || y < 0 || x >= S || y >= S ) return;
		if( typing ) nameInput.blur();
		var K = hxd.Key;
		if( tool == PICKER || (button == 0 && K.isDown(K.ALT)) ) {
			var c = kube.faces[face][y * S + x];
			if( c >>> 24 != 0 ) pickColor(c);
			if( tool == PICKER ) setTool(PENCIL);
			return;
		}
		snapshot([face]);
		if( tool == FILL && button == 0 ) {
			floodFill(x, y, color);
			if( mirror ) floodFill(S - 1 - x, y, color);
			endStroke();
			return;
		}
		painting = true;
		paintButton = button;
		lastX = x;
		lastY = y;
		plot(x, y);
	}

	function paintColor() : Int return paintButton != 0 || tool == ERASER ? 0 : color;

	function plot( x : Int, y : Int ) {
		var px = kube.faces[face], c = paintColor();
		px[y * S + x] = c;
		if( mirror ) px[y * S + S - 1 - x] = c;
		refreshStripFace(face);
	}

	/** linea de pixeles entre dos puntos (Bresenham): el raton salta varios pixeles entre dos imagenes */
	function line( x0 : Int, y0 : Int, x1 : Int, y1 : Int ) {
		var dx = Std.int(Math.abs(x1 - x0)), dy = -Std.int(Math.abs(y1 - y0));
		var sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, err = dx + dy;
		while( true ) {
			plot(x0, y0);
			if( x0 == x1 && y0 == y1 ) break;
			var e2 = 2 * err;
			if( e2 >= dy ) { err += dy; x0 += sx; }
			if( e2 <= dx ) { err += dx; y0 += sy; }
		}
	}

	static inline function same( a : Int, b : Int ) return a == b || (a >>> 24 == 0 && b >>> 24 == 0);

	function floodFill( x : Int, y : Int, c : Int ) {
		var px = kube.faces[face], target = px[y * S + x];
		if( same(target, c) ) return;
		var stack = [y * S + x];
		while( stack.length > 0 ) {
			var i = stack.pop();
			if( !same(px[i], target) ) continue;
			px[i] = c;
			var xx = i % S, yy = Std.int(i / S);
			if( xx > 0 ) stack.push(i - 1);
			if( xx < S - 1 ) stack.push(i + 1);
			if( yy > 0 ) stack.push(i - S);
			if( yy < S - 1 ) stack.push(i + S);
		}
		refreshStripFace(face);
	}

	function endStroke() {
		painting = false;
		dirty = true;
		refreshKubeColors();
		refreshShapeInfo();
	}

	/** guarda las caras antes de un cambio (un trazo, voltear, vaciar...) para poder deshacerlo */
	function snapshot( fs : Array<Int> ) {
		undoStack.push([for( f in fs ) { f : f, px : kube.faces[f].copy() }]);
		if( undoStack.length > HISTORY ) undoStack.shift();
		redoStack = [];
	}

	function restore( from : Array<Array<{ f : Int, px : haxe.ds.Vector<Int> }>>, to : Array<Array<{ f : Int, px : haxe.ds.Vector<Int> }>> ) {
		var e = from.pop();
		if( e == null ) return;
		to.push([for( s in e ) { f : s.f, px : kube.faces[s.f].copy() }]);
		for( s in e ) {
			kube.faces[s.f] = s.px;
			refreshStripFace(s.f);
		}
		if( !kube.usesFace(face) || e.length == 1 && e[0].f != face && kube.usesFace(e[0].f) ) selectFace(e[0].f);
		dirty = true;
		refreshKubeColors();
		refreshShapeInfo();
	}

	function undo() restore(undoStack, redoStack);

	function redo() restore(redoStack, undoStack);

	/** voltear o girar la cara: dst(x, y) da donde va el pixel x, y */
	function transformFace( dst : Int -> Int -> Int ) {
		snapshot([face]);
		var src = kube.faces[face].copy(), px = kube.faces[face];
		for( y in 0...S ) for( x in 0...S ) px[dst(x, y)] = src[y * S + x];
		refreshStripFace(face);
		endStroke();
	}

	function clearFace() {
		snapshot([face]);
		var px = kube.faces[face];
		for( i in 0...S * S ) px[i] = 0;
		refreshStripFace(face);
		endStroke();
	}

	function copyToAll() {
		var others = [for( f in kube.shape.faces ) if( f != face ) f];
		if( others.length == 0 ) return;
		snapshot(others);
		for( f in others ) {
			kube.copyFace(face, f);
			refreshStripFace(f);
		}
		endStroke();
		message(Lang.t("kube.copied"));
	}

	// ---------------------------------------------------------------- color

	static function hsvToRgb( h : Float, s : Float, v : Float ) : Int {
		var hh = (h - Math.floor(h)) * 6, i = Std.int(hh), f = hh - i;
		var p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
		var rgb = switch( i ) {
			case 0: [v, t, p];
			case 1: [q, v, p];
			case 2: [p, v, t];
			case 3: [p, q, v];
			case 4: [t, p, v];
			default: [v, p, q];
		}
		return (Math.round(rgb[0] * 255) << 16) | (Math.round(rgb[1] * 255) << 8) | Math.round(rgb[2] * 255);
	}

	/** color elegido (paleta, pipeta): un gris no cambia el tono de las barras */
	function pickColor( c : Int ) {
		var r = ((c >> 16) & 0xFF) / 255, g = ((c >> 8) & 0xFF) / 255, b = (c & 0xFF) / 255;
		var mx = Math.max(r, Math.max(g, b)), mn = Math.min(r, Math.min(g, b)), d = mx - mn;
		if( d > 0 ) {
			var h = mx == r ? (g - b) / d : mx == g ? 2 + (b - r) / d : 4 + (r - g) / d;
			hue = (h / 6 + 1) % 1;
		}
		sat = mx == 0 ? 0 : d / mx;
		val = mx;
		opacity = (c >>> 24) / 255;
		color = c;
		if( tool == ERASER || tool == PICKER ) setTool(PENCIL);
		drawColor();
	}

	function setBar( i : Int, v : Float ) {
		v = Math.max(0, Math.min(1, v));
		switch( i ) {
		case 0: hue = Math.min(v, 0.999);
		case 1: sat = v;
		case 2: val = v;
		default: opacity = v;
		}
		color = (Math.round(opacity * 255) << 24) | hsvToRgb(hue, sat, val);
		if( tool == ERASER || tool == PICKER ) setTool(PENCIL);
		drawColor();
	}

	function drawColor() {
		swatch.clear();
		Theme.rect(swatch, 0, 0, 52, 52, 0x2A303C);
		Theme.rect(swatch, 0, 0, 26, 26, 0x363D4B);
		Theme.rect(swatch, 26, 26, 26, 26, 0x363D4B);
		Theme.rect(swatch, 0, 0, 52, 52, color & 0xFFFFFF, opacity);
		Theme.rect(swatch, 0, 52, 52, 1, 0xFFFFFF, 0.2);
		hexText.text = "#" + StringTools.hex(color & 0xFFFFFF, 6);
		opacityText.text = Math.round(opacity * 100) + "%";
		var vals = [hue, sat, val, opacity];
		for( i in 0...4 ) {
			var g = bars[i];
			g.clear();
			var n = 45;
			for( k in 0...n ) {
				var f = k / (n - 1);
				var c = switch( i ) {
					case 0: hsvToRgb(f, 1, 1);
					case 1: hsvToRgb(hue, f, val);
					case 2: hsvToRgb(hue, sat, f);
					default: k & 1 == 0 ? 0x2A303C : 0x4A5470;
				}
				Theme.rect(g, k * 4, 0, 4, 18, c);
				if( i == 3 ) Theme.rect(g, k * 4, 0, 4, 18, color & 0xFFFFFF, f);
			}
			Theme.rect(g, vals[i] * 180 - 2, -2, 4, 22, 0xFFFFFF);
		}
	}

	/** los 16 colores que mas se usan en las caras del kube, para retocar con los mismos tonos */
	function refreshKubeColors() {
		kubeColors.removeChildren();
		var count = new Map<Int, Int>();
		for( f in kube.shape.faces )
			for( c in kube.faces[f] )
				if( c >>> 24 != 0 ) count.set(c, (count.exists(c) ? count.get(c) : 0) + 1);
		var cs = [for( c in count.keys() ) c];
		cs.sort(function(a, b) return count.get(b) - count.get(a));
		var g = new h2d.Graphics(kubeColors);
		for( i in 0...Std.int(Math.min(16, cs.length)) ) {
			var c = cs[i];
			Theme.rect(g, i * 20, 0, 18, 18, c & 0xFFFFFF, Math.max(0.25, (c >>> 24) / 255));
			var it = new h2d.Interactive(18, 18, kubeColors);
			it.x = i * 20;
			it.onClick = function(_) pickColor(c);
		}
	}

	// ---------------------------------------------------------------- lista de kubes

	function showTab( t : Int ) {
		tab = t;
		if( t == 0 && gameList.numChildren == 0 ) buildGameList();
		if( t == 1 ) loadMine();
		gameList.visible = t == 0;
		mineList.visible = t == 1;
		for( i in 0...2 ) tabButtons[i].selected = i == t;
		scrollList(0);
	}

	/** una casilla por bloque del juego, una sola vez: los iconos que falten se pintan unos pocos por imagen (Icons.pump) y se quedan */
	function buildGameList() {
		for( i in 0...gameBlocks.length ) {
			var b = gameBlocks[i];
			var cell = new h2d.Object(gameList);
			cell.setPosition((i % COLS) * CELL, Std.int(i / COLS) * CELL);
			var g = new h2d.Graphics(cell);
			Theme.rect(g, 1, 1, CELL - 2, CELL - 2, 0xFFFFFF, 0.05);
			Icons.bitmap(cell, b, 48, atlas).setPosition(4, 4);
			var it = new h2d.Interactive(CELL - 2, CELL - 2, cell);
			it.propagateEvents = true;
			it.onOver = function(_) {
				g.clear();
				Theme.rect(g, 1, 1, CELL - 2, CELL - 2, Theme.ACCENT, 0.3);
				listInfo.text = KubeData.blockName(b);
			};
			it.onOut = function(_) {
				g.clear();
				Theme.rect(g, 1, 1, CELL - 2, CELL - 2, 0xFFFFFF, 0.05);
			};
			it.onClick = function(_) if( overList() ) confirmLoss("block" + b.index, function() {
				var k = KubeData.fromBlock(b);
				setKube(k, false, true);
				message(StringTools.replace(Lang.t("kube.loaded"), "%n%", k.name));
			});
		}
	}

	/** relee los .kube de la carpeta (al entrar en Mis kubes y al guardar o borrar uno) */
	function loadMine() {
		mine = [];
		for( p in KubeData.list() ) {
			var info = KubeData.peek(p);
			if( info == null ) continue;
			mine.push({ path : p, name : info.name, thumb : info.thumb == null ? null : h2d.Tile.fromPixels(info.thumb) });
		}
		drawMine();
	}

	/** Mis kubes: primero la fila para empezar uno de cero, luego los kubes guardados (el que se esta editando, marcado) */
	function drawMine() {
		if( mine == null ) return;
		mineList.removeChildren();
		function row( i : Int, label : String, thumb : h2d.Tile, current : Bool, hint : String, onClick : Void -> Void ) {
			var r = new h2d.Object(mineList);
			r.y = i * CELL;
			var g = new h2d.Graphics(r);
			Theme.rect(g, 1, 1, COLS * CELL - 2, CELL - 2, current ? Theme.ACCENT : 0xFFFFFF, current ? 0.2 : 0.05);
			if( thumb != null ) {
				// lisa, como los iconos de los bloques (Icons.bitmap): 64 px reducidos con el nearest de h2d salian pixelados
				var bmp = new h2d.Bitmap(thumb, r);
				bmp.smooth = true;
				bmp.setScale(48 / thumb.width);
				bmp.setPosition(4, 4);
			}
			var t = Theme.text(r, label, 1.4, thumb == null ? Theme.ACCENT : Theme.TEXT, thumb == null ? 14 : 60, 0);
			t.y = Std.int((CELL - t.textHeight * t.scaleY) * 0.5);
			var it = new h2d.Interactive(COLS * CELL - 2, CELL - 2, r);
			it.propagateEvents = true;
			it.onOver = function(_) listInfo.text = hint;
			it.onClick = function(_) if( overList() ) onClick();
		}
		row(0, "+  " + Lang.t("kube.mine.new"), null, false, "", newKube);
		if( mine.length == 0 ) {
			var t = Theme.text(mineList, Lang.t("kube.mine.empty"), 1.3, Theme.DIM, 6, CELL + 8);
			t.maxWidth = (COLS * CELL - 12) / t.scaleX;
		}
		for( i in 0...mine.length ) {
			var m = mine[i];
			row(i + 1, m.name, m.thumb, kube != null && kube.file == m.path, new haxe.io.Path(m.path).file + ".kube", function() confirmLoss("file" + m.path, function() {
				var k = KubeData.load(m.path);
				if( k == null ) {
					message(Lang.t("kube.loadfail"), true);
					return;
				}
				setKube(k, true, true);
				message(StringTools.replace(Lang.t("kube.loaded"), "%n%", k.name));
			}));
		}
	}

	/** h2d.Mask solo recorta el dibujo: una casilla medio tapada no debe recibir el clic que cae fuera de la lista */
	function overList() : Bool {
		var sc = getScene();
		return sc != null && sc.mouseY >= LY && sc.mouseY < LY + ROWS * CELL;
	}

	function listHeight() : Float return tab == 0 ? Math.ceil(gameBlocks.length / COLS) * CELL : (mine.length + 1) * CELL;

	/** pide desplazar la lista d pixeles; update la lleva hasta ahi poco a poco */
	function scrollList( d : Float ) {
		var max = Math.max(0, listHeight() - ROWS * CELL);
		scrollTarget[tab] = Math.max(0, Math.min(max, scrollTarget[tab] + d));
		if( listInfo.text == "" || d == 0 ) listInfo.text = max > 0 ? Lang.t("kube.list.scroll") : "";
	}

	function updateList( dt : Float ) {
		var list = tab == 0 ? gameList : mineList;
		var p = scrollPos[tab], target = scrollTarget[tab];
		p += (target - p) * Math.min(1, dt * 14);
		if( Math.abs(target - p) < 0.5 ) p = target;
		scrollPos[tab] = p;
		list.y = -Math.round(p);
		// las filas fuera de la mascara se esconden: sin eso seguirian recibiendo clics sobre las pestanas y el texto de abajo
		for( c in list ) c.visible = c.y + list.y > -CELL && c.y + list.y < ROWS * CELL;
	}


	// ---------------------------------------------------------------- guardar, carpeta, borrar

	/** accion que pierde los cambios sin guardar: con cambios, hace falta repetirla antes de 3 s */
	function confirmLoss( key : String, action : Void -> Void ) {
		if( dirty && (pendingKey != key || pendingTime <= 0) ) {
			pendingKey = key;
			pendingTime = 3;
			message(Lang.t("kube.discard"), true);
			return;
		}
		pendingKey = null;
		action();
	}

	public function saveKube() {
		if( StringTools.trim(kube.name) == "" ) {
			kube.name = Lang.t("kube.newname");
			nameInput.text = kube.name;
		}
		try {
			var path = kube.save(thumbPixels(), flipView);
			dirty = false;
			deleteButton.enabled = true;
			if( mine != null ) loadMine();
			message(StringTools.replace(Lang.t("kube.saved"), "%p%", new haxe.io.Path(path).file + ".kube"));
		} catch( e : Dynamic ) {
			message(StringTools.replace(Lang.t("kube.savefail"), "%e%", Std.string(e)), true);
		}
	}

	static function winPath( p : String ) return Sys.systemName() == "Windows" ? StringTools.replace(p, "/", "\\") : p;

	function openFolder() {
		var d = winPath(KubeData.dir());
		try {
			new sys.io.Process(Sys.systemName() == "Windows" ? "explorer" : "xdg-open", [d]);
		} catch( e : Dynamic ) {}
		message(StringTools.replace(Lang.t("kube.folderpath"), "%p%", d));
	}

	function deleteKube() {
		if( kube.file == null ) return;
		if( pendingKey != "delete" || pendingTime <= 0 ) {
			pendingKey = "delete";
			pendingTime = 3;
			message(Lang.t("kube.deleteask"), true);
			return;
		}
		pendingKey = null;
		try sys.FileSystem.deleteFile(kube.file) catch( e : Dynamic ) {}
		kube.file = null;
		dirty = true;
		deleteButton.enabled = false;
		if( mine != null ) loadMine();
		message(Lang.t("kube.deleted"));
	}

	function close() {
		if( typing ) nameInput.blur();
		if( onClose != null ) onClose();
	}

	function message( s : String, warn = false ) {
		msgText.text = s;
		msgText.textColor = warn ? Theme.DANGER : Theme.ACCENT;
		msgText.visible = true;
		helpText.visible = false;
		msgTime = 4;
	}

	// ---------------------------------------------------------------- cada imagen

	/** la pantalla se quita al cambiar de idioma o al empezar una partida (GalaxyApp.clearUi): sus texturas con ella */
	override function onRemove() {
		super.onRemove();
		previewTex.depthBuffer.dispose();
		previewTex.dispose();
		strip.dispose();
		scene.dispose();
	}

	override function update( dt : Float, pad : hxd.Pad ) {
		if( !visible ) return;
		var K = hxd.Key;
		var sc = getScene();
		var mx = sc == null ? 0. : sc.mouseX, my = sc == null ? 0. : sc.mouseY;

		if( drag != null ) {
			if( K.isDown(K.MOUSE_LEFT) ) drag(mx, my) else drag = null;
		}
		var hx = Math.floor((mx - CX) / PX), hy = Math.floor((my - CY) / PX);
		var inside = hx >= 0 && hy >= 0 && hx < S && hy < S;
		if( painting ) {
			if( !K.isDown(paintButton == 0 ? K.MOUSE_LEFT : K.MOUSE_RIGHT) ) endStroke();
			else {
				var x = Std.int(Math.max(0, Math.min(S - 1, hx))), y = Std.int(Math.max(0, Math.min(S - 1, hy)));
				if( x != lastX || y != lastY ) line(lastX, lastY, x, y);
				lastX = x;
				lastY = y;
			}
		}
		hoverG.clear();
		if( inside ) {
			hoverG.lineStyle(1, 0xFFFFFF, 0.9);
			hoverG.drawRect(hx * PX, hy * PX, PX, PX);
			if( mirror ) hoverG.drawRect((S - 1 - hx) * PX, hy * PX, PX, PX);
			var c = kube.faces[face][hy * S + hx];
			posText.text = hx + ", " + hy + "   " + (c >>> 24 == 0 ? Lang.t("kube.empty") : "#" + StringTools.hex(c & 0xFFFFFF, 6));
		} else
			posText.text = Lang.t("kube.unused");

		if( !typing ) {
			var ctrl = K.isDown(K.CTRL);
			if( ctrl && K.isPressed(K.Z) ) K.isDown(K.SHIFT) ? redo() : undo();
			else if( ctrl && K.isPressed(K.Y) ) redo();
			else if( ctrl && K.isPressed(K.S) ) saveKube();
			else if( !ctrl ) {
				if( K.isPressed(K.B) || K.isPressed(K.NUMBER_1) ) setTool(PENCIL);
				if( K.isPressed(K.E) || K.isPressed(K.NUMBER_2) ) setTool(ERASER);
				if( K.isPressed(K.G) || K.isPressed(K.NUMBER_3) ) setTool(FILL);
				if( K.isPressed(K.I) || K.isPressed(K.NUMBER_4) ) setTool(PICKER);
				if( K.isPressed(K.M) ) mirrorButton.onClick();
				if( K.isPressed(K.NUMPAD_ADD) || K.isPressed(K.QWERTY_EQUALS) ) zoomBy(1);
				if( K.isPressed(K.NUMPAD_SUB) || K.isPressed(K.QWERTY_MINUS) ) zoomBy(-1);
				var fs = kube.shape.faces, fi = fs.indexOf(face);
				if( K.isPressed(K.LEFT) || K.isPressed(K.PGUP) ) selectFace(fs[(fi + fs.length - 1) % fs.length]);
				if( K.isPressed(K.RIGHT) || K.isPressed(K.PGDOWN) || K.isPressed(K.TAB) ) selectFace(fs[(fi + 1) % fs.length]);
			}
			if( K.isPressed(K.ESCAPE) || (pad != null && pad.isPressed(pad.config.B)) ) close();
		} else if( K.isPressed(K.ESCAPE) || K.isPressed(K.ENTER) || K.isPressed(K.NUMPAD_ENTER) )
			nameInput.blur();

		updateList(dt);
		if( pendingTime > 0 ) pendingTime -= dt;
		if( msgTime > 0 && (msgTime -= dt) <= 0 ) {
			msgText.visible = false;
			helpText.visible = true;
		}
		if( spin && drag == null ) yaw += dt * 0.6;
		if( stripDirty ) {
			strip.uploadPixels(stripPix);
			stripDirty = false;
		}
		renderPreview();
	}

	// ---------------------------------------------------------------- banco de pruebas (orden kube de Dev)

	public function devInfo() : String {
		var used = 0;
		for( f in kube.shape.faces ) for( v in cover[f] ) if( v ) used++;
		return "kube '" + kube.name + "' forma " + kube.shape.id + " tipo " + kube.blockType() + " caja " + kube.box.join(",") + " luz "
			+ kube.light + " traversable " + kube.noCollide + " cara " + KubeData.FACES[face] + " caras " + [for( f in kube.shape.faces ) KubeData.FACES[f]].join("/")
			+ " pixeles visibles " + used + " cambios " + dirty + " deshacer " + undoStack.length + " archivo " + (kube.file == null ? "-" : new haxe.io.Path(kube.file).file)
			+ " lista " + (tab == 0 ? gameBlocks.length + " bloques" : mine.length + " kubes") + " mosaico " + tiles + " zoom " + ZOOMS[zoomIndex]
			+ " foco " + [lookAt.x, lookAt.y, lookAt.z].map(v -> Math.round(v * 100) / 100).join(",") + " caras vista " + previewFaces();
	}

	/** caras de la malla de la vista previa (el mosaico sin las caras de dentro) */
	function previewFaces() : Int {
		if( previewMesh == null ) return 0;
		var poly = Std.downcast(previewMesh.primitive, h3d.prim.Polygon);
		return poly == null ? 0 : Std.int(poly.points.length / 4);
	}

	/** dev: mosaico de n x n x n */
	public function devTiles( n : Int ) setTiles(Std.int(Math.max(1, Math.min(3, n))));

	/** dev: el paso de zoom mas cercano a z, hacia el centro de la vista */
	public function devZoom( z : Float ) {
		var best = 0;
		for( i in 0...ZOOMS.length ) if( Math.abs(ZOOMS[i] - z) < Math.abs(ZOOMS[best] - z) ) best = i;
		zoomBy(best - zoomIndex);
	}

	/** dev: vista fija, la de los iconos (sin girar), para comparar capturas */
	public function devView() {
		spin = false;
		spinButton.selected = false;
		yaw = -Math.PI / 4;
		pitch = 0.53;
	}

	/** dev: pinta (o borra con color 0) un rectangulo de la cara actual como un trazo */
	public function devPaint( x0 : Int, y0 : Int, x1 : Int, y1 : Int, c : Int ) {
		snapshot([face]);
		for( y in y0...y1 + 1 ) for( x in x0...x1 + 1 ) kube.faces[face][y * S + x] = c;
		refreshStripFace(face);
		endStroke();
	}

	public function devShape( id : String ) {
		shapeChoice.set(KubeData.SHAPES.indexOf(KubeData.shapeById(id)));
		shapeChoice.onChange(shapeChoice.index);
	}

	public function devLoadBlock( b : Block ) setKube(KubeData.fromBlock(b), false, true);

	public function devFace( f : Int ) selectFace(f);

	public function devTab( t : Int ) showTab(t);

	public function devName( n : String ) {
		nameInput.text = n;
		nameInput.onChange();
	}

	public function devLoadFile( i : Int ) {
		var k = KubeData.load(mine[i].path);
		if( k != null ) setKube(k, true, true);
	}
}
