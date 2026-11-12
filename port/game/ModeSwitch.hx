import Ui;

/**
 * Bascula creativo <-> supervivencia de una partida creada en creativo (anadido del port, GameView.setSurvival). La partida
 * sigue siendo creativa (SaveInfo.creative): licencias sin limite, Base de datos ESCorp completa, etiqueta de la lista.
 * ModeSwitch.button es el boton, con GalaxyApp.switchMode al pulsarlo: en creativo va abajo a la derecha de la paleta
 * (Palette.addCornerButton, Y del mando); en supervivencia, la tecla de la paleta abre la pantalla de inventario y va arriba a
 * la derecha (InvScreen.addCornerButton, Select del mando: alli Y tira, como al jugar).
 */
class ModeSwitch {

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
}
