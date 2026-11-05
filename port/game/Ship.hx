import Common;

/**
 * La nave del jugador (ShipLogic del original). Es un volumen de bloques colgado sobre el planeta, desde z = 130, centrado sobre el
 * punto de aterrizaje. Se baja al planeta pisando el teletransportador (BShipEntry) y se vuelve entrando en el haz de luz que marca
 * el punto de aterrizaje.
 */
class Ship {

	/** aterrizaje en el planeta */
	public var x(default, null) : Int;
	public var y(default, null) : Int;
	/** altura del suelo en el punto de aterrizaje (ShipLogic.z): base del rayo, donde se aparece al bajar */
	public var z(default, null) = 0.;
	/** posicion del jugador al aparecer en la nave (encima del teletransportador), en coordenadas del planeta */
	public var start(default, null) : { x : Int, y : Int, z : Int };
	public var world(default, null) : World;
	/** zonas de los sintetizadores: lo unico de la nave donde se pueden poner y quitar bloques */
	public var crafts(default, null) : Array<ShipData.CraftArea>;

	/** true si la posicion (en coordenadas del planeta) esta en la zona libre sobre una losa de ensamblaje (CraftPoint.inside) */
	public function inCraft( wx : Int, wy : Int, wz : Int ) : Bool {
		if( wz < World.SHIP_Z ) return false;
		var s = planet.size;
		var lx = (wx - planet.shipDX) % s, ly = (wy - planet.shipDY) % s;
		if( lx < 0 ) lx += s;
		if( ly < 0 ) ly += s;
		var lz = wz - World.SHIP_Z;
		for( c in crafts )
			if( c.inside(lx, ly, lz) ) return true;
		return false;
	}

	var planet : World;
	var beam : h3d.scene.Mesh;
	var beamUv : h3d.shader.UVDelta;
	var beamFog : Sky.FogShader;
	var beamMat : h3d.mat.Material;
	var time = 0.;
	var needRecal = true;
	/** la nave de la partida (la del hangar o la de serie): las imagenes del mapa se centran en ella */
	var data : ShipData.ShipDataInfo;
	/** desplazamiento de la nave mientras se pilota (con decimales; planet.shipDX/shipDY son su redondeo) */
	var fx = 0.;
	var fy = 0.;
	/** true si el jugador la ha pilotado a otro sitio de este planeta (anadido del port): ese sitio se guarda */
	public var moved(default, null) = false;
	/** copia del planeta en la que se dibuja la nave (vueltas enteras, updateWrap) */
	var wrapX = 0.;
	var wrapY = 0.;
	/** centro de la nave (media de sus bloques), en coordenadas de la nave: con el se elige esa copia */
	var midX = 0.;
	var midY = 0.;

	/**
	 * El mundo de la nave sin construir (anadido del port), para la pantalla de carga: lo construye poco a poco (World.step)
	 * mientras se carga el planeta y luego se lo da a new Ship (ready). Construirlo de golpe al llegar al planeta (la luz y los
	 * 64 trozos de la nave) alargaba la imagen de la llegada
	 */
	public static function prepare( planet : World, atlas : h3d.mat.Texture, parent : h3d.scene.Object, ?edits : Array<Int>, ?shipBytes : haxe.io.Bytes ) : World {
		var w = makeWorld(planet, atlas, parent, edits, ShipData.load(shipBytes != null ? shipBytes : Const.DEFAULT_SHIP));
		// no se dibuja hasta la llegada (new Ship)
		w.root.visible = false;
		return w;
	}

	static function makeWorld( planet : World, atlas : h3d.mat.Texture, parent : h3d.scene.Object, edits : Array<Int>, data : ShipData.ShipDataInfo ) : World {
		// cambio del port: una puerta abierta a bordo vuelve cerrada al rehacer la nave (cargar, viajar, volver del hangar), como en
		// el original, que no guardaba los cambios de la nave (ShipLogic.init). Las claves negativas son del mar, no bloques
		if( edits != null )
			edits = [for( i in 0...edits.length ) i & 1 == 1 && edits[i - 1] >= 0 ? Hangar.shipId(Block.all[edits[i] & 0xFFFF]) | (edits[i] & ~0xFFFF) : edits[i]];
		return new World(planet.seed, planet.biomeName, 1, parent, atlas, false, edits, data, planet.sky);
	}

	/** ready: su mundo, de Ship.prepare con los mismos edits y shipBytes (si no, se construye aqui) */
	public function new( planet : World, atlas : h3d.mat.Texture, parent : h3d.scene.Object, ?edits : Array<Int>, ?shipBytes : haxe.io.Bytes, ?at : { x : Int, y : Int }, ?ready : World ) {
		this.planet = planet;
		data = ShipData.load(shipBytes != null ? shipBytes : Const.DEFAULT_SHIP);
		crafts = data.crafts;
		for( c in data.cells ) {
			midX += c.x + 0.5;
			midY += c.y + 0.5;
		}
		if( data.cells.length > 0 ) {
			midX /= data.cells.length;
			midY /= data.cells.length;
		}
		// el sitio de aterrizaje es fijo para cada planeta (misma semilla = mismo sitio), como en Game.placeShip; anadido del port:
		// si el jugador la ha pilotado a otro sitio (at), aparece alli
		var p = planet.shipPlace();
		x = p != null ? p.x : 14;
		y = p != null ? p.y : 12;
		if( at != null ) {
			var s = planet.size;
			x = ((at.x % s) + s) % s;
			y = ((at.y % s) + s) % s;
			moved = true;
		}
		start = { x : data.entry.x, y : data.entry.y, z : data.entry.z + 1 + World.SHIP_Z };
		var dx = x - start.x, dy = y - start.y;
		world = ready != null ? ready : makeWorld(planet, atlas, parent, edits, data);
		// la ya construida pasa al final de la escena, donde quedaba al crearla aqui (despues de la mano, los objetos sueltos y las
		// particulas): el orden de dibujo no cambia
		parent.addChild(world.root);
		world.root.visible = true;
		var guard = 0;
		while( !world.isReady() && guard++ < 1000 ) world.step(1000);
		// el ordenador de la nave no se puede perder (sin el no hay mapa ni hangar): si una partida lo tiene roto, vuelve
		for( c in data.cells ) {
			var b = Block.all[c.id];
			if( b != null && b.k == BShipComputer && world.block(c.x, c.y, c.z) == null ) world.setBlock(c.x, c.y, c.z, b);
		}
		planet.ship = world;
		planet.shipDX = dx;
		planet.shipDY = dy;
		fx = dx;
		fy = dy;
		world.root.setPosition(dx, dy, World.SHIP_Z);
		// el punto de aparicion del jugador, ya en coordenadas del planeta
		start = { x : x, y : y, z : start.z };
		// cambio del port: el rayo se recalcula con cualquier cambio en su columna (poner, romper, agua, procesos); el original solo
		// al romper un bloque de esa columna (Game.blockBreak) y al cargar su trozo
		planet.onSetBlock = function( cx, cy, cz ) if( cx == x && cy == y ) needRecal = true;
		recalDock();
		buildBeam(planet);
	}

	/**
	 * Altura del suelo bajo la nave (ShipLogic.update: needRecal): encima del bloque mas alto de la columna que tenga colision.
	 * El agua, la lava y las plantas no tienen: con liquido encima el rayo baja hasta el fondo.
	 */
	public function recalDock() {
		z = groundAt(x, y);
		needRecal = false;
		beamX = x;
		beamY = y;
		beamZ = z;
		updateBeam();
	}

	/** base del rayo en una columna del planeta: encima de su bloque mas alto con colision */
	function groundAt( cx : Int, cy : Int ) : Float {
		var zz = World.HEIGHT - 1;
		while( zz > 0 && !planet.collidePoint(cx + 0.5, cy + 0.5, zz) ) zz--;
		// cambio del port: sobre un bloque bajo (placa, cofre) la base es su cara de arriba; el original la ponia un bloque encima
		// y desde la placa ya no se podia volver a la nave
		var b = planet.block(cx, cy, zz);
		return zz + (b != null && b.size != null ? b.size.z2 : 1);
	}

	// ---------------------------------------------------------------- haz de luz del punto de aterrizaje

	function buildBeam( planet : World ) {
		var segs = 6;
		var pts = [], uvs = [], idx = new hxd.IndexBuffer();
		for( i in 0...segs ) {
			var a0 = i * Math.PI * 2 / segs, a1 = (i + 1) * Math.PI * 2 / segs;
			var r = 0.48;
			var b = pts.length;
			pts.push(new h3d.col.Point(Math.cos(a0) * r, Math.sin(a0) * r, 0));
			pts.push(new h3d.col.Point(Math.cos(a1) * r, Math.sin(a1) * r, 0));
			pts.push(new h3d.col.Point(Math.cos(a1) * r, Math.sin(a1) * r, 1));
			pts.push(new h3d.col.Point(Math.cos(a0) * r, Math.sin(a0) * r, 1));
			uvs.push(new h3d.prim.UV(i / segs, 1));
			uvs.push(new h3d.prim.UV((i + 1) / segs, 1));
			uvs.push(new h3d.prim.UV((i + 1) / segs, 0));
			uvs.push(new h3d.prim.UV(i / segs, 0));
			idx.push(b); idx.push(b + 1); idx.push(b + 2);
			idx.push(b); idx.push(b + 2); idx.push(b + 3);
		}
		var poly = new h3d.prim.Polygon(pts, idx);
		poly.addNormals(); // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
		poly.uvs = uvs;
		var tex = hxd.res.Any.fromBytes("ship_halo.png", Res.bytes("ship_halo.png")).toTexture();
		tex.wrap = Repeat;
		tex.filter = Linear;
		var mat = h3d.mat.Material.create(tex);
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		mat.blendMode = Add;
		mat.mainPass.depthWrite = false;
		mat.mainPass.setPassName("alpha");
		mat.color.set(1, 1, 1, 0.5);
		beamMat = mat;
		beamUv = new h3d.shader.UVDelta();
		beamUv.uvScale.set(segs / 3, 1);
		mat.mainPass.addShader(beamUv);
		// el original no le pone niebla (PolyTexShader): solo la curva del planeta
		beamFog = new Sky.FogShader();
		beamFog.fogK = 0;
		mat.mainPass.addShader(beamFog);
		beam = new h3d.scene.Mesh(poly, mat, planet.root);
		updateBeam();
	}

	/** columna y base del rayo: el punto de aterrizaje o, pilotando (anadido del port), donde aterrizaria la nave ahora */
	var beamX = 0;
	var beamY = 0;
	var beamZ = 0.;

	function updateBeam() {
		if( beam == null ) return;
		var h = start.z - beamZ;
		beam.setPosition(beamX + 0.5, beamY + 0.5, beamZ);
		beam.scaleZ = h > 0 ? h : 0.01;
	}

	// ---------------------------------------------------------------- pilotar la nave sobre el planeta (anadido del port)

	/** rumbo de la nave pilotada (0 = como aterriza, con el morro hacia +x, como la dibuja el mapa) e inclinacion lateral al girar.
	    Solo se ve: los bloques, la colision y el guardado siguen en la orientacion de siempre, que recupera al aterrizar */
	public var heading(default, null) = 0.;
	var roll = 0.;
	var poseQ = new h3d.Quat();

	/** centro de la nave (media de sus bloques), en coordenadas del planeta y girado con el rumbo: la camara de pilotar mira ahi */
	public function center() : { x : Float, y : Float, z : Float } {
		var gx = 0., gy = 0., gz = 0.;
		for( c in data.cells ) {
			gx += c.x;
			gy += c.y;
			gz += c.z;
		}
		var n = data.cells.length > 0 ? data.cells.length : 1;
		// alrededor de la entrada, como el giro (setPose)
		var ox = 0.5 + gx / n - (data.entry.x + 0.5), oy = 0.5 + gy / n - (data.entry.y + 0.5);
		var c = Math.cos(heading), s = Math.sin(heading);
		return { x : fx + wrapX + data.entry.x + 0.5 + ox * c - oy * s, y : fy + wrapY + data.entry.y + 0.5 + ox * s + oy * c, z : 0.5 + gz / n + World.SHIP_Z };
	}

	/** pilotando (anadido del port): el rayo se ve con esta fuerza (0 = oculto, 1 = como siempre) */
	public function setBeamFade( f : Float ) {
		if( beam == null ) return;
		beam.visible = f > 0.01;
		beamMat.color.a = 0.5 * f;
	}

	/** gira la nave (solo la imagen) sobre la columna de su entrada: el rayo sigue debajo del teletransportador */
	public function setPose( heading : Float, roll : Float ) {
		this.heading = heading;
		this.roll = roll;
		placeRoot();
	}

	/**
	 * Cambio del port: la nave se dibuja en la copia del planeta mas cercana al jugador, como cada trozo del terreno (World.updateWrap)
	 * y el rayo (update). Si no, al cruzar el borde del mundo dentro de la nave (GameView.clampPos lleva la x de size a 0) se quedaba a
	 * una vuelta entera y solo se veia el cielo; pilotando desde ese lado, la camara (center) y el planeta quedaban en copias distintas.
	 * Los bloques y la colision no cambian: el planeta los busca con el modulo de su tamano (World.shipLocal).
	 */
	public function updateWrap( px : Float, py : Float ) {
		var s = planet.size;
		var ox = s * Math.round((px - fx - midX) / s), oy = s * Math.round((py - fy - midY) / s);
		if( ox == wrapX && oy == wrapY ) return;
		wrapX = ox;
		wrapY = oy;
		placeRoot();
	}

	function placeRoot() {
		var r = world.root;
		if( heading == 0 && roll == 0 ) {
			r.setRotation(0, 0, 0);
			r.setPosition(fx + wrapX, fy + wrapY, World.SHIP_Z);
			return;
		}
		var q = poseQ;
		q.initRotateAxis(0, 0, 1, heading);
		if( roll != 0 ) {
			var qr = new h3d.Quat();
			qr.initRotateAxis(1, 0, 0, roll);
			q.multiply(q, qr);
		}
		r.setRotationQuat(q);
		// la entrada (pivote) se queda donde estaba: posicion = desplazamiento + pivote - pivote girado
		var p = new h3d.Vector(data.entry.x + 0.5, data.entry.y + 0.5, data.entry.z + 1);
		var rp = p.transformed3x3(q.toMatrix());
		r.setPosition(fx + wrapX + p.x - rp.x, fy + wrapY + p.y - rp.y, World.SHIP_Z + p.z - rp.z);
	}

	/** desplaza la nave (dx, dy) sobre el planeta, a la misma altura; el rayo marca donde aterrizaria si se deja ahora */
	public function slide( dx : Float, dy : Float ) {
		fx += dx;
		fy += dy;
		planet.shipDX = Math.round(fx);
		planet.shipDY = Math.round(fy);
		placeRoot();
		var p = landingSpot();
		if( p.x != beamX || p.y != beamY ) {
			beamX = p.x;
			beamY = p.y;
			beamZ = groundAt(p.x, p.y);
			updateBeam();
		}
	}

	/**
	 * Lo que falta mover para dejar la nave en una celda entera, con el punto de aterrizaje dentro del planeta (0..size-1).
	 * El planeta da la vuelta: la vuelta entera (k * size) no cambia lo que se ve, solo deja las coordenadas en su rango.
	 */
	public function snapDelta() : { dx : Float, dy : Float } {
		var s = planet.size;
		var rx = Math.round(fx), ry = Math.round(fy);
		var lx = rx + data.entry.x, ly = ry + data.entry.y; // punto de aterrizaje: encima esta la entrada de la nave
		var nx = lx % s, ny = ly % s;
		if( nx < 0 ) nx += s;
		if( ny < 0 ) ny += s;
		return { dx : rx - fx + (nx - lx), dy : ry - fy + (ny - ly) };
	}

	/** lo que falta para que la nave quede en una celda entera (sin la vuelta entera del planeta): el aterrizaje se centra con esto */
	public function cellDelta() : { dx : Float, dy : Float } {
		return { dx : Math.round(fx) - fx, dy : Math.round(fy) - fy };
	}

	/** punto de aterrizaje en que quedaria la nave si se aterriza ahora (para guardar a mitad del vuelo) */
	public function landingSpot() : { x : Int, y : Int } {
		var d = snapDelta();
		return { x : Math.round(fx + d.dx) + data.entry.x, y : Math.round(fy + d.dy) + data.entry.y };
	}

	/** deja la nave en una celda entera y baja el rayo alli; devuelve lo que se ha movido en este ultimo paso */
	public function land() : { dx : Float, dy : Float } {
		var d = snapDelta();
		heading = roll = 0; // vuelve a su orientacion de siempre (GameView la lleva poco a poco antes de llamar a land)
		slide(d.dx, d.dy);
		x = planet.shipDX + data.entry.x;
		y = planet.shipDY + data.entry.y;
		start = { x : x, y : y, z : start.z };
		moved = true;
		recalDock();
		return d;
	}

	public function dispose() {
		if( beam != null ) beam.remove();
		beam = null;
		planet.onSetBlock = null;
	}

	// ---------------------------------------------------------------- teletransporte y vida a bordo (ShipLogic.update)

	public function update( g : GameView, tmod : Float ) {
		time += tmod;
		world.flush();
		if( needRecal && !g.piloting ) recalDock(); // pilotando, el rayo marca otra columna (slide); al aterrizar se recalcula
		beamUv.uvDelta.set(time / 100, 0);

		var s = planet.size;
		var ddx = g.wrapDist(x + 0.5 - g.px), ddy = g.wrapDist(y + 0.5 - g.py);
		// Render.viewX/viewY: el rayo se dibuja en la copia del planeta mas cercana al jugador
		if( beam != null ) {
			beamFog.curve = planet.sky.fog.curve;
			beam.x = g.px + g.wrapDist(beamX + 0.5 - g.px);
			beam.y = g.py + g.wrapDist(beamY + 0.5 - g.py);
		}
		var d = Math.sqrt(ddx * ddx + ddy * ddy);
		var onShipEntry = g.pz > Const.SIZE && g.standingBlock == Block.all[Type.enumIndex(BShipEntry)];
		// cambio del port: desde el planeta solo se sube de pie a la altura de la base del rayo (g.pz < z + 1); el original valia
		// cualquier altura por encima (g.pz <= Const.SIZE), p. ej. el borde de un hoyo cavado bajo la nave, a menos de 0.6 del centro
		// cometa con el tiempo acabado (Comets, añadido del port): el teletransportador de a bordo ya no baja; desde abajo se sube
		var beamOff = onShipEntry && g.cometOver();
		if( !beamOff && d < 0.6 && g.pz >= z && (g.pz < z + 1 || onShipEntry) ) {
			if( g.enteringShip >= 0 && g.standingBlock != null ) {
				g.enteringShip += tmod * 0.05;
				if( g.enteringShip >= 1.5 ) g.gotoShip(!onShipEntry);
			}
		} else {
			g.enteringShip -= tmod * 0.1;
			if( g.enteringShip < 0 ) g.enteringShip = 0;
		}

		// ShipLogic.checkHero: de pie en la nave se recupera vida; se suma a la de las plantas y cajas de curacion (GameView.updateLife)
		if( g.pz >= World.SHIP_Z && g.standingBlock != null ) {
			g.life += tmod * 0.05;
			if( g.life > 100 ) g.life = 100;
		}
	}

	// ---------------------------------------------------------------- sintetizador (ShipLogic.craft / activateBlock)

	/** zona de sintetizador que contiene esa posicion del planeta, con la posicion relativa a la zona */
	function areaAt( wx : Int, wy : Int, wz : Int ) : { c : ShipData.CraftArea, x : Int, y : Int, z : Int } {
		if( wz < World.SHIP_Z ) return null;
		var s = planet.size;
		var lx = (wx - planet.shipDX) % s, ly = (wy - planet.shipDY) % s;
		if( lx < 0 ) lx += s;
		if( ly < 0 ) ly += s;
		var lz = wz - World.SHIP_Z;
		for( c in crafts )
			if( c.inside(lx, ly, lz) ) return { c : c, x : lx, y : ly, z : lz };
		return null;
	}

	/** al cargar una partida: los bloques que ya hay en las zonas vuelven a contar para el sintetizador */
	public function initCrafts( g : GameView ) {
		for( c in crafts ) {
			for( dx in 0...c.w )
				for( dy in 0...c.h )
					for( dz in 0...c.heights[dx][dy] ) {
						var b = world.block(c.x + dx, c.y + dy, c.z + dz);
						if( b != null ) c.engine.add(b, dx, dy, dz);
					}
			checkCraft(c, g);
		}
	}

	/** se ha puesto (b) o quitado (null) un bloque en el planeta: si cae en una zona, el sintetizador lo recuerda */
	public function craft( wx : Int, wy : Int, wz : Int, b : Block, g : GameView ) {
		var a = areaAt(wx, wy, wz);
		if( a == null ) return;
		a.c.engine.remove(a.x - a.c.x, a.y - a.c.y, a.z - a.c.z);
		if( b != null ) a.c.engine.add(b, a.x - a.c.x, a.y - a.c.y, a.z - a.c.z);
		checkCraft(a.c, g);
	}

	function outPos( c : ShipData.CraftArea ) {
		return { x : c.out.x + planet.shipDX + 0.5, y : c.out.y + planet.shipDY + 0.5, z : c.out.z + World.SHIP_Z + 0.25 };
	}

	function checkCraft( c : ShipData.CraftArea, g : GameView ) {
		var r = c.engine.checkAll();
		// tutorial: solo el aluminio y el blindaje que pide (Tutorial.craftAllowed); lo demas no se fabrica y la zona lo dice en rojo
		var refused = r != null && !Tutorial.craftAllowed(g.info, r);
		if( refused ) r = null;
		c.curCraft = r;
		if( c.preview != null ) {
			g.drops.remove(c.preview);
			c.preview = null;
		}
		if( r != null && c.out != null ) {
			var p = outPos(c);
			var d = g.drops.add(p.x, p.y, p.z, Block.get(r.out));
			d.fixed = true;
			d.active = false;
			c.preview = d;
		}
		var text = [];
		var bl = c.engine.getBlocks(false);
		for( b in bl ) text.push(b.n + "x " + b.b.getName());
		if( bl.length > 0 )
			text.push(" = " + (refused ? TutoText.get("craftonly") : r != null ? (r.count != null && r.count > 1 ? r.count + " x " : "") + Block.get(r.out).getName() : Lang.t("craft.norecipe")));
		c.curText = text.length == 0 ? null : text.join("
");
	}

	/** texto de las recetas cercanas (ShipLogic.checkHero); null si no hay ninguna cerca */
	public function message( g : GameView ) : String {
		if( g.pz < World.SHIP_Z ) return null;
		for( c in crafts ) {
			if( c.curText == null ) continue;
			var dx = g.wrapDist(c.x + planet.shipDX + c.w * 0.5 - g.px);
			var dy = g.wrapDist(c.y + planet.shipDY + c.h * 0.5 - g.py);
			var dz = c.z + World.SHIP_Z - g.pz;
			if( Math.sqrt(dx * dx + dy * dy + dz * dz) < Math.max(c.w, c.h) * 0.5 + 3 ) {
				g.messageRed = c.curCraft == null;
				return c.curText;
			}
		}
		return null;
	}

	/** ordenador del sintetizador: fabrica la receta con los bloques del inventario o, si faltan, con los puestos en la zona */
	public function activateCraft( wx : Int, wy : Int, wz : Int, g : GameView ) {
		var s = planet.size;
		var lx = (wx - planet.shipDX) % s, ly = (wy - planet.shipDY) % s;
		if( lx < 0 ) lx += s;
		if( ly < 0 ) ly += s;
		var lz = wz - World.SHIP_Z;
		var c : ShipData.CraftArea = null;
		for( cc in crafts )
			if( cc.out != null && cc.out.x == lx && cc.out.y == ly && cc.out.z == lz ) {
				c = cc;
				break;
			}
		if( c == null ) return;
		// lo puesto en la zona se mira otra vez: el tutorial puede haber acabado con una receta rechazada en ella
		checkCraft(c, g);
		if( c.curCraft == null ) return;
		var cur = c.curCraft;
		var blocks = c.engine.getBlocks(true);
		// ShipLogic.activateBlock (hasInv): si el inventario tiene todos los bloques de la receta se gastan esos y la zona queda
		// como plantilla para fabricar otra vez; si falta alguno se gastan los puestos en la zona. Nunca se mezclan las dos fuentes.
		// Se gasta antes de soltar el resultado: si algo no cuadra no se fabrica nada (sin duplicar).
		var fromInv = true;
		for( b in blocks )
			if( !g.inv.hasBlocks(b.b, b.n) ) fromInv = false;
		if( fromInv ) {
			for( b in blocks )
				if( !g.inv.useBlocks(b.b, b.n) ) return;
		} else {
			c.engine.clear();
			g.drops.remove(c.preview);
			c.preview = null;
			c.curCraft = null;
			c.curText = null;
			for( b in blocks )
				for( q in b.pos ) {
					var x = c.x + q.x + planet.shipDX, y = c.y + q.y + planet.shipDY, z = c.z + q.z + World.SHIP_Z;
					g.removeShipBlock(x, y, z, b.b);
				}
		}
		var out = Block.get(cur.out);
		var n = cur.count != null ? cur.count : 1;
		Kubindex.crafted(g.info, cur);
		var p = outPos(c);
		for( i in 0...n ) {
			var d = g.drops.add(p.x, p.y, p.z, out);
			d.delay = 30;
		}
	}

	// ---------------------------------------------------------------- imagenes de la nave para el mapa (r3d.Capture)

	/**
	 * Renderiza la nave desde arriba (camara a 35 de altura, inclinacion 0.5) en `angles` direcciones y devuelve un BitmapData por
	 * fotograma, con el contraste y el contorno negro del original. Solo se ve la nave: el resto de la escena se oculta un momento.
	 */
	public function captureFrames( engine : h3d.Engine, s3d : h3d.scene.Scene, size = 192, angles = 32 ) : Array<flash.display.BitmapData> {
		var gx = 0., gy = 0.;
		for( c in data.cells ) {
			gx += c.x;
			gy += c.y;
		}
		var cx = 0.5 + gx / data.cells.length + planet.shipDX + wrapX, cy = 0.5 + gy / data.cells.length + planet.shipDY + wrapY;
		var baseZ = World.SHIP_Z + 1;
		var height = 35.;
		var incli = 0.5;
		var delta = Math.sin(incli) * height;

		// ocultar todo menos la nave; sin niebla ni curvatura
		var hidden = [];
		for( i in 0...s3d.numChildren ) {
			var o = s3d.getChildAt(i);
			if( o != world.root && o.visible ) {
				hidden.push(o);
				o.visible = false;
			}
		}
		var fog = planet.sky.fog;
		var oldFog = fog.fogK, oldCurve = fog.curve, oldWorldFogK = world.sky.fog.fogK;
		fog.fogK = 0;
		fog.curve = 0;
		world.sky.fog.fogK = 0;
		// la nave tiene la luz del planeta (sunPower del bioma): en la Luna salia casi negra y en Marte quemada. El original la
		// captura siempre con la misma luz (r3d.Capture, bioma BIShed): aqui se lleva a luz plena (LBASE) mientras se captura
		var k = World.LBASE / Data.getBiome(Type.createEnum(BiomeKind, planet.biomeName)).sunPower;
		var mats = world.root.getMaterials();
		var oldColors = [for( m in mats ) m.color.clone()];
		for( m in mats ) m.color.scale3(k);
		var cam = s3d.camera;
		var old = { pos : cam.pos.clone(), target : cam.target.clone(), up : cam.up.clone(), fov : cam.fovY, zn : cam.zNear, zf : cam.zFar, ratio : cam.screenRatio };
		cam.fovY = 52;
		cam.zNear = 0.1;
		cam.zFar = 256;
		cam.screenRatio = 1;
		cam.up.set(0, 0, 1);

		var tex = new h3d.mat.Texture(size, size, [Target]);
		tex.depthBuffer = new h3d.mat.Texture(size, size, [Target], Depth24Stencil8);
		var frames = [];
		for( i in 0...angles ) {
			var a = Math.PI * 2 * i / angles;
			var p = -(Math.PI / 2 - incli);
			cam.pos.set(cx - Math.cos(a) * delta, cy - Math.sin(a) * delta, baseZ + height);
			cam.target.set(cam.pos.x + Math.cos(a) * Math.cos(p), cam.pos.y + Math.sin(a) * Math.cos(p), cam.pos.z + Math.sin(p));
			engine.pushTarget(tex);
			engine.clear(0x00000000, 1, 0);
			s3d.render(engine);
			engine.popTarget();
			var px = tex.capturePixels();
			px.convert(BGRA);
			var bd = new flash.display.BitmapData(size, size, true, 0);
			for( k in 0...size * size ) bd.px[k] = px.bytes.getInt32(k * 4);
			px.dispose();
			// la luz de la nave es mas fuerte que la del original: se oscurece antes del contraste y el contorno negro (Manager.initShip)
			bd.colorTransform(bd.rect, new flash.geom.ColorTransform(0.58, 0.58, 0.6, 1));
			bd.applyFilter(bd, bd.rect, new flash.geom.Point(0, 0), new flash.filters.ColorMatrixFilter([1 + 0.7 * 1.5, 0, 0, 0, -64 * 0.7, 0, 1 + 0.7 * 1.5, 0, 0, -64 * 0.7, 0, 0, 1 + 0.7 * 1.5, 0, -64 * 0.7, 0, 0, 0, 1, 0]));
			bd.applyFilter(bd, bd.rect, new flash.geom.Point(0, 0), new flash.filters.GlowFilter(0x0, 1, 3, 3, 3));
			frames.push(bd);
		}
		tex.depthBuffer.dispose();
		tex.dispose();

		// restaurar
		cam.pos.load(old.pos);
		cam.target.load(old.target);
		cam.up.load(old.up);
		cam.fovY = old.fov;
		cam.zNear = old.zn;
		cam.zFar = old.zf;
		cam.screenRatio = old.ratio;
		fog.fogK = oldFog;
		fog.curve = oldCurve;
		world.sky.fog.fogK = oldWorldFogK;
		for( i in 0...mats.length ) mats[i].color.load(oldColors[i]);
		for( o in hidden ) o.visible = true;
		return frames;
	}
}
