import Common;

/**
 * Prueba del guardado: escribe una partida con inventario y cambios de terreno y la vuelve a leer.
 *   haxe port/savetest.hxml   y   GALAXY55_DATA=port/out/testdata hl port/out/savetest.hl
 * Solo corre con GALAXY55_DATA (una carpeta de datos de prueba): sin ella escribiria en las partidas de verdad (%APPDATA%).
 */
class SaveTest {
	static function main() {
		var data = Sys.getEnv("GALAXY55_DATA");
		if( data == null || data == "" ) {
			Sys.println("SaveTest necesita GALAXY55_DATA (carpeta de datos de prueba, p. ej. port/out/testdata): no se toca %APPDATA%");
			Sys.exit(1);
		}
		// creativo: empieza con el inventario inicial del original (en aventura estaria vacio)
		var info = SaveData.create("Prueba guardado", 42, "BIMoon", 2, true);
		info.inv.t[0].n = 7;
		info.inv.t[9] = { k : Type.enumIndex(BWood), n : 3 };
		info.inv.charges[1].n = 12;
		info.edits = [12345, 0, 67890, Type.enumIndex(BLamp)];
		var ok = SaveData.write(info, null);
		var back = SaveData.read(info.id);
		Sys.println("escrito: " + ok);
		Sys.println("nombre: " + back.name + " semilla: " + back.seed + " bioma: " + back.biome + " tamano: " + back.sizeChunks);
		Sys.println("inventario[0]=" + back.inv.t[0].k + "x" + back.inv.t[0].n + " (esperado " + Type.enumIndex(BLamp) + "x7)");
		Sys.println("inventario[9]=" + back.inv.t[9].k + "x" + back.inv.t[9].n + " (esperado " + Type.enumIndex(BWood) + "x3)");
		Sys.println("cargas[1]=" + back.inv.charges[1].c + "x" + back.inv.charges[1].n + " (esperado 1x12)");
		Sys.println("ediciones=" + back.edits.join(",") + " (esperado 12345,0,67890," + Type.enumIndex(BLamp) + ")");
		SaveData.delete(info.id);
	}
}
