package gen;
import Common;

private class CavePoint {
	public var x : Int;
	public var y : Int;
	public var z : Int;
	public var size : Int;
	public var dist : Int;
	public var links : Int;
	public var next : Array<CavePoint>;
	public function new(x, y, z, size) {
		this.x = x;
		this.y = y;
		this.z = z;
		this.size = size;
		next = [];
	}
}

private class Model {
	public var sx : Int;
	public var sy : Int;
	public var sz : Int;
	public var bytes : haxe.io.Bytes;
	public var blocks : Array<BlockKind>;
	public function new(sx, sy, sz, bytes) {
		this.sx = sx;
		this.sy = sy;
		this.sz = sz;
		this.bytes = bytes;
	}
}

class Generator {

	static inline var EMPTY = 0;
	static inline var BEDROCK = 1;
	static inline var WATER = 2;
	
	static inline var TMP = 128;
	static inline var TMASK = 127;
	static inline var CAVE = 128;
	
	static inline var MINERAL_COM = 3;
	static inline var MINERAL_RARE = 4;
	static inline var ROCK = 5;
	static inline var SOIL = 6;

	static inline var HBITS = Const.ZBITS;
	static inline var HEIGHT = Const.ZSIZE;

	/**
	 * Anadido del port: version de la generacion. Las partidas solo guardan los cambios del jugador y rehacen el planeta con su
	 * semilla (SaveInfo.genVersion: la version con la que se visito por primera vez).
	 * - 0: el generador del original (un solo azar para todo). Ya no existe: un planeta de version 0 se genera con la 1 y la
	 *   partida sale como "Ancienne partie" (World, GalaxyApp).
	 * - 1: azar por nombre (Rng, Generator.stream), estructuras en un registro (Structures) puestas por regiones, etapas en un
	 *   orden fijo. Anadir una estructura (Structures: since) solo cambia el planeta dentro de su caja.
	 * - 2: la lava y la cascada caen y se extienden tambien por lo que rompen al pasar en el juego (flowBreaks: hierbas, plantas,
	 *   cristales de hexalita...). Antes solo por el aire: se quedaban paradas encima o al lado de una hierba (addPropagate).
	 * Reglas: lo que cambie lo que genera el generador sube VERSION y solo se aplica con version >= la nueva (Structures: since /
	 * until); port/headless/gen_ref.txt: las lineas de las versiones que ya han salido no cambian nunca.
	 */
	public static inline var VERSION = 2;

	/**
	 * Anadido del port: la version mas antigua que se sigue generando tal cual. Un planeta de una anterior (la 0) se genera con
	 * esta y la partida sale como "Ancienne partie" (SaveData.isOldGeneration); uno de esta o de una posterior, con la suya
	 */
	public static inline var MIN_VERSION = 1;

	public var size(default,null) : Int;
	/** anadido del port: version con la que se genera este planeta (VERSION si no se dice otra) */
	public var version : Int;
	/**
	 * anadido del port: eventos del calendario activos al generar este planeta (CalendarEvents: los ids), que ponen sus
	 * estructuras (Structures: event). Vacio = ninguno (las pruebas y port/headless/gen_ref.txt)
	 */
	public var events : Array<String> = [];
	var seed : Int;
	/** el azar del paso o de la estructura en curso (Rng: por nombre, initStep, stream) */
	var rnd : Rng;
	/** vueltas a empezar de fillSoil (poca agua en un planeta grande): entra en todos los hashes (stream) */
	var attempt = 0;
	/** nombre del bioma (prefijo de los nombres de los pasos) */
	var biomeName = "";
	/** veces que se ha hecho cada paso (stepRetry: el nombre de la siguiente vez lleva "/rN") */
	var stepTries : Array<Int> = [];
	
	var perlin : FPerlin;
	var globalScale : Float;
	var curScale : Float;
	var realHeightMin : Float;
	var realHeightScale : Float;
	
	var outHeight : Int;
	var outPos : Int;
	var spentTime : Int;
	public var totalTime : Int;
	public var maxTime : Int;
	public var fast : Bool;
	
	var steps : Array<{ name : String, f : Void->Void, p : haxe.PosInfos }>;
	var curPosition : Int;
	
	var maxHeight : Int;
	var waterLevel : Int;
	var waterLimit : Int;
	var waterTotal : Int;
	
	public var progress : Float;
	
	public var blocks : Array<Block>;
	public var hblocks : IntHash<Int>;
	public var btrans : Array<Bool>;
	var models : Hash<Model>;
	
	public function new(size,seed) {
		this.size = size;
		this.seed = seed;
		version = VERSION;
		models = new Hash();
		perlin = new FPerlin(size);
		outHeight = perlin.buf.length;
		perlin.buf.length += size * size;
		outPos = perlin.buf.length;
		perlin.buf.length += size * size << HBITS;
		perlin.bind();
		blocks = [];
		btrans = [];
		steps = [];
		hblocks = new IntHash();
		alloc(BEmpty);
		alloc(BBedrock);
	}
	
	/**
	 * Azar de un nombre (Rng.hash de la semilla, el intento de fillSoil y el nombre): cada paso, estructura y bonus (cristales de
	 * hexalita) tiene el suyo, asi que lo que se anade o se quita no cambia el de los demas
	 */
	public function stream( name : String, a = 0, b = 0, c = 0 ) : Rng {
		return new Rng(Rng.hash(seed ^ (attempt << 20), name, a, b, c));
	}

	/** principio de un paso: su azar y la semilla del perlin, de su nombre */
	function initStep( name : String ) {
		rnd = stream(name);
		perlin.seed = Rng.hash(seed ^ (attempt << 20), name, 0x5EED) & 0x1FFFFFFF;
	}

	/**
	 * Anadido del port: los bloques reservados (numeros locales fijos: WATER 2, MINERAL_COM 3, MINERAL_RARE 4, ROCK 5, SOIL 6),
	 * antes en World, GenMain y RenderMain. Un bioma sin suelos (BIShed) usa roca y tierra: si no, el siguiente alloc se quedaba
	 * con el numero 5 y la lava de fillLava se tomaba por ROCK (el hangar de tamano 3 no acababa nunca)
	 */
	public function reserveBlocks( biome : BiomeKind ) {
		var bd = Data.getBiome(biome);
		alloc(bd.water);
		alloc(BMinIron);
		alloc(BMinAluminium);
		var soils = bd.soils != null && bd.soils.length >= 2 ? bd.soils : [BRock, BSoil];
		for( s in soils ) alloc(s);
	}
	
	public function forceBlock( b : BlockKind ) {
		hblocks.remove(Type.enumIndex(b));
	}
	
	public function alloc( b : BlockKind ) {
		var bid = Type.enumIndex(b);
		var id = hblocks.get(bid);
		if( id != null ) return id;
		id = blocks.length;
		var b = Block.all[bid];
		blocks.push(b);
		btrans.push( b.type != BTFull && b.type != BTAlpha);
		hblocks.set(bid, id);
		// mientras se genera, el numero local va en 7 bits (el octavo es TMP / CAVE); despues World guarda 2 bytes por celda
		if( id > TMASK && curPosition < steps.length ) throw "demasiados bloques en el generador: " + id;
		// lo que cubre o se propaga se hace en una sola pasada al final (coverAll)
		return id;
	}
	
	public function getKind(bid:Int) {
		return null;
	}
	
	function randMineral() {
		return rnd.random(5) == 0 ? MINERAL_RARE : MINERAL_COM;
	}
	
	public function getWaterInfos() {
		return { level : waterLevel, total : waterTotal };
	}

	inline function addr(x, y, z) {
		return ((x + y * size) << HBITS) | z;
	}
	
	inline function fset(addr, v) {
		if( tracking ) trackCell(addr, v);
		perlin.setByte(addr + outPos, v);
	}

	// ---------------------------------------------------------------- lo que cambia una estructura (anadido del port)

	/** se esta poniendo una estructura (DetailsGenerator.pose): cada celda y altura que cambia agranda su caja */
	var tracking = false;
	/** origen de la estructura (la caja va respecto a el, con realDist: sigue bien en el borde del mapa) */
	var trackX = 0;
	var trackY = 0;
	/** caja: x0, y0, z0, x1, y1, z1 (incluidos) */
	var trackBox : Array<Int>;
	/** celdas y alturas cambiadas */
	var trackChanged = 0;
	/** algunas celdas puestas (direccion, valor), para ver al final si otra estructura la ha tapado */
	var trackSamples : Array<Int>;
	static inline var TRACK_SAMPLES = 48;

	function beginTrack( x : Int, y : Int ) {
		tracking = true;
		trackX = real(x);
		trackY = real(y);
		trackBox = null;
		trackChanged = 0;
		trackSamples = [];
	}

	function endTrack() {
		tracking = false;
	}

	inline function trackPoint( dx : Int, dy : Int, z0 : Int, z1 : Int ) {
		var b = trackBox;
		if( b == null ) trackBox = [dx, dy, z0, dx, dy, z1];
		else {
			if( dx < b[0] ) b[0] = dx;
			if( dy < b[1] ) b[1] = dy;
			if( z0 < b[2] ) b[2] = z0;
			if( dx > b[3] ) b[3] = dx;
			if( dy > b[4] ) b[4] = dy;
			if( z1 > b[5] ) b[5] = z1;
		}
	}

	function trackCell( addr : Int, v : Int ) {
		if( fget(addr) == v ) return;
		var c = addr >> HBITS, z = addr & (HEIGHT - 1);
		trackPoint(realDist((c % size) - trackX), realDist(Std.int(c / size) - trackY), z, z);
		trackChanged++;
		// muestras repartidas: las primeras y luego una de cada vez mas
		if( trackSamples.length < TRACK_SAMPLES * 2 || trackChanged % (trackChanged >> 4) == 0 ) {
			if( trackSamples.length >= TRACK_SAMPLES * 2 ) trackSamples.splice(0, 2);
			trackSamples.push(addr);
			trackSamples.push(v);
		}
	}

	function trackHeight( x : Int, y : Int, old : Int, v : Int ) {
		if( old == v ) return;
		trackPoint(realDist(real(x) - trackX), realDist(real(y) - trackY), old < v ? old : v, old < v ? v : old);
		trackChanged++;
	}

	inline function set(x, y, z, v) {
		if( z > 0 && z < HEIGHT )
			fset(((real(x) + real(y) * size) << HBITS) | z, v);
	}
	
	inline function get(x, y, z) {
		if( z < 0 ) return BEDROCK;
		if( z >= HEIGHT ) return EMPTY;
		return fget(((real(x) + real(y) * size) << HBITS) | z);
	}
	
	function oset(x, y, z, v) {
		if( z > 0 && z < HEIGHT ) {
			var addr = ((real(x) + real(y) * size) << HBITS) | z;
			if( fget(addr) == EMPTY ) {
				fset(addr, v);
				return true;
			}
		}
		return false;
	}
	
	inline function fget(addr) {
		return perlin.byte(addr + outPos);
	}

	/**
	 * Anadido del port: la primera celda del mundo en [start, end) que vale v (o end), en un bucle cerrado sobre el tampon: para
	 * recorrer todo el mundo buscando un bloque en el mismo orden (las mismas tiradas de rnd) sin pagar fget celda a celda
	 */
	inline function findCell( start : Int, end : Int, v : Int ) : Int {
		#if (hl && !genCheck)
		var m = perlin.mem, o = outPos, i = start + o, e = end + o;
		while( i < e && m.getUI8(i) != v ) i++;
		return i - o;
		#else
		var i = start;
		while( i < end && fget(i) != v ) i++;
		return i;
		#end
	}

	/** la primera celda del mundo en [start, end) que vale v o w (o end) */
	inline function findCell2( start : Int, end : Int, v : Int, w : Int ) : Int {
		#if (hl && !genCheck)
		var m = perlin.mem, o = outPos, i = start + o, e = end + o;
		while( i < e ) {
			var c = m.getUI8(i);
			if( c == v || c == w ) break;
			i++;
		}
		return i - o;
		#else
		var i = start;
		while( i < end ) {
			var c = fget(i);
			if( c == v || c == w ) break;
			i++;
		}
		return i;
		#end
	}

	/** n celdas seguidas del mundo a v, desde addr (anadido del port: fill del tampon en vez de fset una a una) */
	inline function fillCells( addr : Int, n : Int, v : Int ) {
		#if (hl && !genCheck)
		if( n > 0 ) perlin.mem.fill(addr + outPos, n, v);
		#else
		for( i in 0...n ) fset(addr + i, v);
		#end
	}

	inline function hval(addr) {
		return perlin.byte(addr + outHeight);
	}
	
	inline function height(x, y) {
		return hval(real(x) + real(y) * size);
	}

	inline function setHeight(x, y, v) {
		if( tracking ) trackHeight(x, y, height(x, y), v);
		perlin.setByte(real(x) + real(y) * size + outHeight, v);
	}
	
	inline function hash(n) {
		for( i in 0...3 ) {
			n ^= (n << 7) & 0x2b5b2500;
			n ^= (n << 15) & 0x1b8b0000;
			n ^= n >>> 16;
			n &= 0x3FFFFFFF;
			var h = 5381 + perlin.seed;
			h = (h << 5) + h + (n & 0xFF);
			h = (h << 5) + h + ((n >> 8) & 0xFF);
			h = (h << 5) + h + ((n >> 16) & 0xFF);
			h = (h << 5) + h + (n >> 24);
			n = h & 0x3FFFFFFF;
		}
		return n & 0x1FFFFFFF;
	}
	
	inline function realHeight(p) {
		return perlin.double(perlin.outOffset + (p << 3));
	}

	function setRealHeight(x, y, v) {
		var p = real(x) + real(y) * size;
		if( tracking && realHeight(p) != v ) trackHeight(x, y, 0, height(x, y) + 1);
		perlin.setDouble(perlin.outOffset + (p << 3), v);
	}
	
	inline function real(v) {
		if( v < 0 ) v += size;
		if( v >= size ) v -= size;
		return v;
	}
	
	function initPerlin( scale : Float ) {
		perlin.seed++;
		curScale = perlin.initScale(globalScale * scale);
	}
	
	inline function perlin2D( x : Float, y : Float ) {
		return perlin.gradient2DAt(x * curScale, y * curScale);
	}

	inline function perlin3D( x : Float, y : Float, z : Float ) {
		return perlin.gradient3DAt(x * curScale, y * curScale, z * curScale);
	}
	
	/**
	 * Los pasos del planeta, en un orden fijo (version 1): el terreno del bioma (initBiome; los relieves van dentro de fillSoil),
	 * las estructuras de las grutas, las de la superficie, los bonus (cristales de hexalita), las del aire, una sola pasada de lo
	 * que cubre o se propaga (coverAll), el agua (checkWater) y la roca madre
	 */
	public function startGenerate( biome : BiomeKind ) {
		spentTime = 0;
		maxTime = 0;
		totalTime = 0;
		progress = 0;
		biomeName = Type.enumConstructor(biome);
		rnd = stream("start");
		perlin.init(seed, 0, 0);
		steps = [];
		initBiome(biome);
		addStep("caves", stageCave);
		addStep("surface", stageSurface);
		addStep("bonus", addBonus);
		addStep("air", stageAir);
		addStep("cover", coverAll);
		addStep("checkWater", checkWater);
		addStep("fillBedrock", fillBedrock);
		globalScale *= 1 / 180;
	}

	/** etapas de las estructuras y de los bonus, los cristales de hexalita (DetailsGenerator) */
	function stageRelief() {
	}

	function stageCave() {
	}

	function stageSurface() {
	}

	function stageAir() {
	}

	function addBonus() {
	}

	/** las celdas CAVE al llegar a saveCaveMask (un bit cada una), para la etapa de las grutas (DetailsGenerator.stageCave) */
	var caveMask : haxe.io.Bytes;

	/**
	 * Version 1: donde los biomas ponian sus estructuras de gruta (addCaveDetails) se guardan las celdas CAVE; las estructuras y
	 * los bonus (cristales de hexalita) de las grutas se ponen despues de todo el terreno, en su etapa (stageCave)
	 */
	function saveCaveMask() {
		var total = size * size * HEIGHT;
		caveMask = haxe.io.Bytes.alloc((total >> 3) + 1);
		gcFree(true);
		var addr = findCell(0, total, CAVE);
		while( addr < total ) {
			caveMask.set(addr >> 3, caveMask.get(addr >> 3) | (1 << (addr & 7)));
			addr = findCell(addr + 1, total, CAVE);
		}
		gcFree(false);
	}

	/**
	 * Anadido del port (paso 5): alrededor de un bucle largo que solo lee y escribe bytes (ni reserva memoria ni guarda referencias).
	 * El recolector de HashLink espera a que todos los hilos esten parados: un bucle asi, en el hilo de World, hacia esperar al
	 * principal. Con hl.Gc.blocking(true) no lo espera; con false, si hay una recoleccion en curso, este hilo espera a que acabe.
	 * Nada dentro puede reservar memoria (si no, el recolector no veria lo reservado); nada de esto cambia el mundo
	 */
	inline function gcFree( b : Bool ) {
		#if hl
		hl.Gc.blocking(b);
		#end
	}

	/** un paso con nombre (Macro.generate pone "funcion#n"): su azar sale de el y del bioma (initStep) */
	function addStep( name : String, f : Void -> Void, ?p : haxe.PosInfos ) {
		steps.push( { name : name, f : f, p : p } );
	}

	/** el paso que toca, entero: su azar (con "/rN" si se repite: stepRetry) y su funcion */
	function runStep( i : Int ) {
		var s = steps[i];
		while( stepTries.length <= i ) stepTries.push(0);
		var n = stepTries[i];
		stepTries[i] = n + 1;
		initStep(biomeName + "/" + s.name + (n == 0 ? "" : "/r" + n));
		s.f();
	}

	/** nombre del paso i (GenMain --steps) */
	public function stepName( i : Int ) : String {
		var s = steps[i];
		return s == null ? null : s.name;
	}
	
	/** anadido del port: el paso que toca (fichero y linea de su addStep); null al acabar */
	public function getCurrentStep() {
		var s = steps[curPosition];
		if( s == null ) return null;
		return s.p;
	}
	
	function stepRetry() {
		curPosition--;
	}

	/** pasadas de smooth3D como mucho (version 1: antes hasta que no cambiara nada; en el original salian de 1 a 8) */
	static inline var SMOOTH_PASSES = 8;

	/** otra pasada de smooth3DLater si la ultima cambio algo y no se han hecho ya SMOOTH_PASSES (una mas no cambiaria nada) */
	function smoothAgain( changed : Int ) {
		if( changed > 0 && stepTries[curPosition - 1] < SMOOTH_PASSES ) stepRetry();
	}
	
	function initBiome(biome:BiomeKind) {
	}
	
	/**
	 * Anadido del port (version 1): lo que cubre (tierra -> tierra con hierba) o se propaga (cae o se extiende), en una sola pasada
	 * despues de todas las estructuras, sobre todos los bloques del planeta por orden de nombre. Antes cada alloc ponia su paso
	 * al final, en el orden de los alloc: una estructura nueva cambiaba lo que se hacia despues en todo el planeta
	 */
	function coverAll() {
		var i = 0;
		while( i < blocks.length ) {
			var b = blocks[i++];
			if( b.covered != null ) alloc(b.covered.k);
			if( b.propagate != null ) alloc(b.propagate.k);
		}
		var ids = [for( id in 0...blocks.length ) if( blocks[id].covered != null || blocks[id].propagate != null ) id];
		ids.sort(function(a, b) return Reflect.compare(Type.enumConstructor(blocks[a].k), Type.enumConstructor(blocks[b].k)));
		for( id in ids ) {
			var b = blocks[id];
			if( b.covered != null ) addCover(id, alloc(b.covered.k));
			if( b.propagate != null ) {
				var tid = alloc(b.propagate.k);
				addPropagate(id, tid, b.hasFlag(BFFallCopy) ? id : tid);
			}
		}
	}

	function addCover( bid : Int, bid2 : Int ) {
		perlin.select();
		var transp = btrans;
		var addr = 0;
		gcFree(true);
		for( y in 0...size )
			for( x in 0...size ) {
				addr += HEIGHT - 1;
				var over = EMPTY;
				for( z in 1...HEIGHT ) {
					var b = fget(addr);
					if( b == bid && (over == EMPTY || transp[over])  )
						fset(addr, bid2);
					over = b;
					addr--;
				}
				addr += HEIGHT;
			}
		gcFree(false);
	}
	
	/**
	 * Anadido del port: lo que un liquido que cae o se extiende (lava, cascada) rompe al pasar en el juego (WorldProcess.canPropagate):
	 * hierbas y plantas (BTModel2Side), modelos y bloques reducidos y, para la lava, lo que no choca. Nunca otro liquido
	 */
	public static function flowBreaks( liquid : Block, t : Block ) : Bool {
		if( t.type == BTWater || t.propagate != null || t.hasProp(PLiquid) || t.hasProp(PLava) ) return false;
		return switch( t.type ) {
		case BTModel, BTModel2Side, BTReduced: true;
		default: !t.collide && !liquid.hasProp(PLiquid);
		}
	}

	function addPropagate( bid : Int, bid2 : Int, fallId : Int ) {
		// version 2: las celdas de lo que este liquido rompe al pasar (flowBreaks) cuentan como aire
		var brk = new haxe.ds.Vector<Bool>(256);
		for( t in 0...256 ) brk[t] = t == EMPTY || (version >= 2 && t < blocks.length && flowBreaks(blocks[bid], blocks[t]));
		perlin.select();
		var addr = 0;
		gcFree(true);
		for( y in 0...size )
			for( x in 0...size ) {
				addr += HEIGHT;
				for( z in 0...HEIGHT ) {
					var b = fget(--addr);
					if( b == bid ) {
						if( z < HEIGHT - 1 && (brk[fget(addr - 1)] || fget(addr-1) == fallId) )
							fset(addr - 1, fallId);
						else if( bid2 != bid ) {
							if( brk[fget(addr + HEIGHT * minusOne(x))] )
								fset(addr + HEIGHT * minusOne(x), bid2);
							if( brk[fget(addr + HEIGHT * plusOne(x))] )
								fset(addr + HEIGHT * plusOne(x), bid2);
							if( brk[fget(addr + HEIGHT * minusOne(x))] )
								fset(addr + HEIGHT * minusOne(x), bid2);
							if( brk[fget(addr + HEIGHT * size * plusOne(y))] )
								fset(addr + HEIGHT * size * plusOne(y), bid2);
							if( brk[fget(addr + HEIGHT * size * minusOne(y))] )
								fset(addr + HEIGHT * size * minusOne(y), bid2);
						}
					}
				}
				addr += HEIGHT;
			}
		gcFree(false);
	}
	
	#if genDebug
	public static function dbg( s : String ) {
		#if flash
		flash.Lib.trace(s);
		#else
		Sys.println(s);
		#end
	}
	#end

	/**
	 * Anadido del port: lo que queda de un paso largo, repartido entre varias llamadas a process (en el juego, unos ms por
	 * imagen): un paso de 100-300 ms paraba la pantalla de carga. process llama al trabajo de arriba hasta que devuelve false
	 * (un trabajo puede poner otro encima y esperarlo) antes de pasar al paso siguiente. Entre medias no hay initStep ni nada
	 * que toque el mundo, el perlin o el azar: mismo orden de calculo, mismo mundo.
	 */
	var jobs : Array<Void -> Bool> = [];

	/** f(0) ... f(n - 1), una por llamada (y los trabajos que ponga cada una), y luego done */
	function spread( n : Int, f : Int -> Void, ?done : Void -> Void ) {
		var i = 0;
		jobs.push(function() {
			if( i < n ) {
				f(i++);
				return true;
			}
			if( done != null ) done();
			return false;
		});
	}

	function runJob() {
		var j = jobs[jobs.length - 1];
		if( !j() ) jobs.remove(j);
	}

	/**
	 * Anadido del port (GenMain --profile / --steps / genDebug): si no es null, cada paso se hace entero, con sus trabajos, y
	 * luego se llama con su numero, su addStep y lo que ha tardado en ms. No cambia el mundo.
	 */
	public var onStep : Int -> haxe.PosInfos -> Float -> Void;

	/**
	 * Anadido del port (GenMain --steps): sumas Adler-32 de las alturas y de las alturas reales (cada 3 bytes), y una suma
	 * (h * 31 + c, 32 bits: cualquier celda cambiada la cambia) de todas las celdas del mundo, cada una con el nombre de su
	 * bloque (blocks[id].k) en vez de su numero local, que depende del orden de los alloc; los bits TMP / CAVE cuentan aparte.
	 */
	public function stepSums() : String {
		perlin.select();
		var code = new haxe.ds.Vector<Int>(256);
		for( v in 0...256 ) {
			var id = v & TMASK;
			var n = id < blocks.length ? Type.enumConstructor(blocks[id].k) : "#" + id;
			var h = 5381;
			for( i in 0...n.length ) h = ((h << 5) + h + StringTools.fastCodeAt(n, i)) & 0xFFFF;
			code[v] = h | ((v & TMP) << 9);
		}
		var w = 0, i = outPos, end = outPos + (size * size << HBITS);
		while( i < end )
			w = (w << 5) - w + code[perlin.byte(i++)];
		// mezcla final (cada paso se puede deshacer: dos sumas distintas siguen siendo distintas)
		w ^= w >>> 16;
		w ^= w << 11;
		w ^= w >>> 7;
		var ha = 1, hb = 0;
		for( j in 0...size * size ) {
			ha = (ha + perlin.byte(outHeight + j)) % 65521;
			hb = (hb + ha) % 65521;
		}
		var da = 1, db = 0, j = perlin.outOffset;
		var dend = perlin.outOffset + size * size * 8;
		while( j < dend ) {
			da = (da + perlin.byte(j)) % 65521;
			db = (db + da) % 65521;
			j += 3;
		}
		return "heights=" + StringTools.hex(ha, 4) + StringTools.hex(hb, 4) + " doubles=" + StringTools.hex(da, 4) + StringTools.hex(db, 4) + " world=" + StringTools.hex(w, 8);
	}

	public function process( maxTimeSlice = 100 ) {
		var t0 = flash.Lib.getTimer();
		perlin.select();
		if( curPosition >= steps.length && jobs.length == 0 ) {
			return false;
		}
		while( true ) {
			var t = flash.Lib.getTimer();
			if( jobs.length > 0 )
				runJob();
			else {
				var cur = steps[curPosition];
				curPosition++;
				stepRuns++;
				if( onStep == null )
					runStep(curPosition - 1);
				else {
					// el paso entero, con sus trabajos (entre ellos no se toca nada mas: mismo mundo)
					var st = haxe.Timer.stamp();
					runStep(curPosition - 1);
					while( jobs.length > 0 ) runJob();
					onStep(curPosition - 1, cur.p, (haxe.Timer.stamp() - st) * 1000);
					perlin.select();
				}
			}
			var t2 = flash.Lib.getTimer();
			spentTime += t2 - t;
			var dt = t2 - t0;
			if( dt > maxTime ) maxTime = dt;
			var p = curPosition / steps.length;
			progress = p;
			if( dt >= maxTimeSlice || (curPosition >= steps.length && jobs.length == 0) ) {
				totalTime += dt;
				break;
			}
		}
		return true;
	}
	
	inline function minusOne(v) {
		return v == 0 ? size - 1 : -1;
	}

	inline function plusOne(v) {
		return v == size-1 ? 1-size : 1;
	}

	/** la coordenada anterior (x - 1 o y - 1, dando la vuelta al mapa) */
	inline function prevC(v) {
		return v == 0 ? size - 1 : v - 1;
	}
	
	inline function addHeight( scale : Float, power : Float ) {
		perlin.add(scale * globalScale, power);
		return power;
	}
	
	inline function addMulHeight( add : Float, mul : Float ) {
		perlin.addMul(add, mul);
	}
	
	function adjustHeight( scale : Float, delta : Float ) {
		perlin.adjust(scale * globalScale, delta);
	}
	
	function fillHeight( levels : Array<{ v : Float, h : Int }> ) {
		var wh = waterLevel;
		var heights = new flash.Vector<Int>();
		maxHeight = 0;
		var hmin = levels[0].v;
		var hmax = levels[levels.length - 1].v;
		var hscale = 65535 / (hmax - hmin);
		this.realHeightMin = hmin;
		this.realHeightScale = hscale;
		var pos = 0;
		var prev = levels[0];
		var lastHeight = 0;
		for( h in levels ) {
			var target = Std.int((h.v - hmin) * hscale);
			if( target > pos ) {
				var cur = 0.;
				var dt = 1. / (target - pos);
				while( pos < target ) {
					var h = Std.int(prev.h * (1 - cur) + h.h * cur + wh);
					if( h >= HEIGHT ) h = HEIGHT - 1;
					if( h > maxHeight ) maxHeight = h;
					lastHeight = h;
					heights[pos++] = h;
					cur += dt;
				}
			}
			prev = h;
		}
		while( pos < 65536 )
			heights[pos++] = lastHeight;
	
		waterLimit = 65536;
		for( i in 0...65536 )
			if( heights[i] > wh+1 ) {
				waterLimit = i-1;
				break;
			}
				
		for( p in 0...size * size ) {
			var fh = Std.int((realHeight(p) - realHeightMin) * realHeightScale);
			if( fh < 0 ) fh = 0 else if( fh > 0xFFFF ) fh = 0xFFFF;
			perlin.setByte(outHeight + p, heights[fh]);
		}
	}
	
	inline function removeBlock( b : BlockKind ) {
		replaceBlock(alloc(b), EMPTY);
	}
	
	function replaceBlock( b : Int, by : Int ) {
		for( i in 0...size * size * HEIGHT )
			if( fget(i) == b )
				fset(i, by);
	}
	
	function replaceSomeBlocks( b:BlockKind, by:BlockKind, pctChance:Int ) {
		var b = alloc(b);
		var by = alloc(by);
		for( i in 0...size * size * HEIGHT )
			if( fget(i) == b && rnd.random(100)<pctChance )
				fset(i, by);
	}

	/** replaceSomeBlocks repartido, una fila y de columnas por llamada (anadido del port, ver jobs): mismo orden de celdas */
	function replaceSomeBlocksLater( b:BlockKind, by:BlockKind, pctChance:Int ) {
		var b = alloc(b);
		var by = alloc(by);
		spread(size, function(y) {
			var end = (y + 1) * size * HEIGHT;
			var i = findCell(y * size * HEIGHT, end, b);
			while( i < end ) {
				if( rnd.random(100)<pctChance )
					fset(i, by);
				i = findCell(i + 1, end, b);
			}
		});
	}
	
	function around(x, y, z, b) {
		return get(x - 1, y, z) == b || get(x + 1, y, z) == b || get(x, y - 1, z) == b || get(x, y + 1, z) == b || get(x, y, z - 1) == b || get(x, y, z + 1) == b;
	}
	
	function free(x, y, z, dx, dy, dz) {
		for( dx in 0...dx )
			for( dy in 0...dy )
				for( dz in 0...dz )
					if( get(x + dx, y + dy, z + dz) != EMPTY )
						return false;
		return true;
	}

	
	/** vueltas a empezar de fillSoil como mucho (si no, se queda con lo que salga) */
	static inline var MAX_ATTEMPTS = 8;

	function fillSoil( minWater : Float ) {
		stageRelief();
		var wh = waterLevel;
		// fill soil
		initPerlin(4);
		var hscale = 0.9 * (maxHeight - wh);
		var p = -1;
		var water = 0;
		gcFree(true);
		for( y in 0...size )
			for( x in 0...size ) {
				var h = hval(++p);
				var rnd = perlin2D(x, y);
				var rock = h - Std.int((rnd + hscale / h) * 4);
				if( rock < 0 ) rock = 0;
				if( rock > h ) rock = h;
				var addr = p << HBITS;
				fillCells(addr, rock, ROCK);
				fillCells(addr + rock, h - rock, SOIL);
				addr += h;
				if( (realHeight(p) - realHeightMin) * realHeightScale < waterLimit )
					for( i in h...wh+1 ) {
						fset(addr++, WATER);
						water++;
					}
			}
		gcFree(false);
		var w = water / (size * size);
		if( w < minWater && size > 128 && attempt < MAX_ATTEMPTS - 1 ) {
			// poca agua: otra vez desde el principio, con otro azar en todos los pasos (attempt entra en stream)
			attempt++;
			perlin.clear();
			fillCells(0, size * size * HEIGHT, 0);
			curPosition = 0;
			stepTries = [];
			jobs = [];
		}
	}

	function addHoles( hsize : Float, levels : Array<{ h : Int, v : Float }>, ?block=EMPTY ) {
		var row = holesRow(hsize, levels, block);
		for( y in 0...size )
			row(y);
	}

	/** addHoles repartido, una fila por llamada (anadido del port, ver jobs) */
	function addHolesLater( hsize : Float, levels : Array<{ h : Int, v : Float }>, ?block=EMPTY ) {
		spread(size, holesRow(hsize, levels, block));
	}

	/** lo de antes de las filas de addHoles (perlin y alturas) y la funcion que hace la fila y */
	function holesRow( hsize : Float, levels : Array<{ h : Int, v : Float }>, block : Int ) : Int -> Void {
		initPerlin(hsize);
		var heights = new flash.Vector<Float>();
		var cur = 0;
		var prev = { h : 0, v : -1. };
		var hmax = 0;
		for( h in 0...255 ) {
			var l = levels[cur];
			var v = prev.v + (l.v - prev.v) * ((h - prev.h) / (l.h - prev.h));
			if( l == prev ) v = prev.v;
			heights.push(v);
			if( v > -1 )
				hmax = h;
			while( l.h <= h ) {
				prev = l;
				if( cur == levels.length - 1 )
					break;
				l = levels[++cur];
			}
		}
		var hstart = levels[0].h;
		return function( y : Int ) {
			for( x in 0...size ) {
				var p = x + y * size;
				var h = height(x, y);
				if( h < hstart || h > hmax )
					continue;
				var h = hval(p);
				var min = hstart + 1;
				var addr = (p << HBITS) + min;
				// cada pasada se para en la primera celda vacia de la columna, como el original: las 100 pasadas de Marte solo
				// agrandan por debajo lo que dejo la primera, y quedan los pilares y las grietas estrechas bajo las arenas movedizas
				for( z in min...h ) {
					if( fget(addr) == EMPTY )
						break;
					if( perlin3D(x, y, z) < heights[z] )
						fset(addr, block);
					addr++;
				}
			}
		};
	}
	
	/**
	 * Quita lo que flota: se marca (TMP) lo que hay por encima del primer vacio de cada columna, se desmarca lo que toca algo
	 * apoyado y lo que toca eso, y se borra lo que queda marcado. Version 1: un solo relleno (antes varias pasadas de
	 * removeBlobRec con stepRetry, que llegaban a lo mismo salvo en el borde del mapa)
	 */
	function removeBlobs() {
		gcFree(true);
		for( y in 0...size )
			for( x in 0...size ) {
				var addr = (x + y * size) << HBITS;
				for( z in 0...HEIGHT ) {
					var b = fget(addr++);
					if( b == CAVE )
						fset(addr-1,EMPTY);
					else if( b != EMPTY )
						continue;
					// mark upper part as to-do
					for( i in z + 1...HEIGHT ) {
						var b = fget(addr);
						if( b == CAVE )
							fset(addr, EMPTY);
						else if( b != EMPTY )
							fset(addr, b | TMP);
						addr++;
					}
					break;
				}
			}
		gcFree(false);
		// lo marcado que toca algo apoyado (lleno y sin TMP), y desde ahi todo lo marcado que se toca
		var queue = new Array<Int>();
		var total = size * size * HEIGHT;
		for( addr in 0...total )
			if( fget(addr) & TMP != 0 && supported(addr) ) {
				fset(addr, fget(addr) & TMASK);
				queue.push(addr);
			}
		while( queue.length > 0 ) {
			var addr = queue.pop();
			var c = addr >> HBITS, z = addr & (HEIGHT - 1);
			var x = c % size, y = Std.int(c / size);
			inline function visit( n : Int ) {
				if( fget(n) & TMP != 0 ) {
					fset(n, fget(n) & TMASK);
					queue.push(n);
				}
			}
			visit(addr + (minusOne(x) << HBITS));
			visit(addr + (plusOne(x) << HBITS));
			visit(addr + ((minusOne(y) * size) << HBITS));
			visit(addr + ((plusOne(y) * size) << HBITS));
			if( z > 0 ) visit(addr - 1);
			if( z < HEIGHT - 1 ) visit(addr + 1);
		}
		gcFree(true);
		for( addr in 0...total )
			if( fget(addr) & TMP != 0 )
				fset(addr, EMPTY);
		gcFree(false);
	}

	/** una vecina llena y sin TMP (apoyada) */
	function supported( addr : Int ) : Bool {
		var c = addr >> HBITS, z = addr & (HEIGHT - 1);
		var x = c % size, y = Std.int(c / size);
		inline function solid( n : Int ) return (fget(n) - 1) & TMP == 0;
		return solid(addr + (minusOne(x) << HBITS)) || solid(addr + (plusOne(x) << HBITS)) || solid(addr + ((minusOne(y) * size) << HBITS))
			|| solid(addr + ((plusOne(y) * size) << HBITS)) || (z > 0 && solid(addr - 1)) || (z < HEIGHT - 1 && solid(addr + 1));
	}
	
	function smoothHeight() {
		var addr = 0;
		for( y in 0...size )
			for( x in 0...size ) {
				var h = (hval(addr) << 2) + (hval(addr + minusOne(x)) + hval(addr + plusOne(x)) + hval(addr + minusOne(y) * size) + hval(addr + plusOne(y)*size)) * 3;
				perlin.setByte(outHeight + addr, (h + 7) >> 4);
				addr++;
			}
	}
	
	inline function countEmpty(x, y, z, addr) {
		var count = 0;
		if( fget(addr + (minusOne(x) << HBITS)) == EMPTY )
			count++;
		if( fget(addr + (plusOne(x) << HBITS)) == EMPTY )
			count++;
		if( z > 0 && fget(addr - 1) == EMPTY )
			count++;
		if( z < HEIGHT - 1 && fget(addr + 1) == EMPTY )
			count++;
		if( fget(addr + (minusOne(y) << HBITS) * size) == EMPTY )
			count++;
		if( fget(addr + (plusOne(y) << HBITS) * size) == EMPTY )
			count++;
		return count;
	}
	
	/** countEmpty(x, y, z, addr) <= 2, sin leer las vecinas que ya no cambian la respuesta (anadido del port) */
	inline function fewEmpty(x, y, z, addr) {
		var n = (fget(addr + (minusOne(x) << HBITS)) == EMPTY ? 1 : 0) + (fget(addr + (plusOne(x) << HBITS)) == EMPTY ? 1 : 0);
		if( fget(addr + (minusOne(y) << HBITS) * size) == EMPTY ) n++;
		if( n <= 2 ) {
			if( fget(addr + (plusOne(y) << HBITS) * size) == EMPTY ) n++;
			if( n <= 2 ) {
				if( z > 0 && fget(addr - 1) == EMPTY ) n++;
				if( n <= 2 && z < HEIGHT - 1 && fget(addr + 1) == EMPTY ) n++;
			}
		}
		return n <= 2;
	}

	/** countEmpty(x, y, z, addr) >= 5, sin leer las vecinas que ya no cambian la respuesta (anadido del port) */
	inline function manyEmpty(x, y, z, addr) {
		// vecinas que no cuentan como vacias (fuera del mundo en z o llenas): con 2 ya no llega a 5
		var miss = (z > 0 ? 0 : 1) + (z < HEIGHT - 1 ? 0 : 1);
		if( fget(addr + (minusOne(x) << HBITS)) != EMPTY ) miss++;
		if( miss < 2 ) {
			if( fget(addr + (plusOne(x) << HBITS)) != EMPTY ) miss++;
			if( miss < 2 ) {
				if( fget(addr + (minusOne(y) << HBITS) * size) != EMPTY ) miss++;
				if( miss < 2 && fget(addr + (plusOne(y) << HBITS) * size) != EMPTY ) miss++;
				if( miss < 2 && z > 0 && fget(addr - 1) != EMPTY ) miss++;
				if( miss < 2 && z < HEIGHT - 1 && fget(addr + 1) != EMPTY ) miss++;
			}
		}
		return miss < 2;
	}

	/**
	 * Anadido del port: lo que hace falta para que smooth3D no mire mas de lo necesario, con el mismo resultado:
	 * - smoothTop: por columna, lo mas alto que no esta vacio (o mas: solo sube). Por encima del maximo de una columna y de sus
	 *   4 vecinas, mas uno, una celda vacia tiene 5 o 6 vecinas vacias (no se rellena) y no hay celdas llenas: no se mira;
	 * - smoothDirty: columnas en las que se ha escrito en la pasada anterior (bit 0) y en esta (bit 1). En una reanudacion
	 *   (stepRetry o el bucle de Marte, smoothSeq), una columna sin escrituras en ella ni en sus vecinas desde la ultima vez que
	 *   se miro no cambiaria nada: cada cambio empieza en una celda de la columna que se mira y solo depende de sus 6 vecinas.
	 */
	var smoothTop : haxe.ds.Vector<Int>;
	var smoothDirty : haxe.ds.Vector<Int>;
	/** la ultima pasada de smooth3D que cambio algo: en que ejecucion de paso (stepRuns), en que paso y con que alturas */
	var smoothSeq : { run : Int, pos : Int, hmin : Int, hmax : Int };
	/** pasos empezados (process): una reanudacion de smooth3D es en el mismo o en el siguiente, el mismo paso otra vez */
	var stepRuns = 0;

	/** principio de una pasada de smooth3D: la primera de una serie mira todas las columnas */
	function smoothBegin( hmin : Int, hmax : Int ) {
		var n = size * size;
		var s = smoothSeq;
		var resume = s != null && s.hmin == hmin && s.hmax == hmax && (s.run == stepRuns || (s.run == stepRuns - 1 && s.pos == curPosition - 1));
		if( resume ) {
			for( c in 0...n ) smoothDirty[c] = smoothDirty[c] >> 1;
			return;
		}
		if( smoothTop == null ) {
			smoothTop = new haxe.ds.Vector(n);
			smoothDirty = new haxe.ds.Vector(n);
		}
		for( c in 0...n ) {
			var addr = (c << HBITS) + HEIGHT - 1, z = HEIGHT - 1;
			while( z > 0 && fget(addr) == EMPTY ) {
				z--;
				addr--;
			}
			smoothTop[c] = z;
			smoothDirty[c] = 1;
		}
	}

	/** fin de una pasada: si cambio algo, la siguiente puede ser una reanudacion */
	function smoothEnd( changed : Int, hmin : Int, hmax : Int ) {
		smoothSeq = changed > 0 ? { run : stepRuns, pos : curPosition - 1, hmin : hmin, hmax : hmax } : null;
	}

	/** se ha escrito en la celda addr (si es del mundo: los saltos de minusOne pueden salirse) */
	inline function smoothWrote( addr : Int, filled : Bool ) {
		if( addr >= 0 && addr < size * size * HEIGHT ) {
			var c = addr >> HBITS;
			smoothDirty[c] = smoothDirty[c] | 2;
			if( filled && (addr & (HEIGHT - 1)) > smoothTop[c] ) smoothTop[c] = addr & (HEIGHT - 1);
		}
	}

	function smooth3D( hmin = -1, hmax = 255 ) {
		var changed = 0;
		if( hmin < 0 ) hmin = waterLevel;
		smoothBegin(hmin, hmax);
		for( y in 0...size )
			changed += smooth3DRow(y, hmin, hmax);
		smoothEnd(changed, hmin, hmax);
		return changed;
	}

	/** smooth3D() repartido, una fila por llamada (anadido del port, ver jobs); then recibe lo que ha cambiado */
	function smooth3DLater( then : Int -> Void ) {
		var changed = 0, hmin = waterLevel;
		smoothBegin(hmin, 255);
		spread(size, function(y) changed += smooth3DRow(y, hmin, 255), function() {
			smoothEnd(changed, hmin, 255);
			then(changed);
		});
	}

	function smooth3DRow( y : Int, hmin : Int, hmax : Int ) {
		var changed = 0;
		var top = smoothTop, dirty = smoothDirty;
		var row = y * size, up = minusOne(y) * size, down = plusOne(y) * size;
		for( x in 0...size ) {
			var h = height(x,y);
			if( h <= hmin || h > hmax ) continue;
			var c = row + x, l = c + minusOne(x), r = c + plusOne(x), u = c + up, d = c + down;
			if( (dirty[c] | dirty[l] | dirty[r] | dirty[u] | dirty[d]) == 0 ) continue;
			var zmax = top[c];
			if( top[l] > zmax ) zmax = top[l];
			if( top[r] > zmax ) zmax = top[r];
			if( top[u] > zmax ) zmax = top[u];
			if( top[d] > zmax ) zmax = top[d];
			zmax += 2;
			if( zmax > HEIGHT ) zmax = HEIGHT;
			var addr = (c << HBITS) + hmin;
			for( z in hmin...zmax ) {
				var b = fget(addr);
				if( b == EMPTY ) {
					if( fewEmpty(x, y, z, addr) )
						changed += smooth3DEmptyRec(x, y, z, addr, 4);
				} else if( b != WATER ) {
					if( manyEmpty(x, y, z, addr) )
						changed += smooth3DRec(x, y, z, addr, 10);
				}
				addr++;
			}
		}
		return changed;
	}

	function smooth3DRec(x, y, z, addr, depth) {
		if( fget(addr) == WATER )
			return 0;
		fset(addr, EMPTY);
		smoothWrote(addr, false);
		var count = 1;
		depth--;
		if( depth == 0 ) return count;
		// version 1: la x / y de la vecina (antes se pasaba el desplazamiento de minusOne: mal en el borde del mapa)
		var naddr = addr + (minusOne(x) << HBITS);
		if( manyEmpty(prevC(x), y, z, naddr) )
			count += smooth3DRec(prevC(x), y, z, naddr, depth);
		var naddr = addr + (minusOne(y) << HBITS) * size;
		if( manyEmpty(x, prevC(y), z, naddr) )
			count += smooth3DRec(x, prevC(y), z, naddr, depth);
		var naddr = addr - 1;
		if( z > 0 && manyEmpty(x,y, z-1, naddr) )
			count += smooth3DRec(x, y, z - 1, naddr, depth);
		return count;
	}

	function smooth3DEmptyRec(x, y, z, addr, depth) {
		fset(addr, SOIL);
		smoothWrote(addr, true);
		var count = 1;
		depth--;
		if( depth == 0 ) return count;
		var naddr = addr + (minusOne(x) << HBITS);
		if( fewEmpty(prevC(x), y, z, naddr) )
			count += smooth3DEmptyRec(prevC(x), y, z, naddr, depth);
		var naddr = addr + (minusOne(y) << HBITS) * size;
		if( fewEmpty(x, prevC(y), z, naddr) )
			count += smooth3DEmptyRec(x, prevC(y), z, naddr, depth);
		var naddr = addr - 1;
		if( z > 0 && fewEmpty(x,y, z-1, naddr) )
			count += smooth3DEmptyRec(x, y, z - 1, naddr, depth);
		return count;
	}
	
	public function getBitmap() {
		var bmp = new flash.display.BitmapData(size, size, true, 0);
		var colors = bmp.getVector(bmp.rect);
		perlin.select();
		
		var wh = waterLevel;
		for( y in 0...size )
			for( x in 0...size ) {
				var p = x + y * size;
				var addr = p << HBITS;
				var h = hval(p);
				var color;
				if( h < wh )
					color = Std.int(h * 255 / wh);
				else {
					var f = Std.int( (h - wh) * 255 / (HEIGHT - wh) );
					color = f | (f << 16) | (((f >> 1) | 0x80) << 8);
				}
				if( h > wh ) h = wh;
				for( i in 0...h )
					if( fget(addr++) == EMPTY ) {
						var f = 0.2 + 0.8 * (i / h);
						var r = Std.int( ((color >> 16) & 0xFF) * f + (1 - f) * 0xFF );
						var g = Std.int( ((color >> 8) & 0xFF) * f );
						var b = Std.int( (color & 0xFF) * f + (1 - f) * 0xFF );
						color = (r << 16) | (g << 8) | b;
						break;
					}
				colors[p] = 0xFF000000 | color;
			}
		bmp.setVector(bmp.rect, colors);
		return bmp;
	}
	
	public function getBytes() {
		var out = new flash.utils.ByteArray();
		out.writeBytes(perlin.buf, outPos, size * size << HBITS);
		return out;
	}
		
	inline function srand( v : Float ) {
		return rnd.rand() * (v * 2) - v;
	}
	
	// ---------------- CAVES/TOOLS ---------------------------------------------------------------------------------------------
	
	inline function box(sizeX, sizeY, sizeZ, callb) {
		for(dx in 0...sizeX)
			for(dy in 0...sizeY)
				for(dz in 0...sizeZ)
					callb(dx,dy,dz);
	}
	
	inline function boxWalls(sizeX, sizeY, sizeZ, callb) {
		for(dx in 0...sizeX)
			for(dy in 0...sizeY)
				for(dz in 0...sizeZ)
					if( dx==0 || dx==sizeX-1 || dy==0 || dy==sizeY-1 || dz==0 || dz==sizeZ-1 )
						callb(dx,dy,dz);
	}
	
	inline function boxCentered(sizeX,sizeY,sizeZ, callb) {
		var bx = -Std.int(sizeX/2);
		var by = -Std.int(sizeY/2);
		var bz = -Std.int(sizeZ/2);
		for( dx in bx...bx + Std.int(sizeX) )
			for( dy in by...by + Std.int(sizeY) )
				for( dz in bz...bz + Std.int(sizeZ) )
					callb(dx,dy,dz);
	}
	
	inline function boxCenteredWalls(sizeX,sizeY,sizeZ, callb) {
		var bx = -Std.int(sizeX/2);
		var by = -Std.int(sizeY/2);
		var bz = -Std.int(sizeZ/2);
		for( dx in bx...bx + Std.int(sizeX) )
			for( dy in by...by + Std.int(sizeY) )
				for( dz in bz...bz + Std.int(sizeZ) )
					if( dx==bx || dx==bx+Std.int(sizeX)-1 || dy==by || dy==by+Std.int(sizeY)-1  || dz==bz || dz==bz+Std.int(sizeZ)-1 )
						callb(dx,dy,dz);
	}
	
	
	inline function square(sizeX,sizeY, callb) {
		var bx = -Std.int(sizeX/2);
		var by = -Std.int(sizeY/2);
		for( dx in bx...bx + Std.int(sizeX) )
			for( dy in by...by + Std.int(sizeY) )
				callb(dx,dy);
	}
	
	inline function squareWalls(sizeX,sizeY, callb) {
		var bx = -Std.int(sizeX/2);
		var by = -Std.int(sizeY/2);
		for( dx in bx...bx + Std.int(sizeX) )
			for( dy in by...by + Std.int(sizeY) )
				if( dx==bx || dx==bx+Std.int(sizeX)-1 || dy==by || dy==by+Std.int(sizeY)-1 )
					callb(dx,dy);
	}
	//inline function squareWalls(sizeX,sizeY,sizeZ, callb) {
		//var bx = -Std.int(sizeX/2);
		//var by = -Std.int(sizeY/2);
		//var bz = -Std.int(sizeZ/2);
		//for( dx in bx...bx + Std.int(sizeX) )
			//for( dy in by...by + Std.int(sizeY) )
				//for( dz in bz...bz + Std.int(sizeZ) )
					//if( dx==bx || dx==bx+Std.int(sizeX)-1 || dy==by || dy==by+Std.int(sizeY)-1  || dz==bz || dz==bz+Std.int(sizeZ)-1 )
						//callb(dx,dy,dz);
	//}
	
	
		
	inline function elipse(xx, yy, zz, callb) {
		var ix = Math.ceil(xx);
		var iy = Math.ceil(yy);
		var iz = Math.ceil(zz);
		for( dx in -ix...ix + 1 )
			for( dy in -iy...iy + 1 )
				for( dz in -iz...iz + 1 ) {
					var d = (dx / xx) * (dx / xx) + (dy / yy) * (dy / yy) + (zz == 0 ? 0 : (dz / zz) * (dz / zz));
					if( d > 1 ) continue;
					callb(dx, dy, dz);
				}
	}
	
	inline function circle(xx, yy, callb) {
		var ix = Math.ceil(xx);
		var iy = Math.ceil(yy);
		for( dx in -ix...ix + 1 )
			for( dy in -iy...iy + 1 ) {
				var d = (dx / xx) * (dx / xx) + (dy / yy) * (dy / yy);
				if( d > 1 ) continue;
				callb(dx, dy);
			}
	}
	
	inline function min(a, b) return a < b ? a : b;
	inline function max(a, b) return a < b ? b : a;
	
	inline function line( x : Int, y : Int, z : Int, dx : Int, dy : Int, dz : Int, callb ) {
		
		var ax = dx < 0 ? -1 : 1;
		var ay = dy < 0 ? -1 : 1;
		var az = dz < 0 ? -1 : 1;
		var d = dx * ax + dy * ay + dz * az;
		if( d == 0 ) d = 1;
		
		var ix = x;
		var iy = y;
		var iz = z;

		while( --d >= 0 ) {
			callb(x, y, z);
			var nx = (x + ax - ix) / dx;
			var ny = (y + ay - iy) / dy;
			var nz = (z + az - iz) / dz;
			if( nx < ny ) {
				if( nx < nz )
					x += ax;
				else
					z += az;
			} else if( ny < nz )
				y += ay;
			else
				z += az;
		}
	}

	function addCaves( amount : Float, scale : Float, broken : BlockKind ) {
		var wh = waterLevel;
		var pts = [];
		var broken = alloc(broken);
		for( i in 0...Std.int(size * size * amount / 1000) ) {
			var x, y, z, ntry = 100;
			do {
				x = rnd.random(size);
				y = rnd.random(size);
				z = height(x,y) - 1;
				if( --ntry == 0 ) break;
			} while( z < wh || z > wh + (wh >> 1) || fget(addr(x, y, z)) != SOIL );
			if( ntry == 0 )
				continue;
			z = rnd.random(z) + (z>>2) + 5;
			var size = Std.int((2. + min(rnd.random(20), rnd.random(20)) - Std.int(z * 4 / wh)) * scale);
			if( size < 2 ) size = 2;
			pts.push(new CavePoint(x,y,z,size));
		}
		for( p in pts ) {
			for( p2 in pts ) {
				if( p2.z >= p.z ) continue;
				var dx = realDist(p.x - p2.x), dy = realDist(p.y - p2.y), dz = p2.z - p.z;
				p2.dist = dx * dx + dy * dy + dz * dz;
				if( p2.dist < 50*50 )
					p.next.push(p2);
			}
			FlashSort.sort(p.next, sortCaves);
			var next = 0;
			for( i in 0...min(p.next.length, 2 + (rnd.random(3) == 0 ? 1 : 0)) - p.links ) {
				var p2 = p.next[i];
				p.links++;
				p2.links++;
				var x = p.x, y = p.y, z = p.z;
				var walls = [];
				while( true ) {
					var dx = realDist(p2.x - x);
					var dy = realDist(p2.y - y);
					var dz = p2.z - z;
					var ax = dx < 0 ? -dx : dx;
					var ay = dy < 0 ? -dy : dy;
					var az = dz < 0 ? -dz : dz;
					var t = ax + ay + az;
					elipse(1 + rnd.random(3), 1 + rnd.random(3), 2+rnd.random(2), function(dx, dy, dz) {
						var x = x + dx, y = y + dy, z = z + dz;
						set(x, y, z, CAVE);
					});
					if( t == 0 ) break;
					var jump = 1;
					if( rnd.random(20) == 0 )
						jump = 10;
					for( i in 0...jump ) {
						if( i == 5 )
							walls.push( { x : x, y : y, z : z } );
						var k = rnd.random(t);
						k -= ax;
						if( k < 0 ) {
							x += dx > 0 ? 1 : -1;
							continue;
						}
						k -= ay;
						if( k < 0 ) {
							y += dy > 0 ? 1 : -1;
							continue;
						}
						z += dz > 0 ? 1 : -1;
					}
				}
				for( w in walls )
					elipse(2 + rnd.random(2), 2 + rnd.random(2), 2+rnd.random(2), function(dx, dy, dz) {
						var x = w.x + dx, y = w.y + dy, z = w.z + dz;
						if( rnd.random(3) != 0 ) {
							var b = get(x, y, z);
							if( b == ROCK || b == SOIL )
								set(x, y, z, broken);
						}
					});
			}
		}
		for( p in pts ) {
			if( p.links == 0 ) continue;
			var size = p.size;
			for( i in 0...size * size ) {
				var x = p.x + rnd.random(size) - (size >> 1);
				var y = p.y + rnd.random(size) - (size >> 1);
				var z = p.z + ((rnd.random(size) - (size >> 1)) >> 1);
				elipse(rnd.random(size >> 1) + 1, rnd.random(size >> 1) + 1, (rnd.random(size >> 1) >> 1) + 1, function(dx, dy, dz) {
					var x = x + dx, y = y + dy, z = z + dz;
					set(x, y, z, CAVE);
				});
			}
		}
	}
	
	inline function realDist( d : Int ) {
		var half = size >> 1;
		return d <= -half ? d + size : (d > half ? d - size : d);
	}
	
	function sortCaves( c1 : CavePoint, c2 : CavePoint ) {
		return c1.dist - c2.dist;
	}
	
	function showCaves() {
		var tot = size * size << HBITS;
		var tmp = new flash.Vector<Int>(tot+1);
		for( addr in 0...tot )
			if( fget(addr) == CAVE )
				tmp[addr] = 1;
		addStep("showCaves", function() {
			var addr = 0;
			for( y in 0...size )
				for( x in 0...size )
					for( z in 0...HEIGHT ) {
						if( tmp[addr] == 1 || (z > 0 && tmp[addr-1] == 1) || tmp[addr+1] == 1 || tmp[addr+(plusOne(x)<<HBITS)] == 1 || tmp[addr+(minusOne(x)<<HBITS)] == 1 || tmp[addr+(plusOne(y)<<(HBITS*2))] == 1 || tmp[addr+(minusOne(y)<<(HBITS*2))] == 1 ) {
							// ok
						} else {
							fset(addr, EMPTY);
						}
						addr++;
					}
		});
	}
	
	function checkWater() {
		var addr = 0;
		waterTotal = 0;
		var transp = btrans.copy();
		transp[WATER] = false;
		var isLiquid = blocks[WATER].hasProp(PLiquid);
		// version 1: solo el agua hasta el nivel del mar (la de las cascadas de las estructuras corre en el juego)
		var top = waterLevel < HEIGHT - 1 ? waterLevel : HEIGHT - 2;
		gcFree(true);
		for( y in 0...size )
			for( x in 0...size ) {
				var col = (x + y * size) << HBITS;
				addr = col + 1;
				// anadido del port: de un agua a la siguiente de la columna (findCell), en el mismo orden
				var colEnd = col + top + 1;
				while( (addr = findCell(addr, colEnd, WATER)) < colEnd ) {
					var z = addr & (HEIGHT - 1);
					waterTotal++;
					if( isLiquid ) {
						var a = addr + (minusOne(x) << HBITS);
						if( transp[fget(a)] ) fset(a, SOIL);
						var a = addr + (plusOne(x) << HBITS);
						if( transp[fget(a)] ) fset(a, SOIL);
						var a = addr + (minusOne(y) << HBITS) * size;
						if( transp[fget(a)] ) fset(a, SOIL);
						var a = addr + (plusOne(y) << HBITS) * size;
						if( transp[fget(a)] ) fset(a, SOIL);
						if( z > 0 ) {
							var a = addr - 1;
							if( transp[fget(a)] ) fset(a, SOIL);
						}
						if( z < waterLevel && fget(addr + 1) == EMPTY )
							fset(addr + 1, WATER);
					}
					addr++;
				}
			}
		gcFree(false);
	}
	
	function fillBedrock() {
		for( p in 0...size * size ) {
			fset(p << HBITS, BEDROCK);
			// clear z=127
			fset((p << HBITS) | (HEIGHT - 1), EMPTY);
		}
	}
	
	inline function gen( density : Float, retry = 100, callb : Void -> Bool ) {
		for( i in 0...Math.ceil(size * size * density / 100) ) {
			var ntry = retry;
			while( ntry-- > 0 )
				if( callb() )
					break;
		}
	}
	
	function loadModel( mdata : String ) {
		var m = models.get(mdata);
		if( m != null )
			return m;
		var bytes : haxe.io.Bytes = haxe.Unserializer.run(mdata);
		#if flash
		var data = bytes.getData();
		data.uncompress();
		bytes = haxe.io.Bytes.ofData(data);
		#else
		bytes = haxe.zip.Uncompress.run(bytes);
		#end
		var sx = bytes.get(0), sy = bytes.get(1), sz = bytes.get(2);
		// calculate size
		var xmin = sx - 1, ymin = sy - 1, xmax = 0, ymax = 0, zmax = 0;
		var pos = 3;
		for( y in 0...sy )
			for( x in 0...sx )
				for( z in 0...sz ) {
					if( bytes.get(pos) != 0 || bytes.get(pos + 1) != 0 ) {
						if( x < xmin ) xmin = x;
						if( y < ymin ) ymin = y;
						if( x > xmax ) xmax = x;
						if( y > ymax ) ymax = y;
						if( z > zmax ) zmax = z;
					}
					pos += 2;
				}
		zmax++;
		var w = xmax - xmin + 1;
		var h = ymax - ymin + 1;
		var b = haxe.io.Bytes.alloc(w * h * zmax);
		var hblocks = new IntHash();
		var blocks = [];
		var out = 0;
		for( y in 0...h )
			for( x in 0...w )
				for( z in 0...zmax ) {
					var pos = 3 + (z + (x+xmin) * sz + (y + ymin) * sz * sx) * 2;
					var k = bytes.get(pos) | (bytes.get(pos + 1) << 8);
					if( k == 0 ) {
						out++;
						continue;
					}
					var index = hblocks.get(k);
					if( index == null ) {
						index = blocks.length + 1;
						hblocks.set(k, index);
						blocks.push(Block.all[k].k);
					}
					b.set(out++, index);
				}
		m = new Model(w, h, zmax, b);
		m.blocks = blocks;
		models.set(mdata, m);
		return m;
	}
	
	function addModel( px, py, pz, model : String ) {
		var m = loadModel(model);
		px -= (m.sx - 1) >> 1;
		py -= (m.sy - 1) >> 1;
		var blocks = [];
		for( b in m.blocks )
			blocks.push(alloc(b));
		var pos = 0;
		for( y in 0...m.sy )
			for( x in 0...m.sx )
				for( z in 0...m.sz ) {
					var b = m.bytes.get(pos++);
					if( b == 0 )
						continue;
					set(px + x, py + y, pz + z, blocks[b-1]);
				}
	}
	
	function isSolid(b) {
		return b != EMPTY && !btrans[b];
	}
	
	inline function isSolidAt(x,y,z) {
		var b = get(x,y,z);
		return b!=CAVE && b != EMPTY && !btrans[b];
	}
	
	function putModel( px, py, pz, model ) {
		var m = loadModel(model);
		var x = px - (m.sx >> 1);
		var y = py - (m.sy >> 1);
		var pos = 0;
		// check if the volume is empty and the lower parts on soil
		for( dy in 0...m.sy )
			for( dx in 0...m.sx )
				for( dz in 0...m.sz ) {
					if( dz == 0 ) {
						if( m.bytes.get(pos) != 0 ) {
							var b = get(x + dx, y + dy, pz - 1);
							if( !isSolid(b) )
								return false;
						}
					} else if( get(x + dx, y + dy, pz + dz) != EMPTY )
						return false;
					pos++;
				}
		addModel(px, py, pz, model);
		return true;
	}
	
}
