import Ui;

/** un servidor guardado en Multijugador: nombre que le da el jugador, direccion y la huella de su clave (la primera vez que se entro) */
typedef SavedServer = { name : String, host : String, port : Int, ?fp : String };

/** lo que contesta un servidor a la sonda "G55?" (GameServer.pumpUdp) y cuanto tardo */
typedef ServerStatus = { name : String, version : String, content : String, players : Int, port : Int, password : Bool, ping : Float, host : String, seen : Float };

/**
 * Servidores del jugador (anadido del port): la lista de Multijugador, en Settings.dir()/multijoueur.json (fuera de las partidas:
 * se conservan al cambiar de partida). Solo nombre, direccion y huella: nada que venga de un servidor se escribe aqui salvo su
 * huella, que es un texto hexadecimal que se comprueba al leerlo.
 */
class MultiServers {

	public static inline var PORT = 55055;
	static inline var NAME_MAX = 32;

	static function path() return Settings.dir() + "/multijoueur.json";

	public static function load() : Array<SavedServer> {
		var out : Array<SavedServer> = [];
		var o : Dynamic = try haxe.Json.parse(sys.io.File.getContent(path())) catch( e : Dynamic ) null;
		var l : Array<Dynamic> = o == null || !Std.isOfType(o.servers, Array) ? [] : o.servers;
		for( e in l ) {
			if( e == null || !Std.isOfType(e.host, String) || !Std.isOfType(e.port, Int) ) continue;
			var name : String = Std.isOfType(e.name, String) ? e.name : e.host;
			var fp : String = Std.isOfType(e.fp, String) && ~/^[0-9a-f]{8,128}$/.match(e.fp) ? e.fp : null;
			out.push({ name : name.substr(0, NAME_MAX), host : (e.host : String).substr(0, 253), port : e.port, fp : fp });
		}
		return out;
	}

	public static function save( l : Array<SavedServer> ) {
		try {
			sys.FileSystem.createDirectory(Settings.dir());
			sys.io.File.saveContent(path(), haxe.Json.stringify({ servers : l }, "\t"));
		} catch( e : Dynamic ) Sys.stderr().writeString("multijoueur.json: " + e + "\n");
	}

	/** "host", "host:puerto" o "[ipv6]:puerto"; null si no vale */
	public static function parseAddress( s : String ) : { host : String, port : Int } {
		s = StringTools.trim(s);
		if( s == "" ) return null;
		var host = s, port = PORT;
		var i = s.lastIndexOf(":");
		if( i > 0 && s.indexOf(":") == i ) {
			host = s.substr(0, i);
			var p = Std.parseInt(s.substr(i + 1));
			if( p == null || p <= 0 || p > 65535 ) return null;
			port = p;
		}
		if( !~/^[A-Za-z0-9.\-]{1,253}$/.match(host) ) return null;
		return { host : host, port : port };
	}

	public static inline function key( host : String, port : Int ) return host + ":" + port;
}

/**
 * Sondas UDP "G55?" (anadido del port): la difusion en la red local (al puerto de siempre) encuentra las partidas creadas en
 * ella, y una sonda directa a cada servidor guardado dice si esta en linea, cuantos juegan y si tiene la misma version. La
 * respuesta es un JSON corto que solo se lee (ningun campo se escribe en disco) y se acota.
 */
class ServerProbe {

	var udp : sys.net.UdpSocket;
	var buf = haxe.io.Bytes.alloc(1024);
	var sent = new Map<String, Float>();
	/** respuestas por "host:puerto" */
	public var results(default, null) = new Map<String, ServerStatus>();
	/** las que llegaron de la difusion (red local) */
	public var lan(default, null) = new Map<String, Bool>();

	public function new() {
		try {
			udp = new sys.net.UdpSocket();
			udp.setBlocking(false);
		} catch( e : Dynamic ) udp = null;
		if( udp != null ) try udp.setBroadcast(true) catch( e : Dynamic ) Sys.stderr().writeString("sonda: sin difusion (" + e + ")\n");
	}

	public function dispose() {
		if( udp != null ) try udp.close() catch( e : Dynamic ) {}
		udp = null;
	}

	function sendTo( host : String, port : Int ) : Bool {
		if( udp == null ) return false;
		try {
			var a = new sys.net.Address();
			a.host = new sys.net.Host(host).ip;
			a.port = port;
			udp.sendTo(haxe.io.Bytes.ofString("G55?"), 0, 4, a);
			return true;
		} catch( e : Dynamic ) return false;
	}

	/** a un servidor guardado */
	public function probe( host : String, port : Int ) {
		if( sendTo(host, port) ) sent.set(MultiServers.key(host, port), haxe.Timer.stamp());
	}

	/** a toda la red local (y a este PC: una partida creada en el mismo PC) */
	public function broadcast() {
		var ok = sendTo("255.255.255.255", MultiServers.PORT);
		if( sendTo("127.0.0.1", MultiServers.PORT) ) ok = true;
		if( ok ) sent.set("*", haxe.Timer.stamp());
	}

	/** respuesta reciente de host:puerto (la de una partida que se ha parado deja de valer) */
	public function fresh( k : String ) : ServerStatus {
		var s = results.get(k);
		return s != null && haxe.Timer.stamp() - s.seen < 8 ? s : null;
	}

	public function pump() {
		if( udp == null ) return;
		var from = new sys.net.Address();
		for( _ in 0...32 ) {
			var n = -1;
			try n = udp.readFrom(buf, 0, buf.length, from) catch( e : Dynamic ) n = -1;
			if( n < 4 || buf.getString(0, 4) != "G55!" ) {
				if( n < 0 ) return;
				continue;
			}
			var o : Dynamic = try haxe.Json.parse(buf.getString(4, n - 4)) catch( e : Dynamic ) null;
			if( o == null ) continue;
			var host = from.getHost().toString();
			var port : Int = Std.isOfType(o.port, Int) ? o.port : from.port;
			var k = MultiServers.key(host, port);
			var t0 = sent.exists(k) ? sent.get(k) : sent.exists("*") ? sent.get("*") : haxe.Timer.stamp();
			if( !sent.exists(k) ) lan.set(k, true);
			results.set(k, {
				name : Std.isOfType(o.name, String) ? (o.name : String).substr(0, 48) : host,
				version : Std.isOfType(o.version, String) ? (o.version : String).substr(0, 16) : "?",
				content : Std.isOfType(o.content, String) ? (o.content : String).substr(0, 64) : "",
				players : Std.isOfType(o.players, Int) ? o.players : 0,
				port : port,
				password : o.password == true,
				ping : haxe.Timer.stamp() - t0,
				host : host,
				seen : haxe.Timer.stamp(),
			});
		}
	}
}

/**
 * Fila de un servidor en Multijugador (como SaveRow): nombre, direccion y estado; con el foco, sus acciones arriba a la
 * derecha (Unirse, Modificar, Borrar; o Unirse y Anadir para una partida de la red local que no esta guardada).
 */
class ServerRow extends Widget {
	public static inline var W = 1000;
	static inline var BW = 150;
	/** ancho de sus botones (BW; los de los invitados, mas largos: Pasar a explorador) */
	var bw : Int;
	static inline var BH = 36;
	public var actions(default, null) : Array<String>;
	public var action(default, set) = 0;
	public var onAction : String -> Void;
	var status : h2d.Text;
	var acts : h2d.Object;
	var actBg : Array<h2d.Graphics>;
	var actText : Array<h2d.Text>;

	public function new( parent : h2d.Object, title : String, address : String, actions : Array<String>, lanTag : Bool, bw = BW ) {
		super(parent, W, 92);
		this.bw = bw;
		this.actions = actions;
		label.visible = false;
		Theme.text(this, title, 2.3, Theme.TEXT, 22, 10);
		Theme.text(this, (lanTag ? Lang.t("mp.lan") + "  ·  " : "") + address, 1.6, Theme.CYAN, 22, 46);
		status = Theme.text(this, Lang.t("mp.status.wait"), 1.5, Theme.DIM, 22, 68);
		acts = new h2d.Object(this);
		actBg = [];
		actText = [];
		var x0 = w - 14 - actions.length * (bw + 8) + 8;
		for( i in 0...actions.length ) {
			var b = new h2d.Object(acts);
			b.x = x0 + i * (bw + 8);
			b.y = 10;
			actBg.push(new h2d.Graphics(b));
			var t = Theme.text(b, Lang.t("mp.act." + actions[i]), 1.7, Theme.TEXT);
			Theme.center(t, bw, BH);
			actText.push(t);
			var it = new h2d.Interactive(bw, BH, b);
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
		onRight = function() if( action < actions.length - 1 ) action++;
		onActivate = function() if( onAction != null && actions.length > 0 ) onAction(actions[action]);
		inter.onClick = function(_) if( enabled ) {
			if( onPress != null ) onPress(this);
			action = 0;
			activate();
		};
		drawActions();
	}

	/** la linea de abajo con otro texto (Opciones multijugador: donde esta el jugador) */
	public function setInfo( text : String, col : Int ) {
		status.text = text;
		status.textColor = col;
	}

	/** la linea de estado: lo que contesto el servidor (o que no contesta) */
	public function setStatus( s : ServerStatus, waited : Bool ) {
		// sin respuesta desde hace un rato: ya no esta (se ha parado)
		if( s != null && haxe.Timer.stamp() - s.seen > 8 ) s = null;
		if( s == null ) {
			status.text = Lang.t(waited ? "mp.status.offline" : "mp.status.wait");
			status.textColor = Theme.DIM;
			return;
		}
		var same = s.version == GameVersion.VERSION && (s.content == "" || s.content == GameVersion.contentHash());
		var parts = [Lang.t("mp.status.online"), Lang.t("mp.status.players").split("%n%").join("" + s.players), Std.int(s.ping * 1000) + " ms"];
		if( s.password ) parts.push(Lang.t("mp.status.password"));
		parts.push(same ? Lang.t("mp.status.version.ok") : Lang.t("mp.status.version.bad").split("%v%").join(s.version));
		status.text = parts.join("  ·  ");
		status.textColor = same ? Theme.ACCENT : Theme.DANGER;
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
			if( on ) Theme.rect(g, 0, 0, bw, BH, actions[i] == "delete" ? Theme.DANGER : Theme.ACCENT, 0.9);
			else Theme.rect(g, 0, 0, bw, BH, 0xFFFFFF, 0.08);
			actText[i].textColor = on ? Theme.BG : Theme.TEXT;
		}
	}
}

/** pantalla Multijugador: las filas de los servidores (VISIBLE a la vista, como LoadScreen) y un tic para las sondas */
class ServerListScreen extends Screen {
	public var rows = new Array<ServerRow>();
	public var top = 0;
	/** filas a la vista */
	public var VISIBLE = 4;
	static inline var STEP = 100;
	public var listX = 130.;
	public var listY = 130.;
	public var onTick : Float -> Void;
	var bar : h2d.Graphics;

	override function setFocus( i : Int ) {
		super.setFocus(i);
		if( i >= 0 && i < rows.length ) {
			if( i < top ) top = i;
			if( i >= top + VISIBLE ) top = i - VISIBLE + 1;
			layout();
		}
	}

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
		if( onTick != null ) onTick(dt);
		super.update(dt, pad);
	}

	public function layout() {
		for( i in 0...rows.length ) {
			var r = rows[i];
			r.visible = i >= top && i < top + VISIBLE;
			r.x = listX;
			r.y = listY + (i - top) * STEP;
		}
		if( bar == null ) bar = new h2d.Graphics(this);
		bar.clear();
		if( rows.length > VISIBLE ) {
			var x = listX + ServerRow.W + 12, h = VISIBLE * STEP - 8;
			var th = h * VISIBLE / rows.length;
			Theme.rect(bar, x, listY, 6, h, 0xFFFFFF, 0.08);
			Theme.rect(bar, x, listY + (h - th) * top / (rows.length - VISIBLE), 6, th, Theme.ACCENT, 0.8);
		}
	}
}
