import Msg;
import ExpData;

/**
 * Multijugador (anadido del port): los sistemas de las galaxias de otros jugadores donde este tiene planetas abiertos (SForeign)
 * se anaden a su mapa como sistemas mas, "Sistema de XXXX", arriba a la izquierda del sector. En ellos solo se aterriza en lo
 * abierto para el (PInvited: explorador, PVisit: visita); el resto sale cerrado (PForbidden) y las cometas no salen nunca.
 * Sus ids van desde BASE para no chocar con los del jugador; targets da, para cada planeta, la galaxia y el id de verdad.
 */
class ForeignMap {

	public static inline var BASE = 1000;
	static var targets = new Map<Int, { pub : String, pid : Int, owner : String }>();

	public static inline function isForeign( systemId : Int ) return systemId >= BASE;

	/** galaxia (id publico de su descubridor) e id de verdad de un planeta del mapa; null si es del jugador */
	public static function target( mapId : Int ) return targets.get(mapId);

	public static function inject( d : ExpInfos, list : Array<NetForeign> ) {
		targets = new Map();
		if( list == null ) return;
		var k = 0;
		for( f in list ) {
			var start = f.startSize == 0 ? null : { seed : f.startSeed, biome : f.startBiome, size : f.startSize };
			var fd = ExpOffline.make(f.seed, start, null, null, null, f.gone);
			var systems = new Map<Int, Bool>();
			for( p in f.planets ) {
				var at = ExpOffline.planet(fd, p.pid);
				if( at != null ) systems.set(at.s.id, true);
			}
			for( fs in fd.systems ) {
				if( !systems.exists(fs.id) ) continue;
				var sid = BASE + k;
				var copy : ExpSystem = {
					id : sid, seed : fs.seed, name : Lang.t("mp.system.of").split("%n%").join(f.owner),
					x : 4 + (k % 6) * 4, y : 4 + Std.int(k / 6) * 5, status : SOpen, planets : [],
				};
				k++;
				for( i in 0...fs.planets.length ) {
					var p = fs.planets[i];
					var st = Lambda.find(f.planets, q -> q.pid == p.id);
					var status : ExpPlanetStatus = st == null ? PForbidden : Type.createEnumIndex(ExpPlanetStatus, st.status);
					var id = sid * 10 + i;
					copy.planets.push({ id : id, seed : p.seed, size : p.size, distance : p.distance, name : p.name, status : status,
						gas : p.gas, biome : p.biome });
					targets.set(id, { pub : f.pub, pid : p.id, owner : f.owner });
				}
				d.systems.push(copy);
			}
		}
	}
}
