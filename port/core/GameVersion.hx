import Common;

/**
 * Version del juego (antes GalaxyApp.VERSION) y huella del contenido para el multijugador (anadido del port): un cliente solo
 * entra en un servidor con la misma version, el mismo protocolo y el mismo contenido (bloques, recetas, biomas, generador).
 */
class GameVersion {

	public static inline var VERSION = "0.8.1";

	static var hash : String;

	/** SHA-256 corto de lo que tiene que ser igual en los dos lados (los kubes del editor no cuentan: los manda el servidor) */
	public static function contentHash() : String {
		if( hash != null ) return hash;
		var s = new StringBuf();
		s.add(VERSION + "|gen" + gen.Generator.VERSION + "|");
		for( n in Type.getEnumConstructs(BlockKind) ) { s.add(n); s.add(","); }
		s.add("|");
		for( n in Type.getEnumConstructs(BiomeKind) ) { s.add(n); s.add(","); }
		s.add("|");
		for( r in Data.CRAFT ) {
			s.add(r.id); s.add(":"); s.add(Std.string(r.out)); s.add("x"); s.add(r.count);
			s.add("="); s.add(Std.string(r.schema)); s.add(";");
		}
		hash = haxe.crypto.Sha256.encode(s.toString()).substr(0, 16);
		return hash;
	}
}
