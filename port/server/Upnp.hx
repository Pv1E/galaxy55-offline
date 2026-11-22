/**
 * Abrir el puerto del servidor en el router de casa con UPnP (anadido del port para el multijugador): SSDP para encontrar el
 * router (InternetGatewayDevice), su descripcion para el servicio WANIPConnection (o WANPPPConnection) y SOAP para
 * AddPortMapping (TCP para el juego, UDP para la sonda) y GetExternalIPAddress. Todo en un hilo aparte (start): el resultado
 * se recoge con poll. Si no hay router UPnP o lo rechaza, el resultado dice el puerto y la IP local para abrirlo a mano.
 * Lo que contesta el router solo se lee (y se acota): nada se ejecuta ni se escribe en disco.
 */
class Upnp {

	public static inline var SSDP_HOST = "239.255.255.250";
	public static inline var SSDP_PORT = 1900;
	static inline var MAX_REPLY = 1 << 16;

	var result : sys.thread.Deque<UpnpResult>;
	var control : { url : String, service : String };
	var port : Int;

	public function new() {}

	/** empieza a abrir el puerto port (TCP y UDP) en el hilo */
	public function start( port : Int, desc : String ) {
		this.port = port;
		result = new sys.thread.Deque();
		var q = result;
		var self = this;
		sys.thread.Thread.create(function() {
			var r : UpnpResult = try self.open(port, desc) catch( e : Dynamic ) { ok : false, external : "", local : "", error : Std.string(e) };
			q.add(r);
		});
	}

	/** el resultado, si ya esta (una vez) */
	public function poll() : Null<UpnpResult> {
		if( result == null ) return null;
		var r = result.pop(false);
		if( r != null ) result = null;
		return r;
	}

	/** al parar el servidor: quitar la redireccion (sin esperar mucho; si falla, el router la quitara o quedara) */
	public function close() {
		var c = control;
		if( c == null ) return;
		control = null;
		for( proto in ["TCP", "UDP"] )
			try soap(c, "DeletePortMapping", "<NewRemoteHost></NewRemoteHost><NewExternalPort>" + port + "</NewExternalPort><NewProtocol>" + proto + "</NewProtocol>") catch( e : Dynamic ) {}
	}

	function open( port : Int, desc : String ) : UpnpResult {
		var loc = discover();
		if( loc == null ) return { ok : false, external : "", local : localIp(null), error : "no UPnP router" };
		var c = findControl(loc);
		if( c == null ) return { ok : false, external : "", local : localIp(loc), error : "the router has no WANIPConnection" };
		var local = localIp(loc);
		desc = ~/[^A-Za-z0-9 _.\-]/g.replace(desc, "").substr(0, 40);
		for( proto in ["TCP", "UDP"] ) {
			var body = "<NewRemoteHost></NewRemoteHost><NewExternalPort>" + port + "</NewExternalPort><NewProtocol>" + proto + "</NewProtocol>"
				+ "<NewInternalPort>" + port + "</NewInternalPort><NewInternalClient>" + local + "</NewInternalClient><NewEnabled>1</NewEnabled>"
				+ "<NewPortMappingDescription>" + desc + "</NewPortMappingDescription><NewLeaseDuration>0</NewLeaseDuration>";
			var r = soap(c, "AddPortMapping", body);
			if( r == null ) return { ok : false, external : "", local : local, error : "the router refuses to open the port (" + proto + ")" };
		}
		control = c;
		var ext = "";
		var r = soap(c, "GetExternalIPAddress", "");
		if( r != null ) {
			var re = ~/<NewExternalIPAddress>([0-9a-fA-F.:]{1,64})<\/NewExternalIPAddress>/;
			if( re.match(r) ) ext = re.matched(1);
		}
		return { ok : true, external : ext, local : local, error : "" };
	}

	/** SSDP M-SEARCH: la LOCATION del primer router que conteste (2 s) */
	function discover() : String {
		var u = new sys.net.UdpSocket();
		try {
			u.setTimeout(2);
			var msg = "M-SEARCH * HTTP/1.1\r\nHOST: " + SSDP_HOST + ":" + SSDP_PORT + "\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: urn:schemas-upnp-org:device:InternetGatewayDevice:1\r\n\r\n";
			var a = new sys.net.Address();
			a.host = new sys.net.Host(SSDP_HOST).ip;
			a.port = SSDP_PORT;
			var b = haxe.io.Bytes.ofString(msg);
			u.sendTo(b, 0, b.length, a);
			var buf = haxe.io.Bytes.alloc(2048), from = new sys.net.Address();
			var t0 = haxe.Timer.stamp();
			while( haxe.Timer.stamp() - t0 < 3 ) {
				var n = u.readFrom(buf, 0, buf.length, from);
				if( n <= 0 ) break;
				var s = buf.getString(0, n);
				var re = ~/\r\nlocation:[ \t]*(http:\/\/[^\r\n]{1,300})/i;
				if( re.match(s) ) {
					u.close();
					return StringTools.trim(re.matched(1));
				}
			}
		} catch( e : Dynamic ) {}
		try u.close() catch( e : Dynamic ) {}
		return null;
	}

	/** del XML de la descripcion del router: la URL de control del servicio WANIPConnection o WANPPPConnection */
	function findControl( loc : String ) : { url : String, service : String } {
		var xml = httpGet(loc);
		if( xml == null ) return null;
		for( svc in ["urn:schemas-upnp-org:service:WANIPConnection:1", "urn:schemas-upnp-org:service:WANIPConnection:2", "urn:schemas-upnp-org:service:WANPPPConnection:1"] ) {
			var i = xml.indexOf(svc);
			if( i < 0 ) continue;
			var re = ~/<controlURL>([^<]{1,300})<\/controlURL>/;
			if( !re.match(xml.substr(i)) ) continue;
			var url = StringTools.trim(re.matched(1));
			if( !StringTools.startsWith(url, "http") ) url = base(loc) + (StringTools.startsWith(url, "/") ? "" : "/") + url;
			return { url : url, service : svc };
		}
		return null;
	}

	static function base( url : String ) : String {
		var re = ~/^(http:\/\/[^\/]+)/;
		return re.match(url) ? re.matched(1) : url;
	}

	/** la IP de este PC en la red del router (la que usa para llegar a el) */
	static function localIp( loc : String ) : String {
		var host = "8.8.8.8", port = 53;
		if( loc != null ) {
			var re = ~/^http:\/\/([^\/:]+)(?::([0-9]+))?/;
			if( re.match(loc) ) {
				host = re.matched(1);
				port = re.matched(2) != null ? Std.parseInt(re.matched(2)) : 80;
			}
		}
		try {
			var s = new sys.net.Socket();
			s.setTimeout(2);
			s.connect(new sys.net.Host(host), port);
			var ip = s.host().host.toString();
			s.close();
			return ip;
		} catch( e : Dynamic ) {}
		try return new sys.net.Host(sys.net.Host.localhost()).toString() catch( e : Dynamic ) return "?";
	}

	static function httpGet( url : String ) : String {
		var h = new haxe.Http(url);
		h.cnxTimeout = 3;
		var out : String = null;
		h.onData = function(d) out = d.length > MAX_REPLY ? d.substr(0, MAX_REPLY) : d;
		h.onError = function(_) out = null;
		try h.request(false) catch( e : Dynamic ) return null;
		return out;
	}

	/** una accion SOAP del servicio; la respuesta, o null si falla */
	function soap( c : { url : String, service : String }, action : String, body : String ) : String {
		var env = '<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>'
			+ '<u:' + action + ' xmlns:u="' + c.service + '">' + body + '</u:' + action + '></s:Body></s:Envelope>';
		var h = new haxe.Http(c.url);
		h.cnxTimeout = 3;
		h.setHeader("Content-Type", 'text/xml; charset="utf-8"');
		h.setHeader("SOAPAction", '"' + c.service + "#" + action + '"');
		h.setPostData(env);
		var out : String = null, status = 0;
		h.onStatus = function(s) status = s;
		h.onData = function(d) out = d.length > MAX_REPLY ? d.substr(0, MAX_REPLY) : d;
		h.onError = function(_) out = null;
		try h.request(true) catch( e : Dynamic ) return null;
		return status == 200 ? out : null;
	}
}

typedef UpnpResult = { ok : Bool, external : String, local : String, error : String };
