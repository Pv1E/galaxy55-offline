/**
 * Lo de las cometas que necesitan los datos del mundo (anadido del port, multijugador): su tamano y sus biomas. El resto de
 * las reglas de las cometas (franjas, tiradas, visitas) esta en Comets.
 */
class CometRules {
	/** lado del mundo de una cometa (multiplo de 16 por los trozos) */
	public static inline var SIZE = 96;
	/** biomas de cometa (BiomeKind) */
	public static var KINDS = ["BICometCinder"];

	public static function isComet( biome : String ) return KINDS.indexOf(biome) >= 0;
}
