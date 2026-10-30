import Common;
import Block;

/**
 * Process.hx del original: lo que pasa en el mundo despues de poner o quitar un bloque.
 * - el agua del mar (BTWater) inunda los huecos que se abren a su lado, hacia los lados y hacia abajo, y hacia arriba solo
 *   por debajo del nivel del mar (updateFlood, cada 0,4 s): llena todo, sin capas, como el original;
 * - el agua puesta por el jugador (anadido del port) se extiende como la cascada: cae y da 4 pasos a los lados, cada uno
 *   mas bajo (nivel en World.waterLvl: sin entrada = mar, 9 = puesta, 1..4 = pasos), y se seca sin fuente;
 * - los liquidos con BFPropagate (cascada, lava) caen y se extienden con su bloque de "flujo"; si pierden la fuente,
 *   desaparecen (updatePropagate, cada 0,1 s con un retraso de 2 a 4 pasos);
 * - la hierba se cubre al quedar al aire (covered) y se descubre al taparla (uncover);
 * - al quitar un bloque se rompen los detalles de encima y lo anclado arriba o abajo;
 * - congelador (BFreezer): el agua cercana pasa a hielo y la lava a roca; BFTransform cambia el bloque al quitarlo;
 * - bloques con BFTrack (PTrack: el turbo minero): con el jugador dentro de su radio, la potencia de excavacion pasa a 3;
 * - cada bloque del agua del bioma que se pone aqui cuenta para bajar el nivel del mar (api.processBlock de Process.set, que
 *   en el cliente original hace net/Local.hx); la bajada (World.reduceWater) se hace en la siguiente actualizacion.
 * En el hangar (EditShip) no hay transformaciones (allowTransforms) y los liquidos no se mueven (allowFlow).
 * No se porta lo del servidor: camara compartida.
 */
class WorldProcess {

	var world : World;
	/** rompe un bloque con sus drops (Game.blockBreak con isProcess = true) */
	var breakFn : Int -> Int -> Int -> Block -> Void;
	/** cambio del port: bomba antigua alcanzada por la lava (GameView.lavaBomb); sin el se rompe como con el agua */
	public var lavaBombFn : Int -> Int -> Int -> Block -> Void;
	var flooding : Array<Int> = [];
	var cover : Array<{ x : Int, y : Int, z : Int }> = [];
	var propagate : Array<{ x : Int, y : Int, z : Int, b : Block, t : Int }> = [];
	var time = 0.;
	var frame = 0;
	public var allowTransforms = true;
	/** cambio del port: en el hangar los liquidos no se mueven (en el original no podia entrar ninguno: ni el agua, que no
	    se recoge, ni lo que se propaga, EditShip.checkSelect); los de una nave antigua se quedan quietos */
	public var allowFlow = true;

	public function new( world : World, breakFn ) {
		this.world = world;
		this.breakFn = breakFn;
		initTrack();
	}

	inline function real( p : Int ) : Int {
		var s = world.size;
		return p < 0 ? p + s : (p >= s ? p - s : p);
	}

	inline function get( x : Int, y : Int, z : Int ) : Block {
		return world.block(real(x), real(y), z);
	}

	function set( x : Int, y : Int, z : Int, old : Block, b : Block ) {
		x = real(x);
		y = real(y);
		world.setBlock(x, y, z, b);
		if( b != null && b == world.seaBlock && z < World.SHIP_Z ) world.addFlood();
		onSet(x, y, z, old, b);
	}

	/** Process.update: pasos de 0,1 s. (hx, hy, hz): el jugador a media altura de los ojos (hero.z + viewZ * 0.5) */
	public function update( dt : Float, hx : Float, hy : Float, hz : Float ) {
		// la bajada del mar pedida por addFlood (Local: haxe.Timer.delay(reduceWater, 1))
		if( world.floodFlag ) world.reduceWater();
		time += dt;
		var n = 0;
		while( time >= 0.1 && n < 3 ) {
			time -= 0.1;
			n++;
			frame++;
			if( frame % 4 == 0 ) updateFlood();
			updateCover();
			updatePropagate();
			updateTrack(hx, hy, hz);
		}
		if( time > 0.1 ) time = 0;
	}

	inline function pushFlood( x : Int, y : Int, z : Int ) {
		flooding.push(real(x));
		flooding.push(real(y));
		flooding.push(z);
	}

	/** nivel del agua puesta por el jugador (World.waterLvl) */
	public static inline var PLACED = 9;
	static inline var STEPS = 4;

	inline function isWater( b : Block ) return b != null && b.type == BTWater;

	function updateFlood() {
		if( flooding.length == 0 ) return;
		var wlevel = world.waterLevel();
		var flood = flooding;
		flooding = [];
		var i = 0;
		while( i < flood.length ) {
			var x = flood[i], y = flood[i + 1], z = flood[i + 2];
			i += 3;
			var b = get(x, y, z);
			if( b == null || b.type != BTWater ) continue;
			// el agua puesta por el jugador no inunda: se extiende como la cascada
			if( world.waterLevelAt(x, y, z) != 0 ) {
				pushPlaced(x, y, z, b);
				continue;
			}
			this.flood(real(x - 1), y, z, b);
			this.flood(real(x + 1), y, z, b);
			this.flood(x, real(y - 1), z, b);
			this.flood(x, real(y + 1), z, b);
			if( z < wlevel ) this.flood(x, y, z + 1, b);
			while( z > 1 && this.flood(x, y, --z, b) ) {
			}
		}
	}

	function flood( x : Int, y : Int, z : Int, b : Block ) {
		if( z < 1 || z >= World.HEIGHT - 1 ) return false;
		var b2 = get(x, y, z);
		if( b2 == b ) {
			// agua puesta junto al mar: el mar la llena
			if( world.waterLevelAt(x, y, z) == 0 ) return false;
			world.setWater(real(x), real(y), z, b, 0);
			pushFlood(x, y, z);
			return true;
		}
		if( canPropagate(b, b2) ) {
			if( b2 != null ) breakFn(real(x), real(y), z, b2);
			set(x, y, z, null, b);
			pushFlood(x, y, z);
			return true;
		}
		return false;
	}

	inline function pushPlaced( x : Int, y : Int, z : Int, b : Block ) {
		propagate.push({ x : real(x), y : real(y), z : z, b : b, t : 2 + Std.random(3) });
	}

	/** cambio del port: estos pasos no cuentan para bajar el nivel del mar (en el original el agua puesta inundaba como el mar) */
	function setWater( x : Int, y : Int, z : Int, b : Block, level : Int ) {
		x = real(x);
		y = real(y);
		var old = get(x, y, z);
		if( old != null && old != b ) breakFn(x, y, z, old);
		world.setWater(x, y, z, b, level);
		onSet(x, y, z, null, b);
	}

	/** paso para las reglas de la cascada: el mar y el agua puesta son la fuente (0); -1 si no es esa agua */
	function placedStep( x : Int, y : Int, z : Int, b : Block ) : Int {
		if( get(x, y, z) != b ) return -1;
		var l = world.waterLevelAt(x, y, z);
		return l == PLACED ? 0 : l;
	}

	/** updatePropagate del original aplicado al agua puesta: Fall..Fall4 son los pasos 1..4 (con BFFallCopy al caer) */
	function updatePlaced( x : Int, y : Int, z : Int, b : Block ) {
		var st = placedStep(x, y, z, b);
		if( st < 0 ) return;
		if( st > 0 ) {
			// sin fuente: desaparece (arriba el mismo paso o el anterior; al lado el anterior)
			var keep = false, a = placedStep(x, y, z + 1, b);
			if( a >= 0 && (a == st || a == st - 1) ) keep = true;
			for( d in DIRS ) if( !keep && placedStep(x + d[0], y + d[1], z, b) == st - 1 ) keep = true;
			if( !keep ) {
				set(x, y, z, b, null);
				return;
			}
		}
		// cae: la fuente suelta el paso 1, los pasos caen iguales
		var under = get(x, y, z - 1);
		if( z > 1 && canPropagate(b, under) && !isWater(under) ) {
			setWater(x, y, z - 1, b, st == 0 ? 1 : st);
			return;
		}
		if( isWater(under) ) return; // sobre agua no se extiende (como la cascada: under == b.propagate)
		// a los lados, un paso mas (y mas bajo); reemplaza pasos peores
		var next = st + 1;
		if( next > STEPS ) return;
		for( d in DIRS ) {
			var tx = x + d[0], ty = y + d[1];
			var t = get(tx, ty, z);
			if( !isWater(t) && canPropagate(b, t) )
				setWater(tx, ty, z, b, next);
			else if( t == b ) {
				var ts = placedStep(tx, ty, z, b);
				if( ts > next ) setWater(tx, ty, z, b, next);
			}
		}
	}

	function updateCover() {
		if( cover.length == 0 || Std.random(5) != 0 ) return;
		var c = cover[Std.random(cover.length)];
		cover.remove(c);
		var b = get(c.x, c.y, c.z);
		var over = get(c.x, c.y, c.z + 1);
		if( b != null && b.covered != null && (over == null || over.isTransparent()) )
			set(c.x, c.y, c.z, b, b.covered);
	}

	/** lo que tapa la cascada o la lava se rompe con sus drops (la bomba antigua se suelta, como con el agua). Cambio del
	    port: la lava hace explotar la bomba; el original la rompia como a cualquier bloque reducido */
	function flowBreak( liquid : Block, x : Int, y : Int, z : Int, t : Block ) {
		if( t.k == BArtiBomb && liquid.hasProp(PLava) && lavaBombFn != null ) lavaBombFn(x, y, z, t) else breakFn(x, y, z, t);
	}

	public function canPropagate( b : Block, bt : Block ) {
		return bt == null || (!bt.collide && !b.hasProp(PLiquid)) || (switch( bt.type ) { case BTModel, BTModel2Side, BTReduced: true; default: false; }) || (b.hasProp(PLava) && (bt.hasProp(PLiquid) && !bt.hasProp(PLava)));
	}

	/** Process.onSet: se llama despues de cambiar un bloque del planeta o del hangar (no de la nave) */
	public function onSet( x : Int, y : Int, z : Int, old : Block, b : Block ) {
		if( z >= World.SHIP_Z ) return;
		if( (old != null && old.hasProp(PTrack)) || (b != null && b.hasProp(PTrack)) )
			checkTrack(x, y, z);
		var over = get(x, y, z + 1);
		var under = get(x, y, z - 1);

		checkBroken(x - 1, y, z);
		checkBroken(x + 1, y, z);
		checkBroken(x, y - 1, z);
		checkBroken(x, y + 1, z);
		checkBroken(x, y, z + 1);
		checkBroken(x, y, z - 1);

		if( b == null ) {
			// cubrir si se abre un hueco
			if( under != null && under.covered != null )
				cover.push({ x : x, y : y, z : z - 1 });
			// romper el detalle de encima
			if( over != null && over.hasFlag(BFDetail) ) {
				set(x, y, z + 1, over, null);
				over = null;
			}
			// romper lo anclado
			if( over != null && over.hasAnchor(Down) )
				breakFn(real(x), real(y), z + 1, over);
			if( under != null && under.hasAnchor(Up) )
				breakFn(real(x), real(y), z - 1, under);
		} else {
			// cubrir si se pone bajo un hueco o algo transparente
			if( b.covered != null && (over == null || over.isTransparent()) )
				cover.push({ x : x, y : y, z : z });
			// descubrir el bloque de abajo
			if( under != null && under.uncover != null && !b.isTransparent() )
				set(x, y, z - 1, under, under.uncover);
			if( allowFlow && b.type == BTWater ) {
				if( world.waterLevelAt(x, y, z) != 0 ) pushPlaced(x, y, z, b) else pushFlood(x, y, z);
			}
			else if( allowFlow && b.propagate != null )
				propagate.push({ x : real(x), y : real(y), z : z, b : b, t : 2 + Std.random(3) });
			switch( b.k ) {
			case BFreezer:
				if( allowTransforms ) freeze(x, y, z);
			default:
			}
		}
		if( old != null )
			for( f in old.flags )
				switch( f ) {
				case BFTransform(t, p):
					if( allowTransforms && (p == null || Math.random() < p) )
						set(x, y, z, b, Block.get(t));
				default:
				}
	}

	/** congelador: esfera de radio 4, el liquido pasa a hielo y la lava a roca */
	function freeze( x : Int, y : Int, z : Int ) {
		var ice = Block.get(BIce), lavaRock = Block.get(BLavaRock);
		var d = 4;
		for( dx in -d...d + 1 )
			for( dy in -d...d + 1 )
				for( dz in -d...d + 1 ) {
					var e = (dx / d) * (dx / d) + (dy / d) * (dy / d) + (dz / d) * (dz / d);
					if( e >= 1 ) continue;
					var x = real(x + dx), y = real(y + dy), z = z + dz;
					var b = get(x, y, z);
					if( b == null ) continue;
					if( b.hasProp(PLava) )
						set(x, y, z, b, lavaRock);
					else if( b.hasProp(PLiquid) )
						set(x, y, z, b, ice);
				}
	}

	function checkBroken( x : Int, y : Int, z : Int ) {
		var b = get(x, y, z);
		if( b == null || !allowFlow ) return;
		if( b.type == BTWater )
			pushFlood(x, y, z);
		else if( b.propagate != null )
			propagate.push({ x : real(x), y : real(y), z : z, b : b, t : 2 + Std.random(3) });
	}

	function updatePropagate() {
		var old = propagate;
		if( old.length == 0 ) return;
		propagate = [];
		for( p in old ) {
			if( p.t-- >= 0 ) {
				propagate.push(p);
				continue;
			}
			var x = p.x, y = p.y, z = p.z, b = p.b;
			// sigue ahi?
			if( get(x, y, z) != b ) continue;
			if( b.type == BTWater ) {
				updatePlaced(x, y, z, b);
				continue;
			}
			// sin fuente: desaparece
			var remove = b.hasFlag(BFNoDrop) || b.hasFlag(BFNoPick);
			var other;
			if( remove && (other = get(x, y, z + 1)) != null && (other.propagate == b || other == b) ) remove = false;
			if( remove && (other = get(x - 1, y, z)) != null && other != b && other.propagate == b ) remove = false;
			if( remove && (other = get(x + 1, y, z)) != null && other != b && other.propagate == b ) remove = false;
			if( remove && (other = get(x, y - 1, z)) != null && other != b && other.propagate == b ) remove = false;
			if( remove && (other = get(x, y + 1, z)) != null && other != b && other.propagate == b ) remove = false;
			if( remove ) {
				set(x, y, z, b, null);
				continue;
			}
			// cae
			var under = get(x, y, z - 1);
			if( z > 1 && canPropagate(b, under) ) {
				var tb = b.hasFlag(BFFallCopy) ? b : b.propagate;
				if( under != null ) flowBreak(b, x, y, z - 1, under);
				set(x, y, z - 1, null, tb);
				continue;
			} else if( under == b || under == b.propagate )
				continue;
			// se extiende a los lados
			if( b.propagate == b ) continue;
			for( d in DIRS ) {
				var tx = real(x + d[0]), ty = real(y + d[1]), tz = z;
				var t = get(tx, ty, tz);
				if( canPropagate(b, t) ) {
					if( t != null ) flowBreak(b, tx, ty, tz, t);
					set(tx, ty, tz, null, b.propagate);
				} else {
					var k = b.propagate;
					if( t != k ) {
						k = k.propagate;
						while( k != null ) {
							if( k == t ) {
								set(tx, ty, tz, t, b.propagate);
								break;
							}
							if( k.propagate == k ) break;
							k = k.propagate;
						}
					}
				}
			}
		}
	}

	// ---------------------------------------------------------------- BFTrack (Process.initTrack, updateTrack, checkTrack)

	/** bloques con BFTrack del planeta: celda, bloque, radio y si el jugador esta dentro */
	var tracks : Array<TrackBlock> = [];
	var miningSpeedCount = 0;
	/** potencia de excavacion del jugador (Hero.miningPower): 3 en el radio de algun turbo minero, si no 1. El turbo no se
	    gasta ni se apaga: sirve mientras siga puesto */
	public var miningPower(default, null) = 1.;

	/** radio de un bloque BFTrack (el mayor si tiene varios) */
	static function trackDist( b : Block ) : Int {
		var d = 0;
		for( f in b.flags )
			switch( f ) {
			case BFTrack(_, r): if( r > d ) d = r;
			default:
			}
		return d;
	}

	/**
	 * Process.initTrack/onInitLevel: el original buscaba los BFTrack en las celdas de cada trozo al cargarlo. El generador no
	 * pone ninguno, asi que basta con mirar los cambios del jugador (World.editMap) en vez de recorrer todo el planeta.
	 */
	function initTrack() {
		var size = world.size;
		for( key in world.editMap.keys() ) {
			var gi : Int = world.editMap.get(key);
			gi &= 0xFFFF; // sin el nivel del agua
			if( gi == 0 ) continue;
			var b = Block.all[gi];
			if( b == null || !b.hasProp(PTrack) ) continue;
			var c = key >> World.ZBITS;
			tracks.push({ x : c % size, y : Std.int(c / size), z : key & (World.HEIGHT - 1), b : b, dist : trackDist(b), on : false });
		}
	}

	/** Process.checkTrack: alta o baja del bloque BFTrack de una celda que acaba de cambiar */
	function checkTrack( x : Int, y : Int, z : Int ) {
		x = real(x);
		y = real(y);
		for( t in tracks )
			if( t.x == x && t.y == y && t.z == z ) {
				setTrack(t, false);
				tracks.remove(t);
				break;
			}
		var b = get(x, y, z);
		if( b != null && b.hasProp(PTrack) )
			tracks.push({ x : x, y : y, z : z, b : b, dist : trackDist(b), on : false });
	}

	/** Process.updateTrack: quita los que ya no estan y mira si el jugador esta a menos de su radio del centro del bloque */
	function updateTrack( hx : Float, hy : Float, hz : Float ) {
		if( tracks.length == 0 ) return;
		for( t in tracks.copy() )
			if( get(t.x, t.y, t.z) != t.b ) {
				setTrack(t, false);
				tracks.remove(t);
			}
		var s = world.size;
		inline function realDist( d : Float ) return d > s * 0.5 ? d - s : (d < -s * 0.5 ? d + s : d);
		// menos 0,5: la distancia es al centro del bloque. Cambio del port: la altura no da la vuelta (el original tambien le
		// aplicaba realDist, y en un planeta pequeno un turbo en el fondo contaria desde la nave)
		var x = hx - 0.5, y = hy - 0.5, z = hz - 0.5;
		for( t in tracks ) {
			var dx = realDist(t.x - x), dy = realDist(t.y - y), dz = t.z - z;
			setTrack(t, dx * dx + dy * dy + dz * dz < t.dist * t.dist);
		}
	}

	/** Process.activateTrack + trackEffect: el jugador entra en el radio de un bloque BFTrack o sale de el */
	function setTrack( t : TrackBlock, on : Bool ) {
		if( t.on == on ) return;
		t.on = on;
		for( f in t.b.flags )
			switch( f ) {
			case BFTrack(TMiningSpeed, _):
				miningSpeedCount += on ? 1 : -1;
				miningPower = miningSpeedCount <= 0 ? 1 : 3;
			default:
			}
	}

	static var DIRS = [[-1, 0], [1, 0], [0, 1], [0, -1]];
}

private typedef TrackBlock = { x : Int, y : Int, z : Int, b : Block, dist : Int, on : Bool };
