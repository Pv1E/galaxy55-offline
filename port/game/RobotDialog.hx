import Ui;

/** respuesta del jugador en la conversacion con el robot: "N. texto" en una fila como las de Contratos; la elegida, con marco dorado */
class DialogOption extends Widget {

	var num : Int;
	var text : String;

	public function new( parent : h2d.Object, num : Int, text : String, w : Int ) {
		this.num = num;
		this.text = text;
		super(parent, w, 44);
	}

	override function redraw() {
		if( label == null ) return;
		bg.clear();
		if( text == null ) return;
		var on = focused && enabled;
		// como las filas de Contratos (ContractPanel): caja clara y, la elegida, con marco dorado
		Theme.rect(bg, 0, 0, w, h - 4, 0xFFFFFF, on ? 0.12 : 0.06);
		if( on ) {
			Theme.rect(bg, 0, 0, w, 3, Theme.ACCENT);
			Theme.rect(bg, 0, h - 7, w, 3, Theme.ACCENT);
			Theme.rect(bg, 0, 0, 3, h - 4, Theme.ACCENT);
			Theme.rect(bg, w - 3, 0, 3, h - 4, Theme.ACCENT);
		}
		label.text = num + ". " + text;
		label.setScale(2.2);
		label.x = 14;
		label.textColor = !enabled ? Theme.DISABLED : on ? Theme.ACCENT : Theme.TEXT;
		label.y = (h - label.textHeight * label.scaleY) * 0.5;
	}
}

/**
 * Conversacion con el robot comerciante de la nave nodriza (anadido del port), en un panel abajo de la pantalla con los colores
 * de los menus del juego, como la ventana de Contratos (azul oscuro, franja dorada, filas claras y marco dorado en la elegida),
 * pero sin oscurecer la pantalla para que se vea al robot. Arriba, lo que dice el robot, letra a letra con
 * estatica de radio (sfx robotStatic) mientras se le mueve la cabeza (Robot.talk); debajo, las respuestas numeradas (1-3, raton,
 * flechas o mando). La camara se gira sola hasta mirarlo (GalaxyApp.updateRobotDialog). Charlar le hace decir otra frase y la
 * conversacion sigue; Comerciar abre la tienda y Adios (o Esc) la cierra.
 */
class RobotDialog extends Screen {

	/** letras por segundo */
	static inline var CPS = 36;
	static inline var CHAT_LINES = 10;

	public var robot(default, null) : Robot;
	public var onTrade : Void -> Void;
	public var onBye : Void -> Void;

	var frame : h2d.Graphics;
	var line : h2d.Text;
	var full = "";
	var shown = 0.;
	var chan : hxd.snd.Channel;
	var t = 0.;
	var options : Array<DialogOption> = [];
	var bx : Float;
	var by : Float;
	var bw : Float;
	var bh : Float;
	static var lastChat = -1;

	public function new( parent : h2d.Object, robot : Robot, canTrade : Bool ) {
		super(parent);
		this.robot = robot;
		var a = Theme.visibleArea();
		bw = Math.min(1060, a.w - 80);
		bh = 290;
		bx = a.x + (a.w - bw) * 0.5;
		by = a.y + a.h - bh - 30;
		frame = new h2d.Graphics(this);
		// como los paneles de los menus (GalaxyApp.drawPanel): fondo azul, franja dorada arriba y una linea clara abajo
		Theme.rect(frame, bx, by, bw, bh, Theme.PANEL, 0.94);
		Theme.rect(frame, bx, by, bw, 4, Theme.ACCENT);
		Theme.rect(frame, bx, by + bh - 1, bw, 1, 0xFFFFFF, 0.1);
		Theme.rect(frame, bx + 16, by + 52, bw - 32, 1, 0xFFFFFF, 0.08);
		Theme.rect(frame, bx + 16, by + bh - 158, bw - 32, 1, 0xFFFFFF, 0.08);
		Theme.text(this, Lang.t("shop.title"), 2.6, Theme.TEXT, bx + 24, by + 14);
		line = Theme.text(this, "", 2.0, Theme.CYAN, bx + 24, by + 60);
		line.maxWidth = (bw - 44) / line.scaleX;
		var labels = [Lang.t("robot.opt.trade"), Lang.t("robot.opt.chat"), Lang.t("robot.opt.bye")];
		for( i in 0...3 ) {
			var o = new DialogOption(this, i + 1, labels[i], Std.int(bw - 36));
			add(o, bx + 18, by + bh - 150 + i * 46);
			options.push(o);
		}
		options[0].enabled = canTrade;
		options[0].onActivate = function() if( onTrade != null ) onTrade();
		options[1].onActivate = chat;
		options[2].onActivate = function() if( onBye != null ) onBye();
		onBack = function() if( onBye != null ) onBye();
		say(Lang.t("robot.hello" + (Std.random(3) + 1)));
	}

	function chat() {
		var i = Std.random(CHAT_LINES);
		if( i == lastChat ) i = (i + 1) % CHAT_LINES;
		lastChat = i;
		say(Lang.t("robot.chat" + (i + 1)));
	}

	/** el robot empieza a decir s: las respuestas se esconden hasta que acaba */
	function say( s : String ) {
		stopSound();
		full = s;
		shown = 0;
		line.text = "";
		for( o in options ) o.visible = false;
		chan = Snd.play("robotStatic", 0.9, true);
	}

	function typing() return shown < full.length;

	function stopSound() {
		if( chan != null ) {
			chan.stop();
			chan = null;
		}
	}

	public function close() {
		stopSound();
		remove();
	}

	override function update( dt : Float, pad : hxd.Pad ) {
		t += dt;
		if( typing() ) {
			shown += dt * CPS;
			if( robot != null ) robot.talk = 0.2;
			// Intro, espacio, clic o A: se ve la frase entera de una vez
			var K = hxd.Key;
			var skip = K.isPressed(K.ENTER) || K.isPressed(K.SPACE) || K.isPressed(K.MOUSE_LEFT) || (pad != null && pad.isPressed(pad.config.A));
			if( skip && t > 0.3 ) shown = full.length;
			line.text = full.substr(0, Std.int(Math.min(shown, full.length)));
			if( !typing() ) {
				stopSound();
				for( o in options ) o.visible = true;
				firstEnabled();
			}
			if( K.isPressed(K.ESCAPE) || (pad != null && pad.isPressed(pad.config.B)) ) if( onBye != null ) onBye();
			return;
		}
		var K = hxd.Key;
		for( i in 0...options.length )
			if( (K.isPressed(K.NUMBER_1 + i) || K.isPressed(K.NUMPAD_1 + i)) && options[i].enabled ) {
				setFocus(i);
				options[i].activate();
				return;
			}
		super.update(dt, pad);
	}
}
