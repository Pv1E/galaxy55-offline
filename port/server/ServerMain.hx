/**
 * Servidor del multijugador sin ventana (anadido del port). De momento solo comprueba que el nucleo (port/core) compila sin
 * Heaps: `hl port/out/server.hl --gen SEMILLA BIOMA TAMANO` genera un planeta con WorldData y escribe la suma de sus celdas
 * (la misma que da la orden de pruebas `print cellhash` del juego).
 */
class ServerMain {

	static function main() {
		var args = Sys.args();
		if( args.length >= 4 && args[0] == "--gen" ) {
			PortRules.apply();
			var w = new WorldData(Std.parseInt(args[1]), args[2], Std.parseInt(args[3]));
			var t0 = haxe.Timer.stamp();
			while( !w.genStep(haxe.Timer.stamp(), 1000) ) {}
			Sys.println('cellhash ${args[1]} ${args[2]} ${args[3]}: ' + w.cellHash() + ' (' + Std.int((haxe.Timer.stamp() - t0) * 1000) + ' ms)');
			return;
		}
		Sys.println("uso: server.hl --gen SEMILLA BIOMA TAMANO");
	}
}
