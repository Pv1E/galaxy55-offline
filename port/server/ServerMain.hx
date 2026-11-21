import Msg;

/**
 * Servidor del multijugador sin ventana (anadido del port): `hl server.hl [--data CARPETA] [--port PUERTO]` (galaxy55-serveur.bat).
 * La primera vez crea en la carpeta (por defecto "serveur", junto al servidor) serveur.json, su clave y la base de datos; cada
 * jugador nuevo empieza en una galaxia nueva y el primero que entra es el propietario. Escribe el registro en la consola y lee
 * ordenes: stop, list, kick PSEUDO, ban PSEUDO, unban PSEUDO, op PSEUDO, deop PSEUDO, say TEXTO, save, help.
 * Pruebas: `--gen SEMILLA BIOMA TAMANO` (suma de las celdas de un planeta, la de `print cellhash` del juego) y
 * `--newplayer SEMILLA` (partida nueva sin el juego).
 */
class ServerMain {

	static function main() {
		var args = Sys.args();
		// las reglas del port (lo que sueltan los bloques, etc.), como en el juego (GalaxyApp.init)
		PortRules.apply();
		if( args.length >= 4 && args[0] == "--gen" ) {
			var w = new WorldData(Std.parseInt(args[1]), args[2], Std.parseInt(args[3]));
			var t0 = haxe.Timer.stamp();
			while( !w.genStep(haxe.Timer.stamp(), 1000) ) {}
			Sys.println('cellhash ${args[1]} ${args[2]} ${args[3]}: ' + w.cellHash() + ' (' + Std.int((haxe.Timer.stamp() - t0) * 1000) + ' ms)');
			return;
		}
		if( args.length >= 2 && args[0] == "--newplayer" ) {
			// partida nueva de un jugador (como la aventura sin tutorial): comprueba que los datos de partida compilan sin el juego
			var info = TutoSetup.newGame("prueba", Std.parseInt(args[1]), false);
			var p = ExpData.ExpOffline.make(info.uni.seed, info.uni.start).systems[0].planets[TutoSetup.PLANET];
			Sys.println("new game: sector " + info.uni.seed + ", planet " + p.name + " (" + p.biome + ", " + p.size + "), credits " + info.credits
				+ ", licenses " + info.uni.licenses.length + ", contracts " + Contracts.active(info).length);
			return;
		}
		var dir = "serveur", port : Null<Int> = null;
		var i = 0;
		while( i < args.length ) {
			switch( args[i] ) {
			case "--data" if( i + 1 < args.length ): dir = args[++i];
			case "--port" if( i + 1 < args.length ): port = Std.parseInt(args[++i]);
			case "--help", "-h", "/?":
				Sys.println("usage: server.hl [--data FOLDER] [--port PORT]");
				return;
			default:
				Sys.println("unknown option: " + args[i] + " (--help)");
				return;
			}
			i++;
		}
		run(dir, port);
	}

	static function run( dir : String, port : Null<Int> ) {
		sys.FileSystem.createDirectory(dir);
		var server = new GameServer(dir);
		server.files.echo = true;
		// sin juego que dibujar: mas tiempo para generar planetas en cada vuelta
		server.genBudgetMs = 15;
		// kubes del editor: los .kube de <datos>/kubes
		server.loadKubes(dir + "/kubes");
		server.listen("0.0.0.0", port);
		Sys.println("Galaxy 55 - server \"" + server.files.options.name + "\" v" + GameVersion.VERSION + " on port " + (port != null ? port : server.files.options.port)
			+ " (data: " + sys.FileSystem.absolutePath(dir) + "). Commands: help");
		// la consola se lee en otro hilo (readLine espera): las ordenes llegan por la cola
		var lines = new sys.thread.Deque<String>();
		sys.thread.Thread.create(function() {
			while( true ) {
				var l = try Sys.stdin().readLine() catch( e : Dynamic ) null;
				if( l == null ) break;
				lines.add(l);
				// tras una orden de parar no se vuelve a leer: en Linux y macOS exit() espera al cerrojo de stdin, que un
				// readLine en curso no suelta, y el proceso se quedaba vivo despues de "server stopped"
				var c = StringTools.trim(l).toLowerCase();
				if( c == "stop" || c == "quit" || c == "exit" ) break;
			}
		});
		var last = haxe.Timer.stamp();
		var running = true;
		while( running ) {
			var now = haxe.Timer.stamp();
			var dt = now - last;
			last = now;
			if( dt > 0.25 ) dt = 0.25;
			server.pump(dt);
			var l = lines.pop(false);
			while( l != null ) {
				if( !command(server, StringTools.trim(l)) ) running = false;
				l = lines.pop(false);
			}
			Sys.sleep(0.01);
		}
		server.stop();
	}

	/** una orden de la consola; false = parar */
	static function command( server : GameServer, l : String ) : Bool {
		if( l == "" ) return true;
		var sp = l.indexOf(" ");
		var cmd = (sp < 0 ? l : l.substr(0, sp)).toLowerCase(), arg = sp < 0 ? "" : StringTools.trim(l.substr(sp + 1));
		switch( cmd ) {
		case "stop", "quit", "exit":
			return false;
		case "list":
			var ps = server.playing();
			Sys.println(ps.length + (ps.length == 1 ? " player" : " players") + (ps.length == 0 ? "" : ": " + [for( s in ps ) s.display + (s.role == Owner ? " (owner)" : s.role == Manager ? " (manager)" : "") + (s.where != "" ? " on a planet" : " in space")].join(", ")));
		case "kick", "ban", "unban", "op", "deop":
			var r = server.consoleAdmin(cmd, arg);
			Sys.println(r);
		case "say":
			if( arg != "" ) server.consoleSay(arg);
		case "save":
			server.worlds.commit();
			Sys.println("saved");
		case "help", "?":
			Sys.println("commands: stop | list | kick NICKNAME | ban NICKNAME | unban NICKNAME | op NICKNAME | deop NICKNAME | say TEXT | save");
		default:
			Sys.println("unknown command: " + cmd + " (help)");
		}
		return true;
	}
}
