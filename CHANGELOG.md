# Novedades (versión nativa)

[English: `CHANGELOG.en.md`](CHANGELOG.en.md) · [Français : `CHANGELOG.fr.md`](CHANGELOG.fr.md)

## Sin publicar
- **Base de datos ESCorp** (añadido del port), en el ordenador de a bordo, con tres pestañas: el **Kubindex**, con todos los
  kubes del juego por categorías (apuntar uno con el láser lo localiza; tenerlo en el inventario lo recupera, con las veces
  que se ha puesto, roto y fabricado, las recetas que lo dan y las que lo usan); **Espacio**, con los tipos de planeta y de
  cometa explorados y las anomalías cruzadas; y **Recetas**, que se descubren al recuperar uno de sus kubes. Un aviso arriba
  a la derecha dice lo nuevo y las fichas nuevas llevan una marca hasta mirarlas. Se abre al instante. En creativo se sabe
  todo; en el tutorial se abre después de fabricar el blindaje.
- **Cometas** (añadido del port): mundos pequeños que visitan los sistemas solares un tiempo (en cada franja de 2 horas, cada
  sistema tiene 1 posibilidad entre 6). Escanear uno es aterrizar, sin gastar licencia. El amarre está contado (de 1:30 a
  15:00 según la velocidad de la nave; el tiempo solo corre abajo) y, al acabarse, se vuelve a la nave. Al despegar se
  pierde. El cometa calcinado tiene roca de cráter de meteoritos, escombros calcinados, vetas de eterium con meteoritos de
  eterium y lava, sin agua.
- Sin parones al aparecer el menú de inicio, en las pantallas de carga, al llegar a un planeta ni al cargar la nave nodriza
  (antes, hasta casi un segundo, y unos 6 s la primera visita a la nodriza).
- Caer en la arena movediza: al tocarla se recibe el golpe de la caída, como en el suelo, y la arena para la caída (cambio
  del port: en el original el daño llegaba al final, el de toda la caída).
- Un bloque roto en la zona del sintetizador o en el hangar se suelta siempre, aunque en otro sitio solo se suelte con
  suerte; un suelto enterrado bajo bloques puestos sale por un lado en vez de acabar en el techo de la nave (cambios del port).
- Fuera del planeta principal, el ordenador de a bordo ya no ofrece "Pilotar la nave" (antes salía y avisaba al pulsarlo).
- Las felicitaciones del final del tutorial se van al despegar y duran 12 s (antes 16): ya no vuelven en el planeta
  siguiente, seguidas de "este es tu planeta principal".
- Editor de kubes: en francés, la ayuda vuelve a decir "enregistrer" para Ctrl+S.
- **Editor de kubes** (añadido del port): en el menú de inicio, debajo de Nueva partida. Se dibujan las caras de un bloque
  píxel a píxel en una de las formas que ya dibuja el juego (cubo, cubo de 6 caras, caja, puerta, planta, panel, columna...),
  se ve girar en 3D y se guarda como archivo `.kube` en la carpeta `kubes` de los datos del juego para enviárnoslo. Se puede
  partir de cualquier bloque del juego.
- El ordenador del sintetizador se usa también con un bloque en la mano y con el clic derecho (cambio del port).
- Dos clics rápidos ponen los dos bloques (cambio del port: el original no ponía el segundo si llegaba antes de 0,47 s).
- Durante el tutorial el sintetizador solo fabrica aluminio y blindaje: ya no se puede gastar el aluminio en otra receta y
  quedarse atascado.
- En el tutorial sale la flecha verde hacia el planeta del aterrizaje de emergencia.
- Al abrir el ordenador de a bordo o el menú de pausa, el puntero va al centro de la ventana.
- La ventana del juego se abre ya con su tamaño y su título (antes se veía un momento pequeña).
- La hierba roja alta ya no suelta trozos blancos al romperse.
- El suelo bajo bloques parciales juntos (p. ej. cuatro lingotes de hierro o aluminio en la nave) ya no se ve negro (cambio
del port: en el original esos bloques no dejan pasar la luz; paredes y techos siguen igual).
- Editor de kubes: un kube llamado como un nombre reservado de Windows (con, aux, nul...) ya se puede guardar.
- **Licencias de exploración de la ESCorp** (añadido del port; en el original las llevaba el servidor): en aventura, escanear
  un planeta gasta una licencia, 4 en total (1 principal y 3 de exploración); en creativo no hay límite. El primer planeta
  escaneado es el principal (con tutorial, el suyo). **Solo se pilota la nave sobre el planeta principal**: en los demás, el
  ordenador de a bordo no ofrece "Pilotar la nave". Allí, "Licencias de exploración" muestra las licencias y deja cambiar de
  planeta principal (gratis la primera vez, luego 1000 créditos y 24 horas reales entre cambios); en el mapa, "Abandonar"
  libera la licencia de un planeta. Las partidas anteriores dan licencia a los planetas visitados y el de salida es el principal.
- El volumen de Opciones ya se aplica a los sonidos (a 0 no suena nada).
- La cascada se ve detrás del cristal; la cámara ya no se mete en el bloque de arriba al subir por una cascada.
- Se pone un bloque sobre la hierba alta (se pisa) y la sombra de colocar solo sale donde se puede poner.
- Los bloques soltados ya no tiemblan en el suelo; las hierbas sueltan su propia hierba.
- La nieve solo cubre bloques en el planeta nevado y a cielo abierto.
- La niebla depende de la distancia y no cambia al girar la cámara.
- El ordenador de a bordo, la tienda, los contratos y las licencias ya no paran el juego (se sigue curando en la nave).
- El robot comerciante ya no salta con la nave al entrar en un sistema; el juego ya no se cierra al abrir el mapa en un PC lento.
- Botones del ordenador de a bordo sin las notas entre paréntesis.
- Los bloques parciales junto a un neón vuelven a verse iluminados; la nave se sigue viendo al cruzar el borde del mundo.

## v0.6 — pre-release
- Repositorio: se quitan de `main` los archivos que solo compilaban la versión Flash (`client*.hxml`, `build.bat`/`build.sh`,
  los SWF de `release/`, `libs/heaps` y `libs/format_old`). Siguen intactos en la rama `flash`. El juego no cambia.
- **Pilotar la nave** (añadido del port): en el ordenador de a bordo, "Pilotar la nave" la mueve sobre el planeta con WASD o la
  palanca izquierda (el ratón o la palanca derecha giran la cámara) y E, Esc, B o Start la dejan allí. Siempre a la misma
  altura y sin gasto; acelera y frena con suavidad, gira hacia donde va y se inclina en las curvas, y al dejarla frena, se
  endereza y aterriza sola. El haz de luz marca dónde quedará: a toda velocidad se desvanece y vuelve al ir
  despacio, al pararse y al aterrizar. Solo en los planetas jugables: no en la nave nodriza, el hangar ni
  durante el tutorial. El sitio se guarda por planeta, también a mitad del vuelo; las partidas anteriores no cambian.
- De **Cornor923** (¡gracias!, PR 60-63):
  - **Contratos de la ESCorp** (añadido del port; en el original los hacía el servidor y se perdieron): botón "Contratos
    (ESCorp)" del ordenador de a bordo con 3 contratos para entregar bloques a cambio de créditos (uno de base de los bloques
    triviales del original y dos encargos). El tablero es el mismo para todos y cambia cada 30 minutos de hora real; lo
    entregado se guarda con la partida. Se configura en `contracts.json` sin recompilar. Desactivado durante el tutorial. Los
    créditos de salida bajan de 500 a 200 y la ESCorp los envía al acabar el tutorial (0 mientras dura).
  - La lava hace explotar la bomba antigua (cambio del port: el original la rompía y la soltaba, como sigue haciendo el agua).
  - Con un bloque en la mano se pone delante de plantas, modelos y bloques parciales (antes no se podía), y las hierbas y
    estalactitas se pisan al poner, como en el original.
  - Desde dentro de la nave, el marco de una ventana ya no se pisa con un neón pegado por fuera (cara trasera oculta, como el original).
- Arreglos de fallos encontrados por **Sekhmet**: poner un bloque encima de la capa más alta ya no lo gasta sin ponerlo; con la
  cabeza dentro de una fuente de cascada o de arena movediza se puede apuntar y excavar lo de delante, como en el original; la
  arena movediza, el hielo y el cristal ya no se ven huecos junto a una cascada (cambio del port).

## v0.5 — pre-release
- Arreglos de Cornor923 (¡gracias!), integrados desde sus PR 17-30 (cambio del port): sin gasto de oxígeno bajo el agua en
  creativo; el hielo junto al agua ya no se corta en triángulos visto desde abajo; la ayuda de la paleta creativa cabe en su
  panel y no hay bloque marcado al abrirla; sin banda sin agua bajo un bloque en el mar con olas; tras morir te quedas en la
  nave (también al cargar una partida guardada con 0 de vida); sin daño en el hangar; los intercambios con el robot no se
  pierden al guardar en la nave nodriza y se cuenta el tiempo de juego allí; en el mapa, la nave tiene los mismos colores en
  todos los planetas, conserva su rumbo al pararse y se centra según la nave del hangar.
- Del original, traído por **Cornor923** (¡gracias!, PR 31-51):
  - la cámara y el HUD tiemblan al romper bloques y al aterrizar;
  - el turbo minero funciona (potencia 3 a menos de 15 bloques, con su icono en el HUD);
  - en tu nave recuperas vida poco a poco;
  - la bomba exótica explota al activarla (y hace estallar las bombas que alcanza);
  - Mayús+K funde a blanco unos 3 segundos y te deja en la nave con la vida y el oxígeno llenos;
  - la vista baja al morir, sube con Mayús+K y el teletransportador, y se agacha un poco al recibir un golpe;
  - bajo el agua el campo de visión se estrecha y el cielo toma el color del líquido, sin estrellas;
  - el nivel del mar baja un bloque cuando el agua que inunda huecos llena una capa del mar;
  - salen trozos del bloque en el punto donde da el láser;
  - el cielo estrellado del original en los planetas, que gira al andar;
  - texturas con mipmaps: el paisaje lejano ya no parpadea (cambio del port: las plantas no se borran de lejos);
  - marco de selección visible, bloques soltados del tamaño del original, iconos y barra de carga del planeta como el original;
  - F2 guarda una captura sin el HUD y F muestra u oculta las coordenadas y los FPS (ocultos al empezar);
  - el sonido de rotura suena una vez por cada bloque soltado, también en las cadenas;
  - la ventana de la cantina ya no para el juego y se cierra al alejarte;
  - el rayo de aterrizaje sigue el suelo bajo la nave (cavar o poner bloques debajo ya no lo deja flotando);
  - en el hangar: sin líquidos ni bomba, los soportes funcionan (una puerta o un neón sin apoyo se caen) y se excava más rápido
    y sin cargas (cambio del port).
- Más de **Cornor923** (¡gracias!, PR 52-59, cambio del port salvo lo marcado):
  - **menú de inicio nuevo**: Continuar abre la lista de partidas (jugar, renombrar, borrar); Nueva partida pide nombre,
    semilla y modo (Creativo: bioma y tamaño; Aventura: tutorial sí/no);
  - **tutorial guiado** (añadido del port) para las partidas de aventura nuevas, que empiezan en el espacio con el inventario
    vacío, como el original; se puede saltar desde la pausa o el ordenador de a bordo;
  - el ordenador de a bordo ya no tiene el atajo de prueba a la nave nodriza;
  - la flecha «<» de los selectores va a la opción anterior; la Ciudad muerta sale con su nombre y color en el mapa;
  - en creativo, una caída fuerte ya no hace temblar la pantalla como un golpe;
  - una puerta abierta de la nave ya no cuenta como agujero en el hangar y las puertas se guardan cerradas, como el original;
  - arreglos perdidos al integrar los PR 31-51 (icono del turbo con el temblor, ayuda de las órdenes de prueba, READMEs).

## v0.4 — pre-release
- **Vida y oxígeno**, como el original: las caídas fuertes, la lava, el agua ácida, el carbón ardiente y las hierbas ácidas
  hacen daño; bajo el agua se gasta el oxígeno y, sin él, te ahogas; las arenas movedizas también te ahogan; la planta y la
  caja de curación curan. Barras de vida y oxígeno abajo (solo se ven si no están llenas) y destello rojo o azul. Al morir
  vuelves a la nave con la vida llena, sin perder nada. En creativo no hay daño.
- Opciones separadas en secciones (General, Controles, Gráficos, Interfaz): todo junto ya no cabía.
- Plantas y demás modelos: se apuntan por lo que se ve (sus hojas, no toda la celda); con varias plantas juntas ya es fácil romper la que miras (cambio del port).
- **Olas del agua**, las del original; se pueden quitar en Opciones.
- Bloques parciales (placas, hierro, cofres…): luz por esquina como el original.
- Menú: un solo planeta de fondo pequeño; ya no da tirones mientras se genera.
- **Agua que fluye** (el `Process.hx` del original): el mar llena lo que cavas a su lado hasta su nivel; la cascada y la lava
  caen y se extienden y desaparecen sin fuente; la hierba se cubre y descubre; lo anclado y los detalles se rompen al quitar
  su apoyo. La cascada y el agua que pones bajan de altura en cada paso, con la superficie inclinada (añadido del port).
- **Robot comerciante en el mapa de estrellas:** viaja entre los sistemas del sector; al pulsarlo se para y te espera, y al
  acoplarte entras en su nave (la nave nodriza), con la tienda. Al salir vuelves al mapa. En el mapa, su nave tiene la forma
  de la nave nodriza vista desde arriba.
- **Despegar es salir del planeta**, como en el original: el planeta se descarga (sus cambios se guardan) y no queda nada
  dibujado detrás del mapa. Para volver, aterrizas. Si guardas o cierras el juego en el espacio (o dentro de la nave del robot),
  "Continuar" te devuelve al mapa donde estabas; la lista de partidas dice "En el espacio".
- Mapa de estrellas: Esc (o Start del mando) abre un menú de pausa (Reanudar, Opciones, Menú principal).
- **Flechas GPS** del original en el mapa: apuntan a los planetas que visitaste (y a sus sistemas) y al robot (en naranja).
- Opciones: sombra del bloque que vas a poner y nombre del bloque apuntado (pequeño, abajo a la derecha); los dos se pueden quitar.
- Modo creativo: las cuatro aguas (normal, oscura, ácida y de invierno) están en la paleta.
- Arreglos de **Cornor923** (¡gracias!): la roca madre (capa 0) se dibuja y se puede construir encima; el menú principal se
  pega a los bordes en ventanas anchas; el sintetizador gasta primero los bloques del inventario y deja la zona como plantilla
  (como el original); el juego se abre como `galaxy55.exe`, con su icono (Discord ya no dice "Half-Life"); el agua y el hielo
  se dibujan en el orden correcto; ya no se ponen bloques dentro de una fuente de cascada ni en arenas movedizas; los fondos
  de la tienda, el cofre, la paleta y el mapa tapan toda la ventana; textos centrados en los botones del mapa y sin pisar el
  botón Cerrar; nombres para muchos bloques que no lo tenían (variantes con nieve, cargas, plantas, cristales de bonus).
- El bloque en la mano ya no tiembla al andar.
- Arreglos reportados por Sekhmet (¡gracias!): atajos de teclado (Tab excava y 1-0 son las 10 casillas), se pueden poner
  bloques bajo el agua, no nieva bajo techo ni en cuevas, el hielo ya no suelta un bloque al romperlo, sombra del bloque que
  se va a poner, nombre del bloque apuntado y el congelador vuelve a congelar el agua y la lava cercanas.
- Linux: los zips usan `/` en las rutas (antes salían archivos con `\`); pasos de Linux de Sekhmet en el `LEEME` del zip.
## v0.3.1 — pre-release
- Opciones: sincronización vertical (VSync) y límite de FPS (30, 60, 120, 144, 240 o sin límite).
- Arreglos de **Cornor923** (¡gracias!): el velo del agua y los fondos de los menús cubren ventanas más anchas que 16:9,
  sin manchas oscuras a través del hielo, la cabeza ya no se mete en los bloques al caer o flotar, `jugar.bat` usa
  `hlw.exe` (sin consola) si está, y README en francés.

## v0.3 — pre-release
- Hangar: rehaz tu nave bloque a bloque, como en el original; se sale por el teletransportador para guardarla.
- Tienda: compra y vende bloques con créditos, al robot comerciante.
- Sonido: los 12 efectos del original (pasos, salto, aterrizaje, caída fuerte, jetpack, láser, romper y recoger bloques).
- Punto de mira fijo en el centro de la pantalla.
- Nombres de los bloques completos en español, inglés y francés (antes salían en español o mezclados).
- Cofres: un toque los abre y mantener el láser los rompe (lo que tenían cae al suelo). En tu nave, el ordenador y las
  puertas no se rompen.
- Creativo: paleta con mando (R3), copiar el bloque apuntado (L3 o clic central) y dos bloques nuevos, blindaje
  amarillo y negro, para franjas de peligro.
- Nave nodriza: cielo de espacio profundo (Vía Láctea, nebulosas, miles de estrellas y galaxias lejanas), plazas con
  borde de franjas de peligro y editor (`editar_nodriza.bat`).
- Menos tirones al romper o poner bloques, sobre todo en la nave nodriza.
- El rayo del teletransporte a la nave ya no desaparece con la niebla del invierno.
- Arreglos reportados por Sekhmet (¡gracias!): dentro de un líquido la pantalla y la niebla toman su color, como en el
  original (la arena movediza ya no parece transparente); no nieva bajo el agua; el agua tiene caras laterales; el hielo
  sumergido queda detrás del agua; textos del mapa de estrellas traducidos.
- Nombres originales de los biomas en francés (Terres Rouges, Rocaille sombre, Sables arides), encontrados por Sekhmet
  en la antigua Twinpedia.
- Versión DirectX opcional (`haxe port\game_dx.hxml`, `jugar_dx.bat`), además de la de OpenGL.
- Nave nodriza: indestructible, mejor iluminada, puertas cerradas, campos de fuerza láser en los hangares, 10 plazas
  marcadas, tu nave aparcada en la tuya (apareces dentro y su ordenador te devuelve), y una tienda con un robot
  comerciante animado en el túnel de entrada.
- Mando: cofres, tienda y cambio de casilla (LB/RB).
- El juego ya no se congela unos segundos al arrancar.
- `jugar.bat` funciona aunque el PATH tenga carpetas con paréntesis.

## v0.2 — pre-release
- Mapa de estrellas con las animaciones del original (entrar y salir de un sistema, hiperespacio, destellos, espera del
  servidor), fondo común con remolino; el sistema se genera en segundo plano y ya no se congela.
- Bloque elegido en la mano y partículas al romper, copiados del original.
- Ciudad muerta elegible en Nueva partida.
- Arreglos: borrar partida, quitar la fuente de cascada en la nave, giro de los sueltos, nieve dentro de la nave.
- Cambios respecto al original: el sintetizador gasta los bloques de su zona; hierbas y estalactitas rompibles; curvatura
  al 60 %; montículos de nieve con planta escondida como la nieve; acercamiento al planeta al entrar.

## v0.1 — pre-release
Primera versión nativa publicada: menús y partidas guardadas, planetas idénticos a los de Flash, excavar/colocar/jetpack,
modo creativo, nave (teletransportador, puertas, sintetizador con recetas originales, ordenador), mapa de estrellas
(sector, sistemas, escaneo y aterrizaje; el universo forma parte de la partida) y paquete portátil con `jugar.bat`.
Fallos conocidos: [`ERRORES.md`](ERRORES.md).

La versión Flash anterior tiene sus propias novedades en [`docs/flash/CHANGELOG_flash.md`](docs/flash/CHANGELOG_flash.md).
