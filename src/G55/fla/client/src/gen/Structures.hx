package gen;

/** etapa en la que se pone una estructura (DetailsGenerator): el orden de las etapas es fijo (Generator.startGenerate) */
enum StructureStage {
	/** en fillSoil, antes de llenar el suelo: cambian las alturas */
	Relief;
	/** en las grutas (Otono, Invierno y Marte: las celdas CAVE de Generator.saveCaveMask) */
	Cave;
	/** sobre el suelo */
	Surface;
	/** al final, por encima de todo (la anomalia Invisible) */
	Air;
}

/**
 * Una estructura del registro. id: su nombre (de el sale su azar: Generator.stream); group: su tipo de anomalia en kubindex.json
 * (Base de datos ESCorp; null en los relieves, que no lo son); p: ~1 region de 128x128 de cada p la tiene; biomes: nombres de
 * BiomeKind (null = todos los de planeta: PLANET_BIOMES; nunca el hangar, el bioma de prueba ni las cometas); since / until:
 * primera version del generador que la tiene / que ya no (Generator.VERSION; null = desde la 1 / sin fin); f: la pone en x, y, z
 * (z: el suelo, la gruta o nada) y dice si ha podido.
 */
typedef StructureDef = {
	var id : String;
	var group : String;
	var stage : StructureStage;
	var p : Int;
	var biomes : Array<String>;
	/** biomas en los que nunca cabe (sus propias condiciones no se cumplen alli: GenMain --allstructures); no se tira */
	var ?notIn : Array<String>;
	var since : Null<Int>;
	var until : Null<Int>;
	var f : DetailsGenerator -> Int -> Int -> Int -> Bool;
	/**
	 * su tipo de anomalia cuando sale con lava en vez de agua (las cascadas tiran una u otra: DetailsGenerator.poseLava). Solo
	 * cambia el nombre, no el mundo: se puede anadir a una estructura de una version que ya ha salido
	 */
	var ?lavaGroup : String;
}

/**
 * Anadido del port (generador version 1): todas las estructuras de los planetas en un solo sitio (antes cuatro mecanismos: los
 * relieves de addHeightDetails, las grutas de addCaveDetails, la superficie de addDetails y la Invisible aparte). Cada region de
 * 128x128 tira cada estructura de su etapa con su propio azar (DetailsGenerator.placeStage): anadir una solo cambia las regiones
 * en las que sale, y el planeta solo dentro de su caja.
 * Reglas: no se cambia ni se quita una estructura de una version que ya ha salido; para retocarla, una nueva con since y la vieja
 * con until (los ids no se repiten).
 */
@:access(gen.DetailsGenerator)
class Structures {

	/**
	 * los planetas de verdad: solo ellos tienen estructuras y cristales de hexalita (bonus, DetailsGenerator.hasStructures). El
	 * hangar (BIShed) no es un planeta (se construye con shipData), ni el bioma de prueba (BITest) ni las cometas (CometGenerator)
	 */
	public static var PLANET_BIOMES = ["BIAutumn", "BIMoon", "BIMars", "BIWinterPeaks", "BIAcidForest", "BIDeadCity"];

	/** biomas con grutas (los que guardan las celdas CAVE: saveCaveMask) */
	static var CAVE_BIOMES = ["BIAutumn", "BIWinterPeaks", "BIMars"];

	public static var ALL : Array<StructureDef> = [
		// relieves (p de addHeightDetails)
		def("hole", null, Relief, 50, (g, x, y, z) -> g.hdetHole(x, y)),
		def("pilars", null, Relief, 20, (g, x, y, z) -> g.hdetPilars(x, y)),
		def("plateau", null, Relief, 10, (g, x, y, z) -> g.hdetPlateau(x, y)),
		def("noise", null, Relief, 7, (g, x, y, z) -> g.hdetNoise(x, y)),
		def("pilarfield", null, Relief, 10, (g, x, y, z) -> g.hdetPilarField(x, y)),
		// grutas (addCaveDetails)
		def("cavefield", "cavegarden", Cave, 3, (g, x, y, z) -> g.detCaveField(x, y, z), CAVE_BIOMES),
		def("caveceilplant", "cavegarden", Cave, 3, (g, x, y, z) -> g.detCaveCeilPlant(x, y, z), CAVE_BIOMES),
		def("cavesphere", "cavesphere", Cave, 15, (g, x, y, z) -> g.detCaveSphere(x, y, z), CAVE_BIOMES),
		def("cavebuilding", "caveruins", Cave, 15, (g, x, y, z) -> g.detCaveBuilding(x, y, z), CAVE_BIOMES),
		def("cavecascade", "cavecascade", Cave, 1, (g, x, y, z) -> g.detCaveCascade(x, y, z), CAVE_BIOMES, null, null, null, "cavelava"),
		def("caveceilcascade", "cavecascade", Cave, 1, (g, x, y, z) -> g.detCaveCeilCascade(x, y, z), CAVE_BIOMES, null, null, null, "cavelava"),
		def("cavematerial", "caveveins", Cave, 3, (g, x, y, z) -> g.detCaveMaterial(x, y, z), CAVE_BIOMES),
		def("cavefrozen", "cavefrozen", Cave, 6, (g, x, y, z) -> g.detCaveFrozen(x, y, z), CAVE_BIOMES),
		def("cavetoxic", "cavegarden", Cave, 4, (g, x, y, z) -> g.detCaveToxicPlants(x, y, z), CAVE_BIOMES),
		def("caveceilcharges", "cavecharges", Cave, 3, (g, x, y, z) -> g.detCaveCeilCharges(x, y, z), CAVE_BIOMES),
		def("cavewall", "caveveins", Cave, 2, (g, x, y, z) -> g.detCaveWallDetails(x, y, z), CAVE_BIOMES),
		def("caveheal", "cavegarden", Cave, 5, (g, x, y, z) -> g.detCaveHeal(x, y, z), CAVE_BIOMES),
		// superficie (addDetails)
		def("bigcrater", "bigcrater", Surface, 100, (g, x, y, z) -> g.detBigCrater(x, y, z)),
		def("crater", "crater", Surface, 10, (g, x, y, z) -> g.detSmallCrater(x, y, z)),
		def("pillars", "pillars", Surface, 200, (g, x, y, z) -> g.detStrangePilars(x, y, z)),
		def("highbuilding", "ruins", Surface, 40, (g, x, y, z) -> g.detHighBuilding(x, y, z), null, null, null, ["BIAcidForest", "BIDeadCity"]),
		def("groundbuilding", "ruins", Surface, 60, (g, x, y, z) -> g.detGroundBuilding(x, y, z)),
		def("artifact", "artifact", Surface, 20, (g, x, y, z) -> g.detGroundArtifact(x, y, z), null, null, null, ["BIDeadCity"]),
		def("fence", "fence", Surface, 15, (g, x, y, z) -> g.detFence(x, y, z)),
		def("capsule", "capsule", Surface, 250, (g, x, y, z) -> g.detCapsule(x, y, z)),
		def("bigmush", "bigmush", Surface, 50, (g, x, y, z) -> g.detBigChampi(x, y, z)),
		def("volcano", "volcano", Surface, 15, (g, x, y, z) -> g.detVolcano(x, y, z)),
		def("robot", "robot", Surface, 130, (g, x, y, z) -> g.detAlienRobot(x, y, z)),
		def("pyramid", "pyramid", Surface, 100, (g, x, y, z) -> g.detPyramid(x, y, z)),
		def("tree", "tree", Surface, 6, (g, x, y, z) -> g.detTree(x, y, z)),
		def("grove", "grove", Surface, 30, (g, x, y, z) -> g.detForest(x, y, z)),
		def("ice", "ice", Surface, 40, (g, x, y, z) -> g.detIce(x, y, z)),
		def("burned", "burned", Surface, 6, (g, x, y, z) -> g.detBurned(x, y, z)),
		def("meadow", "meadow", Surface, 8, (g, x, y, z) -> g.detField(x, y, z)),
		def("largepit", "largepit", Surface, 50, (g, x, y, z) -> g.detLargePit(x, y, z)),
		def("pit", "pit", Surface, 20, (g, x, y, z) -> g.detSmallPit(x, y, z)),
		def("ruin", "ruins", Surface, 50, (g, x, y, z) -> g.detRuin(x, y, z)),
		def("cascade", "cascade", Surface, 7, (g, x, y, z) -> g.detCascade(x, y, z), null, null, null, ["BIDeadCity"], "lavafall"),
		def("heal", "heal", Surface, 5, (g, x, y, z) -> g.detHeal(x, y, z)),
		// aire (la anomalia Invisible: ~1 planeta normal de cada 8, flotando sobre lo mas alto de debajo)
		def("invisible", "invisible", Air, 8, (g, x, y, z) -> g.detInvisible(x, y) >= 0),
	];

	static function def( id : String, group : String, stage : StructureStage, p : Int, f : DetailsGenerator -> Int -> Int -> Int -> Bool,
		?biomes : Array<String>, ?since : Int, ?until : Int, ?notIn : Array<String>, ?lavaGroup : String ) : StructureDef {
		return { id : id, group : group, stage : stage, p : p, biomes : biomes, notIn : notIn, since : since, until : until, f : f,
			lavaGroup : lavaGroup };
	}

	/** un planeta de verdad (PLANET_BIOMES): con estructuras y cristales de hexalita (bonus) */
	public static inline function isPlanet( biome : String ) : Bool return PLANET_BIOMES.indexOf(biome) >= 0;

	/**
	 * Las estructuras de una etapa en un bioma y una version, de la mas rara a la mas comun (p de mayor a menor) y luego por id:
	 * el orden en el que se tiran en cada region. only: solo esa (GenMain --allstructures)
	 */
	public static function active( biome : String, stage : StructureStage, version : Int, ?only : String ) : Array<StructureDef> {
		var out = [];
		for( e in ALL ) {
			if( e.stage != stage || (only != null && e.id != only) ) continue;
			if( (e.since != null && version < e.since) || (e.until != null && version >= e.until) ) continue;
			if( !isPlanet(biome) || (e.biomes != null && e.biomes.indexOf(biome) < 0) ) continue;
			if( e.notIn != null && e.notIn.indexOf(biome) >= 0 ) continue;
			out.push(e);
		}
		out.sort(function(a, b) return a.p != b.p ? b.p - a.p : (a.id < b.id ? -1 : (a.id > b.id ? 1 : 0)));
		return out;
	}

	/** la estructura de un id (null si no hay) */
	public static function get( id : String ) : StructureDef {
		for( e in ALL ) if( e.id == id ) return e;
		return null;
	}
}
