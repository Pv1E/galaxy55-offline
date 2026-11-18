/**
 * La hora de las reglas (anadido del port para el multijugador): contratos, licencias y cometas. En solo es la del PC; en
 * multijugador, la del servidor (offset, puesto al entrar con la de SWelcome), para que el tablero de contratos y los plazos
 * sean los mismos para el cliente y el servidor.
 */
class Clock {

	public static var offset = 0.;

	public static inline function now() : Float return Sys.time() + offset;
}
