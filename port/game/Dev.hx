import Common;

/**
 * Banco de pruebas (solo para desarrollo): ejecuta un guion de ordenes sobre una partida nueva, sin ventana a la vista ni teclado.
 *   hl galaxy55.hl --script=guion.txt [--bgbiome=BIAutumn] [--creative]
 * Una orden por linea, "#" = comentario. Las coordenadas son del planeta salvo las de `tpl`, `setl` y `lookl` (locales a la nave).
 *   wait N                  esperar N actualizaciones
 *   until fade|tele X       esperar (600 actualizaciones como mucho) a que la opacidad del fundido o la carga del
 *                           teletransportador llegue a X
 *   tp x y z [yaw pitch]    colocar al jugador (z = "top" pone sobre el suelo)
 *   tpl x y z [yaw pitch]   igual, con coordenadas locales de la nave
 *   look yaw pitch          orientar la camara
 *   nudge dx dy [dz]        mover al jugador desde donde esta
 *   lookat x y z            mirar a ese punto (planeta)    lookl x y z   (nave)
 *   ship | planet           ir a la nave / bajar al planeta
 *   pilot | pilotgo dx dy | pilotkeys a l | pilotland | pilotstop   pilotar la nave (anadido del port): empezar, moverla de golpe,
 *                           mantener las teclas, dejarla con suavidad (como E) o ya mismo (print pilot|pilotcam)
 *   tele                    pisar de nuevo el teletransporte (o el rayo): si se cumplen las condiciones, transporta al rato
 *   tpdock dx dy [dz]       colocar al jugador respecto al centro y la base del rayo de la nave
 *   dockp dz Bloque|none    poner o romper (como al jugar) en la columna del rayo; dz = 0 es su bloque de arriba
 *   slot N                  elegir casilla (0 = excavador)
 *   give Bloque [n]         meter n bloques (50) en el inventario
 *   drop x y z Bloque [vida] soltar un bloque quieto (vida en segundos, 180)
 *   hand Bloque             poner ese bloque en la casilla elegida (como la paleta creativa)
 *   set x y z Bloque|none   poner o quitar un bloque (como si el jugador lo hubiera hecho); setl = locales de la nave
 *   activate x y z          activar el bloque de esa celda (puertas, ordenadores); activatel = local; si abre un menu, el guion sigue en el
 *   synth N                 usar el ordenador del sintetizador N
 *   jet 1|0                 mantener Espacio (salto y jetpack)
 *   press|release TECLA...  pulsar o soltar teclas de verdad (shift o una letra), p. ej. press shift k = Mayus+K
 *   explore                 abrir el mapa de estrellas (explorador); expsys N / expgo x y / expinfo lo manejan
 *   walk avance [lado]      andar (1 = adelante, -1 = atras; 0 0 para parar)
 *   waitfor COSA [max]      esperar (como mucho max fotogramas, 2000 por defecto) a: map (mapa abierto), sector (la nave fuera
 *                           de los sistemas), window (ventana del mapa
 *                           abierta), planet (jugando en un planeta), mother (jugando en la nave nodriza), ready (cargado: jugando
 *                           o en el mapa); si no llega, lo dice
 *   waitfor ground          esperar a estar de pie en el suelo (el fotograma del aterrizaje tras una caida)
 *   print land              aterrizaje: suelo, gravedad, aturdimiento (stun), cabeceo del casco (bobY), temblor y fundido
 *   key NOMBRE / unkey      pulsar y soltar una accion: dig, place, jump
 *   mine x y z              excavar ese bloque con el excavador y decir cuanto tarda (y con que potencia)
 *   print inv|pos|zones|drops|loose|chest|msg|shake|fade|block x y z|blockl x y z|around x y z r|select|ship|map [z]|palette|time|power|life|fov|sky|menu
 *   shop / shopclose        abrir y cerrar la tienda del robot;  buy|sell Bloque n   comprar o vender (print credits)
 *   contracts [close]       abrir y cerrar los contratos de la ESCorp; contracts slot N impone el periodo (-1 = la hora real);
 *                           contracts fill i da los bloques del contrato i; deliver i lo entrega; print contracts;
 *                           contracts load RUTA lee otro contracts.json
 *   seaflood [N]            dejar el contador de inundacion a N bloques (1) de la bajada del mar; seadrop la hace ya
 *   print sea|lightcheck    estado del mar; luz actual comparada con recalcular todo el planeta
 *   shot nombre             captura en port/out/nombre.png ("%b" en el nombre = bioma del planeta)
 *   loadshot nombre [N]     captura en la imagen N (5) de la siguiente carga de planeta (mientras carga el guion no corre)
 *   f2                      pulsa F2 (captura sin HUD en screenshots de la carpeta de datos); print shots las lista
 *   pause                   menu de pausa como Esc (el guion sigue; close lo cierra)
 *   newgame SEMILLA [acc..] Menu principal > Nueva partida como el jugador: pasa a Creativo, escribe la semilla, maneja la fila del bioma con
 *                           las acciones (izq / der = flechas, ok = Intro, clic< / clic> = clic en esas flechas, clicfila =
 *                           clic en el titulo de la fila) y pulsa Crear; seguir con waitfor planet y print biome
 *   tuto new|notuto [semilla] partida de aventura nueva en el espacio, con o sin tutorial; tuto step N; tuto skip (sin preguntar)
 *   print tuto              paso del tutorial, objetivos marcados, sus bloques en el planeta y el texto (tambien en el mapa)
 *   menu                    Menu principal (guarda la partida, como desde la pausa); el guion sigue en los menus de inicio
 *   devsaves N              borra las partidas de la carpeta de datos de prueba y crea N de ejemplo (solo con GALAXY55_DATA)
 *   tap TECLA               pulsar y soltar una tecla: up down left right enter esc tab space pgup pgdown o una letra
 *   type TEXTO              escribir el resto de la linea en el campo de texto en el que se esta escribiendo
 *   wheel N                 rueda del raton (N > 0 = hacia abajo)
 *   mouse X Y [click]       llevar el raton a ese punto de la zona 1280x720 (y hacer clic)
 *   print menu|saves        pantalla de menu abierta y su foco / partidas guardadas (waitfor menu: el menu y su fondo listos)
 *   quit
 */
class Dev {

	static var shoreX = 0;
	static var shoreY = 0;
	/** vida y tiempo de juego del ultimo `print life` (para el ritmo de curacion) */
	static var lifeV = 0.;
	static var lifeT = -1.;

	/** mensajes de seguimiento del juego (orden `trace`) */
	public static var trace = false;
	/** el guion abrio la pausa (orden `pause`): sigue ejecutandose en pausa */
	public var inPause = false;
	/** el guion volvio al menu principal (orden `menu`): sigue ejecutandose en los menus de inicio */
	public var inMenu = false;
	/** tecla de la orden `tap`, que se suelta en la siguiente actualizacion */
	var tapKey = -1;
	var lines : Array<String>;
	var pc = 0;
	var waiting = 0;
	var waitCond : String = null;
	var waitMax = 0;
	/** orden `mine` en curso: celda, bloque y cuando se empezo */
	var mining : { x : Int, y : Int, z : Int, b : Block, t0 : Float, power : Float };
	/** orden `until`: "fade" o "tele", el valor que se espera y las actualizaciones que quedan como mucho */
	var untilWhat : String;
	var untilValue = 0.;
	var untilLeft = 0;
	var loadShot : String;
	var loadShotWait = 0;

	public function new( path : String ) {
		lines = sys.io.File.getContent(path).split("\n").map(StringTools.trim).filter(function(l) return l != "" && l.charAt(0) != "#");
	}

	static function bk( name : String ) : Block {
		var k = Type.createEnum(BlockKind, name);
		return Block.get(k);
	}

	static function f( s : String ) return Std.parseFloat(s);

	/** codigo de una tecla de press, release y tap: un nombre o una letra */
	static function keyCode( n : String ) : Int {
		var K = hxd.Key;
		return switch( n ) {
			case "shift": K.SHIFT;
			case "ctrl": K.CTRL;
			case "backspace": K.BACKSPACE;
			case "up": K.UP;
			case "down": K.DOWN;
			case "left": K.LEFT;
			case "right": K.RIGHT;
			case "enter": K.ENTER;
			case "esc": K.ESCAPE;
			case "tab": K.TAB;
			case "space": K.SPACE;
			case "pgup": K.PGUP;
			case "pgdown": K.PGDOWN;
			default: n.toUpperCase().charCodeAt(0);
		}
	}

	static function keyEvent( down : Bool, code : Int ) {
		var e = new hxd.Event(down ? EKeyDown : EKeyUp);
		e.keyCode = code;
		hxd.Window.getInstance().event(e);
	}

	/** condiciones de waitfor: los tiempos de carga y de viaje cambian mucho de un PC a otro */
	static function reached( app : GalaxyApp, g : GameView, what : String ) : Bool {
		var playing = Type.enumConstructor(@:privateAccess app.state) == "Playing";
		return switch( what ) {
			case "map": g == null && app.explorer != null;
			// en el sector y con la animacion de salida del sistema ya terminada (mientras dura, el mapa no hace caso)
			case "sector": app.explorer != null && app.explorer.shipPos() != null && !@:privateAccess app.explorer.locked && !@:privateAccess app.explorer.serverLock;
			case "window": app.explorer != null && app.explorer.devWindowOpen();
			case "planet": playing && g != null && g.info.mothership != true && g.hangar == null;
			case "mother": playing && g != null && g.info.mothership == true;
			case "ready": playing || (g == null && app.explorer != null);
			case "ground": g != null && g.onGround();
			case "menu": Type.enumConstructor(@:privateAccess app.state) == "Menu" && @:privateAccess app.bgWorlds.length > 0;
			default: true;
		}
	}
	/** en cada imagen de la carga de un planeta (orden loadshot) */
	public function loadingFrame( app : GalaxyApp ) {
		if( loadShot == null || --loadShotWait > 0 ) return;
		app.capture("port/out/" + loadShot + ".png", false);
		loadShot = null;
	}

	/** una orden por actualizacion; devuelve true al terminar */
	public function tick( app : GalaxyApp, g : GameView ) : Bool {
		if( tapKey >= 0 ) {
			keyEvent(false, tapKey);
			tapKey = -1;
		}
		if( waiting > 0 ) {
			waiting--;
			return false;
		}
		if( waitCond != null ) {
			if( reached(app, g, waitCond) ) waitCond = null;
			else if( --waitMax <= 0 ) {
				Sys.println("waitfor " + waitCond + ": no llego");
				waitCond = null;
			} else return false;
		}
		if( mining != null && g != null ) {
			// mine: se espera a que el bloque se rompa (20 s como mucho)
			var m = mining;
			var broken = g.world.block(m.x, m.y, m.z) != m.b;
			if( !broken && g.playSeconds - m.t0 < 20 ) {
				m.power = g.miningPower;
				return false;
			}
			g.debugKey = null;
			mining = null;
			Sys.println("excavar " + m.b.k + ": " + (broken ? Math.round((g.playSeconds - m.t0) * 100) / 100 + " s" : "no se rompe") + " con potencia " + m.power);
		}
		if( untilWhat != null && g != null && --untilLeft > 0 && (untilWhat == "tele" ? g.enteringShip : g.fadeAlpha()) < untilValue )
			return false;
		untilWhat = null;
		while( pc < lines.length ) {
			var l = lines[pc++];
			var a = l.split(" ").filter(function(s) return s != "");
			// en el mapa de estrellas no hay planeta cargado (g = null): solo valen las ordenes del mapa y las generales
			var w = g != null ? g.world : null;
			var sdx = w != null ? w.shipDX : 0, sdy = w != null ? w.shipDY : 0, sz = World.SHIP_Z;
			try {
				switch( a[0] ) {
				case "wait":
					waiting = Std.parseInt(a[1]);
					return false;
				case "waitfor":
					waitCond = a[1];
					waitMax = a.length > 2 ? Std.parseInt(a[2]) : 2000;
				case "until":
					untilWhat = a[1];
					untilValue = f(a[2]);
					untilLeft = 600;
					return false;
				case "tp", "tpl":
					var l = a[0] == "tpl";
					g.px = f(a[1]) + (l ? sdx : 0);
					g.py = f(a[2]) + (l ? sdy : 0);
					g.pz = StringTools.startsWith(a[3], "top") ? w.topCollide(Std.int(g.px), Std.int(g.py)) + 0.01 + (a[3].length > 3 ? Std.parseInt(a[3].substr(3)) : 0) : f(a[3]) + (l ? sz : 0);
					if( a.length > 5 ) {
						g.yaw = f(a[4]);
						g.pitch = f(a[5]);
					}
				case "look":
					g.yaw = f(a[1]);
					g.pitch = f(a[2]);
				case "nudge":
					// nudge dx dy [dz]: mover al jugador desde donde esta (alejarse un poco de la cantina abierta)
					g.px += f(a[1]);
					g.py += f(a[2]);
					if( a.length > 3 ) g.pz += f(a[3]);
				case "lookat", "lookl":
					var l = a[0] == "lookl";
					var dx = f(a[1]) + (l ? sdx : 0) - g.px, dy = f(a[2]) + (l ? sdy : 0) - g.py, dz = f(a[3]) + (l ? sz : 0) - (g.pz + g.viewZ);
					g.yaw = Math.atan2(dy, dx);
					g.pitch = Math.atan2(dz, Math.sqrt(dx * dx + dy * dy));
				case "ship": g.gotoShip(true);
				// pilotar la nave (anadido del port): pilot empieza (como el boton del ordenador), pilotgo DX DY la mueve de golpe,
				// pilotkeys AVANCE LADO mantiene las teclas (-1..1; "pilotkeys 0 0" las suelta), pilotland la deja como E (frena y
				// aterriza sola), pilotstop la deja ya mismo
				case "pilot":
					g.startPiloting();
					Sys.println("pilotar: " + (g.piloting ? "si" : "no (canPilot=" + g.canPilot() + ")"));
				case "pilotgo": g.pilotSlide(f(a[1]), f(a[2]));
				case "pilotkeys": g.debugPilot = f(a[1]) == 0 && f(a[2]) == 0 ? null : { speed : f(a[1]), strafe : f(a[2]) };
				case "pilotland": g.stopPiloting();
				case "pilotstop":
					g.finishPiloting();
					Sys.println("nave dejada en " + g.ship.x + "," + g.ship.y + " suelo z=" + g.ship.z + " desplazamiento=" + w.shipDX + "," + w.shipDY + " jugador=" + Std.int(g.px * 100) / 100 + "," + Std.int(g.py * 100) / 100 + "," + Std.int(g.pz * 100) / 100);
				case "planet": g.gotoShip(false);
				case "tele": g.enteringShip = 0; // como si se hubiera apartado y vuelto a pisar
				case "tpdock":
					g.px = g.ship.x + 0.5 + f(a[1]);
					g.py = g.ship.y + 0.5 + f(a[2]);
					g.pz = g.ship.z + (a.length > 3 ? f(a[3]) : 0);
				case "dockp":
					// dockp DZ BLOQUE|none: setp / breakp en la columna del rayo, DZ sobre su bloque de arriba
					var x = g.ship.x, y = g.ship.y, z = Math.ceil(g.ship.z) - 1 + Std.parseInt(a[1]);
					var old = w.block(x, y, z);
					var nb = a[2] == "none" ? null : bk(a[2]);
					if( nb == null ) {
						if( old != null ) g.breakBlock(x, y, z, old);
					} else {
						if( nb.type == BTWater ) w.setWater(x, y, z, nb, WorldProcess.PLACED) else w.setBlock(x, y, z, nb);
						g.process.onSet(x, y, z, old, nb);
					}
					Sys.println("dockp " + x + "," + y + "," + z + " antes=" + (old == null ? "aire" : "" + old.k) + " ahora=" + (nb == null ? "aire" : "" + nb.k));
				case "slot": g.inv.select(Std.parseInt(a[1]));
				case "life":
					// life N [OXIGENO]: pone la vida (y el oxigeno)
					g.life = f(a[1]);
					if( a.length > 2 ) g.oxygen = f(a[2]);
				case "hurt": g.hit(f(a[1]));
				case "shake": g.shake = f(a[1]); // shake V: pone el temblor (la bomba antigua lo pone a 1)
				case "waves": Settings.waterWaves = a[1] == "1"; // waves 0|1: opcion de olas del agua
				case "fov": Settings.fov = Std.parseInt(a[1]); // fov N: opcion de campo de vision
				case "seaflood": w.waterFlood = w.floodThreshold() - (a.length > 1 ? Std.parseInt(a[1]) : 1);
				case "seadrop": w.reduceWater();
				case "vitals":
					Sys.println("vida " + Math.round(g.life * 10) / 10 + " oxigeno " + Math.round(g.oxygen * 10) / 10 + " fundido " + Math.round(g.fadeAlpha() * 100) / 100 + " pos " + Math.round(g.px * 10) / 10 + "," + Math.round(g.py * 10) / 10 + "," + Math.round(g.pz * 10) / 10 + " nadando " + g.swimming + " ojos " + Math.round(g.viewZ * 100) / 100 + " tele " + Math.round(g.enteringShip * 100) / 100);
				case "drop":
					// drop x y z Bloque [vida]: un bloque suelto quieto (sin velocidad) con esa vida en segundos (180)
					var d = g.drops.add(f(a[1]), f(a[2]), f(a[3]), bk(a[4]));
					d.vx = d.vy = 0;
					if( a.length > 5 ) d.time = f(a[5]);
				case "give":
					var b = bk(a[1]);
					g.inv.addBlocks(b, a.length > 2 ? Std.parseInt(a[2]) : 50);
				case "hand": g.setSlot(bk(a[1])); // hand Bloque: lo pone en la casilla elegida, como la paleta creativa
				case "set", "setl":
					var l = a[0] == "setl";
					var x = Std.parseInt(a[1]) + (l ? sdx : 0), y = Std.parseInt(a[2]) + (l ? sdy : 0), z = Std.parseInt(a[3]) + (l ? sz : 0);
					var b = a[4] == "none" ? null : bk(a[4]);
					w.setBlock(x, y, z, b);
					if( z >= sz ) g.ship.craft(x, y, z, b, g);
				case "setp", "breakp":
					// setp X Y Z BLOQUE / breakp X Y Z: como al jugar (avisa a Process: agua, lava, hierba, anclas)
					var x = Std.parseInt(a[1]), y = Std.parseInt(a[2]);
					var z = StringTools.startsWith(a[3], "top") ? w.topCollide(x, y) + (a[3].length > 3 ? Std.parseInt(a[3].substr(3)) : 0) : Std.parseInt(a[3]);
					var old = w.block(x, y, z);
					if( a[0] == "breakp" ) {
						if( old != null ) g.breakBlock(x, y, z, old);
					} else {
						var nb = a[4] == "none" ? null : bk(a[4]);
						if( nb != null && nb.type == BTWater ) w.setWater(x, y, z, nb, WorldProcess.PLACED) else w.setBlock(x, y, z, nb);
						g.process.onSet(x, y, z, old, nb);
					}
					Sys.println(a[0] + " " + x + "," + y + "," + z + " antes=" + (old == null ? "aire" : "" + old.k));
				case "shore":
					// shore: busca una orilla (agua al nivel del mar con roca o tierra al lado) y pone ahi al jugador mirando al agua
					var wl = w.waterLevel(), found = false;
					for( y in 0...w.size ) {
						for( x in 0...w.size ) {
							var b = w.block(x, y, wl - 1);
							if( b == null || b.type != BTWater ) continue;
							var s = w.block(x + 1, y, wl - 1);
							if( s == null || !s.collide || w.block(x + 1, y, wl + 1) != null ) continue;
							g.px = x + 1.5; g.py = y + 0.5; g.pz = w.topCollide(x + 1, y) + 0.01;
							g.yaw = Math.PI; g.pitch = -0.6;
							shoreX = x; shoreY = y;
							Sys.println("shore agua=" + x + "," + y + "," + (wl - 1) + " suelo=" + (x + 1) + " top=" + Std.int(g.pz) + " mar=" + wl);
							found = true;
							break;
						}
						if( found ) break;
					}
					if( !found ) {
						var hist = new Map<Int, Int>();
						for( y in 0...w.size ) for( x in 0...w.size ) for( z in 1...World.HEIGHT ) {
							var b = w.block(x, y, z);
							if( b != null && b.type == BTWater ) { var c = hist.get(z); hist.set(z, c == null ? 1 : c + 1); }
						}
						Sys.println("shore: no hay orilla; mar=" + wl + " bioma=" + w.biomeName + " agua por altura=" + [for( k in hist.keys() ) k + ":" + hist.get(k)].join(" "));
					}
				case "shoredig":
					// shoredig N: zanja de N bloques tierra adentro desde la orilla, de la superficie hasta 2 bajo el mar
					var wl = w.waterLevel();
					for( i in 1...Std.parseInt(a[1]) + 1 ) {
						var x = shoreX + i, y = shoreY;
						var z = w.topCollide(x, y);
						while( z >= wl - 2 ) {
							var old = w.block(x, y, z);
							if( old != null ) g.breakBlock(x, y, z, old);
							z--;
						}
					}
				case "shorelvl":
					// shorelvl N: nivel del agua en la zanja, columna a columna (m = mar, p = puesta, 1..4 = pasos)
					var out = [];
					for( i in 1...Std.parseInt(a[1]) + 1 ) {
						var col = [];
						for( z in w.waterLevel() - 4...w.waterLevel() + 1 ) {
							var b = w.block(shoreX + i, shoreY, z);
							if( b == null || b.type != BTWater ) { col.push("."); continue; }
							var l = w.waterLevelAt(shoreX + i, shoreY, z);
							col.push(l == 0 ? "m" : (l == WorldProcess.PLACED ? "p" : "" + l));
						}
						out.push(col.join(""));
					}
					Sys.println("zanja (de abajo arriba): " + out.join(" | "));
				case "shorecount":
					var n = 0;
					for( i in 1...Std.parseInt(a[1]) + 1 )
						for( z in 1...World.HEIGHT ) {
							var b = w.block(shoreX + i, shoreY, z);
							if( b != null && b.type == BTWater ) n++;
						}
					Sys.println("agua en la zanja: " + n);
				case "wlvl":
					// wlvl X1 Y1 X2 Y2: agua por altura y nivel (0 = fuente, 8 = cae)
					var h = new Map<String, Int>();
					for( x in Std.parseInt(a[1])...Std.parseInt(a[3]) + 1 )
						for( y in Std.parseInt(a[2])...Std.parseInt(a[4]) + 1 )
							for( z in 1...World.HEIGHT ) {
								var b = w.block(x, y, z);
								if( b == null || b.type != BTWater ) continue;
								var k = "z" + z + "/n" + w.waterLevelAt(x, y, z);
								var c = h.get(k);
								h.set(k, c == null ? 1 : c + 1);
							}
					var ks = [for( k in h.keys() ) k];
					ks.sort(Reflect.compare);
					Sys.println("wlvl " + [for( k in ks ) k + "=" + h.get(k)].join(" "));
				case "palette":
					@:privateAccess app.openPalette();
					if( a.length > 1 && app.palette != null ) for( i in 0...Std.parseInt(a[1]) ) app.palette.scroll(1);
				case "palnav":
					// palnav left|right|up|down|lb|rb|a: como la cruceta, LB/RB o A del mando con la paleta abierta
					var k = a[1];
					if( app.palette != null ) app.palette.nav(k == "left" ? -1 : k == "right" ? 1 : 0, k == "up" ? -1 : k == "down" ? 1 : 0, k == "lb" ? -1 : k == "rb" ? 1 : 0, k == "a");
				case "palhover":
					// palhover N [out]: el raton entra en la casilla N de la pagina de la paleta (out: sale de ella)
					if( app.palette != null ) app.palette.devHover(Std.parseInt(a[1]), a[2] != "out");
				case "row":
					// row X1 X2 Y Z: nivel del agua en una fila (m = mar, p = puesta, 1..4 = pasos, . = sin agua)
					var y = Std.parseInt(a[3]), z = Std.parseInt(a[4]), out = [];
					for( x in Std.parseInt(a[1])...Std.parseInt(a[2]) + 1 ) {
						var b = w.block(x, y, z);
						if( b == null || b.type != BTWater ) { out.push("."); continue; }
						var l = w.waterLevelAt(x, y, z);
						out.push(l == 0 ? "m" : (l == WorldProcess.PLACED ? "p" : "" + l));
					}
					Sys.println("fila z=" + z + ": " + out.join(""));
				case "filla":
					// filla x1 y1 x2 y2 z1 z2 BLOQUE: rellena un prisma con alturas absolutas
					var bb = a[7] == "none" ? null : bk(a[7]);
					for( x in Std.parseInt(a[1])...Std.parseInt(a[3]) + 1 )
						for( y in Std.parseInt(a[2])...Std.parseInt(a[4]) + 1 )
							for( z in Std.parseInt(a[5])...Std.parseInt(a[6]) + 1 )
								w.setBlock(x, y, z, bb);
				case "top":
					Sys.println("top " + a[1] + "," + a[2] + " = " + w.topCollide(Std.parseInt(a[1]), Std.parseInt(a[2])));
				case "count":
					// count BLOQUE X1 Y1 X2 Y2: cuantos hay en esa zona (todas las alturas)
					var kb = bk(a[1]), n = 0;
					for( x in Std.parseInt(a[2])...Std.parseInt(a[4]) + 1 )
						for( y in Std.parseInt(a[3])...Std.parseInt(a[5]) + 1 )
							for( z in 1...World.HEIGHT )
								if( w.block(x, y, z) == kb ) n++;
					Sys.println("count " + a[1] + " = " + n);
				case "fillt":
					// fillt x1 y1 x2 y2 dz1 dz2 BLOQUE: rellena un prisma; dz es la altura sobre el punto mas alto de la zona
					var base = 0;
					for( x in Std.parseInt(a[1])...Std.parseInt(a[3]) + 1 )
						for( y in Std.parseInt(a[2])...Std.parseInt(a[4]) + 1 ) {
							var t = w.topCollide(x, y);
							if( t > base ) base = t;
						}
					var bb = a[7] == "none" ? null : bk(a[7]);
					for( x in Std.parseInt(a[1])...Std.parseInt(a[3]) + 1 )
						for( y in Std.parseInt(a[2])...Std.parseInt(a[4]) + 1 )
							for( z in base + Std.parseInt(a[5])...base + Std.parseInt(a[6]) + 1 )
								w.setBlock(x, y, z, bb);
				case "activate", "activatel":
					var l = a[0] == "activatel";
					var x = Std.parseInt(a[1]) + (l ? sdx : 0), y = Std.parseInt(a[2]) + (l ? sdy : 0), z = Std.parseInt(a[3]) + (l ? sz : 0);
					var b = w.block(x, y, z);
					Sys.println("activar " + x + "," + y + "," + z + ": " + (b == null ? "nada" : "" + b.k));
					if( b != null ) g.activateBlock(x, y, z, b);
					if( @:privateAccess app.current != null ) inPause = true; // el ordenador de a bordo abre un menu: el guion sigue en el (close lo cierra)
				case "synth":
					var c = g.ship.crafts[Std.parseInt(a[1])];
					g.ship.activateCraft(c.out.x + sdx, c.out.y + sdy, c.out.z + sz, g);
				case "explore": app.startExplorer();
				case "expsys": app.explorer.devClickSystem(Std.parseInt(a[1]));
				case "expplanet": app.explorer.devClickPlanet(Std.parseInt(a[1]));
				case "expbutton": app.explorer.devPressButton();
				case "expgo": app.explorer.devClickPoint(f(a[1]), f(a[2]));
				case "expgor": app.explorer.devClickPoint(f(a[1]), f(a[2]), true); // expgor DX DY: punto relativo a la nave
				case "expangle": Sys.println(app.explorer.devShipAngle());
				case "expship": app.explorer.devDumpShip("port/out/" + a[1] + ".png");
				case "expinfo": Sys.println(app.explorer.devInfo());
				case "exprobot": app.explorer.devClickRobot();
				case "exprinfo": Sys.println(app.explorer.devRobotInfo());
				case "exppause": @:privateAccess app.openMapPause(); // Esc en el mapa
				case "landhome": app.devLandHome(); // aterrizar en el planeta del que despegaste
				case "reload": app.devReload(); // Menu principal y Continuar con esta partida
				case "newgame": newGame(app, a.slice(1));
				case "expesc": app.explorer.escape(); // Esc o Start del mando en el mapa
				case "screen2": @:privateAccess app.show(a[1]); // abre una pantalla de menu sin cambiar de estado
				case "setlang":
					// setlang es|en|fr: como el selector de idioma de Opciones > General
					Settings.lang = a[1];
					Lang.setCode(a[1]);
					Settings.save();
					@:privateAccess app.rebuildScreens("options.general");
					Sys.println("pantalla " + @:privateAccess app.currentName + " mapa " + (app.explorer != null) + " pausa " + (app.explorer != null && app.explorer.paused));
				case "closewin":
					// closewin: lo que hace la X de la ventana (guardar), sin cerrar el juego
					hxd.Window.getInstance().onClose();
					var i = SaveData.read(app.curInfo().id);
					var u = i != null ? i.uni : null;
					Sys.println("guardado: pos " + (u != null ? "" + u.pos : "-") + (u != null && u.space == true ? " en el espacio" : "") + (u != null && u.ship != null ? " nave " + Std.int(u.ship.x) + "," + Std.int(u.ship.y) : ""));
				case "walk":
					g.debugSpeed = f(a[1]) * 0.15;
					g.debugStrafe = a.length > 2 ? f(a[2]) * 0.15 : 0;
				case "jet": g.debugJet = a[1] == "1";
				case "press", "release":
					// eventos de teclado de la ventana: hxd.Key los ve como si se hubieran pulsado (isPressed en la siguiente actualizacion)
					for( n in a.slice(1) ) keyEvent(a[0] == "press", keyCode(n));
				case "tap":
					keyEvent(true, keyCode(a[1]));
					tapKey = keyCode(a[1]);
				case "type":
					var text = l.substr(l.indexOf(" ") + 1);
					for( i in 0...text.length ) {
						var e = new hxd.Event(ETextInput);
						e.charCode = text.charCodeAt(i);
						hxd.Window.getInstance().event(e);
					}
				case "wheel":
					var e = new hxd.Event(EWheel);
					e.wheelDelta = f(a[1]);
					hxd.Window.getInstance().event(e);
				case "mouse":
					// de la zona W x H a pixeles de la ventana (LetterBox)
					var area = Ui.Theme.visibleArea(), eng = h3d.Engine.getCurrent();
					var mx = (f(a[1]) - area.x) * eng.width / area.w, my = (f(a[2]) - area.y) * eng.height / area.h;
					var win = hxd.Window.getInstance();
					win.event(new hxd.Event(EMove, mx, my));
					if( a[3] == "click" ) {
						win.event(new hxd.Event(EPush, mx, my));
						win.event(new hxd.Event(ERelease, mx, my));
					}
				case "menu":
					@:privateAccess app.toMainMenu();
					inMenu = true;
				case "devsaves": app.devSaves(Std.parseInt(a[1]));
				case "trace": trace = true;
				case "shop": app.openShop();
				case "screen": @:privateAccess app.show(a[1]);
				case "winsize":
					// winsize ANCHO ALTO: tamano de la ventana, para probar ventanas mas anchas o mas altas que 16:9
					hxd.Window.getInstance().resize(Std.parseInt(a[1]), Std.parseInt(a[2]));
				case "cover":
					// cover NOMBRE: lo abierto tapa toda la ventana? (y guarda port/out/cover_NOMBRE.png con solo eso dibujado)
					Sys.println("cover " + (a.length > 1 ? a[1] + " " : "") + app.devCover(a[1]));
				case "close":
					// close: cierra la tienda, el cofre, la paleta, el mapa de estrellas o el menu abierto (como Esc)
					@:privateAccess {
						app.closeChest();
						app.closeShop();
						app.closeContracts();
						app.closePalette();
						if( app.explorer != null ) app.devLandHome(); // del mapa se sale aterrizando
						if( app.current != null ) app.resume();
					}
					inPause = false;
				case "pause":
					@:privateAccess app.pause();
					inPause = true;
				case "f2":
					// como la tecla: soltar y pulsar F2; la captura se hace en la siguiente actualizacion
					var win = hxd.Window.getInstance();
					for( k in [hxd.Event.EventKind.EKeyUp, hxd.Event.EventKind.EKeyDown] ) {
						var e = new hxd.Event(k);
						e.keyCode = hxd.Key.F2;
						win.event(e);
					}
				case "creative": @:privateAccess g.creative = true;
				case "maxfps": Settings.maxFps = Std.parseInt(a[1]);
				case "fps": Sys.println("fps " + Std.int(hxd.Timer.fps()));
				case "helptext": Settings.showHelp = a[1] == "1"; // helptext 0|1: opcion de ayuda en pantalla
				case "hangar": app.startHangar();
				case "computer":
					// el menu del ordenador de a bordo, como al activarlo (el guion sigue; close lo cierra)
					@:privateAccess app.openComputer();
					inPause = true;
				case "tuto":
					// tuto new|notuto [semilla]: partida de aventura nueva, en el espacio (con o sin tutorial); tuto step N; tuto skip
					switch( a[1] ) {
					case "new", "notuto": app.devNewGame(a[1] == "new", a.length > 2 ? Std.parseInt(a[2]) : 1234);
					case "step": if( app.curInfo().tuto != null ) app.curInfo().tuto.step = Std.parseInt(a[2]);
					case "skip": app.skipTutorial();
					case "ask": @:privateAccess app.askSkip(app.current); // la ventana de confirmacion (con la pausa abierta)
					case "rule":
						// tuto rule place|break x y z Bloque: lo que dicen las reglas del hangar del tutorial (null = se puede)
						var r = g.hangarRule;
						Sys.println("regla " + a[2] + " " + a[3] + "," + a[4] + "," + a[5] + " " + a[6] + ": " + (r == null ? "sin reglas" : "" + r(a[2] == "place", Std.parseInt(a[3]), Std.parseInt(a[4]), Std.parseInt(a[5]), bk(a[6]))));
					case "view":
						// de pie a 6 bloques del primer objetivo, por su lado libre, mirandolo (para las capturas)
						var t = @:privateAccess app.tutorial.targets(g)[0];
						if( t != null ) {
							var d = [1, 0];
							for( o in [[-1, 0], [1, 0], [0, -1], [0, 1]] ) if( w.block(t.x + o[0], t.y + o[1], t.z) == null ) d = o;
							lines.insert(pc, "lookat " + (t.x + 0.5) + " " + (t.y + 0.5) + " " + (t.z + 0.5));
							lines.insert(pc, "tp " + (t.x + 0.5 + d[0] * 6) + " " + (t.y + 0.5 + d[1] * 6) + " top");
						}
					case "goto", "mine", "activate":
						// sobre el primer objetivo marcado: goto = de pie a 1,5 bloques mirandolo; mine y activate como esas ordenes
						var t = @:privateAccess app.tutorial.targets(g)[0];
						if( t == null ) Sys.println("tuto " + a[1] + ": sin objetivo");
						else if( a[1] == "goto" ) {
							// en una celda libre junto a el (con sitio para la cabeza): el hueco del risco, el lado del filon
							var at = null;
							for( o in [[-1, 0, 0], [1, 0, 0], [0, -1, 0], [0, 1, 0], [0, 0, 1]] )
								if( at == null && w.block(t.x + o[0], t.y + o[1], t.z + o[2]) == null && w.block(t.x + o[0], t.y + o[1], t.z + o[2] + 1) == null )
									at = { x : t.x + o[0], y : t.y + o[1], z : t.z + o[2] };
							lines.insert(pc, "lookat " + (t.x + 0.5) + " " + (t.y + 0.5) + " " + (t.z + 0.5));
							lines.insert(pc, at == null ? "tp " + (t.x - 1.5) + " " + (t.y + 0.5) + " top" : "tp " + (at.x + 0.5) + " " + (at.y + 0.5) + " " + at.z);
						} else {
							// mine: despues se pone en la celda que queda libre para recoger lo que suelta
							if( a[1] == "mine" ) {
								lines.insert(pc, "wait 40");
								lines.insert(pc, "tp " + (t.x + 0.5) + " " + (t.y + 0.5) + " " + t.z);
							}
							lines.insert(pc, a[1] + " " + t.x + " " + t.y + " " + t.z);
						}
					}
				case "mothership": app.startMothership();
				case "settop":
					// pone un bloque encima del primero que haya en la columna (para probar el hangar)
					var x = Std.parseInt(a[1]), y = Std.parseInt(a[2]), z = 14;
					while( z > 0 && w.block(x, y, z) == null ) z--;
					w.setBlock(x, y, z + 1, bk(a[3]));
					Sys.println("settop " + x + "," + y + "," + (z + 1));
				case "hangarexit": if( g != null && g.onHangarExit != null ) g.onHangarExit(); // sin partida (en el mapa) no hace nada
				case "chestclick": if( app.chest != null ) app.chest.click(Std.parseInt(a[1]), Std.parseInt(a[2]));
				case "chestfocus": if( app.chest != null ) app.chest.devFocus(Std.parseInt(a[1]), Std.parseInt(a[2]));
				case "shopclose": if( app.shop != null ) @:privateAccess app.closeShop();
				case "contracts":
					switch( a[1] ) {
					case null: app.openContracts();
					case "close": app.closeContracts();
					case "slot":
						var s = Std.parseInt(a[2]);
						Contracts.devSlot = s < 0 ? null : s;
					case "fill":
						var c = Contracts.board(Contracts.slot())[Std.parseInt(a[2])];
						g.inv.addBlocks(c.block, c.n);
					case "load": @:privateAccess Contracts.config = Contracts.load(a[2]);
					default:
					}
				case "deliver":
					// deliver i: entrega el contrato i (con el panel abierto, como su boton)
					var i = Std.parseInt(a[1]);
					var ok = app.contracts != null ? app.contracts.deliver(i) : Contracts.deliver(g.info, g.inv, i);
					Sys.println("deliver " + i + " -> " + (ok ? "entregado" : "rechazado") + " creditos=" + g.info.credits);
				case "shopnav": if( app.shop != null ) app.shop.devNav(Std.parseInt(a[1]), Std.parseInt(a[2]), a[3] == "a");
				case "buy", "sell":
					// buy CLAVE n / sell CLAVE n (clave de Market: b<bloque> o c<carga>; o el nombre del bloque, p.ej. BWood)
					var w = Market.ware(a[1]);
					if( w == null ) w = Market.wareOfBlock(bk(a[1]));
					if( app.shop != null ) { if( a[0] == "buy" ) app.shop.doBuy(w, Std.parseInt(a[2])) else app.shop.doSell(w, Std.parseInt(a[2])); }
					Sys.println(a[0] + " " + w.block.k + " x" + a[2] + " -> creditos=" + g.info.credits + " compra=" + g.market.buyPrice(w) + " venta=" + g.market.sellPrice(w));
				case "mine":
					// mine X Y Z: apunta al centro del bloque, excava con el excavador y dice cuanto tarda en romperse
					var x = Std.parseInt(a[1]), y = Std.parseInt(a[2]), z = Std.parseInt(a[3]);
					var dx = x + 0.5 - g.px, dy = y + 0.5 - g.py, dz = z + 0.5 - (g.pz + GameView.VIEW_Z);
					g.yaw = Math.atan2(dy, dx);
					g.pitch = Math.atan2(dz, Math.sqrt(dx * dx + dy * dy));
					g.inv.select(0);
					g.debugKey = "dig";
					mining = { x : x, y : y, z : z, b : w.block(x, y, z), t0 : g.playSeconds, power : g.miningPower };
				case "key": g.debugKey = a[1];
				case "unkey": g.debugKey = null;
				case "print": print(a, g, app);
				case "loadshot":
					loadShot = a[1];
					loadShotWait = a.length > 2 ? Std.parseInt(a[2]) : 5;
				case "shot":
					// "%b" = bioma: un mismo guion sirve para varios biomas (--bgbiome)
					app.capture("port/out/" + (w != null ? StringTools.replace(a[1], "%b", w.biomeName) : a[1]) + ".png", false);
				case "quit":
					return true;
				default:
					Sys.println("orden desconocida: " + l);
				}
			} catch( e : Dynamic ) {
				Sys.println("ERROR en '" + l + "': " + e);
			}
			// tras cada orden se deja pasar una actualizacion para que el juego la procese
			return false;
		}
		return true;
	}

	/** orden newgame: el formulario de Nueva partida, buscando sus filas por el titulo (como las ve el jugador) */
	function newGame( app : GalaxyApp, args : Array<String> ) @:privateAccess {
		if( app.game != null || app.explorer != null ) app.toMainMenu();
		app.show("new");
		var biome : Ui.Selector = null, seed : Ui.TextField = null, create : Ui.Widget = null;
		for( w in app.current.widgets ) {
			// el bioma solo se elige en creativo (PR 54): se pasa el modo a Creativo antes
			if( Std.isOfType(w, Ui.Selector) && cast(w, Ui.Selector).title == Lang.t("mode") ) {
				var m : Ui.Selector = cast w;
				m.index = 1;
				m.onChange(1);
			}
			if( Std.isOfType(w, Ui.Selector) && cast(w, Ui.Selector).title == Lang.t("biome") ) biome = cast w;
			else if( Std.isOfType(w, Ui.TextField) && cast(w, Ui.TextField).title == Lang.t("seed") ) seed = cast w;
			else if( w.label.text == Lang.t("create") ) create = w;
		}
		seed.input.text = args[0];
		// un clic del raton en la fila del bioma a la altura x (h2d.Interactive.onClick con relX)
		function click( x : Float ) {
			app.current.setFocus(app.current.widgets.indexOf(biome));
			biome.inter.onClick(new hxd.Event(ERelease, x, biome.h * 0.5));
		}
		var v = biome.value;
		for( act in args.slice(1) ) {
			var before = biome.choices[biome.index];
			switch( act ) {
			case "izq": biome.onLeft();
			case "der": biome.onRight();
			case "ok": biome.activate();
			case "clic<": click(v.x + 6);
			case "clic>": click(v.x + v.textWidth * v.scaleX - 6);
			case "clicfila": click(40);
			default: Sys.println("newgame: accion desconocida " + act);
			}
			Sys.println("newgame " + act + ": " + before + " -> " + biome.choices[biome.index]);
		}
		Sys.println("formulario: bioma " + biome.choices[biome.index] + " (" + biome.index + "), semilla " + seed.input.text);
		create.activate();
		Sys.println("partida creada: " + app.loadInfo.name + " bioma " + app.loadInfo.biome + " semilla " + app.loadInfo.seed);
	}

	function print( a : Array<String>, g : GameView, app : GalaxyApp ) {
		if( a[1] == "screen" ) {
			Sys.println("pantalla " + @:privateAccess app.currentName);
			return;
		}
		if( a[1] == "menu" ) {
			Sys.println(app.devMenuInfo());
			return;
		}
		if( a[1] == "saves" ) {
			Sys.println(app.devSavesInfo());
			return;
		}
		if( a[1] == "shots" ) {
			// capturas de F2: tamano del PNG, si es el de la ventana y si es opaca
			var dir = Settings.dir() + "/screenshots";
			var files = sys.FileSystem.exists(dir) ? sys.FileSystem.readDirectory(dir) : [];
			files.sort(Reflect.compare);
			var eng = h3d.Engine.getCurrent();
			Sys.println("capturas F2: " + files.length + " (ventana " + eng.width + "x" + eng.height + ")");
			for( f in files ) {
				var d = new format.png.Reader(new haxe.io.BytesInput(sys.io.File.getBytes(dir + "/" + f))).read();
				var hd = format.png.Tools.getHeader(d);
				var px = format.png.Tools.extract32(d);
				var opaque = true;
				for( i in 0...hd.width * hd.height )
					if( px.get(i * 4 + 3) != 0xFF ) {
						opaque = false;
						break;
					}
				Sys.println("  " + f + " " + hd.width + "x" + hd.height + (hd.width == eng.width && hd.height == eng.height ? " = ventana" : " DISTINTO DE LA VENTANA") + (opaque ? ", opaca" : ", CON TRANSPARENCIA"));
			}
			return;
		}
		if( a[1] == "tuto" ) {
			// paso, bloques del tutorial, objetivos marcados y texto (tambien en el mapa)
			var info = app.curInfo(), t = @:privateAccess app.tutorial;
			var sp = info.tuto == null || info.tuto.spots == null ? [] : info.tuto.spots;
			var spots = [for( i in 0...Std.int(sp.length / 4) ) Block.all[sp[i * 4 + 3]].k + "@" + sp[i * 4] + "," + sp[i * 4 + 1] + "," + sp[i * 4 + 2]
				+ (g != null && g.world.block(sp[i * 4], sp[i * 4 + 1], sp[i * 4 + 2]) == Block.all[sp[i * 4 + 3]] ? "" : "(recogido)")];
			Sys.println("tuto: " + (info.tuto == null ? "no" : "paso " + info.tuto.step) + " objetivos " + [for( o in t.targets(g) ) o.x + "," + o.y + "," + o.z].join(" ")
				+ "\n  bloques: " + spots.join(" ") + "\n  cargas: " + [for( c in (g != null ? g.inv.inv : info.inv).charges )Type.createEnumIndex(ChargeKind, c.c) + "x" + c.n].join(" ")
				+ "\n  texto: " + t.text(info, g));
			return;
		}
		if( g == null ) {
			// en el mapa de estrellas
			var u = app.curInfo().uni;
			Sys.println("pos: espacio " + u.pos + (u.ship != null ? " nave " + Std.int(u.ship.x) + "," + Std.int(u.ship.y) : "") + " recorrido " + Std.int(u.traveled));
			return;
		}
		var w = g.world;
		switch( a[1] ) {
		case "names":
			// nombres de unos bloques en los tres idiomas ("all" = todos, con el indice y si se puede apuntar)
			var cur = Lang.cur;
			var all = a[2] == "all";
			for( k in (all ? [for( b in Block.all ) Type.enumConstructor(b.k)] : a.slice(2)) ) {
				var b = bk(k);
				var s = [];
				for( i in 0...3 ) { Lang.setCode(Lang.CODES[i]); s.push(b.getName()); }
				Sys.println((all ? b.index + " " : "") + k + (all && !b.hasProp(PCanPick) ? " (nopick)" : "") + ": " + s.join(" | "));
			}
			Lang.setCode(Lang.CODES[cur]);
		case "snd":
			// print snd NOMBRE: veces que ha sonado desde el ultimo print snd de ese sonido
			var n = Snd.played.get(a[2]);
			Snd.played.remove(a[2]);
			Sys.println("sonido " + a[2] + ": " + (n == null ? 0 : n));
		case "lightsum":
			// suma de la luz en un cubo (x y z radio): para comprobar que tras editar y deshacer queda igual
			var x = Std.parseInt(a[2]), y = Std.parseInt(a[3]), z = Std.parseInt(a[4]), r = Std.parseInt(a[5]);
			var s = 0, dark = 0;
			for( dz in -r...r + 1 ) for( dy in -r...r + 1 ) for( dx in -r...r + 1 ) {
				var v = @:privateAccess w.lightAt(x + dx, y + dy, z + dz);
				s += v;
				if( v == 0 && w.block(x + dx, y + dy, z + dz) == null ) dark++;
			}
			Sys.println("luz " + s + " huecos a oscuras " + dark);
		case "credits":
			Sys.println("creditos: " + g.info.credits);
		case "contracts":
			// periodo, tablero (bloque, cantidad, recompensa, lo que llevas, entregado), tiempo hasta el siguiente y creditos
			var board = Contracts.board(Contracts.slot());
			Sys.println("contratos: periodo " + Contracts.slot() + " | " + [for( i in 0...board.length ) {
				var c = board[i];
				i + " " + c.block.k + " x" + c.n + " +" + c.reward + " llevas " + Contracts.have(g.inv, c.block) + (Contracts.isDone(g.info, i) ? " ENTREGADO" : "");
			}].join(" | ") + " | quedan " + Std.int(Contracts.remaining()) + " s creditos=" + g.info.credits + " panel=" + (app.contracts != null)
				+ " boton=" + (@:privateAccess app.computerContracts == null ? "-" : "" + @:privateAccess app.computerContracts.enabled));
		case "menu":
			// botones del menu abierto (etiqueta y y), de arriba abajo
			Sys.println("menu: " + (@:privateAccess app.current == null ? "cerrado" : [for( wd in @:privateAccess app.current.widgets ) @:privateAccess wd.label.text + "@" + Std.int(wd.y)].join(" | ")));
		case "palette":
			Sys.println("paleta: " + (app.palette == null ? "cerrada" : app.palette.devInfo()));
		case "time":
			Sys.println("tiempo: " + Std.int(g.playSeconds));
		case "life":
			// vida, tiempo de juego y ritmo desde el ultimo `print life` (vida por segundo)
			var t = g.playSeconds;
			var rate = lifeT < 0 || t <= lifeT ? "" : " ritmo " + Math.round((g.life - lifeV) / (t - lifeT) * 100) / 100 + "/s en " + Math.round((t - lifeT) * 10) / 10 + " s";
			Sys.println("vida " + Math.round(g.life * 100) / 100 + " t " + Math.round(t * 100) / 100 + rate + " z " + Math.round(g.pz * 100) / 100 + " suelo " + (g.standingBlock == null ? "-" : "" + g.standingBlock.k));
			lifeV = g.life;
			lifeT = t;
		case "sea":
			// nivel del mar, contador y agua del bioma en la capa de arriba, en la de encima y en la de debajo
			var wl = w.waterLevel(), cnt = [0, 0, 0];
			for( y in 0...w.size ) for( x in 0...w.size ) for( i in 0...3 )
				if( w.block(x, y, wl + 1 - i) == w.seaBlock ) cnt[i]++;
			Sys.println("mar: nivel " + wl + " (generador " + @:privateAccess w.gen.getWaterInfos().level + ") inundacion " + w.waterFlood + "/" + w.floodThreshold()
				+ " total " + w.waterTotal + " agua z" + (wl + 1) + "=" + cnt[0] + " z" + wl + "=" + cnt[1] + " z" + (wl - 1) + "=" + cnt[2]
				+ " trozos pendientes " + @:privateAccess w.seaChunks.length + (@:privateAccess w.seaJob != null ? " (luz a medias)" : ""));
		case "lightcheck":
			Sys.println("luz: " + w.debugLightCheck());
		case "hangar":
			Sys.println("hangar: " + (g.hangar == null ? "no" : "valida=" + g.hangarValid + " error=" + g.hangar.error + " velocidad=" + g.hangar.speed) + " mensaje=" + g.message);
		case "wares":
			for( m in Market.wares ) Sys.println("ware " + m.block.k + " " + m.base);
		case "inv":
			Sys.println("inv: " + [for( s in g.inv.inv.t ) s == null ? "-" : Block.all[s.k].k + "x" + s.n].join(" ") + "  casilla=" + g.inv.blockIndex);
		case "pos":
			Sys.println("pos: " + g.px + "," + g.py + "," + g.pz + "  yaw=" + g.yaw + " pitch=" + g.pitch + "  suelo=" + (g.standingBlock == null ? "-" : "" + g.standingBlock.k));
		case "hud":
			// texto de arriba a la izquierda (coordenadas y fps de la tecla F, ayuda en pantalla) en una linea
			Sys.println("hud: " + @:privateAccess app.hud.text.split("\n").join(" | "));
		case "zones":
			for( i in 0...g.ship.crafts.length ) {
				var c = g.ship.crafts[i];
				Sys.println("zona " + i + " (local): x=" + c.x + ".." + (c.x + c.w - 1) + " y=" + c.y + ".." + (c.y + c.h - 1) + " z=" + c.z + " alto=" + c.zSize
					+ (c.out == null ? "" : "  ordenador=" + c.out.x + "," + c.out.y + "," + c.out.z) + "  receta=" + (c.curCraft == null ? "-" : "" + c.curCraft.out));
			}
			Sys.println("nave: entrada local de salida en planeta=" + g.ship.start.x + "," + g.ship.start.y + "," + g.ship.start.z + "  desplazamiento=" + w.shipDX + "," + w.shipDY);
		case "map":
			// corte horizontal de la nave a la altura local z (por defecto la del jugador): letra = inicial del bloque, '.' = aire, '@' = jugador
			var z = a.length > 2 ? Std.parseInt(a[2]) : Std.int(g.pz) - World.SHIP_Z;
			var ox = Std.int(g.px) - w.shipDX, oy = Std.int(g.py) - w.shipDY;
			Sys.println("corte local z=" + z + "  (x " + (ox - 12) + ".." + (ox + 12) + ", y hacia abajo " + (oy - 8) + ".." + (oy + 8) + ")");
			for( dy in -8...9 ) {
				var row = "";
				for( dx in -12...13 ) {
					var b = w.block(ox + dx + w.shipDX, oy + dy + w.shipDY, z + World.SHIP_Z);
					row += dx == 0 && dy == 0 ? "@" : (b == null ? "." : "" + ("" + b.k).charAt(1));
				}
				Sys.println(row);
			}
		case "cells":
			// bloques de la zona 0 del sintetizador (locales de la nave)
			var c = g.ship.crafts[0];
			var out = [];
			for( dx in 0...c.w ) for( dy in 0...c.h ) for( dz in 0...c.heights[dx][dy] ) {
				var b = w.block(c.x + dx + w.shipDX, c.y + dy + w.shipDY, c.z + dz + World.SHIP_Z);
				if( b != null ) out.push(b.k + "@" + (c.x + dx) + "," + (c.y + dy) + "," + (c.z + dz));
			}
			Sys.println("celdas de la zona: " + out.join("  ") + "   texto: " + c.curText);
		case "hit": Sys.println(g.debugPick());
		case "power":
			// potencia de excavacion (turbo minero) y el icono "power" del casco
			var ic = @:privateAccess app.statusIcon;
			Sys.println("potencia " + g.miningPower + " icono " + (ic.visible ? "visible alfa " + Math.round(ic.alpha * 100) / 100 : "no"));
		case "parts": Sys.println("trozos: " + @:privateAccess g.parts.list.length);
		case "mips": Sys.println("mipmaps del atlas: " + Math.round(Atlas.mipTime * 1000) + " ms");
		case "drops": Sys.println("sueltos: " + g.drops.count() + " " + [for( d in @:privateAccess g.drops.list ) d.block.k + " z=" + Math.round(d.z * 100) / 100 + " vida=" + Math.round(d.time * 100) / 100].join("  "));
		case "loose":
			// sueltos con su bloque, cantidad y posicion (en la nave, tambien la local: pilotar la mueve)
			var w = g.world;
			Sys.println("sueltos: " + [for( d in @:privateAccess g.drops.list ) d.block.k + "x" + d.n + "@" + Math.round(d.x * 100) / 100 + "," + Math.round(d.y * 100) / 100 + "," + Math.round(d.z * 100) / 100
				+ (d.z >= World.SHIP_Z ? " local " + (Math.round((d.x - w.shipDX) * 100) / 100) + "," + (Math.round((d.y - w.shipDY) * 100) / 100) : "")].join(" "));
		case "chest":
			// ventana de la cantina (abierta o no) y las cantinas de la partida con lo que tienen
			inline function items( t : Protocol.BlockInventory ) return [for( s in t ) s == null ? "-" : Block.all[s.k].k + "x" + s.n].join(" ");
			var c = app.chest;
			Sys.println("cantina: " + (c == null ? "cerrada" : "abierta [" + items(c.box) + "]") + "  guardadas: " + (g.info.chests == null ? "" : [for( e in g.info.chests ) e.key + " [" + items(e.t) + "]"].join(", ")));
		case "shake":
			// temblor, subida de la camara y del HUD (en pixeles de la ventana) de este fotograma, y segundos de juego
			inline function r( v : Float ) return Math.round(v * 1000) / 1000;
			var hudPx = @:privateAccess app.hudShake * h3d.Engine.getCurrent().width / Ui.Theme.visibleArea().w;
			Sys.println("temblor " + r(g.shake) + " camara " + r(g.shakeZ) + " hud " + r(hudPx) + " px  t=" + r(g.playSeconds));
		case "fov":
			// campo de vision de la camara y bloque en los ojos (en el agua: opcion * 0.8)
			var b = w.block(Math.floor(g.px), Math.floor(g.py), Std.int(g.pz + g.viewZ));
			Sys.println("fov " + Math.round(@:privateAccess g.s3d.camera.fovY * 100) / 100 + " opcion=" + Settings.fov + " ojos=" + (b == null ? "aire" : "" + b.k));
		case "msg": Sys.println("mensaje: " + g.message + (g.messageRed ? " (rojo)" : ""));
		case "block", "blockl":
			// blockl: coordenadas locales de la nave
			var l = a[1] == "blockl";
			var b = w.block(Std.parseInt(a[2]) + (l ? w.shipDX : 0), Std.parseInt(a[3]) + (l ? w.shipDY : 0), Std.parseInt(a[4]) + (l ? World.SHIP_Z : 0));
			Sys.println("bloque: " + (b == null ? "nada" : "" + b.k));
		case "around":
			// print around X Y Z R: bloques en el cubo de lado 2R+1 (planeta, nave y roca madre) y bombas por explotar
			var x = Std.parseInt(a[2]), y = Std.parseInt(a[3]), z = Std.parseInt(a[4]), r = Std.parseInt(a[5]);
			var n = 0, s = 0, bed = 0;
			for( dz in -r...r + 1 ) for( dy in -r...r + 1 ) for( dx in -r...r + 1 ) {
				var zz = z + dz;
				if( zz < 0 ) continue;
				var b = w.block(x + dx, y + dy, zz);
				if( b == null ) continue;
				if( zz >= World.SHIP_Z ) s++ else if( b.k == BBedrock ) bed++ else n++;
			}
			Sys.println("alrededor " + x + "," + y + "," + z + " r" + r + ": planeta " + n + " roca madre " + bed + " nave " + s + "  bombas en cola " + @:privateAccess g.bombQueue.length);
		case "fade":
			var f = g.fadeFX;
			Sys.println(f == null ? "fundido: ninguno" : "fundido: color " + StringTools.hex(f.col, 6) + " t=" + Math.round(f.t * 100) / 100 + " opacidad " + Math.round(g.fadeAlpha() * 100) / 100 + " bloqueo " + f.lock);
		case "land":
			// lo que deja un aterrizaje: aturdido > 0 impide saltar (Hero.hit: stun = 10), el casco baja con bobY
			inline function r( v : Float ) return Math.round(v * 1000) / 1000;
			Sys.println("aterrizaje: suelo " + (g.standingBlock == null ? "-" : "" + g.standingBlock.k) + " gravedad " + r(g.gravity) + " aturdido " + r(@:privateAccess g.stun)
				+ " casco " + r(g.bobY) + " temblor " + r(g.shake) + " fundido " + r(g.fadeAlpha()) + " vida " + r(g.life) + " creativo " + g.creative);
		case "select": Sys.println("select: " + (g.select == null ? "ninguno" : g.select.b.k + " @" + g.select.x + "," + g.select.y + "," + g.select.z + " poder=" + g.select.power));
		case "sky":
			// giro de las estrellas (Sky.follow): a donde apuntan los ejes x y z del cubo de estrellas
			var m = @:privateAccess w.sky.starRot;
			function r( v : Float ) return Math.round(v * 1000) / 1000;
			if( m == null ) Sys.println("cielo: sin estrellas");
			else Sys.println("cielo: x -> " + r(m._11) + "," + r(m._12) + "," + r(m._13) + "  z -> " + r(m._31) + "," + r(m._32) + "," + r(m._33));
			// dentro de un liquido (Sky.setLiquid): el color plano que tapa el degradado y si se ven las estrellas
			@:privateAccess {
				var flat = w.sky.dome.material.mainPass.getShader(h3d.shader.FixedColor);
				var st = w.sky.stars;
				Sys.println("cielo: " + (flat == null ? "degradado" : "color " + StringTools.hex(flat.color.toColor() & 0xFFFFFF, 6))
					+ ", estrellas " + (st != null && st.visible ? "si" : "no"));
			}
		case "biome":
			// bioma del mundo cargado, el de la partida y el de salida del universo; y el suelo que mas se ve (una columna de cada 8x8)
			var u = g.info.uni;
			var count = new Map<String, Int>();
			var y = 0;
			while( y < w.size ) {
				var x = 0;
				while( x < w.size ) {
					var z = World.HEIGHT - 1;
					while( z > 0 && (w.block(x, y, z) == null || w.block(x, y, z).type != BTFull) ) z--;
					var b = w.block(x, y, z);
					var k = b == null ? "-" : "" + b.k;
					count.set(k, (count.exists(k) ? count.get(k) : 0) + 1);
					x += 8;
				}
				y += 8;
			}
			var top = [for( k in count.keys() ) k];
			top.sort(function(a, b) return count.get(b) - count.get(a));
			Sys.println("bioma: mundo " + w.biomeName + ", partida " + g.info.biome + ", salida " + (u == null ? "-" : u.start.biome) + ", semilla " + g.info.seed
				+ ", suelo " + [for( k in top.slice(0, 3) ) k + "x" + count.get(k)].join(" "));
		case "pilotcam":
			// camara de pilotar (anadido del port): posicion, objetivo y centro de la nave
			var c = @:privateAccess g.s3d.camera, m = g.ship.center();
			Sys.println("camara " + [c.pos.x, c.pos.y, c.pos.z].map(v -> Math.round(v)) + " mira " + [c.target.x, c.target.y, c.target.z].map(v -> Math.round(v)) + " centro nave " + [m.x, m.y, m.z].map(v -> Math.round(v)) + " raiz " + [g.ship.world.root.x, g.ship.world.root.y, g.ship.world.root.z].map(v -> Math.round(v)));
		case "pilot":
			Sys.println("pilotando: " + (g.piloting ? "si" : "no") + " pausa: " + (@:privateAccess app.current != null) + " guardado shipAt: " + g.info.shipAt
				+ (g.ship != null ? " rumbo " + Math.round(g.ship.heading * 100) / 100 + " velocidad " + Math.round(Math.sqrt(@:privateAccess (g.pilotVX * g.pilotVX + g.pilotVY * g.pilotVY)) * 10) / 10 + " jugador " + Math.round(g.px * 100) / 100 + "," + Math.round(g.py * 100) / 100 : ""));
		case "ship":
			if( g.ship == null ) {
				Sys.println("sin nave (nave nodriza o hangar)");
				return;
			}
			var beam = @:privateAccess g.ship.beam;
			Sys.println("nave en " + g.ship.x + "," + g.ship.y + " suelo z=" + g.ship.z + (beam == null ? "" : " rayo z=" + beam.z + " alto=" + Math.round(beam.scaleZ * 100) / 100));
		default: Sys.println("print desconocido: " + a[1]);
		}
	}
}
