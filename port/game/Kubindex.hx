import Common;
import Ui;
import SaveData.SaveInfo;

/** Veces que el jugador ha puesto (p) y roto (b) un kube (nombre del constructor de BlockKind). */
typedef KubStat = { k : String, p : Int, b : Int };

/**
 * Lo que sabe la Base de datos ESCorp de la partida (SaveInfo.kub, anadido del port). Los kubes se guardan con el nombre de su
 * constructor de BlockKind (estable aunque se anadan bloques) y siempre por su ficha (BlockNames.entry).
 */
typedef KubInfo = {
	/** apuntados con el laser al menos una vez (aunque no se pudieran romper) */
	var seen : Array<String>;
	/** recuperados: pasaron por el inventario o, si no sueltan nunca nada, se rompieron */
	var got : Array<String>;
	var stats : Array<KubStat>;
	/** planetas explorados (aterrizado al menos una vez) y su bioma */
	var planets : Array<{ id : Int, b : String }>;
	/** cometas exploradas: su sistema, su franja y su tipo */
	var comets : Array<{ sys : Int, slot : Int, b : String }>;
	/** recetas fabricadas (Data.CRAFT: id) y cuantas veces */
	var crafts : Array<{ id : Int, n : Int }>;
	/** anomalias cruzadas (id de kubindex.json) */
	var anomalies : Array<String>;
	/** fichas nuevas desde la ultima vez que se miraron en la base de datos */
	var fresh : Array<String>;
}

/** Estado de una ficha para el jugador. */
enum abstract KubState(Int) to Int {
	var Unknown = 0;
	var Seen = 1;
	var Got = 2;
}

/**
 * Base de datos ESCorp (anadido del port): kubes repertoriados (el Kubindex), planetas y cometas explorados y recetas
 * descubiertas. Reglas:
 * - apuntar un kube con el laser lo repertoria como visto: su imagen (oscurecida), su nombre y donde encontrarlo;
 * - tenerlo en el inventario lo recupera: imagen normal, estadisticas (puestos, rotos) y sus recetas (las que lo fabrican y las
 *   que lo usan). Un kube que no suelta nada al romperlo (0 %) se recupera al romperlo; uno que suelta con suerte, solo cuando
 *   cae;
 * - una receta se descubre al recuperar uno de sus kubes (ingredientes o resultado);
 * - un tipo de planeta o de cometa se descubre al aterrizar en uno, una anomalia al pasar cerca de una (hasta entonces sale
 *   como "???" en los sitios de sus kubes);
 * - las cargas (citronox, etherium, rosa) tienen su propia categoria: se recuperan al tenerlas.
 * - los kubes de tu nave se conocen desde el principio (shipKnown). Las cargas no son fichas: salen en las recetas que las dan.
 * En creativo se sabe todo (Kubindex.full) y no se apunta nada.
 */
class Kubindex {

	/** aviso al jugador al repertoriar algo nuevo (GalaxyApp: KubNotify, arriba a la derecha) */
	public static var onNews : KubNotify.KubNews -> Void;

	static var lastSeen : { kub : KubInfo, index : Int };

	public static function empty() : KubInfo {
		return { seen : [], got : [], stats : [], planets : [], comets : [], crafts : [], anomalies : [], fresh : [] };
	}

	/** crea los datos si la partida no los tiene (antes de copiarla para el hangar o la nodriza: las copias los comparten) */
	public static function ensure( info : SaveInfo ) : KubInfo {
		if( info.kub == null ) info.kub = empty();
		return info.kub;
	}

	/** creativo: todo se sabe */
	public static inline function full( info : SaveInfo ) return info.creative == true;

	static inline function key( e : Block ) return Type.enumConstructor(e.k);

	// ---------------------------------------------------------------- consultas

	public static function state( info : SaveInfo, e : Block ) : KubState {
		if( e == null ) return Unknown;
		if( full(info) ) return Got;
		var k = ensure(info), n = key(e);
		return k.got.indexOf(n) >= 0 ? Got : k.seen.indexOf(n) >= 0 ? Seen : Unknown;
	}

	public static inline function known( info : SaveInfo, e : Block ) return state(info, e) != Unknown;

	public static inline function got( info : SaveInfo, e : Block ) return state(info, e) == Got;

	/** estadisticas de la ficha; sin create, null si aun no tiene */
	public static function stat( info : SaveInfo, e : Block, create = true ) : KubStat {
		var n = key(e);
		for( s in ensure(info).stats ) if( s.k == n ) return s;
		if( !create ) return null;
		var s = { k : n, p : 0, b : 0 };
		info.kub.stats.push(s);
		return s;
	}

	/** planetas (o cometas) de ese bioma explorados */
	public static function explored( info : SaveInfo, biome : String ) : Int {
		var k = ensure(info), n = 0;
		for( p in k.planets ) if( p.b == biome ) n++;
		for( c in k.comets ) if( c.b == biome ) n++;
		return n;
	}

	/** bioma descubierto (en creativo, todos) */
	public static function biomeKnown( info : SaveInfo, biome : String ) return full(info) || explored(info, biome) > 0;

	/**
	 * Anomalia identificada: se ha pasado cerca de una (encounter). Los cristales verdes, que el generador no apunta, se
	 * identifican al identificar uno de sus kubes propios (KubData.anomalyOwnBlocks).
	 */
	public static function anomalyKnown( info : SaveInfo, id : String ) : Bool {
		if( full(info) || ensure(info).anomalies.indexOf(id) >= 0 ) return true;
		var a = KubData.get().anomaly(id);
		if( a == null || !a.byBlocks ) return false;
		for( e in KubData.get().anomalyOwnBlocks(id) ) if( known(info, e) ) return true;
		return false;
	}

	/** se ha pasado cerca de una anomalia de ese tipo (GameView.updateAnomalies) */
	public static function encounter( info : SaveInfo, id : String ) {
		if( full(info) ) return;
		var k = ensure(info);
		if( k.anomalies.indexOf(id) >= 0 ) return;
		k.anomalies.push(id);
		if( onNews != null ) onNews({ title : KubText.get("kub.newanomaly"), name : KubData.get().anomalyName(id), colors : [Theme.ACCENT] });
	}

	/** receta descubierta: se ha recuperado uno de sus kubes */
	public static function recipeKnown( info : SaveInfo, r : CraftRule ) : Bool {
		if( full(info) ) return true;
		for( e in KubData.get().recipeBlocks(r) ) if( got(info, e) ) return true;
		return false;
	}

	public static function craftCount( info : SaveInfo, r : CraftRule ) : Int {
		for( c in ensure(info).crafts ) if( c.id == r.id ) return c.n;
		return 0;
	}

	public static function isFresh( info : SaveInfo, e : Block ) return !full(info) && ensure(info).fresh.indexOf(key(e)) >= 0;

	/** la ficha se ha mirado en la base de datos */
	public static function viewed( info : SaveInfo, e : Block ) if( e != null ) ensure(info).fresh.remove(key(e));

	/** cambia en cuanto cambia algo de lo que se ve en la base de datos (DatabasePanel: una pestana guardada se rehace) */
	public static function version( info : SaveInfo ) : String {
		var k = ensure(info), used = 0, made = 0;
		for( s in k.stats ) used += s.p + s.b;
		for( c in k.crafts ) made += c.n;
		return [k.seen.length, k.got.length, k.fresh.length, k.planets.length, k.comets.length, k.anomalies.length, used, made].join(",")
			+ (full(info) ? "+" : "");
	}

	// ---------------------------------------------------------------- lo que hace el jugador

	/** el laser toca el bloque b del mundo (cada imagen mientras dure: solo la primera cuenta) */
	public static function see( info : SaveInfo, b : Block ) {
		if( full(info) || b == null ) return;
		var k = ensure(info);
		if( lastSeen != null && lastSeen.kub == k && lastSeen.index == b.index ) return;
		lastSeen = { kub : k, index : b.index };
		var e = KubData.get().entryOrCharge(b);
		if( e == null || k.seen.indexOf(key(e)) >= 0 || k.got.indexOf(key(e)) >= 0 ) return;
		k.seen.push(key(e));
		k.fresh.push(key(e));
		news("kub.seen", e, Seen);
	}

	/** un kube llega al inventario (o se rompe uno que no suelta nunca nada) */
	public static function gain( info : SaveInfo, b : Block ) {
		if( full(info) || b == null ) return;
		var e = KubData.get().entryOrCharge(b);
		if( e == null ) return;
		var k = ensure(info), n = key(e);
		if( k.got.indexOf(n) >= 0 ) return;
		k.seen.remove(n);
		k.got.push(n);
		if( k.fresh.indexOf(n) < 0 ) k.fresh.push(n);
		news("kub.got", e, Got);
	}

	/** lo que hay en el inventario (bloques y cargas) queda recuperado; en cada cambio del inventario */
	public static function scan( info : SaveInfo, inv : Protocol.InventoryInfos ) {
		if( full(info) || inv == null ) return;
		for( s in inv.t ) if( s != null && s.n > 0 ) gain(info, Block.all[s.k]);
		for( c in inv.charges )
			if( c.n > 0 )
				for( b in KubData.get().charges ) if( Type.enumIndex(b.charge) == c.c ) gain(info, b);
	}

	/** los kubes de tu nave se conocen desde el principio: recuperados, sin aviso ni estrella (tambien tras cambiarla en el hangar) */
	public static function shipKnown( info : SaveInfo ) {
		if( full(info) ) return;
		var k = ensure(info), d = KubData.get();
		for( c in ShipData.load(Hangar.currentShip(info)).cells ) {
			var e = d.entryOf(Block.all[c.id]);
			if( e == null || k.got.indexOf(key(e)) >= 0 ) continue;
			k.seen.remove(key(e));
			k.fresh.remove(key(e));
			k.got.push(key(e));
		}
	}

	/** el jugador ha roto b con el laser: cuenta en sus estadisticas y, si no suelta nunca nada de lo suyo, queda recuperado */
	public static function broke( info : SaveInfo, b : Block ) {
		if( full(info) ) return;
		var d = KubData.get();
		var e = d.entryOf(b);
		if( e == null ) return;
		see(info, b);
		stat(info, e).b++;
		// solo el propio kube (no la nieve que esconde una planta ni la roca rota, que llevan la ficha de otro)
		if( b.getMain() == e && d.dropChance(b) == 0 ) gain(info, b);
	}

	public static function placed( info : SaveInfo, b : Block ) {
		if( full(info) ) return;
		var e = KubData.get().entryOf(b);
		if( e != null ) stat(info, e).p++;
	}

	public static function crafted( info : SaveInfo, r : CraftRule ) {
		if( full(info) || r == null ) return;
		for( c in ensure(info).crafts )
			if( c.id == r.id ) {
				c.n++;
				return;
			}
		info.kub.crafts.push({ id : r.id, n : 1 });
	}

	/** se juega en un planeta o una cometa: queda explorado (y su tipo descubierto) */
	public static function visit( info : SaveInfo ) {
		// la Ciudad muerta (nunca sale en el mapa) no esta en la base de datos
		if( full(info) || info.hangar == true || info.mothership == true || !KubData.get().biomeIndexed(info.biome) ) return;
		var k = ensure(info);
		var isNew = explored(info, info.biome) == 0;
		if( info.comet != null ) {
			for( c in k.comets ) if( c.sys == info.comet.sys && c.slot == info.comet.slot ) return;
			k.comets.push({ sys : info.comet.sys, slot : info.comet.slot, b : info.biome });
		} else {
			var id = info.uni != null ? info.uni.planetId : 0;
			for( p in k.planets ) if( p.id == id ) return;
			k.planets.push({ id : id, b : info.biome });
		}
		if( isNew && onNews != null )
			onNews({ title : KubText.get(info.comet != null ? "kub.newcomet" : "kub.newbiome"), name : ExpData.ExpOffline.biomeName(info.biome),
				colors : Data.getBiome(Type.createEnum(BiomeKind, info.biome)).exploreColors });
	}

	static function news( what : String, e : Block, st : KubState ) {
		if( onNews != null ) onNews({ title : KubText.get(what), name : e.getName(), block : e, state : st });
	}
}
