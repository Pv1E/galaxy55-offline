import Common;

/**
 * Nave nodriza del robot comerciante (anadido del port). Casco principal facetado de dos cubiertas, con franjas de ventanas
 * y el morro biselado; detras, cinco capsulas de motor unidas al casco por brazos de celosia. Dentro, un gran hangar abierto
 * por un costado con bahias de aparcamiento (en una esta tu nave; las demas, para el multijugador) y al fondo la zona de
 * comercio (el mostrador del robot y puestos para tiendas de jugadores).
 * El mismo modelo se usa en el mapa (fotogramas como los de tu nave) y como mundo para entrar.
 */
class Mothership {

	/** volumen local y su posicion en el mundo de 128 */
	public static inline var LX = 124;
	public static inline var LY = 124;
	public static inline var LZ = 68;
	public static inline var X0 = 2;
	public static inline var Y0 = 2;
	public static inline var Z0 = 16;
	/** casco principal: de MX0 a MX1 en x (morro hacia +x), centrado en (CY, CZ), media anchura W y media altura H */
	static inline var MX0 = 44;
	static inline var MX1 = 122;
	static inline var CY = 62;
	static inline var CZ = 34;
	static inline var W = 24;
	static inline var H = 13;
	/** hangar: hueco abierto por el costado -y, de HX0 a HX1, de la pared exterior hasta HY1 y de HZ0 a HZ1 */
	public static inline var HX0 = 48;
	public static inline var HX1 = 111;
	public static inline var HY1 = CY + 14;
	public static inline var HZ0 = CZ - 10;
	public static inline var HZ1 = CZ + 9;
	/** bahias: 3 a lo largo del hangar, de 19x19 (cabe la nave mas grande del hangar, 17x17x14) */
	public static inline var BAYS = 3;
	public static inline var BAY = 19;

	/** centro de la bahia i (coordenadas del mundo); z = encima del suelo */
	public static function bay( i : Int ) {
		if( fileBays != null && fileBays.length > 0 ) return fileBays[i % fileBays.length];
		var span = (HX1 - HX0) / BAYS;
		return { x : X0 + Std.int(HX0 + span * (i + 0.5)), y : Y0 + CY - W + 3 + (BAY >> 1), z : Z0 + HZ0 };
	}

	/** media anchura del casco principal en x: el morro se estrecha redondeado */
	static function halfWidth( x : Int ) : Float {
		if( x < MX0 || x > MX1 ) return -1;
		var f = (x - MX0) / (MX1 - MX0);
		if( f < 0.72 ) return W;
		var t = (f - 0.72) / 0.28;
		return W * (0.45 + 0.55 * Math.sqrt(1 - t * t));
	}

	/** casco principal: seccion octogonal (esquinas biseladas) y una ranura entre las dos cubiertas */
	static function mainHull( x : Int, y : Int, z : Int ) : Bool {
		var hw = halfWidth(x);
		if( hw < 0 ) return false;
		var dy = Math.abs(y + 0.5 - CY), dz = z + 0.5 - CZ;
		var hh = x > MX1 - 8 ? H - (x - (MX1 - 8)) * 0.6 : H;
		if( dy > hw || Math.abs(dz) > hh ) return false;
		// biselado de las aristas largas (arriba un poco piramidal)
		if( dy + Math.abs(dz) * 1.1 > hw + hh * 0.45 ) return false;
		if( dz > 0 && dy > hw * 0.45 && dz > hh - (dy - hw * 0.45) * 0.35 ) return false;
		// ranura entre cubiertas en los costados
		if( Math.abs(dz) < 1 && dy > hw - 2 ) return false;
		return true;
	}

	/** capsulas de motor: centro, longitud y radio; con una antena en la punta */
	static var PODS = [
		{ y : CY - 50, z : CZ + 20, x : 10, len : 40, r : 7. },
		{ y : CY + 32, z : CZ + 26, x : 14, len : 36, r : 7. },
		{ y : CY + 54, z : CZ - 2, x : 8, len : 34, r : 6.5 },
		{ y : CY - 40, z : CZ - 22, x : 12, len : 38, r : 7. },
		{ y : CY + 26, z : CZ - 24, x : 6, len : 40, r : 7.5 },
	];

	static function pod( x : Int, y : Int, z : Int ) : Int {
		for( p in PODS ) {
			var fx = (x + 0.5 - p.x) / p.len;
			if( fx < 0 || fx > 1 ) continue;
			// cuerpo: grueso en el centro, punta afilada delante y culata recortada detras
			var prof = fx < 0.15 ? 0.75 + fx / 0.15 * 0.25 : (fx > 0.7 ? 1 - (fx - 0.7) / 0.3 * 0.8 : 1);
			var r = p.r * prof;
			var dy = Math.abs(y + 0.5 - p.y), dz = Math.abs(z + 0.5 - p.z);
			// seccion octogonal
			if( dy <= r && dz <= r && dy + dz <= r * 1.45 ) return 1;
		}
		return 0;
	}

	/** brazos de celosia de la culata del casco a cada capsula */
	static function strut( x : Int, y : Int, z : Int ) : Bool {
		for( p in PODS ) {
			var ax = MX0 + 2., ay = CY + (p.y - CY) * 0.25, az = CZ + (p.z - CZ) * 0.3;
			var bx = p.x + p.len * 0.5, by = p.y, bz = p.z;
			var vx = bx - ax, vy = by - ay, vz = bz - az;
			var l2 = vx * vx + vy * vy + vz * vz;
			var t = ((x + 0.5 - ax) * vx + (y + 0.5 - ay) * vy + (z + 0.5 - az) * vz) / l2;
			if( t < 0 || t > 1 ) continue;
			var qx = ax + vx * t - x - 0.5, qy = ay + vy * t - y - 0.5, qz = az + vz * t - z - 0.5;
			if( qx * qx + qy * qy + qz * qz <= 2.3 ) return true;
		}
		return false;
	}

	static var cache : ShipData.ShipDataInfo;

	/** tamano del mundo (en trozos de 128) y aparicion; cambian si la nave se carga de un archivo */
	public static var sizeChunks = 1;
	public static var spawnAt : { x : Int, y : Int, z : Int };
	/** bahias del hangar de la nave importada (mc2g55.py, formato G55N); null en la nave generada */
	public static var fileBays : Array<{ x : Int, y : Int, z : Int }>;
	/** robots de la nave importada (G55O): celda y tipo (0..3 comerciante mirando a +x, +y, -x, -y; 4 dron) */
	public static var robots : Array<{ x : Int, y : Int, z : Int, k : Int }> = [];

	/** nave importada (port/tools/mc2g55.py): mothership.bin en GALAXY55_MOTHERSHIP o en res/ */
	static function fromFile() : ShipData.ShipDataInfo {
		var p = Sys.getEnv("GALAXY55_MOTHERSHIP");
		if( p == null || p == "" ) p = Res.path("mothership.bin");
		if( !sys.FileSystem.exists(p) ) return null;
		var b = sys.io.File.getBytes(p);
		var magic = b.getString(0, 4);
		if( magic != "G55M" && magic != "G55N" && magic != "G55O" ) return null;
		var w = b.getUInt16(4), l = b.getUInt16(6), h = b.getUInt16(8);
		var sx = b.getUInt16(10), sy = b.getUInt16(12), sz = b.getUInt16(14);
		// G55N: bahias del hangar (centro del suelo de cada una) antes de los datos
		var pos = 16;
		var raw = [];
		var rawRobots = [];
		if( magic == "G55N" || magic == "G55O" ) {
			var n = b.getUInt16(pos);
			pos += 2;
			for( i in 0...n ) {
				raw.push({ x : b.getUInt16(pos), y : b.getUInt16(pos + 2), z : b.getUInt16(pos + 4) });
				pos += 6;
			}
		}
		// G55O: robots (x, y, z, tipo: 0..3 comerciante mirando a +x, +y, -x, -y; 4 dron)
		if( magic == "G55O" ) {
			var n = b.getUInt16(pos);
			pos += 2;
			for( i in 0...n ) {
				rawRobots.push({ x : b.getUInt16(pos), y : b.getUInt16(pos + 2), z : b.getUInt16(pos + 4), k : b.getUInt16(pos + 6) });
				pos += 8;
			}
		}
		var g = haxe.zip.Uncompress.run(b.sub(pos, b.length - pos));
		file = { path : p, header : b.sub(0, pos), w : w, l : l, h : h, base : g };
		sizeChunks = Std.int(Math.max(1, Math.ceil((Math.max(w, l) + 32) / Const.SIZE)));
		var size = sizeChunks * Const.SIZE;
		var ox = (size - w) >> 1, oy = (size - l) >> 1, oz = 24;
		file.ox = ox; file.oy = oy; file.oz = oz;
		fileBays = [for( r in raw ) { x : ox + r.x, y : oy + r.y, z : oz + r.z }];
		robots = [for( r in rawRobots ) { x : ox + r.x, y : oy + r.y, z : oz + r.z, k : r.k }];
		var out = [];
		var i = 0;
		for( z in 0...h )
			for( y in 0...l )
				for( x in 0...w ) {
					var k = g.get(i++);
					if( k != 0 ) out.push({ x : ox + x, y : oy + y, z : oz + z, id : k });
				}
		spawnAt = { x : ox + sx, y : oy + sy, z : oz + sz };
		shopCells = new Map();
		for( r in robots ) if( r.k < 4 ) shop(r, out);
		return { sx : size, sy : size, sz : oz + h, cells : out, entry : null, crafts : [] };
	}

	/** celdas de las tiendas (shop): no se guardan en la nave nodriza (la pared invisible no cabe en un byte) */
	static var shopCells : Map<Int, Bool>;

	/** celda de la tienda del robot r a (a, b): a a su derecha, b hacia delante */
	public static function shopCell( r : { x : Int, y : Int, z : Int, k : Int }, a : Int, b : Int ) {
		var fx = [1, 0, -1, 0][r.k], fy = [0, 1, 0, -1][r.k];
		return { x : r.x + b * fx - a * fy, y : r.y + b * fy + a * fx };
	}

	/**
	 * Tienda del robot comerciante r (anadido del port), hecha aqui y no en mothership.bin, asi no se pierde al volver a generarla
	 * con mc2g55.py. Solo con bloques del juego y abierta, para que no tape el hangar: un cuadro de 7x7 a la altura del robot con
	 * el mostrador de blindaje estriado todo alrededor (se le habla con un clic: GameView.aimedMerchant) y una losa baja por
	 * dentro; columnas de tubos en las esquinas y, encima (a 4 de alto), un techo de casco con neones. Sobre el mostrador, hasta el
	 * techo, una pared invisible (BShopBarrier) para que no se salte adentro; no se apunta, asi se le sigue hablando al robot.
	 */
	static function shop( r : { x : Int, y : Int, z : Int, k : Int }, out : Array<ShipData.ShipCell> ) {
		function put( a : Int, b : Int, dz : Int, k : BlockKind ) {
			var c = shopCell(r, a, b);
			var x = c.x, y = c.y, z = r.z + dz;
			shopCells.set(cellKey(x, y, z), true);
			out.push({ x : x, y : y, z : z, id : Block.get(k).index });
		}
		for( a in -3...4 )
			for( b in -3...4 ) {
				var ring = Std.int(Math.max(Math.abs(a), Math.abs(b)));
				if( ring == 3 ) {
					if( Math.abs(a) == 3 && Math.abs(b) == 3 ) for( dz in 0...4 ) put(a, b, dz, BShipTubes);
					else {
						put(a, b, 0, BShipWire);
						for( dz in 1...4 ) put(a, b, dz, BShopBarrier);
					}
				} else if( ring == 2 ) put(a, b, 0, BShipPlate);
				put(a, b, 4, BShipHull);
				if( Math.abs(a) == 2 && Math.abs(b) == 2 ) put(a, b, 3, BShipLight);
			}
	}

	/** archivo cargado (para guardar lo editado con --editnodriza): ruta, cabecera tal cual, tamano, rejilla original y origen */
	static var file : { path : String, header : haxe.io.Bytes, w : Int, l : Int, h : Int, base : haxe.io.Bytes, ?ox : Int, ?oy : Int, ?oz : Int };
	/** celdas ocupadas por la nave del jugador aparcada: no se guardan en la nave nodriza */
	static var shipCells : Map<Int, Bool>;
	static inline function cellKey( x : Int, y : Int, z : Int ) return (x << 18) | (y << 8) | z;

	/**
	 * Modo de edicion (--editnodriza): escribe el mundo editado en mothership.bin (misma cabecera: aparicion, bahias y
	 * robots). Donde esta tu nave aparcada se deja lo que habia. La primera vez guarda una copia en mothership.bin.orig.
	 * Ojo: si se vuelve a generar con mc2g55.py, se pierden estas ediciones.
	 */
	public static function save( world : World ) : Bool {
		if( file == null ) return false;
		var f = file;
		var g = haxe.io.Bytes.alloc(f.w * f.l * f.h);
		var i = 0;
		for( z in 0...f.h )
			for( y in 0...f.l )
				for( x in 0...f.w ) {
					var wx = f.ox + x, wy = f.oy + y, wz = f.oz + z;
					var k = 0;
					var key = cellKey(wx, wy, wz);
					if( (shipCells != null && shipCells.exists(key)) || (shopCells != null && shopCells.exists(key)) ) k = f.base.get(i);
					else {
						var b = world.block(wx, wy, wz);
						if( b != null ) k = b.index < 256 ? b.index : Type.enumIndex(b.k);
					}
					g.set(i++, k);
				}
		var z = haxe.zip.Compress.run(g, 9);
		var out = new haxe.io.BytesBuffer();
		out.add(f.header);
		out.add(z);
		if( !sys.FileSystem.exists(f.path + ".orig") ) sys.io.File.copy(f.path, f.path + ".orig");
		sys.io.File.saveBytes(f.path, out.getBytes());
		f.base = g;
		cache = null;
		return true;
	}

	/** donde aparece el jugador en la nave nodriza: encima del teletransportador de su nave aparcada (null = la plaza) */
	public static var shipSpawn : { x : Float, y : Float, z : Float };

	/**
	 * La nave nodriza con la nave del jugador aparcada en su plaza (añadido del port): la nave (la del hangar, o la de serie)
	 * se pone centrada en la plaza de llegada, apoyada en el suelo, y el jugador aparece sobre su teletransportador.
	 */
	public static function withShip( ship : haxe.io.Bytes ) : ShipData.ShipDataInfo {
		var base = data();
		shipSpawn = null;
		if( base == null || spawnAt == null || ship == null ) return base;
		var s = try ShipData.load(ship) catch( e : Dynamic ) null;
		if( s == null ) return base;
		var dx = (Const.SIZE - s.sx) >> 1, dy = (Const.SIZE - s.sy) >> 1;
		var ox = spawnAt.x - (s.sx >> 1), oy = spawnAt.y - (s.sy >> 1), oz = spawnAt.z;
		var cells = base.cells.copy();
		shipCells = new Map();
		for( c in s.cells ) shipCells.set(cellKey(ox + c.x - dx, oy + c.y - dy, oz + c.z - 1), true);
		for( c in s.cells ) cells.push({ x : ox + c.x - dx, y : oy + c.y - dy, z : oz + c.z - 1, id : c.id });
		if( s.entry != null ) shipSpawn = { x : ox + s.entry.x - dx + 0.5, y : oy + s.entry.y - dy + 0.5, z : oz + s.entry.z - 1 + 1. };
		return { sx : base.sx, sy : base.sy, sz : base.sz, cells : cells, entry : null, crafts : [] };
	}

	public static function data() : ShipData.ShipDataInfo {
		if( cache != null ) return cache;
		var f = fromFile();
		if( f != null ) return cache = f;
		var kind = new haxe.ds.Vector<Int>(LX * LY * LZ);
		inline function id( x : Int, y : Int, z : Int ) return x + y * LX + z * LX * LY;
		inline function get( x : Int, y : Int, z : Int ) return x >= 0 && y >= 0 && z >= 0 && x < LX && y < LY && z < LZ ? kind[id(x, y, z)] : 0;
		// 1 = casco principal, 2 = capsula, 3 = brazo
		for( x in 0...LX )
			for( y in 0...LY )
				for( z in 0...LZ )
					kind[id(x, y, z)] = mainHull(x, y, z) ? 1 : (pod(x, y, z) > 0 ? 2 : (strut(x, y, z) ? 3 : 0));
		// el hangar: hueco abierto por el costado -y
		for( x in HX0...HX1 )
			for( y in CY - W - 1...HY1 )
				for( z in HZ0...HZ1 )
					if( kind[id(x, y, z)] == 1 ) kind[id(x, y, z)] = 0;
		inline function solid( x, y, z ) return get(x, y, z) != 0;
		var cells = new Map<Int, BlockKind>();
		inline function put( x : Int, y : Int, z : Int, b : BlockKind ) cells.set(id(x, y, z), b);
		for( x in 0...LX )
			for( y in 0...LY )
				for( z in 0...LZ ) {
					var k = kind[id(x, y, z)];
					if( k == 0 ) continue;
					if( solid(x - 1, y, z) && solid(x + 1, y, z) && solid(x, y - 1, z) && solid(x, y + 1, z) && solid(x, y, z - 1) && solid(x, y, z + 1) ) continue;
					var b = BShipHull;
					var side = !solid(x, y - 1, z) || !solid(x, y + 1, z);
					var top = !solid(x, y, z + 1);
					var dz = z - CZ;
					switch( k ) {
					case 1:
						// franjas de ventanas en cada cubierta, paneles en la parte de arriba y luces en el lomo
						if( side && (dz == 5 || dz == -5) && x % 6 != 0 ) b = BShipGlass2;
						else if( side && (dz == 2 || dz == -3 || dz == 8 || dz == -8) ) b = BShipPlate;
						else if( top && (Std.int(x / 5) + Std.int(y / 7)) % 3 == 0 ) b = BShipPlate;
						if( top && x % 10 == 0 && Math.abs(y - CY) < 3 ) b = BShipLight;
						// culata: toberas
						if( !solid(x - 1, y, z) && x <= MX0 + 1 && (y + z) % 3 != 0 ) b = BShipEngine;
					case 2:
						var p = PODS[0];
						for( q in PODS ) if( x >= q.x && x < q.x + q.len && Math.abs(y - q.y) <= q.r + 1 && Math.abs(z - q.z) <= q.r + 1 ) p = q;
						var fx = (x - p.x) / p.len;
						if( fx < 0.08 ) b = BShipEngine; // tobera detras
						else if( fx > 0.62 && fx < 0.72 && side ) b = BShipGlass2;
						else if( Std.int(x / 3) % 3 == 0 ) b = BShipPlate;
					case 3:
						b = (x + y + z) % 3 == 0 ? BShipTubes : BShipPlate;
					}
					put(x, y, z, b);
				}
		// antenas en la punta de cada capsula
		for( p in PODS )
			for( i in 0...7 ) put(p.x + p.len + i, Std.int(p.y), Std.int(p.z), i == 6 ? BShipLight : BShipTubes);
		// hangar: suelo, techo con claraboyas, luces en la pared del fondo, bahias
		var hy0 = CY - W;
		for( x in HX0...HX1 )
			for( y in hy0...HY1 ) {
				if( !solid(x, y, HZ0 - 1) ) continue;
				put(x, y, HZ0 - 1, BShipPlate);
				var beam = (x - HX0) % 9 == 0 || (y - hy0) % 9 == 0 || y >= HY1 - 10;
				for( z in HZ1...CZ + H + 1 )
					if( solid(x, y, z) ) put(x, y, z, beam ? (z == HZ1 && x % 3 == 1 ? BShipLight : BShipPlate) : BGlass);
			}
		for( x in HX0...HX1 )
			for( z in HZ0...HZ1 )
				if( x % 4 == 1 && (z == HZ0 + 3 || z == HZ1 - 3) ) put(x, HY1, z, BShedWallLight);
		for( i in 0...BAYS ) {
			var c = bay(i);
			var bx = c.x - X0, by = c.y - Y0;
			for( dx in -(BAY >> 1)...(BAY >> 1) + 1 )
				for( dy in -(BAY >> 1)...(BAY >> 1) + 1 ) {
					var edge = Math.abs(dx) == BAY >> 1 || Math.abs(dy) == BAY >> 1;
					if( edge && (dx + dy) % 2 == 0 ) put(bx + dx, by + dy, HZ0 - 1, BShipLight);
					else if( edge ) put(bx + dx, by + dy, HZ0 - 1, BShedGroundArrow);
				}
		}
		// zona de comercio al fondo del hangar: el mostrador del robot en el centro y puestos a los lados
		// (para las tiendas de jugadores en el multijugador), con toldos de colores
		var awn = [BStainRed, BStainOrange, BStainGreen, BStainPurple, BStainWhite, BStainRed];
		var stalls = 7, sw = 7;
		var sx0 = ((HX0 + HX1) >> 1) - ((stalls * (sw + 1)) >> 1);
		var cy0 = HY1 - 7;
		for( i in 0...stalls ) {
			var x0 = sx0 + i * (sw + 1);
			var robot = i == stalls >> 1;
			for( dx in 0...sw ) {
				put(x0 + dx, cy0, HZ0, robot ? BShipComputer : BShipPlate);
				for( dy in 1...6 ) put(x0 + dx, cy0 + dy, HZ0 + 5, robot ? BShipLight : awn[i % awn.length]);
			}
			for( dz in 0...5 ) {
				put(x0, cy0, HZ0 + dz, BShipTubes);
				put(x0 + sw - 1, cy0, HZ0 + dz, BShipTubes);
			}
			if( !robot ) put(x0 + (sw >> 1), cy0 + 3, HZ0 + 4, BShipLight);
		}
		var out = [];
		for( key => b in cells ) {
			var x = key % LX, y = Std.int(key / LX) % LY, z = Std.int(key / (LX * LY));
			out.push({ x : X0 + x, y : Y0 + y, z : Z0 + z, id : Type.enumIndex(b) });
		}
		return cache = { sx : Const.SIZE, sy : Const.SIZE, sz : Z0 + LZ, cells : out, entry : null, crafts : [] };
	}
}
