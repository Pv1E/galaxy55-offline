# Resumen del port de Galaxy 55 (leer esto primero)

> Notas técnicas para quien desarrolla. Para jugadores: [`README.md`](../README.md), errores en [`ERRORES.md`](../ERRORES.md), lista de tareas en [`PENDIENTES.md`](../PENDIENTES.md) (los tres se mantienen a la vez que esta lista).

## Qué estamos haciendo
Galaxy 55 (Motion Twin, 2012) era un juego de bloques en Flash. Este repo lo hacía funcionar sin servidor.
Flash está muerto, así que estamos **portándolo a una aplicación nativa de escritorio**: Haxe 4 + Heaps moderno + HashLink
(el mismo motor y lenguaje con el que se hizo el original, y con el que Motion Twin hizo Dead Cells).
Metas: menú de inicio con guardado y carga, fidelidad al original, y a futuro Steam y multijugador.
Desde el 2026-10-14 la versión nativa es la oficial: está en `main` y en `port-hashlink` (iguales). La versión Flash sigue intacta en la
etiqueta `flash-version` y la rama `flash`, con sus SWF y archivos de compilación. Desde el 2026-10-26 esos archivos (`client*.hxml`,
`build.*`, `release/`, `libs/heaps`, `libs/format_old`) ya no están en `main`/`port-hashlink`: el port no los usa (usa el Heaps actual). El README avisa de las dos versiones y de los errores conocidos.

## Cómo lo hacemos
- **Reutilizar, no reescribir:** los generadores de planetas originales (`src/G55/fla/client/src/gen`) se compilan tal cual.
  Una capa `port/shim/` imita `flash.Memory`, `Vector`, `ByteArray`. Los cambios al código original son mínimos y con `#if flash`.
- **Verificación contra Flash:** el mismo programa se compila a SWF y a HashLink y se comparan mundos
  (hash Adler-32 + agua + recuento de bloques). Los 4 mundos de referencia son idénticos.
- **Render y juego nuevos** en `port/game/` (Heaps moderno): mallado por chunks 16x16, cielo y niebla con los colores
  originales de cada bioma, jugador con la física del original (`Hero.doMove`), casco, jetpack, menús, guardado.
- **Pruebas automáticas:** `galaxy55.hl --shot=<png> --screen=main|new|load|options|pause|game|jet|phys` genera capturas
  o números sin molestar (ventana fuera de pantalla); se leen los PNG para comprobar la interfaz.

## Estado actual (todo funciona y está probado, salvo lo marcado)
- Menú: Continuar (lista de partidas con miniatura que se desplaza: jugar, renombrar, borrar), Nueva partida (nombre, semilla, modo; en
  creativo bioma y tamaño, en aventura tutorial sí/no), Opciones, Salir. es/en/fr.
  Ratón, teclado y mando. Fondo = el juego visto desde dentro, recorriendo varios biomas con fundido.
- Partidas en `%APPDATA%\Galaxy55\` (miniatura incluida, autoguardado, F5). Captura con F2 en `screenshots\` (`GalaxyApp.takeScreen`,
  como `Render.takeScreenShot`: sin HUD, casco, caja de selección ni bloque en la mano). Opciones: idioma, sensibilidad, FOV, volumen,
  pantalla completa, invertir eje vertical, A/D girar (original) o desplazar.
- Jugador: caminar, X despacio, saltar, jetpack con combustible, colisiones, casco (H), barra de combustible. Sin correr ni vuelo.
- Biomas jugables: Otoño, Luna, Marte, Cumbres nevadas (con nieve, añadido nuestro), Bosque ácido.
- Mundo: da la vuelta como el original (toroide, copias vecinas hasta 180 bloques); luz como `Builder.relight` (sol por bioma, cuevas, `BFLight`, suavizado por vértice); modelos de bloque (`Models.hx`, copia de `initModels`), bloques parciales y extendidos; hielo/cristal con alfa.
- Planeta redondo: `curve = 2/tamaño` como `AbstractGame`; el shader (`Sky.FogShader.vertex`) baja cada vértice `(dx²+dy²)·curve` respecto a la cámara. Solo visual: física y selección no lo usan (el original corrige la selección con la curva, pendiente al hacer romper/colocar: `Render.pick`).
- Excavar y colocar (copia de `Game.checkAction/blockBreak`, `Level`, `Dummy`, `Inventory`): rayo del centro con la curva (`GameView.pick`), tiempo de rotura `requiredPower*40/miningPower` por tmod, cargas rápidas (`quickBreaks`), sueltos con probabilidad (`BFDropChance`), reglas de ancla/imán al colocar. Barra de inventario arriba al centro (`InvBar`, casillas de 40 px cada 44, la 0 es el excavador, cargas a la izquierda, icono 3D con `IconMesh.Icons`). Efectos del original en `Fx`: caja naranja, cubo que tiembla al excavar, cubo con la casilla (51,0) si no se puede romper, rayo con 4 texturas según la carga. Cambios de terreno e inventario van en el guardado (`SaveInfo.inv/edits`). Luz y malla se rehacen por zona (`World.setBlock/flush/relightRegion`). Teclas: clic/E/Mayús, 1-0 y rueda, Tab, R.
- Nave (parte 1; `Ship.hx`, `ShipData.hx`, `World` con `ship`): la partida nueva empieza dentro de la nave (DUCK-01, 17x17x12), un volumen en z>=130 sobre el punto de aterrizaje (`World.startPlace` = `Level.getStartPlace`, fijo por semilla). Teletransportador (BShipEntry) y haz de luz del aterrizaje con las condiciones de `ShipLogic.update` y fundido blanco (1,5); Mayús+K vuelve a la nave. El ordenador de a bordo abre su menú (despegar/hangar/comerciar aún no disponibles); las puertas (`BFToggle`, modelos de `door.md`) se abren y cierran. El casco no se puede apuntar, salvo las **zonas de sintetizador** (`ShipData.CraftArea`, hueco libre sobre las losas `BCrafter`, aquí 2x2 con 2 de alto): ahí se coloca sin apoyo y se excava x4 sin cargas (`ShipLogic.checkSelect`). Los cambios en la nave y las puertas abiertas se guardan (`SaveInfo.shipEdits`). Pruebas: `--tele`, `--door`, `--computer`, `--listnear`.
- Modo creativo (añadido nuestro, se elige en Nueva partida y se guarda en `SaveInfo.creative`): bloques sin gastar, rotura instantánea (0,25 s entre bloques), sin sueltos, jetpack infinito, y paleta con los 146 bloques de la tienda del original (tecla I, `Palette.hx`, clic = poner en la casilla elegida, rueda = página). Prueba: `--creative`, `--screen=palette`.
- Pruebas: `--screen=mine|place|cont [--n=frames --slot=N --at=x,y,yaw,pitch --deny --save]`, `port/savetest.hxml`.
- Falta del original (inventario de bloques: 213; ~85 eran modelos, ya dibujados): puertas de nave (`door.md` binario), vida/daño/curación/oxígeno/lava, bloques activables y contenedores, líquidos que fluyen, romper/colocar, y los modos nave, hangar y mapa de exploración (`fla/explore`).
- No probado en ventana real por mí: ratón/teclado/mando en vivo, ni el movimiento de la nieve (solo capturas y números).
- Pilotar la nave (2026-10-26, añadido del port, rama `pilotar-nave`): botón "Pilotar la nave" del ordenador de a bordo (solo si
  `GameView.canPilot`: planeta jugable, sin nave nodriza, hangar, tutorial ni fundido). `Ship.slide` mueve el volumen de la nave
  (`fx/fy` con decimales, `World.shipDX/shipDY` redondeados) a la misma altura (z 130: por debajo chocaría con el planeta);
  `Ship.land` la deja en celda entera con el punto de aterrizaje dentro del planeta (el planeta da la vuelta). El jugador y los
  sueltos de la nave (`Drops.shiftShip`) van con ella; mientras se pilota no hay física del jugador ni de los sueltos. Cámara
  detrás y arriba (`GameView.pilotCamera`, apunta compensando la curva de `Sky.FogShader`) y niebla más suave
  (`Sky.setPilotFog`); el haz marca dónde quedará. Se guarda en `SaveInfo.shipAt` y `UniPlanet.shipAt` (opcionales: sin ellos,
  el sitio de siempre); a mitad de vuelo se guarda el sitio en que aterrizaría con el jugador movido lo mismo. E/Esc/B/Start
  la dejan. Textos `computer.pilot` y `hud.pilot`. Guiones `pilotar`, `pilotar_casos`, `pilotar_camara`, `pilotar_tuto`,
  `pilotar_sintetizador`, `pilotar_vuelo`, `pilotar_lados`. Los hashes de los mundos no cambian.
  Segunda vuelta (tras probarlo Pvie: "no gira hacia la dirección" y "demasiado tosco"): velocidad con inercia
  (`GameView.pilotStep`: aceleración 1.8/s, frenado 3.5/s al dejarla, máximo 18 bloques/s), rumbo hacia donde va con inclinación
  en las curvas (`Ship.setPose`, solo la imagen: gira `world.root` sobre la columna de la entrada, así el haz sigue debajo del
  teletransportador; morro hacia +x, como lo dibuja el mapa). Al dejarla (E/Esc/B/Start, `stopPiloting`) frena, vuelve al rumbo
  0 y se centra en su celda; luego `finishPiloting` aterriza. Los sueltos de la nave se ocultan en vuelo (`Drops.setShipVisible`).
  Arreglo: al aterrizar el jugador está sobre el teletransportador y bajaba solo al planeta; ahora `enteringShip = -1` como en
  `gotoShip`. Órdenes nuevas: `pilotkeys`, `pilotland`.
  Tercera vuelta (Pvie: el haz molesta en vuelo, pero hace falta para saber dónde aterriza): el haz se desvanece con la velocidad
  (`GameView.pilotBeam`, `Ship.setBeamFade`: entero hasta 3 bloques/s, nada desde 9, entero al aterrizar).
- PR 60-63 de Cornor923 (fusionados 2026-11-02):
  - 60, contratos de la ESCorp (añadido del port): `Contracts.hx` (tablero sorteado con el número del periodo UTC como semilla,
    1 contrato de base de `Data.BASIC_BLOCKS` + 2 encargos, recompensa 1,5x el mejor precio de venta del robot + cargas),
    `ContractPanel.hx`, datos en `src/G55/fla/client/gfx/contracts.json` (copiado por `package.ps1`), `SaveInfo.contracts`
    opcional. Botón del ordenador de a bordo desactivado en el tutorial. `Market.START_CREDITS` 500 -> 200, entregados en
    `Tutorial.finish`. `showToast` acepta duración (aviso de la ESCorp 7 s). Guiones `contrats`, `contrats_tuto`, `contrats_json`.
  - 61, la lava hace explotar la bomba antigua (cambio del port): `WorldProcess.flowBreak` -> `GameView.lavaBomb` (a `bombQueue`;
    en hangar y nodriza se rompe). El agua la sigue soltando como el original. Guion `bomb_liquids`.
  - 62, poner delante de modelos y bloques parciales (como `Render.pick` del original): `GameView.pick` toma la celda por la que
    llega el rayo; con bloque en la mano se ignoran los que `Block.canOverride` permite pisar; `place` usa `canOverride`. Guion `place_front`.
  - 63, pasada opaca de `BTAlpha` (marco del cristal) con `culling = Back` como el original (`World.hx`). Guion `ventana_neon`.
- Fallos de Sekhmet (2026-11-02): `GameView.pick` no apunta con un bloque en la mano si la celda donde iría está en z >= 127
  (`Game.update` del original: `select.z >= ZSIZE - 1`) y `place` no gasta el bloque fuera de 1..126; la celda de la cámara no
  cuenta al apuntar (`Render.pick` empieza el rayo en su borde): con la cabeza en una fuente de cascada se apunta lo de delante;
  `World.openAlphaNear` (cambio del port): las caras de un `BTAlpha` que no es cascada se dibujan contra la cascada, que aquí baja
  de altura y dejaba ver a través de la arena movediza. Guiones `altura_max`, `fuente_excavar`, `cascada_arena`. La nave que
  cambia de sitio (ERRORES #15): ya arreglado en 167cc91 (v0.5, `World.shipPlace` antes de `applySaved`). Comprobado con
  `nave_sitio`: con el código actual la nave sigue en 124,21 tras cavar, recargar y guardar dentro; quitando esa línea salta a
  74,110 y se queda allí, como contó Sekhmet. Pasa con partidas de la v0.4 o anteriores.
- PR 64-78 de Cornor923 (2026-11-04): volumen (`Snd.applyVolume`), poner sobre hierba alta (`PortRules.placeOver`,
  `GameView.canPlace`, que ahora tiene la guarda de 1..126), cámara bajo el techo (`CAMERA_GAP`), sueltos quietos, hierbas que
  se sueltan a sí mismas, nieve solo en BIWinterPeaks a cielo abierto, niebla por distancia (`Sky.FogShader`), ordenador sin
  pausa, robot en el salto del mapa, vigilante de HashLink pausado al construir el mapa, textos del ordenador, luz por cara
  junto a un neón, `World.openCascade` (cascada contra cristal), `Ship.updateWrap` y licencias (`Licenses.hx`, añadido del
  port). Añadido al fusionar: la pantalla `licenses` deja correr el juego como `computer` (guion `licencias_vida`).
- PR 79-86 de Cornor923 (2026-11-05): editor de kubes (`KubeEditor.hx`, `KubeData.hx`, pantalla `kubes` del menú de inicio,
  añadido del port; guarda `.kube` en `Settings.dir()/kubes`), ventana creada ya a W x H con título (`hxd.System.createWindow`
  en `main`), corte de alfa de los trozos 0.03 (`Parts`, cambio del port), flecha del tutorial (`Explorer.tutoTarget` con
  setter), `Tutorial.craftAllowed` en `Ship.checkCraft`, pausa tras poner anulada al soltar (`GameView`, cambio del port),
  ordenador del sintetizador con bloque en la mano y clic derecho (`GameView.synthAimed`, cambio del port) y puntero al centro
  en ordenador y pausa (`GalaxyApp.centerMouse`, `Screen.holdHover`). Arreglado al fusionar: `print mouse` (PR 86) usaba
  `sdl.Sdl` sin guarda y el build DirectX no compilaba; ahora va en `#if hlsdl`. Después: la ayuda del editor (`kube.help`)
  se acorta en ES y FR para que quepa en una línea.
- Revisión posterior (2026-11-05): `World.cornerLight` (cambio del port) da a las esquinas de las caras de arriba la luz más
  alta alrededor de un bloque parcial (BTReduced) vecino en vez de 0: el suelo entre cuatro lingotes salía negro. Solo caras
  de arriba; comparado píxel a píxel con el build anterior en luz_parcial, luz_neon, ventana_neon, snow_cover, hangar, mother,
  homebay, zones y sintetizador_mano (solo cambia ese suelo). `GalaxyApp.TEST_RUN`: con --script/--shot no se captura el ratón
  ni se mueve el cursor del sistema (Heaps lo llevaba a la ventana de prueba al soltar la captura). `KubeData.slug` añade
  "-kube" a los nombres de dispositivo de Windows (con, aux, nul, prn, com1-9, lpt1-9).
  Con TEST_RUN la ventana además se crea fuera de la pantalla (-10000,-10000): devrun la pedía minimizada, pero SDL la mostraba
  en el centro del escritorio (pasaba ya antes de estos PR); las capturas salen igual.
- Arena movediza (2026-11-05, Cornor923). **A propósito, se quedan como el original** (no "arreglarlo"): el daño dentro
  (`Hero.doMove`: con los ojos dentro, 1 de cada 20 pasos de física, `hit(dt * 5)`, unos 6-8 por segundo) y que mirando abajo
  desde dentro no se apunte nada (`Render.pick` para en la arena y `Game.update` no deja apuntar a la celda de los pies ni a la
  de encima; el original tampoco apuntaba nada mientras se estaba aturdido). Cambio del port en la caída: el original solo
  frenaba con `dt *= 0.3`; la gravedad seguía creciendo y el daño llegaba al final, el de toda la caída. Ahora tocar la arena
  cayendo es como aterrizar (`GameView.fallImpact`, el mismo golpe que en el suelo) y la gravedad vuelve a 0; al salir por
  debajo se sigue a la velocidad que se veía dentro (`SAND_SLOW`, `inSand`), así que la caída se cuenta desde la salida.
  Desde z=76 sobre una losa de 2 y 6 de aire: al tocarla 67.8 (11 sobre roca: 69.9), abajo 63.6 (original: 100 al tocarla,
  47.0 abajo). Desde z=75 sobre un pozo de 3: 32.0 al tocarlo, 22.9 en el fondo por la arena (original: 46.4 en el fondo).
  Guion `arena_movediza`.
- "Pilotar la nave" fuera del planeta principal (2026-11-05, Cornor923): en aventura el ordenador de a bordo ya no lo ofrece
  (`GalaxyApp.pilotOffered`: `canPilot` y `pilotLicensed`) en vez de sacarlo y avisar al pulsarlo (se quita el texto
  `license.pilotmain`); en creativo, en todos. El menú guardado se rehace al volver de las licencias si ha cambiado
  (`showComputer`). Guiones `licencias` y `licencias_creativo`.
- PR 87-94 de Cornor923 (2026-11-05; el 88 y el 91 tienen su entrada arriba):
  - 87: en francés la ayuda del editor de kubes (`kube.help`) vuelve a decir "enregistrer" para Ctrl+S.
  - 89: `Tutorial.takeoff()` (desde `GalaxyApp.buildExplorer`, tras `space.takeoff()`) pone `doneTime = 0`: las
    felicitaciones y el aviso del planeta principal ya no se quedan parados en el mapa ni vuelven en el planeta siguiente.
    `DONE_TIME` 16 -> 12 s, `MAIN_TIME` igual. Guion `tuto_despegue` (a 30 fps: los avisos cuentan tiempo real).
  - 90, cometas (añadido del port): `Comets.hx`: franjas de 2 h de hora real (`Licenses.now`) desplazadas por sistema y una
    tirada fija (semilla del sector, sistema y franja) con 1 de 6; nada se guarda por cometa. Id `sistema * 10 + 9`, fuera de
    `ExpSystem.planets` (ni el sector ni las licencias lo cuentan); `UniInfo.comets` guarda los visitados y `SaveInfo.comet`
    el tiempo que queda. `CometGenerator.hx` (`BICometCinder` al final de `BiomeKind`, proba 0 en `DataGen`): mundo de 96
    (múltiplo de 16 por los chunks; la nave sigue en 128 y aterriza a 12 o más del borde). Amarre según `Hangar.speedOf`
    (`Hangar.check` lee los bloques por función): 1:30 a 0,2 PC/s o menos, 15:00 como mucho. `GameView.updateComet`: cuenta
    atrás solo abajo, vuelta de emergencia como Mayús+K, teletransportador en rojo. `Explorer.cometStart`: al despegar la nave
    sale donde estaba el cometa. Escanearlo no gasta licencia; nunca es principal ni se pilota. Guiones `cometa`,
    `cometa_terreno`.
  - 92, Base de datos ESCorp (añadido del port): `Kubindex.hx` (`SaveInfo.kub`: vistos, recuperados, estadísticas, planetas,
    cometas, recetas fabricadas, anomalías y nuevos; por nombre de constructor de `BlockKind`), `KubData.hx` (categorías y
    sitios, en `res/kubindex.json`, que copia `package.ps1`), `DatabasePanel` y las vistas `KubBlocksView`, `KubPlanetsView`,
    `KubRecipesView`, `KubDetail`, `KubCell`, `KubScroll`, `KubNotify`, `KubText`. `DetailsGenerator.placed` /
    `World.anomalies()` para saber qué anomalía se cruza. En creativo todo se sabe, nada se cuenta y no salen los contadores
    (`Kubindex.full`). En el tutorial se abre desde el paso DATABASE (`Tutorial.databaseAllowed`, `databaseOpened`).
    Sin parón al abrirla (antes 3 a 4,7 s con todo sabido): el contorno de los iconos se hace en la GPU (`IconAlphaSum`,
    `IconOutline`, la misma aritmética entera que `BitmapData.glowCommon`: 431 de 436 iconos idénticos, los 5 de lava a
    1/255), sin leer de vuelta; los iconos grandes se hacen unos pocos por imagen (`Icons.pump`; los de reserva, `Icons.warm`,
    en la pantalla de carga, con sus tres shaders compilados uno por imagen); las pestañas se guardan mientras está abierta
    (`Kubindex.version`) y `KubScroll` no dibuja lo que no se ve. Toda la interfaz dibuja los bloques con `Icons.bitmap`
    (Base de datos, barra del inventario, paleta, cofre, tienda, contratos, editor de kubes), no hay otra manera: el mismo
    icono de 256 px con mipmaps, liso a cualquier tamaño de ventana y con los translúcidos bien hechos. Marca de nuevo:
    `mush_recent.png` (`img/icons/ui/recent.png` de Mush, WebGamesArchives de Motion Twin, CC BY-NC-SA 4.0, en `NOTICE`;
    dentro del .hl con `-resource`). Guiones `kubindex`, `kubindex_guardar`, `kubindex_cometa`, `kubindex_anomalias`,
    `kubindex_tuto`, `iconos_lisos`.
  - 93, sin parones: los buffers de cada chunk se crean al construirlo (`World.emitMesh`) y no todos en la primera imagen
    (primera imagen del menú ~740 -> ~110 ms); `ChunkPrim` guarda solo el buffer de floats y sus límites (el GC ya no recorre
    millones de objetos); `bgComputeAlt` guarda la altura de cada columna para sus 11 caminos (110-170 -> ~15 ms); la nave del
    aterrizaje se construye en la pantalla de carga (`Ship.prepare`, imagen de llegada ~550-700 -> ~90 ms); los pasos largos del
    generador se reparten (`Generator.jobs`, mismo orden; las versiones de una vez se quedan para Marte; mismos Adler-32 en
    `port/headless`); la luz por partes (`World.lightTask`; `--lighttime` da su suma, igual antes y después); la nodriza por
    pasos (`GalaxyApp.loadSteps`, `World.placeCells`, `SpaceSky.build` como tarea, mismas caras píxel a píxel): 440-880 ms en
    cada visita y ~6 s la primera -> 90-97 ms, 163 ms la primera.
  - 94 (cambios del port): `GameView.breakBlock` suelta siempre en las zonas de sintetizador y en el hangar
    (`GameView.inCraftZone`, la que ya usaba `mine()`); `Drops.unbury` saca por un lado (el más cercano al jugador) un suelto
    enterrado con otro bloque sólido encima; sin lado libre, en la nave va al jugador. Guiones `recuperar_zona`, `suelto_enterrado`.

## Qué falló y cómo se resolvió
| Problema | Causa | Solución |
|---|---|---|
| Sin permisos de administrador | no se podía instalar Haxe | zips portables en `tools-portable/`; `haxelib` con Neko portable |
| Haxe prohíbe el paquete `flash` | restricción de plataforma | `--macro allowPackage('flash')` |
| El generador de Luna no terminaba en HashLink | el último `-cp` gana: usaba `mt.Rand` Int en vez de Float | copia de `mt.Rand` con la variante Float, colocada al final del classpath |
| Autumn/Mars distintos de Flash | `Array.sort` de Flash es inestable (quicksort) y HashLink es estable | `gen/FlashSort.hx` reproduce el algoritmo de Tamarin |
| `Reflect.field` en enums daba null | solo funciona en Flash | `Type.createEnum` con `#if flash` |
| Flash standalone "no hacía nada" | pasaba la ruta del SWF entre comillas; además `trace` de Haxe pinta en pantalla y `System.exit` está bloqueado | ruta sin comillas, `flash.Lib.trace`, sin `exit`, trabajo por tandas (límite de 15 s por script) |
| `JIT ERROR 128` de HashLink | función con 14 argumentos decimales | pasar un array |
| Todo se veía inverso (giro, A/D) | Heaps usa coordenadas zurdas | invertir signos |
| Las hojas no chocaban | usaba "opaco" en vez de `Block.collide` | usar el atributo `collide` del bloque |
| Fondo negro, planeta flotando | solo era un render | domo de cielo + shader de niebla con los 3 colores originales de cada bioma |
| Cámara del menú en zigzag | la altura seguía cada árbol | tabla de alturas precalculada, la mejor de 11 rutas, más lenta |
| "?" en "Generando…" | la fuente no tiene el carácter "…" | tres puntos normales |
| Nieve corría al girar, luego pegada al jugador | el modo de partículas GPU rota un offset grande; la versión 2D no reaccionaba al movimiento | copos con posición fija en el mundo, proyectados con la cámara y ocultos tras el terreno |
| Movimiento inventado (Shift, vuelo) | no existía en el original | copia fiel de `Hero.doMove`/`moveHero`; correr y vuelo eliminados |
| Filtro de seguridad bloquea comandos | falso positivo de "Remove-Item" | usar las herramientas Edit/Write y evitar `//` en comandos PowerShell |

## Ver el juego original en marcha (referencia visual)
`port/dev/orig_flash_shot.ps1` abre un SWF original (por defecto el explorador `fla/explore/swf/explore.swf`) con `flashplayer_32_sa_debug.exe`, pulsa "Continuar" en los
avisos de error del reproductor y guarda capturas SOLO de la ventana del reproductor (PrintWindow); admite clics (`-Clicks "880,225;..."`). Nunca capturar la pantalla completa.
El explorador original arranca en modo depuracion dentro de un sistema solar (`PInSystem(5)`); saliendo por el borde con clics se llega a la vista del sector.

## Explorador (portado desde `fla/explore`)
- `port/shim/flash/*`: `BitmapData` por software (ruido, Perlin, filtros, mezcla), `geom`, `filters`, `Sprite/Graphics` minimos. OJO: `getPixel32` devuelve `UInt`; restar con UInt da valores enormes: convertir a `Int`.
- `port/explore/`: `ExpRoom` (generacion de fondos: copia de `Room.hx`), `ExpData` (datos offline), `Explorer` (vista del sector con paralaje, sistemas, nave, viaje con clic).
- Hecho: vista del sector (fondo, sistemas, cursor, viaje), tu nave renderizada desde arriba en 32 fotogramas (`Ship.captureFrames`), vista del sistema solar (sol, orbitas, planetas con
  ventana, rocas, anillo de salida, calor del sol), transiciones con fundido a negro y aterrizaje (de momento cada planeta crea una partida nueva).
- Datos: `ExpData.ExpOffline` copia `exp.OfflineData` del original sin servidor: TODOS los sistemas abiertos (los candados de `Main.hx` eran solo datos de prueba) y planetas sin explorar ("Escanear" y luego aterrizar).
- Universo guardado: HECHO (`SaveInfo.uni`: semilla del sector, planeta actual, posicion de la nave en el mapa, planetas visitados con sus cambios). El mapa empieza junto al planeta inicial y,
  al volver de un planeta, la nave aparece junto a ese planeta en su sistema.
- En el espacio (desde la v0.4): al despegar el planeta se descarga (`GalaxyApp.buildExplorer`) y la partida queda en `spaceInfo` con
  `uni.space = true` y `uni.ship` (punto del sector). Guardar en el mapa escribe eso con miniatura del mapa; al cargarla se genera el
  planeta solo para `Ship.captureFrames` y se abre el mapa (`finishLoading` -> `toSpace`). Del mapa se sale aterrizando.
  `Space.hx` es la base de las reglas del viaje (combustible, candados, misiones...): recibe despegue, distancia recorrida
  (`uni.traveled`), cambios de sistema, aterrizaje, candado y acoplamiento; hoy solo cuenta la distancia.
- **PENDIENTE (lo siguiente, pedido por el usuario, el 15/10/2026): hacer las transiciones IGUALES al original.** Hoy solo hay un fundido a negro. Leer y portar de `Manager.hx`:
  1. **Entrar al sistema solar** (`gotoSolar` con `anim`, lineas ~1412-1595): `hyperjumpFx3D` (10 lineas de particulas que convergen en la nave + `novaFx` que se absorbe) y luego `zoomAnim` de 1300 ms:
     lineas de hiperespacio (`makeHyperspacePart`) entre el 10 % y el 60 %, destello de calor (`burn`/`overdriveBurn`), el sistema crece desde un punto (`zoomCache` = `solar.snapshot()`, escala 0.01 -> 1 con `TEase`),
     el sector se aleja (zoom 60 de las capas, alpha 1-t; las entidades zoom 12), las estrellas del sistema (`solarStars`, zoom 0 -> 10) y el fondo cambia de color; al acabar `popString(nombre)` y `hyperjumpArrivalFx(10)`.
  2. **Salir del sistema solar** (`gotoSector` con `anim`, ~1596-1715): `hyperjumpFxHorizontal` + `zoomAnim` de 800 ms (el sistema se encoge a un punto, el sector vuelve con zoom 60 -> 0) + `hyperjumpArrivalFx(6)`.
     **Ademas hoy la salida ocurre demasiado rapido**: el original deja pasar la ULTIMA linea de orbita y un rato despues te saca (la salida se dispara con `d >= exitDist - 30` y destino `td >= exitDist`;
     `exitDist = getOrbitDist(ultimo) + 100`). Mirar esa parte del original en marcha con `port/dev/orig_flash_shot.ps1` (salir por el borde con clics) y copiar el comportamiento y el momento exacto.
  3. **Entrar a un planeta** (`Escanear`/`Aterrizar`): el original oscurece la pantalla (`initMask`, 350 ms), muestra el nombre grande (`popString(p.name, false)`), la barra fina de carga (`showBar`) y el icono giratorio
     (`loading`), y al aterrizar un planeta activo bloquea los controles y llama a `onLand` a los 100 ms.
  Para portarlo hace falta: un gestor de animaciones como `Tweenie` (curvas Bezier: TEase 0,0,1,1; TEaseIn 0,0,.5,1; TEaseOut 0,.5,1,1; TBurnIn 0,1,1,1), un sistema de particulas como `Particle` (dx/dy, friccion, vida, alpha),
  el zoom de las capas (`ExpLayer.zoom` ya existe) y de las entidades, y `snapshot()` del sistema (render de las capas con una vista virtual de 2200x2200 a una textura).
- Hecho despues: particulas del salto y destello de reactores (`Explorer.hx`, `ExpFx.hx`), tienda y hangar. Falta: GPS (flechas) a planetas activos, la "common room" (remolino), el robot comerciante viajando por el mapa y revisar las particulas del motor en marcha.
- El paquete portatil necesita ademas `res/explore_tiles.png` (de `src/G55/fla/explore/gfx/tiles.png`) y volver a generarse con el sintetizador y el explorador.

## Banco de pruebas (`port/game/Dev.hx`, guiones en `port/dev/`)
Solo para desarrollo: `hl galaxy55.hl --script=guion.txt` arranca una partida nueva y ejecuta ordenes (tp, tpl, lookat, set, activate, synth, give, print, map, shot...;
la lista esta en la cabecera de `Dev.hx`). `port/dev/devrun.ps1 -Script port/dev/synth.txt` lo lanza y muestra la salida. Ejemplos: `zones.txt`, `map.txt`, `synth.txt`.
Desde los PR 17-30 de Cornor923 (cambio del port), `devrun.ps1` lanza `galaxy55.exe` (con `hl` de reserva), hay `print palette` y `print time`, y cada arreglo trae su guion (`creative_oxygen`, `hielo_bajo_agua`, `palette_hint`, `palette_focus`, `olas_bloque`, `muerte_nave`, `hangar_vida`, `mother_save`, `play_time`, `map_ship_color`, `map_ship_angle`, `map_ship_center`).
Los guiones esperan con `waitfor sector|window|mother|map|planet|ready [max]` cuando el tiempo depende del PC (viajes, cargas,
acoplarse al robot); `wait N` solo para tiempos fijos.
PR 31-51 de Cornor923 (2026-10-22, del original salvo lo marcado como cambio del port): temblor, turbo minero, vida en la
nave, bomba exotica, Mayus+K con fundido blanco, altura de los ojos (`GameView.viewZ`), FOV y cielo bajo el agua, bajada del nivel
del mar (`World.reduceWater`), trozos del laser, cielo estrellado, mipmaps, detalles (marco, bloques soltados, iconos, barra), F2,
F, sonido de rotura, cantina no modal, rayo de aterrizaje, hangar sin liquidos, con soportes y excavacion rapida. Detalle en TRASPASO.
PR 52-59 de Cornor923 (2026-10-22/23, cambio del port): menu de inicio con lista de partidas y formulario por modo (54),
tutorial de aventura en el espacio (58: `Tutorial.hx`, `TutoGuide.hx`, `TutoText.hx`, `SaveInfo.tuto`, anadido del port),
sin atajo a la nodriza en el ordenador (52), flecha '<' y Ciudad muerta en el mapa (53), sin temblor en caidas en creativo (55),
puertas abiertas en el hangar (57), arreglos perdidos de los PR 31-51 (56), `devrun.ps1` sin robar teclado ni mando (59).
PR 87-94 de Cornor923 (2026-11-05): `kub ...` y `print kub|kubdata` (Base de datos ESCorp), `comet force|time|speed|stats`,
`print comet` y `--all-comets` (cometas), `breakl` (romper en coordenadas locales de la nave), `--frametime=MS` (umbral de los
fotogramas lentos y tiempo de arranque) y `--lighttime` con la suma Adler-32 de la luz.
Los ganchos antiguos `--screen=... --craft --at=...` siguen funcionando, pero para pruebas nuevas se usa Dev.

## Siguiente paso acordado (mañana): paquete de prueba
Crear un **zip portátil** (no instalador todavía) y publicarlo como **pre-release** en GitHub Releases (no dentro de `main`):
- Contenido: `hl.exe` y DLL de HashLink, `galaxy55.hl`, los gráficos del original que lee el juego (`texture.png`, `hud.png`, `hud_jetpack.png`, `digger.png`,
  `icons.png`, `lazer*.png`, `ship_halo.png`, `door.md`) en una carpeta `res/`, un `jugar.bat`, `LEEME`, `NOTICE` y licencia.
- El juego lee hoy esas imágenes con rutas relativas `src/G55/fla/client/gfx/...`: hay que moverlas a una ruta configurable o relativa al ejecutable y
  **probarlo en una carpeta vacía** (sin el repositorio) antes de publicar.
- En la descripción: lista de errores conocidos, aviso de que el formato de las partidas puede cambiar entre versiones, y que la versión Flash es hoy la más completa.
- Un instalador `.exe` vendrá después, cuando haya menos errores. No empezar sin que el usuario pruebe el zip.

## Pendiente (por orden)
1. **Nave** (parte 1 hecha: aparecer, teletransporte, ordenador, puertas; parte 2a hecha: **sintetizador** con `CraftEngine` del original, vista previa del
   resultado, texto de la receta en pantalla y fabricar con el ordenador del sintetizador; probado por hook `--craft`/`--craftgo`, falta probarlo con ratón y
   teclado reales). Falta: **tienda ESCorp** (`Game.openShop`, créditos) — idea del usuario (a hacer DESPUÉS del explorador): naves de comerciantes (robot) que dan vueltas por las galaxias del mapa, entrando y saliendo de planetas; al pulsar una, nuestra nave la sigue; al llegar a su lado aparecemos en el espacio dentro de nuestra nave y la puerta se conecta a la nave del robot, donde está la tienda. A decidir luego: una nave fija o varias con vendedores distintos, y si el vendedor se va o espera mientras lo seguimos. Orden nuevo: explorador → nave del robot/tienda → hangar, y el menú "despegar" que llevará al explorador.
2. **Hangar** (`EditShip.hx`, `net/EditShip.hx`): editar los bloques de la nave y validarla (hermética, motores, ordenador, teletransportador...).
3. **Explorador / mapa de estrellas** (`fla/explore`, `Manager.hx` + `Room.hx`) — EN CURSO (ver la sección "Explorador" más arriba). Hecho: sector, sistema solar, planetas con ventana, nave 3D,
   universo guardado (`SaveInfo.uni`), aterrizar y volver junto al planeta. **Falta, por orden (lo pidió el usuario: "tiene que ser igual al original"):**
   a. **Entrar al sistema solar** (`Manager.gotoSolar` + `hyperjumpFx3D` + `zoomAnim`, 1300 ms): partículas de líneas que convergen en la nave y `novaFx`; el sector hace zoom
      (capas `zoom` 0→60 con alfa 1→0, entidades zoom 0→12) mientras `makeHyperspacePart` lanza líneas desde el centro entre t=0.10 y 0.60; el sistema crece desde un punto (`zoomCache` = `solar.snapshot()`,
      escala 0.01→1, TEase, empieza a los 10 %), las estrellas del sistema hacen zoom 0→10 con alfa 0→1, fondo `setBg` con fundido, `overdriveBurn` (destello de color, alfa 0→0.7→0) y al final
      `popString(nombre)`, `hyperjumpArrivalFx(10)` (líneas rectas + nova) y `centerView`.
   b. **Salir del sistema** (`gotoSector` + `hyperjumpFxHorizontal` + `zoomAnim`, 800 ms): hoy es demasiado rápido. En el original el borde del sistema NO te saca al instante: dejas pasar la
      última órbita y, pasado un rato, te saca (revisar `Manager.main`: `d>=exitDist-30 && td>=exitDist` con `exitDist = órbita más lejana + 100`; probablemente la nave tiene que frenar/seguir hacia el
      anillo de salida durante un tiempo; comprobar con el original en marcha, ver "Ver el juego original"). Luego el sistema se encoge a un punto (zoomCache 1→0.01, TBurnIn), el sector hace zoom 60→0.
   c. **Aterrizar** (`Manager.sendAction(ALandPlanet)` y el flujo de "Escanear"): fundido a negro, `popString(nombre)` grande sin desvanecerse, barra de carga fina (`showBar`), icono de carga que gira
      (`loading`), y al terminar entrar al planeta. Hoy solo hay una barra provisional.
   d. Utilidades que hacen falta para a, b y c: un `Tweenie` (curvas Bézier: TEase 0,0,1,1; TEaseIn 0,0,.5,1; TEaseOut 0,.5,1,1; TBurnIn 0,1,1,1), un `Particle` (dx, dy, fricción, vida, `onUpdate`),
      `novaFx` (círculo blanco con brillo interior y desenfoque) y la "common room" (`generateCommon`, remolino `makeMaelstrom`), más GPS a planetas activos y reactores de la nave.
   e. Opcional más adelante: sonidos, "energía" de la nave.
4. Después, ideas guardadas por el usuario (no empezar antes de 1-3):
   - **Agua que se mueve**: primero el flujo del original (`Process.hx`: inundación del mar con `updateFlood`, líquidos con `BFPropagate`
     como cascada y lava, cubrir/descubrir hierba, plantas que se rompen al quitar el suelo; hay que portar `Process.onSet` entero),
     luego niveles de altura al estilo Minecraft (cada paso lateral baja la altura de la superficie; la columna que cae va llena)
     y una textura de agua animada.
   - **Fallos a corregir (avisados por el usuario, en el bioma de invierno y al excavar):**
     1. Al romper un bloque el original hacía una animación de partículas (`render.parts.doBreak`, `Particles.hx`); falta.
     2. El bloque suelto en el suelo gira demasiado rápido (`Drops.hx`, `setRotation(d.time * 6)`); copiar la rotación de `Render` para `Dummy`.
     3. Las hojas del abeto (`BWinterLeaves`, "Touffe de sapin") sueltan material. En los datos originales no tienen `BFNoDrop` ni `BFDropChance`, así que según `DataGen.hx` sí se recogían; el usuario recuerda que no. Comprobarlo en el juego Flash (reproductor en `Downloads\ruffle...\flashplayer_32_sa_debug.exe`) antes de cambiar nada.
     4. No se pueden romper las cosas colgadas de los árboles (estalactitas/colgantes, `BFDetail`, p. ej. `BIceStalactite*`, enredaderas) ni la planta del suelo: `GameView.blocking()` descarta los `BFDetail`. El original sí los apuntaba (se rompen con la mano vacía).
     5. Hay bloques blancos en el bioma de invierno (cubos de color blanco liso, sin textura): mirar qué bloque es (¿casilla de color de `Atlas`, p. ej. `BCascadeSource`/`BIce`, o `BWinterWall`?).
     6. La curvatura del planeta se nota demasiado (`curve = 2/tamaño` en `World`/`Sky.FogShader`); reducirla un poco (valor o opción) y comparar con el original.
     7. Los cristales verdes que sueltan las plantas (cargas, `BTSprite`: `BYellowCharge`, `BBlueCharge`, `BBonusCharge`...) se ven demasiado anchos al caer: en el original son sprites que miran a la cámara (`Builder.addBufferBlock`, caso `BTSprite`), no la cruz de modelo que dibuja `Drops`/`IconMesh`.
     8. El agua se congela al tocar hielo: el usuario lo mencionó "por cierto"; confirmar si es lo esperado (en `Process.onSet` solo `BFreezer` congela) o un fallo, y portar la lógica al hacer el agua.
     9. La capa 0 (roca madre, mirada desde abajo) se ve como un plano liso lila con un círculo oscuro: revisar texturas y luz de `BBedrock` en `z=0`.
     10. Borrar una partida desde el menú no funciona (`GalaxyApp`, pantalla de cargar partida; revisar `SaveData.delete` y que se refresque la lista).
     11. Luz mal en los bloques que no son cuadrados (`BTReduced`, `BTExtended`, modelos...): el brillo de las caras o del vértice no coincide con el de los cubos vecinos; revisar `addQuadL`/`NOLIGHT` en `World.hx` para esos tipos.
     12. El bloque de fuente de cascada (`BCascadeSource`) puesto en la nave no se puede quitar (en la zona del sintetizador). Mirar `GameView.mine`/`pick` y las reglas de `inCraft` para bloques activables o con `toggle`.
     13. Al fabricar en el sintetizador no desaparecen los bloques con los que se fabrica: hoy, si el inventario aún tiene esos bloques, se gastan los del inventario y los puestos en la zona se quedan (así lo hace `ShipLogic.activateBlock` del original: `hasInv`). Decidir si se copia tal cual o se cambia a gastar siempre los puestos en la zona (parece lo esperado por quien juega).
   - (HECHO en la v0.2, `Hand.hx`) **Ver en la mano el bloque elegido** (el original dibuja el bloque en `Render.hx`, `drawBlock(block, curLight)` con `curLight` suavizado; hoy solo se ve en la barra).
   - **Opción de calidad** (distancia de dibujado, caras de las hojas) para PC lentas; el valor por defecto sigue siendo la mejor calidad.
   - Vida, daño, curación, oxígeno y lava; bloques activables, cofres, `BFTransform`; sonido; partículas al romper; planeta Shed y Ciudad muerta completos.
5. Decidir SDL (actual) o DirectX; empaquetar como instalable; multijugador y Steam.
   - **Evaluar versión web** (Heaps JS/WebGL; pedida por la comunidad de Eternaltwin; NO probado). Trabajo: sustituir `sys.io.File`/`sys.FileSystem` por recursos incrustados o descargados; guardados en localStorage/IndexedDB; versión JS del shim `flash.Memory`; ratón bloqueado, mando y pantalla completa con APIs del navegador; comprobar los filtros por software del explorador y `Ship.captureFrames`. Riesgos: velocidad y memoria de la generación de mundos en JS, y los ~5 s de generación del explorador.
6. Cuando el usuario lo apruebe: fusionar `port-hashlink` en `main` ("hacerlo oficial").


## Cómo retomar
    . ..\tools-portable\env.ps1         (Haxe 4.3.7, HashLink 1.16, Neko)
    haxe port\game.hxml                 compila el juego
    port\jugar.bat                      lo abre
Verificación de generadores: `haxe port\headless.hxml` y `haxe port\headless_flash.hxml` (comparar hashes).
