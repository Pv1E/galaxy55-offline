import Common;
import SaveData.SaveInfo;

/** Bloque apuntado: (x,y,z) el bloque que se golpea, (tx,ty,tz) la celda libre delante de el, (hx,hy,hz) el punto de impacto. */
typedef Select = {
	var x : Int;
	var y : Int;
	var z : Int;
	var b : Block;
	var tx : Int;
	var ty : Int;
	var tz : Int;
	var hx : Float;
	var hy : Float;
	var hz : Float;
	var power : Float;
}

/**
	Una partida en curso: el jugador en primera persona sobre un World.

	La fisica es una copia fiel de ent/Hero.hx y Game.moveHero del juego original: misma gravedad,
	salto, jetpack, sondas de colision de pies, cabeza y paredes, velocidades y unidad de tiempo
	(tmod: 1 unidad = 1/32 s). No hay boton de correr: en el original solo existe caminar despacio (X).
**/
class GameView {

	/** unidades de tiempo del juego (mt.Timer.wantedFPS) */
	static inline var FPS = 32.;
	/** altura normal de los ojos (Hero.viewZ = 1.5); la de ahora es viewZ */
	public static inline var VIEW_Z = 1.5;
	/** colision de cabeza (cambio del port): puntos alrededor del centro y su radio, que cubre el plano cercano de la camara
	    (llega a unos 0.18 del ojo a 70 grados) */
	static inline var HEAD_POINTS = 8;
	static inline var HEAD_RADIUS = 0.2;

	public var world(default, null) : World;
	public var info(default, null) : SaveInfo;

	// posicion y vista (Hero.x/y/z, angle, angleZ)
	public var px = 0.;
	public var py = 0.;
	public var pz = 0.;
	public var yaw = 0.;
	public var pitch = 0.;
	/** altura de los ojos sobre los pies (Hero.viewZ): baja y sube con los fundidos y el teletransportador (updateViewZ) */
	public var viewZ = VIEW_Z;
	public var playSeconds = 0.;

	// excavar y colocar (Game.checkAction)
	public var inv(default, null) : Inv;
	public var select : Select;
	public var laserActive = false;
	public var canBreak = true;
	public var laserCharge : Null<ChargeKind>;
	/** Hero.miningPower: 3 cerca de un turbo minero (WorldProcess.updateTrack), si no 1 */
	public var miningPower(get, never) : Float;
	inline function get_miningPower() return process.miningPower;
	/** modo creativo (anadido nuestro): bloques sin limite, rotura instantanea y jetpack infinito */
	public var creative(default, null) = false;
	/** --editnodriza: la nave nodriza se puede editar (en creativo) y al salir se guarda en mothership.bin */
	public static var editMother = Sys.args().indexOf("--editnodriza") >= 0;
	var actionPause = 0.;
	var activatePending : Select;
	var actionWait = false;
	var armed = false;
	/** tmod acumulado para los trozos del laser (laserParts) */
	var laserPartsTime = 0.;
	public var drops : Drops;
	var fx : Fx;
	var parts : Parts;
	var hand : Hand;
	/** Process.hx del original: agua y lava que fluyen, hierba, anclas... */
	public var process : WorldProcess;
	/** la nave: el jugador empieza dentro y baja al planeta por el teletransportador (Game.placeShip) */
	public var ship(default, null) : Ship;
	/** progreso del teletransporte (Hero.enteringShip): -1 = recien llegado, 0..1.5 = entrando; a 1.5 se transporta */
	public var enteringShip = -1.;

	// estado fisico (Hero)
	public var gravity = 0.;
	public var maxGravity = 0.9;
	/** combustible del jetpack, de 0 a 1 (Hero.jetpack) */
	public var jetpack = 0.;
	public var swimming = false;
	public var standingBlock : Block;
	/** true mientras el jetpack empuja (para el brillo del casco) */
	public var thrusting(default, null) = false;
	/** true si el raton gobierna la vista; si no, los cursores giran (Game.drag.active) */
	public var mouseLook = true;
	/** Game.actionKeys: false con la cantina abierta (Chest.onOpen): se anda y se mira, pero no se salta ni se usa el jetpack,
	    el laser, la activacion ni las teclas de casilla. Cambio del port: las flechas tampoco mueven, son de la ventana */
	public var actionKeys = true;

	// vaiven del casco y de la camara (Game.walkBobbing, bobbingX, bobbingY)
	public var walking = false;
	public var walkBobbing = 0.;
	public var bobX = 0.;
	public var bobY = 0.;
	public var turnSpeed = 0.;
	/** temblor de la camara y del HUD (Game.shake): sube al romper un bloque y al caer, baja 0.01 por tmod, maximo 1.5.
	    La bomba antigua lo pone a 1 (Process.onActivate: game.shake = 1) */
	public var shake = 0.;
	/** subida o bajada de la camara de este fotograma por el temblor */
	public var shakeZ(default, null) = 0.;

	var pushPower = 0.;
	var walkingSlow = false;
	var oldSpeedX = 0.;
	var oldSpeedY = 0.;
	var stun = 0.;

	// vida y oxigeno (Hero.life, Hero.oxygen): de 0 a 100. En creativo no se recibe dano ni se gasta oxigeno
	public var life = 100.;
	public var oxygen = 100.;
	var damageRecover = 0.;
	var healRecover = 0.;
	/** fundido de color de pantalla (Game.fadeFX): golpe en rojo, curacion en azul, muerte en rojo y Mayus+K en blanco hasta
	    volver a la nave. t va de 0 a 1 (+ tmod * speed / 200); alpha(t) da la opacidad (null = t); lock: sin controles mientras dura;
	    dz: cuanto bajan los ojos al acabar (negativo: suben) */
	public var fadeFX : { t : Float, col : Int, speed : Float, alpha : Null<Float -> Float>, done : Void -> Void, lock : Bool, dz : Float };

	public inline function onGround() return standingBlock != null;
	var s3d : h3d.scene.Scene;

	public function new( s3d : h3d.scene.Scene, world : World, info : SaveInfo, atlas : h3d.mat.Texture ) {
		this.s3d = s3d;
		this.world = world;
		this.info = info;
		playSeconds = info.playSeconds;
		// Game.init: con la vida a 0 se vuelve a la nave (hero.hit(0)); aqui directamente con la vida llena
		life = info.life != null && info.life > 0 ? info.life : 100;
		creative = info.creative == true || Sys.args().indexOf("--creative") >= 0 || (editMother && info.mothership == true);
		inv = new Inv(info.inv != null ? Inv.copy(info.inv) : Inv.defaults());
		// solo pruebas: --inv=BIron,BGlass,... llena el inventario con esos bloques
		for( a in Sys.args() )
			if( StringTools.startsWith(a, "--inv=") ) {
				inv.inv.t = [];
				for( nm in a.substr(6).split(",") )
					inv.inv.t.push({ k : Type.enumIndex(Type.createEnum(BlockKind, nm)), n : 5 });
				while( inv.inv.t.length < 10 ) inv.inv.t.push(null);
			}
		drops = new Drops(world, atlas);
		process = new WorldProcess(world, (x, y, z, b) -> breakBlock(x, y, z, b, true));
		process.lavaBombFn = lavaBomb;
		fx = new Fx(world, atlas);
		parts = new Parts(world, atlas);
		hand = new Hand(world, atlas);
		if( info.mothership == true ) {
			// nave nodriza del robot comerciante: se aparece en la primera bahia
			Mothership.data();
			var b = Mothership.spawnAt != null ? Mothership.spawnAt : Mothership.bay(0);
			px = b.x + 0.5;
			py = b.y + 0.5;
			pz = b.z;
			// sobre el teletransportador de tu nave, aparcada en tu plaza
			var s = Mothership.shipSpawn;
			if( s != null ) {
				px = s.x;
				py = s.y;
				pz = s.z;
			}
			yaw = Math.PI / 2;
			pitch = 0;
			// robots (añadido del port): el comerciante del puesto y los drones
			for( r in Mothership.robots ) {
				var drone = r.k >= 4;
				robots.push(new Robot(world, atlas, drone ? Robot.DRONE : Robot.MERCHANT, r.x + 0.5, r.y + 0.5, r.z, drone ? 0 : r.k * Math.PI / 2));
			}
			return;
		}
		if( info.hangar == true ) {
			// hangar (EditShip): el cobertizo con la nave; sin la nave colgada encima
			hangar = new Hangar(world);
			// el proceso del mundo sigue (soportes, detalles, hierba) sin transformaciones (EditShip: process.allowTransforms = false)
			// y, cambio del port, sin mover liquidos
			process.allowTransforms = false;
			process.allowFlow = false;
			hangarCheck();
			var sp = Hangar.spawn();
			px = sp.x;
			py = sp.y;
			pz = sp.z;
			yaw = 0;
			pitch = -0.1;
			enteringShip = -1;
			return;
		}
		ship = new Ship(world, atlas, s3d, info.shipEdits, Hangar.currentShip(info), info.shipAt);
		ship.initCrafts(this);
		if( info.px < 0 ) {
			// partida nueva: se empieza dentro de la nave, encima del teletransportador
			gotoShip(true);
			pitch = -0.25;
		} else if( info.life != null && info.life <= 0 ) {
			// guardada con la vida a 0 (durante el fundido de la muerte): de vuelta en la nave, como hero.hit(0) en Game.init
			gotoShip(true);
		} else {
			px = info.px;
			py = info.py;
			pz = info.pz;
			yaw = info.yaw;
			pitch = info.pitch;
		}
	}

	/** mercado del robot comerciante (se crea al abrir la tienda por primera vez) */
	public var market(get, null) : Market;
	function get_market() {
		if( market == null ) {
			if( info.credits == null ) info.credits = Market.START_CREDITS;
			market = new Market(info.market);
			info.market = market.info;
		}
		market.advance(playSeconds);
		return market;
	}

	/** hangar (null fuera de el) y lo que se avisa al salir */
	public var hangar(default, null) : Hangar;
	public var hangarValid(default, null) = false;
	public var hangarChanged(default, null) = false;
	public var onHangarExit : Void -> Void;
	var hangarTime = 0.;
	var hangarNext = 0.;

	/** EditShip.checkShip: valida la nave y lo dice en el mensaje de abajo */
	function hangarCheck() {
		hangarValid = hangar.check();
		hangarMsg = hangarValid ? Lang.t("hangar.ship_valid").split("%speed%").join("" + hangar.speed) : Lang.t("hangar." + hangar.error);
	}
	var hangarMsg = "";
	/** aviso (ya traducido) de un bloque que no se puede poner (Hangar.forbidden, hangarRule) y cuanto le queda en pantalla */
	var hangarRefused : String;
	/** reglas del hangar durante el tutorial (Tutorial.hangarRule): (poner, x, y, z, bloque) -> aviso, o null si se puede */
	public var hangarRule : Bool -> Int -> Int -> Int -> Block -> String;
	var hangarRefusedTime = 0.;
	/** se acaba de poner un bloque y el boton sigue pulsado: lo siguiente que se apunte no avisa (la celda de al lado no es un error) */
	var placedHold = false;

	function hangarUpdate( tmod : Float ) {
		hangarTime += tmod;
		if( hangarTime >= hangarNext ) {
			hangarNext = hangarTime + 15;
			hangarCheck();
		}
		if( hangarValid && hangar.spawnCell != null && world.lightAt(hangar.spawnCell.x, hangar.spawnCell.y, hangar.spawnCell.z + 1) == 0 ) {
			hangarValid = false;
			hangarMsg = Lang.t("hangar.no_spawn_light");
		}
		// lo que no se puede poner (cambio del port): se avisa en rojo un momento, como los errores del hangar del original
		if( hangarRefusedTime > 0 ) hangarRefusedTime -= tmod;
		messageRed = hangarRefusedTime > 0;
		message = messageRed ? hangarRefused : (hangarTime < 400 ? Lang.t("hangar.help") : hangarMsg);
		// salir por las casillas de teletransporte (EditShip.update)
		if( standingBlock != null && standingBlock.k == BShipEntry ) {
			if( enteringShip >= 0 ) {
				enteringShip += tmod * 0.03;
				if( enteringShip > 1 ) {
					enteringShip = -1;
					if( onHangarExit != null ) onHangarExit();
				}
			}
		} else {
			if( enteringShip > 0 ) enteringShip -= tmod * .1;
			if( enteringShip < 0 ) enteringShip = 0;
		}
	}

	/** la nave editada (comprimida) */
	public function hangarShip() return Hangar.shipBytes(world);

	/** Estado actual para guardar. */
	public function toInfo() : SaveInfo {
		info.px = px;
		info.py = py;
		info.pz = pz;
		info.yaw = yaw;
		info.pitch = pitch;
		info.life = life;
		info.fly = false;
		info.playSeconds = playSeconds;
		info.inv = Inv.copy(inv.inv);
		info.edits = world.editsFlat();
		if( ship != null ) info.shipEdits = ship.world.editsFlat();
		// anadido del port: el sitio donde se dejo la nave pilotandola; a mitad de vuelo, el sitio en que aterrizaria ahora, con el
		// jugador movido lo mismo (asi no aparece dentro de una pared ni fuera de la nave al cargar)
		if( ship != null && ship.moved ) info.shipAt = { x : ship.x, y : ship.y };
		if( ship != null && piloting ) {
			var d = ship.snapDelta();
			info.shipAt = ship.landingSpot();
			info.px = px + d.dx;
			info.py = py + d.dy;
			info.pitch = pilotPitch;
		}
		return info;
	}

	/** Mirar con el raton: mismos divisores que Game (lookLock: 260 en horizontal, 360 en vertical). */
	public function look( dx : Float, dy : Float ) {
		yaw += dx * Settings.mouseSens / 260.0;
		pitch -= dy * Settings.mouseSens / 360.0 * (Settings.invertY ? -1 : 1);
		clampPitch();
	}

	inline function clampPitch() {
		var amax = Math.PI / 2.01;
		if( pitch < -amax ) pitch = -amax;
		else if( pitch > amax ) pitch = amax;
	}

	inline function collide( x : Float, y : Float, z : Float ) : Bool {
		return world.collidePoint(x, y, z);
	}

	inline function clampPos( v : Float ) : Float {
		var s = world.size;
		// el planeta da la vuelta (AbstractGame.real del original)
		return v < 0 ? v + s : (v >= s ? v - s : v);
	}

	inline function onWater() return inWater(0.01);

	/** Hero.inWater: isRealWater = solo agua (BTWater), no cascadas ni arena movediza */
	function inWater( ?dz : Float, isRealWater = false ) : Bool {
		if( dz == null ) dz = viewZ;
		var b = world.block(Math.floor(px), Math.floor(py), Std.int(pz + dz));
		return b != null && b.hasFlag(BFLiquid) && (!isRealWater || b.type == BTWater);
	}

	// ---------------------------------------------------------------- bucle de entrada (Game.moveHero)

	public function update( realDt : Float, controls : Bool, pad : hxd.Pad ) {
		if( realDt > 0.1 ) realDt = 0.1;
		playSeconds += realDt;
		var tmod = realDt * FPS;
		var K = hxd.Key;
		if( fadeFX != null && fadeFX.lock ) controls = false; // hero.lock del original mientras se vuelve a la nave
		// pilotando (anadido del port): los controles mueven la nave, no al jugador
		if( piloting ) {
			if( fadeFX != null && fadeFX.lock ) finishPiloting();
			else pilotStep(tmod, controls && !pilotLanding ? pilotInput(tmod, pad) : { x : 0., y : 0. });
			controls = false;
		}

		var speed = 0., strafe = 0.;
		var useJetpack = false;
		walkingSlow = false;
		walking = false;
		if( controls ) {
			// A/D y flechas izquierda/derecha: en el original giran al personaje, con aceleracion
			// (Settings.turnKeys); por defecto se desplazan de lado
			var move = false;
			var turnMode = Settings.turnKeys;
			var arrows = actionKeys;
			if( (arrows && K.isDown(K.RIGHT)) || K.isDown(K.D) || K.isDown(K.NUMPAD_6) ) {
				if( turnSpeed < 0 ) turnSpeed = 0;
				if( turnMode ) turnSpeed += 0.008 * tmod;
				else strafe += 0.15;
				move = true;
			}
			if( (arrows && K.isDown(K.LEFT)) || K.isDown(K.A) || K.isDown(K.Q) || K.isDown(K.NUMPAD_4) ) {
				if( turnSpeed > 0 ) turnSpeed = 0;
				if( turnMode ) turnSpeed -= 0.008 * tmod;
				else strafe -= 0.15;
				move = true;
			}
			if( !move ) turnSpeed *= Math.pow(0.6, tmod);
			var tmax = 0.06;
			if( turnSpeed < -tmax ) turnSpeed = -tmax;
			if( turnSpeed > tmax ) turnSpeed = tmax;
			var turn = turnSpeed;

			walkingSlow = K.isDown(K.X);
			if( (arrows && K.isDown(K.UP)) || K.isDown(K.W) || K.isDown(K.Z) || K.isDown(K.X) || K.isDown(K.NUMPAD_8) ) {
				speed += 0.15;
				walking = true;
			} else pushPower = 0.0;
			if( (arrows && K.isDown(K.DOWN)) || K.isDown(K.S) || K.isDown(K.NUMPAD_2) ) {
				speed -= 0.15;
				walking = true;
			}

			// mando: palanca izquierda mueve, derecha mira, A salta/jetpack, B camina despacio
			if( pad != null ) {
				var dead = 0.2;
				var lx = pad.xAxis, ly = pad.yAxis;
				if( Math.abs(lx) > dead ) { strafe += 0.15 * lx; walking = true; }
				if( Math.abs(ly) > dead ) { speed += -0.15 * ly; walking = true; }
				walkingSlow = walkingSlow || pad.isDown(pad.config.B);
				if( actionKeys && pad.isDown(pad.config.A) ) useJetpack = true;
				var rx = pad.rxAxis, ry = pad.ryAxis;
				if( Math.abs(rx) > dead ) yaw += rx * 0.054 * Settings.mouseSens * tmod;
				if( Math.abs(ry) > dead ) pitch -= ry * 0.036 * Settings.mouseSens * tmod * (Settings.invertY ? -1 : 1);
			}

			if( speed != 0 && strafe != 0 ) {
				var diag = 1 / Math.sqrt(2);
				speed *= diag;
				strafe *= diag;
			}
			if( swimming || onWater() ) {
				speed *= 0.6;
				strafe *= 0.6;
				turn *= 0.6;
			} else if( walkingSlow ) {
				speed *= 0.4;
				strafe *= 0.4;
				turn *= 0.4;
			}
			if( actionKeys && (K.isDown(K.SPACE) || K.isDown(K.CTRL)) ) useJetpack = true;
			yaw += turn;
			clampPitch();
		} else
			turnSpeed = 0;

		if( debugJet && actionKeys ) useJetpack = true;
		if( debugSpeed != 0 || debugStrafe != 0 ) {
			speed = debugSpeed;
			strafe = debugStrafe;
			walking = true;
		}
		// pilotando, el jugador va quieto junto al ordenador y la nave lo lleva (pilotInput)
		if( !piloting ) stepPhysics(tmod, speed, strafe, useJetpack);
		updateViewZ(tmod);
		updateLife(tmod);
		// temblor (Game.update): baja con el tiempo y la camara sube o baja al azar hasta 0.4 * shake
		if( shake > 0 ) {
			shake -= 0.01 * tmod;
			if( shake > 1.5 ) shake = 1.5;
			if( shake < 0 ) shake = 0;
		}
		shakeZ = Math.random() * 0.4 * shake * (Std.random(2) * 2 - 1);
		// olas: fx.time * animWater.speed (tiempo en segundos * 0.5)
		if( world.wave != null ) {
			world.wave.time += realDt * 0.5;
			world.wave.amp = Settings.waterWaves ? World.WAVE_AMP : 0; // la opcion se aplica al momento
		}
		updateBobbing(realDt * 60);
		if( hangar != null ) hangarUpdate(tmod);
		else if( ship != null ) {
			ship.update(this, tmod);
			if( piloting ) enteringShip = -1; // sin teletransporte mientras se pilota (ship.update lo pondria a 0 lejos del rayo viejo)
			message = ship.message(this);
		}
		// despues del teletransportador (el original sale de Game.update al acabar el fundido): la muerte lleva a la nave y
		// ship.update, con el standingBlock del suelo, pondria enteringShip a 0 y el teletransportador lo bajaria
		updateFade(tmod);
		if( debugDoorFrames > 0 && ++debugDoorFrames == 12 ) {
			// solo pruebas: abre la puerta de la nave que hay cerca del teletransportador
			if( Sys.args().indexOf("--computer") >= 0 ) onComputer();
			var dz = Std.int(ship.start.z);
			var db =world.block(ship.x - 3, ship.y + 3, dz);
			Sys.println("puerta: " + (db == null ? "ninguna" : db.k + " toggle=" + (db.toggle == null ? "null" : "" + db.toggle.k)));
			activateBlock(ship.x - 3, ship.y + 3, dz, db);
			var da = world.block(ship.x - 3, ship.y + 3, dz);
			Sys.println("despues: " + (da == null ? "ninguna" : "" + da.k));
		}
		if( debugCraft > 0 ) {
			// solo pruebas: pone bloques de madera en la primera zona de sintetizador y, con --craftgo, usa el ordenador
			debugCraft++;
			var c = ship.crafts[0];
			var bx = c.x + world.shipDX, by = c.y + world.shipDY, bz = c.z + World.SHIP_Z;
			if( debugCraft == 5 ) {
				world.setBlock(bx, by, bz, Block.get(BWood));
				ship.craft(bx, by, bz, Block.get(BWood), this);
				Sys.println("zona: " + c.curText + " receta=" + (c.curCraft != null));
			}
			if( debugCraft == 12 && Sys.args().indexOf("--craftgo") >= 0 ) {
				ship.activateCraft(c.out.x + world.shipDX, c.out.y + world.shipDY, c.out.z + World.SHIP_Z, this);
				Sys.println("fabricado; sueltos=" + drops.count() + " madera en inv=" + inv.hasBlocks(Block.get(BWood), 1));
			}
			if( debugCraft == 30 ) Sys.println("tras 60 frames: sueltos=" + drops.count() + " tablas en inv=" + inv.hasBlocks(Block.get(BWoodPlank), 1) + " zona=" + c.curText);
		}
		if( debugTele > 0 ) {
			// solo pruebas: se aparta del teletransportador y vuelve a el para probar el teletransporte
			debugTele++;
			if( debugTele == 6 ) enteringShip = 0; // como si se hubiera apartado y vuelto a pisar la plataforma
		}
		updateAction(tmod, controls, pad);
		if( bombQueue.length > 0 ) {
			var c = bombQueue.shift();
			explodeBomb(c.x, c.y, c.z);
		}
		process.update(realDt, px, py, pz + viewZ * 0.5);
		world.flush();
		if( !piloting ) drops.update(this, tmod); // pilotando, los sueltos de la nave van con ella (pilotMove)
		fx.update(this, realDt, tmod);
		parts.update(tmod, s3d.camera, px, py);
	}

	/** solo pruebas: recorre el rayo de la mira y cuenta la primera celda ocupada y por que se descarta */
	public function debugPick() : String {
		var cp = Math.cos(pitch);
		var dx = Math.cos(yaw) * cp, dy = Math.sin(yaw) * cp, dz = Math.sin(pitch);
		var ex = px, ey = py, ez = pz + viewZ + Math.sin(walkBobbing) * 0.05;
		var curve = World.curve(world.size);
		var out = [];
		var t = 0.;
		var last = "";
		while( t < 7.0 ) {
			t += 0.02;
			var hx = dx * t, hy = dy * t;
			var x = ex + hx, y = ey + hy, z = ez + dz * t + (hx * hx + hy * hy) * curve;
			var ix = Math.floor(x), iy = Math.floor(y), iz = Math.floor(z);
			var b = world.block(ix, iy, iz);
			var s = b == null ? "" : "" + b.k;
			if( s != last && s != "" ) {
				out.push(s + "@" + ix + "," + iy + "," + iz + " t=" + Std.int(t * 100) / 100 + (blocking(b) ? "" : "(no bloquea)"));
			}
			last = s;
		}
		return "ojos=" + Std.int(ex * 100) / 100 + "," + Std.int(ey * 100) / 100 + "," + Std.int(ez * 100) / 100 + " yaw=" + yaw + " pitch=" + pitch + "  rayo: " + out.join("  ");
	}

	/** vuelve a exigir soltar el boton antes de actuar (al volver de un menu) */
	public function releaseAction() {
		armed = false;
		laserActive = false;
	}

	/** lo que no sale en la captura de F2 (Render.render(screenShot) del original): la caja de seleccion y el bloque de la mano */
	public function screenShotHidden() : Array<h3d.scene.Object> {
		return fx.screenShotHidden().concat([hand.frame]);
	}

	/** corta los sonidos en bucle (menus abiertos, pausa, salir) */
	public function stopSounds() {
		if( jetSound != null ) jetSound.stop();
		if( laserSound != null ) laserSound.stop();
		jetSound = laserSound = null;
	}

	public function dispose() {
		stopSounds();
		if( ship != null ) ship.dispose();
		fx.dispose();
		parts.dispose();
		hand.dispose();
		drops.dispose();
	}

	/** solo para pruebas automaticas: mantiene el jetpack pulsado */
	public var debugJet = false;
	/** solo para pruebas automaticas: mantiene pulsado el boton de excavar/colocar */
	public var debugAction = false;
	/** banco de pruebas (Dev): mantiene pulsado excavar/colocar */
	public var debugKey : String;
	public var debugSpeed = 0.;
	public var debugStrafe = 0.;
	public var debugTele = 0;
	public var debugCraft = Sys.args().indexOf("--craft") >= 0 ? 1 : 0;
	public var debugClick = Sys.args().indexOf("--click") >= 0 ? 1 : 0;
	public var debugDoorFrames = Sys.args().indexOf("--door") >= 0 || Sys.args().indexOf("--computer") >= 0 ? 1 : 0;
	/** solo para pruebas: finge que el bloque no se puede romper (para ver el efecto) */
	public var debugDeny = false;

	/** Un fotograma de fisica con varios pasos pequenos, como el original (tmod: 1 = 1/32 s). */
	public function stepPhysics( tmod : Float, speed : Float, strafe : Float, useJetpack : Bool ) {
		var k = Math.ceil(tmod * 10);
		var dt = tmod / k;
		thrusting = false;
		for( i in 0...k ) doMove(dt, speed, strafe, useJetpack);
		if( creative ) jetpack = 1;
		if( footCD > 0 ) footCD -= tmod;
		updateSounds();
	}

	/** sonidos de bucle del original: jetpack (Hero.update) y laser (Game.update) */
	var footCD = 0.;
	var jetSound : hxd.snd.Channel;
	var laserSound : hxd.snd.Channel;
	function updateSounds() {
		if( thrusting ) {
			if( jetSound == null ) {
				Snd.play("jetpackStart", 0.2);
				jetSound = Snd.play("jetpack", 0.07, true);
			}
		} else if( jetSound != null ) {
			jetSound.stop();
			jetSound = null;
		}
		if( laserActive && select != null ) {
			if( laserSound == null ) {
				Snd.play("lazerStart", 0.3);
				laserSound = Snd.play("lazer", 0.25, true);
			}
		} else if( laserSound != null ) {
			laserSound.stop();
			laserSound = null;
		}
	}

	/** Game.updateInterface: el original lo ejecuta una vez por fotograma (60 por segundo). */
	function updateBobbing( frames : Float ) {
		if( walking && onGround() && !stunnedLock() )
			walkBobbing += (inWater() ? 0.05 : 0.2) * frames;
		else
			walkBobbing = 0;
		if( !onGround() ) bobY = -gravity * 30;
		bobX += -turnSpeed * 300 * frames;
		if( bobX < -20 ) bobX = -20;
		if( bobX > 20 ) bobX = 20;
		if( bobY < -15 ) bobY = -15;
		if( bobY > 15 ) bobY = 15;
		var decay = Math.pow(0.92, frames);
		bobX *= decay;
		bobY *= decay;
	}

	inline function stunnedLock() return false;

	var fallBob = 0.;

	// ---------------------------------------------------------------- vida (Hero.hit, Hero.heal, Hero.update)

	/** Hero.hit: quita vida y aturde; a 0, fundido rojo y vuelta a la nave con la vida y el oxigeno llenos (Game.returnToShip, modo local) */
	public function hit( dmg : Float ) {
		// en el hangar no se recibe dano (EditShip.init: hero.invincible = true)
		if( creative || hangar != null || (fadeFX != null && fadeFX.lock) ) return;
		life -= dmg;
		stun = 10;
		if( life <= 0 ) {
			life = 0;
			returnToShip(false);
		} else if( fadeFX == null ) {
			var pow = dmg / 100;
			fadeFX = { t : 0., col : 0xFF0000, speed : 3 + 10 * (1 - pow), alpha : t -> (1 - t) * (0.5 + pow * 0.5), lock : false, dz : 0.1, done : function() {} };
		}
	}

	/** Game.returnToShip (modo local): fundido sin controles, rojo al morir y blanco con Mayus+K; al acabar, de vuelta en la
	    nave con la vida y el oxigeno llenos; los ojos bajan 0.8 al morir y suben 0.5 con Mayus+K. Sustituye a un fundido de
	    golpe o de curacion */
	public function returnToShip( manual : Bool ) {
		if( fadeFX != null && fadeFX.lock ) return; // hero.lock: ya se esta volviendo
		fadeFX = { t : 0., col : manual ? 0xFFFFFF : 0xFF0000, speed : 2., alpha : null, lock : true, dz : manual ? -0.5 : 0.8, done : function() {
			life = 100;
			oxygen = 100;
			gravity = 0;
			gotoShip(true);
		} };
	}

	/** Hero.heal */
	public function heal( v : Float ) {
		if( life <= 0 ) return;
		life += v;
		if( life > 100 ) life = 100;
		if( fadeFX == null )
			fadeFX = { t : 0., col : 0x00C5E8, speed : 10., alpha : t -> Math.sin(t * 3.14) * 0.35, lock : false, dz : 0., done : function() {} };
	}

	/** Hero.update: bloques que hacen dano (lava, agua acida, carbon ardiente, hierbas acidas) o que curan (planta y caja de
	    curacion), y ahogarse sin oxigeno */
	function updateLife( dt : Float ) {
		inline function at( z : Float ) return world.block(Math.floor(px), Math.floor(py), Std.int(z));
		if( damageRecover > 0 )
			damageRecover -= dt;
		else {
			var maxHit = 0.;
			for( b in [standingBlock, at(pz + 0.1), at(pz + viewZ + 0.15)] ) {
				if( b == null ) continue;
				for( f in b.flags )
					switch( f ) {
					case BFDamage(v): if( v > maxHit ) maxHit = v;
					default:
					}
			}
			if( maxHit > 0 ) {
				hit(maxHit);
				damageRecover = 10.;
			}
			if( swimming && oxygen <= 0 ) {
				damageRecover = 4;
				hit(1);
			}
		}
		if( healRecover > 0 )
			healRecover -= dt;
		else
			for( b in [standingBlock, at(pz + 0.1)] ) {
				if( b == null ) continue;
				for( f in b.flags )
					switch( f ) {
					case BFHeal(v):
						heal(v);
						healRecover = 20.;
					default:
					}
			}
	}

	/** Hero.updateAngleView: los ojos van hacia 1.5 - t * dz del fundido (bajan al morir o con un golpe, suben con Mayus+K) o,
	    sin fundido, hacia 1.5 + 0.2 por unidad del teletransporte (suben en el planeta, bajan en la nave); suben mas deprisa
	    (0.8 por tmod) de lo que bajan (0.9) */
	function updateViewZ( tmod : Float ) {
		var target = VIEW_Z;
		if( fadeFX != null )
			target -= fadeFX.t * fadeFX.dz;
		else if( enteringShip > 0 )
			target += enteringShip * 0.2 * (pz > Const.SIZE ? -1 : 1);
		if( viewZ != target ) {
			var p = Math.pow(viewZ < target ? 0.8 : 0.9, tmod);
			viewZ = viewZ * p + target * (1 - p);
			if( Math.abs(viewZ - target) < 0.01 ) viewZ = target;
		}
		// cambio del port: por encima de 1.5 los ojos dejan de subir cuando la cabeza (0.13 mas arriba, como en doMove) toca un
		// bloque; si no, bajo un techo bajo la camara se metia en el
		while( viewZ > VIEW_Z && headCollide(pz + viewZ + 0.13) )
			viewZ = Math.max(VIEW_Z, viewZ - 0.01);
	}

	/** algun punto de la cabeza (HEAD_POINTS a HEAD_RADIUS del centro, como en doMove) dentro de un bloque a esa altura */
	function headCollide( z : Float ) {
		for( i in 0...HEAD_POINTS ) {
			var ha = yaw + i * Math.PI * 2 / HEAD_POINTS;
			if( collide(px + Math.cos(ha) * HEAD_RADIUS, py + Math.sin(ha) * HEAD_RADIUS, z) ) return true;
		}
		return false;
	}

	function updateFade( tmod : Float ) {
		if( fadeFX == null ) return;
		fadeFX.t += tmod * fadeFX.speed / 200;
		if( fadeFX.t > 1 || fadeFX.t < 0 ) {
			var done = fadeFX.done;
			fadeFX = null;
			done();
		}
	}

	/** opacidad del fundido de color ahora mismo (0 si no hay) */
	public function fadeAlpha() return fadeFX == null ? 0. : fadeFX.alpha != null ? fadeFX.alpha(fadeFX.t) : fadeFX.t;

	// ---------------------------------------------------------------- fisica (Hero.doMove)

	function doMove( dt : Float, speed : Float, strafe : Float, useJetpack : Bool ) {
		if( stun > 0 ) stun -= dt;

		var waterBlock = world.block(Math.floor(px), Math.floor(py), Std.int(pz + 0.1));
		if( waterBlock != null && !waterBlock.hasFlag(BFLiquid) ) waterBlock = null;
		if( waterBlock != null && waterBlock.k == BMarsQuickSand ) {
			// hundido hasta los ojos: se ahoga poco a poco
			if( world.block(Math.floor(px), Math.floor(py), Std.int(pz + viewZ)) == waterBlock && Std.random(20) == 0 )
				hit(dt * 5);
			dt *= 0.3;
			speed *= 0.6;
			strafe *= 0.6;
		}

		swimming = inWater();
		if( creative ) {
			oxygen = 100;
		} else if( swimming ) {
			if( oxygen > 0 ) oxygen -= dt * 0.1;
			if( oxygen < 0 ) oxygen = 0;
		} else {
			if( oxygen < 100 ) oxygen += dt * 0.5;
			if( oxygen > 100 ) oxygen = 100;
		}

		pz -= gravity * dt;

		// angulo con el desplazamiento lateral
		var a = yaw;
		if( speed != 0 || strafe != 0 ) {
			var s = Math.sqrt(speed * speed + strafe * strafe);
			a += Math.atan2(strafe / s, speed / s);
			speed = s;
		}

		// puntos de los pies
		var fx = new Array<Float>(), fy = new Array<Float>();
		for( da in [0., Math.PI * 2 / 3, -Math.PI * 2 / 3] ) {
			fx.push(px + Math.cos(a + da) * 0.1);
			fy.push(py + Math.sin(a + da) * 0.1);
		}

		// colision de pies
		var col = false;
		for( i in 0...3 )
			if( collide(fx[i], fy[i], pz - 0.01) ) {
				col = true;
				break;
			}

		// colision de cabeza
		// cambio del port: tambien al caer o flotar con el jetpack (el original solo al subir) y con HEAD_POINTS puntos a HEAD_RADIUS
		// del centro (el original usaba los 3 de los pies, a 0.1). Si no, bajando de un salto o flotando junto al borde de un saliente,
		// la cabeza y la camara se metian de lado en el bloque: las sondas de las paredes no pasan de 1.3. Se empuja hacia abajo,
		// como al chocar subiendo, en vez de frenar el avance (frenarlo impedia saltar a un escalon bajo un techo bajo).
		if( !col ) {
			var d = viewZ + 0.13;
			var recal = 0.;
			for( i in 0...HEAD_POINTS ) {
				var ha = a + i * Math.PI * 2 / HEAD_POINTS;
				var hx = px + Math.cos(ha) * HEAD_RADIUS, hy = py + Math.sin(ha) * HEAD_RADIUS;
				while( recal < 0.5 && collide(hx, hy, pz + d) ) {
					pz -= 0.01;
					recal += 0.01;
				}
			}
			if( gravity < 0 && recal > 0 && recal < 0.5 ) gravity = 0;
		}

		if( useJetpack && swimming ) {
			if( gravity > -0.1 ) gravity -= 0.03 * dt;
			useJetpack = false;
		}

		var jconsume = 0.02;
		if( !col ) {
			standingBlock = null;
			if( useJetpack ) {
				if( jetpack > 0 ) {
					thrusting = true;
					jetpack -= jconsume * dt;
					if( gravity > -0.05 )
						gravity += -(0.025 / Math.pow(1 + Math.abs(gravity), 2)) * dt; // cayendo
					else
						gravity += -0.005 * dt; // subiendo
				}
			} else {
				if( swimming ) jetpack += jconsume * 0.7 * dt;
				else jetpack += jconsume * 0.2 * dt;
			}
			if( swimming ) {
				gravity += 0.005 * dt;
				if( gravity > 0.07 ) gravity *= Math.pow(0.95, dt);
			} else {
				gravity += 0.014 * dt;
				if( gravity > maxGravity ) gravity = maxGravity;
			}
		} else {
			// recolocar los pies sobre el suelo (resolucion de 1/32)
			if( gravity >= 0 ) {
				var h = Std.int(pz * 32) / 32;
				while( true ) {
					var found = false;
					for( i in 0...3 )
						if( collide(fx[i], fy[i], h) ) {
							found = true;
							break;
						}
					if( !found ) break;
					h += 1 / 32;
				}
				pz = h;
			}
			if( jetpack < 1 ) jetpack += jconsume * 7 * dt;
			var feet : Block;
			if( collide(px, py, pz - 0.02) )
				feet = world.block(Math.floor(px), Math.floor(py), Std.int(pz - 0.02));
			else
				feet = null;
			if( feet == null )
				for( i in 0...3 )
					if( collide(fx[i], fy[i], pz - 0.02) ) {
						feet = world.block(Math.floor(fx[i]), Math.floor(fy[i]), Std.int(pz - 0.02));
						break;
					}
			if( feet != standingBlock ) {
				standingBlock = feet;
				// caida fuerte: dano y temblor segun la velocidad; caida suave: solo temblor (Hero.doMove)
				var threshold = 0.4;
				var hitPow = gravity / maxGravity;
				if( hitPow > threshold && !creative ) {
					Snd.play("landHard", 1.5);
					Snd.play("hit", 0.7);
					hitPow = (hitPow - threshold) / (1 - threshold);
					shake += 0.4 * hitPow;
					var dmg = 1 + Math.pow(hitPow * 15, 2);
					if( dmg > life ) dmg = life;
					hit(dmg);
					fallBob = dmg + 20;
				} else {
					// cambio del port: en creativo una caida fuerte tiembla como la caida suave mas fuerte (g = 0.4: 0.112). Si no,
					// 0.7 * g^2 llegaba a 0.7, mas que el temblor de una caida con dano (0.4 como mucho) y parecia un golpe. El
					// original solo se saltaba el dano con cheating (vuelo de depuracion)
					if( hitPow > threshold ) hitPow = threshold;
					shake += 0.7 * hitPow * hitPow;
				}
			}
			if( speed > 0 && footCD <= 0 && !swimming ) {
				footCD = 9;
				Snd.play(Std.random(100) < 70 ? "footstep1" : "footstep2", 0.3);
			}
			if( gravity > 0 ) {
				Snd.play("land");
				pushPower = 0;
				if( jetpack < 1 ) jetpack += 0.3;
				else if( gravity >= 0.25 ) bobY = 15; // aterrizaje fuerte
				else bobY = 5;
				if( fallBob > 0 ) bobY = fallBob; // game.bobbingY = dmg + 20
				fallBob = 0;
				gravity = 0;
			}
			if( useJetpack && stun <= 0 ) {
				gravity = -0.23; // salto
				Snd.play("jump", 0.5);
			}
		}

		if( jetpack > 1 ) jetpack = 1;

		// movimiento
		var dist = speed * dt;
		var ox = px, oy = py;

		if( standingBlock != null )
			for( f in standingBlock.flags )
				switch( f ) {
				case BFJump(p):
					if( gravity >= 0 ) gravity = -p;
				default:
				}

		if( standingBlock != null && standingBlock.hasFlag(BFSlippy) ) {
			var p = Math.pow(0.96, dt);
			dist *= 0.005;
			oldSpeedX *= p;
			oldSpeedY *= p;
			oldSpeedX += dist * Math.cos(a);
			oldSpeedY += dist * Math.sin(a);
			dist = Math.sqrt(oldSpeedX * oldSpeedX + oldSpeedY * oldSpeedY);
			a = Math.atan2(oldSpeedY, oldSpeedX);
		} else {
			oldSpeedX = dist * Math.cos(a);
			oldSpeedY = dist * Math.sin(a);
		}
		px += oldSpeedX;
		py += oldSpeedY;

		// permitir pequenas correcciones
		if( dist == 0 ) dist = 0.01;

		// recolocar contra las paredes
		var old = pushPower;
		var dzs = swimming ? [0., 0.5, 0.9] : (walkingSlow ? [-0.2, 0., 0.5, 1., 1.3] : [0., 0.5, 1., 1.3]);
		for( dz in dzs ) {
			var qz = pz + dz;
			var recal = 20;
			while( --recal > 0 ) {
				var r = false;
				for( k in 0...16 ) {
					var a2 = a + ((k & 1) * 2 - 0.99) * (k >> 1) * Math.PI / 8;
					var px2 = px + Math.cos(a2) * 0.45, py2 = py + Math.sin(a2) * 0.45;
					if( collide(px2, py2, qz) == (dz < 0) ) continue;
					px -= Math.cos(a2) * dist / 20;
					py -= Math.sin(a2) * dist / 20;
					pushPower += dist / 20;
					r = true;
				}
				if( !r ) break;
			}
		}

		ox -= px;
		oy -= py;
		dist = Math.sqrt(ox * ox + oy * oy);

		px = clampPos(px);
		py = clampPos(py);

		if( walkingSlow || pushPower == old || dist > speed * dt * 0.5 ) pushPower = 0;
	}

	// ---------------------------------------------------------------- la nave

	/** distancia con signo en un planeta que da la vuelta (AbstractGame.realDist) */
	public function wrapDist( d : Float ) : Float {
		var s = world.size;
		d %= s;
		if( (d < 0 ? -d : d) > s * 0.5 ) d += d < 0 ? s : -s;
		return d;
	}

	// ---------------------------------------------------------------- pilotar la nave (anadido del port)

	/** true mientras se pilota la nave sobre el planeta (desde el ordenador de a bordo) */
	public var piloting(default, null) = false;
	/** se ha pedido dejar la nave: frena, vuelve a su orientacion y se centra en su celda antes de bajar el rayo */
	var pilotLanding = false;
	/** inclinacion de la vista al empezar a pilotar: se recupera al acabar */
	var pilotPitch = 0.;
	/** velocidad actual de la nave pilotada (bloques por segundo) */
	var pilotVX = 0.;
	var pilotVY = 0.;
	/** velocidad maxima de la nave pilotada, en bloques por segundo (sin gasto) */
	static inline var PILOT_SPEED = 18.;
	/** rapidez con que acelera y frena (1/s: cuanto mayor, mas brusco) */
	static inline var PILOT_ACCEL = 1.8;
	/** frenado al dejar la nave (1/s): mas firme, para que aterrice en un par de segundos */
	static inline var PILOT_BRAKE = 3.5;
	/** rapidez con que gira hacia donde va (1/s) e inclinacion lateral maxima al girar (rad) */
	static inline var PILOT_TURN = 2.2;
	static inline var PILOT_BANK = 0.3;
	/** camara de pilotar: distancia por detras de la nave y altura sobre ella */
	static inline var PILOT_CAM_DIST = 22.;
	static inline var PILOT_CAM_UP = 30.;

	/** solo en los planetas jugables: no en la nave nodriza, el hangar ni el tutorial, y no durante un fundido */
	public function canPilot() : Bool {
		return ship != null && hangar == null && info.mothership != true && !Tutorial.active(info) && (fadeFX == null || !fadeFX.lock)
			&& life > 0 && pz >= World.SHIP_Z;
	}

	public function startPiloting() {
		if( piloting || !canPilot() ) return;
		piloting = true;
		pilotLanding = false;
		pilotVX = pilotVY = 0;
		ship.slide(0, 0); // el rayo pasa a marcar donde aterrizaria
		drops.setShipVisible(false); // la nave gira al volar y los sueltos de dentro no: se ocultan hasta aterrizar
		world.sky.setPilotFog(true);
		pilotPitch = pitch;
		pitch = -0.35;
		laserActive = false;
		releaseAction();
		stopSounds();
	}

	/** pide dejar la nave (E, B, Esc, Start): frena y aterriza sola en unos instantes (pilotStep) */
	public function stopPiloting() {
		if( piloting ) pilotLanding = true;
	}

	/** deja la nave ya mismo (en una celda entera, con su orientacion de siempre) y baja el rayo alli: al acabar el aterrizaje
	    suave, en un fundido y en las pruebas */
	public function finishPiloting() {
		if( !piloting ) return;
		var d = ship.land();
		moveRiders(d.dx, d.dy);
		drops.setShipVisible(true);
		world.sky.setPilotFog(false);
		piloting = false;
		pilotLanding = false;
		pilotVX = pilotVY = 0;
		pilotBeam = 1;
		ship.setBeamFade(1);
		pitch = pilotPitch;
		// de pie sobre el teletransportador: como al aparecer en la nave (gotoShip), no transporta hasta que te apartas y vuelves
		enteringShip = -1;
		releaseAction();
	}

	/** lo que va dentro de la nave se mueve con ella: el jugador y los bloques sueltos (las vistas previas de los sintetizadores) */
	function moveRiders( dx : Float, dy : Float ) {
		px += dx;
		py += dy;
		drops.shiftShip(dx, dy);
	}

	/**
	 * WASD / flechas / palanca izquierda: hacia donde acelera la nave, segun la camara (raton y palanca derecha la giran).
	 * Devuelve la velocidad buscada; E o B piden dejar la nave (Esc y Start, en GalaxyApp).
	 */
	function pilotInput( tmod : Float, pad : hxd.Pad ) : { x : Float, y : Float } {
		var K = hxd.Key;
		if( K.isPressed(K.E) || (pad != null && pad.isPressed(pad.config.B)) ) {
			stopPiloting();
			return { x : 0., y : 0. };
		}
		var speed = 0., strafe = 0.;
		var arrows = actionKeys;
		if( (arrows && K.isDown(K.UP)) || K.isDown(K.W) || K.isDown(K.Z) || K.isDown(K.NUMPAD_8) ) speed += 1;
		if( (arrows && K.isDown(K.DOWN)) || K.isDown(K.S) || K.isDown(K.NUMPAD_2) ) speed -= 1;
		if( (arrows && K.isDown(K.RIGHT)) || K.isDown(K.D) || K.isDown(K.NUMPAD_6) ) strafe += 1;
		if( (arrows && K.isDown(K.LEFT)) || K.isDown(K.A) || K.isDown(K.Q) || K.isDown(K.NUMPAD_4) ) strafe -= 1;
		if( pad != null ) {
			var dead = 0.2;
			if( Math.abs(pad.xAxis) > dead ) strafe += pad.xAxis;
			if( Math.abs(pad.yAxis) > dead ) speed -= pad.yAxis;
			if( Math.abs(pad.rxAxis) > dead ) yaw += pad.rxAxis * 0.054 * Settings.mouseSens * tmod;
		}
		if( debugPilot != null ) {
			speed = debugPilot.speed;
			strafe = debugPilot.strafe;
		}
		var s = Math.sqrt(speed * speed + strafe * strafe);
		if( s == 0 ) return { x : 0., y : 0. };
		if( s > 1 ) s = 1;
		// mismo angulo que doMove: yaw + atan2(strafe, speed)
		var a = yaw + Math.atan2(strafe, speed);
		return { x : Math.cos(a) * s * PILOT_SPEED, y : Math.sin(a) * s * PILOT_SPEED };
	}

	/** banco de pruebas: mantiene pulsado avanzar (speed) y de lado (strafe) mientras se pilota, de -1 a 1 */
	public var debugPilot : { speed : Float, strafe : Float };

	/**
	 * Un paso del vuelo: la velocidad se acerca poco a poco a la buscada (acelera y frena con suavidad), la nave gira hacia donde
	 * va y se inclina un poco al girar. Al dejarla, frena, vuelve a su orientacion y se centra en su celda; entonces aterriza.
	 */
	function pilotStep( tmod : Float, want : { x : Float, y : Float } ) {
		var dt = tmod / FPS;
		var k = 1 - Math.exp(-dt * (pilotLanding ? PILOT_BRAKE : PILOT_ACCEL));
		pilotVX += (want.x - pilotVX) * k;
		pilotVY += (want.y - pilotVY) * k;
		var v = Math.sqrt(pilotVX * pilotVX + pilotVY * pilotVY);
		if( pilotLanding && v < 0.3 ) pilotVX = pilotVY = v = 0;
		if( v > 0 ) pilotSlide(pilotVX * dt, pilotVY * dt);
		// rumbo: hacia donde va (si va lo bastante rapido) o, al aterrizar, el de siempre (0)
		var h = ship.heading;
		var target = pilotLanding && v < 2 ? 0. : (v > 1 ? Math.atan2(pilotVY, pilotVX) : h);
		var diff = angleDiff(target - h);
		var turn = diff * (1 - Math.exp(-dt * PILOT_TURN * (pilotLanding ? 2 : 1)));
		var bank = dt > 0 ? -turn / dt * 0.25 : 0.;
		if( bank > PILOT_BANK ) bank = PILOT_BANK;
		if( bank < -PILOT_BANK ) bank = -PILOT_BANK;
		var roll = pilotRoll + (bank - pilotRoll) * (1 - Math.exp(-dt * 3));
		pilotRoll = roll;
		ship.setPose(h + turn, roll);
		// el rayo: entero hasta 3 bloques/s, nada desde 9
		var bt = pilotLanding ? 1. : Math.max(0, Math.min(1, 1 - (v - 3) / 6));
		pilotBeam += (bt - pilotBeam) * (1 - Math.exp(-dt * 4));
		ship.setBeamFade(pilotBeam);
		if( !pilotLanding ) return;
		// ya casi parada: se centra en su celda (sin dar saltos) y aterriza cuando esta derecha y en su sitio
		if( v < 2 ) {
			var c = ship.cellDelta();
			var kc = 1 - Math.exp(-dt * 6);
			if( Math.abs(c.dx) > 0.01 || Math.abs(c.dy) > 0.01 ) pilotSlide(c.dx * kc, c.dy * kc);
			// lo que queda (menos de 3 grados y 0.05 bloques) lo quita land sin que se note
			if( v == 0 && Math.abs(c.dx) < 0.05 && Math.abs(c.dy) < 0.05 && Math.abs(angleDiff(ship.heading)) < 0.05 && Math.abs(pilotRoll) < 0.05 )
				finishPiloting();
		}
	}
	var pilotRoll = 0.;
	/** fuerza del rayo en vuelo: a toda velocidad no se ve y aparece al ir despacio, al pararse y al aterrizar, cuando se elige el sitio */
	var pilotBeam = 1.;

	/** angulo llevado a -PI..PI */
	static function angleDiff( a : Float ) : Float {
		a %= Math.PI * 2;
		if( a > Math.PI ) a -= Math.PI * 2;
		if( a < -Math.PI ) a += Math.PI * 2;
		return a;
	}

	/** mueve la nave pilotada (dx, dy) con lo que lleva dentro */
	public function pilotSlide( dx : Float, dy : Float ) {
		if( !piloting ) return;
		ship.slide(dx, dy);
		moveRiders(dx, dy);
	}

	/** Hero.gotoShip: aparece en la nave (encima del teletransportador) o en el suelo, bajo ella */
	public function gotoShip( inside : Bool ) {
		enteringShip = -1;
		if( ship == null ) {
			// en la nave nodriza (o el hangar) Mayus+K vuelve a tu nave
			if( onHangarExit != null && hangar == null ) onHangarExit();
			return;
		}
		px = ship.x + 0.5;
		py = ship.y + 0.5;
		pz = inside ? ship.start.z : ship.z;
		gravity = 0;
		oldSpeedX = oldSpeedY = 0;
		// se mira hacia donde no haya pared
		for( i in 0...4 ) {
			var a = i * Math.PI / 2;
			if( !collide(px + Math.cos(a), py + Math.sin(a), pz + 1.5) ) {
				yaw = a;
				break;
			}
		}
	}

	/** se llama al activar el ordenador de a bordo */
	public dynamic function onComputer() {}
	/** celda del ultimo ordenador activado (en la nave nodriza decide si es el del robot o el de tu nave) */
	public var lastComputer : { x : Int, y : Int, z : Int };

	/** en la nave nodriza: el ordenador del puesto del robot comerciante (cerca del robot), no el de tu nave */
	public function isRobotComputer() : Bool {
		var c = lastComputer;
		if( c == null ) return false;
		for( r in Mothership.robots )
			if( r.k < 4 && Math.abs(r.x - c.x) <= 4 && Math.abs(r.y - c.y) <= 4 && Math.abs(r.z - c.z) <= 2 ) return true;
		return false;
	}

	/** texto de recetas del sintetizador cercano (se muestra en pantalla) */
	public var message : String;
	public var messageRed = false;

	/** ShipLogic.activateBlock, Process.onActivate y Process.toggle: ordenador de a bordo, cantinas, bomba antigua y bloques
	    que se abren o cierran (puertas) */
	public function activateBlock( x : Int, y : Int, z : Int, b : Block ) {
		if( b.activable != null ) {
			var ok = switch( b.activable ) {
				case WEverywhere: true;
				case WInShip: z >= World.SHIP_Z || info.mothership == true; // la nave nodriza cuenta como nave
				case WOnPlanet: z < World.SHIP_Z;
			};
			if( !ok ) return;
			switch( b.k ) {
			case BShipComputer: lastComputer = { x : x, y : y, z : z }; onComputer();
			case BCrafterComputer: if( ship != null ) ship.activateCraft(x, y, z, this);
			// cambio del port: en el hangar (EditShip) y en la nave nodriza no explota, para no romper la nave
			case BArtiBomb: if( hangar == null && info.mothership != true ) explodeBomb(x, y, z);
			default:
				if( b.hasProp(PContainer) && onChest != null ) onChest(chestBox(x, y, z, b));
			}
		} else if( b.toggle != null ) {
			// Process.toggle: se cambia toda la columna del mismo bloque (una puerta mide varios bloques de alto)
			while( world.block(x, y, z - 1) == b ) z--;
			while( world.block(x, y, z) == b ) {
				world.setBlock(x, y, z, b.toggle);
				z++;
			}
		}
	}

	/** bombas alcanzadas por una explosion: explotan despues, una por fotograma (Process.onActivateLate) */
	var bombQueue : Array<{ x : Int, y : Int, z : Int }> = [];

	/**
	 * Cambio del port: la bomba antigua que alcanza la lava explota como al activarla (en el hangar y en la nave nodriza,
	 * donde no se activa, se rompe y se suelta). Va a bombQueue y explota en el siguiente fotograma, no en medio del paso de
	 * los liquidos. El original la rompia y la soltaba, como sigue haciendo el agua (del mar, puesta o de cascada).
	 */
	function lavaBomb( x : Int, y : Int, z : Int, b : Block ) {
		if( hangar == null && info.mothership != true ) bombQueue.push({ x : x, y : y, z : z }) else breakBlock(x, y, z, b, true);
	}

	/**
	 * Process.onActivate (BArtiBomb): dano de 20 (en el borde) a 150 (en el centro), temblor a 1, fundido de blanco (en el
	 * borde) a rojo (en el centro), y vacia una esfera de radio 8 sin soltar nada. Al activarla se explota; si se excava
	 * hasta el final se recoge, como cualquier bloque (Game.checkToggle / checkAction).
	 */
	function explodeBomb( x : Int, y : Int, z : Int ) {
		var ray = 8;
		var hx = wrapDist(px - x), hy = wrapDist(py - y), hz = pz - z;
		var pow = 1 - (hx * hx + hy * hy + hz * hz) / (ray * ray);
		var dmg = Math.ceil(130 * pow) + 20;
		// fuera de su alcance (solo en cadena) ni golpe ni fundido: con el dano negativo el original curaria
		if( dmg > 0 ) {
			hit(dmg);
			// conserva el final del fundido anterior (morir: volver a la nave)
			var old = fadeFX;
			var gb = Std.int(255 * (1 - (pow < 0 ? 0 : pow)));
			fadeFX = { t : 0., col : 0xFF0000 | (gb << 8) | gb, speed : 2.5, alpha : t -> (Math.random() * 0.1 + 0.9) * (1 - t),
				lock : old != null && old.lock, dz : old != null ? old.dz : 0., done : old != null ? old.done : function() {} };
		}
		shake = 1;
		for( dx in -ray...ray )
			for( dy in -ray...ray )
				for( dz in -ray...ray ) {
					if( dx * dx + dy * dy + dz * dz > ray * ray ) continue;
					var bx = wrapI(x + dx), by = wrapI(y + dy), bz = z + dz;
					// la nave no se toca; la capa 0 y la de arriba del todo tampoco (World.setBlock no las cambia)
					if( bz >= World.SHIP_Z || bz < 1 || bz >= World.HEIGHT - 1 ) continue;
					var old = world.block(bx, by, bz);
					if( old == null ) continue;
					// cambio del port: lo que no se rompe (power -1, la roca madre) se queda; el original miraba la potencia
					// de la bomba y no la del bloque
					var req = old.requiredPower != null ? old.requiredPower : old.matter.requiredPower;
					if( req != null && req < 0 ) continue;
					if( old.hasProp(PContainer) ) breakChest(bx, by, bz);
					world.setBlock(bx, by, bz, null);
					// cambio del port: 8 trozos por bloque en vez de 75; con unos 1000 bloques salian hasta 70000 y el juego se
					// quedaba a pocos fotogramas por segundo
					parts.doBreak(bx, by, bz, old, 8);
					process.onSet(bx, by, bz, old, null);
					// cambio del port: en el original onActivateLate comprobaba que la bomba alcanzada seguia ahi, pero ya
					// se habia quitado y nunca explotaba; aqui explota, como pretendia el codigo
					if( old.k == BArtiBomb && (dx != 0 || dy != 0 || dz != 0) ) bombQueue.push({ x : bx, y : by, z : bz });
				}
	}

	// ---------------------------------------------------------------- excavar y colocar

	inline function wrapI( v : Int ) : Int {
		var s = world.size;
		return v < 0 ? v + s : (v >= s ? v - s : v);
	}

	/** Render.doPick del original: se apunta a todo lo que tiene PCanPick (no lo quitan BFDetail ni BFNoPick: el agua no, la fuente de cascada si) */
	inline function blocking( b : Block ) : Bool {
		return b.hasProp(PCanPick);
	}

	static var pickBoxes = new Map<Int, { x1 : Float, y1 : Float, z1 : Float, x2 : Float, y2 : Float, z2 : Float }>();

	/**
	 * Caja con la que se apunta a un bloque: la suya (BFSize) o, en las plantas y demas modelos, la de su dibujo.
	 * Cambio del port: el original apuntaba a los modelos como a un bloque entero y, con varias plantas juntas, costaba
	 * romper la que se miraba. Las plantas en cruz ocupan la celda en diagonal: se apuntan por su parte central.
	 */
	/**
	 * Cambio del port: plantas y demas modelos se apuntan por lo que se ve. El tramo del rayo de (ax,ay,az) a (bx,by,bz),
	 * en coordenadas de la celda, cruza alguna cara del modelo en un pixel no transparente de su textura.
	 */
	static function modelHit( b : Block, ax : Float, ay : Float, az : Float, bx : Float, by : Float, bz : Float ) : Bool {
		var md = Models.get(b.model != null ? b.model : MCross);
		var v = md.v, pix = Atlas.pixels;
		var n = Std.int(v.length / 24);
		for( q in 0...n ) {
			var o = q * 24;
			var sel = Std.int(v[o + 3]);
			var tile = !md.multi || sel == 0 ? b.tlr : (sel == 1 ? b.tu : b.td);
			if( tile < 0 || tile >= 0xFFF ) continue;
			// plano de la cara (vertices 0, 1, 2)
			var x0 = v[o], y0 = v[o + 1], z0 = v[o + 2];
			var e1x = v[o + 6] - x0, e1y = v[o + 7] - y0, e1z = v[o + 8] - z0;
			var e2x = v[o + 12] - x0, e2y = v[o + 13] - y0, e2z = v[o + 14] - z0;
			var nx = e1y * e2z - e1z * e2y, ny = e1z * e2x - e1x * e2z, nz = e1x * e2y - e1y * e2x;
			var da = nx * (ax - x0) + ny * (ay - y0) + nz * (az - z0);
			var db = nx * (bx - x0) + ny * (by - y0) + nz * (bz - z0);
			if( (da > 0 && db > 0) || (da < 0 && db < 0) || da == db ) continue;
			var t = da / (da - db);
			var px = ax + (bx - ax) * t, py = ay + (by - ay) * t, pz = az + (bz - az) * t;
			// triangulos (0,1,2) y (2,1,3), como World.addModel
			for( tri in 0...2 ) {
				var i0 = tri == 0 ? 0 : 2, i1 = 1, i2 = tri == 0 ? 2 : 3;
				var a0 = o + i0 * 6, a1 = o + i1 * 6, a2 = o + i2 * 6;
				var ux = v[a1] - v[a0], uy = v[a1 + 1] - v[a0 + 1], uz = v[a1 + 2] - v[a0 + 2];
				var wx = v[a2] - v[a0], wy = v[a2 + 1] - v[a0 + 1], wz = v[a2 + 2] - v[a0 + 2];
				var rx = px - v[a0], ry = py - v[a0 + 1], rz = pz - v[a0 + 2];
				var uu = ux * ux + uy * uy + uz * uz, uw = ux * wx + uy * wy + uz * wz, ww = wx * wx + wy * wy + wz * wz;
				var ru = rx * ux + ry * uy + rz * uz, rw = rx * wx + ry * wy + rz * wz;
				var den = uu * ww - uw * uw;
				if( den == 0 ) continue;
				var s1 = (ww * ru - uw * rw) / den, s2 = (uu * rw - uw * ru) / den;
				if( s1 < 0 || s2 < 0 || s1 + s2 > 1 ) continue;
				inline function fu( k : Int ) return v[k + 3] - Std.int(v[k + 3]);
				var u = fu(a0) + (fu(a1) - fu(a0)) * s1 + (fu(a2) - fu(a0)) * s2;
				var w = v[a0 + 4] + (v[a1 + 4] - v[a0 + 4]) * s1 + (v[a2 + 4] - v[a0 + 4]) * s2;
				// con un margen de 3 pixeles (1/10 de bloque) alrededor: los huecos entre hojas no dejan pasar el rayo al suelo
				var ts = Std.int(pix.width / 64);
				var t0x = (tile & 63) * ts, t0y = (tile >> 6) * ts;
				var tx = Std.int(((tile & 63) / 64 + u) * pix.width), ty = Std.int(((tile >> 6) / 64 + w) * pix.height);
				for( ddy in -3...4 )
					for( ddx in -3...4 ) {
						var sx = tx + ddx, sy = ty + ddy;
						if( sx < t0x || sy < t0y || sx >= t0x + ts || sy >= t0y + ts ) continue;
						if( (pix.getPixel(sx, sy) >>> 24) >= 128 ) return true;
					}
			}
		}
		return false;
	}

	public static function pickBox( b : Block ) {
		if( b.size != null ) return b.size;
		if( b.type != BTModel && b.type != BTModel2Side && b.type != BTSprite ) return null;
		var c = pickBoxes.get(b.index);
		if( c != null ) return c;
		var v = Models.get(b.model != null ? b.model : MCross).v;
		var x1 = 1., y1 = 1., z1 = 1., x2 = 0., y2 = 0., z2 = 0.;
		var i = 0;
		while( i < v.length ) {
			x1 = Math.min(x1, v[i]); x2 = Math.max(x2, v[i]);
			y1 = Math.min(y1, v[i + 1]); y2 = Math.max(y2, v[i + 1]);
			z1 = Math.min(z1, v[i + 2]); z2 = Math.max(z2, v[i + 2]);
			i += 6;
		}
		if( x2 < x1 ) return null;
		if( x2 - x1 > 0.9 && y2 - y1 > 0.9 ) {
			x1 = y1 = 0.2;
			x2 = y2 = 0.8;
		}
		// planos (enredaderas): un poco de grosor para poder apuntarlos
		if( x2 - x1 < 0.16 ) { var cx = (x1 + x2) * 0.5; x1 = cx - 0.08; x2 = cx + 0.08; }
		if( y2 - y1 < 0.16 ) { var cy = (y1 + y2) * 0.5; y1 = cy - 0.08; y2 = cy + 0.08; }
		c = { x1 : x1, y1 : y1, z1 : Math.max(0, z1), x2 : x2, y2 : y2, z2 : Math.max(Math.min(1, z2), 0.25) };
		pickBoxes.set(b.index, c);
		return c;
	}

	/**
	 * Primer bloque que toca el rayo del centro de la pantalla (alcance 7). Igual que Render.pick del original, la altura
	 * se corrige con la curvatura del planeta (z + r2 * curve), porque lo que se ve esta curvado.
	 */
	function pick( hand : Block ) : Select {
		var cp = Math.cos(pitch);
		var dx = Math.cos(yaw) * cp, dy = Math.sin(yaw) * cp, dz = Math.sin(pitch);
		// con el temblor de la camara: el original apunta desde ella (Render.pick)
		var ex = px, ey = py, ez = pz + viewZ + Math.sin(walkBobbing) * 0.05 + shakeZ;
		var curve = hangar != null ? 0. : World.curve(world.size);
		var lx = 0, ly = 0, lz = 0, have = false;
		var t = 0.;
		var ox = ex, oy = ey, oz = ez; // punto anterior del rayo
		while( t < 7.0 ) {
			t += 0.02;
			var hx = dx * t, hy = dy * t;
			var x = ex + hx, y = ey + hy, z = ez + dz * t + (hx * hx + hy * hy) * curve;
			var px0 = ox, py0 = oy, pz0 = oz;
			ox = x; oy = y; oz = z;
			var ix = Math.floor(x), iy = Math.floor(y), iz = Math.floor(z);
			// (no se salta la misma celda: los bloques parciales solo cuentan si el rayo pasa por su caja)
			// el agua que no se apunta (mar, cascada que cae, agua puesta) no para el rayo: se pone bajo el agua; la fuente de
			// cascada y la arena movediza si lo paran: se pone contra ellas (Render.pick del original)
			var b = world.block(ix, iy, iz);
			var bx = b != null ? pickBox(b) : null;
			var model = b != null && b.size == null && bx != null && Atlas.pixels != null;
			if( b != null && blocking(b) && (model ? modelHit(b, px0 - ix, py0 - iy, pz0 - iz, x - ix, y - iy, z - iz)
				: (bx == null || (x - ix >= bx.x1 && x - ix <= bx.x2 && y - iy >= bx.y1 && y - iy <= bx.y2 && z - iz >= bx.z1 && z - iz <= bx.z2))) ) {
				if( Dev.trace && iz >= World.SHIP_Z ) Sys.println("pick: toca " + b.k + "@" + ix + "," + iy + "," + iz + " antes=" + lx + "," + ly + "," + lz + " mano=" + (hand != null) + " enZona=" + ship.inCraft(lx, ly, lz));
				// la capa 0 (roca madre) se apunta como en el original (Render.doPick: solo z < 0 queda fuera): se pone encima,
				// pero no se rompe (power -1)
				if( !have || iz < 0 ) return null;
				// hangar: solo dentro de la zona construible (EditShip.checkSelect); para poner basta con que el sitio lo este
				if( hangar != null && !Hangar.inZone(ix, iy, iz) && (hand == null || !Hangar.inZone(lx, ly, lz)) ) return null;
				// nave nodriza: no se rompe ni se construye; como en tu nave (ShipLogic.checkSelect), solo se apunta a lo que se activa
				if( info.mothership == true && !editMother && (hand != null || (b.activable == null && b.toggle == null && !b.hasProp(PContainer))) ) return null;
				if( iz >= World.SHIP_Z ) {
					// en la nave solo se puede apuntar a lo que se activa (puertas, ordenador); el casco no se toca (ShipLogic.checkSelect)
					if( hand == null ) {
						// mano vacia: se apunta a lo que se activa o a lo que se puso en una zona de sintetizador
						if( b.activable == null && b.toggle == null && !ship.inCraft(ix, iy, iz) ) return null;
					} else if( !ship.inCraft(lx, ly, lz) )
						return null; // con un bloque en la mano solo se puede poner dentro de esas zonas
				} else if( iz >= World.HEIGHT - 1 )
					return null;
				return { x : wrapI(ix), y : wrapI(iy), z : iz, b : b, tx : wrapI(lx), ty : wrapI(ly), tz : lz, hx : x, hy : y, hz : z, power : 0. };
			}
			lx = ix;
			ly = iy;
			lz = iz;
			have = true;
		}
		return null;
	}

	function updateAction( tmod : Float, controls : Bool, pad : hxd.Pad ) {
		var K = hxd.Key;
		var held = false, forceEmpty = false;
		if( controls && actionKeys ) {
			held = K.isDown(K.MOUSE_LEFT) || K.isDown(K.E) || K.isDown(K.SHIFT);
			if( pad != null ) {
				var rt = pad.isDown(pad.config.RT), lt = pad.isDown(pad.config.LT);
				if( rt || lt ) held = true;
				forceEmpty = rt && !lt;
				// como el mando de la version Flash (input/Pad.hx): RB / cruceta derecha = casilla siguiente,
				// LB / cruceta izquierda = anterior, Y = tirar el bloque elegido
				if( pad.isPressed(pad.config.RB) || pad.isPressed(pad.config.dpadRight) ) inv.scroll(-1);
				if( pad.isPressed(pad.config.LB) || pad.isPressed(pad.config.dpadLeft) ) inv.scroll(1);
				if( pad.isPressed(pad.config.Y) && inv.getCurrentBlock() != null ) dropCurrent();
				if( pad.isPressed(pad.config.analogClick) ) copyTarget();
			}
			if( hxd.Key.isPressed(hxd.Key.MOUSE_MIDDLE) ) copyTarget();
			// casillas: TAB = excavador, 1..9 y 0 = los 10 bloques. El original (Game.checkKeys) ponia el excavador tambien en 1
			// y dejaba la ultima casilla sin atajo; aqui se corrige a peticion de los jugadores
			for( i in 1...11 )
				if( K.isPressed(K.NUMBER_0 + (i % 10)) && inv.inv.t.length >= i ) inv.select(i);
			if( K.isPressed(K.TAB) ) inv.select(0);
			// Mayus + K: volver a la nave (Game.checkKeys); sin nave (nave nodriza) gotoShip sale de ella al momento
			if( K.isDown(K.SHIFT) && K.isPressed(K.K) ) {
				if( ship != null ) returnToShip(true);
				else gotoShip(true);
			}
			if( (K.isPressed(K.R) || K.isPressed(K.DELETE)) && inv.getCurrentBlock() != null ) dropCurrent();
		}
		if( debugAction || (debugKey != null && actionKeys) ) {
			held = true;
			armed = true;
		}
		if( debugClick > 0 ) {
			// solo pruebas: un clic completo (se pulsa 10 fotogramas y se suelta)
			debugClick++;
			held = debugClick > 8 && debugClick < 20;
		}
		var hand = forceEmpty ? null : inv.getCurrentBlock();
		if( !held ) {
			armed = true;
			actionWait = false;
			placedHold = false;
		}
		laserActive = controls && held && armed && !actionWait;
		if( actionPause > 0 ) actionPause -= tmod;

		// seleccion (Game.update: no se puede apuntar a la propia celda ni a la de encima)
		var prev = select;
		var s = controls || select != null || debugAction ? pick(hand) : null;
		if( s != null ) {
			var cx = hand == null ? s.x : s.tx, cy = hand == null ? s.y : s.ty, cz = hand == null ? s.z : s.tz;
			if( cx == Std.int(px) && cy == Std.int(py) && (cz == Std.int(pz) || cz == Std.int(pz) + 1) ) s = null;
		}
		if( s != null && prev != null && prev.x == s.x && prev.y == s.y && prev.z == s.z && prev.b == s.b ) {
			// misma celda: se conserva lo acumulado
			prev.hx = s.hx;
			prev.hy = s.hy;
			prev.hz = s.hz;
			prev.tx = s.tx;
			prev.ty = s.ty;
			prev.tz = s.tz;
			s = prev;
		}
		select = s;

		if( !laserActive ) {
			if( activatePending != null ) {
				var a = activatePending;
				activatePending = null;
				if( a == select ) activateBlock(a.x, a.y, a.z, a.b);
			}
			if( select != null ) select.power = 0;
			return;
		}
		if( select == null ) return;
		if( hand == null ) {
			mine(tmod);
			laserParts(tmod);
		} else
			place(hand);
	}

	/** Game.checkAction con la mano vacia: acumula potencia segun la dureza del bloque (requiredPower) y las cargas. */
	function mine( tmod : Float ) {
		var s = select;
		var b = s.b;
		// bloques que se activan (ordenador, puertas, cofres): al soltar el boton se activan (Game.checkToggle); si se
		// mantiene el laser hasta el final se rompen, como en el original (checkAction no los distingue)
		if( b.activable != null || b.toggle != null ) {
			if( s.power == 0 ) s.power = 1e-8;
			activatePending = s;
		}
		// en una zona de sintetizador se excava x4 y sin necesitar cargas (ShipLogic.checkSelect)
		// cambio del port: en el hangar tambien, a proposito, para editar la nave con comodidad (alli la velocidad y las cargas
		// no importan). En el original (EditShip) se excava x1 y con las cargas, como en el planeta
		var inCraft = hangar != null || (s.z >= World.SHIP_Z && ship.inCraft(s.x, s.y, s.z));
		var matter = b.matter;
		var req = b.requiredPower != null ? b.requiredPower : matter.requiredPower;
		if( req == null ) req = 1;
		// en creativo los bloques que se activan (ordenador, puertas, cofres) no se rompen de golpe: hay que mantener el laser
		var instant = creative && req > 0 && b.activable == null && b.toggle == null;
		var power = inCraft ? 4.0 : 1.0;
		laserCharge = null;
		if( !inCraft && matter.quickBreaks != null )
			for( c in matter.quickBreaks )
				if( inv.hasCharge(c.c) ) {
					power *= c.v;
					laserCharge = c.c;
					break;
				}
		if( creative ) laserCharge = null;
		if( req > 0 && (!matter.hasProp(PRequireCharge) || laserCharge != null || creative || inCraft) ) {
			canBreak = true;
			if( actionPause > 0 ) {
				if( s.power == 0 ) s.power = 1e-8;
				return;
			}
			s.power += instant ? 1 : miningPower * power / (req * 40);
		} else
			canBreak = false;
		if( debugDeny || (info.mothership == true && !editMother) ) canBreak = false;
		// en tu nave, ordenador y puertas solo se usan, no se rompen (ShipLogic.checkSelect: allowBreak = false)
		if( s.z >= World.SHIP_Z && !inCraft && (b.activable != null || b.toggle != null) ) canBreak = false; // la nave nodriza no se rompe
		// tutorial: en el hangar no se rompe nada; lo que se activa (puertas, ordenador) se sigue usando, sin aviso
		if( canBreak && hangar != null && hangarRule != null ) {
			var why = hangarRule(false, s.x, s.y, s.z, b);
			if( why != null ) {
				canBreak = false;
				if( b.activable == null && b.toggle == null ) {
					hangarRefused = why;
					hangarRefusedTime = 90;
				}
			}
		}
		actionPause = 1;
		if( s.power < 1 || !canBreak ) return;
		if( laserCharge != null ) inv.useCharge(laserCharge);
		activatePending = null;
		breakBlock(s.x, s.y, s.z, b);
		if( creative ) actionPause = 8;
		select = null;
	}

	/**
	 * Game.update: mientras el laser toca un bloque que se puede romper, salta un trozo de su textura en el punto de impacto
	 * 1 vez de cada 2 (1 de cada 6 sin potencia acumulada). Nada si no se puede romper (roca madre, sin la carga, puertas y
	 * ordenador de la nave) ni, en lo que se activa (puertas, ordenadores, cofres), por debajo de 0.15.
	 * Cambio del port: el original tira el dado en cada fotograma dibujado; aqui una vez por tmod (1/32 s,
	 * mt.Timer.wantedFPS), para que no dependa de los FPS.
	 */
	function laserParts( tmod : Float ) {
		var s = select;
		if( s == null || !canBreak || ((s.b.activable != null || s.b.toggle != null) && s.power < 0.15) ) return;
		laserPartsTime += tmod;
		if( laserPartsTime < 1 ) return;
		// punto de impacto en la cara del bloque (Selection.pt de Render.pick): el punto del rayo ya esta dentro de la celda,
		// se vuelve atras por el rayo hasta su borde
		var cp = Math.cos(pitch);
		var dx = Math.cos(yaw) * cp, dy = Math.sin(yaw) * cp, dz = Math.sin(pitch);
		var fx = wrapDist(s.hx - s.x), fy = wrapDist(s.hy - s.y), fz = s.hz - s.z;
		inline function back( f : Float, d : Float ) return d > 0 ? f / d : (d < 0 ? (f - 1) / d : 1e9);
		var tx = back(fx, dx), ty = back(fy, dy), tz = back(fz, dz);
		var t = Math.min(tx, Math.min(ty, tz));
		fx -= dx * t;
		fy -= dy * t;
		fz -= dz * t;
		if( t == tx ) fx = dx > 0 ? 0 : 1;
		else if( t == ty ) fy = dy > 0 ? 0 : 1;
		else fz = dz > 0 ? 0 : 1;
		while( laserPartsTime >= 1 ) {
			laserPartsTime -= 1;
			if( Std.random(s.power > 0 ? 2 : 6) == 0 ) parts.doLaser(s.x + fx, s.y + fy, s.z + fz, s.b, s.x, s.y, s.z);
		}
	}

	/** Game.checkAction con un bloque en la mano: se coloca si algo lo sujeta (anclas e imanes). */
	function place( hand : Block ) {
		var s = select;
		// hangar: ni liquidos ni la bomba exotica a bordo (cambio del port); no se pone y se dice por que
		var refused = hangar != null ? Hangar.forbidden(hand) : null;
		var why = refused != null ? Lang.t("hangar." + refused) : (hangar != null && hangarRule != null ? hangarRule(true, s.tx, s.ty, s.tz, hand) : null);
		if( why != null ) {
			if( !placedHold ) {
				hangarRefused = why;
				hangarRefusedTime = 180;
			}
			return;
		}
		var put = hand.getFlip(yaw);
		// en la nave solo se coloca dentro de las zonas de sintetizador (el casco se edita en el hangar) y alli no hace falta apoyo
		var inShip = s.tz >= World.SHIP_Z;
		if( inShip && !ship.inCraft(s.tx, s.ty, s.tz) ) return;
		var x = s.tx, y = s.ty, z = s.tz;
		var ok = false;
		var tmp : Block;
		if( !ok && hand.canPut(Up) && (tmp = world.block(x, y, z + 1)) != null && tmp.hasMagnet(Down) ) ok = true;
		if( !ok && hand.canPut(Down) && (tmp = world.block(x, y, z - 1)) != null && tmp.hasMagnet(Up) ) ok = true;
		if( !ok && hand.canPut(LeftRight) ) {
			if( (tmp = world.block(x + 1, y, z)) != null && tmp.hasMagnet(LeftRight) ) ok = true;
			else if( (tmp = world.block(x - 1, y, z)) != null && tmp.hasMagnet(LeftRight) ) ok = true;
			else if( (tmp = world.block(x, y - 1, z)) != null && tmp.hasMagnet(LeftRight) ) ok = true;
			else if( (tmp = world.block(x, y + 1, z)) != null && tmp.hasMagnet(LeftRight) ) ok = true;
		}
		if( inShip ) ok = true; // select.ignoreMagnets del original
		var here = world.block(x, y, z);
		// celda ocupada (p. ej. por lo que se acaba de poner): no se gasta nada. Solo se pisa el liquido que no se apunta
		// (Block.canOverride del original): ni la fuente de cascada ni la arena movediza
		if( here != null && !(here.hasProp(PLiquid) && !here.hasProp(PCanPick)) ) return;
		if( !ok || actionPause > 0 ) return;
		actionPause = creative ? 6 : 15;
		if( !creative && !inv.useCurrentBlock() ) return;
		// bien puesto: se quita el aviso que hubiera y no se avisa de nada hasta soltar el boton
		placedHold = true;
		hangarRefusedTime = 0;
		// si era el ultimo bloque, hay que soltar el boton antes de seguir (evita excavar sin querer)
		if( inv.getCurrentBlock() == null ) actionWait = true;
		if( Dev.trace ) Sys.println("place en " + x + "," + y + "," + z + " sobre " + s.b.k + "@" + s.x + "," + s.y + "," + s.z + " antes=" + world.block(x, y, z));
		// el agua puesta por el jugador se extiende como la cascada (si no, inundaria como el mar)
		if( put.type == BTWater && !inShip && hangar == null ) world.setWater(x, y, z, put, WorldProcess.PLACED);
		else world.setBlock(x, y, z, put);
		if( !inShip ) process.onSet(x, y, z, here, put);
		if( inShip ) ship.craft(x, y, z, put, this);
		select = null;
	}

	/** Game.blockBreak: suelta lo que corresponda (con su probabilidad) y quita el bloque. */
	/** clave de una cantina: en la nave, coordenadas de la nave (se mueve de planeta en planeta); si no, planeta y celda */
	function chestKey( x : Int, y : Int, z : Int ) : String {
		if( z >= World.SHIP_Z )
			return "s:" + Std.int(@:privateAccess world.shipLocal(x, world.shipDX)) + "," + Std.int(@:privateAccess world.shipLocal(y, world.shipDY)) + "," + (z - World.SHIP_Z);
		return "p" + (info.uni != null ? info.uni.planetId : 0) + ":" + wrapI(x) + "," + wrapI(y) + "," + z;
	}

	/** contenido de la cantina (se crea vacia con las casillas de BFContainer) */
	public function chestBox( x : Int, y : Int, z : Int, b : Block ) : Protocol.BlockInventory {
		if( info.chests == null ) info.chests = [];
		var k = chestKey(x, y, z);
		for( c in info.chests ) if( c.key == k ) return c.t;
		var size = 4;
		for( f in b.flags ) switch( f ) { case BFContainer(s): size = s; default: }
		var c = { key : k, t : [for( i in 0...size ) null] };
		info.chests.push(c);
		return c.t;
	}

	/** al romper una cantina, lo que tenia sale suelto (cambio del port: el original no lo resolvia) */
	function breakChest( x : Int, y : Int, z : Int ) {
		if( info.chests == null ) return;
		var k = chestKey(x, y, z);
		for( c in info.chests )
			if( c.key == k ) {
				// si esta abierta, la ventana se cierra antes de soltar lo que tiene (ya no se puede sacar nada de ella)
				if( onChestBreak != null ) onChestBreak(c.t);
				for( s in c.t ) if( s != null ) {
					var d = drops.add(x + 0.5, y + 0.5, z + 0.5, Block.all[s.k]);
					d.n = s.n;
					Snd.play("destroyBlock", 0.25); // como cada objeto que cae al romper un bloque
				}
				info.chests.remove(c);
				return;
			}
	}

	public var onChest : Protocol.BlockInventory -> Void;
	public var onChestBreak : Protocol.BlockInventory -> Void;

	public function breakBlock( x : Int, y : Int, z : Int, b : Block, isProcess = false ) {
		shake += 0.05 * Math.random(); // temblor (Game.blockBreak)
		if( b.hasProp(PContainer) ) breakChest(x, y, z);
		var get = b.getDrop();
		if( get != null && !creative ) {
			var chance = b.getMain().getDropChance();
			for( i in 0...get.count ) {
				if( Std.random(100) >= chance ) continue;
				drops.add(x + 0.5, y + 0.5, z + 0.5, get.b);
				// un sonido por cada objeto que cae, tambien en las roturas en cadena; si no cae nada, no suena
				Snd.play("destroyBlock", 0.25);
			}
		}
		world.setBlock(x, y, z, null);
		parts.doBreak(x, y, z, b);
		if( z >= World.SHIP_Z ) ship.craft(x, y, z, null, this);
		else process.onSet(x, y, z, b, null);
	}

	/** bloque de una zona de sintetizador gastado en una receta: desaparece con su efecto de rotura */
	public function removeShipBlock( x : Int, y : Int, z : Int, b : Block ) {
		world.setBlock(x, y, z, null);
		parts.doBreak(x, y, z, b);
	}

	/** Game.dropCurrent: tira la pila de la casilla elegida delante del jugador. */
	function dropCurrent() {
		var index = inv.blockIndex - 1;
		var s = inv.drop(index);
		if( s == null || creative ) return; // en creativo tirar solo vacia la casilla
		var d = drops.add(px + Math.cos(yaw), py + Math.sin(yaw), pz + 1.2, Block.all[s.k]);
		d.n = s.n;
		d.vx = Math.cos(yaw) * 0.3;
		d.vy = Math.sin(yaw) * 0.3;
		d.active = false;
	}

	/** creativo: L3 o clic central copian el bloque apuntado a la casilla elegida (anadido del port) */
	function copyTarget() {
		if( !creative ) return;
		var s = pick(null);
		if( s != null && s.b != null ) setSlot(s.b);
	}

	/** Paleta creativa: pone el bloque en la casilla elegida (o en la primera libre si esta el excavador). */
	public function setSlot( b : Block ) {
		var idx = inv.blockIndex - 1;
		if( idx < 0 ) {
			idx = 0;
			for( i in 0...inv.inv.t.length )
				if( inv.inv.t[i] == null ) {
					idx = i;
					break;
				}
			inv.blockIndex = idx + 1;
		}
		inv.inv.t[idx] = { k : b.index, n : inv.maxBlock(b) };
		inv.display();
	}

	/** rueda del raton */
	public function scrollInventory( delta : Int ) {
		inv.scroll(delta);
	}

	// ---------------------------------------------------------------- camara

	/** robots de la nave nodriza (Robot.hx) */
	var robots : Array<Robot> = [];

	/** color y opacidad del velo de pantalla dentro de un liquido (Game.getEffects: fades), null fuera */
	public var liquidFade(default, null) : { a : Float, col : Int } = null;
	var liquidTime = 0.;

	/** Game.getEffects + Hero.inWaterBlock del original: el bloque en los ojos, si es liquido con BFColor(c, alpha), tine la pantalla y la niebla */
	function updateLiquidView( ez : Float ) {
		liquidTime += 1 / 60;
		liquidFade = null;
		var b = world.block(Math.floor(px), Math.floor(py), Std.int(ez));
		if( b != null && b.hasFlag(BFLiquid) )
			for( f in b.flags )
				switch( f ) {
				case BFColor(c, alpha):
					if( alpha == null ) alpha = 0.65;
					// el original suma ruido de Perlin a la densidad; aqui una oscilacion suave equivalente
					var power = 60 * alpha + Math.sin(liquidTime * 0.7 + px * 0.3) * 10;
					world.sky.setLiquid(c, power);
					var a = alpha + Math.sin(Math.PI * 2 * (liquidTime % 2.5) / 2.5) * 0.08;
					if( a > 0.999 ) a = 0.999;
					if( a < 0.3 ) a = 0.3;
					liquidFade = { a : a, col : c };
					return;
				default:
				}
		world.sky.setLiquid(null, 0);
	}

	public function updateCamera() {
		if( piloting ) {
			pilotCamera();
			return;
		}
		var cp = Math.cos(pitch);
		var c = s3d.camera;
		var ez = pz + viewZ + Math.sin(walkBobbing) * 0.05;
		// en el agua la vista sube y baja con las olas (Game.hx, planet.animWater)
		var wv = world.wave;
		if( wv != null && (onWater() || inWater()) )
			ez -= Math.sin(px * wv.width + wv.time) * Math.cos(py * wv.width + wv.time) * wv.amp;
		// con los ojos en el agua el campo de vision se cierra al momento (Game.hx: hero.inWater(true), fov * 0.8)
		c.fovY = inWater(null, true) ? Settings.fov * 0.8 : Settings.fov;
		c.zNear = 0.1;
		c.zFar = 1500;
		// temblor (Game.update: pz + random * 0.4 * shake); en pausa y en los menus se queda como estaba
		c.pos.set(px, py, ez + shakeZ);
		c.target.set(px + Math.cos(yaw) * cp, py + Math.sin(yaw) * cp, ez + shakeZ + Math.sin(pitch));
		c.up.set(0, 0, 1);
		world.sky.follow(px, py, ez);
		world.sky.update(1 / 60);
		updateLiquidView(ez);
		for( r in robots ) r.update(1 / 60, px, py, pz);
		world.updateWrap(px, py);
		// la mano va pegada a la camara de este fotograma (antes usaba la del anterior y temblaba al andar)
		hand.update(inv.getCurrentBlock(), c, bobX, bobY);
	}

	/** camara de pilotar (anadido del port): fuera de la nave, detras y arriba, mirando a su centro; el raton la gira.
	    El planeta es redondo (Sky.FogShader: cada vertice baja con el cuadrado de su distancia a la camara): se apunta a donde
	    se dibuja la nave, no a donde esta */
	function pilotCamera() {
		var c = s3d.camera;
		var m = ship.center();
		var dist = PILOT_CAM_DIST, up = PILOT_CAM_UP;
		c.fovY = Settings.fov;
		c.zNear = 0.1;
		c.zFar = 1500;
		c.pos.set(m.x - Math.cos(yaw) * dist, m.y - Math.sin(yaw) * dist, m.z + up);
		c.target.set(m.x, m.y, m.z - dist * dist * World.curve(world.size));
		c.up.set(0, 0, 1);
		world.sky.follow(c.pos.x, c.pos.y, c.pos.z);
		world.sky.update(1 / 60);
		world.sky.setLiquid(null, 0);
		for( r in robots ) r.update(1 / 60, px, py, pz);
		world.updateWrap(px, py);
		hand.update(null, c, 0, 0);
	}
}
