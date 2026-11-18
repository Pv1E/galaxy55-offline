/**
 * Servidor del multijugador sin ventana (anadido del port). De momento solo comprueba que el nucleo (port/core) compila sin
 * Heaps: `hl port/out/server.hl --gen SEMILLA BIOMA TAMANO` genera un planeta con WorldData y escribe la suma de sus celdas
 * (la misma que da la orden de pruebas `print cellhash` del juego).
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
			Sys.println("partida nueva: sector " + info.uni.seed + ", planeta " + p.name + " (" + p.biome + ", " + p.size + "), creditos " + info.credits
				+ ", licencias " + info.uni.licenses.length + ", contratos " + Contracts.active(info).length);
			return;
		}
		Sys.println("uso: server.hl --gen SEMILLA BIOMA TAMANO | --newplayer SEMILLA");
	}
}
