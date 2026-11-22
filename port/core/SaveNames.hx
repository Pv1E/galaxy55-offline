import Common;
import SaveData.SaveInfo;

/**
 * Nombres de bloques y de cargas en las partidas guardadas (anadido del port). En memoria la partida sigue con los numeros de
 * Block.all; en el archivo (SaveArchive) cada bloque va por su nombre: el constructor de BlockKind, o "editor:<archivo>#<variante>"
 * para un kube del editor de kubes. Asi una partida no depende del orden de BlockKind (que sigue siendo "anadir al final" para el
 * codigo: Block.hx, los modelos del generador y DEFAULT_SHIP).
 * - Un nombre que esta version no conoce (de una version con mas bloques) y un kube del editor que no esta cargado pasan a un
 *   bloque de remplazo: uno mas al final de Block.all (como los de KubeCore), con el aspecto de BKubeMystery. Se vuelve a
 *   escribir con su nombre: no se pierde nada aunque se juegue y se guarde.
 * - Las partidas de antes (.json) llevan numeros: se leen con la tabla de su linea (UPSTREAM o FORK, ver legacyTable).
 */
class SaveNames {

	/** prefijo de los kubes del editor: "editor:<archivo>#<variante>" */
	public static inline var EDITOR = "editor:";

	/**
	 * Los kubes del editor cargados (EditorKubes, que es del juego: el servidor y las pruebas de red usan SaveNames sin el): el
	 * archivo de un bloque, su variante y el bloque de un archivo. Lo pone EditorKubes antes de cargar el primero; mientras es null
	 * no hay ninguno (sus nombres van a bloques de remplazo)
	 */
	public static var editorKubes : { idOfBlock : Block -> String, variantOf : Block -> Int, blockOrFirst : String -> Int -> Block };

	/** bloques de remplazo de esta sesion: nombre -> bloque (siempre el mismo para el mismo nombre) */
	static var placeholders = new Map<String, Block>();
	/** y al reves: indice en Block.all -> nombre */
	static var placeholderNames = new Map<Int, String>();

	/** nombre de un bloque para guardarlo */
	public static function nameOf( b : Block ) : String {
		if( b == null ) return "BEmpty";
		var p = placeholderNames.get(b.index);
		if( p != null ) return p;
		var id = editorKubes == null ? null : editorKubes.idOfBlock(b);
		if( id != null ) return EDITOR + id + "#" + editorKubes.variantOf(b);
		return Type.enumConstructor(b.k);
	}

	/** nombre del bloque global gi (indice de Block.all; 0 = aire) */
	public static inline function nameOfIndex( gi : Int ) : String return nameOf(Block.all[gi]);

	/**
	 * El bloque de un nombre guardado: el de BlockKind, el kube del editor si esta cargado (si su forma ya no tiene esa variante,
	 * la 0: EditorKubes.block) o, si no, uno de remplazo
	 */
	public static function resolve( name : String ) : Block {
		if( name == null || name == "" ) throw "nombre de bloque vacio";
		var p = placeholders.get(name);
		if( StringTools.startsWith(name, EDITOR) ) {
			var e = parseEditor(name);
			var b = e == null || editorKubes == null ? null : editorKubes.blockOrFirst(e.id, e.variant);
			if( b != null ) return b;
		} else if( p == null ) {
			var k = try Type.createEnum(BlockKind, name) catch( e : Dynamic ) null;
			if( k != null ) return Block.get(k);
		}
		return p != null ? p : placeholder(name);
	}

	/** "editor:<archivo>#<variante>" -> archivo (en minusculas) y variante; null si no tiene esa forma (o no hay nombre) */
	public static function parseEditor( name : String ) : { id : String, variant : Int } {
		if( name == null || !StringTools.startsWith(name, EDITOR) ) return null;
		var s = name.substr(EDITOR.length), h = s.lastIndexOf("#");
		if( h <= 0 ) return null;
		var v = Std.parseInt(s.substr(h + 1));
		return v == null || v < 0 ? null : { id : s.substr(0, h).toLowerCase(), variant : v };
	}

	/** el bloque de remplazo de un nombre: como BKubeMystery, con el nombre que tenia (getName) */
	static function placeholder( name : String ) : Block {
		// multijugador: los bloques de los kubes del editor (KubeCore.blocksFor) tienen el mismo indice en el servidor y en cada
		// juego; se reservan todos antes del primer bloque de remplazo, que va detras (si no, los de un juego que ha leido una
		// partida con bloques desconocidos quedarian corridos)
		KubeCore.reserveAll();
		var src = Block.get(BKubeMystery);
		var b = new Block(BKubeMystery);
		b.index = Block.all.length;
		b.type = src.type;
		b.flags = src.flags.copy();
		b.special = src.special;
		b.tu = src.tu;
		b.td = src.td;
		b.tlr = src.tlr;
		b.props = src.props;
		b.model = src.model;
		b.size = src.size;
		b.weight = src.weight;
		b.matter = b;
		@:privateAccess b.name = name;
		Block.all.push(b);
		placeholders.set(name, b);
		placeholderNames.set(b.index, name);
		return b;
	}

	/** el bloque de remplazo de un nombre aunque se conozca (los kubes del editor en aventura: EditorKubes.attach) */
	public static function placeholderFor( name : String ) : Block {
		var p = placeholders.get(name);
		return p != null ? p : placeholder(name);
	}

	/** el bloque es de remplazo (su nombre no se conoce o es un kube del editor que no esta cargado) */
	public static function isPlaceholder( b : Block ) : Bool return b != null && placeholderNames.exists(b.index);

	/** nombre guardado de un bloque de remplazo (null si no lo es) */
	public static function placeholderName( b : Block ) : String return b == null ? null : placeholderNames.get(b.index);

	/** un bloque que esta version no conoce: de remplazo y no de un kube del editor (esos vuelven al cargar su archivo) */
	public static function isUnknown( b : Block ) : Bool {
		var n = placeholderName(b);
		return n != null && !StringTools.startsWith(n, EDITOR);
	}

	// ---------------------------------------------------------------- cargas

	/** nombre de una carga (indice de ChargeKind) para guardarla */
	public static function chargeName( c : Int ) : String {
		var all = Type.getEnumConstructs(ChargeKind);
		return c >= 0 && c < all.length ? all[c] : "#" + c;
	}

	/** indice de ChargeKind de un nombre guardado; -1 si esta version no lo conoce */
	public static function resolveCharge( name : String ) : Int {
		return Type.getEnumConstructs(ChargeKind).indexOf(name);
	}

	// ---------------------------------------------------------------- partidas de antes (numeros)

	/** cargas de las partidas de antes: el mismo orden en las dos lineas */
	public static var LEGACY_CHARGES = ["CYellow", "CBlue", "CPink", "CBonus"];

	/**
	 * BlockKind de upstream (Pv1E/galaxy55-offline) tal como estaba al dejar de guardar numeros: las partidas .json de esa linea
	 * llevan estos indices. No se cambia nunca.
	 */
	public static var UPSTREAM : Array<String> = [
		"BEmpty", "BBedrock", "BWater", "BSoil", "BSoilCover", "BRock", "BWood", "BGreenLeaves", "BYellowCrystalLight",
		"BAutumnHerbs1", "BAutumnHerbs2", "BPinkFlower", "BChampiLight", "BAutumnStraw", "BVines", "BVinesY", "BTreeHerbs",
		"BCactus", "BLamp", "BYellowCrystalDense", "BYellowCharge", "BBackPack", "BWoodPlank", "BBrokenRock", "BHardRock",
		"BMinAluminium", "BCactusBase", "BCactusFlower", "BBlueCrystalLight", "BBlueCrystalDense", "BBlueCharge", "BRockWall",
		"BWoodWindow", "BWoodWindowY", "BWoodPlate", "BVineColumn", "BRockWallSquare", "BTest", "BHardRockColumn", "BWoodColumn",
		"BHardRockWall", "BWoodScrew", "BLeavesCurtain", "BLeavesCurtainY", "BRawRed", "BShedWall", "BShedGround", "BShedLight",
		"BShipHull", "BShipEngine", "BShipGlass", "BShipDoor", "BShipDoorY", "BShipDoorOpen", "BShipDoorYOpen", "BShipPlate",
		"BShipWire", "BShipComputer", "BShipTubes", "BShipGlass2", "BShipEntry", "BCrafter", "BCrafterComputer", "BShipLight",
		"BShedGroundArrow", "BShedWallColumn", "BShedGlass", "BShedWallLight", "BAluminium", "BGlass", "BLight", "BPurpleLeaves",
		"BBrownLeaves", "BPinkLeaves", "BMoonSoil", "BMoonSoilCover", "BMoonRock", "BMoonSand", "BMoonLight", "BMoonLightDead",
		"BMoonLightColumn", "BDarkWater", "BMoonRockColumn", "BMoonBrokenRock", "BStainEmpty", "BStainPurple", "BStainRed", "BRaw",
		"BRawPurple", "BMoonHerbs1", "BMoonHerbs2", "BAcidWood", "BAcidWoodHole", "BAcidWoodBubble", "BAcidSoil", "BAcidSoilCover",
		"BAcidRock", "BAcidWater", "BAcidLeaves", "BAcidLeavesBubble", "BAcidLeaves2", "BAcidLeaves2Bubble", "BAcidMush",
		"BAcidFruit", "BAcidTreeSap", "BFreezer", "BIce", "BCascadeSource", "BCascadeFall", "BCascadeFall2", "BCascadeFall3",
		"BCascadeFall4", "BYellowPlant", "BBluePlant", "BWinterWater", "BWinterSoil", "BWinterSoilCover", "BWinterRock",
		"BWinterBrokenRock", "BWinterHidden", "BWinterFlowerDeleted", "BWinterLeaves", "BWinterLeavesCover", "BWinterHerb1",
		"BWinterHerb2", "BWinterHerb3", "BWinterWood", "BBlackIce", "BBlackIceLight", "BIceStalactite1", "BIceStalactite2",
		"BBlackLight", "BMarsSoil", "BMarsSoil2", "BMarsRock", "BMarsCraterRock", "BMarsBlueRock", "BMarsHardRock",
		"BMarsRockFossil", "BMarsQuickSand", "BMarsCactus", "BMarsCactusFossil", "BMarsCactusFlower", "BPinkCharge", "BMarsHerb1",
		"BMarsHerb2", "BMarsHerb3", "BAlienRock", "BArtiBomb", "BBigMushTrunk", "BBigMushHead", "BJumper", "BLava", "BLava2",
		"BLava3", "BLava4", "BLava5", "BLavaRock", "BChest", "BAlienTreasure", "BCamera", "BMush", "BCoral1", "BCoral2",
		"BFrozenRock", "BCoal", "BCoalHot", "BPlantSoil", "BHighHerb1", "BHighHerb2", "BHighHerb3", "BHighHerb4", "BHighHerb5",
		"BHighHerb6", "BFreezerPlant", "BMiningGenerator", "BStainWhite", "BRawWhite", "BStainOrange", "BRawOrange", "BStainGreen",
		"BRawGreen", "BMarsWall", "BWinterWall", "BAcidWall", "BPlantRock", "BAcidHerb1", "BAcidHerb2", "BAcidHerbCeil",
		"BHealPlant", "BYellowCeil", "BCavePlantCeil", "BBonusSmall", "BBonusMedium", "BBonusLarge", "BBonusCharge",
		"BBonusMediumRemain", "BBonusHerb1", "BBonusHerb2", "BMinIron", "BIron", "BIronFence", "BIronFenceY", "BIronLight",
		"BShipGlassBlack", "BShiningWoodPlank", "BHealBox", "BCircuit", "BDeadRock", "BDeadSoil", "BDeadSwamp", "BDeadTree",
		"BDarkLeaves", "BMotherHull", "BMotherPanel", "BMotherDark", "BMotherField", "BMotherYellow", "BMotherBlack", "BKubeFixed",
		"BKubeWater", "BKubeSoilTree", "BKubeSoilTree1", "BKubeSoilTree2", "BKubeAutumnTree", "BKubeAutumnTree1",
		"BKubeAutumnTree2", "BKubeHighTree", "BKubeHighTree1", "BKubeHighTree2", "BKubeHighTree3", "BKubeClouds", "BKubeClouds1",
		"BKubeClouds2", "BKubeSphereTree", "BKubeSphereTree1", "BKubeLargeTree", "BKubeLargeTree1", "BKubeLargeTree2",
		"BKubeSnowSapin", "BKubeSnowSapin1", "BKubeSnowSapin2", "BKubeJungle", "BKubeJungle1", "BKubeJungle2", "BKubeJungle3",
		"BKubeCaverns", "BKubeCaverns1", "BKubeCaverns2", "BKubeField", "BKubeField1", "BKubeField2", "BKubeSwamp", "BKubeSwamp1",
		"BKubeSwamp2", "BKubeSwamp3", "BKubeSoilPeaks", "BKubeSoilPeaks1", "BKubePilarPlain", "BKubePilarPlain1",
		"BKubePilarPlain2", "BKubeFlowerPlain", "BKubeFlowerPlain1", "BKubeFlowerPlain2", "BKubeFlowerPlain3", "BKubeSavana",
		"BKubeSavana1", "BKubeSavana2", "BKubeSavana3", "BKubeDesert", "BKubeDesert1", "BKubeFruit", "BKubeLava", "BKubeDolpart",
		"BKubeDolmen", "BKubeFlying", "BKubeFlying1", "BKubeFlying2", "BKubeKoala", "BKubeInvisible", "BKubeAmethyste",
		"BKubeEmeraude", "BKubeRubis", "BKubeSaphir", "BKubeFog", "BKubeShade", "BKubeLight", "BKubeGold", "BKubeMessage",
		"BKubeTeleport", "BKubeJump", "BKubeChest", "BKubeMulticol", "BKubeMtwin", "BKubeCrate", "BKubeNoel", "BRockColumn",
		"BHardRockWallSquare", "BAcidWallSquare", "BWinterWallSquare", "BKubeMystery", "BShipGlassRed", "BShipGlassBlue",
		"BShipGlassGreen", "BShipGlassPink", "BShopBarrier", "BKubeEditor", "BKubePaintingYellowFlowers",
		"BKubePaintingYellowFlowersTurn1", "BKubePaintingYellowFlowersTurn2", "BKubePaintingYellowFlowersTurn3",
		"BKubePaintingSculpture", "BKubePaintingSculptureTurn1", "BKubePaintingSculptureTurn2", "BKubePaintingSculptureTurn3",
		"BKubePaintingBush", "BKubePaintingBushTurn1", "BKubePaintingBushTurn2", "BKubePaintingBushTurn3",
		"BKubePaintingPottedPlant", "BKubePaintingPottedPlantTurn1", "BKubePaintingPottedPlantTurn2",
		"BKubePaintingPottedPlantTurn3", "BKubePaintingFlowerVase", "BKubePaintingFlowerVaseTurn1", "BKubePaintingFlowerVaseTurn2",
		"BKubePaintingFlowerVaseTurn3", "BKubePaintingFruitBasket", "BKubePaintingFruitBasketTurn1",
		"BKubePaintingFruitBasketTurn2", "BKubePaintingFruitBasketTurn3", "BKubePaintingHouse", "BKubePaintingHouseTurn1",
		"BKubePaintingHouseTurn2", "BKubePaintingHouseTurn3", "BKubePaintingBeach", "BKubePaintingBeachTurn1",
		"BKubePaintingBeachTurn2", "BKubePaintingBeachTurn3", "BKubePaintingPyramid", "BKubePaintingPyramidTurn1",
		"BKubePaintingPyramidTurn2", "BKubePaintingPyramidTurn3", "BKubePaintingAlley", "BKubePaintingAlleyTurn1",
		"BKubePaintingAlleyTurn2", "BKubePaintingAlleyTurn3", "BKubePaintingShipwreck", "BKubePaintingShipwreckTurn1",
		"BKubePaintingShipwreckTurn2", "BKubePaintingShipwreckTurn3", "BKubePaintingMeadow", "BKubePaintingMeadowTurn1",
		"BKubePaintingMeadowTurn2", "BKubePaintingMeadowTurn3", "BKubePaintingMoonlight", "BKubePaintingMoonlightTurn1",
		"BKubePaintingMoonlightTurn2", "BKubePaintingMoonlightTurn3", "BKubePortraitMan", "BKubePortraitManTurn1",
		"BKubePortraitManTurn2", "BKubePortraitManTurn3", "BKubePaintingTree", "BKubePaintingTreeTurn1", "BKubePaintingTreeTurn2",
		"BKubePaintingTreeTurn3", "BKubePortraitWoman", "BKubePortraitWomanTurn1", "BKubePortraitWomanTurn2",
		"BKubePortraitWomanTurn3"
	];

	/**
	 * BlockKind de la linea del fork (Cornor923/galaxy55-offline): la de upstream con dos bloques de Grey Haven metidos en 300 y
	 * 301 (d7d448e), antes de BKubeMystery. Ningun campo de las partidas .json distingue las dos lineas (savedWith dice "0.8.1" en
	 * las dos): por defecto se lee con la de este juego (lineage) y una orden de pruebas vuelve a migrar con la otra.
	 */
	public static var FORK : Array<String> = UPSTREAM.slice(0, 300).concat(["BKubeGreyHavenTreeTrunk", "BKubeGreyHavenSand"]).concat(UPSTREAM.slice(300));

	/** "upstream" o "fork": la linea de este juego (la tabla de la que BlockKind empieza igual) */
	public static function lineage() : String {
		var names = Type.getEnumConstructs(BlockKind);
		inline function prefix( t : Array<String> ) {
			var ok = names.length >= t.length;
			if( ok ) for( i in 0...t.length ) if( names[i] != t[i] ) { ok = false; break; }
			return ok;
		}
		return prefix(FORK) ? "fork" : "upstream";
	}

	/** la tabla de una linea ("upstream" o "fork") */
	public static function legacyTable( lineage : String ) : Array<String> return lineage == "fork" ? FORK : UPSTREAM;

	// ---------------------------------------------------------------- recorrer los bloques de una partida

	/**
	 * Cada numero de bloque de una partida (Block.all; 0 = aire): casillas del inventario, de las cantinas, del stockage y del
	 * equipo dejado, celdas cambiadas del planeta actual, de los visitados y de la nave, la nave del hangar (shipData), los bloques
	 * del tutorial y las claves "b<numero>" del robot comerciante. f(numero, donde) devuelve el numero nuevo (o el mismo);
	 * donde = "world", "ship" o "items" (como UnknownBlocks).
	 */
	public static function mapBlocks( info : SaveInfo, f : Int -> String -> Int ) {
		function slots( t : Protocol.BlockInventory ) {
			if( t == null ) return;
			for( s in t ) if( s != null ) s.k = f(s.k, "items");
		}
		function edits( e : Array<Int>, where : String ) {
			if( e == null ) return;
			var i = 0;
			while( i + 1 < e.length ) {
				if( e[i] >= 0 ) e[i + 1] = (e[i + 1] & ~0xFFFF) | f(e[i + 1] & 0xFFFF, where);
				i += 2;
			}
		}
		if( info.inv != null ) slots(info.inv.t);
		if( info.chests != null ) for( c in info.chests ) slots(c.t);
		if( info.storage != null ) slots(info.storage.t);
		if( info.deathDrops != null ) for( d in info.deathDrops ) slots(d.t);
		edits(info.edits, "world");
		if( info.uni != null && info.uni.planets != null ) for( p in info.uni.planets ) edits(p.edits, "world");
		edits(info.shipEdits, "ship");
		if( info.tuto != null && info.tuto.spots != null ) {
			var s = info.tuto.spots, i = 3;
			while( i < s.length ) {
				s[i] = f(s[i], "world");
				i += 4;
			}
		}
		if( info.market != null && info.market.items != null )
			for( it in info.market.items )
				if( it.key != null && it.key.charAt(0) == "b" ) {
					var id = Std.parseInt(it.key.substr(1));
					if( id != null ) it.key = "b" + f(id, "items");
				}
		if( info.shipData != null ) info.shipData = mapShipData(info.shipData, function(id) return f(id, "ship"));
	}

	/** la nave del hangar (ShipData: zlib en base64 de sx, sy, sz y 2 bytes por celda) con otros numeros de bloque */
	public static function mapShipData( data : String, f : Int -> Int ) : String {
		var raw = try haxe.zip.Uncompress.run(haxe.crypto.Base64.decode(data)) catch( e : Dynamic ) null;
		if( raw == null ) return data;
		var cells = raw.get(0) * raw.get(1) * raw.get(2), changed = false;
		for( i in 0...cells ) {
			var p = 3 + i * 2;
			if( p + 1 >= raw.length ) break;
			var id = raw.get(p) | (raw.get(p + 1) << 8);
			if( id == 0 ) continue;
			var n = f(id);
			if( n == id ) continue;
			raw.set(p, n & 0xFF);
			raw.set(p + 1, n >> 8);
			changed = true;
		}
		return changed ? haxe.crypto.Base64.encode(haxe.zip.Compress.run(raw, 9)) : data;
	}
}
