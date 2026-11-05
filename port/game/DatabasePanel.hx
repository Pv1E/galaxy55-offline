import Ui;
import SaveData.SaveInfo;

/**
 * Base de datos ESCorp (anadido del port, ver Kubindex), desde el ordenador de a bordo. Tres pestanas: el Kubindex (kubes
 * localizados y recuperados, con su ficha), los planetas (tipos explorados y sus kubes) y las recetas descubiertas.
 * No para el juego, como los contratos. Raton, teclado (Tab, flechas, Intro, Esc) y mando (LB/RB, cruceta, A, B).
 */
class DatabasePanel extends h2d.Object {

	public static inline var PW = 1200;
	public static inline var PH = 660;
	/** zona de las pestanas (dentro del panel) */
	public static inline var CW = 1152;
	public static inline var CH = 498;
	static var TABS = ["tab.kubindex", "tab.planets", "tab.recipes"];

	public var onClose : Void -> Void;
	public var info(default, null) : SaveInfo;
	public var atlas(default, null) : h3d.mat.Texture;
	public var tab(default, null) = -1;
	public var view(default, null) : KubView;
	/**
	 * las pestanas ya hechas se guardan (ocultas) mientras el panel este abierto, con la Kubindex.version de cuando se dejaron:
	 * al volver a una sin que nada haya cambiado no se rehace. Rehacerla creaba cientos de objetos y el recolector de memoria
	 * de HashLink paraba el juego unas decenas de ms
	 */
	var views : Array<KubView> = [];
	var versions : Array<String> = [];
	var px : Float;
	var py : Float;
	var tabsG : h2d.Graphics;
	var tabTexts : Array<h2d.Text> = [];
	var content : h2d.Object;
	var infoText : h2d.Text;
	var hover : String;

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture, info : SaveInfo ) {
		super(parent);
		this.atlas = atlas;
		this.info = info;
		Kubindex.ensure(info);
		px = (Theme.W - PW) * 0.5;
		py = (Theme.H - PH) * 0.5;
		var bg = new h2d.Graphics(this);
		Theme.fullRect(bg, 0x000000, 0.55);
		Theme.rect(bg, px, py, PW, PH, Theme.PANEL, 0.97);
		Theme.rect(bg, px, py, PW, 4, Theme.ACCENT);
		Theme.rect(bg, px + 24, py + PH - 40, PW - 48, 1, 0xFFFFFF, 0.1);
		Theme.text(this, KubText.get("title"), 2.6, Theme.TEXT, px + 24, py + 18);
		tabsG = new h2d.Graphics(this);
		for( i in 0...TABS.length ) {
			var it = new h2d.Interactive(200, 38, this);
			it.setPosition(px + 24 + i * 210, py + 66);
			var t = Theme.text(it, KubText.get(TABS[i]), 1.8, Theme.TEXT);
			Theme.center(t, 200, 38);
			tabTexts.push(t);
			it.onClick = function(_) setTab(i);
		}
		var close = new h2d.Interactive(160, 36, this);
		close.setPosition(px + PW - 184, py + 18);
		var cg = new h2d.Graphics(close);
		Theme.rect(cg, 0, 0, 160, 36, 0xFFFFFF, 0.08);
		Theme.center(Theme.text(close, Lang.t("shop.close"), 1.8, Theme.TEXT), 160, 36);
		close.onClick = function(_) if( onClose != null ) onClose();
		content = new h2d.Object(this);
		content.setPosition(px + 24, py + 118);
		infoText = Theme.text(this, "", 1.4, Theme.DIM, px + 24, py + PH - 30);
		setTab(0);
	}

	public function setTab( i : Int ) {
		if( i == tab ) return;
		if( view != null ) {
			view.visible = false;
			versions[tab] = Kubindex.version(info);
		}
		tab = i;
		view = views[i];
		if( view != null && versions[i] == Kubindex.version(info) )
			view.visible = true;
		else {
			if( view != null ) view.remove();
			view = views[i] = switch( i ) {
				case 1: new KubPlanetsView(this, content);
				case 2: new KubRecipesView(this, content);
				default: new KubBlocksView(this, content);
			};
			view.refresh();
		}
		setHover(null);
		tabsG.clear();
		for( j in 0...TABS.length ) {
			Theme.rect(tabsG, px + 24 + j * 210, py + 66, 200, 38, j == tab ? Theme.ACCENT : 0xFFFFFF, j == tab ? 0.35 : 0.06);
			tabTexts[j].textColor = j == tab ? Theme.TEXT : Theme.DIM;
		}
	}

	/** ir a la ficha de un kube en el Kubindex (clic en una ficha de una receta o de un planeta) */
	public function pick( e : Block ) {
		if( e == null || !Kubindex.known(info, e) ) return;
		setTab(0);
		cast(view, KubBlocksView).show(e);
	}

	/** linea de abajo: lo que hay bajo el raton o, si nada, la ayuda de los controles */
	public function setHover( s : String ) {
		hover = s;
		infoText.text = s != null ? s : KubText.get("hint");
		infoText.textColor = s != null ? Theme.TEXT : Theme.DIM;
	}

	public function scroll( delta : Float ) view.scroll(delta);

	/** teclado y mando */
	public function update( dt : Float, pad : hxd.Pad ) {
		var K = hxd.Key;
		var dx = 0, dy = 0, dt2 = 0;
		if( K.isPressed(K.LEFT) ) dx = -1;
		if( K.isPressed(K.RIGHT) ) dx = 1;
		if( K.isPressed(K.UP) ) dy = -1;
		if( K.isPressed(K.DOWN) ) dy = 1;
		if( K.isPressed(K.TAB) ) dt2 = K.isDown(K.SHIFT) ? -1 : 1;
		var ok = K.isPressed(K.ENTER) || K.isPressed(K.NUMPAD_ENTER), back = K.isPressed(K.ESCAPE);
		var page = K.isPressed(K.PGUP) ? -1 : K.isPressed(K.PGDOWN) ? 1 : 0;
		if( pad != null ) {
			if( pad.isPressed(pad.config.dpadLeft) ) dx = -1;
			if( pad.isPressed(pad.config.dpadRight) ) dx = 1;
			if( pad.isPressed(pad.config.dpadUp) ) dy = -1;
			if( pad.isPressed(pad.config.dpadDown) ) dy = 1;
			if( pad.isPressed(pad.config.RB) ) dt2 = 1;
			if( pad.isPressed(pad.config.LB) ) dt2 = -1;
			if( pad.isPressed(pad.config.A) ) ok = true;
			if( pad.isPressed(pad.config.B) ) back = true;
			if( pad.isPressed(pad.config.X) ) page = 1;
		}
		if( back ) {
			if( onClose != null ) onClose();
			return;
		}
		if( dt2 != 0 ) setTab((tab + dt2 + TABS.length) % TABS.length);
		if( dx != 0 || dy != 0 ) view.nav(dx, dy);
		if( page != 0 ) view.page(page);
		if( ok ) view.activate();
	}
}
