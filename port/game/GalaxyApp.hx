import Ui;
import SaveData.SaveInfo;

enum State {
	Boot;
	Menu;
	Loading;
	Playing;
	Paused;
	Exploring;
}

/**
 * Fila de la lista de partidas guardadas: miniatura, nombre y datos. Con el foco muestra sus acciones (jugar, renombrar, borrar):
 * izquierda/derecha eligen una e Intro (o A) la hace; un clic en un boton hace lo suyo y uno en el resto de la fila juega.
 */
class SaveRow extends Widget {
	public static var ACTIONS = ["play", "rename", "delete"];
	public static inline var W = 1000;
	static inline var BW = 132;
	static inline var BH = 36;
	public var info(default, null) : SaveInfo;
	/** accion elegida (indice de ACTIONS); vuelve a Jugar cuando la fila pierde el foco */
	public var action(default, set) = 0;
	public var onAction : Int -> Void;
	var acts : h2d.Object;
	var actBg : Array<h2d.Graphics>;
	var actText : Array<h2d.Text>;

	public function new( parent : h2d.Object, info : SaveInfo ) {
		super(parent, W, 104);
		this.info = info;
		label.visible = false;
		var tb = SaveData.thumb(info.id);
		var thumb : h2d.Tile = null;
		if( tb != null ) {
			try thumb = hxd.res.Any.fromBytes("t.png", tb).toTile() catch( e : Dynamic ) {}
		}
		if( thumb != null ) {
			var bm = new h2d.Bitmap(thumb, this);
			bm.x = 8;
			bm.y = 7;
			bm.scaleX = 160 / thumb.width;
			bm.scaleY = 90 / thumb.height;
		} else {
			var ph = new h2d.Graphics(this);
			Theme.rect(ph, 8, 7, 160, 90, 0xFFFFFF, 0.07);
		}
		Theme.text(this, info.name, 2.4, Theme.TEXT, 190, 10);
		var size = 128 * info.sizeChunks;
		var where = info.uni != null && info.uni.space == true ? Lang.t("save.space") : Lang.t("biome." + info.biome) + "  ·  " + size + "x" + size;
		Theme.text(this, where + "  ·  " + Lang.t("seed") + " " + info.seed + (info.creative == true ? "  ·  " + Lang.t("mode.creative") : ""), 1.7, Theme.CYAN, 190, 48);
		Theme.text(this, Lang.t("played") + " " + Lang.duration(info.playSeconds) + "   " + Lang.t("saved") + " " + Lang.date(info.saved), 1.5, Theme.DIM, 190, 74);
		// botones de las acciones, arriba a la derecha (el nombre tiene 24 letras como mucho y no llega a ellos)
		acts = new h2d.Object(this);
		actBg = [];
		actText = [];
		var x0 = w - 14 - ACTIONS.length * (BW + 8) + 8;
		for( i in 0...ACTIONS.length ) {
			var b = new h2d.Object(acts);
			b.x = x0 + i * (BW + 8);
			b.y = 10;
			actBg.push(new h2d.Graphics(b));
			var t = Theme.text(b, Lang.t(ACTIONS[i]), 1.8, Theme.TEXT);
			Theme.center(t, BW, BH);
			actText.push(t);
			var it = new h2d.Interactive(BW, BH, b);
			it.onOver = function(_) if( enabled ) {
				if( onHover != null ) onHover(this);
				action = i;
			};
			it.onClick = function(_) if( enabled ) {
				if( onPress != null ) onPress(this);
				action = i;
				activate();
			};
		}
		acts.visible = false;
		onLeft = function() if( action > 0 ) action--;
		onRight = function() if( action < ACTIONS.length - 1 ) action++;
		onActivate = function() if( onAction != null ) onAction(action);
		inter.onClick = function(_) if( enabled ) {
			if( onPress != null ) onPress(this);
			action = 0;
			activate();
		};
		drawActions();
	}

	function set_action( v : Int ) {
		action = v;
		drawActions();
		return v;
	}

	override function set_focused( v : Bool ) {
		if( !v ) action = 0;
		super.set_focused(v);
		if( acts != null ) acts.visible = v;
		return v;
	}

	function drawActions() {
		if( actBg == null ) return;
		for( i in 0...actBg.length ) {
			var g = actBg[i], on = i == action;
			g.clear();
			if( on ) Theme.rect(g, 0, 0, BW, BH, ACTIONS[i] == "delete" ? Theme.DANGER : Theme.ACCENT, 0.9);
			else Theme.rect(g, 0, 0, BW, BH, 0xFFFFFF, 0.08);
			actText[i].textColor = on ? Theme.BG : Theme.TEXT;
		}
	}
}

/**
 * Pantalla de partidas guardadas: se ven VISIBLE filas y la lista se desplaza con la rueda, las flechas, el mando y Re Pag / Av Pag.
 * El foco siempre queda en una fila a la vista.
 */
class LoadScreen extends Screen {
	public var rows = new Array<SaveRow>();
	public var top = 0;
	public static inline var VISIBLE = 4;
	static inline var STEP = 112;
	public var listX = 130.;
	public var listY = 140.;
	var bar : h2d.Graphics;

	override function setFocus( i : Int ) {
		super.setFocus(i);
		if( i >= 0 && i < rows.length ) {
			if( i < top ) top = i;
			if( i >= top + VISIBLE ) top = i - VISIBLE + 1;
			layout();
		}
	}

	/** rueda del raton: desplaza la lista una fila; si la fila con el foco sale de la vista, el foco pasa a la mas cercana */
	public function scroll( d : Int ) {
		var t = top + d, max = rows.length - VISIBLE;
		if( t > max ) t = max;
		if( t < 0 ) t = 0;
		if( t == top ) return;
		top = t;
		if( focus < rows.length ) {
			if( focus < top ) setFocus(top);
			else if( focus >= top + VISIBLE ) setFocus(top + VISIBLE - 1);
		}
		layout();
	}

	override function update( dt : Float, pad : hxd.Pad ) {
		// Re Pag / Av Pag: una pagina de filas (con el foco en Volver no hacen nada)
		var K = hxd.Key;
		var page = K.isPressed(K.PGDOWN) ? 1 : K.isPressed(K.PGUP) ? -1 : 0;
		if( active && page != 0 && focus < rows.length ) {
			var i = focus + page * VISIBLE;
			setFocus(i < 0 ? 0 : i >= rows.length ? rows.length - 1 : i);
		}
		super.update(dt, pad);
	}

	public function layout() {
		for( i in 0...rows.length ) {
			var r = rows[i];
			r.visible = i >= top && i < top + VISIBLE;
			r.x = listX;
			r.y = listY + (i - top) * STEP;
		}
		// barra de desplazamiento a la derecha de las filas, solo si no caben todas
		if( bar == null ) bar = new h2d.Graphics(this);
		bar.clear();
		if( rows.length > VISIBLE ) {
			var x = listX + SaveRow.W + 12, h = VISIBLE * STEP - 8;
			var th = h * VISIBLE / rows.length;
			Theme.rect(bar, x, listY, 6, h, 0xFFFFFF, 0.08);
			Theme.rect(bar, x, listY + (h - th) * top / (rows.length - VISIBLE), 6, th, Theme.ACCENT, 0.8);
		}
	}
}

class GalaxyApp extends hxd.App {

	static inline var W = Theme.W;
	static inline var H = Theme.H;
	/** color de fx.Load */
	static inline var LOAD_COLOR = 0xC93814;
	static var BIOMES = ["BIAutumn", "BIMoon", "BIMars", "BIWinterPeaks", "BIAcidForest"];
	/** se pueden elegir pero no salen al azar: en el original la Ciudad Muerta tenia probabilidad 0 */
	static var EXTRA_BIOMES = ["BIDeadCity"];

	var state : State = Boot;
	var atlas : h3d.mat.Texture;
	var bgWorlds = new Array<World>();
	var bgQueue = new Array<String>();
	var bgBuilding : World;
	var bgIndex = 0;
	var bgTimer = 0.;
	var bgFade = 0;
	var bgFadeT = 0.;
	var bgCamZ = -1.;
	var bgPhase = 0.;
	var bgAlt = new Array<Float>();
	var bgCx = 64.;
	var bgCy = 64.;
	var bgR = 38.;
	var snow : Snow;
	var loadWorld : World;
	var loadInfo : SaveInfo;
	var game : GameView;
	var pad : hxd.Pad;

	var ui : h2d.Object;
	var dim : h2d.Bitmap;
	/** velo del color del liquido con la camara dentro (fades del original) */
	var liquidVeil : h2d.Bitmap;
	/** nombre del bloque al que apuntas (con la mano vacia) */
	var targetName : h2d.Text;
	var screens = new Map<String, Screen>();
	var current : Screen;
	var currentName = "";
	var overlayDecor : h2d.Object;
	/** menu principal y su texto de version: se pegan a los bordes de la ventana en cada fotograma (anchorToWindow) */
	var mainScreen : Screen;
	var versionText : h2d.Text;
	var bar : h2d.Graphics;
	var barText : h2d.Text;
	/** barra de la carga de un planeta (fx.Load del original) y la posicion de su trozo (progress, de 0 a 1) */
	var loadAnim : h2d.Graphics;
	var loadAnimPos = 0.;
	var hud : h2d.Text;
	/** F: coordenadas y fps (Game.showFPS del original): ocultos al empezar y sin guardar en settings.json, como en el original */
	var showFps = false;
	var msgText : h2d.Text;
	var jetGlow : h2d.Bitmap;
	var jetBar : h2d.Graphics;
	/** barras de vida y de oxigeno (Interface.lifeMC, oxygenMC): solo se ven si no estan llenas */
	var lifeBar : h2d.Graphics;
	var oxyBar : h2d.Graphics;
	/** icono de estado "power" del turbo minero (Interface.statusMC) */
	var statusIcon : h2d.Bitmap;
	var statusTime = 0.;
	/** fundido de color de los golpes, la curacion y la muerte (Game.fadeFX) */
	var hurtRect : h2d.Bitmap;
	var invBar : InvBar;
	var cross : h2d.Graphics;
	var dot : h2d.Graphics;
	var fadeRect : h2d.Bitmap;
	/** temblor del HUD de este fotograma (Interface.updateShake: ui.y), en unidades de s2d: mueve el inventario, la mira,
	    las barras y el mensaje, no el casco ni el brillo del jetpack (el original los dibuja en la escena 3D) */
	var hudShake = 0.;

	// casco (Game.hudOn, render.hud[H_HELMET]): posicion en pixeles de la imagen de 1024x1024
	var helmet : h2d.Bitmap;
	var helmetOn = true;
	var helmetX = -20.;
	var helmetY = -190.;
	var helmetSeq = new Array<{ wait : Bool, to : Float, dur : Float, easeIn : Bool }>();
	var helmetT = 0.;
	var helmetFrom = 0.;
	var helmetOnDone : Void -> Void;
	var toast : h2d.Text;
	var toastTime = 0.;
	var orbit = 0.;
	var autosaveTimer = 0.;
	var frames = 0;
	var captured = false;

	// pruebas automaticas (captura de pantalla)
	var shotPath : String = null;
	var dev : Dev;
	var shotSeed = 1234;
	var shotLoad : String;
	var shotScreen = "main";
	var shotFrames = 30;
	var demoSaves = false;
	var shotBiome : String = null;
	var shotCont = false;
	var shotN = 20;
	var shotSlot = 2;
	var shotAt : Array<Float> = null; // --at=x,y,yaw[,pitch,z]: coloca al jugador para la captura

	// formulario de nueva partida
	var nName : TextField;
	var nSeed : TextField;
	var nBiome : Selector;
	var nSize : Selector;
	var nMode : Selector;
	var nTutorial : Selector;
	public var palette : Palette;
	var paletteOpen = false;

	/** tutorial de la partida de aventura y lo que se ve de el (objetivo, flecha y aura) */
	var tutorial = new Tutorial();
	var guide : TutoGuide;
	/** guardar en cuanto se abre el mapa (partida nueva o tutorial pasado: empiezan en el espacio) y aviso que se muestra entonces */
	var saveOnMap = false;
	var mapToast : String;

	override function init() {
		PortRules.apply();
		for( a in Sys.args() ) {
			if( StringTools.startsWith(a, "--shot=") ) shotPath = a.substr(7);
			else if( StringTools.startsWith(a, "--screen=") ) shotScreen = a.substr(9);
			else if( StringTools.startsWith(a, "--frames=") ) shotFrames = Std.parseInt(a.substr(9));
			else if( StringTools.startsWith(a, "--script=") ) {
				dev = new Dev(a.substr(9));
				shotPath = "port/out/dev.png";
				shotScreen = "game";
			}
			else if( StringTools.startsWith(a, "--load=") ) shotLoad = a.substr(7);
			else if( StringTools.startsWith(a, "--seed=") ) shotSeed = Std.parseInt(a.substr(7));
			else if( a == "--demo-saves" ) demoSaves = true;
			else if( StringTools.startsWith(a, "--n=") ) shotN = Std.parseInt(a.substr(4));
			else if( StringTools.startsWith(a, "--slot=") ) shotSlot = Std.parseInt(a.substr(7));
			else if( StringTools.startsWith(a, "--at=") ) shotAt = a.substr(5).split(",").map(Std.parseFloat);
			else if( StringTools.startsWith(a, "--bgbiome=") ) shotBiome = a.substr(10);
			else if( StringTools.startsWith(a, "--lang=") ) Lang.setCode(a.substr(7));
		}
		Theme.init();
		Settings.load();
		if( shotPath != null ) {
			for( a in Sys.args() ) if( StringTools.startsWith(a, "--lang=") ) { Settings.lang = a.substr(7); Lang.setCode(Settings.lang); }
		}

		var win = hxd.Window.getInstance();
		win.title = "Galaxy 55 (offline)";
		applyVsync();
		win.onClose = function() {
			// en el mapa se guarda la partida en el espacio; durante el despegue el planeta aun esta cargado
			if( state == Playing || state == Paused || state == Exploring || (state == Loading && pendingExplorer > 0) ) saveGame(false);
			return true;
		};
		if( Settings.fullscreen && shotPath == null ) win.displayMode = Borderless;
		else win.resize(W, H);

		s2d.scaleMode = LetterBox(W, H);
		engine.backgroundColor = 0xFF05070D;

		var png = Res.bytes("texture.png");
		// atlas con los parches del original (colores planos BFColor, opacidades BFAlpha)
		atlas = Atlas.build(png);

		liquidVeil = new h2d.Bitmap(h2d.Tile.fromColor(0xFFFFFF, W, H), s2d);
		liquidVeil.visible = false;
		dim = new h2d.Bitmap(h2d.Tile.fromColor(0x000000, W, H, 0.0), s2d);
		snow = new Snow(s2d);
		ui = new h2d.Object(s2d);
		// brillo del jetpack (hud_jetpack.png del original) y barra de combustible
		var ht = hxd.res.Any.fromBytes("hud.png", Res.bytes("hud.png")).toTile();
		helmet = new h2d.Bitmap(ht, s2d);
		helmet.visible = false;
		var jt = hxd.res.Any.fromBytes("hud_jetpack.png", Res.bytes("hud_jetpack.png")).toTile();
		jetGlow = new h2d.Bitmap(jt, s2d);
		jetGlow.visible = false;
		jetBar = new h2d.Graphics(s2d);
		jetBar.x = Std.int(W * 0.5 - 175);
		jetBar.y = H - 25;
		jetBar.alpha = 0.9;
		jetBar.visible = false;
		// mismos colores, tamanos y brillo que el original (Interface: vida 350x5 a 20 px del borde, oxigeno 350x10 a 35)
		oxyBar = new h2d.Graphics(s2d);
		oxyBar.filter = new h2d.filter.Glow(0x2C66D3, 0.8, 4, 1);
		oxyBar.visible = false;
		lifeBar = new h2d.Graphics(s2d);
		lifeBar.filter = new h2d.filter.Glow(0xA6FF00, 0.8, 4, 1);
		lifeBar.alpha = 0.8;
		lifeBar.visible = false;
		// Interface.setStatus("power"): el rayo de icons.png (casilla 1,2) a x2, en modo suma y con brillo cian
		statusIcon = new h2d.Bitmap(hxd.res.Any.fromBytes("icons.png", Res.bytes("icons.png")).toTile().sub(16, 32, 16, 16), s2d);
		statusIcon.blendMode = Add;
		statusIcon.filter = new h2d.filter.Glow(0x04E9FB, 0.8, 8, 2, 1, true);
		statusIcon.visible = false;
		// mira cian que aparece al excavar (Interface.cross: lineas de 7 px, alfa 0.4)
		// fundido blanco del teletransporte (Hero.enteringShip -> fades)
		fadeRect = new h2d.Bitmap(h2d.Tile.fromColor(0xFFFFFF, W, H), s2d);
		fadeRect.alpha = 0;
		fadeRect.visible = false;
		hurtRect = new h2d.Bitmap(h2d.Tile.fromColor(0xFFFFFF, W, H), s2d);
		hurtRect.visible = false;
		for( b in [liquidVeil, dim, fadeRect, hurtRect] ) Theme.coverWindow(b);
		cross = new h2d.Graphics(s2d);
		cross.lineStyle(1, 0x00FFFF, 1);
		cross.moveTo(0, -7);
		cross.lineTo(0, 7);
		cross.moveTo(-7, 0);
		cross.lineTo(7, 0);
		cross.x = Std.int(W * 0.5);
		cross.y = Std.int(H * 0.5);
		cross.alpha = 0.4;
		cross.visible = false;
		// punto de mira fijo (anadido del port; el original solo mostraba la mira al excavar): 2x2 blanco con borde oscuro
		dot = new h2d.Graphics(s2d);
		dot.beginFill(0x000000, 0.6);
		dot.drawRect(-2, -2, 4, 4);
		dot.beginFill(0xFFFFFF, 0.9);
		dot.drawRect(-1, -1, 2, 2);
		dot.endFill();
		dot.x = Std.int(W * 0.5);
		dot.y = Std.int(H * 0.5);
		dot.visible = false;
		hxd.Window.getInstance().addEventTarget(onWindowEvent);
		hud = Theme.text(s2d, "", 1.8, 0xFFFFFF, 14, 74);
		hud.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 0.9 };
		hud.visible = false;
		msgText = Theme.text(s2d, "", 2.2, 0xFFFFFF, 0, 0);
		msgText.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 0.9 };
		msgText.textAlign = Center;
		msgText.visible = false;
		toast = Theme.text(s2d, "", 2.4, Theme.ACCENT, 0, 640);
		targetName = Theme.text(s2d, "", 1.0, 0xD8D8D8, 0, 0);
		targetName.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 1 };
		targetName.visible = false;
		toast.dropShadow = { dx : 2, dy : 2, color : 0, alpha : 0.9 };
		toast.visible = false;
		guide = new TutoGuide(s2d);
		tutorial.onDone = function() saveGame(false);

		if( demoSaves ) makeDemoSaves();

		// el planeta que gira de fondo del menu
		bgStart();
		showLoading(Lang.t("loading"));

		hxd.Pad.wait(function(p) pad = p);
	}

	// ---------------------------------------------------------------- utilidades de pantalla

	function clearUi() {
		ui.removeChildren();
		screens = new Map();
		current = null;
		currentName = "";
	}

	function gradientPanel( parent : h2d.Object, w : Int ) {
		var g = new h2d.Graphics(parent);
		// franjas sin solapar (una por cada 4 px) para que el degradado no muestre rayas
		var n = Std.int(w / 4);
		// de -H a 2H en vertical, como fullRect: cubre tambien una ventana mas alta que 16:9
		for( i in 0...n ) {
			var f = i / n;
			var a = 0.9 * (1 - f * f);
			Theme.rect(g, i * 4, -H, 4, H * 3, Theme.BG, a);
		}
		Theme.rect(g, 0, -H, 4, H * 3, Theme.ACCENT, 0.9);
	}

	function titleBlock( parent : h2d.Object, x : Float, y : Float, scale : Float ) {
		var shadow = Theme.text(parent, "GALAXY", scale, 0x000000, x + 4, y + 4);
		shadow.alpha = 0.5;
		Theme.text(parent, "GALAXY", scale, 0xFFFFFF, x, y);
		var t55 = Theme.text(parent, "55", scale, Theme.ACCENT, x + 6 * 8 * scale * 1.04 + 8, y);
		Theme.text(parent, Lang.t("subtitle"), scale * 0.2, Theme.DIM, x + 6, y + 13 * scale + 8);
	}

	function panelFor( w : Int, h : Int, title : String ) : Screen {
		var s = new Screen(ui);
		var bg = new h2d.Graphics(s);
		drawPanel(bg, Theme.text(s, title, 3.2, Theme.TEXT), w, h);
		return s;
	}

	/** fondo y titulo de un panel centrado de w x h (se vuelve a llamar si cambia su alto, como en Nueva partida) */
	function drawPanel( bg : h2d.Graphics, title : h2d.Text, w : Int, h : Int ) {
		var x = (W - w) * 0.5, y = (H - h) * 0.5;
		bg.clear();
		Theme.fullRect(bg, 0x000000, 0.35);
		Theme.rect(bg, x, y, w, h, Theme.PANEL, 0.94);
		Theme.rect(bg, x, y, w, 4, Theme.ACCENT);
		Theme.rect(bg, x, y + h - 1, w, 1, 0xFFFFFF, 0.1);
		title.x = (W - title.textWidth * title.scaleX) * 0.5;
		title.y = y + 28;
	}

	function show( name : String ) {
		if( current != null ) current.visible = false;
		var s = screens.get(name);
		if( s == null ) {
			s = switch( name ) {
				case "main": buildMain();
				case "new": buildNew();
				case "load": buildLoad();
				case "options": buildOptions();
				case "options.general", "options.controls", "options.graphics", "options.interface": buildOptionsSection(name.substr(8));
				case "firstlang": buildFirstLang();
				case "pause": buildPause();
				case "mappause": buildMapPause();
				case "computer": buildComputer();
				default: null;
			}
			screens.set(name, s);
		}
		current = s;
		currentName = name;
		s.visible = true;
		s.active = true;
		s.firstEnabled();
	}

	/** Reconstruye todos los menus (al cambiar de idioma). */
	function rebuildScreens( stay : String ) {
		var again = state == Menu || state == Paused || state == Exploring;
		clearUi();
		if( state == Exploring && explorer != null ) explorer.relabel();
		if( again ) show(stay);
	}


	// ---------------------------------------------------------------- pantallas

	function buildMain() : Screen {
		var s = new Screen(ui);
		mainScreen = s;
		gradientPanel(s, 900);
		titleBlock(s, 110, 80, 7.5);
		var saves = SaveData.list();
		var y = 300.;
		// Continuar abre la lista de partidas, con la mas reciente elegida
		var cont = new Button(s, Lang.t("continue"));
		cont.enabled = saves.length > 0;
		cont.onActivate = function() if( saves.length > 0 ) show("load");
		s.add(cont, 110, y);
		var nw = new Button(s, Lang.t("new"));
		nw.onActivate = function() show("new");
		s.add(nw, 110, y + 64);
		var op = new Button(s, Lang.t("options"));
		op.onActivate = function() show("options");
		s.add(op, 110, y + 128);
		var q = new Button(s, Lang.t("quit"));
		q.onActivate = function() quit();
		s.add(q, 110, y + 192);
		if( saves.length > 0 ) {
			var l = saves[0];
			Theme.text(s, Lang.t("lastgame") + ": " + l.name + "  ·  " + Lang.duration(l.playSeconds), 1.5, Theme.DIM, 112, y + 266);
		}
		versionText = Theme.text(s, "v0.5 · port nativo", 1.4, Theme.DISABLED, W - 190, 690);
		anchorToWindow();
		s.onBack = null;
		return s;
	}

	function randomSeed() : Int return 1 + Std.random(999999);

	/** nombre por defecto de una partida nueva: "Partida N" con N = partidas + 1, o el siguiente que no tenga ya otra partida */
	function defaultGameName() : String {
		var names = [for( i in SaveData.list() ) i.name];
		var n = names.length + 1;
		inline function name( n : Int ) return StringTools.replace(Lang.t("newgame.name"), "%n%", "" + n);
		while( names.indexOf(name(n)) >= 0 ) n++;
		return name(n);
	}

	/** Nueva partida: nombre, semilla y modo; en creativo tambien bioma y tamano, en aventura si se juega el tutorial.
	    Las filas del otro modo se ocultan y se desactivan (el foco las salta) y el panel cambia de alto. */
	function buildNew() : Screen {
		var s = new Screen(ui);
		var bg = new h2d.Graphics(s);
		var title = Theme.text(s, Lang.t("newgame.title"), 3.2, Theme.TEXT);
		var x = (W - 560) * 0.5;
		var defName = defaultGameName();
		nName = new TextField(s, Lang.t("name"), defName, 560, 54, 340);
		nSeed = new TextField(s, Lang.t("seed"), "" + randomSeed(), 560, 54, 340);
		nSeed.numeric = true;
		nSeed.maxLen = 9;
		nMode = new Selector(s, Lang.t("mode"), [Lang.t("mode.adventure"), Lang.t("mode.creative")]);
		var names = [Lang.t("biome.random")];
		for( b in BIOMES.concat(EXTRA_BIOMES) ) names.push(Lang.t("biome." + b));
		nBiome = new Selector(s, Lang.t("biome"), names);
		nSize = new Selector(s, Lang.t("size"), [Lang.t("size.small"), Lang.t("size.normal"), Lang.t("size.large")]);
		nSize.index = 0;
		nTutorial = new Selector(s, Lang.t("tutorial"), [Lang.t("yes"), Lang.t("no")]);
		var create = new Button(s, Lang.t("create"), 560);
		var back = new Button(s, Lang.t("back"), 560);
		var all : Array<Widget> = [nName, nSeed, nMode, nBiome, nSize, nTutorial, create, back];
		for( w in all ) s.add(w, x, 0);
		var layout = function() {
			var creative = nMode.index == 1;
			for( w in [nBiome, nSize] ) w.visible = w.enabled = creative;
			nTutorial.visible = nTutorial.enabled = !creative;
			var rows : Array<Widget> = creative ? [nName, nSeed, nMode, nBiome, nSize] : [nName, nSeed, nMode, nTutorial];
			var h = 290 + rows.length * 66;
			drawPanel(bg, title, 760, h);
			var y = (H - h) * 0.5 + 120;
			for( i in 0...rows.length ) rows[i].y = y + i * 66;
			create.y = y + rows.length * 66 + 16;
			back.y = create.y + 66;
		};
		nMode.onChange = function(_) layout();
		layout();
		create.onActivate = function() {
			var seed = Std.parseInt(nSeed.text);
			if( seed == null || seed <= 0 ) seed = randomSeed();
			var biome = nBiome.index == 0 ? BIOMES[seed % BIOMES.length] : BIOMES.concat(EXTRA_BIOMES)[nBiome.index - 1];
			var name = StringTools.trim(nName.text);
			if( name == "" ) name = defName;
			var creative = nMode.index == 1;
			startNewGame(name, seed, creative, !creative && nTutorial.index == 0, biome, nSize.index + 1);
		};
		back.onActivate = function() show("main");
		s.onBack = function() show("main");
		return s;
	}

	/**
	 * Empieza una partida nueva (formulario de Nueva partida). Creativo: en la nave, sobre el planeta del bioma y tamano elegidos.
	 * Aventura: en el espacio, en el sistema 0, con o sin el tutorial (TutoSetup.newGame: con el, su planeta es Terres Rouges
	 * pequeno). La eleccion del tutorial queda en la partida (SaveInfo.tutorial).
	 */
	public function startNewGame( name : String, seed : Int, creative : Bool, tutorial : Bool, biome : String, size : Int ) {
		if( !creative ) {
			startAdventure(name, seed, tutorial);
			return;
		}
		startGame(SaveData.create(name, seed, biome, size, true));
	}

	/** Partidas guardadas (Continuar): jugar, renombrar o borrar cada una */
	function buildLoad() : Screen {
		var s = new LoadScreen(ui);
		var bg = new h2d.Graphics(s);
		Theme.fullRect(bg, 0x000000, 0.4);
		Theme.rect(bg, 110, 50, 1060, 620, Theme.PANEL, 0.94);
		Theme.rect(bg, 110, 50, 1060, 4, Theme.ACCENT);
		var t = Theme.text(s, Lang.t("load.title"), 3.2, Theme.TEXT, 0, 72);
		t.x = (W - t.textWidth * t.scaleX) * 0.5;
		var saves = SaveData.list();
		for( info in saves ) {
			var row = new SaveRow(s, info);
			s.rows.push(row);
			s.add(row, s.listX, s.listY);
			var inf = info;
			row.onAction = function( a ) switch( SaveRow.ACTIONS[a] ) {
				case "rename": askRename(s, inf);
				case "delete": askDelete(s, inf);
				default: startGame(inf);
			};
		}
		s.layout();
		var back = new Button(s, Lang.t("back"), 300, 48);
		s.add(back, (W - 300) * 0.5, 604);
		back.onActivate = function() show("main");
		s.onBack = function() show("main");
		if( saves.length == 0 ) {
			var n = Theme.text(s, Lang.t("nosaves"), 2.2, Theme.DIM, 0, 320);
			n.x = (W - n.textWidth * n.scaleX) * 0.5;
		}
		return s;
	}

	/** vuelve a hacer la lista de partidas (tras renombrar o borrar) desplazada como estaba y con el foco en la fila `at` (o en la
	    ultima que quede) */
	function reopenLoad( at : Int ) {
		var old = screens.get("load");
		var top = old != null ? cast(old, LoadScreen).top : 0;
		screens.remove("load");
		screens.remove("main");
		if( old != null ) old.remove();
		if( SaveData.list().length == 0 ) {
			show("main");
			return;
		}
		show("load");
		var s = cast(current, LoadScreen);
		var max = s.rows.length - LoadScreen.VISIBLE;
		s.top = top < max ? top : max < 0 ? 0 : max;
		s.setFocus(at < s.rows.length ? at : s.rows.length - 1);
	}

	/** ventana para cambiar el nombre de una partida (solo el nombre: SaveData.rename); Intro en el campo acepta */
	function askRename( parent : LoadScreen, info : SaveInfo ) {
		if( modal != null && modal.parent != null ) return;
		parent.active = false;
		var m = new Screen(ui);
		var bg = new h2d.Graphics(m);
		Theme.fullRect(bg, 0x000000, 0.55);
		Theme.rect(bg, 290, 220, 700, 270, Theme.PANEL, 1);
		Theme.rect(bg, 290, 220, 700, 4, Theme.ACCENT);
		var t = Theme.text(m, Lang.t("rename.title"), 2.4, Theme.TEXT, 0, 248);
		t.x = (W - t.textWidth * t.scaleX) * 0.5;
		var field = new TextField(m, Lang.t("name"), info.name, 620, 54, 380);
		var cancel = new Button(m, Lang.t("cancel"), 250, 52);
		var ok = new Button(m, Lang.t("accept"), 250, 52);
		m.add(field, 330, 310);
		m.add(cancel, 380, 400);
		m.add(ok, 650, 400);
		var close = function() {
			m.remove();
			parent.active = true;
		};
		var accept = function() {
			var name = StringTools.trim(field.text);
			if( name == "" || name == info.name ) {
				close();
				return;
			}
			var at = parent.focus;
			SaveData.rename(info.id, name);
			m.remove();
			reopenLoad(at);
		};
		field.onEnter = accept;
		ok.onActivate = accept;
		cancel.onActivate = close;
		m.onBack = close;
		m.setFocus(0);
		field.startTyping();
		// el modal se actualiza desde update()
		modal = m;
	}

	/** ventana de confirmacion para borrar una partida */
	function askDelete( parent : LoadScreen, info : SaveInfo ) {
		if( modal != null && modal.parent != null ) return; // ya hay una ventana de confirmacion abierta
		parent.active = false;
		var m = new Screen(ui);
		var bg = new h2d.Graphics(m);
		Theme.fullRect(bg, 0x000000, 0.55);
		Theme.rect(bg, 390, 250, 500, 220, Theme.PANEL, 1);
		Theme.rect(bg, 390, 250, 500, 4, Theme.DANGER);
		var t = Theme.text(m, Lang.t("delete.ask"), 2.4, Theme.TEXT, 0, 280);
		t.x = (W - t.textWidth * t.scaleX) * 0.5;
		var n = Theme.text(m, info.name, 2.0, Theme.CYAN, 0, 325);
		n.x = (W - n.textWidth * n.scaleX) * 0.5;
		var no = new Button(m, Lang.t("no"), 210, 52);
		var yes = new Button(m, Lang.t("yes"), 210, 52);
		m.add(no, 410, 390);
		m.add(yes, 640 + 10, 390);
		m.setFocus(0);
		var close = function() {
			m.remove();
			parent.active = true;
		};
		no.onActivate = close;
		m.onBack = close;
		yes.onActivate = function() {
			var at = parent.focus;
			SaveData.delete(info.id);
			m.remove();
			reopenLoad(at);
		};
		// el modal se actualiza desde update()
		modal = m;
	}
	var modal : Screen;

	/** confirmacion para pasar el tutorial: avisa de que el inventario, la nave y el planeta vuelven a empezar */
	function askSkip( parent : Screen ) {
		if( modal != null && modal.parent != null ) return;
		parent.active = false;
		var m = new Screen(ui);
		var bg = new h2d.Graphics(m);
		Theme.fullRect(bg, 0x000000, 0.55);
		Theme.rect(bg, 340, 240, 600, 240, Theme.PANEL, 1);
		Theme.rect(bg, 340, 240, 600, 4, Theme.DANGER);
		var t = Theme.text(m, TutoText.get("skip.ask"), 2.4, Theme.TEXT, 0, 266);
		t.x = (W - t.textWidth * t.scaleX) * 0.5;
		var n = Theme.text(m, TutoText.get("skip.warn"), 1.8, Theme.DANGER, 360, 316);
		n.maxWidth = 560 / n.scaleX;
		n.textAlign = Center;
		var no = new Button(m, Lang.t("no"), 210, 52);
		var yes = new Button(m, Lang.t("yes"), 210, 52);
		m.add(no, 410, 400);
		m.add(yes, 640 + 10, 400);
		m.setFocus(0);
		var close = function() {
			m.remove();
			parent.active = true;
		};
		no.onActivate = close;
		m.onBack = close;
		yes.onActivate = function() {
			m.remove();
			skipTutorial();
		};
		modal = m;
	}

	/** pasar el tutorial: la partida vuelve al espacio como si hubiera empezado sin el (TutoSetup.skip) */
	public function skipTutorial() {
		var info = game != null ? game.toInfo() : spaceInfo;
		if( !Tutorial.active(info) ) return;
		TutoSetup.skip(info);
		if( explorer != null ) {
			explorer.dispose();
			explorer = null;
			dim.visible = true;
		}
		spaceInfo = null;
		space = null;
		takeoffSave = 0;
		if( game != null ) leaveGame();
		saveOnMap = true;
		mapToast = TutoText.get("skipped");
		startGame(info);
	}

	/** partida de aventura nueva: empieza en el espacio, con o sin tutorial (TutoSetup.newGame) */
	function startAdventure( name : String, seed : Int, tutorial : Bool ) {
		saveOnMap = true;
		startGame(TutoSetup.newGame(name, seed, tutorial));
	}

	/** pruebas: partida de aventura nueva desde un guion (deja la que haya) */
	public function devNewGame( tutorial : Bool, seed : Int ) {
		if( explorer != null ) {
			explorer.dispose();
			explorer = null;
			dim.visible = true;
		}
		spaceInfo = null;
		space = null;
		takeoffSave = 0;
		if( game != null ) leaveGame();
		startAdventure("Prueba", seed, tutorial);
	}

	/** primera vez: elegir el idioma (cada boton en su propio idioma) */
	function buildFirstLang() : Screen {
		var s = panelFor(640, 420, "Language / Idioma / Langue");
		var x = (W - 540) * 0.5;
		var y = 230.;
		for( i in 0...Lang.CODES.length ) {
			var b = new Button(s, Lang.LABELS[i]);
			s.add(b, x, y + i * 62);
			b.onActivate = function() {
				Settings.lang = Lang.CODES[i];
				Lang.setCode(Settings.lang);
				Settings.firstRun = false;
				Settings.save();
				clearUi();
				show("main");
			};
		}
		s.setFocus(Lang.cur);
		return s;
	}

	static var OPTION_SECTIONS = ["general", "controls", "graphics", "interface"];

	/** Opciones: una lista de secciones (todo junto ya no cabia en 720 de alto) */
	function buildOptions() : Screen {
		var n = OPTION_SECTIONS.length;
		var s = panelFor(640, 160 + (n + 1) * 64, Lang.t("options.title"));
		var x = (W - 460) * 0.5;
		var y = (H - (160 + (n + 1) * 64)) * 0.5 + 110;
		for( i in 0...n ) {
			var sec = OPTION_SECTIONS[i];
			var b = new Button(s, Lang.t("options." + sec));
			b.onActivate = function() show("options." + sec);
			s.add(b, x, y + i * 64);
		}
		var back = new Button(s, Lang.t("back"));
		s.add(back, x, y + n * 64 + 10);
		var leave = function() {
			Settings.save();
			show(state == Paused ? "pause" : state == Exploring ? "mappause" : "main");
		};
		back.onActivate = leave;
		s.onBack = leave;
		return s;
	}

	/** Una seccion de Opciones: sus filas y Volver (a la lista de secciones) */
	function buildOptionsSection( sec : String ) : Screen {
		var rows : Array<Ui.Widget> = [];
		var onOff = [Lang.t("off"), Lang.t("on")];
		var count = switch( sec ) { case "general": 2; case "graphics": 5; default: 3; };
		var h = 170 + (count + 1) * 60;
		var s = panelFor(860, h, Lang.t("options." + sec).toUpperCase());
		var x = (W - 660) * 0.5;
		var y = (H - h) * 0.5 + 105;
		inline function sel( key : String, v : Bool, set : Bool -> Void ) {
			var w = new Selector(s, Lang.t(key), onOff, 660);
			w.index = v ? 1 : 0;
			w.onChange = function(i) set(i == 1);
			rows.push(w);
		}
		switch( sec ) {
		case "general":
			var lang = new Selector(s, Lang.t("language"), Lang.LABELS, 660);
			lang.index = Lang.cur;
			lang.onChange = function(i) {
				Settings.lang = Lang.CODES[i];
				Lang.setCode(Settings.lang);
				Settings.save();
				rebuildScreens("options.general");
			};
			rows.push(lang);
			var vol = new Slider(s, Lang.t("volume"), 0, 100, 5, 660);
			vol.value = Settings.volume;
			vol.onChange = function(v) Settings.volume = Std.int(v);
			rows.push(vol);
		case "controls":
			var sens = new Slider(s, Lang.t("sens"), 0.2, 3.0, 0.1, 660);
			sens.decimals = 1;
			sens.value = Settings.mouseSens;
			sens.onChange = function(v) Settings.mouseSens = v;
			rows.push(sens);
			sel("invert", Settings.invertY, v -> Settings.invertY = v);
			var tk = new Selector(s, Lang.t("turnkeys"), [Lang.t("turnkeys.strafe"), Lang.t("turnkeys.turn")], 660);
			tk.index = Settings.turnKeys ? 1 : 0;
			tk.onChange = function(i) Settings.turnKeys = i == 1;
			rows.push(tk);
		case "graphics":
			sel("fullscreen", Settings.fullscreen, function(v) {
				Settings.fullscreen = v;
				hxd.Window.getInstance().displayMode = v ? Borderless : Windowed;
			});
			sel("vsync", Settings.vsync, function(v) {
				Settings.vsync = v;
				applyVsync();
			});
			var fpsNames = [for( v in Settings.FPS_STEPS ) v == 0 ? Lang.t("maxfps.none") : "" + v];
			var mf = new Selector(s, Lang.t("maxfps"), fpsNames, 660);
			mf.index = Std.int(Math.max(0, Settings.FPS_STEPS.indexOf(Settings.maxFps)));
			mf.onChange = function(i) Settings.maxFps = Settings.FPS_STEPS[i];
			rows.push(mf);
			var fov = new Slider(s, Lang.t("fov"), 60, 110, 5, 660);
			fov.value = Settings.fov;
			fov.onChange = function(v) Settings.fov = Std.int(v);
			rows.push(fov);
			sel("waterwaves", Settings.waterWaves, v -> Settings.waterWaves = v);
		default:
			sel("helptext", Settings.showHelp, v -> Settings.showHelp = v);
			sel("placepreview", Settings.placePreview, v -> Settings.placePreview = v);
			sel("targetname", Settings.targetName, v -> Settings.targetName = v);
		}
		for( i in 0...rows.length ) s.add(rows[i], x, y + i * 60);
		var back = new Button(s, Lang.t("back"), 660);
		s.add(back, x, y + rows.length * 60 + 14);
		var leave = function() {
			Settings.save();
			show("options");
		};
		back.onActivate = leave;
		s.onBack = leave;
		return s;
	}

	/** Ordenador de a bordo (Game.openComputerMenu): despegar, modificar la nave, comerciar. Por ahora solo se puede cerrar. */
	function buildComputer() : Screen {
		// visitar la nave nodriza solo se ofrece al editarla (editar_nodriza.bat); jugando se llega acoplandose al robot en el mapa
		var mother = GameView.editMother;
		var h = mother ? 622 : 560;
		var s = panelFor(640, h, Lang.t("computer.title"));
		var x = (W - 540) * 0.5;
		var y = (H - h) * 0.5 + 135;
		var takeoff = new Button(s, Lang.t("computer.takeoff"));
		var edit = new Button(s, Lang.t("computer.edit"));
		var trade = new Button(s, Lang.t("computer.trade"));
		var contracts = new Button(s, Lang.t("computer.contracts"));
		var close = new Button(s, Lang.t("computer.close"));
		s.add(takeoff, x, y);
		s.add(edit, x, y + 62);
		s.add(trade, x, y + 124);
		s.add(contracts, x, y + 186);
		if( mother ) {
			var visit = new Button(s, Lang.t("computer.mothership"));
			s.add(visit, x, y + 248);
			visit.onActivate = startMothership;
		}
		s.add(close, x, y + (mother ? 324 : 262));
		var soon = function() {
			resume();
			showToast(Lang.t("computer.soon"));
		};
		// tutorial: la nave esta averiada y no despega hasta tapar los agujeros
		takeoff.onActivate = function() {
			if( !Tutorial.active(game.info) ) {
				startExplorer();
				return;
			}
			resume();
			showToast(TutoText.get("notakeoff"));
		};
		if( Tutorial.active(game.info) ) {
			var skip = new Button(s, TutoText.get("skip"));
			s.add(skip, x, close.y + 62);
			skip.onActivate = function() askSkip(s);
		}
		edit.onActivate = startHangar;
		trade.onActivate = openShop;
		contracts.onActivate = openContracts;
		close.onActivate = function() resume();
		s.onBack = function() resume();
		return s;
	}

	// ---------------------------------------------------------------- explorador (mapa de estrellas)

	public var explorer : Explorer;
	var pendingExplorer = 0;
	/** la partida mientras estas en el espacio: el planeta no esta cargado (en el original el mapa era otra pagina) */
	var spaceInfo : SaveInfo;
	/** reglas del viaje espacial (base para lo que se anada al espacio) */
	var space : Space;
	/** imagenes de la nave para el mapa: se hacen con la nave cargada (al despegar) y sirven hasta el siguiente despegue */
	var shipFrames : Array<flash.display.BitmapData>;

	public function startExplorer() {
		if( game != null && (game.hangar != null || game.info.mothership == true) ) return;
		current = null;
		ui.removeChildren();
		screens = new Map();
		state = Loading;
		hud.visible = false; msgText.visible = false;
		showLoading(Lang.t("explore.loading"));
		pendingExplorer = 2; // se deja pintar la pantalla de carga antes de generar el mapa
	}

	/** el universo de la partida (se crea con la primera apertura del mapa si la partida es antigua) */
	function universe() : SaveData.UniInfo {
		var info = game != null ? game.info : spaceInfo;
		if( info.uni == null )
			info.uni = { seed : info.seed, planetId : 0, pos : [2, 0], start : { seed : info.seed, biome : info.biome, size : info.sizeChunks }, planets : [] };
		return info.uni;
	}

	// ---------------------------------------------------------------- hangar (EditShip)

	var hangarReturn : SaveInfo;
	var hangarOrig : String;

	function leaveGame() {
		closePalette();
		closeShop();
		closeContracts();
		closeChest();
		game.dispose();
		if( invBar != null ) {
			invBar.remove();
			invBar = null;
		}
		game.world.dispose();
		game = null;
		ui.removeChildren();
		screens = new Map();
	}

	/** nave nodriza: la nave del robot comerciante (al acoplarse desde el mapa; o --script con "mothership") */
	public function startMothership() {
		if( game == null || game.hangar != null ) return;
		var cur = game.toInfo();
		hangarReturn = cur;
		var h : SaveInfo = Reflect.copy(cur);
		h.inv = Inv.copy(cur.inv);
		h.market = Market.copy(cur.market);
		h.mothership = true;
		leaveGame();
		startGame(h);
	}

	public function startHangar() {
		if( game == null || game.hangar != null ) return;
		var cur = game.toInfo();
		hangarReturn = cur;
		var h : SaveInfo = Reflect.copy(cur);
		h.inv = Inv.copy(cur.inv);
		h.hangar = true;
		leaveGame();
		startGame(h);
	}

	/** EditShip.returnToShip: con cambios validos se guarda la nave (y el inventario); si no son validos, se pregunta */
	function exitHangar() {
		var b64 = haxe.crypto.Base64.encode(game.hangarShip());
		if( b64 == hangarOrig ) {
			backFromHangar();
			return;
		}
		if( game.hangarValid ) {
			hangarReturn.shipData = b64;
			hangarReturn.inv = Inv.copy(game.inv.inv);
			hangarReturn.shipEdits = [];
			hangarReturn.px = hangarReturn.py = hangarReturn.pz = -1;
			Tutorial.repaired(hangarReturn);
			backFromHangar();
			return;
		}
		state = Paused;
		captureMouse(false);
		hud.visible = false;
		msgText.visible = false;
		var m = new Screen(ui);
		var bg = new h2d.Graphics(m);
		Theme.fullRect(bg, 0x000000, 0.55);
		Theme.rect(bg, 290, 250, 700, 220, Theme.PANEL, 1);
		Theme.rect(bg, 290, 250, 700, 4, Theme.DANGER);
		var t = Theme.text(m, Lang.t("hangar.exit_ship_no_save"), 1.9, Theme.TEXT, 0, 290);
		t.x = (W - t.textWidth * t.scaleX) * 0.5;
		var no = new Button(m, Lang.t("no"), 210, 52);
		var yes = new Button(m, Lang.t("yes"), 210, 52);
		m.add(no, 410, 390);
		m.add(yes, 650, 390);
		m.setFocus(0);
		var stay = function() {
			m.remove();
			resume();
		};
		no.onActivate = stay;
		m.onBack = stay;
		yes.onActivate = function() {
			m.remove();
			backFromHangar();
		};
	}

	/** vuelta de la nave nodriza: lo comprado y vendido al robot (inventario, creditos, mercado) se lleva a la partida */
	function backFromMothership() {
		// modo de edicion: lo cambiado se guarda en mothership.bin y el inventario de la partida no se toca
		if( GameView.editMother && game != null ) {
			var ok = try Mothership.save(game.world) catch( e : Dynamic ) { Sys.stderr().writeString("nodriza: " + e + "\n"); false; }
			Sys.println(ok ? "Nave nodriza guardada" : "No se pudo guardar la nave nodriza");
			backFromHangar();
			return;
		}
		syncMothership();
		if( hangarReturn != null && hangarReturn.uni != null && hangarReturn.uni.space == true && shipFrames != null ) {
			var info = returnInfo();
			hangarReturn = null;
			leaveGame();
			toSpace(info);
			return;
		}
		backFromHangar();
	}

	/** lo comprado y vendido al robot pasa a la partida a la que se vuelve (al salir de la nodriza y al guardar dentro) */
	function syncMothership() {
		if( hangarReturn == null || game == null ) return;
		var m = game.toInfo();
		hangarReturn.inv = Inv.copy(game.inv.inv);
		hangarReturn.credits = m.credits;
		hangarReturn.market = Market.copy(m.market);
	}

	/** la partida a la que se vuelve del hangar o de la nodriza (o que se guarda estando dentro): el tiempo jugado dentro tambien cuenta */
	function returnInfo() : SaveInfo {
		if( hangarReturn != null ) hangarReturn.playSeconds = game.playSeconds;
		return hangarReturn;
	}

	function backFromHangar() {
		var info = returnInfo();
		hangarReturn = null;
		Tutorial.leftHangar(info);
		leaveGame();
		info.hangar = null;
		startGame(info);
	}

	function buildExplorer() {
		ui.removeChildren();
		bar = null;
		// despegue: los cambios del planeta quedan en la partida, que pasa al espacio, y el planeta se descarga
		var takeoff = game != null;
		if( takeoff ) {
			universe();
			var info = game.toInfo();
			shipFrames = game.ship.captureFrames(engine, s3d);
			leaveGame();
			info.uni.space = true;
			info.uni.ship = null;
			spaceInfo = info;
		}
		var uni = universe();
		var visited = [uni.planetId];
		for( p in uni.planets ) visited.push(p.id);
		Explorer.shipBytes = Hangar.currentShip(spaceInfo);
		var infos = ExpData.ExpOffline.make(uni.seed, uni.start, visited, uni.pos);
		Explorer.robotStart = uni.robot;
		explorer = new Explorer(s2d, infos, shipFrames);
		s2d.under(explorer);
		space = new Space(uni);
		space.tutorial = Tutorial.active(spaceInfo);
		space.onRefuse = showToast;
		explorer.onTravel = space.travel;
		explorer.canLand = space.canLand;
		explorer.canLeave = space.canLeave;
		explorer.tutoTarget = space.tutorial ? TutoSetup.PLANET : -1;
		explorer.onUnlock = space.unlock;
		explorer.onPause = openMapPause;
		explorer.onLand = landOnPlanet;
		explorer.onPos = function( pos ) {
			universe().pos = pos;
			space.moved(pos);
		};
		explorer.onDock = dockRobot;
		state = Exploring;
		dim.visible = false;
		captureMouse(false);
		if( takeoff ) {
			space.takeoff();
			// se guarda en cuanto el mapa se ha dibujado (para la miniatura); si antes se cierra la ventana, se guarda igual
			takeoffSave = 1.0;
		}
		if( saveOnMap ) {
			saveOnMap = false;
			takeoffSave = 1.0;
		}
		if( mapToast != null ) {
			showToast(mapToast);
			mapToast = null;
		}
	}
	var takeoffSave = 0.;

	/** la partida en curso: la del planeta cargado o, en el espacio, la del mapa */
	public function curInfo() : SaveInfo return game != null ? game.info : spaceInfo;

	/** pruebas: aterrizar en el planeta del que despegaste */
	public function devLandHome() {
		if( explorer == null ) return;
		var id = universe().planetId;
		for( s in explorer.infos.systems )
			for( p in s.planets )
				if( p.id == id ) {
					landOnPlanet(p, s);
					return;
				}
	}

	/** pruebas: como Menu principal y Continuar con esta partida */
	public function devReload() {
		var id = curInfo().id;
		toMainMenu();
		startGame(SaveData.read(id));
	}

	/** abre el mapa con la partida en el espacio (al cargarla o al salir de la nave nodriza), con la nave donde estaba */
	function toSpace( info : SaveInfo ) {
		spaceInfo = info;
		Explorer.shipStart = info.uni.ship;
		startExplorer();
	}

	/** la posicion de la nave y del robot en el mapa pasan a la partida (para guardarla) */
	function storeMapPos() {
		if( explorer == null ) return;
		var uni = universe();
		var rp = explorer.robotPos();
		if( rp != null ) uni.robot = rp;
		uni.ship = explorer.shipPos();
	}

	/** aterrizar en un planeta del mapa: se guardan los cambios del planeta actual y se carga el elegido (o se crea si es nuevo) */
	function landOnPlanet( p : ExpData.ExpPlanet, s : ExpData.ExpSystem ) {
		var old = spaceInfo;
		storeMapPos();
		space.land(p);
		space = null;
		takeoffSave = 0;
		var uni = universe();
		uni.pos = [2, p.id];
		uni.space = null;
		uni.ship = null;
		// los cambios del planeta del que despegaste se guardan con su id
		uni.planets = uni.planets.filter(function(q) return q.id != uni.planetId);
		uni.planets.push({ id : uni.planetId, edits : old.edits });
		var target : SaveData.UniPlanet = null;
		for( q in uni.planets ) if( q.id == p.id ) target = q;
		uni.planets = uni.planets.filter(function(q) return q.id != p.id);
		uni.planetId = p.id;
		explorer.dispose();
		explorer = null;
		spaceInfo = null;
		dim.visible = true;
		ui.removeChildren();
		screens = new Map();
		// misma partida: el inventario, la nave y el universo son de toda la partida; el terreno es el del planeta elegido
		old.seed = p.seed;
		old.biome = p.biome;
		old.sizeChunks = p.size;
		old.edits = target != null ? target.edits : [];
		old.px = old.py = old.pz = -1;
		old.yaw = old.pitch = 0;
		startGame(old);
	}

	/** acoplarse al robot comerciante desde el mapa: se entra en su nave (la nodriza, con la tienda y tu nave aparcada).
	    Al salir se vuelve al mapa, donde te acoplaste; si guardas dentro, la partida sigue en el espacio */
	function dockRobot() {
		storeMapPos();
		space.dock();
		space = null;
		takeoffSave = 0;
		var info = spaceInfo;
		explorer.dispose();
		explorer = null;
		spaceInfo = null;
		dim.visible = true;
		hangarReturn = info;
		var h : SaveInfo = Reflect.copy(info);
		h.inv = Inv.copy(info.inv);
		h.market = Market.copy(info.market);
		h.mothership = true;
		startGame(h);
	}

	function openComputer() {
		if( state != Playing ) return;
		game.stopSounds();
		// en la nave nodriza: el ordenador del puesto del robot abre la tienda; el de tu nave aparcada te devuelve a ella
		if( game != null && game.info.mothership == true ) {
			if( game.isRobotComputer() ) openShop() else backFromMothership();
			return;
		}
		state = Paused;
		captureMouse(false);
		hud.visible = false; msgText.visible = false;
		show("computer");
	}

	/** Esc en el mapa de estrellas: el mapa se para y se abre este menu */
	function openMapPause() {
		if( explorer == null ) return;
		explorer.paused = true;
		pausedThisFrame = true; // el mismo Esc no lo cierra
		show("mappause");
	}

	function closeMapPause() {
		current = null;
		ui.removeChildren();
		screens = new Map();
		if( explorer != null ) explorer.paused = false;
	}

	/** para volver al planeta se aterriza en el; Menu principal guarda la partida en el espacio */
	function buildMapPause() : Screen {
		var tuto = Tutorial.active(spaceInfo);
		var h = tuto ? 370 : 308;
		var s = panelFor(560, h, Lang.t("pause.title"));
		var x = (W - 460) * 0.5;
		var y = (H - h) * 0.5 + 92;
		var res = new Button(s, Lang.t("resume"));
		var op = new Button(s, Lang.t("options"));
		var mm = new Button(s, Lang.t("mainmenu"));
		s.add(res, x, y);
		s.add(op, x, y + 62);
		s.add(mm, x, y + 124);
		if( tuto ) {
			var skip = new Button(s, TutoText.get("skip"));
			s.add(skip, x, y + 186);
			skip.onActivate = function() askSkip(s);
		}
		res.onActivate = closeMapPause;
		op.onActivate = function() show("options");
		mm.onActivate = toMainMenu;
		s.onBack = closeMapPause;
		return s;
	}

	function buildPause() : Screen {
		var s = panelFor(560, 520, Lang.t("pause.title"));
		var x = (W - 460) * 0.5;
		var y = 215.;
		var res = new Button(s, Lang.t("resume"));
		var sv = new Button(s, Lang.t("save"));
		var op = new Button(s, Lang.t("options"));
		var mm = new Button(s, Lang.t("mainmenu"));
		var q = new Button(s, Lang.t("quit"));
		s.add(res, x, y);
		s.add(sv, x, y + 62);
		s.add(op, x, y + 124);
		s.add(mm, x, y + 186);
		s.add(q, x, y + 248);
		// tutorial: se puede pasar desde el planeta (en el hangar y en la nodriza no)
		if( game != null && game.hangar == null && game.info.mothership != true && Tutorial.active(game.info) ) {
			var skip = new Button(s, TutoText.get("skip"));
			s.add(skip, x, y + 310);
			skip.onActivate = function() askSkip(s);
		}
		res.onActivate = function() resume();
		sv.onActivate = function() saveGame(true);
		op.onActivate = function() show("options");
		mm.onActivate = function() toMainMenu();
		q.onActivate = function() {
			saveGame(false);
			quit();
		};
		s.onBack = function() resume();
		return s;
	}

	// ---------------------------------------------------------------- carga con progreso

	function showLoading( msg : String ) {
		ui.removeChildren();
		screens = new Map();
		current = null;
		var s = new Screen(ui);
		var bg = new h2d.Graphics(s);
		Theme.fullRect(bg, Theme.BG, 0.82);
		titleBlock(s, 110, 80, 7.5);
		barText = Theme.text(s, msg, 2.2, Theme.TEXT, 110, 520);
		bar = new h2d.Graphics(s);
		overlayDecor = s;
		anchorToWindow();
		setProgress(0);
	}

	function setProgress( p : Float ) {
		if( bar == null ) return;
		bar.clear();
		Theme.rect(bar, 110, 566, 700, 10, 0xFFFFFF, 0.12);
		Theme.rect(bar, 110, 566, 700 * p, 10, Theme.ACCENT);
	}

	/**
	 * Carga de un planeta como en el original (Game.hx: fx.Load sobre la pantalla en negro, sin texto): una barra naranja
	 * de 300x4 centrada, con brillo (GlowFilter 8, 8), y un trozo de 40 px que la recorre sin parar (no dice cuanto falta).
	 */
	function showPlanetLoading() {
		ui.removeChildren();
		screens = new Map();
		current = null;
		var s = new Screen(ui);
		var bg = new h2d.Graphics(s);
		Theme.fullRect(bg, 0x000000, 1);
		loadAnim = new h2d.Graphics(s);
		// brillo suave como el de Flash (el de Heaps sin smoothColor rellena todo el borde del mismo color)
		loadAnim.filter = new h2d.filter.Glow(LOAD_COLOR, 1, 4, 1, 1, true);
		loadAnim.x = Std.int((W - 300) * 0.5);
		loadAnim.y = Std.int((H - 4) * 0.5);
		loadAnimPos = 0;
		bar = null;
		barText = null;
		overlayDecor = null;
		drawLoadAnim();
	}

	/** fx.Load.set_progress: fondo a 0.25 con borde de 1 px a 0.7, y el trozo de 40 px en progress * 260 */
	function drawLoadAnim() {
		var g = loadAnim;
		g.clear();
		g.beginFill(LOAD_COLOR, 0.25);
		g.lineStyle(1, LOAD_COLOR, 0.7);
		g.drawRect(0, 0, 300, 4);
		g.endFill();
		g.lineStyle();
		g.beginFill(LOAD_COLOR, 1);
		g.drawRect(loadAnimPos * 260, 0, 40, 4);
		g.endFill();
	}

	// ---------------------------------------------------------------- flujo del juego

	function startGame( info : SaveInfo ) {
		state = Loading;
		clearUi();
		hud.visible = false; msgText.visible = false;
		loadInfo = info;
		loadWorld = info.mothership == true
			? new World(info.seed, "BIMoon", (Mothership.data() != null ? Mothership.sizeChunks : 1), s3d, atlas, false, null, Mothership.withShip(Hangar.currentShip(info)))
			: info.hangar == true
			? new World(info.seed, "BIShed", 1, s3d, atlas, false, null, TutoSetup.holed(info, Hangar.shedData(Hangar.currentShip(info))))
			: new World(info.seed, info.biome, info.sizeChunks, s3d, atlas, false, info.edits);
		if( info.mothership == true ) {
			loadWorld.sky.fog.curve = 0.00001;
			loadWorld.lightTop = Mothership.Z0 + Mothership.LZ + 4;
			// la Hades se diseño con la luz de Minecraft (las lamparas pierden 1 por bloque) y alli nunca se ve negro del todo
			// las luces del techo de los hangares estan a ~14 del suelo: con 0.7 por bloque la luz llega al suelo y a las naves
			loadWorld.lampFalloff = 0.7;
			loadWorld.minLight = 4;
			loadWorld.sky.makeSpace();
		}
		if( info.hangar == true ) {
			loadWorld.sky.fog.curve = 0.00001; // EditShip: planet.curve = 0.00001
			loadWorld.lightTop = Hangar.SZ; // y planet.lightHeight: el sol entra bajo el techo
		}
		loadWorld.root.visible = false;
		showPlanetLoading();
	}

	function finishLoading() {
		bgDisposeAll();
		loadWorld.root.visible = true;
		if( shotPath != null ) {
			Sys.println("mundo " + loadWorld.biomeName + ": " + loadWorld.faces + " caras, spawn z=" + loadWorld.spawnPoint().z);
			Sys.println(loadWorld.debugStats());
		}
		game = new GameView(s3d, loadWorld, loadInfo, atlas);
		loadWorld = null;
		if( loadInfo.uni != null && loadInfo.uni.space == true && loadInfo.hangar != true && loadInfo.mothership != true ) {
			// partida en el espacio: el planeta solo se carga para hacer las imagenes de la nave; luego se abre el mapa
			shipFrames = game.ship.captureFrames(engine, s3d);
			leaveGame();
			toSpace(loadInfo);
			return;
		}
		invBar = new InvBar(s2d, game.inv, atlas, W);
		game.onComputer = openComputer;
		game.onChest = openChest;
		game.onChestBreak = function(t) if( chest != null && chest.box == t ) closeChest();
		if( game.info.mothership == true ) game.onHangarExit = backFromMothership;
		if( game.hangar != null ) {
			game.onHangarExit = exitHangar;
			game.hangarRule = Tutorial.hangarRule(game.info);
			hangarOrig = haxe.crypto.Base64.encode(game.hangarShip());
		}
		ui.removeChildren();
		bar = null;
		loadAnim = null;
		state = Playing;
		hud.visible = true;
		autosaveTimer = 0;
		captureMouse(true);
		if( loadInfo.px < 0 && loadInfo.hangar != true && loadInfo.mothership != true ) {
			// partida nueva: se crea el archivo enseguida para que aparezca en la lista
			saveGame(false);
		}
	}

	function resume() {
		current = null;
		ui.removeChildren();
		screens = new Map();
		dim.tile = h2d.Tile.fromColor(0x000000, W, H, 0.0);
		game.releaseAction();
		state = Playing;
		hud.visible = true;
		captureMouse(true);
	}

	var pausedThisFrame = false;

	function pause() {
		if( game != null ) game.stopSounds();
		state = Paused;
		captureMouse(false);
		hud.visible = false; msgText.visible = false;
		show("pause");
	}

	function toMainMenu() {
		saveGame(false);
		if( explorer != null ) {
			explorer.dispose();
			explorer = null;
			dim.visible = true;
		}
		spaceInfo = null;
		space = null;
		takeoffSave = 0;
		if( game != null ) leaveGame();
		ui.removeChildren();
		screens = new Map();
		bgStart();
		hud.visible = false; msgText.visible = false;
		state = Menu;
		show("main");
	}

	function quit() {
		hxd.System.exit();
	}

	function captureMouse( on : Bool ) {
		captured = on;
		if( game != null ) game.mouseLook = on;
		hxd.Window.getInstance().mouseMode = on ? Relative(onMouse, true) : Absolute;
	}

	/** rueda del raton: cambia de casilla (en el original, bajar la rueda pasa a la siguiente); con la paleta abierta, de pagina;
	    en la lista de partidas la desplaza */
	function onWindowEvent( e : hxd.Event ) {
		if( e.kind != EWheel ) return;
		if( state == Menu && current != null && current.active && Std.isOfType(current, LoadScreen) ) {
			cast(current, LoadScreen).scroll(e.wheelDelta > 0 ? 1 : -1);
			return;
		}
		if( game == null || state != Playing ) return;
		if( shop != null ) shop.scroll(e.wheelDelta);
		else if( paletteOpen && palette != null ) palette.scroll(e.wheelDelta);
		else game.scrollInventory(e.wheelDelta > 0 ? -1 : 1);
	}

	function openPalette() {
		if( paletteOpen || game == null || !game.creative ) return;
		palette = new Palette(s2d, atlas);
		palette.onPick = function(b) game.setSlot(b);
		palette.onClose = closePalette;
		paletteOpen = true;
		captureMouse(false);
	}

	public var shop : Shop;
	public var chest : Chest;

	/** cantina abierta: se esta mirando con el raton (arrastrar fuera de la ventana) */
	var chestDrag = false;

	/** Cantina de ESCorp (cofre). No es modal (ent/Chest.hx): el juego sigue y se cierra al alejarse (update).
	    El original tenia siempre el cursor libre (se miraba arrastrando): aqui se suelta el raton mientras esta abierta */
	public function openChest( box : Protocol.BlockInventory ) {
		if( game == null || chest != null || shop != null ) return;
		chest = new Chest(s2d, atlas, game.inv, box, { x : game.px, y : game.py, z : game.pz });
		chest.onClose = closeChest;
		game.actionKeys = false;
		captureMouse(false);
	}

	function closeChest() {
		if( chest == null ) return;
		chest.remove();
		chest = null;
		chestDrag = false;
		if( game == null ) return;
		game.actionKeys = true;
		if( state == Playing ) {
			captureMouse(true);
			game.releaseAction();
		}
	}

	/** Game.click/drag del original: con la cantina abierta, pulsar fuera de la ventana y arrastrar mueve la vista.
	    Mientras se arrastra se captura el raton; al soltar, el cursor vuelve a donde estaba */
	function updateChestDrag() {
		var K = hxd.Key;
		if( !chestDrag && K.isPressed(K.MOUSE_LEFT) && !chest.isOver(s2d.mouseX, s2d.mouseY) ) {
			chestDrag = true;
			captureMouse(true);
		} else if( chestDrag && !K.isDown(K.MOUSE_LEFT) ) {
			chestDrag = false;
			captureMouse(false);
		}
	}

	/** tienda del robot comerciante (por ahora desde el ordenador de a bordo; luego estara en la nave nodriza) */
	public function openShop() {
		if( game == null || shop != null ) return;
		if( current != null ) resume();
		var m = game.market;
		shop = new Shop(s2d, atlas, m, game.inv, game.info.credits);
		shop.onCredits = function(c) game.info.credits = c;
		shop.onClose = closeShop;
		paletteOpen = true;
		captureMouse(false);
	}

	function closeShop() {
		if( shop == null ) return;
		shop.remove();
		shop = null;
		paletteOpen = false;
		if( game != null && state == Playing ) {
			captureMouse(true);
			game.releaseAction();
		}
	}

	/** contratos de la ESCorp (ContractPanel, anadido del port), desde el ordenador de a bordo */
	public var contracts : ContractPanel;

	public function openContracts() {
		if( game == null || contracts != null ) return;
		if( current != null ) resume();
		contracts = new ContractPanel(s2d, atlas, game.info, game.inv);
		contracts.onClose = closeContracts;
		paletteOpen = true;
		captureMouse(false);
	}

	public function closeContracts() {
		if( contracts == null ) return;
		contracts.remove();
		contracts = null;
		paletteOpen = false;
		if( game != null && state == Playing ) {
			captureMouse(true);
			game.releaseAction();
		}
	}

	function closePalette() {
		if( palette != null ) {
			palette.remove();
			palette = null;
		}
		paletteOpen = false;
		if( game != null && state == Playing ) {
			captureMouse(true);
			game.releaseAction();
		}
	}

	function onMouse( e : hxd.Event ) {
		if( game != null && state == Playing ) game.look(e.relX, e.relY);
	}

	// ---------------------------------------------------------------- guardado

	function captureThumb() : haxe.io.Bytes {
		try {
			var w = engine.width, h = engine.height;
			var tex = new h3d.mat.Texture(w, h, [Target]);
			tex.depthBuffer = new h3d.mat.Texture(w, h, [Target], Depth24Stencil8);
			engine.pushTarget(tex);
			if( game != null ) {
				game.updateCamera();
				engine.clear(0xFF6FA8DC, 1, 0);
				s3d.render(engine);
			} else {
				// en el espacio: el mapa de estrellas, sin los menus
				engine.clear(0xFF000000, 1, 0);
				var hidden = [for( o in s2d ) if( o != explorer && o.visible ) o];
				for( o in hidden ) o.visible = false;
				s2d.render(engine);
				for( o in hidden ) o.visible = true;
			}
			engine.popTarget();
			var px = tex.capturePixels();
			var tw = 320, th = 180;
			var out = hxd.Pixels.alloc(tw, th, px.format);
			for( y in 0...th )
				for( x in 0...tw )
					out.setPixel(x, y, px.getPixel(Std.int(x * w / tw), Std.int(y * h / th)));
			var bytes = out.toPNG();
			tex.depthBuffer.dispose();
			tex.dispose();
			return bytes;
		} catch( e : Dynamic ) {
			return null;
		}
	}

	function saveGame( notify : Bool ) {
		if( game == null ) {
			// en el espacio: la partida con la nave y el robot donde estan en el mapa
			if( spaceInfo == null || explorer == null ) return;
			storeMapPos();
			var ok = SaveData.write(spaceInfo, captureThumb());
			if( notify ) showToast(ok ? Lang.t("saved.ok") : "ERROR");
			return;
		}
		// en el hangar se guarda la partida tal como estaba al entrar (con el tiempo jugado); en la nodriza, con lo comprado y vendido
		if( game.info.mothership == true && !GameView.editMother ) syncMothership();
		var ok = SaveData.write(game.hangar != null || game.info.mothership == true ? returnInfo() : game.toInfo(), captureThumb());
		// modo de edicion: guardar (Esc, guardar y salir) tambien escribe la nave nodriza
		if( GameView.editMother && game.info.mothership == true )
			ok = (try Mothership.save(game.world) catch( e : Dynamic ) false) && ok;
		if( notify ) showToast(ok ? Lang.t("saved.ok") : "ERROR");
	}

	/** Captura de pantalla (F2): Interface.takeScreen y Render.takeScreenShot del original. Solo la escena, al tamano de la ventana:
	    sin casco, HUD, menus, caja de seleccion ni bloque en la mano; los velos de color (fades del original) y la nieve (del port) si salen.
	    Se dibuja aparte y se vuelve a mostrar todo antes del fotograma: en pantalla no cambia nada.
	    Cambio del port: el original abria el dialogo de Flash para guardar el PNG; aqui va a la carpeta screenshots de los datos
	    del juego, con el nombre del original (G55-fecha.png) */
	function takeScreen() {
		var w = engine.width, h = engine.height;
		var tex = new h3d.mat.Texture(w, h, [Target]);
		tex.depthBuffer = new h3d.mat.Texture(w, h, [Target], Depth24Stencil8);
		var scene : Array<h2d.Object> = [liquidVeil, @:privateAccess snow.batch, fadeRect, hurtRect];
		var hidden2d = [for( o in s2d ) if( o.visible && scene.indexOf(o) < 0 ) o];
		var hidden3d = [for( o in game.screenShotHidden() ) if( o.visible ) o];
		for( o in hidden2d ) o.visible = false;
		for( o in hidden3d ) o.visible = false;
		engine.pushTarget(tex);
		engine.clear(engine.backgroundColor, 1, 0);
		s3d.render(engine);
		s2d.render(engine);
		engine.popTarget();
		for( o in hidden2d ) o.visible = true;
		for( o in hidden3d ) o.visible = true;
		try {
			var px = tex.capturePixels();
			// opaca, como la del original (forceAlpha)
			px.convert(BGRA);
			for( i in 0...w * h ) px.bytes.set(px.offset + i * 4 + 3, 0xFF);
			var data = Settings.dir();
			var dir = data + "/screenshots";
			if( !sys.FileSystem.exists(dir) ) sys.FileSystem.createDirectory(dir);
			var base = "G55-" + Date.now().toString().split(":").join("_");
			var name = base + ".png", n = 1;
			// dos capturas en el mismo segundo: la segunda no pisa la primera (anadido del port)
			while( sys.FileSystem.exists(dir + "/" + name) ) name = base + " (" + (++n) + ").png";
			// compresion rapida (nivel 1): la de por defecto tarda el doble y el juego se para ese rato
			sys.io.File.saveBytes(dir + "/" + name, px.toPNG(1));
			if( shotPath != null ) Sys.println("captura F2: " + name + " " + w + "x" + h);
			// aviso de donde ha ido (anadido del port)
			var sep = Sys.systemName() == "Windows" ? "\\" : "/";
			showToast(Lang.t("shot.saved").split("%dir%").join(haxe.io.Path.withoutDirectory(data) + sep + "screenshots"));
		} catch( e : Dynamic ) {
			showToast("ERROR");
		}
		tex.depthBuffer.dispose();
		tex.dispose();
	}

	/** Quitar o poner el casco (tecla H), con las mismas animaciones que Game.update del original. */
	function toggleHelmet() {
		if( helmetSeq.length > 0 ) return;
		if( helmetOn ) {
			helmetOn = false;
			helmetSeq = [{ wait : false, to : -210, dur : 0.1, easeIn : false }, { wait : true, to : 0, dur : 0.3, easeIn : false }, { wait : false, to : -1024, dur : 0.7, easeIn : true }];
			helmetOnDone = function() helmet.visible = false;
		} else {
			helmet.visible = true;
			helmetSeq = [{ wait : false, to : -250, dur : 0.5, easeIn : true }, { wait : true, to : 0, dur : 0.1, easeIn : false }, { wait : false, to : -190, dur : 0.8, easeIn : true }];
			helmetOnDone = function() helmetOn = true;
		}
		helmetT = 0;
		helmetFrom = helmetY;
	}

	function updateHelmet( dt : Float, p : GameView ) {
		if( helmetSeq.length > 0 ) {
			var s = helmetSeq[0];
			helmetT += dt;
			if( s.wait ) {
				if( helmetT >= s.dur ) {
					helmetSeq.shift();
					helmetT = 0;
					helmetFrom = helmetY;
				}
			} else {
				var f = Math.min(1, helmetT / s.dur);
				var e = s.easeIn ? f * f : 1 - (1 - f) * (1 - f);
				helmetY = helmetFrom + (s.to - helmetFrom) * e;
				if( f >= 1 ) {
					helmetSeq.shift();
					helmetT = 0;
					helmetFrom = helmetY;
				}
			}
			if( helmetSeq.length == 0 && helmetOnDone != null ) {
				var f = helmetOnDone;
				helmetOnDone = null;
				f();
			}
		}
		// casco puesto: sigue el vaiven de la camara
		if( helmetOn && helmetSeq.length == 0 ) {
			helmetX = -20 + p.bobX;
			helmetY = -190 + Math.cos(p.walkBobbing) * 2 + p.bobY;
		}
	}

	/** El menu principal y la pantalla de carga se disenaron pegados al borde izquierdo de la zona W x H: en una ventana mas ancha
	    que 16:9, LetterBox los dejaba separados del borde (con el fondo 3D a la vista a su izquierda). Se mueven al borde real de la
	    ventana, y el texto de version al borde derecho. */
	function anchorToWindow() {
		var left = Theme.visibleArea().x;
		for( o in [mainScreen, overlayDecor] ) if( o != null ) o.x = left;
		if( versionText != null ) versionText.x = W - 190 - 2 * left;
	}

	/** Coloca el casco y el brillo del jetpack cubriendo toda la ventana (escala del original: ancho/974, alto/624). */
	function layoutHelmet() {
		var a = Theme.visibleArea();
		var scale = engine.width / a.w;
		var visW = a.w, visH = a.h;
		var offX = a.x, offY = a.y;
		var sx = visW / 974, sy = visH / 624;
		for( b in [helmet, jetGlow] ) {
			b.scaleX = sx;
			b.scaleY = sy;
			b.x = offX + helmetX * sx;
			b.y = offY + helmetY * sy;
		}
		jetBar.setScale(1 / scale);
		jetBar.x = offX + (visW - 350 / scale) * 0.5;
		jetBar.y = offY + visH - 25 / scale + hudShake;
		for( b in [lifeBar, oxyBar] ) {
			b.setScale(1 / scale);
			b.x = jetBar.x;
		}
		lifeBar.y = offY + visH - 20 / scale + hudShake;
		oxyBar.y = offY + visH - 35 / scale + hudShake;
	}

	/** Barra de combustible y brillo del jetpack, como Interface.updateJetpack y el HUD del original. */
	function updateJetHud( p : GameView ) {
		var ratio = 1 - p.jetpack;
		if( ratio <= 0 ) {
			jetBar.visible = false;
		} else {
			if( ratio > 1 ) ratio = 1;
			jetBar.visible = true;
			jetBar.clear();
			jetBar.beginFill(0x000000, 0.3);
			jetBar.drawRect(0, 0, 350, 4);
			var col = ratio >= 0.8 ? 0xFD5C17 : (ratio >= 0.6 ? 0xFFA428 : 0xFFD900);
			jetBar.beginFill(col, 1);
			jetBar.drawRect(0, 0, ratio * 350, 4);
			jetBar.endFill();
		}
		drawBar(oxyBar, p.oxygen / 100, 10, 0x4AA5FF);
		drawBar(lifeBar, p.life / 100, 5, 0xA3F50A);
		// el brillo solo se ve con el casco puesto (Hero.hx: if game.hudOn)
		jetGlow.visible = p.thrusting && helmetOn;
		if( jetGlow.visible ) jetGlow.alpha = 0.3 + Math.random() * 0.7;
	}

	/**
	 * Icono "power" con un turbo minero cerca (Hero.set_miningPower -> Interface.setStatus). Como Game.updateInterface:
	 * parpadea (|sin(t * 5)|) y va abajo a la izquierda del casco (statusMC.x = helmet.x + 100, y = helmet.y + 650 - alto, en
	 * pixeles de la imagen del casco). Con el casco quitado o poniendose se queda donde va el casco en reposo.
	 */
	function updateStatus( dt : Float, p : GameView ) {
		statusTime += dt;
		statusIcon.visible = p.miningPower > 1;
		if( !statusIcon.visible ) return;
		statusIcon.alpha = Math.abs(Math.sin(statusTime * 5));
		var a = Theme.visibleArea();
		var scale = engine.width / a.w;
		var hx = helmetOn ? helmetX : -20., hy = helmetOn ? helmetY : -190.;
		// x2 en pixeles de pantalla, como las barras
		statusIcon.setScale(2 / scale);
		statusIcon.x = a.x + (hx + 100) * a.w / 974;
		statusIcon.y = a.y + (hy + 650) * a.h / 624 - 32 / scale + hudShake; // tiembla con el HUD (Interface.ui)
	}

	/** Interface.updateLife / updateOxygen: fondo negro y la parte llena; oculta si esta llena */
	static function drawBar( g : h2d.Graphics, ratio : Float, h : Int, col : Int ) {
		g.visible = ratio < 1;
		if( !g.visible ) return;
		if( ratio < 0 ) ratio = 0;
		g.clear();
		g.beginFill(0x000000, 0.3);
		g.drawRect(0, 0, 350, h);
		g.beginFill(col, 1);
		g.drawRect(0, 0, ratio * 350, h);
		g.endFill();
	}

	/** tutorial: objetivo, flecha y aura jugando y en el mapa (no en pausa, en los menus ni con la tienda o la paleta abiertas) */
	function updateTutorial( dt : Float ) {
		var playing = state == Playing && game != null && !paletteOpen;
		var onMap = state == Exploring && explorer != null && !explorer.paused && current == null;
		var info = playing ? game.info : onMap ? spaceInfo : null;
		var g = playing ? game : null;
		// bajo la barra del inventario (con el nombre del bloque elegido debajo, InvBar.showName: unos 70 px, fijo para que el
		// recuadro no se mueva cuando ese nombre aparece y se va) y, si se ve, bajo la ayuda de las teclas
		var top = invBar != null && invBar.visible ? 72. : 0.;
		if( hud.visible && hud.text != "" ) top = Math.max(top, hud.y + hud.textHeight * hud.scaleY + 8);
		guide.update(dt, info == null ? null : tutorial.text(info, g), g, tutorial.targets(g), s3d.camera, top);
	}

	function showToast( msg : String ) {
		toast.text = msg;
		toast.x = (W - toast.textWidth * toast.scaleX) * 0.5;
		toast.visible = true;
		toast.alpha = 1;
		toastTime = 2.2;
	}

	/** partidas de ejemplo para las capturas (--demo-saves: las 3 primeras) y para probar la lista (devsaves N); de la cuarta en
	    adelante, una de cada cuatro es creativa */
	function makeDemoSaves( n = 3 ) {
		var names = ["Base Alfa", "Cráter del Norte", "Mundo helado", "Colonia Beta", "Dunas rojas", "Bosque de ácido", "Mina lunar", "Ciudad perdida", "Puesto Gamma", "Valle oculto"];
		var biomes = ["BIAutumn", "BIMoon", "BIWinterPeaks", "BIMars", "BIMars", "BIAcidForest", "BIMoon", "BIDeadCity", "BIAutumn", "BIWinterPeaks"];
		for( i in 0...n ) {
			var k = i % names.length;
			var info = SaveData.create(names[k] + (i < names.length ? "" : " " + (1 + Std.int(i / names.length))), 1000 + i * 77, biomes[k], 1 + (i % 2), i % 4 == 3);
			info.playSeconds = 900 + i * 4100;
			info.saved = Date.now().getTime() - i * 86400000.0 * 1.3;
			SaveData.write(info, null, false);
		}
	}

	/** pruebas (devsaves N): borra las partidas de la carpeta de datos y crea N de ejemplo. Solo con GALAXY55_DATA (devrun.ps1),
	    para no tocar nunca las partidas de verdad */
	public function devSaves( n : Int ) {
		var data = Sys.getEnv("GALAXY55_DATA");
		if( data == null || data == "" ) {
			Sys.println("devsaves: solo con GALAXY55_DATA (devrun.ps1)");
			return;
		}
		var d = SaveData.dir();
		for( f in sys.FileSystem.readDirectory(d) )
			if( StringTools.endsWith(f, ".json") || StringTools.endsWith(f, ".png") ) sys.FileSystem.deleteFile(d + "/" + f);
		makeDemoSaves(n);
		Sys.println("devsaves: " + n + " partidas de ejemplo en " + d);
	}

	/** pruebas (print saves): las partidas en el orden de la lista, con su modo, tutorial, inventario y miniatura */
	public function devSavesInfo() : String {
		var out = [];
		for( i in SaveData.list() ) {
			var blocks = 0, charges = 0;
			for( s in i.inv.t ) if( s != null ) blocks += s.n;
			for( c in i.inv.charges ) charges += c.n;
			out.push("'" + i.name + "' " + (i.creative == true ? "creativo" : "aventura") + " tutorial=" + i.tutorial + " " + i.biome + "/" + i.sizeChunks
				+ " bloques=" + blocks + " cargas=" + charges + " miniatura=" + (SaveData.thumb(i.id) != null ? "si" : "no") + " guardado=" + DateTools.format(Date.fromTime(i.saved), "%d/%m %H:%M:%S"));
		}
		return out.length + " partidas:\n  " + out.join("\n  ");
	}

	/** pruebas (print menu): la pantalla abierta (o la ventana encima), el control con el foco y, en la lista de partidas o en Nueva
	    partida, lo que se ve */
	public function devMenuInfo() : String {
		var s = modal != null && modal.parent != null ? modal : current;
		if( s == null ) return curInfo() != null ? "jugando '" + curInfo().name + "'" : "ninguna";
		function desc( w : Widget ) : String {
			if( Std.isOfType(w, SaveRow) ) {
				var r = cast(w, SaveRow);
				return "fila '" + r.info.name + "' (" + SaveRow.ACTIONS[r.action] + ")";
			}
			if( Std.isOfType(w, Selector) ) {
				var c = cast(w, Selector);
				return c.title + " = " + c.choices[c.index];
			}
			if( Std.isOfType(w, TextField) ) {
				var t = cast(w, TextField);
				return t.title + " = '" + t.text + "'" + (t.typing ? " (escribiendo)" : "");
			}
			return "'" + @:privateAccess w.label.text + "'";
		}
		var out = "pantalla " + currentName + (s == modal ? " + ventana" : "") + ", foco " + desc(s.widgets[s.focus]);
		if( s == current && Std.isOfType(s, LoadScreen) ) {
			var l = cast(s, LoadScreen);
			out += "; filas " + l.rows.length + ", a la vista " + [for( r in l.rows ) if( r.visible ) r.info.name].join(" | ");
		} else if( s == current && currentName == "new" ) {
			out += "; filas " + [for( w in s.widgets ) if( w.visible ) desc(w)].join(" | ") + "; panel " + Std.int(s.widgets[0].y - 120) + ".." + Std.int(s.widgets[s.widgets.length - 1].y + 88);
		}
		return out;
	}

	// ---------------------------------------------------------------- bucle principal

	static var frameTime = Sys.args().indexOf("--frametime") >= 0;
	var lastStamp = 0.;

	/** VSync de Opciones (--novsync lo quita siempre, para diagnosticar) */
	function applyVsync() {
		hxd.Window.getInstance().vsync = Settings.vsync && Sys.args().indexOf("--novsync") < 0;
	}

	/** Limite de FPS de Opciones: espera lo que falte hasta el siguiente fotograma */
	var nextFrame = 0.;
	function limitFps() {
		if( Settings.maxFps <= 0 ) {
			nextFrame = 0;
			return;
		}
		var now = haxe.Timer.stamp(), step = 1 / Settings.maxFps;
		if( nextFrame > now ) {
			Sys.sleep(nextFrame - now);
			now = nextFrame;
		}
		// si va retrasado (fotograma lento) no se intenta recuperar
		nextFrame = (nextFrame <= 0 || now - nextFrame > step) ? now + step : nextFrame + step;
	}

	override function update( dt : Float ) {
		limitFps();
		frames++;
		// diagnostico (--frametime): fotogramas de mas de 250 ms y en que estado estaba el juego
		if( frameTime ) {
			var now = haxe.Timer.stamp();
			if( lastStamp > 0 && now - lastStamp > 0.25 ) Sys.println("parada " + Std.int((now - lastStamp) * 1000) + " ms en el fotograma " + frames + ", estado " + state + (bgBuilding != null ? ", construyendo fondo" : ""));
			lastStamp = now;
		}
		if( dt > 0.1 ) dt = 0.1;
		if( state != Playing ) {
			jetBar.visible = false;
			lifeBar.visible = false;
			oxyBar.visible = false;
			jetGlow.visible = false;
			statusIcon.visible = false;
		}
		// el casco se ve jugando y en pausa; en los menus no
		if( game == null || (state != Playing && state != Paused) ) {
			helmet.visible = false;
			helmetOn = true;
			helmetSeq = [];
			helmetX = -20;
			helmetY = -190;
		}
		anchorToWindow();

		// planeta de fondo del menu
		if( state == Boot ) {
			bgUpdate(dt);
			var p = bgBuilding != null ? bgBuilding.progress : (bgWorlds.length > 0 ? 1.0 : 0.0);
			setProgress(p);
			if( bgWorlds.length > 0 ) {
				state = Menu;
				ui.removeChildren();
				bar = null;
				if( Settings.firstRun && shotPath == null ) show("firstlang") else
				show(shotScreen == "load" || shotScreen == "new" || StringTools.startsWith(shotScreen, "options") ? shotScreen : "main");
			}
		}
		if( state == Menu || state == Loading ) {
			if( state == Menu ) bgUpdate(dt);
			bgCamera(dt);
		}

		if( state == Loading && loadWorld != null ) {
			loadWorld.step(14);
			// Game.update: el trozo avanza 0.1 en cada imagen y vuelve al principio
			loadAnimPos += 0.1;
			if( loadAnimPos > 1 ) loadAnimPos--;
			drawLoadAnim();
			if( dev != null ) dev.loadingFrame(this);
			if( loadWorld.isReady() ) finishLoading();
		}

		if( state == Playing && game != null ) {
			var K = hxd.Key;
			if( paletteOpen ) {
				game.stopSounds();
				if( shop != null ) {
					shop.update(dt, pad);
				} else if( contracts != null ) {
					contracts.update(dt, pad);
				} else if( palette != null ) {
					palette.update(dt, pad);
				} else if( K.isPressed(K.ESCAPE) || K.isPressed(K.I) ) closePalette();
				game.updateCamera();
			} else if( chest == null && game.creative && (K.isPressed(K.I) || (pad != null && pad.isPressed(pad.config.ranalogClick))) ) {
				openPalette();
			} else if( chest == null && (K.isPressed(K.ESCAPE) || (pad != null && pad.isPressed(pad.config.start))) ) { pause(); pausedThisFrame = true; }
			else {
				// con la cantina abierta el juego sigue (Esc o B la cierran, sin pausar)
				if( chest != null ) {
					updateChestDrag();
					chest.update(dt, pad);
				}
				game.update(dt, true, pad);
				// salir de la nodriza o del hangar (ordenador, teletransporte) cambia de mundo dentro de update
				if( game == null || state != Playing ) return;
				tutorial.update(dt, game);
				// Process.update del original: la cantina se cierra si el jugador se ha alejado
				if( chest != null && chest.far(game) ) closeChest();
				game.updateCamera();
				if( K.isPressed(K.F5) ) saveGame(true);
				autosaveTimer += dt;
				if( autosaveTimer > 120 ) {
					autosaveTimer = 0;
					saveGame(true);
				}
				var p = game;
				// temblor del HUD (Interface.updateShake): sube o baja al azar hasta 10 px de la ventana * shake;
				// en pausa y en los menus no se recalcula y se queda quieto
				hudShake = p.shake <= 0 ? 0 : Math.random() * 10 * p.shake * (Std.random(2) * 2 - 1) * Theme.visibleArea().w / engine.width;
				// F (Game.checkKeys) muestra u oculta solo la linea de coordenadas y fps; la ayuda en pantalla (anadido del port) va con su opcion
				if( chest == null && K.isPressed(K.F) ) showFps = !showFps; // con la cantina abierta no (actionKeys = false)
				var lines = [];
				if( showFps ) lines.push(Std.int(p.px) + ", " + Std.int(p.py) + ", " + Std.int(p.pz) + "   " + Std.int(engine.fps) + " fps");
				// con la cantina abierta, la ayuda de las teclas del juego no (casi todas estan desactivadas; la ventana tiene la suya)
				if( Settings.showHelp && chest == null ) lines.push(Lang.t("hud.help") + (p.creative ? "\n" + Lang.t("hud.creative") : ""));
				hud.text = lines.join("\n");
				msgText.visible = game.message != null;
				if( game.message != null ) {
					msgText.text = game.message;
					msgText.textColor = game.messageRed ? 0xFF1C1C : 0xFFFFFF;
					msgText.maxWidth = 600 / msgText.scaleX;
					msgText.setPosition(s2d.width * 0.5 - 300, s2d.height * 0.72 + hudShake);
				}
				if( chest == null && (K.isPressed(K.H) || (pad != null && pad.isPressed(pad.config.back))) ) toggleHelmet();
				if( !helmet.visible && helmetOn ) helmet.visible = true;
				updateHelmet(dt, p);
				layoutHelmet();
				updateJetHud(p);
				updateStatus(dt, p);
					if( invBar != null ) invBar.update(dt);
				if( invBar != null ) invBar.y = hudShake;
				cross.y = dot.y = Std.int(H * 0.5) + hudShake;
			}
		} else if( state == Paused && game != null ) {
			game.updateCamera();
		}

		if( pendingExplorer > 0 && --pendingExplorer == 0 ) buildExplorer();
		if( state == Exploring && explorer != null ) {
			if( !explorer.paused && current == null && pad != null && pad.isPressed(pad.config.start) ) explorer.escape();
			explorer.update(dt);
			if( takeoffSave > 0 && (takeoffSave -= dt) <= 0 ) saveGame(false);
		}
		if( invBar != null ) invBar.visible = state == Playing || state == Paused;
		cross.visible = state == Playing && game != null && game.laserActive;
		dot.visible = state == Playing && game != null && !paletteOpen && (chest == null || chestDrag) && !cross.visible;
		var fade = (state == Playing || state == Paused) && game != null ? Math.min(0.999, game.enteringShip) : 0.;
		fadeRect.visible = fade > 0;
		fadeRect.alpha = fade;
		var hurt = (state == Playing || state == Paused) && game != null ? game.fadeAlpha() : 0.;
		hurtRect.visible = hurt > 0;
		if( hurtRect.visible ) {
			hurtRect.alpha = Math.min(1, hurt);
			hurtRect.color.setColor(0xFF000000 | game.fadeFX.col);
		}

		if( modal != null && modal.parent != null ) modal.update(dt, pad);
		else {
			modal = null;
			if( current != null && state != Loading && state != Boot && !pausedThisFrame ) current.update(dt, pad);
			pausedThisFrame = false;
		}

		if( toastTime > 0 ) {
			toastTime -= dt;
			if( toastTime < 0.6 ) toast.alpha = Math.max(0, toastTime / 0.6);
			if( toastTime <= 0 ) toast.visible = false;
		}
		updateTutorial(dt);

		// nombre del bloque apuntado
		var tn = "";
		if( Settings.targetName && state == Playing && game != null && game.select != null && game.inv.getCurrentBlock() == null ) {
			var n = game.select.b.getName();
			if( n != null && n != "-" && n.charAt(0) != "#" ) tn = n;
		}
		targetName.visible = tn != "";
		if( tn != "" && targetName.text != tn ) {
			targetName.text = tn;
			// pequeno, abajo a la derecha (que no tape el centro de la pantalla)
			targetName.x = Std.int(W - 96 - targetName.textWidth);
			targetName.y = H - 72;
		}

		// nieve (solo bioma de invierno): copos fijos en el mundo
		var snowWorld : World = null;
		if( (state == Playing || state == Paused) && game != null )
			snowWorld = game.world;
		else if( (state == Menu || state == Loading) && bgIndex < bgWorlds.length )
			snowWorld = bgWorlds[bgIndex];
		snow.visible = snowWorld != null && snowWorld.biomeName == "BIWinterPeaks" && dim.alpha < 0.5;
		// dentro de la nave no nieva (la nave flota sobre el planeta)
		if( snow.visible && (state == Playing || state == Paused) && game != null && game.pz >= World.SHIP_Z - 1 ) snow.visible = false;
		// dentro de un liquido: velo de su color y sin nieve (reporte de Sekhmet: nevaba bajo el agua)
		var lf = (state == Playing || state == Paused) && game != null ? game.liquidFade : null;
		liquidVeil.visible = lf != null;
		if( lf != null ) {
			liquidVeil.color.setColor(0xFF000000 | lf.col);
			liquidVeil.alpha = lf.a;
			snow.visible = false;
		}
		if( snow.visible ) {
			var ww = engine.width, wh = engine.height;
			var scale = Math.min(ww / W, wh / H);
			var visW = ww / scale, visH = wh / scale;
			snow.update(dt, s3d.camera, snowWorld, (W - visW) * 0.5, (H - visH) * 0.5, visW, visH);
		}

		// F2 (Interface.hx del original): en el planeta, la nave, el hangar y la nodriza, tambien con un menu abierto; no en el mapa
		if( game != null && (state == Playing || state == Paused) && hxd.Key.isPressed(hxd.Key.F2) ) takeScreen();

		testShot();
	}

	// ---------------------------------------------------------------- fondo del menu

	/** Empieza a construir, uno por uno, los planetas que se ven de fondo (cada uno de un bioma distinto). */
	function bgStart() {
		bgDisposeAll();
		bgQueue = BIOMES.copy();
		for( i in 0...bgQueue.length ) {
			var j = Std.random(bgQueue.length);
			var t = bgQueue[i];
			bgQueue[i] = bgQueue[j];
			bgQueue[j] = t;
		}
		if( shotBiome != null ) bgQueue = [shotBiome];
		bgIndex = 0;
		bgTimer = 0;
		bgFade = 0;
		bgCamZ = -1;
		dim.alpha = 0;
	}

	function bgDisposeAll() {
		for( w in bgWorlds ) w.dispose();
		bgWorlds = [];
		if( bgBuilding != null ) bgBuilding.dispose();
		bgBuilding = null;
		bgQueue = [];
		dim.alpha = 0;
	}

	function bgShow( i : Int ) {
		bgIndex = i;
		if( shotPath != null ) Sys.println("fondo del menu: " + bgWorlds[i].biomeName + " (" + bgWorlds.length + " planetas listos)");
		for( k in 0...bgWorlds.length ) bgWorlds[k].root.visible = (k == i);
		bgCamZ = -1;
		bgPhase = Math.random() * 6.28;
		bgComputeAlt(bgWorlds[i]);
	}

	/**
		Altura de la camara a lo largo de la ruta circular, calculada de una vez: maximo del relieve
		(copas incluidas) en una ventana que anticipa los obstaculos, y luego suavizada. Asi la camara
		va siempre por encima de todo, sin subir y bajar al pasar sobre cada arbol.
	**/
	function bgComputeAlt( w : World ) {
		// se prueban varias rutas y se elige la mas baja y llana (menos montanas por encima)
		var s = w.size;
		var cands = [[0.5, 0.5, 0.2], [0.5, 0.5, 0.3], [0.5, 0.5, 0.4], [0.4, 0.4, 0.2], [0.6, 0.4, 0.2], [0.4, 0.6, 0.2], [0.6, 0.6, 0.2], [0.4, 0.4, 0.3], [0.6, 0.4, 0.3], [0.4, 0.6, 0.3], [0.6, 0.6, 0.3]];
		var best : Array<Float> = null;
		var bestScore = 1e18;
		for( c in cands ) {
			var tab = bgPathAlt(w, s * c[0], s * c[1], s * c[2]);
			var total = 0., mx = 0.;
			for( i in 0...tab.length ) {
				total += Math.abs(tab[(i + 1) % tab.length] - tab[i]);
				if( tab[i] > mx ) mx = tab[i];
			}
			var score = 0.5 * mx + 2.5 * total;
			if( score < bestScore ) {
				bestScore = score;
				best = tab;
				bgCx = s * c[0];
				bgCy = s * c[1];
				bgR = s * c[2];
			}
		}
		bgAlt = best;
		if( shotPath != null ) {
			var lo = 1e9, hi = -1e9, maxStep = 0.;
			for( i in 0...bgAlt.length ) {
				if( bgAlt[i] < lo ) lo = bgAlt[i];
				if( bgAlt[i] > hi ) hi = bgAlt[i];
				var d = Math.abs(bgAlt[(i + 1) % bgAlt.length] - bgAlt[i]);
				if( d > maxStep ) maxStep = d;
			}
			var spacing = 2 * Math.PI * bgR / bgAlt.length;
			Sys.println("ruta de camara " + w.biomeName + ": radio " + Std.int(bgR) + ", altura " + Std.int(lo) + "-" + Std.int(hi) + ", pendiente maxima " + (Math.round(maxStep / spacing * 100) / 100));
		}
	}

	/** Tabla de alturas (180 muestras) para una ruta circular. */
	function bgPathAlt( w : World, cx : Float, cy : Float, r : Float ) : Array<Float> {
		var M = 180;
		var raw = new Array<Float>();
		for( i in 0...M ) {
			var a = i / M * Math.PI * 2;
			var x = Std.int(cx + Math.cos(a) * r), y = Std.int(cy + Math.sin(a) * r);
			var top = 0;
			for( dx in -3...4 )
				for( dy in -3...4 ) {
					var hh = w.topCollide(x + dx * 2, y + dy * 2);
					if( hh > top ) top = hh;
				}
			raw.push(top);
		}
		var cur = new Array<Float>();
		for( i in 0...M ) {
			var m = 0.;
			for( k in -24...25 ) {
				var v = raw[(i + k + M * 2) % M];
				if( v > m ) m = v;
			}
			cur.push(m);
		}
		for( pass in 0...3 ) {
			var next = new Array<Float>();
			for( i in 0...M ) {
				var sum = 0.;
				for( k in -12...13 ) sum += cur[(i + k + M * 2) % M];
				next.push(sum / 25);
			}
			cur = next;
		}
		return [for( v in cur ) v + 9];
	}

	function bgUpdate( dt : Float ) {
		// un solo planeta de fondo, pequeno (1 trozo): generar planetas grandes y cambiarlos cada 22 s daba tirones de hasta un
		// segundo en el menu (ERRORES #13). Cada vez que se vuelve al menu sale otro bioma
		if( bgBuilding == null && bgWorlds.length < 1 && bgQueue.length > 0 ) {
			var b = bgQueue.shift();
			bgBuilding = new World(Std.random(100000), b, 1, s3d, atlas, true);
			bgBuilding.root.visible = false;
		}
		if( bgBuilding != null ) {
			bgBuilding.step(state == Boot ? 14 : 6);
			if( bgBuilding.isReady() ) {
				bgWorlds.push(bgBuilding);
				bgBuilding = null;
				if( bgWorlds.length == 1 ) bgShow(0);
			}
		}
		if( bgWorlds.length < 2 ) return;

		// cambio de planeta con fundido a negro
		if( bgFade == 0 ) {
			bgTimer += dt;
			if( bgTimer > 22 ) {
				bgFade = 1;
				bgFadeT = 0;
			}
		} else {
			bgFadeT += dt / 0.8;
			if( bgFade == 1 ) {
				dim.alpha = Math.min(1, bgFadeT);
				if( bgFadeT >= 1 ) {
					bgShow((bgIndex + 1) % bgWorlds.length);
					bgFade = 2;
					bgFadeT = 0;
				}
			} else {
				dim.alpha = Math.max(0, 1 - bgFadeT);
				if( bgFadeT >= 1 ) {
					bgFade = 0;
					bgTimer = 0;
					dim.alpha = 0;
				}
			}
		}
	}

	/** Recorrido lento a baja altura por el terreno, mirando al horizonte, como se ve en el juego. */
	function bgCamera( dt : Float ) {
		if( bgIndex >= bgWorlds.length ) return;
		var w = bgWorlds[bgIndex];
		if( !w.isReady() ) return;
		if( bgAlt.length == 0 ) return;
		// velocidad lenta y constante (unos 2.5 bloques por segundo)
		bgPhase += dt * 0.065;
		var s = w.size;
		var x = bgCx + Math.cos(bgPhase) * bgR, y = bgCy + Math.sin(bgPhase) * bgR;
		// altura interpolada de la tabla precalculada
		var f = bgPhase / (Math.PI * 2);
		f -= Math.floor(f);
		var fi = f * bgAlt.length;
		var i0 = Std.int(fi) % bgAlt.length, i1 = (i0 + 1) % bgAlt.length;
		var t = fi - Std.int(fi);
		bgCamZ = bgAlt[i0] * (1 - t) + bgAlt[i1] * t;
		var yaw = bgPhase + Math.PI * 0.5 + 0.5;
		var pitch = -0.65; // el planeta es redondo: hay que mirar mas abajo para ver el terreno
		var c = s3d.camera;
		c.fovY = 65;
		c.zNear = 0.2;
		c.zFar = 1500;
		c.pos.set(x, y, bgCamZ);
		c.target.set(x + Math.cos(yaw) * Math.cos(pitch), y + Math.sin(yaw) * Math.cos(pitch), bgCamZ + Math.sin(pitch));
		c.up.set(0, 0, 1);
		w.sky.follow(x, y, bgCamZ);
		w.updateWrap(x, y);
	}

	// ---------------------------------------------------------------- pruebas automaticas

	var shotStage = 0;

	/** Prueba numerica de la fisica: reposo, salto, jetpack, caida libre y caminata (1 fotograma = tmod 1). */
	function physTest() {
		var g = game;
		function run( n : Int, speed : Float, strafe : Float, jet : Bool ) {
			for( i in 0...n ) g.stepPhysics(1.0, speed, strafe, jet);
		}
		function f( v : Float ) return "" + Math.round(v * 1000) / 1000;
		run(80, 0, 0, false);
		var z0 = g.pz;
		Sys.println("reposo: z=" + f(z0) + " gravedad=" + f(g.gravity) + " combustible=" + f(g.jetpack) + " enSuelo=" + g.onGround());

		// salto: una pulsacion de un fotograma
		g.stepPhysics(1.0, 0, 0, true);
		var zmax = g.pz, frames = 1;
		for( i in 0...120 ) {
			g.stepPhysics(1.0, 0, 0, false);
			if( g.pz > zmax ) zmax = g.pz;
			frames++;
			if( g.onGround() ) break;
		}
		Sys.println("salto simple: altura maxima=" + f(zmax - z0) + " bloques, duracion=" + frames + " fotogramas (" + f(frames / 32) + " s). Formula 0.23^2/(2*0.014)=" + f(0.23 * 0.23 / (2 * 0.014)));

		// jetpack: espacio mantenido 90 fotogramas
		run(40, 0, 0, false);
		z0 = g.pz;
		var fuel0 = g.jetpack;
		zmax = z0;
		var fuelEnd = 0., tEmpty = -1;
		for( i in 0...90 ) {
			g.stepPhysics(1.0, 0, 0, true);
			if( g.pz > zmax ) zmax = g.pz;
			if( tEmpty < 0 && g.jetpack <= 0 ) tEmpty = i;
		}
		fuelEnd = g.jetpack;
		Sys.println("jetpack mantenido 90 fotogramas: altura maxima=" + f(zmax - z0) + " combustible " + f(fuel0) + " -> " + f(fuelEnd) + (tEmpty >= 0 ? ", se agota en el fotograma " + tEmpty : ""));
		// caer
		var maxG = 0., n = 0;
		while( !g.onGround() && n < 600 ) {
			g.stepPhysics(1.0, 0, 0, false);
			if( g.gravity > maxG ) maxG = g.gravity;
			n++;
		}
		Sys.println("aterriza tras " + n + " fotogramas, gravedad maxima alcanzada=" + f(maxG));

		// caida libre desde 25 bloques
		run(40, 0, 0, false);
		var zs = g.pz;
		g.pz += 25;
		g.gravity = 0;
		g.standingBlock = null;
		maxG = 0;
		n = 0;
		while( !g.onGround() && n < 600 ) {
			g.stepPhysics(1.0, 0, 0, false);
			if( g.gravity > maxG ) maxG = g.gravity;
			n++;
		}
		Sys.println("caida de 25 bloques: " + n + " fotogramas (" + f(n / 32) + " s), gravedad maxima=" + f(maxG) + " (tope 0.9), aterriza en z=" + f(g.pz) + " (suelo " + f(zs) + ")");

		// caminar: 32 fotogramas = 1 segundo, hacia una direccion libre
		var bestDist = -1., bestMode = "";
		for( mode in ["normal", "despacio"] ) {
			run(30, 0, 0, false);
			var x0 = g.px, y0 = g.py;
			var sp = mode == "normal" ? 0.15 : 0.15 * 0.4;
			run(32, sp, 0, false);
			var d = Math.sqrt((g.px - x0) * (g.px - x0) + (g.py - y0) * (g.py - y0));
			Sys.println("caminar " + mode + " 1 s: recorre " + f(d) + " bloques (esperado " + f(sp * 32) + " si no hay obstaculos)");
		}
		// no atraviesa paredes: empuja 200 fotogramas contra lo que haya delante
		var x1 = g.px, y1 = g.py;
		run(200, 0.15, 0, false);
		var tot = Math.sqrt((g.px - x1) * (g.px - x1) + (g.py - y1) * (g.py - y1));
		Sys.println("200 fotogramas hacia delante: recorre " + f(tot) + " bloques (sin atravesar el terreno: z=" + f(g.pz) + ")");
	}

	function testShot() {
		if( shotPath == null ) return;
		// menus: esperar a que el planeta de fondo este listo y sacar la captura
		if( state == Menu && shotStage == 0 && frames > shotFrames ) {
			if( shotScreen == "game" || shotScreen == "pause" || shotScreen == "phys" || shotScreen == "jet" || shotScreen == "mine" || shotScreen == "place" || shotScreen == "cont" || shotScreen == "palette" ) {
				shotStage = 1;
				if( shotScreen == "cont" ) {
					// carga la partida mas reciente (prueba de guardado)
					shotCont = true;
					shotScreen = "mine";
				}
				var info = shotLoad != null ? SaveData.list().filter(function(i) return i.id == shotLoad)[0] : shotCont ? SaveData.list()[0] : SaveData.create("Prueba", shotSeed, shotBiome != null ? shotBiome : "BIAutumn", 1);
				if( info == null ) {
					Sys.println("no se encontro la partida; hay: " + [for( i in SaveData.list() ) i.id].join(", ") + "  carpeta=" + SaveData.dir());
					Sys.exit(1);
				}
				// la partida de prueba nueva es de aventura pero con el inventario inicial del original: los guiones usan sus casillas
				if( shotLoad == null && !shotCont ) info.inv = Inv.defaults();
				startGame(info);
				return;
			}
			capture(shotPath);
		}
		if( state == Exploring && explorer != null && shotStage == 1 ) shotStage = 2;
		if( state == Playing && shotStage == 1 ) {
			shotStage = 2;
			if( shotAt != null && shotAt.length >= 3 ) {
				game.px = shotAt[0];
				game.py = shotAt[1];
				game.yaw = shotAt[2];
				if( shotAt.length > 3 ) game.pitch = shotAt[3];
				game.pz = shotAt.length > 4 ? shotAt[4] : game.world.topCollide(Std.int(game.px), Std.int(game.py)) + 0.01;
			}
			if( shotScreen == "phys" ) {
				physTest();
				Sys.exit(0);
			}
			if( shotScreen == "jet" ) {
				game.debugJet = true;
				shotFrames = frames + 45;
				return;
			}
			if( shotScreen == "mine" || shotScreen == "place" ) {
				game.inv.select(shotScreen == "mine" ? 0 : shotSlot);
				game.debugAction = !shotCont && Sys.args().indexOf("--tele") < 0;
				if( Sys.args().indexOf("--tele") >= 0 ) game.debugTele = 1;
				game.debugDeny = Sys.args().indexOf("--deny") >= 0;
				shotFrames = frames + shotN;
				return;
			}
			if( shotScreen == "palette" ) {
				openPalette();
				shotFrames = frames + 8;
				return;
			}
			if( shotScreen == "pause" ) {
				pause();
				shotFrames = frames + 6;
			} else
				shotFrames = frames + 6;
		}
		if( dev != null && shotStage == 2 && ((game != null && (state == Playing || state == Loading || (state == Paused && dev.inPause))) || (state == Exploring && explorer != null) || (state == Menu && dev.inMenu)) ) {
			if( dev.tick(this, game) ) Sys.exit(0);
			return;
		}
		if( shotStage == 2 && frames > shotFrames && (state == Playing || state == Paused) ) {
			if( Sys.args().indexOf("--listnear") >= 0 ) {
				// solo pruebas: bloques no cubicos a menos de 10 bloques del jugador
				var w = game.world;
				var out = [];
				for( dz in -6...7 )
					for( dy in -10...11 )
						for( dx in -10...11 ) {
							var b = w.block(Std.int(game.px) + dx, Std.int(game.py) + dy, Std.int(game.pz) + dz);
							if( b != null && b.type != BTFull && b.type != BTTransp && b.type != BTWater && b.type != BTModel2Side )
								out.push(b.k + "/" + b.type + "@" + dx + "," + dy + "," + dz);
						}
				Sys.println("cerca: " + out.join("  "));
				var zs = [for( c in game.ship.crafts ) "x=" + (c.x + w.shipDX) + ".." + (c.x + c.w - 1 + w.shipDX) + " y=" + (c.y + w.shipDY) + ".." + (c.y + c.h - 1 + w.shipDY) + " z=" + (c.z + World.SHIP_Z) + " alto=" + c.zSize];
				Sys.println("zonas de sintetizador: " + zs.join("  |  "));
			}
			if( shotScreen == "mine" || shotScreen == "place" ) {
				if( Sys.args().indexOf("--save") >= 0 ) saveGame(false);
				if( Sys.args().indexOf("--click") >= 0 ) Sys.println(game.debugPick());
				var n = 0;
				var cells = [];
				for( k in game.world.editMap.keys() ) {
					n++;
					var col = k >> 7;
					cells.push((col % game.world.size) + "," + Std.int(col / game.world.size) + "," + (k & 127));
				}
				if( cells.length > 0 ) Sys.println("celdas: " + cells.join("  "));
				var items = [for( s in game.inv.inv.t ) s == null ? "-" : Block.all[s.k].k + "x" + s.n];
				Sys.println("ediciones: " + n + "  inventario: " + items.join(" ") + "  select: " + (game.select == null ? "ninguno" : game.select.b.k + " poder=" + game.select.power));
			}
			capture(shotPath);
		}
	}

	public function capture( path : String, exit = true ) {
		var w = engine.width, h = engine.height;
		var tex = new h3d.mat.Texture(w, h, [Target]);
		tex.depthBuffer = new h3d.mat.Texture(w, h, [Target], Depth24Stencil8);
		engine.pushTarget(tex);
		engine.clear(0xFF05070D, 1, 0);
		s3d.render(engine);
		s2d.render(engine);
		engine.popTarget();
		sys.io.File.saveBytes(path, tex.capturePixels().toPNG());
		Sys.println("captura guardada: " + path);
		tex.depthBuffer.dispose();
		tex.dispose();
		if( exit ) Sys.exit(0);
	}

	/** Pruebas (orden `cover`): dibuja sobre magenta solo lo que este abierto (tienda, cofre, paleta, mapa de estrellas o menu;
	    el casco y el HUD se ocultan un momento) y mira si queda magenta en algun punto de los cuatro bordes de la ventana. Se
	    usa un color y no el alfa porque el mapa de estrellas suma sus capas (blend Add): su alfa es 1 aunque deje ver el fondo. */
	public function devCover( ?name : String ) : String {
		var top : h2d.Object = shop != null ? shop : contracts != null ? contracts : chest != null ? chest : palette != null ? palette : explorer != null ? explorer : current != null ? ui : null;
		if( top == null ) return "nada abierto";
		var hidden = [];
		for( o in s2d )
			if( o != top && o.visible ) {
				o.visible = false;
				hidden.push(o);
			}
		var w = engine.width, h = engine.height;
		var tex = new h3d.mat.Texture(w, h, [Target]);
		engine.pushTarget(tex);
		engine.clear(0xFFFF00FF, 1, 0);
		s2d.render(engine);
		engine.popTarget();
		for( o in hidden ) o.visible = true;
		var px = tex.capturePixels();
		tex.dispose();
		if( name != null ) sys.io.File.saveBytes("port/out/cover_" + name + ".png", px.toPNG());
		inline function magenta( x : Int, y : Int ) {
			var c = px.getPixel(x, y);
			return ((c >> 16) & 0xFF) >= 200 && ((c >> 8) & 0xFF) <= 80 && (c & 0xFF) >= 200;
		}
		var open = [];
		for( i in 1...6 ) {
			var fx = Std.int(w * i / 6), fy = Std.int(h * i / 6);
			if( magenta(1, fy) && open.indexOf("izquierda") < 0 ) open.push("izquierda");
			if( magenta(w - 2, fy) && open.indexOf("derecha") < 0 ) open.push("derecha");
			if( magenta(fx, 1) && open.indexOf("arriba") < 0 ) open.push("arriba");
			if( magenta(fx, h - 2) && open.indexOf("abajo") < 0 ) open.push("abajo");
		}
		return w + "x" + h + " " + (open.length == 0 ? "OK" : "SIN TAPAR: " + open.join(", "));
	}

	static function main() {
		#if hldx
		// DirectX compila los shaders la primera vez que se usan (segundos con la pantalla congelada): se guardan
		// compilados junto a las partidas y las siguientes veces se leen del disco
		try {
			var cache = new h3d.impl.ShaderCache(Settings.dir() + "/shaders_dx.cache");
			cache.load();
			h3d.impl.Driver.setShaderCache(cache);
		} catch( e : Dynamic ) {}
		#end
		// en pruebas (--shot/--script) el error va a stderr y se cierra, sin ventana encima del escritorio
		if( Lambda.exists(Sys.args(), a -> StringTools.startsWith(a, "--shot=") || StringTools.startsWith(a, "--script=")) )
			hxd.System.reportError = function(e:Dynamic) {
				Sys.stderr().writeString(Std.string(e) + "\n" + haxe.CallStack.toString(haxe.CallStack.exceptionStack()) + "\n");
				Sys.exit(1);
			};
		new GalaxyApp();
	}
}
