# Port nativo (Haxe 4 + Heaps + HashLink)

[English: `README.md`](README.md) · [Français : `LISEZMOI.md`](LISEZMOI.md)

Esta carpeta contiene el port del juego a una aplicación de escritorio nativa, sin Flash. Es trabajo en curso (con errores
conocidos, ver `ERRORES.md` en la raíz); el juego original en Flash, con sus archivos de compilación y sus SWF, sigue intacto en la rama `flash` (aquí solo queda el código original que compila el port).

## Jugar

Compila (ver abajo) y haz doble clic en `jugar.bat`. Abre el menú de inicio: Continuar (la lista de partidas: jugar, renombrar o borrar), Nueva partida, Opciones y Salir.
En Nueva partida eliges nombre, semilla y modo: **Aventura** (como el original, con el inventario vacío) o **Creativo** (añadido nuestro, con bioma y tamaño).
Las partidas y los ajustes se guardan en `%APPDATA%\Galaxy55\` (se puede cambiar con la variable `GALAXY55_DATA`), y las capturas (F2) en su carpeta `screenshots`.
El formato de las partidas puede cambiar entre versiones: no cuentes con que las de hoy sirvan siempre.

## Controles

Son los del juego original (el movimiento y la física son una copia de `ent/Hero.hx` y `Game.moveHero`).

| Acción | Teclas |
|---|---|
| Moverse | W/Z/↑ avanzar, S/↓ retroceder, A/D y ←/→ de lado (en Opciones pueden girar, como en el original) |
| Mirar | ratón (o mando) |
| Saltar y jetpack | Espacio o Ctrl; en el aire, jetpack (gasta combustible, se recarga en el suelo) |
| Caminar despacio | X |
| Casco | H quita o pone el casco |
| Coordenadas y FPS | F las muestra u oculta (ocultas al empezar, como en el original) |
| Excavar o colocar | clic izquierdo, E o Mayús (mantener). Con la mano vacía excava; con un bloque, lo coloca si algo lo sujeta |
| Elegir casilla | 1–0 o la rueda del ratón; Tab = excavador (mano vacía) |
| Tirar la pila elegida | R o Supr |
| Activar (ordenador de a bordo, puertas, bomba exótica) | apuntar y pulsar y soltar. Si se mantiene hasta que el bloque se rompe, se excava: así se recoge la bomba exótica sin que explote (hace falta la carga rosa, como para la roca exótica) |
| Cantina de ESCorp (cofre) | apuntar y pulsar y soltar. El juego no se para: clic coge y deja (Mayús la mitad, Ctrl una; o flechas e Intro, o cruceta y A), arrastrar fuera de la ventana mira y alejarse la cierra (Esc y B también) |
| Volver a la nave | Mayús+K, o entrar en el haz de luz del aterrizaje |
| Pilotar la nave (añadido del port) | ordenador de a bordo > Pilotar la nave: WASD o palanca izquierda la mueven sobre el planeta, el ratón o la palanca derecha giran la cámara, E, Esc, B o Start la dejan donde está (frena, se endereza y aterriza sola) |
| Creativo: paleta de bloques | I (clic = poner el bloque en la casilla elegida, rueda = página) |
| Pausa | Esc |
| Guardado rápido | F5 |
| Captura de pantalla | F2: un PNG sin el casco ni el HUD, al tamaño de la ventana, en `%APPDATA%\Galaxy55\screenshots\` |

No hay botón de correr, como en el original. Mando: palanca izquierda mueve, derecha mira, A salta y jetpack, B camina despacio,
RT excava, LT coloca, RB/LB o cruceta derecha/izquierda cambian de casilla, Y tira el bloque, Back casco, Start pausa. Menús: flechas/Intro/Esc, ratón o mando.

## Compilar

Hace falta (Windows):
1. **Haxe 4.3.x** (https://haxe.org/download/) y **HashLink 1.16** para Windows (https://github.com/HaxeFoundation/hashlink/releases).
   Pon las carpetas en el `PATH`; `haxe` y `hl` deben funcionar en una terminal.
2. Librerías de Haxe:

       haxelib install format
       haxelib git heaps https://github.com/HeapsIO/heaps
       haxelib git hashlink https://github.com/HaxeFoundation/hashlink
       haxelib dev hlsdl <carpeta-donde-clonaste-hashlink>/libs/sdl

   (`hlsdl` necesita el código de HashLink: clona ese repositorio y apunta `haxelib dev` a su carpeta `libs/sdl`.)
   Así se montó en el equipo de desarrollo (Heaps de la rama principal, HashLink 1.16, sin permisos de administrador). **No está probado desde cero en otro equipo**: si algo falla, abre un *issue*.
3. Desde la raíz del repositorio:

       haxe port\game.hxml          juego completo con menús   (-> port\out\galaxy55.hl)
       haxe port\render.hxml        prueba técnica de render   (-> port\out\render.hl)
       haxe port\headless.hxml      generador de planetas sin pantalla, HashLink
       haxe port\headless_flash.hxml  el mismo programa para Flash (referencia)

`jugar.bat` busca `hl` en el `PATH`; si lo tienes en otra carpeta, define la variable `HL` con su ruta antes de ejecutarlo.

### Versión DirectX (opcional)

Para equipos sin OpenGL 3.2 (por ejemplo, máquinas virtuales con la GPU compartida) hay una versión DirectX 11:

       haxelib dev hldx <carpeta-donde-clonaste-hashlink>/libs/directx
       haxe port\game_dx.hxml       (-> port\out\galaxy55_dx.hl, se abre con jugar_dx.bat)

Problema conocido: si la fuente de `hldx` es más nueva que tu `directx.hdll` (binario de HashLink 1.16 + hashlink de git),
cambiar el modo de pantalla falla con "Primitive or library is missing". Se arregla en `libs/directx/dx/Window.hx`,
`set_displayMode`: envolver el cuerpo en `try { ... } catch( e : Dynamic ) { winSetFullscreen(win, mode != Windowed); }`.
Con un `hldx` de la misma versión que tu HashLink no pasa.
El juego busca los gráficos del original en `res\` (paquete portátil) o, si no existe, en `src\G55\fla\client\gfx\`; la variable `GALAXY55_RES` fuerza otra carpeta.

## Qué hay

- `game/` el juego: menús (`GalaxyApp`, `Ui`), idiomas (`Lang`), ajustes (`Settings`), partidas (`SaveData`), planeta, luz y mallado (`World`),
  modelos de bloque (`Models`), cielo y niebla (`Sky`), nieve (`Snow`), jugador, excavar y colocar (`GameView`), inventario (`Inv`, `InvBar`, `Palette`),
  efectos y sueltos (`Fx`, `Drops`) y la nave (`Ship`, `ShipData`).
- `explore/` el mapa de estrellas (`Explorer`, con el robot comerciante y las flechas GPS). El agua que fluye está en `game/WorldProcess.hx`.
- `shim/` capa de compatibilidad `flash.*` para que los generadores originales compilen en HashLink.
- `headless/` programas de verificación: los mundos son idénticos a los de Flash (hash Adler-32, agua y bloques); también leen la nave y el guardado.

## Diferencias con el original

- La nieve del bioma de invierno es un añadido de este port: el original no la tiene.
- El modo creativo y su paleta son un añadido de este port.
- El menú del ordenador de a bordo tiene un aspecto propio, como en la versión Flash (el original era una página web).
- La ventana de la cantina de ESCorp muestra también tu inventario, se cierra además con Esc, B o Cerrar y se maneja con el
  teclado y el mando (mientras está abierta, las flechas mueven su marca y no al jugador). Lo que guarda va en la partida
  (en el original, en el servidor) y sale suelto si se rompe.
- La tienda del robot comerciante (en el original era un panel web), su nave por el mapa de estrellas y la flecha GPS naranja
  que lo señala son un añadido de este port.
- Los contratos de la ESCorp (ordenador de a bordo > Contratos) son un añadido de este port (en el original los daba el
  servidor; solo queda la lista de bloques triviales de los contratos de base). Se editan en `contracts.json`. Los créditos
  de salida son 200 y llegan al acabar el tutorial (antes 500 desde el principio).
- La lava hace explotar la bomba antigua (cambio del port): el original la rompía y la soltaba, como sigue haciendo el agua.
- La cascada y el agua que pone el jugador bajan de altura en cada paso, con la superficie inclinada: añadido de este port.
  El mar llena los huecos hasta su nivel y, cuando el agua que entra suma el volumen de una capa del mar, el nivel baja un
  bloque en todo el planeta, como el original.
- Las plantas y demás modelos se apuntan por lo que se ve (los píxeles de sus hojas), no por toda la celda (el original las trataba como un bloque entero).
- La bomba exótica hace explotar también las bombas que alcanza, una por fotograma: el original tenía el código, pero una
  comprobación hacía que nunca se disparara. La explosión deja la roca madre (capa 0) en su sitio (el original también la
  quitaba), la bomba no explota en el hangar y suelta 8 trozos por bloque en vez de 75 para que el juego no se congele.
- Las texturas lejanas usan mipmaps como el original, pero las plantas no se borran con la distancia y cada bloque lejano
  conserva su color (en el original las plantas finas desaparecían de lejos y, más lejos aún, se mezclaban texturas vecinas).
- El haz de luz del aterrizaje sigue cualquier cambio en la columna bajo la nave y empieza encima de los bloques bajos como las
  placas (el original solo lo movía al romper un bloque ahí); se vuelve a la nave solo de pie en su base, no desde más arriba.
- Pilotar la nave sobre el planeta es un añadido de este port (el original la dejaba siempre en el mismo sitio de cada planeta):
  desde el ordenador de a bordo, solo en los planetas jugables (no en la nave nodriza, el hangar ni durante el tutorial). Va
  siempre a la misma altura, sin gasto, con una cámara por detrás y por encima y la niebla más suave mientras dura; el haz de
  luz marca dónde quedará (a toda velocidad se desvanece y vuelve al ir despacio, al pararse y al aterrizar). Acelera y frena con suavidad, gira hacia donde va y se inclina en las curvas; al dejarla vuelve a su
  orientación de siempre antes de aterrizar (sus bloques, cofres y sintetizadores no giran). El sitio se guarda por planeta; sin pilotarla, la nave aterriza donde siempre.
- Opciones añadidas: sombra del bloque que vas a poner, nombre del bloque apuntado y quitar las olas del agua.
- El turbo minero hace excavar tres veces más rápido hasta 15 bloques a su alrededor (5 en el original) y se recupera al
  romperlo (en el original se perdía).
- La captura de F2 se guarda directamente en la carpeta `screenshots` y un mensaje dice dónde (el original abría el diálogo de Flash para guardarla).
- En el hangar no se pueden poner líquidos (agua, cascadas, arena movediza, lava...) ni la bomba exótica: un aviso dice que
  no están permitidos a bordo. El original solo impedía poner lo que se extiende (fuente de cascada y lava), sin aviso.
- En el hangar se excava cuatro veces más rápido y sin cargas, como en las zonas de sintetizador de la nave: cambio de este port,
  para editar la nave con comodidad. En el original se excavaba como en el planeta, con las cargas.
- Lo que falta está en `PENDIENTES.md`, los fallos en `ERRORES.md` y las ideas para más adelante en `IDEAS.md` (raíz del repositorio).
