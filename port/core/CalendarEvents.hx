/** un evento del calendario: su id y sus dias (mes * 100 + dia, incluidos; from > to = pasa por el ano nuevo) */
typedef CalendarEvent = { id : String, from : Int, to : Int };

/**
 * Eventos del calendario (anadido del port): lo que el juego solo hace en unas fechas del ano. El dia es el de la hora de las
 * reglas (Clock: la del servidor en multijugador) en UTC, asi el cliente y el servidor estan de acuerdo.
 * Lo que hace cada uno:
 * - christmas (1 al 31 de diciembre): el Sapin de Noel (Structures, estructura "christmastree") sale en los planetas generados
 *   esos dias. Los planetas se rehacen con su semilla cada vez que se cargan: fuera de esas fechas ya no esta.
 * Para probar otra fecha: --date=AAAA-MM-DD (o MM-DD) en la linea de ordenes.
 */
class CalendarEvents {

	public static var ALL : Array<CalendarEvent> = [
		{ id : "christmas", from : 1201, to : 1231 },
	];

	/** dia impuesto por --date (mes * 100 + dia); null = el del reloj */
	public static var forcedDay : Null<Int>;

	/** --date=AAAA-MM-DD o --date=MM-DD de la linea de ordenes */
	public static function applyArgs() {
		for( a in Sys.args() )
			if( StringTools.startsWith(a, "--date=") ) {
				forcedDay = parseDay(a.substr(7));
				if( forcedDay == null ) Sys.stderr().writeString("--date: fecha no valida " + a.substr(7) + " (AAAA-MM-DD)\n");
			}
	}

	/** "AAAA-MM-DD" o "MM-DD" -> mes * 100 + dia (null si no es una fecha) */
	public static function parseDay( s : String ) : Null<Int> {
		var p = s.split("-");
		if( p.length < 2 ) return null;
		var m = Std.parseInt(p[p.length - 2]), d = Std.parseInt(p[p.length - 1]);
		if( m == null || d == null || m < 1 || m > 12 || d < 1 || d > 31 ) return null;
		return m * 100 + d;
	}

	/** el dia (mes * 100 + dia, UTC) de una hora en segundos (Clock.now) */
	public static function dayOf( time : Float ) : Int {
		var d = Date.fromTime(time * 1000);
		return (d.getUTCMonth() + 1) * 100 + d.getUTCDate();
	}

	/** hoy: el dia impuesto por --date o el de Clock.now */
	public static function today() : Int {
		return forcedDay != null ? forcedDay : dayOf(Clock.now());
	}

	static function covers( e : CalendarEvent, day : Int ) : Bool {
		return e.from <= e.to ? day >= e.from && day <= e.to : day >= e.from || day <= e.to;
	}

	/** los ids de los eventos de ese dia (null = hoy), en el orden de ALL */
	public static function active( ?day : Int ) : Array<String> {
		if( day == null ) day = today();
		return [for( e in ALL ) if( covers(e, day) ) e.id];
	}

	public static function isActive( id : String, ?day : Int ) : Bool {
		return active(day).indexOf(id) >= 0;
	}
}
