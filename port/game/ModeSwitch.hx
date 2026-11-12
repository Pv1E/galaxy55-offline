import Ui;

/**
 * Bascula creativo <-> supervivencia de una partida creada en creativo (anadido del port, GameView.setSurvival). La partida
 * sigue siendo creativa (SaveInfo.creative): licencias sin limite, Base de datos ESCorp completa, etiqueta de la lista.
 * - ModeSwitch.button: el boton. Va abajo a la derecha de la paleta creativa (Palette.addCornerButton); la pantalla de
 *   inventario de la aventura debe llevar el mismo, con GalaxyApp.switchMode al pulsarlo.
 * - el panel (new ModeSwitch): en supervivencia, la tecla de la paleta abre solo esto. Provisional, hasta que esa tecla abra
 *   la pantalla de inventario.
 * Con el mando, Y bascula (en la paleta y en el panel); en el panel, A tambien.
 */
class ModeSwitch extends h2d.Object {

	public var onSwitch : Void -> Void;
	public var onClose : Void -> Void;
	var btn : Button;

	public function new( parent : h2d.Object ) {
		super(parent);
		var w = 640, h = 230;
		var px = (Theme.W - w) * 0.5, py = (Theme.H - h) * 0.5;
		var bg = new h2d.Graphics(this);
		Theme.fullRect(bg, 0x000000, 0.5);
		Theme.rect(bg, px, py, w, h, Theme.PANEL, 0.96);
		Theme.rect(bg, px, py, w, 4, Theme.ACCENT);
		Theme.text(this, Lang.t("mode.panel.title"), 2.6, Theme.TEXT, px + 24, py + 22);
		var info = Theme.text(this, Lang.t("mode.panel.info"), 1.6, Theme.DIM, px + 24, py + 66);
		info.maxWidth = (w - 48) / info.scaleX;
		btn = button(this, false, function() if( onSwitch != null ) onSwitch());
		btn.x = Std.int(px + (w - btn.w) * 0.5);
		btn.y = Std.int(py + 120);
		// el unico control: siempre con el foco (Intro / A lo pulsan)
		btn.focused = true;
		Theme.text(this, Keys.fill(Lang.t("mode.panel.hint")), 1.5, Theme.DIM, px + 24, py + h - 34);
	}

	/** el boton de la bascula: "Pasar a supervivencia" (toSurvival) o "Volver a creativo"; se resalta con el raton encima */
	public static function button( parent : h2d.Object, toSurvival : Bool, fn : Void -> Void ) : Button {
		var label = Lang.t(toSurvival ? "mode.toSurvival" : "mode.toCreative");
		var t = Theme.text(null, label, 2.0, Theme.TEXT);
		var b = new Button(parent, label, Std.int(t.textWidth * t.scaleX) + 48, 44);
		@:privateAccess {
			b.label.setScale(2.0);
			b.redraw();
			b.inter.onOut = function(_) b.focused = false;
		}
		b.onHover = function(_) b.focused = true;
		b.onActivate = fn;
		return b;
	}

	/** teclado y mando: Intro / A / Y bascula; la tecla de la paleta, Esc, B o R3 cierran */
	public function update( dt : Float, pad : hxd.Pad ) {
		var K = hxd.Key;
		var go = K.isPressed(K.ENTER), back = K.isPressed(K.ESCAPE) || Keys.pressed("palette");
		if( pad != null ) {
			if( pad.isPressed(pad.config.A) || pad.isPressed(pad.config.Y) ) go = true;
			if( pad.isPressed(pad.config.B) || pad.isPressed(pad.config.ranalogClick) ) back = true;
		}
		if( go ) btn.activate();
		else if( back && onClose != null ) onClose();
	}

	/** banco de pruebas (orden modebutton): pulsa el boton */
	public function devPress() btn.activate();
}
