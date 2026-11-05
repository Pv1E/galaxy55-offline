import Common;
import SaveData.SaveInfo;

/** Anomalia del terreno (DetailsGenerator): nombre en los tres idiomas y biomas en los que puede salir (null = todos). */
typedef KubAnomaly = {
	var id : String;
	var names : Array<String>;
	var biomes : Array<String>;
	/** el generador no la apunta (cristales verdes): se identifica al identificar uno de sus kubes propios */
	var byBlocks : Bool;
}

/** Donde se encuentra una ficha: biomas de planeta, anomalias (id) y tipos de cometa. */
typedef KubPlace = {
	var biomes : Array<String>;
	var anomalies : Array<String>;
	var comets : Array<String>;
}

/** Categoria de una ficha en el Kubindex (una ficha puede estar en varias). */
enum abstract KubCat(Int) to Int {
	var CPlanet = 0;
	var CAnomaly = 1;
	var CComet = 2;
	var CCraft = 3;
	var CSpecial = 4;
	/** las cargas (citronox, etherium, rosa): fichas aparte, fuera de "Todos" */
	var CCharge = 5;
}

/**
 * Datos fijos de la Base de datos ESCorp (anadido del port): las fichas del Kubindex, donde se encuentra cada una y las recetas
 * en las que entra. Los sitios estan en kubindex.json (junto a los graficos, ver Res), que se edita sin recompilar:
 * - "anomalies": las anomalias del terreno con su nombre y sus biomas;
 * - "places": por bloque (constructor de BlockKind), sus sitios: un bioma de planeta ("BIMoon"), un tipo de cometa
 *   ("BICometCinder", ver Comets.KINDS) o una anomalia ("a:volcano");
 * - "hidden": bloques con nombre que no son fichas (pruebas, los de la Ciudad muerta);
 * - "hiddenBiomes": biomas que no estan en la base de datos (la Ciudad muerta: nunca sale en el mapa);
 * - "special": bloques que son especiales aunque salgan en una anomalia (el motor espacial de la capsula estrellada).
 * Las fichas son los bloques con nombre (BlockNames.entry) que se pueden apuntar. Categorias: planeta, cometa y fabricado si
 * sale en un terreno, en una cometa o en una receta; anomalia solo si no sale en ninguno de ellos (la phosphomousse de las
 * ruinas es de planeta, el blindaje fabricado); especial lo que no esta en ningun sitio (nave, nave nodriza) y "special".
 */
class KubData {

	static var inst : KubData;

	public static function get() : KubData {
		if( inst == null ) inst = new KubData(Res.path("kubindex.json"));
		return inst;
	}

	/** pruebas (Dev "kub load RUTA"): otro archivo */
	public static function reload( path : String ) inst = new KubData(path);

	/** todas las fichas, en el orden de los datos (sin las cargas) */
	public var entries(default, null) : Array<Block> = [];
	/** las cargas con ficha propia (categoria Cargas): amarilla, azul y rosa; la de bonus no */
	public var charges(default, null) : Array<Block> = [];
	public var anomalies(default, null) : Array<KubAnomaly> = [];
	var places = new Map<Int, KubPlace>();
	var hiddenBiomes = new Map<String, Bool>();
	var special = new Map<Int, Bool>();
	var isEntry = new Map<Int, Bool>();
	var makes = new Map<Int, Array<CraftRule>>();
	var usedIn = new Map<Int, Array<CraftRule>>();

	function new( path : String ) {
		var o : Dynamic = try haxe.Json.parse(sys.io.File.getContent(path)) catch( e : Dynamic ) {
			Sys.stderr().writeString(path + ": " + e + "\n");
			{};
		};
		var hidden = new Map<String, Bool>();
		if( o.hidden != null ) for( h in (o.hidden : Array<Dynamic>) ) hidden.set(Std.string(h), true);
		if( o.hiddenBiomes != null ) for( h in (o.hiddenBiomes : Array<Dynamic>) ) hiddenBiomes.set(Std.string(h), true);
		if( o.anomalies != null )
			for( a in (o.anomalies : Array<Dynamic>) )
				anomalies.push({
					id : Std.string(a.id),
					names : [for( n in (a.names : Array<Dynamic>) ) Std.string(n)],
					biomes : a.biomes == null ? null : [for( b in (a.biomes : Array<Dynamic>) ) Std.string(b)],
					byBlocks : a.byBlocks == true,
				});
		for( b in Block.all ) {
			if( b == null || BlockNames.entry(b) != b || hidden.exists(Type.enumConstructor(b.k)) ) continue;
			// ni lo que no se puede apuntar (liquidos), ni lo que no se rompe nunca (roca madre), ni las cargas (se citan en las recetas)
			if( !b.hasProp(PCanPick) || (b.requiredPower != null && b.requiredPower < 0) || b.charge != null ) continue;
			entries.push(b);
			isEntry.set(b.index, true);
		}
		for( b in Block.all ) if( b != null && b.charge != null && b.charge != CBonus && BlockNames.entry(b) == b ) charges.push(b);
		if( o.places != null )
			for( f in Reflect.fields(o.places) ) {
				var b = try Block.get(Type.createEnum(BlockKind, f)) catch( e : Dynamic ) null;
				var e = b == null ? null : entryOrCharge(b);
				if( e == null ) {
					Sys.stderr().writeString(path + ": " + f + " no es una ficha del Kubindex\n");
					continue;
				}
				var p = placeOf(e);
				for( s in (Reflect.field(o.places, f) : Array<Dynamic>) ) {
					var s = Std.string(s);
					var list = StringTools.startsWith(s, "a:") ? p.anomalies : Comets.KINDS.indexOf(s) >= 0 ? p.comets : p.biomes;
					var v = StringTools.startsWith(s, "a:") ? s.substr(2) : s;
					if( list.indexOf(v) < 0 ) list.push(v);
				}
			}
		if( o.special != null )
			for( f in (o.special : Array<Dynamic>) ) {
				var b = try Block.get(Type.createEnum(BlockKind, Std.string(f))) catch( e : Dynamic ) null;
				var e = b == null ? null : entryOf(b);
				if( e != null ) special.set(e.index, true);
			}
		for( r in Data.CRAFT ) {
			add(makes, entryOf(Block.get(r.out)), r);
			for( e in recipeBlocks(r, false) ) add(usedIn, e, r);
		}
	}

	static function add( m : Map<Int, Array<CraftRule>>, e : Block, r : CraftRule ) {
		if( e == null ) return;
		var l = m.get(e.index);
		if( l == null ) m.set(e.index, l = []);
		if( l.indexOf(r) < 0 ) l.push(r);
	}

	/** ficha de un bloque del mundo o del inventario (null = no esta en el Kubindex) */
	public function entryOf( b : Block ) : Block {
		if( b == null ) return null;
		var e = BlockNames.entry(b);
		return e != null && isEntry.exists(e.index) ? e : null;
	}

	/** ficha de un bloque o, si es una de las cargas con ficha, la propia carga */
	public function entryOrCharge( b : Block ) : Block {
		if( b == null ) return null;
		return charges.indexOf(b) >= 0 ? b : entryOf(b);
	}

	/** bloques que la sueltan al romperlos, con cuantas (citronox viejo: 3 cargas amarillas) */
	public function chargeSources( c : Block ) : Array<{ e : Block, n : Int }> {
		var out : Array<{ e : Block, n : Int }> = [];
		for( b in Block.all ) {
			var d = b == null ? null : b.getDrop();
			var e = d == null || d.b != c || b == c ? null : entryOf(b);
			if( e == null || Lambda.exists(out, function(s) return s.e == e) ) continue;
			out.push({ e : e, n : d.count });
		}
		return out;
	}

	/** recetas que la fabrican (citronox: 25 cargas amarillas) */
	public function chargeRecipes( c : Block ) : Array<CraftRule> return [for( r in Data.CRAFT ) if( Block.get(r.out) == c ) r];

	/** fichas que piden esa carga para minarlas */
	public function chargeNeeded( c : Block ) : Array<Block> return [for( e in entries ) if( chargeFor(e) == c.charge ) e];

	public function placeOf( e : Block ) : KubPlace {
		var p = places.get(e.index);
		if( p == null ) places.set(e.index, p = { biomes : [], anomalies : [], comets : [] });
		return p;
	}

	public function anomaly( id : String ) : KubAnomaly {
		for( a in anomalies ) if( a.id == id ) return a;
		return null;
	}

	/** recetas que fabrican la ficha */
	public function recipesMaking( e : Block ) : Array<CraftRule> {
		var l = makes.get(e.index);
		return l == null ? [] : l;
	}

	/** recetas que la usan */
	public function recipesUsing( e : Block ) : Array<CraftRule> {
		var l = usedIn.get(e.index);
		return l == null ? [] : l;
	}

	/** fichas de una receta: sus ingredientes y, con out, el resultado */
	public function recipeBlocks( r : CraftRule, out = true ) : Array<Block> {
		var l = [];
		for( s in r.schema ) {
			var e = entryOf(Block.get(switch( s ) { case CSSingle(b), CSBase(b, _), CSLine(b, _): b; }));
			if( e != null && l.indexOf(e) < 0 ) l.push(e);
		}
		var o = entryOf(Block.get(r.out));
		if( out && o != null && l.indexOf(o) < 0 ) l.push(o);
		return l;
	}

	public function has( e : Block, c : KubCat ) : Bool {
		var p = placeOf(e);
		var natural = p.biomes.length + p.comets.length > 0, craft = recipesMaking(e).length > 0, forced = special.exists(e.index);
		return switch( c ) {
			case CPlanet: p.biomes.length > 0;
			case CComet: p.comets.length > 0;
			case CCraft: craft;
			// anomalia solo si no se encuentra de otra manera
			case CAnomaly: p.anomalies.length > 0 && !natural && !craft && !forced;
			case CSpecial: e.charge == null && (forced || (!natural && !craft && p.anomalies.length == 0));
			case CCharge: e.charge != null;
		}
	}

	/** el bioma esta en la base de datos */
	public function biomeIndexed( biome : String ) return !hiddenBiomes.exists(biome);

	/** fichas del terreno de un bioma (o tipo de cometa), en el orden de terrainRank */
	public function ofBiome( biome : String ) : Array<Block> {
		var l = [for( e in entries ) if( placeOf(e).biomes.indexOf(biome) >= 0 || placeOf(e).comets.indexOf(biome) >= 0 ) e];
		l.sort(function(a, b) {
			var d = terrainRank(a) - terrainRank(b);
			return d != 0 ? d : a.index - b.index;
		});
		return l;
	}

	/**
	 * Orden de los kubes de un planeta: tierra, roca, madera, follaje, varios, plantas, hierbas, lo que da cargas al romperlo
	 * (amarillas y luego azules), lo que da cargas en el sintetizador, y al final bauxita, pirita y rouge'rosh.
	 */
	function terrainRank( e : Block ) : Int {
		switch( e.k ) {
			case BMinAluminium: return 1000;
			case BMinIron: return 1100;
			case BHardRock: return 1200;
			default:
		}
		var d = e.getDrop();
		if( d != null && d.b.charge != null ) return 800 + Type.enumIndex(d.b.charge);
		for( r in recipesUsing(e) ) {
			var o = Block.get(r.out);
			if( o.charge != null ) return 900 + Type.enumIndex(o.charge);
		}
		var m = e.matter == null ? e.k : e.matter.k;
		if( e.hasFlag(BFDetail) || m == BHighHerb1 ) return 700;
		return switch( m ) {
			case BSoil, BMoonSand: 100;
			case BRock, BAlienRock: 200;
			case BHardRock: e.k == BCoral1 || e.k == BCoral2 ? 500 : 200;
			case BWood: 300;
			case BGreenLeaves: 400;
			case BCactus, BMarsCactus: 600;
			default: e.type == BTModel2Side ? 600 : 500;
		}
	}

	/** anomalias que pueden salir en un planeta de ese bioma (ninguna en una cometa) */
	public function anomaliesIn( biome : String ) : Array<KubAnomaly> {
		if( Comets.isComet(biome) ) return [];
		return [for( a in anomalies ) if( a.biomes == null || a.biomes.indexOf(biome) >= 0 ) a];
	}

	/** fichas que da una anomalia */
	public function anomalyBlocks( id : String ) : Array<Block> {
		return [for( e in entries ) if( placeOf(e).anomalies.indexOf(id) >= 0 ) e];
	}

	/** las suyas propias: las que no salen en el terreno de ningun planeta ni cometa (todas, si no tiene ninguna propia) */
	public function anomalyOwnBlocks( id : String ) : Array<Block> {
		var all = anomalyBlocks(id);
		var own = [for( e in all ) if( placeOf(e).biomes.length + placeOf(e).comets.length == 0 ) e];
		return own.length > 0 ? own : all;
	}

	/**
	 * Probabilidad (%) de que romper el bloque del mundo b de algo de su propia ficha: 0 si no suelta nunca nada suyo (vidrio,
	 * plantas de cargas, citronox viejo), BFDropChance si cae con suerte, 100 si no.
	 */
	public function dropChance( b : Block ) : Int {
		var d = b.getDrop();
		if( d == null || d.count <= 0 || entryOf(d.b) != entryOf(b) ) return 0;
		return b.getMain().getDropChance();
	}

	/** carga que hace falta para romperla (null = ninguna) */
	public function chargeFor( e : Block ) : ChargeKind {
		var m = e.matter;
		if( m == null || !m.hasProp(PRequireCharge) || m.quickBreaks == null || m.quickBreaks.length == 0 ) return null;
		return m.quickBreaks[0].c;
	}

	/** donde se encuentra, en una linea por tipo de sitio; las anomalias que aun no se han cruzado salen como "???" */
	public function placeLines( info : SaveInfo, e : Block ) : Array<String> {
		var p = placeOf(e), out = [];
		if( has(e, CSpecial) ) out.push(KubText.get("kub.where.special"));
		if( p.biomes.length > 0 ) out.push(KubText.get("kub.where.planets") + " " + [for( b in p.biomes ) ExpData.ExpOffline.biomeName(b)].join(", "));
		if( p.anomalies.length > 0 ) out.push(KubText.get("kub.where.anomalies") + " " + anomalyNames(info, p.anomalies));
		if( p.comets.length > 0 ) out.push(KubText.get("kub.where.comets") + " " + [for( c in p.comets ) ExpData.ExpOffline.biomeName(c)].join(", "));
		return out;
	}

	/** nombres de las anomalias identificadas, y "???" si queda alguna por cruzar */
	function anomalyNames( info : SaveInfo, ids : Array<String> ) : String {
		var names = [for( a in ids ) if( Kubindex.anomalyKnown(info, a) ) anomalyName(a)];
		if( names.length < ids.length ) names.push(KubText.get("kub.unknown"));
		return names.join(", ");
	}

	/** sitio en pocas palabras (bajo una ficha desconocida "???" de una receta) */
	public function placeShort( info : SaveInfo, e : Block ) : String {
		var p = placeOf(e);
		if( p.biomes.length > 0 ) return ExpData.ExpOffline.biomeName(p.biomes[0]) + (p.biomes.length > 1 ? " +" + (p.biomes.length - 1) : "");
		if( p.comets.length > 0 ) return ExpData.ExpOffline.biomeName(p.comets[0]);
		if( recipesMaking(e).length > 0 ) return KubText.get("kub.short.craft");
		if( has(e, CSpecial) ) return KubText.get("kub.tag.special");
		for( a in p.anomalies ) if( Kubindex.anomalyKnown(info, a) ) return anomalyName(a);
		return KubText.get("kub.tag.anomaly") + " " + KubText.get("kub.unknown");
	}

	public function anomalyName( id : String ) : String {
		var a = anomaly(id);
		return a == null ? id : a.names[Lang.cur < a.names.length ? Lang.cur : 0];
	}
}
