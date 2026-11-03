import Common;

/**
 * Terreno de las cometas (Comets, añadido del port): un caso por tipo de cometa, como BiomeGenerator con los biomas. Sin
 * anomalias ni edificios (addDetails), sin cristales verdes (addBonus) y sin mar. La roca es soils[0] del bioma y el agua
 * del bioma no se pone nunca.
 */
@:access(gen.Generator)
class CometGenerator extends gen.DetailsGenerator {

	static inline var EMPTY = gen.Generator.EMPTY;
	static inline var BEDROCK = gen.Generator.BEDROCK;
	static inline var ROCK = gen.Generator.ROCK;
	static inline var HBITS = gen.Generator.HBITS;
	static inline var HEIGHT = gen.Generator.HEIGHT;

	override function initBiome( biome : BiomeKind ) {
		switch( biome ) {
		case BICometCinder:
			// cometa calcinada: un valle entre dos crestas (que se juntan al dar la vuelta), roca de lecho de meteorito con roca
			// madre debajo, montoncitos de escombros calcinados, alguna veta de etherium azul y una o dos fuentes de lava
			waterLevel = 0;
			globalScale = 4;
			Macro.generate({
				addHeight(1, 1);
				addHeight(3, 0.4);
				addHeight(8, 0.15);
				valley(18, 46, 5);
				smoothHeight();
				smoothHeight();
				fillRock(3);
				addMounds(7 + rnd.random(4));
				addScattered(BLavaRock, 4 + rnd.random(4));
				addVeins(5 + rnd.random(3));
				addLava(1 + rnd.random(2), 24);
			});
		default:
			super.initBiome(biome);
		}
	}

	override function addDetails() {}

	override function addBonus() {}

	/**
	 * Alturas en forma de valle: el fondo (floor) sigue un eje que serpentea a lo largo de y y sube hasta la cresta (ridge) a
	 * media vuelta del eje. El ruido (perlin acumulado con addHeight) mueve cada columna hasta `noise` bloques.
	 */
	function valley( floor : Float, ridge : Float, noise : Float ) {
		var half = size * 0.5;
		var x0 = rnd.random(size);
		var amp = size * (0.05 + rnd.rand() * 0.07);
		var phase = rnd.rand() * Math.PI * 2;
		for( y in 0...size )
			for( x in 0...size ) {
				var axis = x0 + amp * Math.sin(Math.PI * 2 * y / size + phase);
				var d = ((x - axis) % size + size) % size;
				if( d > half ) d = size - d;
				var t = d / half;
				var h = floor + (ridge - floor) * t * t * (3 - 2 * t) + realHeight(x + y * size) * noise;
				setHeight(x, y, h < 4 ? 4 : Std.int(h));
			}
	}

	/** columnas llenas de roca hasta su altura, con `bed` capas de roca madre abajo */
	function fillRock( bed : Int ) {
		for( p in 0...size * size ) {
			var addr = p << HBITS;
			for( z in 0...hval(p) ) fset(addr + z, z < bed ? BEDROCK : ROCK);
		}
	}

	/** montoncitos de escombros calcinados sobre el suelo, con algun escombro incandescente o basalto */
	function addMounds( n : Int ) {
		var coal = alloc(BCoal), hot = alloc(BCoalHot), basalt = alloc(BLavaRock);
		for( i in 0...n ) {
			var x = rnd.random(size), y = rnd.random(size);
			var r = 2 + rnd.rand() * 2.5;
			var top = 1.5 + rnd.rand() * 2;
			circle(r, r, function(dx, dy) {
				var d = (dx * dx + dy * dy) / (r * r);
				var hh = Math.round(top * (1 - d) + rnd.rand() * 0.6);
				var z = topAt(x + dx, y + dy);
				for( k in 0...hh ) {
					var v = rnd.random(100);
					set(x + dx, y + dy, z + k, v < 4 ? hot : v < 8 ? basalt : coal);
				}
			});
		}
	}

	/** bloques sueltos de b en el suelo */
	function addScattered( b : BlockKind, n : Int ) {
		var b = alloc(b);
		for( i in 0...n ) {
			var x = rnd.random(size), y = rnd.random(size);
			set(x, y, topAt(x, y) - 1, b);
		}
	}

	/** vetas de etherium azul (alguna con fragmentos) que salen a la superficie */
	function addVeins( n : Int ) {
		var dense = alloc(BBlueCrystalDense), frag = alloc(BBlueCrystalLight);
		for( i in 0...n ) {
			var x = rnd.random(size), y = rnd.random(size);
			var z = topAt(x, y) - 1 - rnd.random(3);
			for( k in 0...4 + rnd.random(6) ) {
				if( get(x, y, z) == ROCK ) set(x, y, z, rnd.random(6) == 0 ? frag : dense);
				switch( rnd.random(6) ) {
				case 0: x++;
				case 1: x--;
				case 2: y++;
				case 3: y--;
				case 4: z++;
				default: z--;
				}
			}
		}
	}

	/**
	 * Fuentes de lava (n como mucho) en el fondo del valle (altura hasta zmax): cada una en un hoyo de un bloque, con basalto
	 * alrededor y debajo para que no corra.
	 */
	function addLava( n : Int, zmax : Int ) {
		var lava = alloc(BLava), basalt = alloc(BLavaRock);
		var tries = 2000;
		while( n > 0 && tries-- > 0 ) {
			var x = rnd.random(size), y = rnd.random(size);
			var z = topAt(x, y);
			if( z > zmax || get(x, y, z - 1) != ROCK ) continue;
			for( dx in -1...2 )
				for( dy in -1...2 )
					set(x + dx, y + dy, z - 2, basalt);
			set(x - 1, y, z - 1, basalt);
			set(x + 1, y, z - 1, basalt);
			set(x, y - 1, z - 1, basalt);
			set(x, y + 1, z - 1, basalt);
			set(x, y, z - 1, lava);
			n--;
		}
	}

	/** primera celda vacia por encima del suelo de la columna */
	function topAt( x : Int, y : Int ) : Int {
		var z = HEIGHT - 2;
		while( z > 0 && get(x, y, z) == EMPTY ) z--;
		return z + 1;
	}
}
