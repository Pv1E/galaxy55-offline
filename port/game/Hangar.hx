import Common;

/**
 * Hangar (EditShip del original): un cobertizo (biome BIShed) con la nave dentro, en una zona construible de 17x17x14.
 * - shedData: el cobertizo de net/EditShip.initLevel con la nave centrada.
 * - check: EditShip.checkShip, la validacion de la nave (teletransportador, casco estanco, motores, ordenador, sintetizador).
 * - shipBytes: la nave de la zona construible, en el formato de las naves (zlib de sx, sy, sz + indices de 2 bytes).
 * El cobertizo del original daba la vuelta al mundo (las casillas de salida estaban en x = -1 y -2); el port no da la
 * vuelta, asi que todo se desplaza OX en x.
 */
class Hangar {

	public static inline var SX = 17;
	public static inline var SY = 17;
	public static inline var SZ = 14;
	static inline var OX = 4;

	/** nave actual de la partida (comprimida); la de serie si no se ha editado */
	public static function currentShip( info : SaveData.SaveInfo ) : haxe.io.Bytes {
		if( info != null && info.shipData != null )
			try return haxe.crypto.Base64.decode(info.shipData) catch( e : Dynamic ) {}
		return Const.DEFAULT_SHIP;
	}

	/** posicion de aparicion (EditShip.getPosition: x = -0.5, sobre las casillas de salida) */
	public static function spawn() return { x : OX - 0.5, y : SY * 0.5 + 2.5, z : 1. };

	/** celda del hangar de un bloque (x, y, z) del plano de una nave de sx x sy (shedData: centrada en la zona construible) */
	public static function shipCell( x : Int, y : Int, z : Int, sx : Int, sy : Int ) {
		return { x : (2 + ((SX - sx) >> 1) + x + OX) & Const.MASK, y : 2 + ((SY - sy) >> 1) + y, z : 1 + z };
	}

	/** dentro de la zona construible (EditShip.checkSelect) */
	public static function inZone( x : Int, y : Int, z : Int ) {
		x -= OX;
		return !(x <= 1 || y <= 1 || x > SX + 1 || y > SY + 1 || z <= 0 || z > SZ);
	}

	/**
	 * Lo que no se puede poner en el hangar (cambio del port): devuelve la clave del aviso (hangar.<clave> en Lang) o null.
	 * - liquidos: BFLiquid (agua de cada planeta, cascada, arena movediza) y la lava (BFIsLava: en el original no es
	 *   BFLiquid). Incluye lo que se extiende (propagate), lo unico que el original no dejaba poner (EditShip.checkSelect).
	 * - la bomba exotica (BArtiBomb).
	 */
	public static function forbidden( b : Block ) : String {
		if( b.hasProp(PLiquid) || b.hasProp(PLava) || b.propagate != null ) return "no_liquid";
		if( b.k == BArtiBomb ) return "no_bomb";
		return null;
	}

	public static function shedData( ship : haxe.io.Bytes ) : ShipData.ShipDataInfo {
		var cells = new Map<Int, Int>();
		inline function set( x : Int, y : Int, z : Int, b : BlockKind ) {
			x = (x + OX) & Const.MASK;
			cells.set((x << 16) | (y << 8) | z, Type.enumIndex(b));
		}
		for( x in 0...Const.SIZE )
			for( y in 0...Const.SIZE )
				set(x, y, 0, y % 3 == 0 ? BShedGroundArrow : BShedGlass);
		var size = { x : SX + 4, y : SY + 4, z : SZ + 2 };
		for( x in 0...size.x )
			for( y in 0...size.y ) {
				if( x == 1 || y == 1 || x == size.x - 2 || y == size.y - 2 ) {
					set(x, y, 0, BShedWall);
					set(x, y, size.z - 1, BShedWall);
				} else if( x % 4 == 2 && y % 4 == 2 )
					set(x, y, size.z - 1, BShedLight);
				else
					set(x, y, size.z - 1, BShedGlass);
			}
		var hmin = size.y >> 1;
		var hmax = ((size.y - 1) >> 1) + 1;
		if( hmin == hmax ) {
			hmin--;
			hmax++;
		}
		for( z in 0...size.z ) {
			for( x in 0...size.x ) {
				var b = z == 3 && x % 3 == 0 ? BShedWallLight : BShedWall;
				set(x, 0, z, b);
				set(x, size.y - 1, z, b);
			}
			for( y in 0...size.y ) {
				var b = y % 3 == 0 ? BShedWallColumn : BShedWall;
				set(size.x - 1, y, z, b);
				var x = (y < hmin || y > hmax) ? 0 : Const.SIZE - 2;
				set(x, y, z, b);
			}
			set(Const.SIZE - 1, hmin - 1, z, BShedWall);
			set(Const.SIZE - 1, hmax + 1, z, BShedWall);
		}
		for( x in 0...2 )
			for( y in hmin...hmax + 1 ) {
				set((Const.SIZE - x) & Const.MASK, y, 0, BShipEntry);
				set((Const.SIZE - x) & Const.MASK, y, size.z - 1, BShedGlass);
			}
		// la nave, centrada en la zona construible
		var raw = haxe.zip.Uncompress.run(ship);
		var sx = raw.get(0), sy = raw.get(1), sz = raw.get(2);
		if( sx <= SX && sy <= SY && sz <= SZ ) {
			var dx = 2 + ((SX - sx) >> 1), dy = 2 + ((SY - sy) >> 1), dz = 1;
			var pos = 3;
			for( y in 0...sy )
				for( x in 0...sx )
					for( z in 0...sz ) {
						var bid = raw.get(pos) | (raw.get(pos + 1) << 8);
						pos += 2;
						var xx = (dx + x + OX) & Const.MASK;
						var k = (xx << 16) | ((dy + y) << 8) | (dz + z);
						if( bid != 0 ) cells.set(k, bid) else cells.remove(k);
					}
		}
		var out = [];
		for( k => id in cells ) out.push({ x : k >> 16, y : (k >> 8) & 0xFF, z : k & 0xFF, id : id });
		return { sx : Const.SIZE, sy : Const.SIZE, sz : size.z, cells : out, entry : null, crafts : [] };
	}

	/**
	 * Indice del bloque para guardar y comprobar la nave (0 = nada). Cambio del port: una puerta abierta cuenta como cerrada; el
	 * original la guardaba abierta y, sin colision, la tomaba por un agujero del casco. Tambien en Ship.new (cambios de a bordo).
	 */
	public static function shipId( b : Block ) : Int {
		if( b == null ) return 0;
		return switch( b.k ) {
			case BShipDoorOpen, BShipDoorYOpen: b.toggle.index;
			default: b.index;
		}
	}

	/** la nave de la zona construible (net/EditShip.getShipData), con las puertas cerradas */
	public static function shipBytes( w : World ) : haxe.io.Bytes {
		var data = haxe.io.Bytes.alloc(SX * SY * SZ * 2 + 3);
		data.set(0, SX);
		data.set(1, SY);
		data.set(2, SZ);
		var pos = 3;
		for( y in 0...SY )
			for( x in 0...SX )
				for( z in 0...SZ ) {
					var id = shipId(w.block(2 + x + OX, 2 + y, 1 + z));
					data.set(pos, id & 0xFF);
					data.set(pos + 1, id >> 8);
					pos += 2;
				}
		return haxe.zip.Compress.run(data, 9);
	}

	// ---------------------------------------------------------------- EditShip.checkShip

	static inline var AIR = 0xFFFF;
	static inline var NO_HULL = 0xFFFE;
	static inline var HULL = 0xFFFD;
	static inline var WALK = 0xFFFC;
	// volumen de trabajo: x 0..SX+3, y 0..SY+3, z 0..SZ+1 (coordenadas del original, sin OX)
	static inline var WX = SX + 4;
	static inline var WY = SY + 4;
	static inline var WZ = SZ + 2;
	static inline var DX = 1;
	static inline var DY = WX;
	static inline var DZ = WX * WY;

	static var collideBits : Array<Int>;
	var t : Array<Int>;
	var blocks : Array<Int>;
	/** bloque de una celda del cobertizo (World.block del hangar, o de una nave sin mundo: speedOf) */
	var blockAt : Int -> Int -> Int -> Block;

	/** resultado: null si la nave es valida; si no, la clave del error (hangar.<clave> en Lang) */
	public var error(default, null) : String;
	public var speed(default, null) = 0.;
	/** casilla del teletransportador (coordenadas del mundo), para la comprobacion de luz */
	public var spawnCell(default, null) : { x : Int, y : Int, z : Int };

	/**
	 * Velocidad de una nave (PC/s) como la da check() en el hangar (añadido del port, para las cometas): la nave puesta en el
	 * cobertizo como shedData, sin crear el mundo. 0 si la nave no es valida.
	 */
	public static function speedOf( ship : haxe.io.Bytes ) : Float {
		var cells = new Map<Int, Block>();
		for( c in shedData(ship).cells ) cells.set((c.x << 16) | (c.y << 8) | c.z, Block.all[c.id]);
		var h = new Hangar(null);
		h.blockAt = function(x, y, z) return x < 0 || y < 0 || z < 0 ? null : cells.get((x << 16) | (y << 8) | z);
		return h.check() ? h.speed : 0;
	}

	public function new( w : World ) {
		if( w != null ) blockAt = w.block;
		if( collideBits == null ) {
			collideBits = [for( b in Block.all ) 0];
			for( b in Block.all ) {
				if( !b.collide ) continue;
				if( b.size == null ) collideBits[b.index] = 7;
				else {
					var x = b.size.x1 == 0 && b.size.x2 == 1;
					var y = b.size.y1 == 0 && b.size.y2 == 1;
					var z = b.size.z1 == 0 && b.size.z2 == 1;
					if( y && z ) collideBits[b.index] |= 1;
					if( x && z ) collideBits[b.index] |= 2;
					if( x && y ) collideBits[b.index] |= 4;
				}
			}
		}
	}

	inline function addr( x : Int, y : Int, z : Int ) return x + y * DY + z * DZ;
	inline function get( a : Int ) return a < 0 || a >= t.length ? 0 : t[a];
	inline function set( a : Int, v : Int ) if( a >= 0 && a < t.length ) t[a] = v;
	inline function getBlock( a : Int ) return a < 0 || a >= blocks.length ? 0 : blocks[a];

	function fail( e : String ) {
		error = e;
		return false;
	}

	public function check() : Bool {
		error = null;
		t = [];
		blocks = [];
		// la nave como se guarda (puertas cerradas): una puerta abierta no es un agujero del casco
		for( z in 0...WZ )
			for( y in 0...WY )
				for( x in 0...WX ) {
					var id = shipId(blockAt(x + OX, y, z));
					t.push(id);
					blocks.push(id);
				}
		var pos = -1;
		var engines = [], computers = [], craft = [], craftOut = [];
		for( x in 0...SX )
			for( y in 0...SY )
				for( z in 0...SZ ) {
					var a = addr(x + 2, y + 2, z + 1);
					var b = get(a);
					if( b == Type.enumIndex(BShipEntry) ) {
						if( pos >= 0 ) return fail("multiple_spawn");
						pos = a;
						spawnCell = { x : x + 2 + OX, y : y + 2, z : z + 1 };
					} else if( b == Type.enumIndex(BShipEngine) ) engines.push(a);
					else if( b == Type.enumIndex(BShipComputer) ) computers.push(a);
					else if( b == Type.enumIndex(BCrafter) ) craft.push(a);
					else if( b == Type.enumIndex(BCrafterComputer) ) craftOut.push(a);
				}
		if( pos < 0 ) return fail("no_spawn");
		if( get(pos + DZ) != 0 || get(pos + DZ * 2) != 0 ) return fail("no_spawn_air");
		// casco estanco
		set(pos + DZ, AIR);
		var changed;
		do {
			changed = false;
			for( x in 0...SX )
				for( y in 0...SY ) {
					var a = addr(x + 2, y + 2, 1);
					for( z in 0...SZ ) {
						var b = get(a);
						if( b < NO_HULL ) {
							a += DZ;
							continue;
						}
						if( x == 0 || y == 0 || z == 0 || x == SX - 1 || y == SY - 1 || z == SZ - 1 ) return fail("hull_hole");
						if( checkHull(a - DX, 1) ) changed = true;
						if( checkHull(a + DX, 1) ) changed = true;
						if( checkHull(a - DY, 2) ) changed = true;
						if( checkHull(a + DY, 2) ) changed = true;
						if( checkHull(a - DZ, 4) ) changed = true;
						if( checkHull(a + DZ, 4) ) changed = true;
						a += DZ;
					}
				}
		} while( changed );
		// el casco se extiende a todo lo que toca
		do {
			changed = false;
			for( x in 0...SX )
				for( y in 0...SY ) {
					var a = addr(x + 2, y + 2, 1);
					for( z in 0...SZ ) {
						if( get(a) != HULL ) {
							a += DZ;
							continue;
						}
						if( setHull(a + DX) ) changed = true;
						if( setHull(a - DX) ) changed = true;
						if( setHull(a + DY) ) changed = true;
						if( setHull(a - DY) ) changed = true;
						if( setHull(a + DZ) ) changed = true;
						if( setHull(a - DZ) ) changed = true;
						a += DZ;
					}
				}
		} while( changed );
		var total = 0, other = 0;
		for( x in 0...SX )
			for( y in 0...SY ) {
				var a = addr(x + 2, y + 2, 1);
				for( z in 0...SZ ) {
					var v = get(a);
					if( v == HULL ) total++;
					else if( v != 0 && v != AIR ) other++;
					a += DZ;
				}
			}
		walkRec(pos + DZ, 0);
		if( other > 0 ) return fail("separate_part");
		var engineCount = 0;
		for( e in engines )
			if( get(e - DX) == 0 ) engineCount++;
		if( engineCount == 0 ) return fail(engines.length > 0 ? "need_engine_out" : "need_engine");
		if( engineCount < 2 ) return fail("need_engines_min2");
		if( total / engineCount > 70 ) return fail("need_engines");
		if( computers.length == 0 ) return fail("need_computer");
		if( craft.length == 0 ) return fail("need_craft");
		if( craftOut.length == 0 ) return fail("need_craft_computer");
		var access = function(a) return get(a) == WALK && getBlock(a) == 0;
		if( !Lambda.exists(computers, function(c) return access(c + DX) || access(c - DX) || access(c + DY) || access(c - DY) || access(c - DZ) || access(c + DZ)) )
			return fail("access_computer");
		if( !Lambda.exists(craft, function(c) return get(c + DZ) == WALK) ) return fail("access_craft");
		if( !Lambda.exists(craftOut, function(c) return (get(c) == AIR || get(c) == WALK) && (access(c + DX) || access(c - DX) || access(c - DY) || access(c + DY) || access(c + DZ))) )
			return fail("access_craft_computer");
		speed = Const.shipSpeed(engineCount, total);
		return true;
	}

	function checkHull( a : Int, dir : Int ) {
		var b = get(a);
		if( b >= HULL ) return false;
		if( b == 0 ) {
			set(a, AIR);
			return true;
		}
		if( collideBits[b] & dir == 0 ) {
			set(a, AIR);
			return true;
		}
		var bd = Block.all[b];
		if( bd.matter.index != Type.enumIndex(BShipHull) ) {
			set(a, NO_HULL);
			return true;
		}
		set(a, HULL);
		return false;
	}

	inline function setHull( a : Int ) {
		var b = get(a);
		return if( b == 0 || b == AIR || b == HULL ) false else { set(a, HULL); true; };
	}

	function walkRec( a : Int, jump : Int ) {
		while( get(a - DZ) == AIR ) a -= DZ;
		if( get(a) == WALK && get(a + DZ) == WALK ) return;
		set(a, WALK);
		set(a + DZ, WALK);
		if( canWalk(a - DX) ) walkRec(a - DX, 0);
		if( canWalk(a + DX) ) walkRec(a + DX, 0);
		if( canWalk(a - DY) ) walkRec(a - DY, 0);
		if( canWalk(a + DY) ) walkRec(a + DY, 0);
		if( jump < 3 && get(a + DZ * 2) == AIR ) walkRec(a + DZ, jump + 1);
	}

	function canWalk( a : Int ) {
		var b1 = get(a);
		var b2 = get(a + DZ);
		if( b1 == AIR && b2 == AIR ) return true;
		var k1 = Block.all[getBlock(a)];
		var k2 = Block.all[getBlock(a + DZ)];
		var z2 = k1.index == 0 ? 0. : (k1.size == null ? null : k1.size.z2);
		var z1 = k2.index == 0 ? 1. : (k2.size == null ? null : k2.size.z1);
		if( z2 == null || z1 == null ) return false;
		return z1 + 1 - z2 > 1.7;
	}
}
