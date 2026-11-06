typedef PlanetInfos = {
	var id : Null<Int>;
	var biome : BiomeKind;
	var size : Int;
	var seed : Int;
	var waterLevel : Int;
	var waterTotal : Int;
	var waterFlood : Int;
}

enum BlockType {
	BTInvisible;
	BTAlpha;
	BTTransp;
	BTModel;
	BTModel2Side;
	BTModelMultiTex;
	BTSprite;
	BTWater; // before full
	BTReduced; // don't let light pass (for roofs)
	BTExtended;
	BTFull; // last
}

enum BlockKind {
	BEmpty;
	BBedrock;
	BWater;
	BSoil;
	BSoilCover;
	BRock;
	BWood;
	BGreenLeaves;
	BYellowCrystalLight;
	BAutumnHerbs1;
	BAutumnHerbs2;
	BPinkFlower;
	BChampiLight;
	BAutumnStraw;
	BVines;
	BVinesY;
	BTreeHerbs;
	BCactus;
	BLamp;
	BYellowCrystalDense;
	BYellowCharge;
	BBackPack;
	BWoodPlank;
	BBrokenRock;
	BHardRock;
	BMinAluminium;
	BCactusBase;
	BCactusFlower;
	BBlueCrystalLight;
	BBlueCrystalDense;
	BBlueCharge;
	BRockWall;
	BWoodWindow;
	BWoodWindowY;
	BWoodPlate;
	BVineColumn;
	BRockWallSquare;
	BTest;
	BHardRockColumn;
	BWoodColumn;
	BHardRockWall;
	BWoodScrew;
	BLeavesCurtain;
	BLeavesCurtainY;
	BRawRed;
	BShedWall;
	BShedGround;
	BShedLight;
	BShipHull;
	BShipEngine;
	BShipGlass;
	BShipDoor;
	BShipDoorY;
	BShipDoorOpen;
	BShipDoorYOpen;
	BShipPlate;
	BShipWire;
	BShipComputer;
	BShipTubes;
	BShipGlass2;
	BShipEntry;
	BCrafter;
	BCrafterComputer;
	BShipLight;
	BShedGroundArrow;
	BShedWallColumn;
	BShedGlass;
	BShedWallLight;
	BAluminium;
	BGlass;
	BLight;
	BPurpleLeaves;
	BBrownLeaves;
	BPinkLeaves;
	BMoonSoil;
	BMoonSoilCover;
	BMoonRock;
	BMoonSand;
	BMoonLight;
	BMoonLightDead;
	BMoonLightColumn;
	BDarkWater;
	BMoonRockColumn;
	BMoonBrokenRock;
	BStainEmpty;
	BStainPurple;
	BStainRed;
	BRaw;
	BRawPurple;
	BMoonHerbs1;
	BMoonHerbs2;
	BAcidWood;
	BAcidWoodHole;
	BAcidWoodBubble;
	BAcidSoil;
	BAcidSoilCover;
	BAcidRock;
	BAcidWater;
	BAcidLeaves;
	BAcidLeavesBubble;
	BAcidLeaves2;
	BAcidLeaves2Bubble;
	BAcidMush;
	BAcidFruit;
	BAcidTreeSap;
	BFreezer;
	BIce;
	BCascadeSource;
	BCascadeFall;
	BCascadeFall2;
	BCascadeFall3;
	BCascadeFall4;
	BYellowPlant;
	BBluePlant;
	BWinterWater;
	BWinterSoil;
	BWinterSoilCover;
	BWinterRock;
	BWinterBrokenRock;
	BWinterHidden;
	BWinterFlowerDeleted;
	BWinterLeaves;
	BWinterLeavesCover;
	BWinterHerb1;
	BWinterHerb2;
	BWinterHerb3;
	BWinterWood;
	BBlackIce;
	BBlackIceLight;
	BIceStalactite1;
	BIceStalactite2;
	BBlackLight;
	BMarsSoil;
	BMarsSoil2;
	BMarsRock;
	BMarsCraterRock;
	BMarsBlueRock;
	BMarsHardRock;
	BMarsRockFossil;
	BMarsQuickSand;
	BMarsCactus;
	BMarsCactusFossil;
	BMarsCactusFlower;
	BPinkCharge;
	BMarsHerb1;
	BMarsHerb2;
	BMarsHerb3;
	BAlienRock;
	BArtiBomb;
	BBigMushTrunk;
	BBigMushHead;
	BJumper;
	BLava;
	BLava2;
	BLava3;
	BLava4;
	BLava5;
	BLavaRock;
	BChest;
	BAlienTreasure;
	BCamera;
	BMush;
	BCoral1;
	BCoral2;
	BFrozenRock;
	BCoal;
	BCoalHot;
	BPlantSoil;
	BHighHerb1;
	BHighHerb2;
	BHighHerb3;
	BHighHerb4;
	BHighHerb5;
	BHighHerb6;
	BFreezerPlant;
	BMiningGenerator;
	BStainWhite;
	BRawWhite;
	BStainOrange;
	BRawOrange;
	BStainGreen;
	BRawGreen;
	BMarsWall;
	BWinterWall;
	BAcidWall;
	BPlantRock;
	BAcidHerb1;
	BAcidHerb2;
	BAcidHerbCeil;
	BHealPlant;
	BYellowCeil;
	BCavePlantCeil;
	BBonusSmall;
	BBonusMedium;
	BBonusLarge;
	BBonusCharge;
	BBonusMediumRemain;
	BBonusHerb1;
	BBonusHerb2;
	BMinIron;
	BIron;
	BIronFence;
	BIronFenceY;
	BIronLight;
	BShipGlassBlack;
	BShiningWoodPlank;
	BHealBox;
	BCircuit;
	BDeadRock;
	BDeadSoil;
	BDeadSwamp;
	BDeadTree;
	BDarkLeaves;
	// anadidos del port: bloques de la nave nodriza (texturas generadas en port/game/Atlas.hx)
	BMotherHull;
	BMotherPanel;
	BMotherDark;
	BMotherField;
	BMotherYellow;
	BMotherBlack;
	// anadidos del port: los 77 kubes de Kube (Motion Twin, 2010), bloques enteros con el nombre que tenian en Kube
	// (WebGamesArchives, Muxxu/Kube/client2/blocks.ods). Texturas en las filas 40 y 41 del atlas; sus .kube en port/kubes
	BKubeFixed;
	BKubeWater;
	BKubeSoilTree;
	BKubeSoilTree1;
	BKubeSoilTree2;
	BKubeAutumnTree;
	BKubeAutumnTree1;
	BKubeAutumnTree2;
	BKubeHighTree;
	BKubeHighTree1;
	BKubeHighTree2;
	BKubeHighTree3;
	BKubeClouds;
	BKubeClouds1;
	BKubeClouds2;
	BKubeSphereTree;
	BKubeSphereTree1;
	BKubeLargeTree;
	BKubeLargeTree1;
	BKubeLargeTree2;
	BKubeSnowSapin;
	BKubeSnowSapin1;
	BKubeSnowSapin2;
	BKubeJungle;
	BKubeJungle1;
	BKubeJungle2;
	BKubeJungle3;
	BKubeCaverns;
	BKubeCaverns1;
	BKubeCaverns2;
	BKubeField;
	BKubeField1;
	BKubeField2;
	BKubeSwamp;
	BKubeSwamp1;
	BKubeSwamp2;
	BKubeSwamp3;
	BKubeSoilPeaks;
	BKubeSoilPeaks1;
	BKubePilarPlain;
	BKubePilarPlain1;
	BKubePilarPlain2;
	BKubeFlowerPlain;
	BKubeFlowerPlain1;
	BKubeFlowerPlain2;
	BKubeFlowerPlain3;
	BKubeSavana;
	BKubeSavana1;
	BKubeSavana2;
	BKubeSavana3;
	BKubeDesert;
	BKubeDesert1;
	BKubeFruit;
	BKubeLava;
	BKubeDolpart;
	BKubeDolmen;
	BKubeFlying;
	BKubeFlying1;
	BKubeFlying2;
	BKubeKoala;
	BKubeInvisible;
	BKubeAmethyste;
	BKubeEmeraude;
	BKubeRubis;
	BKubeSaphir;
	BKubeFog;
	BKubeShade;
	BKubeLight;
	BKubeGold;
	BKubeMessage;
	BKubeTeleport;
	BKubeJump;
	BKubeChest;
	BKubeMulticol;
	BKubeMtwin;
	BKubeCrate;
	BKubeNoel;
}

enum BlockModel {
	MCross;
	MPlanX;
	MPlanY;
	MPlanZ;
	MHalf;
	MMini;
	MMiniTop;
	MColumn;
	MBigColumn;
	MPipeX;
	MPipeY;
	MDoorOpenX;
	MDoorOpenY;
	MCrossSquare;
	MCrossPyramid;
	MCrossBox;
}

enum BlockFace {
	None;
	Up;
	Down;
	UpDown;
	LeftRight;
}

enum Where {
	WEverywhere;
	WInShip;
	WOnPlanet;
}


enum TriggerEffect {
	TCustom;
	TMiningSpeed;
}

enum BlockFlag {
	BFLiquid;
	BFNoCollide;
	BFNoPick;
	BFCoverable;
	BFDetail;
	BFFlip;
	BFNoDrop;
	BFNoShade;
	BFCantPut;
	BFLight( pow : Float, ?falloff : Float );
	BFModel( m : BlockModel );
	BFAnchor( face : BlockFace );
	BFMagnet( face : BlockFace );
	BFDrop( b : BlockKind, ?count : Int );
	BFCharge( c : ChargeKind );
	BFAlpha( v : Float );
	BFSize( x : Float, y : Float, z : Float, x2 : Float, y2 : Float, z2 : Float );
	BFToggle( b : BlockKind );
	BFTextures( a : Array<Int> );
	BFActivable( w : Where );
	BFColor( v : Int, ?alpha : Float );
	BFDamage( v : Float );
	BFSlippy;
	BFTransform( b : BlockKind, ?proba : Float );
	BFPropagate( b : BlockKind );
	BFFallCopy;
	BFIsLava;
	BFDropChance(pctChance:Int); // random(100)<chance
	BFHeal( v : Float );
	BFJump( pow : Float );
	BFTrack( t : TriggerEffect, dist : Int );
	BFNoOptimize;
	BFContainer( size : Int );
}

typedef BlockData = {
	var id : BlockKind;
	var type : BlockType;
	var texture : Array<Int>;
	var texUp : Array<Int>;
	var texDown : Array<Int>;
	var shadeX : Null<Float>;
	var shadeY : Null<Float>;
	var shadeUp : Null<Float>;
	var shadeDown : Null<Float>;
	var power : Null<Float>;
	var weight : Null<Float>;
	@:sep("+")
	var flags : Array<BlockFlag>;
	var matter : Null<BlockKind>;
	var name : Null<String>;
	var basePrice : Null<Int>;
}

@:native('_BK')
enum BiomeKind {
	BITest;
	BIAutumn;
	BIMoon;
	BIShed;
	BIAcidForest;
	BIWinterPeaks;
	BIMars;
	BIDeadCity;
	// añadidos del port: un bioma por tipo de cometa (Comets, CometGenerator); nunca salen al azar como planeta
	BICometCinder;
}

typedef BiomeData = {
	var id : BiomeKind;
	var sunPower : Float;
	var sunFalloff : Null<Float>;
	var fog : Array<Int>;
	var fogPower : Float;
	var water : BlockKind;
	var soils : Array<BlockKind>;
	var exploreColors : Array<Int>;
	var proba : Int;
	var startThrough : Array<BlockKind>;
}

@:native('_CK')
enum ChargeKind {
	CYellow;
	CBlue;
	CPink;
	CBonus;
}

enum ChargeEffect {
	CECanBreak( c : BlockKind );
	CEFast( c : BlockKind, speed : Float );
}

typedef ChargeData = {
	var id : ChargeKind;
	var max : Int;
	@:sep("+")
	var effects : Array<ChargeEffect>;
}

enum CraftSchema {
	CSSingle( b : BlockKind );
	CSBase( b : BlockKind, size : Int );
	CSLine( b : BlockKind, len : Int );
}

typedef CraftRule = {
	var id : Int;
	@:sep("+")
	var schema : Array<CraftSchema>;
	var out : BlockKind;
	var count : Null<Int>;
}

class Data {
	static var BLOCKS = DataGen.BLOCKS;
	static var BIOMES = DataGen.BIOMES;
	static var CHARGES = DataGen.CHARGES;
	
	public static function getAllCharges() return CHARGES;
	public static function getBiome( b : BiomeKind ) return BIOMES[Type.enumIndex(b)];
	public static function getCharge( c : ChargeKind ) return CHARGES[Type.enumIndex(c)];
	public static function getBlocksData() return BLOCKS;
	public static function getBiomesData() return BIOMES;
	
	//blocs that can be consideredas trivial to find, serves for base escorp contracts
	public static var 		BASIC_BLOCKS = [BSoil,BWood,BAluminium, BWinterSoil,BMarsSoil];
	
	
	#if flash
	public static var TEXTURE : flash.display.BitmapData;
	#end

	#if neko
	static var _ = Config;
	static function getCacheFile(file) return neko.Web.getCwd() + "../com/" + file
	
	public static var RANDOM_TEXT =
	{
		var f = neko.io.File.read(Config.TPL + "random.xml", true);
		var rd = mt.data.RandomText.load( f.readAll().toString() );
		f.close;
		f = null;
		rd;
	}
	
	#end
	
	public static var CRAFT = {
		var c = DataGen.CRAFT;
		for( r in c )
			if( r.count == null ) r.count = 1;
		c.sort(function(r1, r2) return r1.id - r2.id);
		c;
	}
}

class Const {

	public static inline var FBITS = 4;
	public static inline var PREC = 1 << FBITS;
	public static inline var POWER = 10000;

	public static inline var BITS = 7;
	public static inline var ZBITS = 7;

	public static inline var MASK = (1 << BITS) - 1;
	public static inline var ZMASK = (1 << ZBITS) - 1;

	public static inline var SIZE = 1 << BITS;
	public static inline var ZSIZE = 1 << ZBITS;
	public static inline var TSIZE = SIZE * SIZE * ZSIZE;

	public static inline var Z = 0;
	public static inline var X = ZBITS;
	public static inline var Y = ZBITS + BITS;
	public static inline var DX = 1 << X;
	public static inline var DY = 1 << Y;
	public static inline var DZ = 1 << Z;

	public static inline var BLOCK_POWER = Std.int(POWER / 125);
	public static inline var SAVE_DIST = 15;

	public static inline var SHIP_Z = 130;
	//public static var DEFAULT_SHIP = haxe.Unserializer.run("s136:eNrt1zsOgCAMAFAO4MLCOdC4mOj9ryUDIw4kKia%160kDG3KJ8YpAMDPpc48Y:vCN:uSSzBOu:5HXdOvu8xd9d%b9U81kxu7bJf9WpyTj89LDmsJ8zLyflFn7zH8XwDgHSf5Ogao");
	public static var DEFAULT_SHIP = haxe.Unserializer.run(
		/* DUCK-01 */ "s207:eNrtl0EKgCAQAH1AFy89oBds0qGg8v%:SshTuaQRVDIj7GGThB22TWsbAwCfo6MEeIFsWnz9yIvHy2tIXKm8O%VbZffVCVBanyU%y82LGc0aYp:0e2ZW3mNuGK7Viiuo:6K4lBiPXz4X811iv0:6nVRfrmgG1tkvovaFVs895vaL0C8Pz5chLOYL:2PA:YX7PuAFAL7IBuaqEt4"
		///* TEST */ "s208:eNrtlzsOgCAQRDmADQ0H8ARILDQRvf%ttKBSJgKNn7xHYrHZrMkMy4K1nQGA19EjAb5AMQ6:PuTLhi%P4dPKxcMl7kT23R9AMQh9YtKuNO7NZFbhY67%IuqYBof:2hehQv8o9rpP3:PJF1K8z%RvWR9n6VeomoH:7Bcv%0LpqfLr6tMvrfNlPBbzhfsY8H7hvQ:4AgBvZAcFWRLe"
		///* TRAILER */ "s287:eNrtl0EOwiAQRecAbrrpATzBlBiDidr730qSqolhRhhKI8X:STePZkJ4mUKH4UANhsmFJ6anMGLu6RxG:vtafaTMy:U5F3uROSuc6AIvVfvlmxdv8IJ%gZeerCxD2ufZ6GUW68j19xOvrN:OnZFb6rNy7tPOdz:lhTO:D3X4%ObTyvrL%vv04jbb:zSv4aXPc6TECyn9VcKnDzcvfsxeD7xs48XC0S9lXuKb0U3ko8LhJX3:sXrxdM:2QlW98B950X21xrnbm7L9n7AtjiAIgvwqD:l:NSw"
		/* BASIC */ //"s140:eNrt1jEKgDAQRNEcwCY3We2E6P2PJfauEIwW8n455Xwm2VqnAgD4hFABL%CFF7ziJRI3o3LcMScGtmQ1WR5pHmVR87BljPOyXnqJzvezN::rXs5s7%i:2Yv:xT0GXsALL%DlAQc:9A3e"
	);
	
	public static function shipSpeed( engines : Int, weight : Float ) {
		return Std.int(engines * 1000 / weight) / 100;
	}
	
	public static inline function addr(x, y, z) {
		return (x << X) | (y << Y) | (z << Z);
	}

	public static inline function quickHash(x, y, z) {
		var a = x ^ (y << 10) ^ (z << 20);
		a ^= (a << 7) & 0x2b5b2500;
		a ^= (a << 15) & 0x1b8b0000;
		a ^= a >>> 16;
		a &= 0x3FFFFFFF;
		return a;
	}

	public static inline var STORAGE_PRICE = 100;
	public static inline var AUTO_STORAGE  = true;
}
