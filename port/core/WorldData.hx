import Common;

/**
 * Datos de un mundo (planeta, cometa o nave) sin nada de dibujo (anadido del port para el multijugador): celdas, generacion,
 * cambios guardados, agua y nivel del mar. El servidor usa esta clase tal cual; World la extiende con la luz, las mallas y el
 * cielo, y se entera de cada cambio por los ganchos (cellChanged, levelChanged, registerId y los de la bajada del mar), que
 * aqui no hacen nada. Las funciones son las de World antes de separarlas, con sus comentarios.
 */
class WorldData {

	public static inline var CSIZE = 16;
	public static inline var ZBITS = 7;
	public static inline var HEIGHT = 128;
	/** altura a partir de la que las coordenadas son de la nave */
	public static inline var SHIP_Z = 130;
	static inline var SEA_LEVEL = -1;
	static inline var SEA_FLOOD = -2;

	public var seed(default, null) : Int;
	public var biomeName(default, null) : String;
	public var size(default, null) : Int;
	var gen : gen.DetailsGenerator;
	/** id local de bloque de cada celda, dos bytes (los kubes del editor pueden pasar de 255 ids) */
	var cells : haxe.io.Bytes;

	/** cambios respecto al terreno generado: celda -> indice global del bloque (0 = aire) | nivel del agua << 16 */
	public var editMap = new Map<Int, Int>();
	var savedEdits : Array<Int>;
	/** nivel del agua puesta por el jugador en cada celda (sin entrada = fuente o agua del mar) */
	public var waterLvl = new Map<Int, Int>();
	var seaLevel = 0;
	public var waterTotal(default, null) = 0;
	public var waterFlood = 0;
	/** agua del bioma (la del mar) */
	public var seaBlock(default, null) : Block;
	var seaId = -1;
	/** agua del generador en cada altura (lo que desaparece si el mar baja esa capa) */
	var seaCount : Array<Int>;
	/** hay que bajar el mar (Local.processBlock: el agua puesta ha llegado al umbral) */
	public var floodFlag(default, null) = false;

	public var shipDX = 0;
	public var shipDY = 0;
	/** aviso de cada cambio de bloque (x, y, z ya dentro del mundo) */
	public var onSetBlock : Int -> Int -> Int -> Void;
	public var isShip(default, null) = false;
	var wraps = true;
	/** ids locales ya dados de alta en las tablas de registerId */
	var registered = 0;
	/** terreno generado y cambios guardados aplicados (genStep ha terminado) */
	var generated = false;

	/** genVersion: version del generador del planeta (SaveInfo.genVersion); null = la actual (gen.Generator.VERSION) */
	public function new( seed : Int, biomeName : String, sizeChunks : Int, ?savedEdits : Array<Int>, ?shipData : ShipData.ShipDataInfo, ?genVersion : Null<Int> ) {
		this.savedEdits = savedEdits;
		this.seed = seed;
		this.biomeName = biomeName;
		// las cometas (Comets, añadido del port) son mas pequenas: su tamano no va en trozos de 128 (la nave, con el bioma del
		// planeta, sigue en 128)
		var comet = shipData == null && CometRules.isComet(biomeName);
		size = comet ? CometRules.SIZE : sizeChunks << Const.BITS;
		var biome : BiomeKind = Type.createEnum(BiomeKind, biomeName);
		// el generador usa la memoria global (flash.Memory): no mientras otro hilo genera (genLock)
		genLock.acquire();
		gen = comet ? new CometGenerator(size, seed) : new gen.DetailsGenerator(size, seed);
		if( genVersion != null ) gen.version = genVersion;
		var bd = Data.getBiome(biome);
		gen.alloc(bd.water);
		gen.alloc(BMinIron);
		gen.alloc(BMinAluminium);
		for( s in bd.soils ) gen.alloc(s);
		if( shipData == null ) {
			gen.startGenerate(biome);
			seaLevel = gen.getWaterInfos().level;
			seaBlock = Block.get(bd.water);
		}
		else initShip(shipData);
		genLock.release();
		// como Builder.init: los modelos sin BFSize usan su propia caja para las colisiones
		for( b in Block.all )
			if( b.model != null && b.size == null ) b.size = Models.get(b.model).box;
	}

	/** anomalias puestas por el generador (DetailsGenerator.placed: posicion y tipo), para la Base de datos ESCorp */
	public function anomalies() return gen.placed;

	/** progreso del generador (0..1) */
	public function genProgress() : Float return gen.progress;

	public inline function isGenerated() return generated;

	/**
	 * Multijugador (anadido del port): aviso de cada mundo cuyo generador acaba de terminar, antes de usar su resultado (el
	 * terreno tal como sale, sin cambios). El anfitrion lo usa para que su servidor tome el planeta que su juego acaba de
	 * generar (adoptGenerated) en vez de generarlo otra vez en los mismos fotogramas.
	 */
	public static var onGenerated : WorldData -> Void;

	/**
	 * Un solo generador a la vez: Generator y FPerlin trabajan sobre una memoria global (flash.Memory, la que eligen al
	 * empezar cada process). El servidor genera sus planetas en otro hilo (PlanetInstance.generateAsync) mientras el juego del
	 * anfitrion puede estar generando el suyo; cada paso del generador (y su creacion) se hace con este cerrojo.
	 */
	public static var genLock(default, null) = new sys.thread.Mutex();

	/**
	 * Toma el terreno que src acaba de generar (llamado desde onGenerated: su generador ha terminado y aun no ha cambiado
	 * nada) si es el mismo planeta (semilla, bioma, tamano, version y tipo de generador): las celdas y lo del generador que se
	 * usa despues (bloques por id local, agua, anomalias), y sigue como genStep (cambios guardados). false si no es el mismo
	 * o este ya esta generado.
	 */
	public function adoptGenerated( src : WorldData ) : Bool {
		if( generated || isShip || src.isShip || src.seed != seed || src.biomeName != biomeName || src.size != size ) return false;
		var g = gen, sg = src.gen;
		if( g.version != sg.version || Type.getClass(g) != Type.getClass(sg) ) return false;
		g.blocks = sg.blocks.copy();
		g.btrans = sg.btrans.copy();
		var h = new IntHash<Int>();
		for( k in sg.hblocks.keys() ) h.set(k, sg.hblocks.get(k));
		g.hblocks = h;
		g.placed = sg.placed.copy();
		@:privateAccess {
			g.waterLevel = sg.waterLevel;
			g.waterLimit = sg.waterLimit;
			g.waterTotal = sg.waterTotal;
		}
		g.progress = 1;
		wideCells(sg.getBytes().b);
		initTables();
		if( savedEdits != null && savedEdits.length > 0 ) shipPlace();
		applySaved();
		generated = true;
		return true;
	}

	/**
	 * Genera el terreno (o pone las celdas de la nave) durante budgetMs desde t0 y, al acabar, aplica los cambios guardados.
	 * true cuando esta todo (World sigue entonces con la luz y las mallas).
	 */
	public function genStep( t0 : Float, budgetMs : Float ) : Bool {
		if( generated ) return true;
		if( isShip ) {
			if( shipCells != null && !placeCells(t0, budgetMs) ) return false;
			applySaved();
			generated = true;
			return true;
		}
		var p0 = gen.progress;
		genLock.acquire();
		var busy = false;
		try busy = gen.process(Std.int(budgetMs)) catch( e : Dynamic ) {
			genLock.release();
			throw e;
		}
		genLock.release();
		if( Sys.args().indexOf("--frametime") >= 0 && haxe.Timer.stamp() - t0 > 0.2 )
			Sys.println("generador: " + Std.int((haxe.Timer.stamp() - t0) * 1000) + " ms en un paso (progreso " + Std.int(p0 * 100) + "% -> " + Std.int(gen.progress * 100) + "%)");
		if( busy ) return false;
		if( onGenerated != null ) onGenerated(this);
		wideCells(gen.getBytes().b);
		initTables();
		// el sitio de la nave se elige antes de aplicar los cambios guardados: si no, con el suelo cavado o construido bajo
		// la nave, al cargar la partida la nave aparecia en otro sitio
		if( savedEdits != null && savedEdits.length > 0 ) shipPlace();
		applySaved();
		generated = true;
		return true;
	}

	// ---------------------------------------------------------------- ganchos de World (aqui no hacen nada)

	/** se ha cambiado el bloque de la celda key (x, y, z ya dentro del mundo) */
	function cellChanged( x : Int, y : Int, z : Int, key : Int ) {}

	/** mismo bloque, otro nivel de agua en x, y (setWater) */
	function levelChanged( x : Int, y : Int ) {}

	/** vacia las tablas por id local (antes de dar de alta todos los ids) */
	function resetTables() {}

	/** da de alta un id local en las tablas por id (tipo, luz) */
	function registerId( id : Int ) {}

	/** antes de bajar el mar (antes de tocar nada) */
	function beforeSeaDrop() {}

	/** empieza a quitar la capa z del mar (seaLevel ya es z - 1) */
	function seaDropStart( z : Int ) {}

	/** columna col, celda p de la capa: no era agua del mar y se queda (id) */
	function seaKept( col : Int, p : Int, id : Int ) {}

	/** columna col, celda p de la capa: era agua del mar y ya es aire */
	function seaRemoved( col : Int, p : Int ) {}

	/** la capa del mar ya esta quitada */
	function seaDropEnd() {}

	/** el volumen de la nave unido a este mundo (World.ship); en los datos solos no hay */
	function shipWorld() : WorldData return null;

	// ---------------------------------------------------------------- consulta de bloques

	/** id local del bloque de la celda p (p = ((x + y * size) << ZBITS) | z) */
	inline function cell( p : Int ) : Int return cells.getUInt16(p << 1);

	inline function setCell( p : Int, id : Int ) cells.setUInt16(p << 1, id);

	/** las celdas que da el generador (un byte cada una) en dos bytes */
	function wideCells( src : haxe.io.Bytes ) {
		var n = src.length;
		cells = haxe.io.Bytes.alloc(n << 1);
		var s = hl.Bytes.fromBytes(src), d = hl.Bytes.fromBytes(cells);
		for( p in 0...n ) d.setUI16(p << 1, s[p]);
	}

	public inline function voxel( x : Int, y : Int, z : Int ) : Int {
		if( x < 0 ) x += size else if( x >= size ) x -= size;
		if( y < 0 ) y += size else if( y >= size ) y -= size;
		if( z < 0 ) return 1;
		if( z >= HEIGHT ) return 0;
		return cell(((x + y * size) << ZBITS) | z);
	}

	/** tipo de bloque a efectos de mallado (las hojas sin BFNoOptimize cuentan como bloque lleno, igual que el original) */
	function tagOf( id : Int ) : BlockType {
		var b = gen.blocks[id];
		// con tarjeta grafica el original NO trata las hojas como bloques llenos (solo el modo por software lo hacia):
		// asi las caras que hay detras de una hoja se dibujan y se ven a traves de sus huecos transparentes
		return b.type;
	}

	/** bloque con el que se choca: usa el atributo collide del original (hojas si, agua y detalles no) */
	public inline function solid( x : Int, y : Int, z : Int ) : Bool {
		var id = voxel(x, y, z);
		if( id == 0 ) return false;
		var b = gen.blocks[id];
		return b != null && b.collide;
	}

	/** suelo opaco (para elegir el punto de aparicion) */
	public inline function opaque( x : Int, y : Int, z : Int ) : Bool {
		var id = voxel(x, y, z);
		return id != 0 && !gen.btrans[id];
	}

	/** bloque en una celda (null si es aire) */
	/** nivel del mar actual (planet.waterLevel del original): el del generador menos las capas que han desaparecido */
	public function waterLevel() : Int {
		return seaLevel;
	}

	public function block( x : Int, y : Int, z : Int ) : Block {
		if( z >= SHIP_Z ) return shipBlock(x, y, z);
		var id = voxel(x, y, z);
		return id <= 0 ? null : gen.blocks[id];
	}

	/** Igual que Level.collide del original: consulta de un punto, con la caja de los bloques parciales. */
	public function collidePoint( x : Float, y : Float, z : Float ) : Bool {
		if( z >= SHIP_Z ) {
			var ship = shipWorld();
			if( ship == null ) return false;
			var lx = shipLocal(x, shipDX), ly = shipLocal(y, shipDY);
			if( lx >= ship.size || ly >= ship.size ) return false;
			return ship.collidePoint(lx, ly, z - SHIP_Z);
		}
		var ix = Math.floor(x), iy = Math.floor(y), iz = Std.int(z);
		if( z < 0 || iz >= HEIGHT ) return false;
		var id = voxel(ix, iy, iz);
		if( id == 0 ) return false;
		var b = gen.blocks[id];
		if( b == null || !b.collide ) return false;
		if( b.size == null ) return true;
		var fz = z - iz;
		// cambio del port: un tableau (BFOnWall) solo choca con su placa; los demas bloques parciales, con todo el ancho de la celda
		if( b.wall >= 0 ) {
			var fx = x - ix, fy = y - iy;
			if( fx < b.size.x1 || fx >= b.size.x2 || fy < b.size.y1 || fy >= b.size.y2 ) return false;
		}
		return fz >= b.size.z1 && fz < b.size.z2;
	}

	/** altura de la superficie mas alta con colision (incluye copas de arboles) */
	public function topCollide( x : Int, y : Int ) : Int {
		var z = HEIGHT - 1;
		while( z > 1 && !solid(x, y, z) ) z--;
		return z + 1;
	}

	/** celdas libres de colision a partir de z (cabe el jugador: 3 bloques de alto) */
	function free( x : Int, y : Int, z : Int ) : Bool {
		for( k in 0...3 ) {
			var id = voxel(x, y, z + k);
			if( id != 0 && gen.blocks[id].collide ) return false;
		}
		return true;
	}

	public function spawnPoint(): { x : Float, y : Float, z : Float } {
		// busca en espiral desde el centro una columna cuyo punto mas alto sea suelo firme (no hojas ni modelos)
		var cx = size >> 1, cy = size >> 1;
		for( r in 0...40 )
			for( dy in -r...r + 1 )
				for( dx in -r...r + 1 ) {
					if( Math.abs(dx) != r && Math.abs(dy) != r ) continue;
					var x = cx + dx, y = cy + dy;
					var top = topCollide(x, y) - 1;
					var b = block(x, y, top);
					if( b != null && b.type == BTFull && !b.hasFlag(BFIsLava) && free(x, y, top + 1) )
						return { x : x + 0.5, y : y + 0.5, z : top + 1.01 };
				}
		var x = cx, y = cy;
		var z = HEIGHT - 1;
		while( z > 1 && !opaque(x, y, z) ) z--;
		return { x : x + 0.5, y : y + 0.5, z : z + 1.01 };
	}

	/**
	 * Suma Adler-32 de los indices globales de bloque de todas las celdas (anadido del port, multijugador): el cliente y el
	 * servidor la comparan para saber que tienen el mismo terreno
	 */
	public function cellHash() : String {
		var a = 1, b = 0;
		for( p in 0...size * size * HEIGHT ) {
			var id = cell(p);
			var gi = id == 0 ? 0 : gen.blocks[id].index;
			a = (a + (gi & 0xFF)) % 65521;
			b = (b + a) % 65521;
			a = (a + (gi >> 8)) % 65521;
			b = (b + a) % 65521;
		}
		return StringTools.hex(b, 4) + StringTools.hex(a, 4);
	}

	// ---------------------------------------------------------------- nave

	function initShip( d : ShipData.ShipDataInfo ) {
		isShip = true;
		wraps = false;
		cells = haxe.io.Bytes.alloc((size * size * HEIGHT) << 1);
		initTables();
		// las celdas se ponen en los primeros pasos de la carga (placeCells): las ~390 000 de la nave nodriza tardaban ~100 ms
		shipCells = d.cells;
		shipCell = 0;
	}

	/** celdas de la nave aun por poner (initShip) y la siguiente */
	var shipCells : Array<ShipData.ShipCell>;
	var shipCell = 0;

	/** pone celdas de la nave, en orden, hasta acabarlas o gastar el tiempo de este paso (empezado en t0); true si estan todas */
	function placeCells( t0 : Float, budgetMs : Float ) : Bool {
		var cells = shipCells;
		while( shipCell < cells.length ) {
			if( (haxe.Timer.stamp() - t0) * 1000 >= budgetMs ) return false;
			var end = shipCell + 8192 < cells.length ? shipCell + 8192 : cells.length;
			for( i in shipCell...end ) {
				var c = cells[i];
				setCell(((c.x + c.y * size) << ZBITS) | c.z, localId(Block.all[c.id]));
			}
			shipCell = end;
		}
		shipCells = null;
		return true;
	}

	/** coordenada de la nave que corresponde a una del planeta (el planeta da la vuelta) */
	function shipLocal( v : Float, d : Int ) : Float {
		var l = (v - d) % size;
		if( l < 0 ) l += size;
		return l;
	}

	function shipBlock( x : Int, y : Int, z : Int ) : Block {
		var ship = shipWorld();
		if( ship == null ) return null;
		var lx = Std.int(shipLocal(x, shipDX)), ly = Std.int(shipLocal(y, shipDY));
		if( lx >= ship.size || ly >= ship.size ) return null;
		return ship.block(lx, ly, z - SHIP_Z);
	}

	/** Level.getStartPlace del original: un sitio de tierra llana fuera del agua donde aterriza la nave (fijo por semilla) */
	public function startPlace( rnd : mt.Rand ) : { x : Int, y : Int, z : Int } {
		var biome : BiomeKind = Type.createEnum(BiomeKind, biomeName);
		var binf = Data.getBiome(biome);
		// cambio del port: con el nivel del mar del generador, no con el actual (el original usa planet.waterLevel): si no, tras
		// una bajada la nave podia aterrizar en otro sitio y una partida guardada dentro de ella quedaba en el aire
		var water = gen.getWaterInfos().level;
		// en una cometa (añadido del port) sobre su roca, que no tiene capa de tierra, y lejos del borde del mundo: la nave (17 de
		// ancho) solo se dibuja donde aterrizo, no en las copias del mundo que dan la vuelta (updateWrap)
		var comet = CometRules.isComet(biomeName);
		var soil = Block.get(binf.soils[comet ? 0 : 1]);
		var margin = comet ? 12 : 1;
		var through = new Map<Int, Bool>();
		for( b in binf.startThrough ) through.set(Block.get(b).index, true);
		var ntry = 10000;
		while( --ntry > 0 ) {
			var x = rnd.random(size - margin * 2) + margin;
			var y = rnd.random(size - margin * 2) + margin;
			var z = HEIGHT - 1;
			while( z > water ) {
				var b = block(x, y, z);
				if( b != null && !through.exists(b.index) ) break;
				z--;
			}
			if( z <= water ) continue;
			if( !block(x, y, z).isSame(soil) ) continue;
			z++;
			if( !freePlace(x, y, z) ) continue;
			return { x : x, y : y, z : z };
		}
		return null;
	}

	/** sitio de aterrizaje de la nave (Game.placeShip): fijo por semilla, elegido sobre el terreno generado */
	public function shipPlace() : { x : Int, y : Int, z : Int } {
		if( shipSpot == null ) shipSpot = startPlace(new mt.Rand(seed ^ 0x5A17));
		return shipSpot;
	}
	var shipSpot : { x : Int, y : Int, z : Int };

	/** casi plano: pocos huecos alrededor (Level.freePlace) */
	function freePlace( x : Int, y : Int, z : Int ) : Bool {
		var count = 0;
		for( dx in -1...2 )
			for( dy in -1...2 )
				if( block(x + dx, y + dy, z) != null ) count++;
		z--;
		for( dx in -1...2 )
			for( dy in -1...2 )
				if( block(x + dx, y + dy, z) == null ) count++;
		return count < 3;
	}

	// ---------------------------------------------------------------- edicion

	inline function wrapC( v : Int ) : Int {
		return v < 0 ? v + size : (v >= size ? v - size : v);
	}

	/** da de alta en las tablas por id todos los bloques que ya tiene el mundo */
	function initTables() {
		resetTables();
		registered = 0;
		for( i in 0...gen.blocks.length ) registerId(i);
		registered = gen.blocks.length;
	}

	/** id local (de este planeta) de un bloque global; lo da de alta si el mundo no lo tenia */
	public function localId( b : Block ) : Int {
		if( b == null ) return 0;
		var id = b.k == BKubeEditor ? editorId(b) : gen.alloc(b.k);
		for( i in registered...gen.blocks.length ) registerId(i);
		registered = gen.blocks.length;
		return id;
	}

	/** los kubes del editor (EditorKubes) comparten BlockKind: gen.alloc los confundiria; se dan de alta por su indice global */
	function editorId( b : Block ) : Int {
		var id = gen.hblocks.get(b.index);
		if( id != null ) return id;
		id = gen.blocks.length;
		gen.blocks.push(b);
		gen.btrans.push(b.type != BTFull && b.type != BTAlpha);
		gen.hblocks.set(b.index, id);
		return id;
	}

	function applySaved() {
		// el mar va antes que los cambios: las capas quitadas son del terreno generado y lo puesto despues se queda
		if( seaBlock != null ) {
			var level = seaLevel, flood = 0;
			if( savedEdits != null ) {
				var i = 0;
				while( i + 1 < savedEdits.length ) {
					if( savedEdits[i] == SEA_LEVEL ) level = savedEdits[i + 1];
					else if( savedEdits[i] == SEA_FLOOD ) flood = savedEdits[i + 1];
					i += 2;
				}
			}
			initSea(level, flood);
		}
		if( savedEdits == null ) return;
		var i = 0;
		while( i + 1 < savedEdits.length ) {
			var key = savedEdits[i], gi = savedEdits[i + 1];
			i += 2;
			if( key < 0 ) continue;
			var lvl = gi >> 16;
			var b = (gi & 0xFFFF) == 0 ? null : Block.all[gi & 0xFFFF];
			setCell(key, localId(b));
			editMap.set(key, gi);
			if( lvl > 0 ) waterLvl.set(key, lvl);
		}
		savedEdits = null;
	}

	/** cambios para guardar: pares [celda, bloque, celda, bloque, ...] */
	public function editsFlat() : Array<Int> {
		var out = [];
		for( k in editMap.keys() ) {
			out.push(k);
			out.push(editMap.get(k));
		}
		// el mar, si ha cambiado (las partidas sin estas claves cargan el del generador)
		if( seaBlock != null && (seaLevel != gen.getWaterInfos().level || waterFlood != 0) ) {
			out.push(SEA_LEVEL);
			out.push(seaLevel);
			out.push(SEA_FLOOD);
			out.push(waterFlood);
		}
		return out;
	}

	// ---------------------------------------------------------------- nivel del mar

	/**
	 * Al terminar de generar: el total de agua (Offline: planet.waterTotal), el agua de cada altura y, si la partida tenia el
	 * mar mas bajo, las capas que ya habian desaparecido (solo el agua del generador: lo cambiado despues esta en editMap).
	 */
	function initSea( level : Int, flood : Int ) {
		var gl = gen.getWaterInfos().level;
		waterTotal = gen.getWaterInfos().total;
		waterFlood = flood;
		seaId = localId(seaBlock);
		if( gl > HEIGHT - 2 ) gl = HEIGHT - 2;
		seaLevel = level < 0 ? 0 : (level > gl ? gl : level);
		seaCount = [for( _ in 0...gl + 1 ) 0];
		if( seaId <= 0 ) return;
		for( col in 0...size * size ) {
			var base = col << ZBITS;
			for( z in 1...gl + 1 ) {
				if( cell(base | z) != seaId ) continue;
				seaCount[z]++;
				if( z > seaLevel ) setCell(base | z, 0);
			}
		}
	}

	/** Local.processBlock: Process ha puesto un bloque del agua del bioma */
	public function addFlood() {
		waterFlood++;
		// cambio del port: sin mar (waterTotal = 0) el umbral seria 0 y cada bloque de agua bajaria un mar que no existe
		if( !floodFlag && waterTotal > 0 && waterFlood >= waterTotal / seaLevel ) floodFlag = true;
	}

	/** bloques de agua que faltan para la siguiente bajada (pruebas) */
	public function floodThreshold() : Int {
		return seaLevel <= 0 ? 0 : Math.ceil(waterTotal / seaLevel);
	}

	/**
	 * Local.reduceWater + Game.onCommand(SReduceWater): desaparece el agua del bioma de la capa z = nivel del mar en todo el
	 * planeta y el nivel baja 1; el contador pierde el agua que el generador puso en esa capa. La luz y las mallas (World) van
	 * en los ganchos seaDropStart, seaKept, seaRemoved y seaDropEnd.
	 */
	public function reduceWater() {
		floodFlag = false;
		var z = seaLevel;
		if( z <= 0 || seaCount == null ) return;
		beforeSeaDrop();
		// cambio del port: Local.reduceWater cuenta Type.enumIndex(BWater), no el agua del bioma, y en los otros biomas el
		// contador no bajaba nunca (cada bloque nuevo volvia a bajar el mar); aqui se cuenta el agua del bioma
		waterFlood -= z < seaCount.length ? seaCount[z] : 0;
		seaLevel--;
		var cols = size * size;
		seaDropStart(z);
		// las celdas de esa capa cambiadas en la partida (pocas) quedan como aire en el guardado; las del generador las vuelve a
		// quitar initSea al cargar
		for( k in [for( k in editMap.keys() ) if( (k & (HEIGHT - 1)) == z && cell(k) == seaId ) k] ) {
			editMap.set(k, 0);
			waterLvl.remove(k);
		}
		for( col in 0...cols ) {
			var p = (col << ZBITS) | z;
			var id = cell(p);
			if( id != seaId ) {
				seaKept(col, p, id);
				continue;
			}
			setCell(p, 0);
			seaRemoved(col, p);
		}
		seaDropEnd();
	}

	inline function cellKey( x : Int, y : Int, z : Int ) : Int {
		return ((wrapC(x) + wrapC(y) * size) << ZBITS) | z;
	}

	/** nivel del agua de la celda: 0 = fuente (llena), 1..7 = fluye (cada vez mas baja), 8 = cae */
	public function waterLevelAt( x : Int, y : Int, z : Int ) : Int {
		if( z < 1 || z >= HEIGHT ) return 0;
		var v = waterLvl.get(cellKey(x, y, z));
		return v == null ? 0 : v;
	}

	/** pone agua con su nivel (0 = fuente) */
	public function setWater( x : Int, y : Int, z : Int, b : Block, level : Int ) {
		if( z < 1 || z >= HEIGHT - 1 || z >= SHIP_Z ) return;
		var key = cellKey(x, y, z);
		if( block(x, y, z) != b ) setBlock(x, y, z, b);
		else levelChanged(x, y);
		if( level > 0 ) waterLvl.set(key, level) else waterLvl.remove(key);
		editMap.set(key, b.index | (level << 16));
	}

	/** Cambia un bloque (null = aire). World rehace el trozo al momento y la luz y los vecinos en los siguientes fotogramas. */
	public function setBlock( x : Int, y : Int, z : Int, b : Block ) : Void {
		if( z >= SHIP_Z ) {
			// la nave tiene su propio volumen
			var ship = shipWorld();
			if( ship != null ) ship.setBlock(Std.int(shipLocal(x, shipDX)), Std.int(shipLocal(y, shipDY)), z - SHIP_Z, b);
			return;
		}
		x = wrapC(x);
		y = wrapC(y);
		if( z < 1 || z >= HEIGHT - 1 ) return;
		var key = ((x + y * size) << ZBITS) | z;
		setCell(key, localId(b));
		editMap.set(key, b == null ? 0 : b.index);
		waterLvl.remove(key);
		cellChanged(x, y, z, key);
		if( onSetBlock != null ) onSetBlock(x, y, z);
	}
}
