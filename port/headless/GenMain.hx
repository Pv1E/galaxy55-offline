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
	CASOS: --seeds A-B (o una sola), --biomes B1,B2 (todos menos BITest y BIShed; las cometas miden COMET_SIZE con cualquier
	tamano), --sizes 1,2,3 (en trozos), --version N (Generator.VERSION). Por defecto: --profile 1-5 de tamano 3, --steps 1-100
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
		var bd = Data.getBiome(biome);
		gen.alloc(bd.water);
		gen.alloc(BMinIron);
		gen.alloc(BMinAluminium);
		for( s in bd.soils ) gen.alloc(s);
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
			case "--profile": profile(args);
			case "--steps": stepSums(args);
			case "--compare" if( args.length >= 3 ): compare(args[1], args[2]);
			case "--census": census(args);
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
