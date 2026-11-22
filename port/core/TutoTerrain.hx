import Common;

typedef TutoFace = { x : Int, y : Int, z : Int, ox : Int, oy : Int };

/**
 * Terreno del tutorial (TutoSetup.seedPlanet) cerca de la nave:
 * - etheriumCave: un hueco abierto en un risco cercano con los fragmentos de etherium en sus paredes; si no hay risco, en un
 *   penasco de roca que se levanta alli (como las paredes de las grutas, donde los pone el generador: addCaveCrystals);
 * - bauxiteVein: un filon de bauxita como los del generador (addMineralsRocks + fillMinerals: elipsoides de volcanita, o
 *   Rouge'rosh, casi enterrados y con el mineral dentro).
 * put(x, y, z, bloque) pone un bloque del tutorial y lo apunta para seguirlo.
 */
class TutoTerrain {

	public static inline function wrap( w : WorldData, v : Int ) return ((v % w.size) + w.size) % w.size;

	static function block( w : WorldData, x : Int, y : Int, z : Int ) return w.block(wrap(w, x), wrap(w, y), z);

	static function set( w : WorldData, x : Int, y : Int, z : Int, k : BlockKind ) w.setBlock(wrap(w, x), wrap(w, y), z, k == null ? null : Block.get(k));

	/** aire o un detalle (hierba, flores): se puede pisar o tapar */
	static function free( w : WorldData, x : Int, y : Int, z : Int ) {
		var b = block(w, x, y, z);
		return b == null || b.hasFlag(BFDetail);
	}

	static function solid( w : WorldData, x : Int, y : Int, z : Int ) {
		var b = block(w, x, y, z);
		return b != null && b.type == BTFull && !b.hasProp(PLiquid) && b.k != BWood;
	}

	/** el bloque macizo mas alto de la columna (-1 si hay liquido encima o un tronco) */
	public static function top( w : WorldData, x : Int, y : Int ) : Int {
		var z = WorldData.HEIGHT - 2;
		while( z > 0 ) {
			var b = block(w, x, y, z);
			if( b != null ) {
				if( b.hasProp(PLiquid) || b.k == BWood ) return -1;
				if( b.type == BTFull ) return z;
			}
			z--;
		}
		return -1;
	}

	/** suelo seco y despejado cerca del punto (angulo a, distancia d) de la nave, a una altura parecida a la suya */
	public static function ground( w : WorldData, sx : Int, sy : Int, gz : Int, a : Float, d : Float ) : { x : Int, y : Int, z : Int } {
		var x0 = sx + Math.round(Math.cos(a) * d), y0 = sy + Math.round(Math.sin(a) * d);
		for( r in 0...10 )
			for( dx in -r...r + 1 )
				for( dy in -r...r + 1 ) {
					if( Math.abs(dx) != r && Math.abs(dy) != r ) continue;
					var x = x0 + dx, y = y0 + dy;
					var z = top(w, x, y);
					if( z > 0 && Math.abs(z - gz) <= 8 && free(w, x, y, z + 1) && free(w, x, y, z + 2) ) return { x : x, y : y, z : z };
				}
		var z = top(w, x0, y0);
		return { x : x0, y : y0, z : z > 0 ? z : gz };
	}

	/** un monticulo (r = radio, h = alto en el centro) de ese bloque sobre el suelo de (cx, cy, base); sin tocar troncos ni hojas */
	static function mound( w : WorldData, cx : Int, cy : Int, base : Int, r : Float, h : Float, k : BlockKind ) {
		var n = Math.ceil(r);
		for( dx in -n...n + 1 )
			for( dy in -n...n + 1 ) {
				var d = Math.sqrt(dx * dx + dy * dy);
				if( d > r ) continue;
				var zt = base + Math.round(h * (1 - d / (r + 1)));
				var z = Std.int(Math.min(top(w, cx + dx, cy + dy), base)) + 1;
				while( z <= zt ) {
					if( free(w, cx + dx, cy + dy, z) ) set(w, cx + dx, cy + dy, z, k);
					z++;
				}
			}
	}

	/** risco cercano: suelo despejado delante (x, y, z) y, hacia (ox, oy), roca de al menos 3 de alto y 3 de fondo */
	static function cliff( w : WorldData, sx : Int, sy : Int, gz : Int ) : TutoFace {
		var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
		for( d in 14...32 )
			for( i in 0...24 ) {
				var a = 1.2 + i * Math.PI / 12;
				var x = sx + Math.round(Math.cos(a) * d), y = sy + Math.round(Math.sin(a) * d);
				var z = top(w, x, y);
				if( z <= 0 || Math.abs(z - gz) > 8 || !free(w, x, y, z + 1) || !free(w, x, y, z + 2) ) continue;
				for( o in dirs ) {
					// roca en el hueco (3 de fondo, 3 de alto) y a sus lados, donde iran los fragmentos
					var ok = true;
					for( k in 1...4 ) for( h in 1...4 ) if( !solid(w, x + o[0] * k, y + o[1] * k, z + h) ) ok = false;
					for( p in [-1, 1] ) for( h in 1...3 ) if( !solid(w, x + o[0] * 2 - o[1] * p, y + o[1] * 2 + o[0] * p, z + h) ) ok = false;
					if( ok ) return { x : x, y : y, z : z, ox : o[0], oy : o[1] };
				}
			}
		return null;
	}

	/** sin risco cerca: un penasco de roca delante de un sitio de suelo, para abrir el hueco en el */
	static function outcrop( w : WorldData, sx : Int, sy : Int, gz : Int ) : TutoFace {
		var s = ground(w, sx, sy, gz, 1.2, 20);
		mound(w, s.x + 4, s.y, s.z, 3.5, 6, BRock);
		return { x : s.x, y : s.y, z : s.z, ox : 1, oy : 0 };
	}

	/** 3 fragmentos de etherium en las paredes de un hueco de 2 de hondo y 2 de alto abierto en la roca */
	public static function etheriumCave( w : WorldData, sx : Int, sy : Int, gz : Int, put : Int -> Int -> Int -> BlockKind -> Void ) {
		var c = cliff(w, sx, sy, gz);
		if( c == null ) c = outcrop(w, sx, sy, gz);
		var px = -c.oy, py = c.ox;
		for( k in 1...3 ) for( h in 1...3 ) set(w, c.x + c.ox * k, c.y + c.oy * k, c.z + h, null);
		put(c.x + c.ox * 3, c.y + c.oy * 3, c.z + 1, BBlueCrystalLight);
		put(c.x + c.ox * 2 + px, c.y + c.oy * 2 + py, c.z + 2, BBlueCrystalLight);
		put(c.x + c.ox * 2 - px, c.y + c.oy * 2 - py, c.z + 1, BBlueCrystalLight);
	}

	/** Generator.elipse: las celdas de un elipsoide de semiejes (xx, yy, zz) */
	static function elipse( xx : Int, yy : Int, zz : Int, f : Int -> Int -> Int -> Void ) {
		for( dx in -xx...xx + 1 )
			for( dy in -yy...yy + 1 )
				for( dz in -zz...zz + 1 )
					if( (dx / xx) * (dx / xx) + (dy / yy) * (dy / yy) + (dz / zz) * (dz / zz) <= 1 ) f(dx, dy, dz);
	}

	/** da al aire (o a un liquido) por un lado o por arriba: se ve y se puede minar desde fuera */
	static function exposed( w : WorldData, x : Int, y : Int, z : Int ) {
		for( o in [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1]] ) {
			var b = block(w, x + o[0], y + o[1], z + o[2]);
			if( b == null || b.hasProp(PLiquid) || b.hasFlag(BFDetail) ) return true;
		}
		return false;
	}

	/**
	 * Filon de bauxita del generador (BiomeGenerator.addMineralsRocks + fillMinerals): 4 elipsoides de volcanita alrededor de un
	 * punto del suelo, casi enterradas (entre el 3 y el 20 % de aire), y una sexta parte de sus celdas de mineral (las que dan al
	 * aire, 1 vez de cada 5). Para el tutorial el mineral es siempre bauxita (en el generador, 1 filon de cada 5) y al menos 3
	 * asoman: son las que se marcan.
	 */
	public static function bauxiteVein( w : WorldData, sx : Int, sy : Int, gz : Int, put : Int -> Int -> Int -> BlockKind -> Void ) {
		var rnd = new mt.Rand(w.seed ^ 0xBA0C);
		var s = ground(w, sx, sy, gz, 2.6, 28);
		var el = [];
		for( t in 0...60 ) {
			var x = s.x + rnd.random(9) - 4, y = s.y + rnd.random(9) - 4, z = s.z - rnd.random(3);
			el = [for( i in 0...4 ) { x : x + rnd.random(6) - 3, y : y + rnd.random(6) - 3, z : z + rnd.random(6) - 3, sx : 2 + rnd.random(3), sy : 2 + rnd.random(3), sz : 2 + rnd.random(2) }];
			var empty = 0, full = 0;
			for( e in el ) elipse(e.sx, e.sy, e.sz, function(dx, dy, dz) if( block(w, e.x + dx, e.y + dy, e.z + dz) == null ) empty++ else full++);
			var ratio = (empty + 1) / (empty + full + 1);
			if( ratio >= 0.03 && ratio <= 0.2 ) break;
		}
		var pts = [];
		for( e in el )
			elipse(e.sx, e.sy, e.sz, function(dx, dy, dz) {
				var z = e.z + dz;
				if( z < 1 || z >= WorldData.HEIGHT - 1 ) return;
				set(w, e.x + dx, e.y + dy, z, BHardRock);
				pts.push({ x : e.x + dx, y : e.y + dy, z : z });
			});
		var all = pts.copy(), shown = [];
		for( i in 0...Std.int(pts.length / 6) ) {
			var p = pts[rnd.random(pts.length)];
			pts.remove(p);
			var out = exposed(w, p.x, p.y, p.z);
			if( out && rnd.random(5) != 0 ) continue;
			set(w, p.x, p.y, p.z, BMinAluminium);
			if( out ) shown.push(p);
		}
		for( p in all ) {
			if( shown.length >= 3 ) break;
			var b = block(w, p.x, p.y, p.z);
			if( b != null && b.k == BHardRock && exposed(w, p.x, p.y, p.z) ) shown.push(p);
		}
		for( p in shown ) put(p.x, p.y, p.z, BMinAluminium);
	}
}
