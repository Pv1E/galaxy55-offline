import Msg;
import GameServer.Session;

/**
 * Kubes del editor del servidor (anadido del port para el multijugador): los .kube de su carpeta (la del anfitrion, o
 * <datos>/kubes en el servidor dedicado), leidos sin el juego (KubeCore.fromKubeFile) y mandados a cada jugador al entrar en
 * bruto (SKubeDef). Cada uno tiene un numero fijo, apuntado en kubes.json junto a los datos del servidor: los bloques que se
 * ponen en el mundo, en los inventarios o en las cantinas (KubeCore.blocksFor(numero)) siguen siendo los mismos al volver a
 * arrancar aunque se anadan kubes; uno que ya no esta deja su numero vacio (aire). Como mucho KubeCore.MAX.
 */
class ServerKubes {

	public var list(default, null) : Array<KubeCore.NetKube> = [];
	var files : ServerFiles;

	public function new( files : ServerFiles ) {
		this.files = files;
	}

	/** lee los .kube de dir (null: ninguno) y les da su numero (los conocidos, el suyo; los nuevos, a continuacion) */
	public function load( dir : String, orderFile : String ) {
		var order : Array<String> = [];
		try {
			var o : Dynamic = haxe.Json.parse(sys.io.File.getContent(orderFile));
			if( Std.isOfType(o, Array) ) order = [for( v in (o : Array<Dynamic>) ) Std.isOfType(v, String) ? (v : String) : ""];
		} catch( e : Dynamic ) {}
		var found = new Map<String, String>(), ids = [];
		if( dir != null && sys.FileSystem.exists(dir) && sys.FileSystem.isDirectory(dir) ) {
			var names = sys.FileSystem.readDirectory(dir);
			names.sort(Reflect.compare);
			for( n in names ) {
				if( !StringTools.endsWith(n.toLowerCase(), ".kube") ) continue;
				var id = n.substr(0, n.length - 5).toLowerCase();
				if( !~/^[a-z0-9_.\-]{1,40}$/.match(id) || found.exists(id) ) continue;
				found.set(id, dir + "/" + n);
				ids.push(id);
			}
		}
		// los nuevos, por orden de nombre de archivo (ids sale ordenado de readDirectory)
		for( id in ids ) if( order.indexOf(id) < 0 && order.length < KubeCore.MAX ) order.push(id);
		list = [];
		var loaded = 0;
		for( i in 0...order.length ) {
			var id = order[i];
			var k = !found.exists(id) ? null : try KubeCore.fromKubeFile(sys.io.File.getBytes(found.get(id)), id) catch( e : Dynamic ) null;
			list.push(k);
			var blocks = KubeCore.blocksFor(i);
			if( k != null ) {
				KubeCore.setupNet(blocks, k, function(_) return 0xFFF);
				loaded++;
			} else
				for( b in blocks ) KubeCore.reset(b, "-");
		}
		try sys.io.File.saveContent(orderFile, haxe.Json.stringify(order)) catch( e : Dynamic ) {}
		if( loaded > 0 ) files.log(loaded + " kubes del editor (" + dir + ")");
	}

	/** a un jugador que entra: los kubes (los que hay) y cuantos numeros */
	public function send( s : Session ) {
		for( i in 0...list.length ) if( list[i] != null ) s.send(SKubeDef(i, list[i]));
		s.send(SKubesEnd(list.length));
	}

	/** el bloque de un kube por su archivo y su variante (la partida de un jugador que traia kubes, ServerWorlds.importHost) */
	public function blockOf( id : String, variant : Int ) : Block {
		for( i in 0...list.length )
			if( list[i] != null && list[i].id == id ) {
				// variantes de su forma (EditorKubes.Slot.variants): la puerta y el tableau 4, el plano 2, lo demas 1
				var s = KubeCore.SHAPES[list[i].shape].id, n = s == "door" || s == "painting" ? 4 : s == "plane" ? 2 : 1;
				return KubeCore.blocksFor(i)[variant >= 0 && variant < n ? variant : 0];
			}
		return null;
	}
}
