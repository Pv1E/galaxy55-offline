import Common;

/**
	Ejecuta el generador de planetas sin pantalla y muestra un resumen verificable.
	Funciona en Flash (log con flash.Lib.trace) y en HashLink (stdout). El trabajo se reparte en
	tandas para no superar el limite de 15 s por script de Flash. La suma Adler-32 usa solo enteros
	pequenos, asi que da el mismo valor en ambos targets.
	En HashLink, `hl port/out/gen.hl SEMILLA BIOMA TAMANO [VERSION]` genera un solo caso (por defecto con Generator.VERSION) y
	escribe su linea ref=; `hl port/out/gen.hl --check port/headless/gen_ref.txt` genera cada caso del fichero con su version y
	lo compara con su linea (sale con codigo 1 si alguno cambia).
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

	static function run( seed : Int, biomeName : String, sizeChunks : Int, version : Int, done : String -> Void ) {
		var biome : BiomeKind = Type.createEnum(BiomeKind, biomeName);
		var gen = new gen.DetailsGenerator(sizeChunks << Const.BITS, seed);
		gen.version = version;
		var bd = Data.getBiome(biome);
		gen.alloc(bd.water);
		gen.alloc(BMinIron);
		gen.alloc(BMinAluminium);
		for( s in bd.soils ) gen.alloc(s);
		gen.startGenerate(biome);
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
					out('blocks=' + [for( k in 0...256 ) if( counts[k] > 0 ) k + ":" + counts[k]].join(" "));
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
	#end

	#if sys
	static function newGen( seed : Int, biomeName : String, sizeChunks : Int, version : Int ) : gen.DetailsGenerator {
		var biome : BiomeKind = Type.createEnum(BiomeKind, biomeName);
		var g = new gen.DetailsGenerator(sizeChunks << Const.BITS, seed);
		g.version = version;
		var bd = Data.getBiome(biome);
		g.alloc(bd.water);
		g.alloc(BMinIron);
		g.alloc(BMinAluminium);
		for( s in bd.soils ) g.alloc(s);
		g.startGenerate(biome);
		return g;
	}

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
	 * flash.Memory es un unico buffer: cada paso de Generator.process vuelve a elegir el suyo (perlin.select).
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
			var gens = [for( want in pair ) { var f = want.split(" "); { want : want, f : f, g : newGen(Std.parseInt(f[0]), f[1], Std.parseInt(f[2]), Std.parseInt(f[3])), busy : true }; }];
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
		if( args.length >= 2 && args[0] == "--check" )
			check(args[1]);
		else if( args.length >= 2 && args[0] == "--interleave" )
			interleave(args[1]);
		else if( args.length >= 3 )
			runAll([{ seed : Std.parseInt(args[0]), biome : args[1], size : Std.parseInt(args[2]), version : args.length >= 4 ? Std.parseInt(args[3]) : null }]);
		else
			runAll(CASES);
		#end
	}
}
