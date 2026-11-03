import SaveData.SaveInfo;
import SaveData.UniInfo;
import ExpData;

/**
 * Viaje espacial: lo que pasa mientras la partida esta en el espacio (despegue, viaje por el mapa, sistemas, aterrizaje,
 * robot comerciante). Es la base del port para las ideas del viaje espacial de IDEAS.md: combustible, desbloquear sistemas,
 * misiones o puntos fijos, robot que se aleja, planetas lejanos mas ricos. En el cliente original no habia nada de esto.
 *
 * Lleva la cuenta de lo recorrido y aplica las licencias de la ESCorp (Licenses: escanear, abandonar). Lo que haya que guardar va en UniInfo (SaveData), en
 * campos opcionales, para que las partidas antiguas sigan cargando. GalaxyApp crea uno cada vez que se abre el mapa.
 */
class Space {

	public var info(default, null) : SaveInfo;
	public var uni(default, null) : UniInfo;
	/** tutorial en curso: la nave esta averiada, solo se aterriza en el planeta del tutorial y no se sale del sistema */
	public var tutorial = false;
	/** aviso de lo que no se puede hacer (GalaxyApp.showToast) */
	public var onRefuse : String -> Void = function(_) {};

	public function new( info : SaveInfo ) {
		this.info = info;
		this.uni = info.uni;
		if( uni.traveled == null ) uni.traveled = 0;
	}

	/** antes de salir del sistema solar al sector: false = la nave se para en el borde */
	public function canLeave() : Bool {
		if( !tutorial ) return true;
		onRefuse(TutoText.get("noleave"));
		return false;
	}

	/** al despegar, con el planeta ya descargado (no al abrir el mapa desde una partida guardada en el espacio) */
	public function takeoff() {}

	/** la nave ha avanzado `dist` en el mapa (en el sector, o dentro de un sistema si `inSystem`): aqui iria el gasto de combustible */
	public function travel( dist : Float, inSystem : Bool ) {
		uni.traveled += dist;
	}

	/** la nave ha entrado en un sistema o ha salido al sector: [0, x, y] o [1, sistema], como UniInfo.pos */
	public function moved( pos : Array<Int> ) {}

	/** antes de aterrizar en un planeta (al pulsar Aterrizar o Escanear): false = no se puede */
	public function canLand( p : ExpPlanet ) : Bool {
		if( Licenses.isAbandoned(uni, p.id) ) return false;
		if( !tutorial || p.id == TutoSetup.PLANET ) return true;
		onRefuse(TutoText.get("badplanet"));
		return false;
	}

	/** antes de escanear un planeta sin explorar: hace falta una licencia libre (Licenses, anadido del port) */
	public function canScan( p : ExpPlanet ) : Bool {
		// una cometa no gasta licencia (Comets, añadido del port)
		if( tutorial || p.comet != null || Licenses.canClaim(info) ) return true;
		onRefuse(Lang.t("license.full"));
		return false;
	}

	/** la ventana del planeta ofrece abandonarlo (Licenses): solo los que tienen licencia, y no en el tutorial */
	public function canAbandon( p : ExpPlanet ) : Bool return !tutorial && Licenses.has(uni, p.id);

	/** al aterrizar, antes de cargar el planeta */
	public function land( p : ExpPlanet ) {}

	/** boton del candado de un sistema cerrado (en el original se abria pagando la licencia): aun no hace nada */
	public function unlock( s : ExpSystem ) {}

	/** al acoplarse al robot comerciante, antes de entrar en su nave */
	public function dock() {}
}
