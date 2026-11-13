# Traspaso para seguir en otra PC (2026-10-16, al día el 2026-11-12)

Léelo entero antes de tocar nada. El usuario es **Pvie** (Pv1E en GitHub): habla español,
quiere respuestas cortas y sin emojis, y que se **copie el original de Motion Twin, sin inventar**. Lo que añadimos nosotros se marca como
"cambio del port" o "añadido del port".

## Dónde está todo
- Repo: https://github.com/Pv1E/galaxy55-offline. Se trabaja solo en la rama `main` y se sube con `git push origin main`
  (la rama `port-hashlink`, copia de `main`, se borró el 2026-11-12). Licencia CC BY-NC-SA 4.0.
- Resumen técnico largo del port: `port/RESUMEN.md`.
- La versión Flash (con `client*.hxml`, `build.*`, `release/`, `libs/heaps`, `libs/format_old`) vive solo en la rama `flash`:
  se quitaron de `main` el 2026-10-26 porque el port no los usa. `src/`, `libs/libs-haxe*`, `stubs/`, `tools/` y `data/` se quedan.
- Lista de lo que falta: `PENDIENTES.md` / `TODO.md`.
- Errores conocidos: `ERRORES.md` / `BUGS.md`.
- Novedades: `CHANGELOG.md`.
- El zip trae también `claude-memoria/`, las notas de la PC anterior: preferencias del usuario y datos del entorno.
  Cópiala a la carpeta de memoria del proyecto en la nueva PC si quieres que se cargue sola.
- `nave-hades-atlas-2-0.zip`: el mapa de Minecraft con la nave nodriza. La hizo un amigo de Pvie, que dio permiso y no pide créditos.

## Entorno
- Haxe 4.3.7 + Heaps (rama main) + HashLink 1.16. Compilar: `haxe port\game.hxml` → `port\out\galaxy55.hl`. Jugar: `port\jugar.bat`.
- En la PC anterior las herramientas eran portables (`tools-portable\env.ps1`). En otra PC, instala Haxe/HashLink y las librerías
  siguiendo `port/README.md`.
- Banco de pruebas: `powershell -File port/dev/devrun.ps1 -Script port/dev/<script>.txt -Data <carpeta vacía> [-Extra "--creative"]`.
  Las órdenes de los scripts están en `port/game/Dev.hx`: `ship`, `tp`, `look`, `set`, `shot`, `print`, `shop`, `buy`/`sell`,
  `hangar`, `hangarexit`, `mothership`, `chestclick`, `settop`...
  Las capturas quedan en `port/out/`. `port/dev/sheet.ps1` las junta en una hoja.
- Normas del usuario:
  - nunca capturas de toda la pantalla;
  - no bajar la calidad visual por la PC lenta de desarrollo (no tiene GPU ni audio);
  - el usuario hace los inicios de sesión;
  - confirmar antes de publicar nada (releases, Discord).

## Hecho en esta sesión (después de la v0.2)
1. **Tienda del robot** (`Market.hx`, `Shop.hx`):
   - créditos en la partida (empiezas con 500); precios propios del port por rareza (en los datos del original casi todo valía 100);
   - el robot **nunca se queda sin nada**;
   - comprar mucho sube el precio, con tope x2 y compartido en el sector (pensado para el multijugador);
   - vender mucho de lo mismo baja lo que te pagan hasta 0, y esa bajada es **personal**; con precio 0 avisa
     "el robot ya tiene demasiado de esto";
   - todo se recupera a la mitad cada 10 min de juego;
   - la ventana muestra todas las casillas del inventario;
   - de momento se abre desde el ordenador → "Comerciar".
2. **Luz:** las caras de bloques reducidos (hierro) que tocaban otro bloque opaco salían negras. Arreglado en `World.addQuadL`.
3. **Bloques que no devolvían nada al romperlos** (BFNoDrop): turbo minero, tornillos, lámpara de minero, nitrógeno, hielo,
   roca helada, tinte muerto. Ahora se recuperan (`PortRules.hx`).
4. **Cantina de ESCorp = cofre de 4 casillas**, copiado de `ent/Chest.hx` (`Chest.hx`):
   - clic coge/deja, Mayús la mitad, Ctrl una;
   - se guarda en la partida (`chests`); al romperla suelta lo que tenía;
   - no es modal, como el original: el juego sigue (sin saltar ni láser, `GameView.actionKeys`) y se cierra al alejarse más
     de 0,5 de donde se abrió (`Chest.far`); con el cursor libre, arrastrar fuera de la ventana mueve la vista.
5. **Hangar** (`Hangar.hx`, copia de `EditShip` y `net/EditShip.initLevel`):
   - cobertizo, zona de 17x17x14 y validación completa con los mensajes del original;
   - se entra desde ordenador → "Modificar la nave" y se sale pisando las casillas de teletransporte;
   - la nave editada se guarda (`shipData` en base64) y la usan el planeta y el mapa;
   - en el hangar se usan los bloques del inventario.
6. **Opciones:** "Ayuda en pantalla" activable; la primera vez que se abre el juego se elige el idioma.
7. **Nave nodriza:**
   - Pvie no quiso mis diseños generados. Ahora es la **nave Hades**, importada de Minecraft a escala 1:1
     (113x347x63, mundo de 384x384).
   - Conversor: `port/tools/mc2g55.py` (+ `mcread.py`), que lee mundos Anvil 1.16+.
     Uso: `python -I port/tools/mc2g55.py "<carpeta del mundo>" src/G55/fla/client/gfx/mothership.bin`.
     La tabla de bloques está en el script.
   - Bloques nuevos del port, añadidos AL FINAL de `BlockKind` (en `Common.hx` y `DataGen.hx`): `BMotherHull`, `BMotherPanel`,
     `BMotherDark`. Sus texturas grises se generan en `Atlas.motherTiles`.
   - Cielo de espacio con nebulosas, galaxias que giran, estrellas de colores y estrellas fugaces (`Sky.makeSpace`).
   - Se visita acoplándose al robot en el mapa; el atajo del ordenador "Visitar la nave nodriza (prueba)" solo sale con `editar_nodriza.bat`. Mayús+K vuelve. Nada se guarda dentro.
   - `Mothership.hx` conserva el diseño generado antiguo como reserva, si no hay `mothership.bin`.

## PR de Cornor923 integrados (2026-10-21, cambio del port)
Los PR 17-30 se fusionaron en local en `port-hashlink`, en orden (publicados en GitHub el 2026-10-22). Un solo conflicto: `Dev.hx` entre el PR 20
(`palette`) y el 26 (`time`); se conservaron ambos comandos. Cada PR trae su guion en `port/dev/`. Compila sin errores
(`haxe port\game.hxml`); los guiones de los PR no se han vuelto a ejecutar tras la fusión. El PR 26 incluye el 25.
Cambios: oxígeno en creativo (17), hielo/agua con desplazamiento de profundidad (18, 22), paleta creativa (19, 20),
`devrun.ps1` con `galaxy55.exe` (21), muerte en la nave (23), sin daño en el hangar (24), guardado y tiempo en la nodriza
(25, 26), nave del mapa: color, rumbo y centrado (27, 28, 29), TODO sin "Shed" (30).
Guiones ejecutados tras la fusión (datos en carpeta temporal): todos dan lo esperado. En `map_ship_center` la nave rehecha en el
hangar es más lenta (0.14 en vez de 0.2) y con esperas fijas no salía del sistema antes de buscar al robot, así que `hangarexit`
llegaba con el mapa abierto y fallaba (partida nula; la orden ya lo comprueba). Arreglado con la orden `waitfor` (sector, window,
mother, map, planet, ready), que espera a que pase algo en vez de un número fijo de fotogramas; los guiones del mapa, del robot y
de recargar la usan. `map_ship_center` ya llega a la nave nodriza y vuelve al mapa.

Los PR 31-51 (2026-10-22) se fusionaron en local, en orden; cada uno compila. Conflictos resueltos: `Dev.hx` (cada PR añade
órdenes: se conservan todas y se quitan las versiones viejas repetidas de `print drops`, `msg`, `ship` y `tele`); temblor (31)
con el fundido ya movido tras el teletransportador; turbo (32) + bomba (34) en `process.update`; mar que baja (37) + turbo en la
cabecera de `WorldProcess.hx`; altura de los ojos (39) con el temblor: `VIEW_Z` pasa a `viewZ` en el láser, el apuntado,
`inWater` y el turbo, y el fundido de la bomba conserva el `dz` del anterior (`Process.hx:249`); F (45) y cantina no modal (47):
con la cantina abierta F no cambia nada y no sale la ayuda; soportes en el hangar (51): `process.update` corre también allí.
Los 20 guiones nuevos de los PR pasan (datos en carpeta temporal).
Tambien pasan los de siempre (espacio, robot2, robot3, mapa_opciones, vida, hangar, map_ship_center, play_time, mother_save,
muerte_nave). No lanzar dos `devrun.ps1` a la vez: los dos escriben `port/out/dev_out.txt`, las salidas se mezclan y uno
puede quedarse colgado.

PR 52, 53 y 55 se fusionaron en GitHub (2026-10-22). Los PR 54, 56, 57, 59 y 58 (2026-10-23) se fusionaron en local en ese
orden (el 58 lleva dentro el 54). Conflictos solo en la cabecera y en `waitfor` de `Dev.hx`: se conservan todas las órdenes
(`menu`, `ground`, `blockl`, `newgame`, `tuto`...). La orden `newgame` (PR 53) pasa ahora el formulario a Creativo antes de
tocar el bioma, porque desde el PR 54 el bioma solo se elige en creativo (cambio del port, aviso de Cornor en el PR 54).
Compilan SDL y DX.
Comprobado que no se pierde nada: por cada PR, cada línea que añade está en el resultado (salvo las que otro PR cambia a
propósito: el 58 reescribe `startNewGame` del 54, y las líneas de ayuda de `print` se juntan en una). Pasan los 20 guiones de
los PR y los de siempre (turbo, espacio, hangar, vida). El botón "Saltar el tutorial" (58) cabe en el ordenador de a bordo ya
reducido por el 52. Por qué `Dev.hx` choca siempre: todos los PR salen de la misma base y añaden su orden en las mismas líneas
de la cabecera (lista de ayuda tras `pause`) y del `switch` de `waitfor`; git no sabe qué orden poner y para. Se resuelve
dejando todas. En los PR 31-51 se perdieron arreglos al resolver así (los recuperó el 56); por eso ahora se comprueba línea
por línea con un script.
Mientras tanto Cornor fusionó él mismo en GitHub los PR 59, 56 y 57 (2026-10-23). Su fusión `01fbe7c` dejó rota una línea
de `Dev.hx` (`var mining`, se perdió `power`) y volvió a repetir la ayuda de `print`: `main` no compilaba. Arreglado al juntar
`origin/main` con lo local; compilan SDL y DX y pasan `hangar_porte`, `nave_porte`, `fov_agua`, `tuto_espacio`.

## Pilotar la nave (2026-10-26, añadido del port, rama `pilotar-nave`)
Idea de Pvie hablada con Cornor (Cornor se queda con los cometas). En el ordenador de a bordo, "Pilotar la nave" la mueve sobre
el planeta en X e Y (Z fija: bajar chocaría con el planeta, que llega a 128; subir obligaría a cambiar `SHIP_Z` en unos 60
sitios). Sin gasto. Solo en planetas jugables: no en la nave nodriza (su ordenador sigue devolviendo al espacio), el hangar, el
tutorial ni durante un fundido. Detalle técnico en RESUMEN. Probado con los guiones `pilotar*.txt` (datos en carpeta
temporal): menú, Esc y E sin pausar, borde del planeta, guardar a mitad de vuelo y recargar, hangar, despegar y aterrizar,
nave nodriza, tutorial, francés, sintetizador tras mover. Compilan SDL y DX; hashes de los 4 mundos iguales.
Sin probar: con mando de verdad, en la ventana DirectX, y viajar a otro planeta y volver al primero (el código es el mismo
que aterrizar en el mismo). Aún no está en `main`: Pvie lo prueba y Cornor lo revisa antes.
Primera prueba de Pvie: la nave no giraba hacia donde iba y el movimiento era tosco. Ahora tiene inercia, gira hacia donde va,
se inclina en las curvas y aterriza sola con suavidad (detalle en RESUMEN). El giro es solo visual: girar la nave de verdad
(sus bloques, cofres, sintetizadores y el guardado) en pasos de 90 grados se podría hacer más adelante, pero toca mucho.
Segunda prueba de Pvie: el haz molestaba en vuelo. Ahora se desvanece a toda velocidad y vuelve al ir despacio, al pararse y
al aterrizar (opción elegida por Pvie entre varias).

## PR 60-63 de Cornor923 integrados (2026-11-02)
Fusionados en local en `port-hashlink`, en orden 60, 61, 62, 63, sin conflictos. Compilan SDL y DX. Pasan sus guiones (datos
en carpeta temporal): `contrats`, `contrats_tuto`, `contrats_json`, `bomb_liquids`, `place_front`, `ventana_neon` y
`fullwindow`. Contenido: contratos de la ESCorp (60, añadido del port; créditos de salida 500 -> 200 al acabar el tutorial),
la lava hace explotar la bomba antigua (61, cambio del port), poner delante de modelos y bloques parciales (62, como el
original) y cara trasera oculta en el marco del cristal (63, como el original). Detalle en RESUMEN. Sin subir aún a GitHub.
Después, 3 fallos de Sekhmet arreglados (altura máxima al poner, apuntar con la cabeza en una fuente de cascada, arena
movediza hueca junto a la cascada) con sus guiones `altura_max`, `fuente_excavar` y `cascada_arena`; pasan también `place_front`,
`hielo_cascada` y `ventana_neon`. La nave que cambia de sitio (ERRORES #15) era el fallo de la v0.4 arreglado en la v0.5 (sitio calculado con los cambios del
jugador); comprobado con `nave_sitio`. Conviene confirmar con Sekhmet qué versión usaba.

## v0.6 (2026-11-02)
Subido a `main` y `port-hashlink` (011ff2e) antes de preparar la versión. Versión del menú, enlaces de los README, changelogs,
ERRORES/BUGS y `port/RELEASE.md` pasan a v0.6. Zips con `package.ps1 -Version 0.6`; probados desde una carpeta vacía (SDL y
DirectX: carga el planeta y los contratos leen `res/contracts.json`). Etiqueta `v0.6`. La release la crea Pvie en GitHub
(pre-release, notas de `port/RELEASE.md`, los dos zips de `port/out/release`).

## PR 64-78 de Cornor923 integrados (2026-11-04)
Fusionados en local en orden; un conflicto en `Dev.hx` entre el 72 (`waitfor jump`) y el 77 (`waitfor system`): se conservan los
dos. El PR 77 avisaba de que, con el 71, la pantalla de licencias también debe dejar correr el juego: añadido en
`GalaxyApp.update` (`currentName == "licenses"`) y comprobado con `port/dev/licencias_vida.txt` (la vida sube 1,6/s). Compilan
SDL y DX. Pasan los 16 guiones de los PR y los de siempre (altura_max, fuente_excavar, cascada_arena, nave_sitio, place_front,
contrats, pilotar, espacio, hangar, vida). El 77 (licencias, añadido del port) lo aprobó Pvie: limita pilotar al planeta principal.
Reportes de Sekhmet aún abiertos: la cascada que se ve opaca, blanca y deformada en su planeta de otoño (vídeo del 2026-11-03;
no se reproduce en las pruebas, Cornor lo mira) y la nave que se movió (lo más probable, partida de la v0.4; si se repite,
pedir su partida: en Linux, `~/Galaxy55/saves/`). Comprobado además que la nave no se mueve con distintas velocidades de carga
ni al continuar desde el menú mientras se genera el planeta de fondo.

## PR 79-86 de Cornor923 integrados (2026-11-05)
Fusionados en local en orden 80, 81, 83, 84, 85, 82, 86, 79. Un conflicto en `Dev.hx` entre el 86 (`mouse` fija la posición de
la ventana, `print mouse`) y el 79 (`mousePos` para `wheel`, orden `kube`, `print kube`): se conservan las dos partes. El 86
no compilaba en DirectX (`sdl.Sdl.getGlobalMouseState` en `print mouse`): se envuelve en `#if hlsdl`. Compilan SDL, DX y
headless. Cambios del port respecto al original: el 85 (en Flash un segundo clic antes de 0,47 s tampoco ponía el bloque), el
82 (ordenador del sintetizador con bloque en la mano y clic derecho) y el 81 (corte de alfa 0.03 en los trozos). El 79 añade
el botón Editor de kubes al menú de inicio (los demás botones bajan una fila).
Pasan los guiones de los PR (herbe_particules, tuto_flecha, tuto_sintetizador, sintetizador_rapido, sintetizador_mano,
ordenador_raton, pausa_raton, kubes) y los de siempre synth y computer_menu; el build DX abre el menú de inicio. Después
(2026-11-05): la línea de ayuda del editor de kubes no cabía en español ni en francés (la última orden bajaba a una segunda
línea; en inglés sí cabe). Se acortan en `Lang.hx` ("Izq./Der.: cara"; "Flèches : face") y caben en una línea en los tres
idiomas (capturas kubes_ayuda_es/en/fr). Arriba y abajo no hacen nada en el editor, así que "Flèches" no engaña. En francés
Ctrl+S sigue siendo "enregistrer" ("sauver" no se dice de guardar en una interfaz) y la línea sigue cabiendo.
Revisión a fondo posterior (2026-11-05), sin regresiones de los PR 79-86: unos 45 guiones (colocar, sintetizador, trozos,
tutorial, ordenador y pausa, mapa, menús, partida) más 14 guiones en BIMoon, BIMars, BIWinterPeaks y BIAcidForest, y pruebas
propias (menú de inicio con teclado, editor de kubes, pausa y ordenador seguidos, clic derecho, recetas en el tutorial).
Arreglado en esta revisión:
- Suelo negro bajo cuatro lingotes juntos en la nave (reportado por Pvie): `World.cornerLight`, cambio del port, solo caras de
  arriba. Comparado píxel a píxel con el build anterior en 9 escenas de luz: solo cambia ese suelo.
- Pruebas: la ventana de prueba salía visible en el centro del escritorio y movía el cursor real (captura del ratón de Heaps).
  Con `GalaxyApp.TEST_RUN` (--script/--shot) se crea en -10000,-10000 y no captura el ratón; por eso fallaba a ratos
  `menu_partidas` (el cursor real daba el foco a otro botón).
- Editor de kubes: nombres reservados de Windows (con, aux...) se guardan con "-kube"; `print menu` con el editor abierto.
Después, aclarado y arreglado: la hierba de Marte sí se apunta; es baja y las plantas se eligen por los píxeles de su
textura (`GameView.modelHit`), así que solo se apunta de 0,1 a 0,4 de altura (barrido de puntos). No es un bug. `herb` ahora
usa una plataforma propia a z=99 y apunta a 0,2 (pasa en otoño, Marte y Luna). `tuto_planeta` usa la nueva orden de Dev
`tuto goin` (dentro de la celda del objetivo) para pisar el rayo: llega al paso 7. `tuto_bandeau` comprobado con un
settings.json `{ "lang" : "es", "showHelp" : false }` en los datos de prueba: sin la ayuda de teclas el recuadro del tutorial
sube bajo el inventario. Ojo: "lang" tiene que ser texto; con un número la lectura se corta y se ignora el resto del archivo.
## PR 87-94 de Cornor923 integrados (2026-11-05)
Fusionados en orden 87 a 91, 93, 94 y por último 92. El 92 (Base de datos ESCorp) iba sobre el 90 (cometas): la base de datos
lista los tipos de cometa. Tres conflictos, todos resueltos conservando las dos partes:
- `port/RESUMEN.md` entre el 88 y el 91: cada uno añade su entrada al final de "Estado actual"; van una tras otra.
- `port/game/GalaxyApp.hx` entre el 88 (`pilotOffered`, `computerPilot`, `showComputer`) y el 92 (`computerDatabase`,
  `computerTrade`): los dos bloques seguidos.
- `port/game/World.hx` entre el 93 (`lighting`, `lightSteps`, `lightTime`) y el 92 (`anomalies()`): la luz primero.
Los dos del 92 se resolvieron en su rama, fusionando `main` en ella. El 94 entra sin conflicto. Compila en SDL con todo. DirectX no
se ha compilado aquí: en el PC de Cornor el hldx portátil es más antiguo que heaps (`dx.Window` sin `NO_ACTIVATE` en
`hxd/Window.hl.hx`), y pasa igual con `main` sin los PR.
Cada PR se comprobó por separado sobre `main` con sus guiones (ver su descripción): `licencias`, `licencias_creativo` (88);
`tuto_despegue` (89); `cometa`, `cometa_terreno`, `hangar`, `vuelta_nave` (90); `arena_movediza`, `creativo_caida` (91);
los cinco `kubindex*` (92); `mother`, `hangar`, `vuelta_nave` y `port/headless` (93); `recuperar_zona`,
`suelto_enterrado`, `drop_rest` (94).
Añadidos del port: 90 (cometas) y 92 (Base de datos ESCorp). Cambios del port respecto al original: 88 (Pilotar la nave ya no
sale fuera del planeta principal), 91 (caer en la arena movediza es como aterrizar; el daño dentro y que desde dentro no se apunte
mirando abajo se quedan como el original, a propósito) y 94 (en la zona del sintetizador y en el hangar todo se suelta; el suelto
enterrado sale por un lado).
A tener en cuenta:
- `res/kubindex.json` tiene que ir junto a los demás recursos: `package.ps1` ya lo copia; un script de compilación propio que
  copie `res/` a mano tiene que añadirlo (sin él la base de datos sale vacía).
- El icono de "nuevo" del 92 es `img/icons/ui/recent.png` de Mush (WebGamesArchives de Motion Twin, CC BY-NC-SA 4.0), sin
  modificar, acreditado en `NOTICE` e incluido en el .hl con `-resource`.
- Partidas antiguas: sin `kub` empiezan con la base de datos vacía (los kubes de la nave ya conocidos) y tienen cometas igual
  (no se guarda nada por cometa).
- `kubindex_tuto`: el último `waitfor planet` (al entrar en el hangar) caduca, pero el paso queda en HANGAR como debe; pasa
  igual sin el 92 en el fork.
- `port/headless` (93): comparado con `main` en 7 de los 14 casos (todos los biomas con pasos repartidos y Marte), mismos
  Adler-32; en el fork de Cornor, los 14.

## Comprobación de los PR 87-95 en el PC de Pvie (2026-11-06)
Cornor los fusionó él mismo en `main` (49be008). Aquí: compilan SDL, **DX** y headless; los 8 mundos de `port/headless` dan las
mismas sumas que antes de los PR (generador repartido en trabajos, mismo orden); las partidas guardadas con baf96ac cargan
(`load` con `--load`); `kubindex.json` en `package.ps1`; `BICometCinder` al final de `BiomeKind`, sin bloques nuevos. Pasan sus
13 guiones nuevos y 25 de los de siempre (sintetizador, colocar, tutorial, menús, mapa, hangar, pilotar, kubes, luz). Notas:
`kubindex_guardar` difiere antes/después de recargar solo porque `kub forget` borra los kubes de la nave y al recargar
`Kubindex.shipKnown` los vuelve a poner (como en una partida normal); en una prueba sin idioma elegido (sin settings.json) los
nombres son los del original y la carga rosa sale "-": en el juego la primera vez se elige idioma y no pasa.
Arreglado aquí: con la base de datos abierta, la ayuda de las teclas (hud) se veía detrás de sus pestañas (el panel es
translúcido); `openDatabase` la oculta y `closeDatabase` la vuelve a mostrar.
## v0.7 preparada (2026-11-06)
Changelogs ES/EN/FR y ERRORES/BUGS pasan de "Sin publicar" a v0.7; enlaces de los README a `releases/tag/v0.7`; menú
"v0.7 · port nativo"; notas en `port/RELEASE.md` (3 idiomas). Zips con `package.ps1 -Version 0.7 -HashLink
..\tools-portable\hashlink\hashlink-1.16.0-win` en `port/out/release` (Windows 8,4 MB, Linux/macOS 3,0 MB, los dos con
`res/kubindex.json`). Probado el de Windows descomprimido en una carpeta vacía: OpenGL y DirectX crean partida, cargan el
planeta y leen la base de datos (164 fichas). Falta: etiqueta `v0.7`, subir y que Pvie cree la release (pre-release) con los
dos zips.
## README con la v0.7 (2026-11-06)
Sección "New in v0.7" / "Novedades de la v0.7" / "Nouveautés de la v0.7" en `README.md`, con `docs/img/base-datos.jpg`
(Kubindex), `docs/img/cometa.jpg` (ventana del cometa en el mapa), `docs/img/editor-kubes.gif` (editor con el motor espacial
girando) y `docs/img/pilotar.gif` (vuelo sobre el planeta). Capturas en inglés, sin la ayuda de teclas (settings.json con
"showHelp": false), hechas con devrun y pasadas a GIF con ffmpeg (12 fps, 640 px, paleta de 128 colores). La vista del cometa
desde el suelo o dando la vuelta salía oscura y poco clara: por eso la foto es la del mapa.
`docs/img/biomas.jpg` rehecha (2026-11-06): nevado, Marte, Luna y bosque ácido (bajo los árboles-seta), desde el suelo, sin
ayuda de teclas, FPS ni nombre del bloque (settings.json con "showHelp": false y "targetName": false), 2x2 a 1280x720.
Notas de la release v0.7 rehechas con el texto largo de Cornor (en inglés, comprobado contra el código: licencias, 1000
créditos y 24 h, abandonar, categorías del Kubindex, cometas), formato limpio, cómo jugar, créditos y traducción ES/FR, en
`port/RELEASE.md`; Pvie guarda el cambio en la página de la release.
## PR 96-112 de Cornor923 integrados (2026-11-06 a 2026-11-11)
Cornor fusionó en GitHub los PR 96-98 (2026-11-06), 99-106 (2026-11-09), 111 y 112 (2026-11-11); Pvie fusionó a mano los
107-110 (ramas `pr-107` a `pr-110`, 2026-11-10). El 97 lleva dentro el 96 (`fix/kube-blocks` fusionó
`fix/smooth-block-icons`). El 101 movió sus funciones de orden junto a `placeOf` para no chocar con el 100 (`51141f8`) y el
103 fusionó `main` en su rama antes de entrar (`cb88840`). Cada PR trae su guion en `port/dev/` (ver su entrada en RESUMEN).
Añadidos del port: 97 (kubes de Kube), 100 (recetas y bloques nuevos), 105 (preguntar antes de cargar bloques desconocidos),
106 (contratos por partes), 107 (anomalía invisible), 108 (gemas del Cofre de Kube) y 109 (vidrios blindados de color).
Cambios del port respecto al original: 100 (rendimientos del sintetizador; tronco de lunimosa con lunimosas muertas, antes con
roca lunar), 103 (precios y estante del robot) y 104 (fundido de la bomba, WCAG 2.3.1).
A tener en cuenta:
- Los bloques nuevos van al final de `BlockKind`: las partidas guardadas no cambian. Pero una partida que los use puede
  cerrar la v0.7 al cargarla (bloque nulo en `InvBar.refresh`); desde el 105, el juego pregunta y quita lo que no conoce.
- Con los kubes de Kube hay más de 255 tipos de bloque y la celda guarda su id local en un byte: `World.hasRoom` no deja
  poner un bloque que ya no cabe en ese mundo (la nave tiene el suyo).
- `texture.png`: filas 40 y 41 para los kubes de Kube y el Kube misterioso ([62,41] y [63,41]), fila 42 para los pilares y
  zócalos nuevos. Los vidrios de color se pintan al cargar en [54,61] a [57,61]: no están en el archivo.
- Las texturas de los kubes de Kube son de Motion Twin (CC BY-NC-SA 4.0), en `NOTICE`, como `recent.png`.
- El Teletransporte de Kube (8 Sombras) todavía no hace nada.
- 99: un recurso nuevo con `-resource` va en `game.hxml` y en `game_dx.hxml`.
- 110: el parpadeo al llegar a un planeta no se ha comprobado en un PC donde pasaba; para los fallos de dibujo, pedir el
  `gpu.txt` de la carpeta de datos.
## v0.8 preparada (2026-11-11)
Changelogs ES/EN/FR y ERRORES/BUGS pasan de "Sin publicar" a v0.8; enlaces de los README a `releases/tag/v0.8`; menú
"v0.8 · port nativo"; notas en `port/RELEASE.md` (3 idiomas). En el README, las novedades de la v0.8 con 4 fotos nuevas en
`docs/img` (kubes de Kube, anomalía invisible, tienda de la nave nodriza, contrato en curso), sacadas en inglés y sin la
ayuda de teclas (`helptext 0`) con los guiones `kube_blocks`, `anomalia_invisible`, `tienda_centro` y `contrats_parciales`;
la v0.7 queda en una línea con su enlace. Entra también el PR 113 (ESCorp en las frases del robot en francés), sin línea en
el changelog porque esas frases son nuevas de esta versión.
Zips con `package.ps1 -Version 0.8 -HashLink ..\tools-portable\hashlink\hashlink-1.16.0-win` en `port/out/release`
(Windows 8,6 MB, Linux/macOS 3,2 MB). Compilados con la toolchain portable de Cornor923: su hldx 1.16 no tiene
`dx.Window.NO_ACTIVATE`, así que `game_dx.hxml` se compiló con una copia de `dx/Window.hx` que lo define a 0 (fuera del
repositorio). Probado el de Windows descomprimido en una carpeta vacía: OpenGL y DirectX crean partida, cargan el planeta y
abren la base de datos (249 fichas). Falta: etiqueta `v0.8` y crear la release (pre-release) con los dos zips.
## PR 116-119 de Cornor923 integrados (2026-11-12)
Fusionados en local en `main`, en orden 116, 117, 119, 118. Un conflicto en `Settings.save` (117 añade `selectBox`, 118 añade
`keys`): se dejaron los dos campos. Compilan SDL, DX y headless. #116 (celdas de dos bytes) no toca el generador, así que los
hashes de referencia no cambian; una partida guardada con `main` anterior (bb31545+) carga con los mismos bloques y `lightcheck`
0; `mas_de_255.txt` da 288 distintos, 33 con id > 255, misma suma antes y después de cargar, `lightcheck` 0. #117, #118 y #119
no se probaron aquí más allá de compilar (Cornor describe sus guiones en cada PR). Changelogs ES/EN/FR y LEEME/README/LISEZMOI
actualizados (la sección "Controles" de LEEME/README dice que se pueden cambiar). Después, revisión de los `.md`: en
`RESUMEN.md` entran los PR 116-119 y sus órdenes de Dev, y las secciones antiguas "Siguiente paso acordado" y "Pendiente"
quedan marcadas como plan de octubre ya hecho en gran parte; en este archivo, "Lo siguiente" marca lo hecho.

## v0.8.1 preparada (2026-11-13)
Traídos los PR 120-125 de Cornor923 (visor del casco al redimensionar, creativo/supervivencia, buscador de la paleta, contrato
especial ESCorp, Agua ácida doble en la paleta, pantalla de inventario), que no traían changelog: se añadieron a los changelogs
ES/EN/FR y a ERRORES/BUGS. Todo pasa de "Sin publicar" a v0.8.1; enlaces de los README a `releases/tag/v0.8.1` con un párrafo
de novedades; menú "v0.8.1 · port nativo"; notas en `port/RELEASE.md` (3 idiomas) con todo lo nuevo desde la v0.8 (PR 116-125). Compilan SDL y DX. Zips con
`package.ps1 -Version 0.8.1 -HashLink ..\tools-portable\hashlink\hashlink-1.16.0-win` en `port/out/release`.

## Lo siguiente (orden acordado en octubre; la lista al día es `PENDIENTES.md`)
1. (HECHO: bahías del hangar y tienda en el centro, v0.8) **Pvie está construyendo en Minecraft el hangar y la zona de comercio dentro de la Hades:**
   - 3 bahías de al menos 19x19 y 18 de alto (caben las naves del hangar, como máximo 17x17x14), y puestos de comercio;
   - marcas: **bloque de esmeralda** en el centro de cada bahía y **bloque de diamante** en el mostrador del robot.
   Cuando mande el zip nuevo: convertir, leer esas marcas en el conversor (guardarlas en el .bin), aparcar la nave del jugador
   en una bahía, poner el robot y abrir la tienda en el mostrador. Las otras bahías quedan para el multijugador.
2. (HECHO el 2026-10-19) **El robot en el mapa:**
   - uno por sector, que viaja **despacio** entre sistemas (es comerciante);
   - icono con la forma de la Hades, renderizado como `Ship.captureFrames`; seguirlo con clic; al alcanzarlo, salto a la nave nodriza;
   - la velocidad de nuestra nave sale de la nave real (`Explorer.shipBytes` ya existe, pero la fórmula del mapa es aproximada:
     usar la del hangar, `Hangar.check().speed`);
   - ojo: `Ship.captureFrames` todavía centra la cámara con `DEFAULT_SHIP`; debería usar la nave actual.
3. Después (sin empezar; ahora en `IDEAS.md`): equipo del personaje (mejoras de jetpack, botas, etc.; lista de ejemplos en `PENDIENTES.md` 3b).

## Ideas de multijugador de Pvie (apuntadas en PENDIENTES 3c)
- Naves de jugador de como máximo 17x17x14, que aparcan en bahías.
- Naves de gremio grandes, con hangar compartido y permisos, que **se acoplan por fuera con tubos**.
- Tiendas de jugadores en los puestos de la nodriza.
- Servidores = **"Galaxias"** (20–50 jugadores cada una); empezar por Galaxias privadas para amigos.
- Cuidar el rendimiento en el navegador.

## VM Hyper-V con GPU compartida: OpenGL, streaming y tirones (2026-10-17)
Investigado en la VM de Pvie (GPU-PV con RTX 2060 Super, streaming con Apollo y Parsec). Puede explicar errores que reporten
otros jugadores en VMs o por streaming.
- **OpenGL nativo no existe en la VM:** Windows solo da `GDI Generic 1.1` ("OpenGL 3.2+ is required"). El controlador NVIDIA
  (`nvoglv64.dll`) se carga, pero no crea contexto en esa pantalla. Ni el Compatibility Pack de Microsoft, ni registrar el ICD a mano,
  ni Mesa instalado para todo el sistema (`mesadrv.dll` + clave `MSOGL`) lo arreglan.
- **Solución para la versión OpenGL: Mesa 26.2.4 por juego** (pal1000/mesa-dist-win, build mingw). Se copian `opengl32.dll`,
  `libgallium_wgl.dll`, `dxil.dll` y `libspirv_to_dxil.dll` junto a `hl.exe` y se pone `GALLIUM_DRIVER=d3d12`: da OpenGL 4.2 sobre
  DirectX 12 en la RTX. Lo más sencillo sigue siendo la versión DirectX (`game_dx.hxml`).
- **Congelones de la pantalla al abrir o cerrar el juego: eran de Apollo, no del juego.** La captura DDX de Apollo 0.4.6 entra en
  un bucle de reinicios (10–15 en pocos segundos, se ve como "Detecting monitors" en `sunshine.log`) cuando la ventana del juego
  se crea o se destruye. Pasa con DirectX, OpenGL/Mesa e incluso Mesa por CPU, y también si se mata el proceso.
  - Descartado con pruebas: GPU/OpenGL, CPU, sonido, mando, cursor, salvapantallas, memoria, HAGS, 120 Hz, codificador NVENC o software.
  - **Arreglo:** Apollo con `capture = wgc`. WGC solo funciona si Apollo corre como programa en la sesión del usuario, no como
    servicio. En esa VM el servicio está en Manual y una tarea programada lo abre al iniciar sesión con
    `conhost.exe --headless Sunshine.exe`. Con WGC, 0 reinicios en 8 aperturas y cierres. Parsec nunca tuvo el problema.
- **Tirones en el menú: son del juego** (ERRORES #13). El generador del planeta de fondo hace pasos de 200–600 ms en el hilo
  principal. Se ve con `--frametime`.
- El límite de FPS del panel NVIDIA del anfitrión **no** se aplica dentro de la VM (medidos 901 FPS con el límite a 60).
- En Opciones hay **VSync** y **límite de FPS** (30/60/120/144/240 o sin límite), guardados en `settings.json`.
  `--novsync` quita el VSync siempre (para diagnosticar); no resolvió los tirones.

## Avisos
- Commits, PR, notas de publicación y `.md` van sin créditos de IA (ni `Co-Authored-By` ni "Generated with"); los commits
  antiguos que ya los llevan se quedan como están (decisión del usuario, 2026-10-21). El Flash original ya no se usa de referencia.
- El mensaje de validez del hangar puede ir un cambio por detrás (se comprueba cada 15 tmod).
- Las piezas de nave están a la venta en la tienda (ya sirven para el hangar).
- No probado con ratón real: la tienda, el cofre, el hangar y la ventana del idioma inicial (solo con el banco de pruebas).
