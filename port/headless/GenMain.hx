import Common;

/**
	Ejecuta el generador de planetas sin pantalla y muestra un resumen verificable.
	Funciona en Flash (log con flash.Lib.trace) y en HashLink (stdout). El trabajo se reparte en
	tandas para no superar el limite de 15 s por script de Flash. La suma Adler-32 usa solo enteros
	pequenos, asi que da el mismo valor en ambos targets.
	En HashLink (haxe port/headless.hxml):
	  hl port/out/gen.hl                                los casos de CASES, con el resumen de cada uno
	  hl port/out/gen.hl SEMILLA BIOMA TAMANO [VERSION] un solo caso (por defecto con Generator.VERSION) y su linea ref=
	  hl port/out/gen.hl --check port/headless/gen_ref.txt
	                                                    genera cada caso del fichero con su version y lo compara con su linea
	                                                    (sale con codigo 1 si alguno cambia)
	  hl port/out/gen.hl --profile [CASOS] [--top N]    tiempo de cada paso del generador (addStep: fichero y linea), sumado en
	                                                    todos los casos: los N pasos mas lentos (40) y el tiempo por bioma
	  hl port/out/gen.hl --steps [CASOS] > a.txt        sumas de cada paso de cada caso (alturas, alturas reales y mundo con el
	                                                    nombre de cada bloque, Generator.stepSums), para comparar dos builds
	  hl port/out/gen.hl --compare a.txt b.txt          compara dos salidas de --steps (de dos builds): el primer paso que cambia
	                                                    en cada caso, sin mirar fichero y linea (sale con codigo 1 si cambia algo)
	  hl port/out/gen.hl --census [CASOS]               anomalias puestas (DetailsGenerator.placed) por nombre y bioma: cuantas y
	                                                    en cuantos planetas
	  hl port/out/gen.hl --locality [CASOS]             generador version 1: cada caso dos veces (igual) y con una estructura de
	                                                    prueba mas: lo que cambia esta en la caja de lo que cambia (1-10, 1 y 2)
	  hl port/out/gen.hl --allstructures [--seeds A-B] [--sizes S]
	                                                    cada estructura del registro forzada en cada bioma: acaba, sale y su caja
	                                                    es razonable (1-3, tamanos 1 y 2: en Marte las grutas y en el
	                                                    bosque acido el artefacto y la cascada solo caben en los grandes)
	  hl port/out/gen.hl --fuzz N [--limit S]           todos los biomas (hangar y cometas incluidos) y tamanos con N semillas al
	                                                    azar: cada planeta acaba en S segundos (60)
	  hl port/out/gen.hl --registry                     tipos de las estructuras (Structures) frente a las anomalias de kubindex.json
	CASOS: --seeds A-B (o una sola), --biomes B1,B2 (todos menos BITest y BIShed; las cometas miden COMET_SIZE con cualquier
	tamano), --sizes 1,2,3 (en trozos), --version N (Generator.VERSION), --events E1,E2 (eventos del calendario activos,
	CalendarEvents: ninguno por defecto). Por defecto: --profile 1-5 de tamano 3, --steps 1-100
	de tamano 1, --census 1-50 de tamano 2.
**/
typedef GenCase = { seed : Int, biome : String, size : Int, ?version : Null<Int> };

class GenMain {
	static var CASES : Array<GenCase> = [
		{ seed : 1234, biome : "BIAutumn", size : 2 },
		{ seed : 99, biome : "BIMars", size : 2 },
		{ seed : 7, biome : "BIMoon", size : 2 },
		{ seed : 4242, biome : "BIWinterPeaks", size : 2 },
		{ seed : 1234, biome : "BIDeadCity", size : 1 },
		{ seed : 77, biome : "BIDeadCity", size : 2 },
		{ seed : 31, biome : "BIAcidForest", size : 2 },
		{ seed : 5, biome : "BIShed", size : 3 },
	];

	/** lado de una cometa (Comets.SIZE en el juego: aqui no se compila Comets) */
	static inline var COMET_SIZE = 96;

	/** --events de CASOS: eventos del calendario con los que se genera (Generator.events; ninguno por defecto) */
	static var events : Array<String> = [];

	/** --check: sin el resumen de cada caso, solo si cambia */
	static var quiet = false;

	static inline function out( s : String ) {
		#if flash
		flash.Lib.trace(s);
		#else
		Sys.println(s);
		#end
	}

	/** En Flash cede el control entre tandas; en HashLink ejecuta directamente. */
	static function later( f : Void -> Void ) {
		#if flash
		haxe.Timer.delay(f, 1);
		#else
		f();
		#end
	}

	/**
	 * Linea de port/headless/gen_ref.txt: semilla, bioma, tamano en trozos, version del generador, suma Adler-32 del mundo y las
	 * anomalias que quedan en el (DetailsGenerator.placed, "-" si ninguna)
	 */
	static function refLine( seed : Int, biome : String, sizeChunks : Int, version : Int, adler : String, anomalies : Array<String> ) {
		return seed + " " + biome + " " + sizeChunks + " " + version + " " + adler + " " + (anomalies.length == 0 ? "-" : anomalies.join(","));
	}

	static function isComet( biome : String ) return StringTools.startsWith(biome, "BIComet");

	/** el generador de un caso, como World: bloques reservados del bioma y startGenerate */
	static function makeGen( seed : Int, biomeName : String, sizeChunks : Int, version : Int ) : gen.DetailsGenerator {
		var biome : BiomeKind = Type.createEnum(BiomeKind, biomeName);
		#if sys
		var gen = isComet(biomeName) ? new CometGenerator(COMET_SIZE, seed) : new gen.DetailsGenerator(sizeChunks << Const.BITS, seed);
		#else
		var gen = new gen.DetailsGenerator(sizeChunks << Const.BITS, seed);
		#end
		gen.version = version;
		gen.events = events;
		gen.reserveBlocks(biome);
		gen.startGenerate(biome);
		return gen;
	}

	/** nombre del bloque de un numero local (con * si lleva el bit TMP / CAVE) */
	static function blockName( gen : gen.Generator, v : Int ) : String {
		var id = v & 127;
		return (id < gen.blocks.length ? Type.enumConstructor(gen.blocks[id].k) : "#" + id) + (v >= 128 ? "*" : "");
	}

	static function run( seed : Int, biomeName : String, sizeChunks : Int, version : Int, done : String -> Void ) {
		var gen = makeGen(seed, biomeName, sizeChunks, version);
		#if genDebug
		gen.onStep = function(i, p, ms) out("STEP " + i + " " + p.fileName + ":" + p.lineNumber + " " + gen.stepSums() + " ms=" + Std.int(ms));
		#end
		var t0 = haxe.Timer.stamp();
		var stepFn : Void -> Void = null;
		stepFn = function() {
			#if genDebug
			var cs = gen.getCurrentStep();
			out("  step " + Std.int(gen.progress * 1000) / 10 + "% " + (cs == null ? "" : cs.fileName + ":" + cs.lineNumber));
			#end
			if( gen.process(50) ) {
				later(stepFn);
				return;
			}
			var dt = haxe.Timer.stamp() - t0;
			#if flash
			var bytes = haxe.io.Bytes.ofData(gen.getBytes());
			#else
			var bytes = gen.getBytes().b;
			#end
			var counts = [for( i in 0...256 ) 0];
			var a = 1, b = 0, pos = 0, len = bytes.length;
			var statFn : Void -> Void = null;
			statFn = function() {
				var end = pos + 1000000;
				if( end > len ) end = len;
				while( pos < end ) {
					var v = bytes.get(pos++);
					counts[v]++;
					a = (a + v) % 65521;
					b = (b + a) % 65521;
				}
				if( pos < len ) {
					later(statFn);
					return;
				}
				var adler = StringTools.hex(a, 4) + StringTools.hex(b, 4);
				var ref = refLine(seed, biomeName, sizeChunks, version, adler, [for( p in gen.placed ) p.n]);
				if( !quiet ) {
					out('seed=$seed biome=$biomeName size=${gen.size} bytes=$len adler=$adler');
					out('water=' + haxe.Json.stringify(gen.getWaterInfos()));
					out('blocks=' + [for( k in 0...256 ) if( counts[k] > 0 ) blockName(gen, k) + ":" + counts[k]].join(" "));
					out('time_ms=' + Std.int(dt * 1000));
					out('ref=' + ref);
				}
				done(ref);
			};
			statFn();
		};
		stepFn();
	}

	static function runAll( cases : Array<GenCase> ) {
		var i = 0;
		var nextFn : Void -> Void = null;
		nextFn = function() {
			if( i >= cases.length ) {
				out("GENTEST DONE");
				return;
			}
			var c = cases[i++];
			var version = c.version == null ? gen.Generator.VERSION : c.version;
			try run(c.seed, c.biome, c.size, version, function(_) later(nextFn)) catch( e : Dynamic ) {
				out("ERROR " + Std.string(e));
				later(nextFn);
			}
		};
		out("GENTEST START");
		nextFn();
	}

	#if sys
	/**
	 * Genera cada caso del fichero (lineas de refLine; # = comentario) con su version y lo compara con su linea. En HashLink run
	 * acaba antes de volver (later no espera).
	 */
	static function check( file : String ) {
		quiet = true;
		var fails = 0, total = 0;
		for( l in sys.io.File.getContent(file).split("\n") ) {
			var want = StringTools.trim(l);
			if( want == "" || want.charAt(0) == "#" ) continue;
			var f = want.split(" ");
			var got = null;
			total++;
			try run(Std.parseInt(f[0]), f[1], Std.parseInt(f[2]), Std.parseInt(f[3]), function(ref) got = ref) catch( e : Dynamic ) got = "ERROR " + Std.string(e);
			if( got == want ) out("OK     " + got);
			else {
				fails++;
				out("CAMBIA " + got);
				out("  ref  " + want);
			}
		}
		out(fails == 0 ? 'GENREF OK ($total casos)' : 'GENREF CAMBIA ($fails de $total casos)');
		Sys.exit(fails == 0 ? 0 : 1);
	}

	static inline function versionOf( c : GenCase ) return c.version == null ? gen.Generator.VERSION : c.version;

	static function caseName( c : GenCase ) return c.seed + " " + c.biome + " " + c.size + " " + versionOf(c);

	/** genera un caso de una vez; onStep (si hay) despues de cada paso entero (Generator.onStep) */
	static function generate( c : GenCase, ?onStep : gen.DetailsGenerator -> Int -> haxe.PosInfos -> Float -> Void ) {
		var g = makeGen(c.seed, c.biome, c.size, versionOf(c));
		if( onStep != null ) g.onStep = function(i, p, ms) onStep(g, i, p, ms);
		while( g.process(1000000) ) {}
		return g;
	}

	/** los casos de --profile, --steps y --census (opciones desde args[1]) */
	static function parseCases( args : Array<String>, seeds : String, sizes : String, ?extra : String -> String -> Bool ) : Array<GenCase> {
		var biomes = [for( b in Type.allEnums(BiomeKind) ) if( b != BITest && b != BIShed ) Type.enumConstructor(b)];
		var version : Null<Int> = null;
		var i = 1;
		while( i < args.length ) {
			var a = args[i++], v = args[i++];
			if( v == null ) throw "falta el valor de " + a;
			switch( a ) {
			case "--seeds": seeds = v;
			case "--sizes": sizes = v;
			case "--biomes": biomes = v.split(",");
			case "--version": version = Std.parseInt(v);
			case "--events": events = v.split(",");
			default: if( extra == null || !extra(a, v) ) throw "opcion desconocida: " + a;
			}
		}
		for( b in biomes ) Type.createEnum(BiomeKind, b);
		var r = seeds.split("-").map(Std.parseInt);
		var sz = sizes.split(",").map(Std.parseInt);
		var cases = [];
		for( b in biomes )
			for( s in (isComet(b) ? [sz[0]] : sz) )
				for( seed in r[0]...(r.length > 1 ? r[1] : r[0]) + 1 )
					cases.push({ seed : seed, biome : b, size : s, version : version });
		return cases;
	}

	static function ms( v : Float ) return Std.string(Math.round(v * 10) / 10);

	static var sources = new Map<String, Array<String>>();

	/** el texto de la linea del addStep (el fichero se lee desde la raiz del repositorio), recortado; "" si no esta */
	static function sourceLine( p : haxe.PosInfos ) : String {
		var lines = sources.get(p.fileName);
		if( lines == null ) {
			lines = try sys.io.File.getContent(p.fileName).split("\n") catch( e : Dynamic ) [];
			sources.set(p.fileName, lines);
		}
		var l = lines[p.lineNumber - 1];
		if( l == null ) return "";
		l = StringTools.trim(l);
		return l.length > 50 ? l.substr(0, 47) + "..." : l;
	}

	/** fichero (sin carpeta) y linea del addStep de un paso */
	static function stepPos( p : haxe.PosInfos ) return haxe.io.Path.withoutDirectory(p.fileName) + ":" + p.lineNumber;

	static function pad( s : String, n : Int ) return StringTools.rpad(s, " ", n);

	static function lpad( s : String, n : Int ) return StringTools.lpad(s, " ", n);

	/** --profile: tiempo de cada paso (sin sumas: solo el reloj alrededor del paso y sus trabajos) */
	static function profile( args : Array<String> ) {
		var top = 40;
		var cases = parseCases(args, "1-5", "3", function(a, v) {
			if( a != "--top" ) return false;
			top = Std.parseInt(v);
			return true;
		});
		var steps = new Map<String, { key : String, ms : Float, n : Int, max : Float, src : String }>();
		var biomes = new Map<String, { ms : Float, n : Int, max : Float, steps : Float }>(), biomeOrder = [];
		for( c in cases ) {
			var t0 = haxe.Timer.stamp(), inSteps = 0.;
			try generate(c, function(g, i, p, t) {
				inSteps += t;
				var key = c.biome + " " + stepPos(p);
				var s = steps.get(key);
				if( s == null ) steps.set(key, s = { key : key, ms : 0., n : 0, max : 0., src : sourceLine(p) });
				s.ms += t;
				s.n++;
				if( t > s.max ) s.max = t;
			}) catch( e : Dynamic ) {
				out("ERROR " + caseName(c) + ": " + Std.string(e));
				continue;
			}
			var t = (haxe.Timer.stamp() - t0) * 1000;
			out("caso " + caseName(c) + ": " + Std.int(t) + " ms");
			var b = biomes.get(c.biome);
			if( b == null ) {
				biomes.set(c.biome, b = { ms : 0., n : 0, max : 0., steps : 0. });
				biomeOrder.push(c.biome);
			}
			b.ms += t;
			b.steps += inSteps;
			b.n++;
			if( t > b.max ) b.max = t;
		}
		out("");
		out("por bioma: casos, media y maximo por caso (ms)");
		var total = 0.;
		for( k in biomeOrder ) {
			var b = biomes.get(k);
			total += b.steps;
			out("  " + pad(k, 16) + lpad("" + b.n, 4) + lpad(ms(b.ms / b.n), 10) + lpad(ms(b.max), 10));
		}
		var all = [for( s in steps ) s];
		all.sort(function(a, b) return a.ms < b.ms ? 1 : a.ms > b.ms ? -1 : 0);
		out("");
		out("pasos mas lentos: total de todos los casos (ms), % del total, veces, media y maximo por vez (ms)");
		for( s in all.slice(0, top) )
			out("  " + pad(s.key, 40) + lpad(ms(s.ms), 10) + lpad(ms(s.ms * 100 / total) + "%", 8) + lpad("" + s.n, 6) + lpad(ms(s.ms / s.n), 9) + lpad(ms(s.max), 9) + "  " + s.src);
		out("PROFILE " + cases.length + " casos, " + ms(total) + " ms en los pasos");
	}

	/** --steps: una linea CASE por caso, una STEP por paso hecho (los repetidos con stepRetry tambien) y END con las anomalias */
	static function stepSums( args : Array<String> ) {
		var cases = parseCases(args, "1-100", "1");
		for( c in cases ) {
			out("CASE " + caseName(c));
			try {
				var g = generate(c, function(g, i, p, _) out("STEP " + i + " " + stepPos(p) + " " + g.stepSums()));
				var names = [for( p in g.placed ) p.n];
				out("END " + (names.length == 0 ? "-" : names.join(",")));
			} catch( e : Dynamic ) out("ERROR " + Std.string(e));
		}
	}

	/** un fichero de texto en UTF-8 o, como lo deja la redireccion > de PowerShell 5, en UTF-16 con BOM (aqui todo es ASCII) */
	static function readText( file : String ) : String {
		var b = sys.io.File.getBytes(file);
		if( b.length >= 2 && b.get(0) == 0xFF && b.get(1) == 0xFE ) {
			var s = new StringBuf();
			var i = 2;
			while( i + 1 < b.length ) {
				s.addChar(b.get(i) | (b.get(i + 1) << 8));
				i += 2;
			}
			return s.toString();
		}
		var start = b.length >= 3 && b.get(0) == 0xEF && b.get(1) == 0xBB && b.get(2) == 0xBF ? 3 : 0;
		return b.getString(start, b.length - start);
	}

	/** una salida de --steps: las lineas de cada caso, sin el fichero y la linea de los STEP (cambian al editar el codigo) */
	static function readSteps( file : String ) {
		var cases = new Map<String, Array<String>>(), order = [], pos = new Map<String, Array<String>>();
		var cur : Array<String> = null, curPos : Array<String> = null;
		for( l in readText(file).split("\n") ) {
			l = StringTools.trim(l);
			if( StringTools.startsWith(l, "CASE ") ) {
				var k = l.substr(5);
				order.push(k);
				cases.set(k, cur = []);
				pos.set(k, curPos = []);
			} else if( cur != null && l != "" ) {
				var f = l.split(" ");
				if( f[0] == "STEP" ) {
					curPos.push(f[2]);
					f.splice(2, 1);
				} else curPos.push("");
				cur.push(f.join(" "));
			}
		}
		return { cases : cases, order : order, pos : pos };
	}

	/** --compare a b: el primer paso distinto de cada caso; los casos que solo estan en uno */
	static function compare( fa : String, fb : String ) {
		var a = readSteps(fa), b = readSteps(fb);
		var same = 0, diff = 0, steps = 0;
		for( k in a.order ) {
			var la = a.cases.get(k), lb = b.cases.get(k);
			if( lb == null ) {
				out("SOLO EN A " + k);
				diff++;
				continue;
			}
			var n = la.length < lb.length ? la.length : lb.length, first = -1;
			for( i in 0...n )
				if( la[i] != lb[i] ) {
					first = i;
					break;
				}
			if( first < 0 && la.length == lb.length ) {
				same++;
				steps += n;
				continue;
			}
			diff++;
			if( first < 0 ) out("CAMBIA " + k + ": " + la.length + " lineas en A y " + lb.length + " en B");
			else {
				var pa = a.pos.get(k)[first], pb = b.pos.get(k)[first];
				out("CAMBIA " + k + ": linea " + first + (pa != "" ? " (A " + pa + ", B " + pb + ")" : ""));
				out("  A " + la[first]);
				out("  B " + lb[first]);
			}
		}
		for( k in b.order )
			if( !a.cases.exists(k) ) {
				out("SOLO EN B " + k);
				diff++;
			}
		out(diff == 0 ? 'STEPS IGUALES ($same casos, $steps lineas)' : 'STEPS CAMBIAN ($diff de ${same + diff} casos)');
		Sys.exit(diff == 0 ? 0 : 1);
	}

	/** --census: por bioma, cada anomalia puesta: cuantas en total y en cuantos planetas; y los planetas sin ninguna */
	static function census( args : Array<String> ) {
		var cases = parseCases(args, "1-50", "2");
		var biomes = new Map<String, { planets : Int, empty : Int, names : Map<String, { n : Int, planets : Int }> }>(), order = [];
		for( c in cases ) {
			var key = c.biome + " " + c.size;
			var b = biomes.get(key);
			if( b == null ) {
				biomes.set(key, b = { planets : 0, empty : 0, names : new Map() });
				order.push(key);
			}
			var g = try generate(c) catch( e : Dynamic ) {
				out("ERROR " + caseName(c) + ": " + Std.string(e));
				continue;
			}
			b.planets++;
			if( g.placed.length == 0 ) b.empty++;
			var seen = new Map<String, Bool>();
			for( p in g.placed ) {
				var e = b.names.get(p.n);
				if( e == null ) b.names.set(p.n, e = { n : 0, planets : 0 });
				e.n++;
				if( !seen.exists(p.n) ) {
					seen.set(p.n, true);
					e.planets++;
				}
			}
		}
		for( k in order ) {
			var b = biomes.get(k);
			var f = k.split(" ");
			out(f[0] + " (tamano " + f[1] + "): " + b.planets + " planetas, " + b.empty + " sin anomalias");
			var names = [for( n in b.names.keys() ) n];
			names.sort(Reflect.compare);
			for( n in names ) {
				var e = b.names.get(n);
				out("  " + pad(n, 16) + lpad("" + e.n, 6) + " en " + lpad("" + e.planets, 4) + " planetas");
			}
		}
		out("CENSUS " + cases.length + " casos");
	}

	// ---------------------------------------------------------------- pruebas del generador version 1 (anadido del port)

	/** el bloque (indice de BlockKind) de cada numero local de un generador: dos mundos se comparan por nombre de bloque */
	static function kindTable( g : gen.Generator ) : Array<Int> {
		return [for( v in 0...256 ) (v & 127) < g.blocks.length ? Type.enumIndex(g.blocks[v & 127].k) : -1 - v];
	}

	/** los bytes del mundo de un generador */
	static function worldBytes( g : gen.Generator ) : haxe.io.Bytes return g.getBytes().b;

	/** los dos mundos tienen los mismos bloques en las mismas celdas */
	static function sameWorld( a : gen.Generator, b : gen.Generator ) : Bool {
		var ka = kindTable(a), kb = kindTable(b), wa = worldBytes(a), wb = worldBytes(b);
		if( wa.length != wb.length ) return false;
		for( i in 0...wa.length ) if( ka[wa.get(i)] != kb[wb.get(i)] ) return false;
		return true;
	}

	static function poseKey( p : gen.DetailsGenerator.Pose ) : String return p.id + "@" + p.x + "," + p.y + "," + p.z + "/" + p.box.join(",");

	/** distancia en el mapa que da la vuelta (como Generator.realDist) */
	static inline function wrap( d : Int, size : Int ) : Int {
		var half = size >> 1;
		return d <= -half ? d + size : (d > half ? d - size : d);
	}

	/**
	 * --locality [CASOS]: la garantia de localidad del generador version 1. Cada caso se genera dos veces (tiene que salir igual)
	 * y otra con una estructura de prueba mas en el registro (un cubo de cristal de 5x5x5 sobre el suelo, etapa Surface): toda
	 * celda que cambia (por nombre de bloque) tiene que estar en la caja de una pose que ha cambiado, con un margen: en x e y,
	 * 1 mas la cadena de propagacion mas larga (una cascada o la lava que la estructura desvia baja y se extiende una celda por
	 * eslabon), 1 por arriba y hasta abajo del todo (lo que se propaga cae)
	 */
	static function locality( args : Array<String> ) {
		var cases = parseCases(args, "1-10", "1,2");
		var test : gen.Structures.StructureDef = { id : "localitytest", group : null, stage : gen.Structures.StructureStage.Surface, p : 1,
			biomes : null, since : null, until : null, f : function(g, x, y, z) @:privateAccess {
				if( z <= g.waterLevel || g.get(x, y, z) != 0 ) return false;
				var glass = g.alloc(BGlass);
				for( dz in 0...5 ) for( dy in -2...3 ) for( dx in -2...3 ) g.set(x + dx, y + dy, z + dz, glass);
				return true;
			} };
		// margen en x e y: lo que se propaga (cascadas, lava) baja y se extiende una celda por eslabon de su cadena (Generator.coverAll)
		var chain = 0;
		for( b in Block.all ) {
			var n = 0, k = b;
			while( k != null && k.propagate != null && n < 20 ) {
				n++;
				k = k.propagate == k ? null : k.propagate;
			}
			if( n > chain ) chain = n;
		}
		var m = 1 + chain;
		out("margen " + m + " (cadena de propagacion mas larga: " + chain + ")");
		var bad = 0, nondet = 0, posed = 0;
		for( c in cases ) {
			var a = generate(c);
			if( !sameWorld(a, generate(c)) ) {
				nondet++;
				out("NO DETERMINISTA " + caseName(c));
			}
			gen.Structures.ALL.push(test);
			var b = try generate(c) catch( e : Dynamic ) {
				gen.Structures.ALL.pop();
				throw e;
			}
			gen.Structures.ALL.pop();
			var ka = [for( p in a.poses ) poseKey(p) => true], kb = [for( p in b.poses ) poseKey(p) => true];
			var changed = [for( p in a.poses ) if( !kb.exists(poseKey(p)) ) p].concat([for( p in b.poses ) if( !ka.exists(poseKey(p)) ) p]);
			var tests = [for( p in b.poses ) if( p.id == test.id ) p].length;
			posed += tests;
			var ta = kindTable(a), tb = kindTable(b), wa = worldBytes(a), wb = worldBytes(b);
			var size = a.size, diff = 0, outside = 0, first = null;
			for( i in 0...wa.length ) {
				if( ta[wa.get(i)] == tb[wb.get(i)] ) continue;
				diff++;
				var col = i >> Const.ZBITS, z = i & (Const.ZSIZE - 1);
				var x = col % size, y = Std.int(col / size), inside = false;
				for( p in changed ) {
					var dx = wrap(x - p.x, size), dy = wrap(y - p.y, size), bx = p.box;
					if( dx >= bx[0] - m && dx <= bx[3] + m && dy >= bx[1] - m && dy <= bx[4] + m && z <= bx[5] + 1 ) {
						inside = true;
						break;
					}
				}
				if( !inside ) {
					outside++;
					if( first == null ) {
						inline function kn( t : Array<Int>, v : Int ) return t[v] < 0 ? "#" + v : Type.getEnumConstructs(BlockKind)[t[v]];
						first = x + "," + y + "," + z + " " + kn(ta, wa.get(i)) + " -> " + kn(tb, wb.get(i)) + "; poses cambiadas "
							+ [for( p in changed ) p.id + "@" + p.x + "," + p.y + "," + p.z + " caja " + p.box.join(",")].join(" | ");
					}
				}
			}
			if( outside > 0 ) bad++;
			out((outside > 0 ? "FUERA  " : "OK     ") + caseName(c) + ": " + tests + " de prueba, " + changed.length + " poses cambiadas, "
				+ diff + " celdas cambiadas" + (outside > 0 ? ", " + outside + " fuera de sus cajas (la primera " + first + ")" : ""));
		}
		out(bad == 0 && nondet == 0 ? 'LOCALITY OK (${cases.length} casos, $posed estructuras de prueba)' : 'LOCALITY FALLA ($bad casos fuera de las cajas, $nondet no deterministas)');
		Sys.exit(bad == 0 && nondet == 0 ? 0 : 1);
	}

	/** genera un caso por tandas, con un limite de tiempo (s); null si no acaba */
	static function generateTimed( c : GenCase, limit : Float, ?force : String ) : gen.DetailsGenerator {
		var g = makeGen(c.seed, c.biome, c.size, versionOf(c));
		if( force != null ) g.forceStructure = force;
		var t0 = haxe.Timer.stamp();
		while( g.process(200) )
			if( haxe.Timer.stamp() - t0 > limit ) return null;
		return g;
	}

	/** los biomas de planeta (sin BITest; con BIShed, el hangar) y los de cometa */
	static function allBiomes( comets : Bool ) : Array<String> {
		return [for( b in Type.allEnums(BiomeKind) ) if( b != BITest && (comets || !isComet(Type.enumConstructor(b))) ) Type.enumConstructor(b)];
	}

	/**
	 * --allstructures [--seeds A-B] [--sizes S]: cada estructura del registro, forzada en cada region (sin tirar su p), en cada
	 * bioma en el que puede salir (con mas semillas, hasta 12, si no ha salido con las pedidas): tiene que acabar (60 s), ponerse
	 * al menos una vez y quedarse en una caja razonable (3/4 del
	 * planeta mas grande probado, 128 como poco: los relieves y el gran crater crecen con el planeta)
	 */
	static function allStructures( args : Array<String> ) {
		var seeds = "1-3", sizes = "1,2", i = 1;
		while( i + 1 < args.length ) {
			switch( args[i] ) {
			case "--seeds": seeds = args[i + 1];
			case "--sizes": sizes = args[i + 1];
			default: throw "opcion desconocida: " + args[i];
			}
			i += 2;
		}
		var r = seeds.split("-").map(Std.parseInt), sz = sizes.split(",").map(Std.parseInt);
		var bad = 0, runs = 0;
		for( e in gen.Structures.ALL )
			for( biome in allBiomes(false) ) {
				var stage = e.stage;
				// las de los eventos del calendario no compiten (Structures.active): solo si pueden salir en el bioma
				if( e.event != null ? !gen.Structures.fits(e, biome, gen.Generator.VERSION) : gen.Structures.active(biome, stage, gen.Generator.VERSION, e.id).length == 0 ) continue;
				var n = 0, worst = 0, slow = 0., err = null;
				// las semillas pedidas y, si no ha salido, mas (hasta 12): en algunos biomas una estructura cabe pocas veces
				var last = r.length > 1 ? r[1] : r[0], seed = r[0];
				while( seed <= last || (n == 0 && err == null && seed < r[0] + 12) ) {
					var s0 = seed++;
					for( s in sz ) {
						var seed = s0;
						runs++;
						var t0 = haxe.Timer.stamp();
						var g = try generateTimed({ seed : seed, biome : biome, size : s }, 60, e.id) catch( ex : Dynamic ) {
							err = Std.string(ex);
							null;
						}
						var dt = haxe.Timer.stamp() - t0;
						if( dt > slow ) slow = dt;
						if( g == null ) {
							if( err == null ) err = "no acaba en 60 s (semilla " + seed + ")";
							continue;
						}
						for( p in g.poses )
							if( p.id == e.id ) {
								n++;
								var w = p.box[3] - p.box[0] + 1, h = p.box[4] - p.box[1] + 1;
								if( w > worst ) worst = w;
								if( h > worst ) worst = h;
							}
					}
				}
				// razonable: como mucho 3/4 del planeta (los relieves y el gran crater crecen con el), y no menos de 128
				var limit = Std.int(Math.max(128, (sz[sz.length - 1] << Const.BITS) * 0.75));
				var ok = err == null && n > 0 && worst <= limit;
				if( !ok ) bad++;
				out((ok ? "OK     " : "FALLA  ") + pad(e.id, 16) + pad(biome, 16) + lpad("" + n, 5) + " puestas, caja " + worst + ", "
					+ ms(slow * 1000) + " ms como mucho" + (err != null ? ", " + err : "") + (n == 0 && err == null ? ", ninguna puesta" : ""));
			}
		out(bad == 0 ? 'ALLSTRUCTURES OK ($runs planetas)' : 'ALLSTRUCTURES FALLA ($bad estructuras y biomas)');
		Sys.exit(bad == 0 ? 0 : 1);
	}

	/**
	 * --fuzz N [--limit S]: todos los biomas (con el hangar BIShed y las cometas) en todos los tamanos (1 a 3; las cometas, el
	 * suyo) con N semillas al azar: cada planeta tiene que acabar en S segundos (60), y el hangar y las cometas sin nada puesto
	 * (ni estructuras ni cristales de hexalita: Structures.PLANET_BIOMES)
	 */
	static function fuzz( args : Array<String> ) {
		var n = args.length > 1 ? Std.parseInt(args[1]) : 5, limit = 60.;
		if( args.length > 3 && args[2] == "--limit" ) limit = Std.parseFloat(args[3]);
		var bad = 0, runs = 0, worst = 0., worstCase = "";
		var rnd = new gen.Rng(Std.int(haxe.Timer.stamp() * 1000) & 0xFFFFFF);
		for( biome in allBiomes(true) )
			for( s in (isComet(biome) ? [1] : [1, 2, 3]) )
				for( k in 0...n ) {
					var c = { seed : rnd.random(1 << 30), biome : biome, size : s };
					runs++;
					var t0 = haxe.Timer.stamp();
					var g = try generateTimed(c, limit) catch( e : Dynamic ) {
						bad++;
						out("ERROR  " + caseName(c) + ": " + Std.string(e));
						continue;
					}
					var dt = haxe.Timer.stamp() - t0;
					if( g == null ) {
						bad++;
						out("LENTO  " + caseName(c) + ": no acaba en " + limit + " s");
						continue;
					}
					if( !gen.Structures.isPlanet(biome) && g.poses.length > 0 ) {
						bad++;
						out("PUESTO " + caseName(c) + ": " + [for( p in g.poses ) p.id].join(",") + " (no es un planeta)");
					}
					if( dt > worst ) {
						worst = dt;
						worstCase = caseName(c);
					}
				}
		out((bad == 0 ? "FUZZ OK" : "FUZZ FALLA (" + bad + ")") + " (" + runs + " planetas, el mas lento " + ms(worst * 1000) + " ms: " + worstCase + ")");
		Sys.exit(bad == 0 ? 0 : 1);
	}

	/**
	 * --registry: los tipos (group) de las estructuras del registro estan en las anomalias de kubindex.json (Base de datos
	 * ESCorp), y que anomalias no tiene ninguna estructura (bonus y cavebonus: los cristales de hexalita, no son estructuras)
	 */
	static function registry() {
		var o : Dynamic = haxe.Json.parse(sys.io.File.getContent("src/G55/fla/client/gfx/kubindex.json"));
		var ids = [for( a in (o.anomalies : Array<Dynamic>) ) Std.string(a.id)];
		var groups = new Map<String, Bool>(), ids2 = new Map<String, Bool>(), missing = [];
		for( e in gen.Structures.ALL ) {
			if( ids2.exists(e.id) ) missing.push("id repetido " + e.id);
			ids2.set(e.id, true);
			// biomes y notIn: solo planetas de verdad (el hangar, el bioma de prueba y las cometas no tienen estructuras)
			for( b in (e.biomes == null ? [] : e.biomes).concat(e.notIn == null ? [] : e.notIn) )
				if( !gen.Structures.isPlanet(b) ) missing.push(e.id + " en " + b + " (no es un planeta)");
			if( e.group == null ) continue;
			for( g in (e.lavaGroup == null ? [e.group] : [e.group, e.lavaGroup]) ) {
				groups.set(g, true);
				if( ids.indexOf(g) < 0 && missing.indexOf(g) < 0 ) missing.push(g);
			}
		}
		var unused = [for( i in ids ) if( !groups.exists(i) && i != "bonus" && i != "cavebonus" ) i];
		out("estructuras: " + gen.Structures.ALL.length + ", tipos: " + [for( g in groups.keys() ) g].length + ", anomalias en kubindex.json: " + ids.length);
		if( unused.length > 0 ) out("anomalias sin estructura: " + unused.join(", "));
		out(missing.length == 0 ? "REGISTRY OK" : "REGISTRY FALLA: " + missing.join(", "));
		Sys.exit(missing.length == 0 ? 0 : 1);
	}
	#end

	#if sys
	static function refOf( g : gen.DetailsGenerator, seed : Int, biomeName : String, sizeChunks : Int, version : Int ) : String {
		var bytes = g.getBytes().b;
		var a = 1, b = 0;
		for( pos in 0...bytes.length ) {
			a = (a + bytes.get(pos)) % 65521;
			b = (b + a) % 65521;
		}
		return refLine(seed, biomeName, sizeChunks, version, StringTools.hex(a, 4) + StringTools.hex(b, 4), [for( p in g.placed ) p.n]);
	}

	/**
	 * Multijugador (anadido del port): genera los casos del fichero de dos en dos, alternando pasos de 1 ms entre los dos
	 * generadores en el mismo hilo (como el servidor dentro del juego junto al planeta del anfitrion), y los compara con sus lineas.
	 * Cada generador tiene su propio tampon (antes flash.Memory era uno solo para todos): uno no debe cambiar lo que sale del otro.
	 */
	static function interleave( file : String ) {
		var cases = [for( l in sys.io.File.getContent(file).split("\n") ) { var s = StringTools.trim(l); if( s != "" && s.charAt(0) != "#" ) s; }];
		cases = [for( c in cases ) if( c != null ) c];
		var fails = 0, swaps = 0;
		var i = 0;
		while( i < cases.length ) {
			var pair = [cases[i]];
			if( i + 1 < cases.length ) pair.push(cases[i + 1]);
			i += 2;
			var gens = [for( want in pair ) { var f = want.split(" "); { want : want, f : f, g : makeGen(Std.parseInt(f[0]), f[1], Std.parseInt(f[2]), Std.parseInt(f[3])), busy : true }; }];
			var any = true;
			while( any ) {
				any = false;
				for( x in gens ) if( x.busy ) {
					x.busy = x.g.process(1);
					swaps++;
					if( x.busy ) any = true;
				}
			}
			for( x in gens ) {
				var got = refOf(x.g, Std.parseInt(x.f[0]), x.f[1], Std.parseInt(x.f[2]), Std.parseInt(x.f[3]));
				if( got == x.want ) out("OK     " + got) else {
					fails++;
					out("CAMBIA " + got);
					out("  ref  " + x.want);
				}
			}
		}
		out(fails == 0 ? 'INTERCALADO OK (${cases.length} casos, $swaps pasos)' : 'INTERCALADO CAMBIA ($fails de ${cases.length})');
		Sys.exit(fails == 0 ? 0 : 1);
	}
	#end

	static function main() {
		#if flash
		#if genOnly
		runAll([CASES[Std.parseInt(haxe.macro.Compiler.getDefine("genCase"))]]);
		#else
		runAll(CASES);
		#end
		#else
		var args = Sys.args();
		try {
			switch( args[0] ) {
			case "--check" if( args.length >= 2 ): check(args[1]);
			case "--interleave" if( args.length >= 2 ): interleave(args[1]);
			case "--profile": profile(args);
			case "--steps": stepSums(args);
			case "--compare" if( args.length >= 3 ): compare(args[1], args[2]);
			case "--census": census(args);
			case "--locality": locality(args);
			case "--allstructures": allStructures(args);
			case "--fuzz": fuzz(args);
			case "--registry": registry();
			default:
				if( args.length >= 3 )
					runAll([{ seed : Std.parseInt(args[0]), biome : args[1], size : Std.parseInt(args[2]), version : args.length >= 4 ? Std.parseInt(args[3]) : null }]);
				else
					runAll(CASES);
			}
		} catch( e : Dynamic ) {
			out("ERROR " + Std.string(e));
			Sys.exit(2);
		}
		#end
	}
}
