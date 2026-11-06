import Common;

/**
 * Nombres de los bloques en los tres idiomas (anadido del port). Las tablas del original (NamesGen) solo estaban bien en
 * espanol: la inglesa tiene la mitad en frances, "TODO" y huecos, y a la francesa le faltan 60. Aqui:
 * - frances: el nombre de DataGen (el juego era frances: son los nombres oficiales)
 * - ingles: los oficiales de NamesGen.EN que estaban bien y el resto traducido
 * - espanol: NamesGen.ES y los bloques que se anadieron despues
 * Las variantes sin nombre propio (nevadas, giradas, abiertas...) llevan el de su bloque base (ver base()); los bloques
 * internos (cascadas...) siguen sin nombre ("-"), como en el original. Las hierbas de decoracion se recogen (PortRules) y
 * tienen nombre.
 */
class BlockNames {

	static var EN : Map<String, String> = [
		// plantas, rocas y cristal con carga: sin nombre en ningun idioma del original
		"BYellowPlant" => "Citronox Plant", "BBluePlant" => "Etherium Plant", "BYellowCeil" => "Citronox Stalactite",
		"BMarsBlueRock" => "Etherium Meteorite", "BMarsCactusFlower" => "Flowering Twister", "BPinkCharge" => "Pink Charge",
		// monticulo de nieve con una planta de citronox dentro: el nombre de la nieve, para no desvelarla
		"BWinterHidden" => "Frozen Earth",
		// hierbas de decoracion: sin nombre en el original (no se recogian); aqui se recogen (PortRules)
		"BAutumnHerbs1" => "Red Grass", "BAutumnHerbs2" => "Tall Red Grass", "BTreeHerbs" => "Hanging Moss",
		"BMoonHerbs1" => "Moon Sprout", "BMoonHerbs2" => "Small Moon Sprout", "BWinterHerb1" => "Frosted Grass",
		"BWinterHerb2" => "Short Frosted Grass", "BWinterHerb3" => "Low Frosted Grass", "BMarsHerb1" => "Low Sand Grass",
		"BMarsHerb2" => "Short Sand Grass", "BMarsHerb3" => "Sand Grass",
		"BBedrock" => "Bedrock", "BWater" => "Water", "BSoil" => "Red Earth", "BSoilCover" => "Red Earth", "BRock" => "Rock",
		"BWood" => "Wood", "BGreenLeaves" => "Green Leaves", "BYellowCrystalLight" => "Old Citronox", "BPinkFlower" => "Wood Rose",
		"BChampiLight" => "Mushlite", "BAutumnStraw" => "Stellar Straw", "BVines" => "Creeping Vines", "BCactus" => "Cactus",
		"BLamp" => "Lantern", "BYellowCrystalDense" => "Citronox", "BYellowCharge" => "Citronox Charge", "BWoodPlank" => "Plank",
		"BHardRock" => "HardRoq", "BMinAluminium" => "Bauxite", "BCactusBase" => "Cactus Root", "BCactusFlower" => "Cactus Flower",
		"BBlueCrystalLight" => "Blue Etherium Fragments", "BBlueCrystalDense" => "Blue Etherium", "BBlueCharge" => "Etherium Charge",
		"BRockWall" => "Rock Wall", "BWoodWindow" => "Window Frame", "BWoodPlate" => "Wood Plating", "BVineColumn" => "Vine Column",
		"BRockWallSquare" => "Rock Tiles", "BTest" => "Test", "BHardRockColumn" => "HardRoq Column", "BWoodColumn" => "Wooden Column",
		"BHardRockWall" => "HardRoq Wall", "BWoodScrew" => "Wooden Bolt", "BLeavesCurtain" => "Leaf Curtain",
		"BRawRed" => "Red Aggregate", "BShipHull" => "Hull Plating", "BShipEngine" => "Space Engine", "BShipGlass" => "Toughened Glass",
		"BShipDoor" => "Armoured Door", "BShipPlate" => "Armour Plate", "BShipWire" => "Ribbed Plating", "BShipComputer" => "Ship's Computer",
		"BShipTubes" => "Armoured Pipes", "BShipGlass2" => "Armoured HUD", "BShipEntry" => "Teleporter", "BCrafter" => "Crafting Panel",
		"BCrafterComputer" => "Synthesizer", "BShipLight" => "Neon Lights", "BAluminium" => "Aluminium", "BGlass" => "Basic Glass",
		"BLight" => "Lumine", "BPurpleLeaves" => "Purple Leaves", "BBrownLeaves" => "Brown Leaves", "BPinkLeaves" => "Pink Leaves",
		"BMoonSoil" => "Violet Earth", "BMoonSoilCover" => "Violet Earth", "BMoonRock" => "Moon Rock", "BMoonSand" => "Moon Dust",
		"BMoonLight" => "Lumen Rock", "BMoonLightDead" => "Dead Lumen Rock", "BMoonLightColumn" => "Lumen Rock Trunk",
		"BMoonRockColumn" => "Moon Rock Column", "BMoonBrokenRock" => "Moon Rock", "BStainEmpty" => "Dead Stainshroom",
		"BStainPurple" => "Purple Stainshroom", "BStainRed" => "Red Stainshroom", "BRaw" => "Undyed Aggregate", "BRawPurple" => "Purple Aggregate",
		"BAcidWood" => "Grozarb Wood", "BAcidWoodHole" => "Hollow Grozarb Wood", "BAcidWoodBubble" => "Grozarb Eye", "BAcidSoil" => "Bubblemud",
		"BAcidRock" => "Soft Rock", "BAcidWater" => "Acid Water", "BAcidLeaves" => "Foliage", "BAcidLeavesBubble" => "Fruity Foliage",
		"BAcidLeaves2" => "Poitevine Leaf", "BAcidLeaves2Bubble" => "Fruity Poitevine Leaf", "BAcidMush" => "Swamp Noodle",
		"BAcidFruit" => "Grozarb Fruit", "BAcidTreeSap" => "Grozarb Sap", "BFreezer" => "Solid Nitrogen", "BIce" => "Ice",
		"BCascadeSource" => "Waterfall Source", "BWinterSoil" => "Frozen Earth", "BWinterRock" => "Frost Rock", "BWinterLeaves" => "Fir Tuft",
		"BWinterWood" => "Frost Wood", "BBlackIce" => "Black Ice", "BBlackIceLight" => "Black Heart", "BBlackLight" => "Black Light",
		"BMarsSoil" => "Sand Classicus", "BMarsSoil2" => "Sand Cobbles", "BMarsRock" => "Scaly Rock", "BMarsCraterRock" => "Meteorite Bed",
		"BMarsHardRock" => "Roundrock", "BMarsRockFossil" => "Fossil", "BMarsQuickSand" => "Quicksand", "BMarsCactus" => "Wild Twister",
		"BMarsCactusFossil" => "Fossil", "BAlienRock" => "Ancient Rock", "BArtiBomb" => "Ancient Bomb", "BBigMushTrunk" => "Bigshroom Trunk",
		"BBigMushHead" => "Bigshroom Cap", "BJumper" => "Temporary Gravity Inverter", "BLava" => "Lava", "BLavaRock" => "Basalt",
		"BChest" => "ESCorp Canteen", "BAlienTreasure" => "Ancient Chest", "BCamera" => "Camera", "BMush" => "Mushroom",
		"BCoral1" => "Gold Coral", "BCoral2" => "Jade Coral", "BFrozenRock" => "Frozen Rock", "BCoal" => "Charred Debris",
		"BCoalHot" => "Glowing Debris", "BPlantSoil" => "Fertile Soil", "BHighHerb1" => "Tall Grass", "BHighHerb2" => "Young Tall Grass",
		"BHighHerb3" => "Mauve Sbeleleb", "BHighHerb4" => "Young Mauve Sbeleleb", "BHighHerb5" => "Blue Sbeleleb", "BHighHerb6" => "Young Blue Sbeleleb",
		"BFreezerPlant" => "Nitrogen Pellets", "BMiningGenerator" => "Mining Turbo", "BStainWhite" => "Icy Stainshroom",
		"BRawWhite" => "White Aggregate", "BStainOrange" => "Orange Stainshroom", "BRawOrange" => "Orange Aggregate",
		"BStainGreen" => "Green Stainshroom", "BRawGreen" => "Green Aggregate", "BMarsWall" => "Brick Wall", "BWinterWall" => "Frost Wall",
		"BAcidWall" => "Soft Rock Wall", "BPlantRock" => "Imprisoned Rock", "BAcidHerb1" => "Stinging Dryad", "BAcidHerb2" => "Young Stinging Dryad",
		"BAcidHerbCeil" => "Underground Dryad", "BHealPlant" => "Wild Calendula", "BCavePlantCeil" => "Hangvine", "BMinIron" => "Pyrite",
		// cristales verdes y su carga: sin nombre en ningun idioma del original
		"BBonusSmall" => "Small Bonus Crystal", "BBonusMedium" => "Bonus Crystal", "BBonusLarge" => "Large Bonus Crystal", "BBonusCharge" => "Bonus Charge",
		"BIron" => "Iron", "BIronFence" => "Wire Mesh", "BIronLight" => "Miner's Lantern", "BShipGlassBlack" => "Tinted Toughened Glass",
		"BShiningWoodPlank" => "Starry Plank", "BHealBox" => "Boxed Calendula", "BCircuit" => "Circuit Block",
		"BDeadRock" => "Dead Rock", "BDeadSoil" => "Dead Soil", "BDeadSwamp" => "Dead Swamp", "BDeadTree" => "Dead Tree", "BDarkLeaves" => "Dark Leaves",
		"BMotherHull" => "Mothership Hull", "BMotherPanel" => "Mothership Panel", "BMotherDark" => "Dark Mothership Hull",
		"BMotherField" => "Hangar Force Field", "BMotherYellow" => "Yellow Plating", "BMotherBlack" => "Black Plating",
		// kubes de Kube (Motion Twin, 2010): los que se llamarian igual que un bloque de Galaxy 55 (Water, Lava, Cactus, Rock, Pink
		// Leaves, Dark Leaves) cambian de nombre para no confundirse con el
		"BKubeFixed" => "Concrete", "BKubeWater" => "Kube Water", "BKubeSoilTree" => "Brown Earth", "BKubeSoilTree1" => "Birch Wood",
		"BKubeSoilTree2" => "Birch Leaves", "BKubeAutumnTree" => "Autumn Earth", "BKubeAutumnTree1" => "Autumn Wood",
		"BKubeAutumnTree2" => "Autumn Leaves", "BKubeHighTree" => "Dark Earth", "BKubeHighTree1" => "Dark Wood",
		"BKubeHighTree2" => "Gloomy Leaves", "BKubeHighTree3" => "Dark Grass", "BKubeClouds" => "Blue Earth", "BKubeClouds1" => "Cloud Heart",
		"BKubeClouds2" => "Cloud", "BKubeSphereTree" => "Light Wood", "BKubeSphereTree1" => "Rosy Leaves", "BKubeLargeTree" => "Roots",
		"BKubeLargeTree1" => "Giant Wood", "BKubeLargeTree2" => "Giant Leaves", "BKubeSnowSapin" => "Snowy Earth",
		"BKubeSnowSapin1" => "Fir Wood", "BKubeSnowSapin2" => "Snowy Leaves", "BKubeJungle" => "Jungle", "BKubeJungle1" => "Dark Vines",
		"BKubeJungle2" => "Light Vines", "BKubeJungle3" => "Rotten Vines", "BKubeCaverns" => "Wall", "BKubeCaverns1" => "Boulder",
		"BKubeCaverns2" => "Pillar", "BKubeField" => "Meadow", "BKubeField1" => "Light Grass", "BKubeField2" => "Grass", "BKubeSwamp" => "Swamp",
		"BKubeSwamp1" => "Swamp Wood", "BKubeSwamp2" => "Swamp Leaves", "BKubeSwamp3" => "Mud", "BKubeSoilPeaks" => "Cold Rock",
		"BKubeSoilPeaks1" => "Volcanic Rock", "BKubePilarPlain" => "Ashes", "BKubePilarPlain1" => "Sandstone",
		"BKubePilarPlain2" => "Ancient Totem", "BKubeFlowerPlain" => "Pasture", "BKubeFlowerPlain1" => "White Flower",
		"BKubeFlowerPlain2" => "Pink Flower", "BKubeFlowerPlain3" => "Stonehenge", "BKubeSavana" => "Savanna", "BKubeSavana1" => "Dry Shrub",
		"BKubeSavana2" => "Zebra", "BKubeSavana3" => "Elephant", "BKubeDesert" => "Sand", "BKubeDesert1" => "Kube Cactus",
		"BKubeFruit" => "Acorn", "BKubeLava" => "Kube Lava", "BKubeDolpart" => "Gloom", "BKubeDolmen" => "Dolmen", "BKubeFlying" => "Meka",
		"BKubeFlying1" => "Metal", "BKubeFlying2" => "Steel", "BKubeKoala" => "Koala", "BKubeInvisible" => "Invisible",
		"BKubeAmethyste" => "Amethyst", "BKubeEmeraude" => "Emerald", "BKubeRubis" => "Ruby", "BKubeSaphir" => "Sapphire", "BKubeFog" => "Fog",
		"BKubeShade" => "Shade", "BKubeLight" => "Light", "BKubeGold" => "Gold", "BKubeMessage" => "Forum", "BKubeTeleport" => "Teleport",
		"BKubeJump" => "Spring", "BKubeChest" => "Chest", "BKubeMulticol" => "Rubix", "BKubeMtwin" => "Motion Twin", "BKubeCrate" => "Crate",
		"BKubeNoel" => "Christmas Kube",
	];

	/** espanol: lo que falta en NamesGen.ES (bloques anadidos despues) y alguna correccion */
	static var ES : Map<String, String> = [
		"BYellowPlant" => "Planta de citronox", "BBluePlant" => "Planta de eterium", "BYellowCeil" => "Estalactita de citronox",
		"BMarsBlueRock" => "Meteorito de eterium", "BMarsCactusFlower" => "Cactus salvaje florido", "BPinkCharge" => "Carga rosa",
		"BWinterHidden" => "Tierra glacial",
		"BWinterFlowerDeleted" => "-",
		"BAutumnHerbs1" => "Hierba roja", "BAutumnHerbs2" => "Hierba roja alta", "BTreeHerbs" => "Musgo colgante",
		"BMoonHerbs1" => "Brote lunar", "BMoonHerbs2" => "Brote lunar pequeño", "BWinterHerb1" => "Hierba escarchada",
		"BWinterHerb2" => "Hierba escarchada corta", "BWinterHerb3" => "Hierba escarchada rasa", "BMarsHerb1" => "Hierba de arena rasa",
		"BMarsHerb2" => "Hierba de arena corta", "BMarsHerb3" => "Hierba de arena",
		"BBonusSmall" => "Cristal de bonus pequeño", "BBonusMedium" => "Cristal de bonus", "BBonusLarge" => "Cristal de bonus grande", "BBonusCharge" => "Carga de bonus",
		"BDeadRock" => "Roca muerta", "BDeadSoil" => "Tierra muerta", "BDeadSwamp" => "Pantano muerto", "BDeadTree" => "Árbol muerto",
		"BDarkLeaves" => "Hojas oscuras",
		"BMotherHull" => "Blindaje de la nodriza", "BMotherPanel" => "Panel de la nodriza", "BMotherDark" => "Blindaje oscuro de la nodriza",
		"BMotherField" => "Campo de fuerza del hangar", "BMotherYellow" => "Blindaje amarillo", "BMotherBlack" => "Blindaje negro",
		// kubes de Kube (Motion Twin, 2010): Agua, Lava, Cactus y Hojas oscuras cambian de nombre, si no compartirian ficha en el
		// Kubindex con los de Galaxy 55 (entry junta los que se llaman igual en espanol)
		"BKubeFixed" => "Hormigón", "BKubeWater" => "Agua de Kube", "BKubeSoilTree" => "Tierra parda", "BKubeSoilTree1" => "Madera de abedul",
		"BKubeSoilTree2" => "Hojas de abedul", "BKubeAutumnTree" => "Tierra otoñal", "BKubeAutumnTree1" => "Madera otoñal",
		"BKubeAutumnTree2" => "Hojas otoñales", "BKubeHighTree" => "Tierra oscura", "BKubeHighTree1" => "Madera oscura",
		"BKubeHighTree2" => "Hojas sombrías", "BKubeHighTree3" => "Hierba oscura", "BKubeClouds" => "Tierra azul",
		"BKubeClouds1" => "Corazón de nube", "BKubeClouds2" => "Nube", "BKubeSphereTree" => "Madera clara", "BKubeSphereTree1" => "Hojas rosas",
		"BKubeLargeTree" => "Raíces", "BKubeLargeTree1" => "Madera gigante", "BKubeLargeTree2" => "Hojas gigantes",
		"BKubeSnowSapin" => "Tierra nevada", "BKubeSnowSapin1" => "Madera de abeto", "BKubeSnowSapin2" => "Hojas nevadas",
		"BKubeJungle" => "Jungla", "BKubeJungle1" => "Lianas oscuras", "BKubeJungle2" => "Lianas claras", "BKubeJungle3" => "Lianas podridas",
		"BKubeCaverns" => "Muro", "BKubeCaverns1" => "Peñasco", "BKubeCaverns2" => "Pilar", "BKubeField" => "Pradera",
		"BKubeField1" => "Hierba clara", "BKubeField2" => "Hierba", "BKubeSwamp" => "Pantano", "BKubeSwamp1" => "Madera de pantano",
		"BKubeSwamp2" => "Hojas de pantano", "BKubeSwamp3" => "Barro", "BKubeSoilPeaks" => "Roca fría", "BKubeSoilPeaks1" => "Roca volcánica",
		"BKubePilarPlain" => "Cenizas", "BKubePilarPlain1" => "Arenisca", "BKubePilarPlain2" => "Tótem antiguo", "BKubeFlowerPlain" => "Pastos",
		"BKubeFlowerPlain1" => "Flor blanca", "BKubeFlowerPlain2" => "Flor rosa", "BKubeFlowerPlain3" => "Stonehenge", "BKubeSavana" => "Sabana",
		"BKubeSavana1" => "Arbusto seco", "BKubeSavana2" => "Cebra", "BKubeSavana3" => "Elefante", "BKubeDesert" => "Arena",
		"BKubeDesert1" => "Cactus de Kube", "BKubeFruit" => "Bellota", "BKubeLava" => "Lava de Kube", "BKubeDolpart" => "Penumbra",
		"BKubeDolmen" => "Dolmen", "BKubeFlying" => "Meka", "BKubeFlying1" => "Metal", "BKubeFlying2" => "Acero", "BKubeKoala" => "Koala",
		"BKubeInvisible" => "Invisible", "BKubeAmethyste" => "Amatista", "BKubeEmeraude" => "Esmeralda", "BKubeRubis" => "Rubí",
		"BKubeSaphir" => "Zafiro", "BKubeFog" => "Niebla", "BKubeShade" => "Sombra", "BKubeLight" => "Luz", "BKubeGold" => "Oro",
		"BKubeMessage" => "Foro", "BKubeTeleport" => "Teletransporte", "BKubeJump" => "Muelle", "BKubeChest" => "Cofre",
		"BKubeMulticol" => "Rubix", "BKubeMtwin" => "Motion Twin", "BKubeCrate" => "Caja", "BKubeNoel" => "Kube de Navidad",
	];

	/** frances: los bloques anadidos despues y algun cambio (BChest: en DataGen "Cantine de l'EScorp") */
	static var FR_EXTRA : Map<String, String> = [
		"BYellowPlant" => "Plante à citronox", "BBluePlant" => "Plante à etherium", "BYellowCeil" => "Stalactite de citronox",
		"BMarsBlueRock" => "Météorite d'etherium", "BMarsCactusFlower" => "Tortillant fleuri", "BPinkCharge" => "Charge rose",
		"BWinterHidden" => "Terre glaciale",
		"BWinterFlowerDeleted" => "-",
		"BAutumnHerbs1" => "Herbe rouge", "BAutumnHerbs2" => "Grande herbe rouge", "BTreeHerbs" => "Mousse pendante",
		"BMoonHerbs1" => "Pousse lunaire", "BMoonHerbs2" => "Petite pousse lunaire", "BWinterHerb1" => "Herbe givrée",
		"BWinterHerb2" => "Herbe givrée courte", "BWinterHerb3" => "Herbe givrée rase", "BMarsHerb1" => "Herbe des sables rase",
		"BMarsHerb2" => "Herbe des sables courte", "BMarsHerb3" => "Herbe des sables",
		"BBonusSmall" => "Petit cristal bonus", "BBonusMedium" => "Cristal bonus", "BBonusLarge" => "Gros cristal bonus", "BBonusCharge" => "Charge bonus",
		"BDeadRock" => "Roche morte", "BDeadSoil" => "Terre morte", "BDeadSwamp" => "Marais mort", "BDeadTree" => "Arbre mort",
		"BDarkLeaves" => "Feuillage sombre",
		"BChest" => "Conteneur EScorp",
	];

	static var cache : Array<Array<Names.NameData>> = [];

	/** tabla de nombres para Names.NAMES (0 = espanol, 1 = ingles, 2 = frances), indexada como Block.index */
	public static function table( lang : Int ) : Array<Names.NameData> {
		if( cache[lang] != null ) return cache[lang];
		var out = new Array<Names.NameData>();
		for( b in Block.all ) {
			if( b == null ) continue;
			var key = Type.enumConstructor(b.k);
			var es = NamesGen.ES[b.index] != null ? NamesGen.ES[b.index].name : null;
			var n : String = switch( lang ) {
				case 1:
					var v = EN.get(key);
					v != null ? v : (es != null && es != "" ? "-" : null);
				case 2:
					var v = FR_EXTRA.get(key);
					v != null ? v : @:privateAccess b.name;
				default:
					var v = ES.get(key);
					v != null ? v : es;
			}
			// los internos llevan "-" en el original
			if( n == null || n == "" ) n = "-";
			out[b.index] = { name : n };
		}
		for( i in 0...out.length ) if( out[i] == null ) out[i] = { name : "-" };
		// el original solo nombraba lo que cabe en el inventario (getDrop ya da el bloque base); aqui se apunta a todo
		for( b in Block.all ) {
			var m = b, n = 0;
			while( m != null && out[m.index].name == "-" && n++ < 8 ) m = base(m);
			if( m != null && m != b ) out[b.index] = { name : out[m.index].name };
		}
		return cache[lang] = out;
	}

	/** nombre propio de un bloque en espanol (sin el de su bloque base); null = interno o variante sin nombre */
	static function ownName( b : Block ) : String {
		var v = ES.get(Type.enumConstructor(b.k));
		if( v == null && NamesGen.ES[b.index] != null ) v = NamesGen.ES[b.index].name;
		return v == null || v == "" || v == "-" ? null : v;
	}

	static var entries : Array<Block>;

	/**
	 * Ficha del Kubindex de un bloque (anadido del port): su bloque principal (cubierto, girado, abierto), el que le da nombre si
	 * no tiene uno propio (roca rota, lava que corre) y, entre los que se llaman igual (roca lunar rota, los dos fosiles, la nieve
	 * con una planta dentro), el primero. null = bloque interno, sin nombre en ningun idioma.
	 */
	public static function entry( b : Block ) : Block {
		if( entries == null ) {
			var own = [for( x in Block.all ) {
				var m = x.getMain(), n = 0;
				while( m != null && ownName(m) == null && n++ < 8 ) m = base(m);
				m != null && ownName(m) != null ? m : null;
			}];
			var first = new Map<String, Block>();
			for( m in own )
				if( m != null && (!first.exists(ownName(m)) || first.get(ownName(m)).index > m.index) ) first.set(ownName(m), m);
			entries = [for( m in own ) m == null ? null : first.get(ownName(m))];
		}
		return entries[b.index];
	}

	/** bloque del que toma el nombre uno sin nombre propio, o null */
	static function base( b : Block ) : Block {
		// cubierto (nieve, hierba), girado o puerta abierta: el principal, como en Block.getDrop
		var m = b.getMain();
		if( m != b ) return m;
		// lava que corre (BLava2-5): la fuente (las cascadas no se pueden apuntar)
		if( b.hasProp(PCanPick) )
			for( s in Block.all ) if( s != b && s.propagate == b ) return s;
		// roca rota: lo que suelta siempre, si es un bloque (no las cargas ni las hierbas con suerte)
		var d = b.getDrop();
		if( d != null && d.b != b && d.b.charge == null && b.getDropChance() == 100 ) return d.b;
		// agua de cada planeta (oscura, helada): agua
		if( b.type == BTWater && b.k != BWater ) return Block.get(BWater);
		return null;
	}
}
