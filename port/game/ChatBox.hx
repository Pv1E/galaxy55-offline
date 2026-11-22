import Ui;
import Msg;

/**
 * Chat del multijugador (anadido del port): los ultimos mensajes abajo a la izquierda, que se apagan solos, y con T una linea
 * para escribir. Se escribe al canal del mundo o al del planeta (Tab mientras se escribe cambia de uno a otro); "/m pseudo
 * texto" es un mensaje privado. Mientras se escribe el juego sigue pero sin controles (GalaxyApp). Todo lo que se manda lo
 * apunta el servidor (chat.log).
 */
class ChatBox extends h2d.Object {

	static inline var LINES = 7;
	static inline var LIFE = 14.;
	static inline var X = 20;
	static inline var BOTTOM = 600;
	static inline var SCALE = 1.6;

	var lines : Array<{ t : h2d.Text, age : Float }> = [];
	var input : h2d.TextInput;
	var chanText : h2d.Text;
	var bg : h2d.Graphics;
	public var typing(default, null) = false;
	public var chan(default, null) : ChatChan = CWorld;
	/** mandar: canal, pseudo del destinatario (privado) y texto */
	public var onSend : ChatChan -> String -> String -> Void;
	/** fotograma en que se dejo de escribir (el Intro o el Esc no deben servir tambien al juego) */
	public var stoppedFrame(default, null) = -1;

	public function new( parent : h2d.Object ) {
		super(parent);
		bg = new h2d.Graphics(this);
		chanText = Theme.text(this, "", SCALE, Theme.ACCENT, X, BOTTOM + 8);
		input = new h2d.TextInput(Theme.font, this);
		input.setScale(SCALE);
		input.textColor = Theme.TEXT;
		input.y = BOTTOM + 8;
		input.inputWidth = Std.int(700 / SCALE);
		input.onChange = function() if( input.text.length > Msg.CHAT_MAX ) input.text = input.text.substr(0, Msg.CHAT_MAX);
		input.onKeyDown = function( e : hxd.Event ) {
			switch( e.keyCode ) {
			case hxd.Key.ENTER, hxd.Key.NUMPAD_ENTER:
				send();
				close();
			case hxd.Key.ESCAPE:
				close();
			case hxd.Key.TAB:
				chan = chan == CWorld ? CPlanet : CWorld;
				drawInput();
			default:
			}
		};
		close();
	}

	/** una linea mas (la de mas abajo); col: su color */
	public function add( text : String, col : Int ) {
		var t = Theme.text(this, text, SCALE, col, X, 0);
		t.maxWidth = 760 / SCALE;
		lines.push({ t : t, age : 0. });
		while( lines.length > LINES ) lines.shift().t.remove();
		layout();
	}

	function layout() {
		var y = BOTTOM;
		var i = lines.length - 1;
		while( i >= 0 ) {
			var l = lines[i];
			y -= Std.int(l.t.textHeight * l.t.scaleY) + 2;
			l.t.y = y;
			i--;
		}
	}

	public function open() {
		if( typing ) return;
		typing = true;
		input.text = "";
		input.visible = true;
		chanText.visible = true;
		drawInput();
		input.focus();
	}

	public function close() {
		if( typing ) stoppedFrame = hxd.Timer.frameCount;
		typing = false;
		input.visible = false;
		chanText.visible = false;
		bg.clear();
		if( input.hasFocus() ) input.blur();
	}

	function drawInput() {
		chanText.text = "[" + Lang.t(chan == CWorld ? "mp.chat.world" : "mp.chat.planet") + "]";
		input.x = X + chanText.textWidth * chanText.scaleX + 10;
		bg.clear();
		Theme.rect(bg, X - 6, BOTTOM + 4, 820, Std.int(Theme.font.lineHeight * SCALE) + 8, 0x000000, 0.55);
	}

	function send() {
		var s = StringTools.trim(input.text);
		if( s == "" || onSend == null ) return;
		// "/m pseudo texto": privado
		if( StringTools.startsWith(s, "/m ") ) {
			var rest = StringTools.trim(s.substr(3));
			var i = rest.indexOf(" ");
			if( i <= 0 ) return;
			onSend(CPrivate, rest.substr(0, i), StringTools.trim(rest.substr(i + 1)));
			return;
		}
		onSend(chan, "", s);
	}

	public function update( dt : Float ) {
		for( l in lines ) {
			l.age += dt;
			// escribiendo se ven todas; si no, se apagan
			l.t.alpha = typing ? 1 : l.age < LIFE - 2 ? 1 : Math.max(0, (LIFE - l.age) / 2);
		}
		if( typing && !input.hasFocus() ) input.focus();
	}
}

/**
 * Lista de jugadores (anadido del port): con Tab mantenido. Pseudo, papel (propietario, gestionnaire) y donde esta: "Espacio"
 * (en el espacio o la nodriza), "???" (un planeta al que no puedes ir) o el planeta de quien es (NetPlayer.place, del servidor).
 */
class PlayerList extends h2d.Object {

	static inline var WID = 760;

	public function new( parent : h2d.Object ) {
		super(parent);
		visible = false;
	}

	public static function placeName( place : String ) : String {
		if( place == "" ) return Lang.t("mp.place.space");
		var i = place.lastIndexOf("|");
		if( i < 0 ) return "???";
		return Lang.t("mp.place.planet").split("%n%").join(place.substr(0, i));
	}

	public function refresh( players : Iterable<NetPlayer>, myId : Int ) {
		removeChildren();
		var l = [for( p in players ) p];
		l.sort(function(a, b) return a.role != b.role ? b.role - a.role : Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase()));
		var rowH = 34, h = 70 + l.length * rowH;
		var x = (Theme.W - WID) >> 1, y = Std.int(Math.max(40, (Theme.H - h) * 0.4));
		var bg = new h2d.Graphics(this);
		Theme.rect(bg, x, y, WID, h, Theme.PANEL, 0.92);
		Theme.rect(bg, x, y, WID, 4, Theme.ACCENT);
		Theme.text(this, Lang.t("mp.players").split("%n%").join("" + l.length), 2.0, Theme.TEXT, x + 20, y + 14);
		var yy = y + 56;
		for( p in l ) {
			var me = p.id == myId;
			Theme.text(this, p.name + (me ? "  " + Lang.t("mp.you") : ""), 1.7, me ? Theme.ACCENT : Theme.TEXT, x + 20, yy);
			var role = p.role == (Owner : Int) ? Lang.t("mp.role.owner") : p.role == (Manager : Int) ? Lang.t("mp.role.manager") : "";
			if( role != "" ) Theme.text(this, role, 1.5, Theme.CYAN, x + 300, yy + 3);
			var t = Theme.text(this, placeName(p.place), 1.5, Theme.DIM, 0, yy + 3);
			t.x = x + WID - 20 - t.textWidth * t.scaleX;
			yy += rowH;
		}
	}
}
