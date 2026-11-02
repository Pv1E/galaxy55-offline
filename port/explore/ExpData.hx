/** Datos del explorador (ExploreProtocol.hx del original, sin Hash ni @:native) y el generador de datos sin servidor (Main.hx). */
typedef ExpSector = {
	var id : Int;
	var seed : Int;
	var width : Int;
	var height : Int;
	var name : String;
}

enum ExpSystemStatus {
	SLocked( cost : Int );
	SOpen;
}

enum ExpPlanetStatus {
	PUnexplored;
	PActive;
	PAbandonned;
	PInvited;
	PForbidden;
}

typedef ExpPlanet = {
	var id : Int;
	var seed : Int;
	var size : Int;
	var distance : Int;
	var name : String;
	var status : ExpPlanetStatus;
	var gas : Bool;
	var biome : String;
}

typedef ExpSystem = {
	var id : Int;
	var seed : Int;
	var name : String;
	var x : Int;
	var y : Int;
	var status : ExpSystemStatus;
	var planets : Array<ExpPlanet>;
}

enum ExpShipPos {
	PInSector( x : Int, y : Int );
	PInSystem( id : Int );
	PPlanet( id : Int );
}

typedef ExpInfos = {
	var sector : ExpSector;
	var systems : Array<ExpSystem>;
	var shipPos : ExpShipPos;
	var energy : Int;
	var freeLicense : Bool;
}

/** Datos de sector y sistemas generados en local (exp.OfflineData del original sin servidor): todos los sistemas abiertos y planetas sin explorar. */
class ExpOffline {
	static var SYS(get, never) : String; static inline function get_SYS() return Lang.t("exp.system");
	static var SEC(get, never) : String; static inline function get_SEC() return Lang.t("exp.sector");
	static var NAMES = ["Aldebar", "Brume", "Cyrene", "Dorian", "Eskel", "Fenris", "Galata", "Hespera", "Ikaros", "Jovan", "Kestrel", "Lumen"];
	static var BIOMES = ["BIAutumn", "BIWinterPeaks", "BIMars", "BIMoon", "BIAcidForest"];
	static var BWEIGHTS = [100, 100, 80, 80, 50];
	/** sistemas del sector; los que sustituyen a uno desaparecido (Licenses) siguen con los ids SYSTEMS, SYSTEMS + 1... */
	public static inline var SYSTEMS = 10;
	static var ROMAN = ["II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"];

	/** nombre de un sistema; a partir de la segunda vuelta de NAMES (sistemas que sustituyen a otros) lleva un numero */
	static function systemName( id : Int ) : String {
		var round = Std.int(id / NAMES.length);
		return SYS + " " + NAMES[id % NAMES.length] + (round > 0 ? " " + ROMAN[(round - 1) % ROMAN.length] : "");
	}
	/** nombre del bioma en el idioma actual; tambien los que no salen al azar (la Ciudad muerta puede ser el planeta de salida) */
	public static function biomeName( biome : String ) : String {
		var n = Lang.t("biome." + biome);
		return n != "biome." + biome ? n : Lang.t("biome." + BIOMES[biomeIndex(biome)]);
	}

	public static function biomeIndex( biome : String ) : Int {
		var i = BIOMES.indexOf(biome);
		return i < 0 ? 0 : i;
	}

	static function generateSystem( id : Int, seed : Int ) : ExpSystem {
		var rseed = new mt.Rand(seed);
		var s : ExpSystem = {
			id : id,
			seed : seed,
			name : systemName(id),
			planets : [],
			x : 20 + id * 3,
			y : 25,
			status : SOpen,
		};
		var total = 0;
		for( w in BWEIGHTS ) total += w;
		for( i in 0...rseed.random(3) + 2 ) {
			var roll = rseed.random(total);
			var bi = 0;
			while( roll >= BWEIGHTS[bi] ) {
				roll -= BWEIGHTS[bi];
				bi++;
			}
			s.planets.push({
				id : id * 10 + i,
				seed : seed + i,
				size : [1, 2, 2, 3][rseed.random(4)], // pequena 128, normal 256, grande 384
				distance : i,
				name : s.name + " " + (i + 1),
				status : PUnexplored,
				gas : false,
				biome : BIOMES[bi],
			});
		}
		return s;
	}

	/** nombres del sector, los sistemas y los planetas en el idioma actual (al cambiar de idioma con el mapa abierto) */
	public static function relabel( d : ExpInfos ) {
		d.sector.name = SEC + " " + d.sector.seed;
		for( s in d.systems ) {
			s.name = systemName(s.id);
			for( i in 0...s.planets.length ) s.planets[i].name = s.name + " " + (i + 1);
		}
	}

	/**
	 * `start` sustituye al planeta 0 del sistema 0 (con el que empieza la partida), `visited` son los planetas con licencia
	 * (activos), `pos` donde esta la nave en el mapa, `abandoned` los planetas abandonados y `gone` los sistemas que
	 * desaparecieron, en orden (Licenses, anadido del port).
	 */
	public static function make( seed : Int, ?start : { seed : Int, biome : String, size : Int }, ?visited : Array<Int>, ?pos : Array<Int>, ?abandoned : Array<Int>, ?gone : Array<Int> ) : ExpInfos {
		seed = 1 + Std.int(Math.abs(seed)) % 999998;
		var d : ExpInfos = {
			sector : { id : 0, seed : seed, width : 50, height : 50, name : SEC + " " + seed },
			systems : [],
			shipPos : PInSector(30, 30),
			energy : 100,
			freeLicense : true,
		};
		for( i in 0...SYSTEMS ) d.systems.push(generateSystem(i, seed + i));
		var rseed = new mt.Rand(seed);
		rseed.initSeed(seed);
		for( s in d.systems ) {
			s.x += rseed.random(2);
			s.y += rseed.random(20);
		}
		if( start != null ) {
			var p = d.systems[0].planets[0];
			p.seed = start.seed;
			p.biome = start.biome;
			p.size = start.size;
		}
		var removed : Array<ExpSystem> = [];
		if( gone != null )
			for( i in 0...gone.length ) {
				var old = system(d, gone[i]);
				if( replaceSystem(d, gone[i], SYSTEMS + i) != null ) removed.push(old);
			}
		for( s in d.systems )
			for( p in s.planets ) {
				if( visited != null && visited.indexOf(p.id) >= 0 ) p.status = PActive;
				if( abandoned != null && abandoned.indexOf(p.id) >= 0 ) p.status = PAbandonned;
			}
		if( pos != null && pos.length > 0 )
			d.shipPos = switch( pos[0] ) {
				case 1: PInSystem(pos[1]);
				case 2: PPlanet(pos[1]);
				default: PInSector(pos[1], pos[2]);
			};
		// la nave estaba en un sistema que ya no esta: queda en el sector, donde estaba ese sistema
		for( s in removed ) {
			var inside = switch( d.shipPos ) {
				case PInSystem(id): id == s.id;
				case PPlanet(id): Lambda.exists(s.planets, function(p) return p.id == id);
				default: false;
			};
			if( inside ) d.shipPos = PInSector(s.x, s.y);
		}
		return d;
	}

	public static function system( d : ExpInfos, id : Int ) : ExpSystem {
		for( s in d.systems ) if( s.id == id ) return s;
		return null;
	}

	/** el planeta id y su sistema (null si no esta en el sector) */
	public static function planet( d : ExpInfos, id : Int ) : { p : ExpPlanet, s : ExpSystem } {
		for( s in d.systems )
			for( p in s.planets )
				if( p.id == id ) return { p : p, s : s };
		return null;
	}

	/**
	 * Anadido del port (Licenses): el sistema oldId desaparece porque se abandonaron todos sus planetas y aparece el newId, con
	 * planetas nuevos, a entre 3 y 5 casillas, en un sitio del sector a 3 o mas de los demas sistemas (si no hay ninguno, en
	 * el mismo). Devuelve el nuevo, o null si oldId no estaba.
	 */
	public static function replaceSystem( d : ExpInfos, oldId : Int, newId : Int ) : ExpSystem {
		var old = system(d, oldId);
		if( old == null ) return null;
		d.systems.remove(old);
		var free = [];
		for( dy in -5...6 )
			for( dx in -5...6 ) {
				var x = old.x + dx, y = old.y + dy, dd = dx * dx + dy * dy;
				if( dd < 9 || dd > 25 || x < 2 || y < 2 || x > d.sector.width - 3 || y > d.sector.height - 3 ) continue;
				if( !Lambda.exists(d.systems, function(o) return (o.x - x) * (o.x - x) + (o.y - y) * (o.y - y) < 9) ) free.push({ x : x, y : y });
			}
		var at = free.length > 0 ? free[new mt.Rand(d.sector.seed + newId * 97).random(free.length)] : { x : old.x, y : old.y };
		var s = generateSystem(newId, d.sector.seed + newId);
		s.x = at.x;
		s.y = at.y;
		d.systems.push(s);
		return s;
	}
}
