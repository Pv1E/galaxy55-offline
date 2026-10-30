import Common;

/**
	Olas del agua del original (planet.animWater, WaterShader0..2): cada vertice del agua baja
	(sin(x * width + t) * cos(y * width + t) + 1) * amp, con t = tiempo * 0.5 y amp = 0.3 * 0.5.
**/
class WaterWave extends hxsl.Shader {
	static var SRC = {
		var transformedPosition : Vec3;
		@param var time : Float;
		@param var width : Float;
		@param var amp : Float;
		function vertex() {
			transformedPosition.z -= (sin(transformedPosition.x * width + time) * cos(transformedPosition.y * width + time) + 1.0) * amp;
		}
	};
}

/**
	Como WaterShader0..2 del original (tpos.z += 0.00002, "prevent some z-fighting with alpha blocks"): el agua queda un poco
	mas lejos en profundidad. Sus caras contra el hielo, el cristal o las hojas estan en el mismo plano que las de esos bloques
	y, sin esto, el redondeo decidia cual ganaba en cada triangulo (triangulos oscuros y rayado en el hielo visto desde el agua).
**/
class WaterDepthBias extends hxsl.Shader {
	static var SRC = {
		var projectedPosition : Vec4;
		function vertex() {
			projectedPosition.z += 0.00002;
		}
	};
}

/** Geometria acumulada de un chunk para un material. */
class MeshBuf {
	public var pts = new Array<h3d.col.Point>();
	public var uvs = new Array<h3d.prim.UV>();
	public var cols = new Array<h3d.col.Point>();
	public var idx = new hxd.IndexBuffer();
	public function new() {}
}

/** Una bajada del mar mientras se reparte su luz (World.reduceWater), que puede durar varios fotogramas. */
class SeaLight {
	public var z = 0;
	public var top = 0;
	public var lmax = 0;
	/** columnas con una celda quitada o con otra luz */
	public var chg : haxe.io.Bytes;
	/** por columna, la primera altura con aire hasta arriba (255 = sin calcular) */
	public var sky : haxe.io.Bytes;
	/** celdas ya repartidas, un bit por celda */
	public var seen : haxe.io.Bytes;
	/** columnas de la capa quitada que pueden estar al sol y por cual se va */
	public var cand : Array<Int>;
	public var ci = 0;
	public var lsun = 0;
	/** anillo actual del reparto (al principio, las semillas), el siguiente y su luz */
	public var cur : Array<Int>;
	public var next = new Array<Int>();
	public var i = 0;
	public var lvalue = 0.;
	public var removed = 0;
	public var sunCols = 0;
	public var cells = 0;
	public var frames = 0;
	public var time = 0.;
	public function new() {}
}

/**
	Un planeta: lo genera con los generadores originales y construye su geometria.
	Se carga por tandas (step) para poder mostrar una barra de progreso sin congelar la ventana.
**/
class World {

	public static inline var CSIZE = 16;
	public static inline var ZBITS = 7;
	public static inline var HEIGHT = 128;
	static inline var TE = 0.999;

	public var seed(default, null) : Int;
	public var biomeName(default, null) : String;
	public var size(default, null) : Int;

	/**
	 * Curvatura del planeta. El original usa curve = 2 / totalSize (AbstractGame); el port la reduce (CURVE_K) porque se notaba
	 * demasiado. Se usa en el dibujo (Sky.FogShader) y al apuntar (GameView.pick), que tienen que coincidir.
	 */
	public static inline var CURVE_K = 0.6;
	public static inline function curve( size : Int ) : Float return CURVE_K * 2.0 / size;
	public var faces(default, null) = 0;
	public var failed(default, null) = false;
	public var progress(default, null) = 0.;
	public var root(default, null) : h3d.scene.Object;
	public var sky(default, null) : Sky;
	/** olas del agua (animWater del original); null en la nave y en el hangar. GameView avanza su tiempo */
	public var wave(default, null) : WaterWave;
	/** altura de las olas: animWater.scale * 0.5 */
	public static inline var WAVE_AMP = 0.3 * 0.5;
	var gen : gen.DetailsGenerator;
	var bytes : haxe.io.Bytes;
	var atlas : h3d.mat.Texture;
	var phase = 0;
	var chunk = 0;
	var meshes = new Array<h3d.scene.Mesh>();
	static inline var VIEW_RADIUS = 180.;
	var meshExtra = new Array<Array<h3d.scene.Mesh>>();
	var meshCx = new Array<Float>();
	var meshCy = new Array<Float>();
	var curCx = 0.;
	var curCy = 0.;
	var wrapX = -1e9;
	var wrapY = -1e9;
	var genStarted : Float;

	// luz (Builder.relight del original): 0..15 por celda; LBASE = 10 equivale a luz plena
	public static inline var LBASE = 10;
	static inline var NOLIGHT = 8; // enumIndex(BTReduced): a partir de aqui el bloque no deja pasar la luz
	var light : haxe.io.Bytes;
	var idTag : Array<Int>;
	var sunP : Float;
	var sunF : Float;
	var lightIdx : Array<Int>;
	var lightInfos : Array<{ p : Int, f : Float, pw : Float }>;
	var mask : haxe.io.Bytes;
	var useMask = false;
	/** cambios del jugador sobre el terreno: celda -> indice global de bloque (0 = aire); se guardan con la partida */
	public var editMap = new Map<Int, Int>();
	var savedEdits : Array<Int>;
	/**
	 * Nivel del agua que fluye (anadido del port, como Minecraft): celda -> 1..7 (cada vez mas baja) u 8 (cayendo).
	 * Sin entrada = fuente (llena, como todo el agua del original). Se guarda en editMap junto al bloque: indice | nivel << 16.
	 */
	public var waterLvl = new Map<Int, Int>();

	/**
	 * Mar del planeta (planet.waterLevel, waterTotal y waterFlood del original). Cada bloque del agua del bioma que pone Process
	 * suma uno a waterFlood (net/Local.processBlock); al llegar al volumen de una capa (waterTotal / nivel) la capa de arriba
	 * desaparece en todo el planeta y el nivel baja 1 (Local.reduceWater y Game.onCommand(SReduceWater)).
	 * El nivel y el contador se guardan con los cambios del terreno, con las claves negativas SEA_LEVEL y SEA_FLOOD.
	 */
	var seaLevel = 0;
	public var waterTotal(default, null) = 0;
	public var waterFlood = 0;
	/** agua del bioma (Local.waterId); null en la nave y en el hangar */
	public var seaBlock(default, null) : Block;
	var seaId = -1;
	/** agua del mar que puso el generador en cada altura (lo que descuenta Local.reduceWater) */
	var seaCount : Array<Int>;
	/** floodFlag de Local: hay una bajada pendiente */
	public var floodFlag(default, null) = false;
	/** trozos que rehacer tras una bajada, los mas cercanos primero */
	var seaChunks = new Array<Int>();
	static inline var SEA_LEVEL = -1;
	static inline var SEA_FLOOD = -2;
	/** posicion de la camara (updateWrap): para rehacer primero lo que se ve */
	var viewX = 0.;
	var viewY = 0.;
	/** reparto de la luz de una bajada del mar que aun no ha acabado */
	var seaJob : SeaLight;
	var chunkMeshes : Array<Array<Int>>;
	var curList : Array<Int>;
	var immediate = new Array<Int>();
	var pendingRelight = new Array<Int>();
	var lightChunks = new Array<Int>();

	// la nave (ShipLogic/Level.extra del original): un volumen de 128x128x128 colgado sobre el planeta, desde z = SHIP_Z
	public static inline var SHIP_Z = 130;
	/** la nave de este planeta (solo en el mundo del planeta) */
	public var ship : World;
	/** desplazamiento (x, y) de la nave respecto al planeta: celda de la nave + desplazamiento = posicion en el planeta */
	public var shipDX = 0;
	public var shipDY = 0;
	/** se llama tras cambiar una celda del planeta con setBlock (x, y ya dentro del planeta): la nave vigila la columna de su rayo */
	public var onSetBlock : Int -> Int -> Int -> Void;
	/** true en el mundo de la nave: no da la vuelta y usa el cielo del planeta */
	public var isShip(default, null) = false;
	/** altura desde la que entra el sol (-1 = desde arriba del todo); el hangar la pone bajo el techo (EditShip: planet.lightHeight) */
	public var lightTop = -1;
	var wraps = true;
	var ownSky = true;

	public function new( seed : Int, biomeName : String, sizeChunks : Int, parent : h3d.scene.Object, atlas : h3d.mat.Texture, menuFog = false, ?savedEdits : Array<Int>, ?shipData : ShipData.ShipDataInfo, ?sharedSky : Sky ) {
		this.savedEdits = savedEdits;
		this.seed = seed;
		this.biomeName = biomeName;
		this.atlas = atlas;
		size = sizeChunks << Const.BITS;
		chunkMeshes = [for( i in 0...sizeChunks * sizeChunks * 64 ) null];
		root = new h3d.scene.Object(parent);
		var biome : BiomeKind = Type.createEnum(BiomeKind, biomeName);
		// la nave comparte el cielo (niebla y curvatura) del planeta
		if( sharedSky != null ) {
			sky = sharedSky;
			ownSky = false;
		} else {
			sky = new Sky(root, biome, menuFog, size);
			sky.fog.curve = curve(size);
		}
		// animWater = { width : 0.5, scale : 0.3, speed : 0.5 }; Render.init ajusta width para que las olas cierren la vuelta
		// al planeta. La nave (sharedSky) no tiene agua que mover
		if( sharedSky == null ) {
			wave = new WaterWave();
			var w = 0.5;
			w -= ((w * size) % (Math.PI * 2)) / size;
			wave.width = w;
			wave.amp = Settings.waterWaves ? WAVE_AMP : 0;
			wave.time = 0;
		}
		gen = new gen.DetailsGenerator(size, seed);
		var bd = Data.getBiome(biome);
		sunP = bd.sunPower;
		sunF = bd.sunFalloff == null ? 1 : bd.sunFalloff;
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
		// como Builder.init: los modelos sin BFSize usan su propia caja para las colisiones
		for( b in Block.all )
			if( b.model != null && b.size == null ) b.size = Models.get(b.model).box;
		genStarted = haxe.Timer.stamp();
	}

	public inline function isReady() return phase >= 2;

	/** Avanza la carga durante budgetMs milisegundos; devuelve el progreso de 0 a 1. */
	public function step( budgetMs : Float ) : Float {
		var t0 = haxe.Timer.stamp();
		if( phase == 0 && isShip ) {
			applySaved();
			computeLight();
			phase = 1;
			return progress = 0.75;
		}
		if( phase == 0 ) {
			var p0 = gen.progress;
			var busy = gen.process(Std.int(budgetMs));
			if( Sys.args().indexOf("--frametime") >= 0 && haxe.Timer.stamp() - t0 > 0.2 )
				Sys.println("generador: " + Std.int((haxe.Timer.stamp() - t0) * 1000) + " ms en un paso (progreso " + Std.int(p0 * 100) + "% -> " + Std.int(gen.progress * 100) + "%)");
			if( !busy ) {
				bytes = gen.getBytes().b;
				initLightTables();
				// el sitio de la nave se elige antes de aplicar los cambios guardados: si no, con el suelo cavado o construido bajo
				// la nave, al cargar la partida la nave aparecia en otro sitio
				if( savedEdits != null && savedEdits.length > 0 ) shipPlace();
				applySaved();
				var tl = haxe.Timer.stamp();
				computeLight();
				if( Sys.args().indexOf("--lighttime") >= 0 ) Sys.println("luz " + size + ": " + Std.int((haxe.Timer.stamp() - tl) * 1000) + " ms");
				phase = 1;
			}
			return progress = (phase == 0 ? gen.progress * 0.75 : 0.75);
		}
		if( phase == 1 ) {
			var n = size >> 4;
			while( chunk < n * n ) {
				buildChunk(chunk % n, Std.int(chunk / n));
				chunk++;
				if( (haxe.Timer.stamp() - t0) * 1000 >= budgetMs ) break;
			}
			if( chunk >= n * n ) phase = 2;
			return progress = 0.75 + 0.25 * chunk / (n * n);
		}
		return progress = 1;
	}

	public function dispose() {
		if( ship != null ) ship.dispose();
		if( ownSky ) sky.dispose();
		for( m in meshes ) {
			if( m == null ) continue;
			m.remove();
			m.primitive.dispose();
		}
		for( ex in meshExtra )
			if( ex != null )
				for( c in ex ) if( c != null ) c.remove();
		meshExtra = [];
		meshes = [];
		meshCx = [];
		meshCy = [];
		root.remove();
	}

	// ---------------------------------------------------------------- consulta de bloques

	public inline function voxel( x : Int, y : Int, z : Int ) : Int {
		if( x < 0 ) x += size else if( x >= size ) x -= size;
		if( y < 0 ) y += size else if( y >= size ) y -= size;
		if( z < 0 ) return 1;
		if( z >= HEIGHT ) return 0;
		return bytes.get(((x + y * size) << ZBITS) | z);
	}

	/** true si la cara contra este voxel se ve (aire o bloque que deja pasar la luz) */
	inline function open( x : Int, y : Int, z : Int ) : Bool {
		var id = voxel(x, y, z);
		return id == 0 || tagOf(id) != BTFull;
	}

	/** como Builder.hx del original: los bloques con alfa (hielo, cristal) dejan ver las caras de lo que hay detras */
	inline function openAlpha( x : Int, y : Int, z : Int ) : Bool {
		var id = voxel(x, y, z);
		if( id == 0 ) return true;
		var t = tagOf(id);
		return t != BTFull && t != BTAlpha;
	}

	/** Builder.isTransparentNot(p, BTWater) del original: ni bloque lleno ni agua (el aire cuenta como abierto) */
	inline function waterOpen( x : Int, y : Int, z : Int ) : Bool {
		var id = voxel(x, y, z);
		if( id == 0 ) return z > 0;
		var t = tagOf(id);
		return t != BTFull && t != BTWater;
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

	// ---------------------------------------------------------------- luz

	/** diagnostico: recuento de celdas por bloque y tipo (solo para pruebas) */
	public function debugStats() : String {
		var counts = new Map<Int, Int>();
		for( i in 0...bytes.length ) {
			var id = bytes.get(i);
			if( id != 0 ) counts.set(id, (counts.exists(id) ? counts.get(id) : 0) + 1);
		}
		var s = "";
		for( id in counts.keys() ) {
			var b = gen.blocks[id];
			s += id + ":" + (b == null ? "null" : Std.string(b.k) + "/" + Std.string(b.type)) + "=" + counts.get(id) + " ";
		}
		return s;
	}

	/** diagnostico: compara la luz actual con la de recalcular todo el planeta (solo para pruebas; la luz actual se queda) */
	public function debugLightCheck() : String {
		var cur = light;
		computeLight();
		var fresh = light;
		light = cur;
		var diff = 0, brighter = 0, maxd = 0, at = -1, seam = 0;
		for( p in 0...fresh.length ) {
			var d = cur.get(p) - fresh.get(p);
			if( d == 0 ) continue;
			diff++;
			if( d > 0 ) brighter++;
			var c = p >> ZBITS, x = c % size, y = Std.int(c / size);
			if( x < 12 || y < 12 || x >= size - 12 || y >= size - 12 ) seam++;
			if( (d < 0 ? -d : d) > maxd ) {
				maxd = d < 0 ? -d : d;
				at = p;
			}
		}
		var col = at >> ZBITS;
		return "celdas con otra luz " + diff + " (mas claras " + brighter + ", mas oscuras " + (diff - brighter) + ", junto a x = 0 o y = 0: " + seam + "), mayor diferencia " + maxd
			+ (at < 0 ? "" : " en " + (col % size) + "," + Std.int(col / size) + "," + (at & (HEIGHT - 1)));
	}

	/** añadido del port para la nave nodriza (hecha en Minecraft): caida de la luz de las lamparas por bloque (null = la de cada bloque) */
	public var lampFalloff : Null<Float> = null;
	/** añadido del port para la nave nodriza: luz minima en todo el mundo (0 = ninguna) */
	public var minLight = 0;

	/** luz de una celda (el mundo da la vuelta; por encima del techo es luz de sol plena) */
	public function lightAt( x : Int, y : Int, z : Int ) : Int {
		if( z >= SHIP_Z && ship != null ) {
			var lx = Std.int(shipLocal(x, shipDX)), ly = Std.int(shipLocal(y, shipDY));
			return lx >= ship.size || ly >= ship.size ? 0 : ship.lightAt(lx, ly, z - SHIP_Z);
		}
		if( z < 0 ) return 0;
		if( z >= HEIGHT ) return Std.int(sunP);
		if( x < 0 ) x += size else if( x >= size ) x -= size;
		if( y < 0 ) y += size else if( y >= size ) y -= size;
		return light.get(((x + y * size) << ZBITS) | z);
	}

	/**
	 * Copia de Builder.relight/processLight para todo el planeta: la luz de sol llena el aire hasta el primer bloque,
	 * se cuela de lado bajo los voladizos y se propaga por las cuevas con la caida de cada bioma;
	 * despues cada bloque luminoso (BFLight) ilumina su entorno.
	 */
	function computeLight() {
		var n = size * size * HEIGHT;
		light = haxe.io.Bytes.alloc(n);
		idTag = [for( b in gen.blocks ) b == null ? 0 : Type.enumIndex(b.type)];
		var lmax = Std.int(sunP);
		var lsun = Std.int(sunP - sunF);
		if( lsun < 0 ) lsun = 0;
		var seeds = new Array<Int>();
		var top = lightTop >= 0 ? lightTop : HEIGHT - 1;
		for( y in 0...size )
			for( x in 0...size ) {
				var col = x + y * size;
				var base = col << ZBITS;
				var cxm = x == 0 ? col + size - 1 : col - 1;
				var cym = y == 0 ? col + size * (size - 1) : col - size;
				var z = top;
				while( z >= 0 ) {
					var p = base | z;
					var t = idTag[bytes.get(p)];
					if( t != 0 ) {
						if( t < NOLIGHT ) {
							light.set(p, lsun);
							seeds.push(p);
						}
						break;
					}
					light.set(p, lmax);
					// la luz se cuela hacia los vecinos -x e -y que aun no la tienen
					var q = (cxm << ZBITS) | z;
					if( light.get(q) == 0 && idTag[bytes.get(q)] < NOLIGHT ) {
						light.set(q, lsun);
						seeds.push(q);
					}
					q = (cym << ZBITS) | z;
					if( light.get(q) == 0 && idTag[bytes.get(q)] < NOLIGHT ) {
						light.set(q, lsun);
						seeds.push(q);
					}
					z--;
				}
				// bajo el primer bloque: aire/bloques con luz directa a su lado
				while( z > 0 ) {
					var p = base | z;
					if( idTag[bytes.get(p)] < NOLIGHT && (isSunAir((cxm << ZBITS) | z, lmax) || isSunAir((cym << ZBITS) | z, lmax)) ) {
						light.set(p, lsun);
						seeds.push(p);
					}
					z--;
				}
			}
		flood(seeds, sunP - sunF * 2, sunF);

		// bloques luminosos
		var infos = new Array<{ p : Int, f : Float }>();
		var lightIdx = [for( b in gen.blocks ) -1];
		for( i in 0...gen.blocks.length ) {
			var b = gen.blocks[i];
			if( b == null || b.special == null ) continue;
			switch( b.special ) {
			case BFLight(p, f):
				var ip = Std.int(p);
				if( ip > 15 ) ip = 15;
				lightIdx[i] = infos.length;
				infos.push({ p : ip, f : lampFalloff != null ? lampFalloff : (f == null ? 1.0 : f) });
			default:
			}
		}
		if( infos.length > 0 ) {
			var powers = [for( b in gen.blocks ) 0.];
			for( i in 0...gen.blocks.length ) {
				var b = gen.blocks[i];
				if( b == null || b.special == null ) continue;
				switch( b.special ) {
				case BFLight(p, _): powers[i] = p;
				default:
				}
			}
			for( p in 0...n ) {
				var id = bytes.get(p);
				var li = lightIdx[id];
				if( li < 0 ) continue;
				var info = infos[li];
				if( light.get(p) >= info.p ) continue;
				light.set(p, info.p);
				flood([p], powers[id] - info.f, info.f);
			}
		}
		if( minLight > 0 )
			for( p in 0...n )
				if( light.get(p) < minLight ) light.set(p, minLight);
	}

	inline function isSunAir( p : Int, lmax : Int ) : Bool {
		return light.get(p) == lmax && idTag[bytes.get(p)] == 0;
	}

	/** onda expansiva: cada anillo baja la luz en delta (Builder.processLight) */
	// listas de la inundacion reutilizadas (antes se creaba una por paso: con miles de luces, mucha basura y pausas)
	var floodA = new Array<Int>();
	var floodB = new Array<Int>();

	function flood( seeds : Array<Int>, lvalue : Float, delta : Float ) {
		var cur = seeds;
		var sz = size;
		var spare = floodA;
		while( true ) {
			var l = Std.int(lvalue);
			if( l > 15 ) l = 15;
			if( l <= 0 || cur.length == 0 ) break;
			var next = spare == cur ? (cur == floodA ? floodB : floodA) : spare;
			next.resize(0);
			for( p in cur ) {
				var z = p & (HEIGHT - 1);
				var col = p >> ZBITS;
				var x = col % sz;
				var y = Std.int(col / sz);
				var c = x == 0 ? col + sz - 1 : col - 1;
				spread((c << ZBITS) | z, l, next);
				c = x == sz - 1 ? col - (sz - 1) : col + 1;
				spread((c << ZBITS) | z, l, next);
				c = y == 0 ? col + sz * (sz - 1) : col - sz;
				spread((c << ZBITS) | z, l, next);
				c = y == sz - 1 ? col - sz * (sz - 1) : col + sz;
				spread((c << ZBITS) | z, l, next);
				if( z > 0 ) spread(p - 1, l, next);
				if( z < HEIGHT - 1 ) spread(p + 1, l, next);
			}
			spare = cur == floodA || cur == floodB ? cur : (next == floodA ? floodB : floodA);
			cur = next;
			lvalue -= delta;
		}
	}

	inline function spread( q : Int, l : Int, next : Array<Int> ) {
		if( light.get(q) < l && idTag[bytes.get(q)] < NOLIGHT && (!useMask || mask.get(q >> ZBITS) != 0) ) {
			light.set(q, l);
			next.push(q);
		}
	}

	// ---------------------------------------------------------------- nave

	function initShip( d : ShipData.ShipDataInfo ) {
		isShip = true;
		wraps = false;
		bytes = haxe.io.Bytes.alloc(size * size * HEIGHT);
		initLightTables();
		for( c in d.cells )
			bytes.set(((c.x + c.y * size) << ZBITS) | c.z, localId(Block.all[c.id]));
	}

	/** coordenada de la nave que corresponde a una del planeta (el planeta da la vuelta) */
	function shipLocal( v : Float, d : Int ) : Float {
		var l = (v - d) % size;
		if( l < 0 ) l += size;
		return l;
	}

	function shipBlock( x : Int, y : Int, z : Int ) : Block {
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
		var soil = Block.get(binf.soils[1]);
		var through = new Map<Int, Bool>();
		for( b in binf.startThrough ) through.set(Block.get(b).index, true);
		var ntry = 10000;
		while( --ntry > 0 ) {
			var x = rnd.random(size - 2) + 1;
			var y = rnd.random(size - 2) + 1;
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

	function initLightTables() {
		idTag = [];
		lightIdx = [];
		lightInfos = [];
		for( i in 0...gen.blocks.length ) registerId(i);
	}

	/** tablas de tipo y de luz de un id local de bloque */
	function registerId( id : Int ) {
		while( idTag.length <= id ) idTag.push(0);
		while( lightIdx.length <= id ) lightIdx.push(-1);
		var b = gen.blocks[id];
		idTag[id] = b == null ? 0 : Type.enumIndex(b.type);
		lightIdx[id] = -1;
		if( b != null && b.special != null )
			switch( b.special ) {
			case BFLight(p, f):
				var ip = Std.int(p);
				if( ip > 15 ) ip = 15;
				lightIdx[id] = lightInfos.length;
				lightInfos.push({ p : ip, f : lampFalloff != null ? lampFalloff : (f == null ? 1.0 : f), pw : p });
			default:
			}
	}

	/** id local (de este planeta) de un bloque global; lo da de alta si el mundo no lo tenia */
	public function localId( b : Block ) : Int {
		if( b == null ) return 0;
		var id = gen.alloc(b.k);
		for( i in idTag.length...gen.blocks.length ) registerId(i);
		return id > 255 ? 0 : id;
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
			bytes.set(key, localId(b));
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
				if( bytes.get(base | z) != seaId ) continue;
				seaCount[z]++;
				if( z > seaLevel ) bytes.set(base | z, 0);
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
	 * planeta y el nivel baja 1; el contador pierde el agua que el generador puso en esa capa.
	 * El original rehace todas las celdas (cada una recalcula su luz al rehacerse). Aqui la luz solo cambia donde la capa
	 * quitada recibia el sol, con las mismas reglas que computeLight: el sol baja hasta el nuevo primer bloque, da luz de sol a
	 * los lados y se reparte desde ahi (stepSeaLight, en varios fotogramas si es mucho). Luego se rehacen solo los trozos con
	 * celdas quitadas o con otra luz y los que dan a ellos, los mas cercanos a la camara primero.
	 */
	public function reduceWater() {
		floodFlag = false;
		var z = seaLevel;
		if( z <= 0 || seaCount == null ) return;
		// una bajada anterior a medias se termina antes
		while( seaJob != null ) stepSeaLight(1e9);
		// cambio del port: Local.reduceWater cuenta Type.enumIndex(BWater), no el agua del bioma, y en los otros biomas el
		// contador no bajaba nunca (cada bloque nuevo volvia a bajar el mar); aqui se cuenta el agua del bioma
		waterFlood -= z < seaCount.length ? seaCount[z] : 0;
		seaLevel--;
		var cols = size * size;
		var t0 = haxe.Timer.stamp();
		var j = seaJob = new SeaLight();
		j.z = z;
		j.top = lightTop >= 0 ? lightTop : HEIGHT - 1;
		j.lmax = Std.int(sunP);
		j.chg = haxe.io.Bytes.alloc(cols);
		j.sky = haxe.io.Bytes.alloc(cols);
		j.sky.fill(0, cols, 255);
		j.seen = haxe.io.Bytes.alloc((cols << ZBITS) >> 3);
		// las celdas de esa capa cambiadas en la partida (pocas) quedan como aire en el guardado; las del generador las vuelve a
		// quitar initSea al cargar
		for( k in [for( k in editMap.keys() ) if( (k & (HEIGHT - 1)) == z && bytes.get(k) == seaId ) k] ) {
			editMap.set(k, 0);
			waterLvl.remove(k);
		}
		j.cand = [];
		for( col in 0...cols ) {
			var p = (col << ZBITS) | z;
			var id = bytes.get(p);
			if( id != seaId ) {
				// agua del mar bajo un bloque en la nueva capa de arriba: con olas tiene cara de arriba (Builder.hx: anim && z == waterLevel)
				if( id != 0 && bytes.get(p - 1) == seaId ) j.chg.set(col, 1);
				continue;
			}
			bytes.set(p, 0);
			j.removed++;
			j.chg.set(col, 1);
			// puede estar al sol si encima hay luz plena (la tiene todo el aire al sol); se mira en stepSeaLight
			if( z == j.top || light.get(p + 1) >= j.lmax ) j.cand.push(col);
		}
		j.lsun = Std.int(sunP - sunF);
		if( j.lsun < 0 ) j.lsun = 0;
		j.cur = [];
		j.lvalue = sunP - sunF * 2;
		j.time = haxe.Timer.stamp() - t0;
		if( FLUSH_TIME ) Sys.println("flush: capa del mar quitada " + Std.int(j.time * 1000) + " ms");
		stepSeaLight(SEA_BUDGET);
	}

	/** primera altura desde la que la columna es aire hasta arriba (aire al sol), calculada una vez por bajada */
	inline function skyZ( col : Int ) : Int {
		var j = seaJob;
		var s = j.sky.get(col);
		if( s == 255 ) {
			var base = col << ZBITS;
			s = j.top + 1;
			while( s > 0 ) {
				var id = bytes.get(base | (s - 1));
				if( id != 0 && idTag[id] != 0 ) break;
				s--;
			}
			j.sky.set(col, s);
		}
		return s;
	}

	/**
	 * Columna con la capa quitada al aire: el aire nuevo al sol tiene luz plena y da luz de sol a los lados como en
	 * computeLight, a -x y -y (la que se cuela) y a +x y +y (bajo el primer bloque), salvo de la ultima columna o fila a la
	 * primera, que computeLight recorre antes; el primer bloque, ahora mas abajo, tambien
	 */
	function seaSunColumn( col : Int ) {
		var j = seaJob;
		var x = col % size, y = Std.int(col / size);
		var base = col << ZBITS;
		var s = skyZ(col);
		j.sunCols++;
		for( k in s...j.z + 1 ) {
			var p = base | k;
			if( light.get(p) < j.lmax ) light.set(p, j.lmax);
			sunSide(((x == 0 ? size - 1 : x - 1) + y * size) << ZBITS | k);
			sunSide((x + (y == 0 ? size - 1 : y - 1) * size) << ZBITS | k);
			if( x < size - 1 ) sunSide(p + (1 << ZBITS));
			if( y < size - 1 ) sunSide(p + (size << ZBITS));
		}
		if( s > 0 ) sunSide(base | (s - 1));
	}

	/**
	 * Luz de sol de computeLight en una celda junto al aire al sol (o el primer bloque): semilla del reparto, aunque ya tenga
	 * mas luz de una lampara (en computeLight el sol va antes que las lamparas)
	 */
	function sunSide( q : Int ) {
		var j = seaJob;
		var t = idTag[bytes.get(q)];
		if( t >= NOLIGHT || (j.seen.get(q >> 3) & (1 << (q & 7))) != 0 || (t == 0 && (q & (HEIGHT - 1)) >= skyZ(q >> ZBITS)) ) return;
		j.seen.set(q >> 3, j.seen.get(q >> 3) | (1 << (q & 7)));
		if( light.get(q) < j.lsun ) {
			light.set(q, j.lsun);
			j.chg.set(q >> ZBITS, 1);
		}
		j.cur.push(q);
	}

	/**
	 * El reparto de computeLight (flood) desde las semillas nuevas, anillo a anillo, durante budget segundos. Cruza tambien las
	 * celdas que ya tienen mas luz (de una lampara u otra semilla: en computeLight el sol se reparte antes que las lamparas) y
	 * no cruza el aire al sol; cada celda una vez, en el anillo mas cercano. Al acabar pone a rehacer los trozos tocados.
	 */
	function stepSeaLight( budget : Float ) {
		var j = seaJob;
		var ts = haxe.Timer.stamp();
		var sz = size, n = 0;
		// primero las semillas: las columnas de la capa quitada que ahora estan al aire hasta arriba
		while( j.ci < j.cand.length ) {
			var col = j.cand[j.ci++];
			if( skyZ(col) <= j.z ) seaSunColumn(col);
			if( (++n & 255) == 0 && haxe.Timer.stamp() - ts > budget ) {
				j.time += haxe.Timer.stamp() - ts;
				j.frames++;
				return;
			}
		}
		while( true ) {
			var l = Std.int(j.lvalue);
			if( l > 15 ) l = 15;
			if( l <= 0 || j.cur.length == 0 ) break;
			if( j.i >= j.cur.length ) {
				j.cur = j.next;
				j.next = [];
				j.i = 0;
				j.lvalue -= sunF;
				continue;
			}
			var p = j.cur[j.i++];
			var pz = p & (HEIGHT - 1);
			var col = p >> ZBITS;
			var x = col % sz, y = Std.int(col / sz);
			seaSpread(((x == 0 ? col + sz - 1 : col - 1) << ZBITS) | pz, l);
			seaSpread(((x == sz - 1 ? col - (sz - 1) : col + 1) << ZBITS) | pz, l);
			seaSpread(((y == 0 ? col + sz * (sz - 1) : col - sz) << ZBITS) | pz, l);
			seaSpread(((y == sz - 1 ? col - sz * (sz - 1) : col + sz) << ZBITS) | pz, l);
			if( pz > 0 ) seaSpread(p - 1, l);
			if( pz < HEIGHT - 1 ) seaSpread(p + 1, l);
			j.cells++;
			if( (++n & 1023) == 0 && haxe.Timer.stamp() - ts > budget ) {
				j.time += haxe.Timer.stamp() - ts;
				j.frames++;
				if( FLUSH_TIME ) Sys.println("flush: luz del mar " + Std.int((haxe.Timer.stamp() - ts) * 1000) + " ms");
				return;
			}
		}
		j.time += haxe.Timer.stamp() - ts;
		j.frames++;
		if( FLUSH_TIME ) Sys.println("flush: luz del mar " + Std.int((haxe.Timer.stamp() - ts) * 1000) + " ms (fin)");
		seaJob = null;
		// trozos que rehacer: los de las columnas tocadas y los que dan a ellas (caras y esquinas del agua en el borde)
		var nc = size >> 4;
		var queued = haxe.io.Bytes.alloc(nc * nc);
		for( id in seaChunks ) queued.set(id, 1);
		for( col in 0...size * size ) {
			if( j.chg.get(col) == 0 ) continue;
			var x = col % size, y = Std.int(col / size);
			for( dy in -1...2 )
				for( dx in -1...2 ) {
					var id = (wrapC(x + dx) >> 4) + (wrapC(y + dy) >> 4) * nc;
					if( queued.get(id) != 0 ) continue;
					queued.set(id, 1);
					seaChunks.push(id);
				}
		}
		var vx = viewX / CSIZE - 0.5, vy = viewY / CSIZE - 0.5;
		inline function dist( id : Int ) : Float {
			var dx = Math.abs(id % nc - vx), dy = Math.abs(Std.int(id / nc) - vy);
			if( dx > nc * 0.5 ) dx = nc - dx;
			if( dy > nc * 0.5 ) dy = nc - dy;
			return dx * dx + dy * dy;
		}
		seaChunks.sort(function(a, b) return Reflect.compare(dist(a), dist(b)));
		if( Dev.trace || FLUSH_TIME )
			Sys.println("mar: capa " + j.z + " quitada (" + j.removed + " celdas, " + j.sunCols + " al sol), nivel " + seaLevel + ", inundacion " + waterFlood
				+ "; luz " + Std.int(j.time * 1000) + " ms en " + j.frames + " fotogramas (" + j.cells + " celdas), " + seaChunks.length + " trozos que rehacer");
	}

	inline function seaSpread( q : Int, l : Int ) {
		var j = seaJob;
		var t = idTag[bytes.get(q)];
		if( t < NOLIGHT && (j.seen.get(q >> 3) & (1 << (q & 7))) == 0 ) {
			var v = light.get(q);
			if( !(t == 0 && v >= j.lmax && (q & (HEIGHT - 1)) >= skyZ(q >> ZBITS)) ) {
				j.seen.set(q >> 3, j.seen.get(q >> 3) | (1 << (q & 7)));
				if( v < l ) {
					light.set(q, l);
					j.chg.set(q >> ZBITS, 1);
				}
				j.next.push(q);
			}
		}
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
		else {
			// mismo bloque, otro nivel: solo hay que rehacer la malla
			var n = size >> 4;
			for( dy in -1...2 )
				for( dx in -1...2 ) {
					var id = (wrapC(x + dx) >> 4) + (wrapC(y + dy) >> 4) * n;
					if( immediate.indexOf(id) < 0 ) immediate.push(id);
				}
		}
		if( level > 0 ) waterLvl.set(key, level) else waterLvl.remove(key);
		editMap.set(key, b.index | (level << 16));
	}

	/**
	 * Superficie inclinada de los liquidos que fluyen (anadido del port, como en Minecraft): familia 1 = agua (BTWater;
	 * el mar es fuente, el agua puesta fluye con niveles en waterLvl), familia 2 = cascada (fuente y Fall..Fall4).
	 */
	function liquidFam( id : Int ) : Int {
		if( id == 0 ) return 0;
		if( tagOf(id) == BTWater ) return 1;
		var b = gen.blocks[id];
		if( b == null ) return 0;
		return switch( b.k ) { case BCascadeSource, BCascadeFall, BCascadeFall2, BCascadeFall3, BCascadeFall4: 2; default: 0; };
	}

	inline function isWaterId( id : Int ) : Bool {
		return id != 0 && tagOf(id) == BTWater;
	}

	/** altura de la superficie de una celda (sin liquido encima): fuente 0.9 y cada paso 0.15 menos */
	function liquidCellH( x : Int, y : Int, z : Int, fam : Int ) : Float {
		var step = 0;
		if( fam == 1 ) {
			var v = waterLvl.get(cellKey(x, y, z));
			step = v == null || v >= 8 ? 0 : v;
		} else {
			var b = gen.blocks[voxel(x, y, z)];
			step = switch( b.k ) { case BCascadeFall: 1; case BCascadeFall2: 2; case BCascadeFall3: 3; case BCascadeFall4: 4; default: 0; };
		}
		return 0.9 - step * 0.15;
	}

	/** la celda se dibuja llena: con liquido igual encima, o agua del mar con un bloque encima (como el original) */
	function liquidFull( x : Int, y : Int, z : Int, fam : Int ) : Bool {
		var up = voxel(x, y, z + 1);
		if( liquidFam(up) == fam ) return true;
		return fam == 1 && up != 0 && !waterLvl.exists(cellKey(x, y, z));
	}

	/** altura de una esquina: media de las celdas de la familia que la tocan (1 si alguna tiene liquido encima) */
	function liquidCorner( cx : Int, cy : Int, z : Int, fam : Int ) : Float {
		var sum = 0., n = 0;
		for( d in 0...4 ) {
			var ix = cx - 1 + (d & 1), iy = cy - 1 + (d >> 1);
			if( liquidFam(voxel(ix, iy, z)) != fam ) continue;
			if( liquidFull(ix, iy, z, fam) ) return 1.;
			sum += liquidCellH(ix, iy, z, fam);
			n++;
		}
		return n == 0 ? 0.9 : sum / n;
	}

	/** caras de un liquido con la superficie inclinada; open dice que lados se ven */
	function addLiquid( m : MeshBuf, b : Block, fam : Int, x : Int, y : Int, z : Int, open : Int -> Int -> Int -> Bool, su : Float, sd : Float, sx : Float, sy : Float, neg : Bool ) {
		var fx = x, fy = y, fz = z;
		var full = liquidFull(x, y, z, fam);
		var h00 = fz + (full ? 1. : liquidCorner(x, y, z, fam)), h10 = fz + (full ? 1. : liquidCorner(x + 1, y, z, fam));
		var h11 = fz + (full ? 1. : liquidCorner(x + 1, y + 1, z, fam)), h01 = fz + (full ? 1. : liquidCorner(x, y + 1, z, fam));
		// con olas, la capa de arriba del mar tiene su cara de arriba aunque haya un bloque lleno encima (Builder.hx del original:
		// anim && z == waterLevel): si no, al bajar la ola quedaba una franja sin agua bajo el borde del bloque
		if( !full || open(x, y, z + 1) || (fam == 1 && wave != null && !isWaterId(voxel(x, y, z + 1)) && z == waterLevel()) )
			addQuadL(m, [fx, fy, h00, fx + 1, fy, h10, fx + 1, fy + 1, h11, fx, fy + 1, h01], b.tu, su, neg, 0, 0, 1, x, y, z);
		if( open(x, y, z - 1) ) addQuadL(m, [fx, fy + 1, fz, fx + 1, fy + 1, fz, fx + 1, fy, fz, fx, fy, fz], b.td, sd, neg, 0, 0, -1, x, y, z);
		if( open(x - 1, y, z) ) addQuadL(m, [fx, fy + 1, fz, fx, fy, fz, fx, fy, h00, fx, fy + 1, h01], b.tlr, sx, neg, -1, 0, 0, x, y, z);
		if( open(x + 1, y, z) ) addQuadL(m, [fx + 1, fy, fz, fx + 1, fy + 1, fz, fx + 1, fy + 1, h11, fx + 1, fy, h10], b.tlr, sx, neg, 1, 0, 0, x, y, z);
		if( open(x, y - 1, z) ) addQuadL(m, [fx, fy, fz, fx + 1, fy, fz, fx + 1, fy, h10, fx, fy, h00], b.tlr, sy, neg, 0, -1, 0, x, y, z);
		if( open(x, y + 1, z) ) addQuadL(m, [fx + 1, fy + 1, fz, fx, fy + 1, fz, fx, fy + 1, h01, fx + 1, fy + 1, h11], b.tlr, sy, neg, 0, 1, 0, x, y, z);
		if( full ) {
			// llena junto a liquido mas bajo: la pared entre las dos alturas, si no queda un hueco
			inline function lower( nx, ny ) return liquidFam(voxel(nx, ny, z)) == fam && !liquidFull(nx, ny, z, fam);
			var c00 = fz + liquidCorner(x, y, z, fam), c10 = fz + liquidCorner(x + 1, y, z, fam), c11 = fz + liquidCorner(x + 1, y + 1, z, fam), c01 = fz + liquidCorner(x, y + 1, z, fam);
			if( lower(x - 1, y) ) addQuadL(m, [fx, fy + 1, c01, fx, fy, c00, fx, fy, h00, fx, fy + 1, h01], b.tlr, sx, neg, -1, 0, 0, x, y, z);
			if( lower(x + 1, y) ) addQuadL(m, [fx + 1, fy, c10, fx + 1, fy + 1, c11, fx + 1, fy + 1, h11, fx + 1, fy, h10], b.tlr, sx, neg, 1, 0, 0, x, y, z);
			if( lower(x, y - 1) ) addQuadL(m, [fx, fy, c00, fx + 1, fy, c10, fx + 1, fy, h10, fx, fy, h00], b.tlr, sy, neg, 0, -1, 0, x, y, z);
			if( lower(x, y + 1) ) addQuadL(m, [fx + 1, fy + 1, c11, fx, fy + 1, c01, fx, fy + 1, h01, fx + 1, fy + 1, h11], b.tlr, sy, neg, 0, 1, 0, x, y, z);
		}
	}

	/** Cambia un bloque (null = aire). El trozo se rehace al momento; la luz y los vecinos, en los siguientes fotogramas. */
	public function setBlock( x : Int, y : Int, z : Int, b : Block ) : Void {
		if( z >= SHIP_Z ) {
			// la nave tiene su propio volumen
			if( ship != null ) ship.setBlock(Std.int(shipLocal(x, shipDX)), Std.int(shipLocal(y, shipDY)), z - SHIP_Z, b);
			return;
		}
		x = wrapC(x);
		y = wrapC(y);
		if( z < 1 || z >= HEIGHT - 1 ) return;
		var key = ((x + y * size) << ZBITS) | z;
		bytes.set(key, localId(b));
		editMap.set(key, b == null ? 0 : b.index);
		waterLvl.remove(key);
		var n = size >> 4;
		for( dy in -1...2 )
			for( dx in -1...2 ) {
				var c = wrapC(x + dx) >> 4, d = wrapC(y + dy) >> 4;
				var id = c + d * n;
				if( immediate.indexOf(id) < 0 ) immediate.push(id);
			}
		// mientras tanto, un hueco nuevo toma la luz de su vecino mas claro (si no, se veria negro hasta recalcular)
		if( idTag[bytes.get(key)] < NOLIGHT ) {
			var best = light.get(key);
			inline function nb( q : Int ) { var v = light.get(q); if( v > best ) best = v; }
			nb(((wrapC(x - 1) + y * size) << ZBITS) | z);
			nb(((wrapC(x + 1) + y * size) << ZBITS) | z);
			nb(((x + wrapC(y - 1) * size) << ZBITS) | z);
			nb(((x + wrapC(y + 1) * size) << ZBITS) | z);
			nb(key - 1);
			nb(key + 1);
			light.set(key, best);
		}
		pendingRelight.push(key);
		// la luz de la zona se recalcula cuando se deja de editar un momento: al excavar seguido (creativo) no se
		// recalcula en cada bloque, que en la nave nodriza (miles de luces) bajaba mucho los fotogramas
		editQuiet = 8;
		if( onSetBlock != null ) onSetBlock(x, y, z);
	}

	var editQuiet = 0;

	/** Procesa lo pendiente tras editar: trozos inmediatos, una zona de luz y unos pocos trozos por fotograma. */
	static var FLUSH_TIME = Sys.args().indexOf("--flushtime") >= 0;
	public function flush() {
		var n = size >> 4;
		var tm = FLUSH_TIME && hasPending() ? haxe.Timer.stamp() : 0.;
		var nImm = immediate.length;
		while( immediate.length > 0 ) {
			var id = immediate.pop();
			buildChunk(id % n, Std.int(id / n));
		}
		if( tm > 0 ) { var t = haxe.Timer.stamp(); if( nImm > 0 ) Sys.println("flush: " + nImm + " trozos inmediatos " + Std.int((t - tm) * 1000) + " ms"); tm = t; }
		if( editQuiet > 0 ) editQuiet--;
		else if( pendingRelight.length > 0 ) {
			var key = pendingRelight.shift();
			var col = key >> ZBITS;
			var x = col % size, y = Std.int(col / size);
			// las ediciones cercanas entran en la misma zona: una sola pasada para todas
			var i = pendingRelight.length;
			while( i-- > 0 ) {
				var c2 = pendingRelight[i] >> ZBITS;
				var ddx = c2 % size - x, ddy = Std.int(c2 / size) - y;
				if( ddx > size >> 1 ) ddx -= size; else if( ddx < -(size >> 1) ) ddx += size;
				if( ddy > size >> 1 ) ddy -= size; else if( ddy < -(size >> 1) ) ddy += size;
				if( ddx >= -6 && ddx <= 6 && ddy >= -6 && ddy <= 6 ) pendingRelight.splice(i, 1);
			}
			// solo se rehacen los trozos donde la luz ha cambiado de verdad (antes, todos los de la zona)
			var changed = relightRegion(x, y, 12);
			if( tm > 0 ) { var t = haxe.Timer.stamp(); Sys.println("flush: luz de la zona " + Std.int((t - tm) * 1000) + " ms, trozos con cambios " + (changed == null ? -1 : changed.length)); tm = t; }
			if( changed == null )
				for( cy in (y - 12) >> 4...((y + 12) >> 4) + 1 )
					for( cx in (x - 12) >> 4...((x + 12) >> 4) + 1 ) {
						var wx = cx < 0 ? cx + n : (cx >= n ? cx - n : cx);
						var wy = cy < 0 ? cy + n : (cy >= n ? cy - n : cy);
						var id = wx + wy * n;
						if( lightChunks.indexOf(id) < 0 ) lightChunks.push(id);
					}
			else
				for( id in changed ) if( lightChunks.indexOf(id) < 0 ) lightChunks.push(id);
		}
		var k = 0;
		// uno por fotograma (en la nave nodriza cada trozo cuesta ~10 ms)
		while( lightChunks.length > 0 && k < 1 ) {
			var id = lightChunks.shift();
			buildChunk(id % n, Std.int(id / n));
			k++;
		}
		if( tm > 0 && k > 0 ) Sys.println("flush: " + k + " trozos de luz " + Std.int((haxe.Timer.stamp() - tm) * 1000) + " ms (quedan " + lightChunks.length + ")");
		// bajada del mar: primero se acaba de repartir la luz; luego los trozos tocados, al menos uno por fotograma y los que
		// quepan en SEA_BUDGET
		if( seaJob != null ) stepSeaLight(SEA_BUDGET);
		else if( seaChunks.length > 0 ) {
			var ts = haxe.Timer.stamp();
			k = 0;
			do {
				var id = seaChunks.shift();
				buildChunk(id % n, Std.int(id / n));
				k++;
			} while( seaChunks.length > 0 && haxe.Timer.stamp() - ts < SEA_BUDGET );
			if( FLUSH_TIME ) Sys.println("flush: " + k + " trozos del mar " + Std.int((haxe.Timer.stamp() - ts) * 1000) + " ms (quedan " + seaChunks.length + ")");
		}
	}

	/** tiempo por fotograma para la luz y los trozos de una bajada del mar (s) */
	static inline var SEA_BUDGET = 0.006;

	public inline function hasPending() : Bool {
		return immediate.length > 0 || pendingRelight.length > 0 || lightChunks.length > 0 || seaChunks.length > 0 || seaJob != null;
	}

	/** Recalcula la luz de una zona (radio rIn) usando las fuentes de una zona mayor, como el original pero local. */
	/** devuelve los trozos cuya luz cambio (null = no se sabe: hay que rehacerlos todos) */
	function relightRegion( cx : Int, cy : Int, rIn : Int ) : Array<Int> {
		var rOut = rIn + 16;
		if( rOut * 2 + 1 >= size ) {
			computeLight();
			return null;
		}
		var changed = new Array<Int>();
		var nc = size >> 4;
		var span = rOut * 2 + 1;
		if( mask == null ) mask = haxe.io.Bytes.alloc(size * size);
		var saved = haxe.io.Bytes.alloc(span * span * HEIGHT);
		var cols = new Array<Int>();
		for( dy in -rOut...rOut + 1 )
			for( dx in -rOut...rOut + 1 ) {
				var col = wrapC(cx + dx) + wrapC(cy + dy) * size;
				cols.push(col);
				mask.set(col, 1);
			}
		for( i in 0...cols.length ) {
			var base = cols[i] << ZBITS;
			saved.blit(i * HEIGHT, light, base, HEIGHT);
			light.fill(base, HEIGHT, 0);
		}
		useMask = true;
		var lmax = Std.int(sunP);
		var lsun = Std.int(sunP - sunF);
		if( lsun < 0 ) lsun = 0;
		var seeds = new Array<Int>();
		var ts = FLUSH_TIME ? haxe.Timer.stamp() : 0.;
		for( col in cols ) sunColumn(col, lmax, lsun, seeds);
		flood(seeds, sunP - sunF * 2, sunF);
		if( FLUSH_TIME ) Sys.println("  sol " + Std.int((haxe.Timer.stamp() - ts) * 1000) + " ms");
		for( col in cols ) {
			var base = col << ZBITS;
			for( z in 1...HEIGHT ) {
				var p = base | z;
				var li = lightIdx[bytes.get(p)];
				if( li < 0 ) continue;
				var info = lightInfos[li];
				if( light.get(p) >= info.p ) continue;
				light.set(p, info.p);
				// la caida de la nave nodriza se fija despues de crear el mundo: aqui igual que en computeLight
				var f = lampFalloff != null ? lampFalloff : info.f;
				flood([p], info.pw - f, f);
			}
		}
		if( FLUSH_TIME ) Sys.println("  lamparas " + Std.int((haxe.Timer.stamp() - ts) * 1000) + " ms");
		useMask = false;
		for( i in 0...cols.length ) {
			var dx = i % span - rOut, dy = Std.int(i / span) - rOut;
			if( dx > rIn || dx < -rIn || dy > rIn || dy < -rIn )
				light.blit(cols[i] << ZBITS, saved, i * HEIGHT, HEIGHT);
			else {
				var base = cols[i] << ZBITS;
				// la luz minima de la nave nodriza tambien al recalcular una zona (si no, al abrir una puerta todo se oscurecia)
				if( minLight > 0 )
					for( z in 0...HEIGHT ) if( light.get(base | z) < minLight ) light.set(base | z, minLight);
				var diff = false, sb = i * HEIGHT;
				for( z in 0...HEIGHT )
					if( light.get(base | z) != saved.get(sb + z) ) {
						diff = true;
						break;
					}
				if( diff ) {
					// la luz de una columna se ve en su trozo y, en los bordes, en los vecinos (caras que dan a ella)
					var col = cols[i];
					var x = col % size, y = Std.int(col / size);
					for( ddy in -1...2 )
						for( ddx in -1...2 ) {
							var id = (wrapC(x + ddx) >> 4) + (wrapC(y + ddy) >> 4) * nc;
							if( changed.indexOf(id) < 0 ) changed.push(id);
						}
				}
			}
			mask.set(cols[i], 0);
		}
		return changed;
	}

	/** luz de sol de una columna (misma logica que computeLight, para una zona) */
	function sunColumn( col : Int, lmax : Int, lsun : Int, seeds : Array<Int> ) {
		var x = col % size, y = Std.int(col / size);
		var base = col << ZBITS;
		var cxm = x == 0 ? col + size - 1 : col - 1;
		var cym = y == 0 ? col + size * (size - 1) : col - size;
		var okx = !useMask || mask.get(cxm) != 0;
		var oky = !useMask || mask.get(cym) != 0;
		var z = lightTop >= 0 ? lightTop : HEIGHT - 1;
		while( z >= 0 ) {
			var p = base | z;
			var t = idTag[bytes.get(p)];
			if( t != 0 ) {
				if( t < NOLIGHT ) {
					light.set(p, lsun);
					seeds.push(p);
				}
				break;
			}
			light.set(p, lmax);
			if( okx ) {
				var q = (cxm << ZBITS) | z;
				if( light.get(q) == 0 && idTag[bytes.get(q)] < NOLIGHT ) {
					light.set(q, lsun);
					seeds.push(q);
				}
			}
			if( oky ) {
				var q = (cym << ZBITS) | z;
				if( light.get(q) == 0 && idTag[bytes.get(q)] < NOLIGHT ) {
					light.set(q, lsun);
					seeds.push(q);
				}
			}
			z--;
		}
		while( z > 0 ) {
			var p = base | z;
			if( idTag[bytes.get(p)] < NOLIGHT && ((okx && isSunAir((cxm << ZBITS) | z, lmax)) || (oky && isSunAir((cym << ZBITS) | z, lmax))) ) {
				light.set(p, lsun);
				seeds.push(p);
			}
			z--;
		}
	}

	// ---------------------------------------------------------------- mallado

	var shv = [0., 0., 0., 0.];
	var redFace = -1;
	var redB : Array<Float>;

	function addQuad( m : MeshBuf, p : Array<Float>, tile : Int, shade : Float ) {
		shv[0] = shv[1] = shv[2] = shv[3] = shade;
		addQuad4(m, p, tile);
	}

	/**
	 * Cara con la luz del original (Builder.addQuad): cada vertice promedia la luz de las 4 celdas que lo rodean
	 * en el plano exterior de la cara, multiplicada por la sombra de la cara. Con BFNoShade (neg) no depende de la luz.
	 * (cx,cy,cz) es la celda del bloque y (ox,oy,oz) la normal de la cara; uniform usa solo la celda exterior.
	 */
	function addQuadL( m : MeshBuf, p : Array<Float>, tile : Int, shade : Float, neg : Bool, ox : Int, oy : Int, oz : Int, cx : Int, cy : Int, cz : Int, uniform = false, ?lp : Array<Float> ) {
		if( tile < 0 || tile >= 0xFFF ) return;
		if( neg ) {
			shv[0] = shv[1] = shv[2] = shv[3] = shade;
		} else if( uniform || (lp != null && lightAt(cx + ox, cy + oy, cz + oz) == 0) ) {
			var l : Float = lightAt(cx + ox, cy + oy, cz + oz);
			// cambio del port: si al lado hay otro bloque que no deja pasar la luz (p. ej. dos hierros juntos), la cara
			// salia negra; se usa la luz mas alta alrededor del bloque
			if( l == 0 ) {
				l = (Math.max(Math.max(lightAt(cx + 1, cy, cz), lightAt(cx - 1, cy, cz)), Math.max(Math.max(lightAt(cx, cy + 1, cz), lightAt(cx, cy - 1, cz)), Math.max(lightAt(cx, cy, cz + 1), lightAt(cx, cy, cz - 1)))));
			}
			l = l * shade / LBASE;
			shv[0] = shv[1] = shv[2] = shv[3] = l;
		} else {
			var nx = cx + ox, ny = cy + oy, nz = cz + oz;
			// lp: esquinas de la cara entera de la celda, para la luz de las caras de un bloque parcial (Builder.addCustomQuad:
			// la luz de cada esquina sale de las celdas vecinas, como en un bloque entero, aunque la cara sea mas pequena)
			var q = lp != null ? lp : p;
			for( k in 0...4 ) {
				var vx = Std.int(q[k * 3]), vy = Std.int(q[k * 3 + 1]), vz = Std.int(q[k * 3 + 2]);
				var s = 0;
				for( a in 0...2 )
					for( b in 0...2 ) {
						if( ox != 0 ) s += lightAt(nx, vy - a, vz - b);
						else if( oy != 0 ) s += lightAt(vx - a, ny, vz - b);
						else s += lightAt(vx - a, vy - b, nz);
					}
				shv[k] = s * shade * (0.25 / LBASE);
			}
		}
		addQuad4(m, p, tile);
	}

	function addQuad4( m : MeshBuf, p : Array<Float>, tile : Int ) {
		if( tile < 0 || tile >= 0xFFF ) return;
		var tx = tile & 63, ty = tile >> 6;
		var u0 = tx / 64 + (1 - TE) / 128, v0 = ty / 64 + (1 - TE) / 128;
		var u1 = u0 + TE / 64, v1 = v0 + TE / 64;
		var b = m.pts.length;
		m.pts.push(new h3d.col.Point(p[0], p[1], p[2]));
		m.pts.push(new h3d.col.Point(p[3], p[4], p[5]));
		m.pts.push(new h3d.col.Point(p[6], p[7], p[8]));
		m.pts.push(new h3d.col.Point(p[9], p[10], p[11]));
		if( redFace >= 0 ) {
			// bloque parcial (BTReduced): como Builder.addCustomQuad, la cara muestra un RECORTE de la casilla del tamano de la cara
			// (en bloques), desde su esquina superior izquierda, en vez de la casilla entera estirada
			for( k in 0...4 ) {
				var px = p[k * 3], py = p[k * 3 + 1], pz = p[k * 3 + 2];
				var u : Float, v : Float;
				switch( redFace ) {
				case 0, 1: u = py - redB[1]; v = redB[2] - px;
				case 2: u = py - redB[1]; v = redB[4] - pz;
				case 3: u = redB[3] - py; v = redB[4] - pz;
				case 4: u = redB[2] - px; v = redB[4] - pz;
				default: u = px - redB[0]; v = redB[4] - pz;
				}
				m.uvs.push(new h3d.prim.UV((tx + u * TE) / 64, (ty + v * TE) / 64));
			}
			redFace = -1;
		} else {
		m.uvs.push(new h3d.prim.UV(u0, v1));
		m.uvs.push(new h3d.prim.UV(u1, v1));
		m.uvs.push(new h3d.prim.UV(u1, v0));
		m.uvs.push(new h3d.prim.UV(u0, v0));
		}
		for( i in 0...4 ) m.cols.push(new h3d.col.Point(shv[i], shv[i], shv[i]));
		// la diagonal se elige segun la luz para evitar costuras raras
		if( shv[0] + shv[2] >= shv[1] + shv[3] ) {
			m.idx.push(b); m.idx.push(b + 1); m.idx.push(b + 2);
			m.idx.push(b); m.idx.push(b + 2); m.idx.push(b + 3);
		} else {
			m.idx.push(b + 1); m.idx.push(b + 2); m.idx.push(b + 3);
			m.idx.push(b + 1); m.idx.push(b + 3); m.idx.push(b);
		}
		faces++;
	}

	/** modelos de Builder.hx (plantas en cruz, planos, columnas, cajas): se copia la geometria del original */
	function addModel( m : MeshBuf, b : Block, x : Int, y : Int, z : Int ) {
		var mk = b.model != null ? b.model : MCross;
		var md = Models.get(mk);
		var v = md.v;
		var n = Std.int(v.length / 24);
		// los modelos usan la luz de su propia celda (Builder: getLight(p) / LBASE)
		var lt = lightAt(x, y, z) / LBASE;
		for( q in 0...n ) {
			var sel = Std.int(v[q * 24 + 3]);
			var tile = !md.multi || sel == 0 ? b.tlr : (sel == 1 ? b.tu : b.td);
			if( tile < 0 || tile >= 0xFFF ) continue;
			var tx = tile & 63, ty = tile >> 6;
			var base = m.pts.length;
			for( k in 0...4 ) {
				var o = q * 24 + k * 6;
				var u = v[o + 3];
				var s = v[o + 5] * lt;
				m.pts.push(new h3d.col.Point(x + v[o], y + v[o + 1], z + v[o + 2]));
				m.uvs.push(new h3d.prim.UV(tx / 64 + (1 - TE) / 128 + (u - Std.int(u)), ty / 64 + (1 - TE) / 128 + v[o + 4]));
				m.cols.push(new h3d.col.Point(s, s, s));
			}
			m.idx.push(base); m.idx.push(base + 1); m.idx.push(base + 2);
			m.idx.push(base + 2); m.idx.push(base + 1); m.idx.push(base + 3);
			faces++;
		}
	}

	/*
	 * Orden de los translucidos en la pasada "alpha": Heaps ordena por Pass.layer y luego por la distancia del objeto, pero
	 * todos los chunks estan en la misma posicion (sus vertices son absolutos; solo las copias de la vuelta al planeta se
	 * mueven), asi que la distancia no los ordenaba y el agua y el hielo de chunks distintos salian en un orden que cambiaba
	 * con la camara (cortes rectos en el borde de un chunk, hielo sumergido visible a ratos). Como en Render.hx del original:
	 * primero el agua de todos los chunks, luego las estrellas (Sky), la profundidad y el color del hielo; el resto de la
	 * pasada (capa 0) despues.
	 */
	static inline var LAYER_WATER = -4;
	public static inline var LAYER_SKY = -3;
	static inline var LAYER_ALPHA_DEPTH = -2;
	static inline var LAYER_ALPHA = -1;

	function emitMesh( m : MeshBuf, kind : Int ) {
		if( m.pts.length == 0 ) return;
		var poly = new h3d.prim.Polygon(m.pts, m.idx);
		poly.addNormals(); // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
		poly.uvs = m.uvs;
		poly.colors = m.cols;
		// con mipmaps como el original (DefShader, TransShader, WaterShader1); el hielo y el cristal sin ellos (AlphaShader1)
		var mat = h3d.mat.Material.create(kind == 3 || Atlas.mipped == null ? atlas : Atlas.mipped);
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		mat.mainPass.addShader(new h3d.shader.VertexColor());
		mat.mainPass.addShader(sky.fog);
		if( kind == 1 ) {
			// bloques con alfa (hojas): se descartan los pixeles transparentes
			mat.textureShader.killAlpha = true;
			mat.textureShader.killAlphaThreshold = 0.5;
		} else if( kind == 3 ) {
			// hielo, cristal, liquidos con alfa: mezcla con el alfa de la propia textura (el original usa AlphaShader)
			// orden del original (Render.hx: BTWater antes que BTAlpha): se dibujan despues del agua, asi el hielo sumergido queda detras de ella
			mat.blendMode = Alpha;
			mat.mainPass.depthWrite = false;
			mat.mainPass.setPassName("alpha");
			// el original dibuja BTAlpha con la cara trasera oculta (culling por defecto): sin esto se veian a traves del hielo
			// sus caras de atras y de abajo, oscuras (sombra de abajo y poca luz bajo el hielo), como manchas sobre el aire
			mat.mainPass.culling = Back;
			// solo la cara translucida mas cercana, como el original (pasada de profundidad y luego color con depth Equal)
			mat.mainPass.depthTest = LessEqual;
			mat.mainPass.layer = LAYER_ALPHA;
		} else if( kind == 2 ) {
			// agua: translucida; escribe profundidad como la primera pasada del original (water0)
			mat.blendMode = Alpha;
			mat.color.a = 0.6;
			mat.mainPass.depthWrite = true;
			mat.mainPass.setPassName("alpha");
			mat.mainPass.layer = LAYER_WATER;
			if( wave != null ) mat.mainPass.addShader(wave);
			// despues de sky.fog, que escribe projectedPosition
			mat.mainPass.addShader(new WaterDepthBias());
		}
		if( kind == 3 ) {
			// pasada opaca de los pixeles solidos (marcos del cristal, bordes del hielo): escribe profundidad, asi las caras lejanas
			// no se pintan encima de las cercanas (la pasada translucida no puede ordenar triangulos)
			var cut = h3d.mat.Material.create(atlas);
			cut.shadows = false;
			cut.mainPass.enableLights = false;
			// cara trasera oculta como las otras pasadas de BTAlpha (y el original): si no, desde dentro de la nave se veia el marco
			// de la cara de fuera de una ventana, en el mismo plano que la cara de un neon pegado por fuera, y se pisaban segun el angulo
			cut.mainPass.culling = Back;
			cut.mainPass.addShader(new h3d.shader.VertexColor());
			cut.mainPass.addShader(sky.fog);
			cut.textureShader.killAlpha = true;
			cut.textureShader.killAlphaThreshold = 0.9;
			meshes.push(new h3d.scene.Mesh(poly, cut, root));
			if( curList != null ) curList.push(meshes.length - 1);
			meshCx.push(curCx);
			meshCy.push(curCy);
			// profundidad de la cara translucida mas cercana (AlphaShader0 del original), antes del color: mismos shaders de
			// vertices que el color, para que la profundidad coincida. El hielo tiene alfa >= 0.28 en toda su textura; el cristal
			// es casi todo < 0.25 y no la escribe, asi lo que hay detras de un cristal se sigue viendo
			var depth = h3d.mat.Material.create(atlas);
			depth.shadows = false;
			depth.mainPass.enableLights = false;
			depth.mainPass.culling = Back;
			depth.mainPass.addShader(new h3d.shader.VertexColor());
			depth.mainPass.addShader(sky.fog);
			depth.textureShader.killAlpha = true;
			depth.textureShader.killAlphaThreshold = 0.25;
			depth.mainPass.setPassName("alpha");
			depth.mainPass.setColorMask(false, false, false, false);
			depth.mainPass.layer = LAYER_ALPHA_DEPTH;
			meshes.push(new h3d.scene.Mesh(poly, depth, root));
			if( curList != null ) curList.push(meshes.length - 1);
			meshCx.push(curCx);
			meshCy.push(curCy);
		}
		meshes.push(new h3d.scene.Mesh(poly, mat, root));
		if( curList != null ) curList.push(meshes.length - 1);
		meshCx.push(curCx);
		meshCy.push(curCy);
	}

	/**
	 * El planeta da la vuelta como en el original (AbstractGame.real/realDist): cada chunk se dibuja en la copia
	 * mas cercana a la camara, asi no hay borde del mundo y el horizonte sigue siendo terreno.
	 */
	public function updateWrap( x : Float, y : Float ) {
		viewX = x;
		viewY = y;
		if( !wraps || (x == wrapX && y == wrapY) ) return;
		wrapX = x;
		wrapY = y;
		var s = size;
		var r = VIEW_RADIUS + CSIZE;
		var r2 = r * r;
		// con el mundo mas pequeno que el alcance de la niebla hacen falta copias vecinas
		var extra = s * 0.5 < VIEW_RADIUS;
		if( extra && meshExtra.length < meshes.length )
			while( meshExtra.length < meshes.length ) meshExtra.push(null);
		for( i in 0...meshes.length ) {
			var m = meshes[i];
			if( m == null ) continue;
			var bx = Math.round((x - meshCx[i]) / s), by = Math.round((y - meshCy[i]) / s);
			m.x = s * bx;
			m.y = s * by;
			if( !extra ) continue;
			var ex = meshExtra[i];
			var k = 0;
			for( oy in -1...2 )
				for( ox in -1...2 ) {
					if( ox == 0 && oy == 0 ) continue;
					var dx = meshCx[i] + s * (bx + ox) - x, dy = meshCy[i] + s * (by + oy) - y;
					var show = dx * dx + dy * dy < r2;
					var c = ex != null ? ex[k] : null;
					if( show && c == null ) {
						if( ex == null ) ex = meshExtra[i] = [for( _ in 0...8 ) null];
						c = ex[k] = new h3d.scene.Mesh(m.primitive, m.material, root);
					}
					if( c != null ) {
						c.visible = show;
						c.x = s * (bx + ox);
						c.y = s * (by + oy);
					}
					k++;
				}
		}
	}

	function buildChunk( cx : Int, cy : Int ) {
		var solidBuf = new MeshBuf();
		var alphaBuf = new MeshBuf();
		var waterBuf = new MeshBuf();
		var blendBuf = new MeshBuf();
		// si el trozo ya existia (edicion), se quitan sus mallas antiguas
		var cid = cx + cy * (size >> 4);
		var old = chunkMeshes[cid];
		if( old != null )
			for( i in old ) {
				var om = meshes[i];
				if( om == null ) continue;
				var ex = i < meshExtra.length ? meshExtra[i] : null;
				if( ex != null ) {
					for( c in ex ) if( c != null ) c.remove();
					meshExtra[i] = null;
				}
				om.remove();
				om.primitive.dispose();
				meshes[i] = null;
			}
		curList = [];
		chunkMeshes[cid] = curList;
		wrapX = -1e9;
		curCx = cx * CSIZE + CSIZE * 0.5;
		curCy = cy * CSIZE + CSIZE * 0.5;

		for( y in cy * CSIZE...(cy + 1) * CSIZE )
			for( x in cx * CSIZE...(cx + 1) * CSIZE )
				// la capa 0 (roca madre, BBedrock: power -1, no se rompe) tambien se dibuja, como en Builder.hx del original: si
				// no, al excavar hasta el fondo se veia el vacio a traves. Su cara de abajo nunca sale: voxel() da roca madre bajo z = 0
				for( z in 0...HEIGHT ) {
					var id = voxel(x, y, z);
					if( id == 0 ) continue;
					var b = gen.blocks[id];
					if( b == null ) continue;
					var su = Math.sqrt(b.shadeUp), sd = Math.sqrt(b.shadeDown);
					var sx = Math.sqrt(b.shadeX), sy = Math.sqrt(b.shadeY);
					var fx = x, fy = y, fz = z;
					var neg = b.hasFlag(BFNoShade);
					switch( b.type ) {
					case BTWater:
						// Builder.hx del original: cada cara contra un vecino que no es lleno ni agua (isTransparentNot(p, BTWater))
						addLiquid(waterBuf, b, 1, x, y, z, waterOpen, su, sd, sx, sy, neg);
					case BTAlpha if( liquidFam(id) == 2 ):
						// cascada: cada paso de Fall..Fall4 un poco mas bajo, superficie inclinada
						addLiquid(blendBuf, b, 2, x, y, z, openAlpha, su, sd, sx, sy, neg);
					case BTFull, BTAlpha, BTTransp:
						var m = b.type == BTFull ? solidBuf : (b.type == BTAlpha ? blendBuf : alphaBuf);
						var al = b.type == BTAlpha;
						if( al ? openAlpha(x, y, z + 1) : open(x, y, z + 1) ) addQuadL(m, [fx, fy, fz + 1, fx + 1, fy, fz + 1, fx + 1, fy + 1, fz + 1, fx, fy + 1, fz + 1], b.tu, su, neg, 0, 0, 1, x, y, z);
						if( al ? openAlpha(x, y, z - 1) : open(x, y, z - 1) ) addQuadL(m, [fx, fy + 1, fz, fx + 1, fy + 1, fz, fx + 1, fy, fz, fx, fy, fz], b.td, sd, neg, 0, 0, -1, x, y, z);
						if( al ? openAlpha(x - 1, y, z) : open(x - 1, y, z) ) addQuadL(m, [fx, fy + 1, fz, fx, fy, fz, fx, fy, fz + 1, fx, fy + 1, fz + 1], b.tlr, sx, neg, -1, 0, 0, x, y, z);
						if( al ? openAlpha(x + 1, y, z) : open(x + 1, y, z) ) addQuadL(m, [fx + 1, fy, fz, fx + 1, fy + 1, fz, fx + 1, fy + 1, fz + 1, fx + 1, fy, fz + 1], b.tlr, sx, neg, 1, 0, 0, x, y, z);
						if( al ? openAlpha(x, y - 1, z) : open(x, y - 1, z) ) addQuadL(m, [fx, fy, fz, fx + 1, fy, fz, fx + 1, fy, fz + 1, fx, fy, fz + 1], b.tlr, sy, neg, 0, -1, 0, x, y, z);
						if( al ? openAlpha(x, y + 1, z) : open(x, y + 1, z) ) addQuadL(m, [fx + 1, fy + 1, fz, fx, fy + 1, fz, fx, fy + 1, fz + 1, fx + 1, fy + 1, fz + 1], b.tlr, sy, neg, 0, 1, 0, x, y, z);
					case BTModel, BTModel2Side, BTSprite:
						addModel(alphaBuf, b, fx, fy, fz);
					case BTReduced:
						if( b.size != null ) {
							// igual que el original: las caras de un bloque parcial se ven si no tapan todo el lado o si el vecino es transparente.
							// Luz por esquina como la cara entera (addCustomQuad); si la celda de al lado no tiene luz, la mas alta alrededor
							var s = b.size;
							var x1 = fx + s.x1, y1 = fy + s.y1, z1 = fz + s.z1, x2 = fx + s.x2, y2 = fy + s.y2, z2 = fz + s.z2;
							redB = [x1, y1, x2, y2, z2];
							if( s.z2 < 1 || open(x, y, z + 1) ) { redFace = 0; addQuadL(alphaBuf, [x1, y1, z2, x2, y1, z2, x2, y2, z2, x1, y2, z2], b.tu, su, neg, 0, 0, 1, x, y, z, false, [fx, fy, fz + 1, fx + 1, fy, fz + 1, fx + 1, fy + 1, fz + 1, fx, fy + 1, fz + 1]); }
							if( s.z1 > 0 || open(x, y, z - 1) ) { redFace = 1; addQuadL(alphaBuf, [x1, y2, z1, x2, y2, z1, x2, y1, z1, x1, y1, z1], b.td, sd, neg, 0, 0, -1, x, y, z, false, [fx, fy + 1, fz, fx + 1, fy + 1, fz, fx + 1, fy, fz, fx, fy, fz]); }
							if( s.x1 > 0 || open(x - 1, y, z) ) { redFace = 2; addQuadL(alphaBuf, [x1, y2, z1, x1, y1, z1, x1, y1, z2, x1, y2, z2], b.tlr, sx, neg, -1, 0, 0, x, y, z, false, [fx, fy + 1, fz, fx, fy, fz, fx, fy, fz + 1, fx, fy + 1, fz + 1]); }
							if( s.x2 < 1 || open(x + 1, y, z) ) { redFace = 3; addQuadL(alphaBuf, [x2, y1, z1, x2, y2, z1, x2, y2, z2, x2, y1, z2], b.tlr, sx, neg, 1, 0, 0, x, y, z, false, [fx + 1, fy, fz, fx + 1, fy + 1, fz, fx + 1, fy + 1, fz + 1, fx + 1, fy, fz + 1]); }
							if( s.y1 > 0 || open(x, y - 1, z) ) { redFace = 4; addQuadL(alphaBuf, [x1, y1, z1, x2, y1, z1, x2, y1, z2, x1, y1, z2], b.tlr, sy, neg, 0, -1, 0, x, y, z, false, [fx, fy, fz, fx + 1, fy, fz, fx + 1, fy, fz + 1, fx, fy, fz + 1]); }
							if( s.y2 < 1 || open(x, y + 1, z) ) { redFace = 5; addQuadL(alphaBuf, [x2, y2, z1, x1, y2, z1, x1, y2, z2, x2, y2, z2], b.tlr, sy, neg, 0, 1, 0, x, y, z, false, [fx + 1, fy + 1, fz, fx, fy + 1, fz, fx, fy + 1, fz + 1, fx + 1, fy + 1, fz + 1]); }
						}
					case BTExtended:
						// caras con texturas distintas empaquetadas de a 12 bits (BFTextures)
						if( open(x, y, z + 1) ) addQuadL(alphaBuf, [fx, fy, fz + 1, fx + 1, fy, fz + 1, fx + 1, fy + 1, fz + 1, fx, fy + 1, fz + 1], b.tu & 0xFFF, su, neg, 0, 0, 1, x, y, z);
						if( open(x, y, z - 1) ) addQuadL(alphaBuf, [fx, fy + 1, fz, fx + 1, fy + 1, fz, fx + 1, fy, fz, fx, fy, fz], b.td & 0xFFF, sd, neg, 0, 0, -1, x, y, z);
						if( open(x - 1, y, z) ) addQuadL(alphaBuf, [fx, fy + 1, fz, fx, fy, fz, fx, fy, fz + 1, fx, fy + 1, fz + 1], b.tlr & 0xFFF, sx, neg, -1, 0, 0, x, y, z);
						if( open(x + 1, y, z) ) addQuadL(alphaBuf, [fx + 1, fy, fz, fx + 1, fy + 1, fz, fx + 1, fy + 1, fz + 1, fx + 1, fy, fz + 1], b.tlr >> 12, sx, neg, 1, 0, 0, x, y, z);
						if( open(x, y - 1, z) ) addQuadL(alphaBuf, [fx, fy, fz, fx + 1, fy, fz, fx + 1, fy, fz + 1, fx, fy, fz + 1], b.tu >> 12, sy, neg, 0, -1, 0, x, y, z);
						if( open(x, y + 1, z) ) addQuadL(alphaBuf, [fx + 1, fy + 1, fz, fx, fy + 1, fz, fx, fy + 1, fz + 1, fx + 1, fy + 1, fz + 1], b.td >> 12, sy, neg, 0, 1, 0, x, y, z);
					default:
					}
				}

		emitMesh(solidBuf, 0);
		emitMesh(alphaBuf, 1);
		emitMesh(waterBuf, 2);
		emitMesh(blendBuf, 3);
	}
}
