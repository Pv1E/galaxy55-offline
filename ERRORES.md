# Errores conocidos (versión nativa)

[English: `BUGS.md`](BUGS.md) · [Français : `BUGS.fr.md`](BUGS.fr.md)

Si encuentras uno que no está aquí, abre un *issue* con lo que hacías y, si puedes, una captura.
Los que están **arreglados** se mueven al final. Los detalles técnicos están en [`port/RESUMEN.md`](port/RESUMEN.md).

## Abiertos

| # | Dónde | Qué pasa |
|---|---|---|
| 4 | Luz | **Por comprobar jugando:** los bloques parciales (placas, hierro, cofres…) ahora toman la luz de cada esquina de las celdas vecinas, como el original (`Builder.addCustomQuad`); antes toda la cara tenía una sola luz. Los modelos ya usaban la luz del original. |
| 8 | Invierno | Las **hojas del abeto** sueltan material; puede que en el original no. |
| 10 | Render | Los **cristales** sueltos (cargas) se ven demasiado anchos. |
| 14 | Agua | **(¿Arreglar?)** Al abrir una cueva junto al mar, el agua entra y la llena de golpe a la misma altura que el mar, sin bajar mientras avanza. Ahora, como en el original (`net/Local.hx` y `SReduceWater`), el agua que entra cuenta y, cada vez que suma el volumen de una capa del mar (cientos o miles de bloques, según el planeta), la capa de arriba desaparece en todo el planeta: el mar baja un bloque. Una cueva pequeña no llega a tanto y se sigue llenando de golpe hasta el nivel del mar, como en el original. |

## Arreglados

- Sin publicar (de **Sekhmet**, arreglados por **Cornor923**): el volumen a 0 ya no suena; la cascada se ve detrás del cristal.
- v0.6 (encontrados por **Sekhmet**, ¡gracias!): poner un bloque encima de la capa más alta ya no lo gasta sin ponerlo (no se apunta, como el original); con la cabeza dentro de una fuente de cascada o de arena movediza se apunta y se excava lo de delante (el original no cuenta la celda de la cámara); la arena movediza, el hielo y el cristal ya no se ven huecos junto a una cascada (cambio del port: su cara contra la cascada se dibuja, porque aquí la cascada baja de altura).
- v0.5 (#15, de **Sekhmet**): la nave ya no cambia de sitio al reabrir la partida. Hasta la v0.4 el sitio de aterrizaje se
  calculaba con los cambios del jugador: al cavar o construir donde aterriza, la nave salía en otro sitio y el jugador, guardado
  dentro, caía al suelo. Desde la v0.5 se calcula sobre el terreno original (comprobado con `port/dev/nave_sitio.txt`). Una
  partida de la v0.4 en la que la nave ya se había movido la ve volver una vez a su sitio de siempre al pasar a la v0.5.
- v0.4: el menú usa un solo planeta de fondo, pequeño (antes tres grandes que cambiaban cada 22 s): ya no da tirones mientras se generan; queda uno de ~0,4 s al principio, cuando se dibuja el planeta por primera vez (#13). La cascada no se congela junto al hielo, solo con el congelador, como el original (#12, comprobado).
- v0.3 (encontrados y reportados por **Sekhmet**, ¡gracias!): la arena movediza y el agua ya no se ven transparentes desde dentro (velo y niebla del color del líquido, como el original); ya no nieva bajo el agua; el agua tiene caras laterales y de fondo; el hielo sumergido queda detrás del agua; los textos del mapa de estrellas salen en el idioma elegido.
- v0.4 (reportados por **Sekhmet**, ¡gracias!): el agua fluye (`WorldProcess.hx`, el `Process.hx` del original); se pueden poner bloques bajo el agua; ya no nieva bajo techo ni en cuevas; el hielo no suelta un bloque al romperlo (como el original); atajos de teclado (Tab excava y 1–0 son las 10 casillas; antes la última no tenía tecla).
- v0.4: el bloque en la mano ya no tiembla al andar; el resaltado de la paleta creativa ya no se queda pegado.
- v0.4 (arreglados por **Cornor923**, ¡gracias!, PR 17-30, cambio del port): sin gasto de oxígeno bajo el agua en creativo; el hielo junto al agua ya no se corta en triángulos visto desde abajo; la ayuda de la paleta creativa cabe en su panel y no hay bloque marcado al abrirla; sin banda sin agua bajo un bloque en el mar con olas; tras morir te quedas en la nave (también al cargar una partida guardada con 0 de vida); sin daño en el hangar; los intercambios con el robot no se pierden al guardar en la nave nodriza y se cuenta el tiempo de juego allí; en el mapa, la nave tiene los mismos colores en todos los planetas, conserva su rumbo al pararse y se centra según la nave del hangar.
- v0.4: el juego funciona también con DirectX (`port/game_dx.hxml`), útil donde no hay OpenGL 3.2 (p. ej. máquinas virtuales).
- v0.4: la capa 0 (roca madre) se dibuja, como en el original: el fondo de un hoyo excavado hasta ella ya no deja ver el vacío y el cielo bajo el planeta.
- v0.4: el sintetizador gasta primero los bloques del inventario, como el original: mientras el inventario los tenga todos, los puestos en su zona se quedan como plantilla y se puede fabricar la misma receta una y otra vez; si falta alguno, se gastan los puestos (se deshace el cambio de la v0.2).

- v0.2 (cambio respecto al original): los montículos de nieve con una planta escondida (`BWinterHidden`) se ven como la nieve, sin brillo propio.
- v0.2: borrar una partida desde el menú (botón Borrar y después elegir la partida; la confirmación ya no se abre dos veces).
- v0.2: ya no nieva dentro de la nave.
- v0.2: el mapa ya no se queda trabado al entrar en un sistema (se genera en segundo plano mientras viajas).
- v0.2 (cambio respecto al original): al entrar en un planeta la cámara se acerca a él en vez del fundido a negro, y el nombre sale una sola vez.
- v0.2: la fuente de cascada se puede quitar (se apunta igual que en el original).
- v0.2: partículas al romper un bloque; los bloques sueltos giran a la velocidad del original.
- v0.2: Ciudad muerta se puede elegir en Nueva partida (Shed todavía no).
- v0.2 (cambio respecto al original): la curvatura del planeta es el 60 % de la del original (se notaba demasiado, sobre todo en planetas pequeños).
- v0.2: se ve el bloque elegido en la mano.
- v0.2: mapa de estrellas con las animaciones del original: entrar y salir de un sistema (zoom, hiperespacio, destellos; la salida deja pasar el anillo y te saca al rato), escanear (fundido, nombre y barra) y aterrizar; fondo común con remolino.
- v0.2 (cambio respecto al original): el sintetizador gasta siempre los bloques puestos en su zona.
- v0.2 (cambio respecto al original): las hierbas del suelo y las estalactitas de hielo se rompen; dan hierba alta (33 %) o hielo (7 %), como las plantas y el hielo negro del original.

- Aparecía «en el cielo» al entrar en el sintetizador (no se ha vuelto a ver).
- Los bloques del sintetizador se duplicaban al colocarlos.
- Pantalla en negro al despegar hacia el mapa de estrellas.
- Volver de un planeta dejaba la nave fuera de su galaxia (ahora vuelve junto al planeta).
