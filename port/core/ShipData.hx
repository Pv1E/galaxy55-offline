import Common;

typedef ShipCell = { var x : Int; var y : Int; var z : Int; var id : Int; }

/**
 * Zona de un sintetizador (CraftPoint): el hueco libre sobre un grupo de losas de ensamblaje (BCrafter). Es la unica parte de la nave
 * donde se pueden poner y quitar bloques. (x, y, z) es la esquina de abajo (encima de la losa), w x h su base y heights la altura libre
 * de cada columna.
 */
class CraftArea {
	public var x : Int;
	public var y : Int;
	public var z : Int;
	public var w = 1;
	public var h = 1;
	public var zSize = 0;
	public var heights : Array<Array<Int>>;
	/** celda del ordenador del sintetizador (BCrafterComputer) que le toca */
	public var out : { x : Int, y : Int, z : Int };
	/** estado del sintetizador (CraftPoint): receta reconocida, texto de la lista y bloque de vista previa */
	public var engine = new CraftEngine();
	public var curCraft : CraftRule;
	public var curText : String;
	/** bloque suelto de vista previa (Drops.Drop del juego; Dynamic para que los datos no dependan del dibujo) */
	public var preview : Dynamic;

	public function new( x : Int, y : Int, z : Int ) {
		this.x = x;
		this.y = y;
		this.z = z;
	}

	public function inside( rx : Int, ry : Int, rz : Int ) : Bool {
		return rx >= x && ry >= y && rz >= z && rx < x + w && ry < y + h && rz < z + heights[rx - x][ry - y];
	}
}

typedef ShipDataInfo = {
	var crafts : Array<CraftArea>;
	/** tamano de la nave en bloques */
	var sx : Int;
	var sy : Int;
	var sz : Int;
	/** bloques ya colocados dentro del volumen de 128x128x128 de la nave (centrados, 1 de margen abajo), como ShipLogic.init */
	var cells : Array<ShipCell>;
	/** celda del teletransportador (BShipEntry) en ese volumen; el jugador aparece encima */
	var entry : { x : Int, y : Int, z : Int };
}

/** Datos de una nave: bytes comprimidos con zlib = sx, sy, sz y, por cada y, x, z, el indice del bloque en 2 bytes. */
class ShipData {

	/** plano de la nave de la partida (SaveInfo.shipData, editado en el hangar) o la de siempre (antes Hangar.currentShip) */
	public static function current( info : SaveData.SaveInfo ) : haxe.io.Bytes {
		if( info != null && info.shipData != null )
			try return haxe.crypto.Base64.decode(info.shipData) catch( e : Dynamic ) {}
		return Const.DEFAULT_SHIP;
	}

	public static function load( compressed : haxe.io.Bytes ) : ShipDataInfo {
		var raw = haxe.zip.Uncompress.run(compressed);
		var sx = raw.get(0), sy = raw.get(1), sz = raw.get(2);
		var dx = (Const.SIZE - sx) >> 1, dy = (Const.SIZE - sy) >> 1, dz = 1;
		var cells = [];
		var entry = null;
		var cinfos = new Array<CraftArea>();
		var cout = [];
		var pos = 3;
		for( y in 0...sy )
			for( x in 0...sx )
				for( z in 0...sz ) {
					var bid = raw.get(pos) | (raw.get(pos + 1) << 8);
					if( bid != 0 ) {
						var c = { x : x + dx, y : y + dy, z : z + dz, id : bid };
						cells.push(c);
						if( bid == Type.enumIndex(BShipEntry) ) entry = { x : c.x, y : c.y, z : c.z };
						else if( bid == Type.enumIndex(BCrafter) ) {
							// losa de ensamblaje: la zona libre que tiene encima (hasta chocar con algo o con el techo de la nave)
							var ca = new CraftArea(x + dx, y + dy, z + dz + 1);
							var pp = pos + 2;
							while( z + ca.zSize + 1 < sz && raw.get(pp) == 0 && raw.get(pp + 1) == 0 ) {
								ca.zSize++;
								pp += 2;
							}
							cinfos[x + y * sx + z * sx * sy] = ca;
						} else if( bid == Type.enumIndex(BCrafterComputer) )
							cout.push({ x : x + dx, y : y + dy, z : z + dz });
					}
					pos += 2;
				}
		var crafts = groupCrafts(cinfos, sx, sy, sz);
		// cada zona toma el ordenador de sintetizador mas cercano (ShipLogic.init)
		for( c in crafts ) {
			var dm = -1., best = null;
			for( o in cout ) {
				var ddx = Math.abs(c.x + c.w * 0.5 - o.x), ddy = Math.abs(c.y + c.h * 0.5 - o.y), ddz = Math.abs(c.z + 0.5 - o.z) * 0.5;
				var d = Math.sqrt(ddx * ddx + ddy * ddy + ddz * ddz);
				if( d < dm || best == null ) {
					dm = d;
					best = o;
				}
			}
			if( best == null ) continue;
			cout.remove(best);
			c.out = best;
		}
		return { sx : sx, sy : sy, sz : sz, cells : cells, entry : entry, crafts : crafts };
	}

	/** une las losas vecinas en zonas rectangulares (ShipLogic.init: "calculate craft points sizes") */
	static function groupCrafts( cinfos : Array<CraftArea>, sx : Int, sy : Int, sz : Int ) : Array<CraftArea> {
		var crafts = [];
		var pos = 0;
		for( z in 0...sz )
			for( y in 0...sy )
				for( x in 0...sx ) {
					var c = cinfos[pos];
					if( c == null ) {
						pos++;
						continue;
					}
					var zs = c.zSize;
					c.heights = [[zs]];
					while( true ) {
						var changed = false;
						var found = true;
						for( dy in 0...c.h )
							if( cinfos[pos + c.w + dy * sx] == null ) {
								found = false;
								break;
							}
						if( found ) {
							c.heights.push([]);
							for( dy in 0...c.h ) {
								var c2 = cinfos[pos + c.w + dy * sx];
								if( c2.zSize < zs ) zs = c2.zSize;
								c.heights[c.w][dy] = c2.zSize;
								cinfos[pos + c.w + dy * sx] = null;
							}
							c.w++;
							changed = true;
						}
						found = true;
						for( dx in 0...c.w )
							if( cinfos[pos + c.h * sx + dx] == null ) {
								found = false;
								break;
							}
						if( found ) {
							for( dx in 0...c.w ) {
								var c2 = cinfos[pos + c.h * sx + dx];
								if( c2.zSize < zs ) zs = c2.zSize;
								c.heights[dx][c.h] = c2.zSize;
								cinfos[pos + c.h * sx + dx] = null;
							}
							c.h++;
							changed = true;
						}
						if( !changed ) break;
					}
					c.zSize = zs;
					crafts.push(c);
					pos++;
				}
		return crafts;
	}

	/** bloque de la nave tal como se guarda: una puerta abierta vuelve cerrada al rehacer la nave (Hangar.shipId; tambien ServerShip) */
	public static function shipId( b : Block ) : Int {
		if( b == null ) return 0;
		return switch( b.k ) {
			case BShipDoorOpen, BShipDoorYOpen: b.toggle.index;
			default: b.index;
		}
	}
}
