## Galaxy 55 (offline) v0.9 — novedades

La versión 0.9 del port nativo **no oficial** de Galaxy 55 (Motion Twin, 2012) ya está aquí. Sin Flash, sin navegador y sin servidor.

**Cómo jugar (Windows):** descomprime la carpeta entera y haz doble clic en `jugar.bat`. Si no abre (equipos sin OpenGL 3.2 o máquinas virtuales), usa `jugar_dx.bat`, la versión DirectX. No hay que instalar nada. Las partidas se guardan en `%APPDATA%\Galaxy55\`.
**Linux y macOS:** zip aparte; necesita HashLink 1.16 instalado (ver su `LEEME.txt`).

Todo lo nuevo es obra de **Cornor923** (¡gracias!, PR 126-148). Cinco grandes novedades que no estaban en el juego original: el almacén de la nave, el equipo que se queda en el suelo al morir, el menú "Contactar con la ESCorp", los cuadros y tus kubes del editor en las partidas creativas. Por debajo cambian también el generador de planetas y el formato de las partidas: lee "Tus partidas guardadas" antes de abrir una partida antigua.

### Las cinco grandes novedades

#### El almacén de la nave
Nuevo botón "Almacén" en el ordenador de a bordo, después de "Modificar la nave": 4 casillas de bloques, como una cantina de ESCorp, y las cargas aparte, sin casillas (amarillas hasta 24, azules 12, rosas 5 y de bonus sin límite). Se arrastra y se suelta como en la pantalla de inventario. En la nave nodriza, el ordenador de tu nave aparcada también lo abre. Hay uno por partida y se queda aunque rehagas la nave en el hangar.

#### Al morir, el equipo se queda en el suelo
Al morir o al volver a la nave con Mayús+K, lo que llevas (bloques, gemas y cargas; los créditos no) cae en una cantina de ESCorp pequeña, donde estabas. No caduca: puedes volver a por ella. En creativo, en el tutorial, en el hangar y en la nave nodriza no se deja nada.
Es una opción de cada partida, activada si no se cambia. En Nueva partida, el botón nuevo "Personalizar" tiene la semilla y la casilla "Equipo al suelo"; en Continuar, "Renombrar" pasa a ser "Modificar" y la cambia después.

#### Contactar con la ESCorp
El ordenador de a bordo agrupa "Comerciar", "Contratos ESCorp" y "Mejoras ESCorp" en un submenú nuevo, "Contactar con la ESCorp". Las mejoras, a cambio de cargas de bonus, llegarán más adelante: de momento la pantalla muestra tus cargas de bonus y que no hay ninguna. El contrato especial sale ahora el primero del panel de contratos y, en el tutorial, el botón que toca pulsar se marca en verde.

#### Cuadros
Los 16 cuadros de CroqueMotel (Motion Twin) están en la paleta creativa. Se cuelgan en la pared que apuntas, girados hacia ti (ni en el suelo ni en el techo), y caen si quitas la pared. El editor de kubes tiene una forma nueva, "Cuadro (en la pared)", para hacer los tuyos.

#### Tus kubes en tu mundo
En una partida creativa, los kubes que dibujas en el editor de kubes (o los `.kube` que dejas en su carpeta) salen al final de la paleta, con una esquina cian, y se ponen como cualquier bloque, puertas y planos incluidos. Hasta 128 por partida. Un kube retocado se ve nuevo la próxima vez que cargas la partida.

### También en la v0.9
- **Subir planchas andando:** se sube a una plancha sin saltar, y a una plancha y luego un bloque en dos pasos (en el original había que saltar).
- **Cantina de ESCorp con arrastrar y soltar,** como la pantalla de inventario: clic derecho, Mayús o Ctrl para la mitad o una, doble clic para juntar, y también con el mando.
- **Paleta creativa:** los tres cristales verdes de bonus y los demás bloques que dan cargas.
- **Rueda del ratón en bucle:** pasa de la última casilla al excavador y al revés (se quita en Opciones > Controles).
- **Versión de cada partida:** la lista de partidas dice con qué versión del juego se creó y se guardó cada una.
- **Generador de planetas nuevo:** sigue los pasos del original, pero cada paso y cada estructura tienen su propio azar, así que lo que se añada más adelante (anomalías nuevas) solo cambiará el planeta en su sitio, y cada planeta recuerda la versión con la que lo visitaste. Los planetas ya no son idénticos a los de la versión Flash.
- **Partidas en archivos `.g55`:** un archivo por partida, con los bloques por su nombre. Los bloques de una versión más nueva ya no se pierden: salen como kubes misteriosos y se conservan. Las partidas ocupan mucho menos y se guardan y se leen más deprisa.
- **Carga más rápida:** el planeta se genera 2-3 veces más deprisa y en segundo plano, sin parones en la pantalla de carga.
- **Mapa de estrellas sin parones:** al despegar, el juego se quedaba parado unos 9 s; ahora la pantalla de carga sigue respondiendo.

#### Arreglos (selección)
- Con una Intel HD 4600 en Linux, las cascadas, las gemas y el vidrio ya se ven, y el menú principal también.
- Un clic fuera de una ventana ya no llega al menú de debajo (detrás de Renombrar, un clic en otra partida la abría).
- Una pila tirada de bloques de carga se puede volver a recoger.
- Las variantes de puerta y de plano de un kube del editor ya no salen en la paleta creativa.
- El agua ácida vista de refilón ya no se cubre de rayas finas.

Todo está en el [CHANGELOG](../CHANGELOG.md), y los errores conocidos en `ERRORES.md`. Gracias también al jugador que probó en su Intel HD 4600 los arreglos de las cascadas invisibles.

### Tus partidas guardadas
Las partidas de la v0.8.1 se abren, pero **cambian**: sus planetas se generan ahora con el generador nuevo. Lo que construiste sigue ahí, pero el terreno de alrededor puede haber cambiado (agujeros, bloques que flotan o quedan enterrados). La lista las marca como "Partida antigua" y avisa cada vez que se abren. Al jugarlas se convierten al formato nuevo (`.g55`) y el archivo de antes queda en `saves/backups`; las versiones anteriores no leen el formato nuevo. **El formato de las partidas todavía puede cambiar entre versiones.**

---

## Galaxy 55 (offline) v0.9 — what's new

Version 0.9 of the **unofficial** native port of Galaxy 55 (Motion Twin, 2012) is out. No Flash, no browser and no server.

**How to play (Windows):** unzip the whole folder and double-click `jugar.bat`. If it doesn't open (PCs without OpenGL 3.2 or virtual machines), use `jugar_dx.bat`, the DirectX build. Nothing to install. Saves go to `%APPDATA%\Galaxy55\`.
**Linux and macOS:** separate zip; it needs HashLink 1.16 installed (see its `LEEME.txt`).

Everything new is by **Cornor923** (thank you!, PRs 126-148). Five big new features that were not in the original game: the ship storage, the equipment left on the ground when you die, the "Contact ESCorp" menu, paintings and your kube editor kubes in creative games. Under the hood, the planet generator and the save format change too: read "Your old saves" before you open an old game.

### The five big new features

#### The ship storage
New "Storage" button on the on-board computer, after "Modify the ship": 4 block slots, like an ESCorp Canteen, and the charges apart, without slots (yellow up to 24, blue 12, pink 5 and bonus without limit). Drag and drop works as in the inventory screen. In the mothership, the computer of your parked ship opens it too. There is one per game, and it stays when you rebuild the ship in the hangar.

#### When you die, your equipment stays on the ground
When you die or go back to the ship with Shift+K, what you carry (blocks, gems and charges; not credits) falls in a small ESCorp Canteen where you were. It never expires: you can go back for it. Nothing is left in creative, in the tutorial, in the hangar or in the mothership.
It is an option of each game, on unless changed. In New game, the new "Customize" button holds the seed and the "Drop equipment" box; in Continue, "Rename" becomes "Edit" and changes it later.

#### Contact ESCorp
The on-board computer groups "Trade", "ESCorp contracts" and "ESCorp upgrades" in a new sub-menu, "Contact ESCorp". Upgrades, paid with bonus charges, will come later: for now the screen shows your bonus charges and that there are none. The special contract now comes first in the contracts panel and, in the tutorial, the button to press is marked in green.

#### Paintings
The 16 paintings of CroqueMotel (Motion Twin) are in the creative palette. They hang on the wall you aim at, turned towards you (not on a floor or a ceiling), and fall if you remove the wall. The kube editor has a new shape, "Painting (on a wall)", to make your own.

#### Your kubes in your world
In a creative game, the kubes you draw in the kube editor (or the `.kube` files you drop in its folder) come last in the palette, with a cyan corner, and are placed like any block, doors and planes included. Up to 128 per game. A retouched kube shows its new look the next time you load the game.

### Also in v0.9
- **Walking up plates:** you climb a plate without jumping, and a plate then a block in two steps (in the original you had to jump).
- **ESCorp Canteen with drag and drop,** like the inventory screen: right click, Shift or Ctrl for half or one, double click to gather, and with the gamepad too.
- **Creative palette:** the three green bonus crystals and the other blocks that give charges.
- **Mouse wheel wraps around:** it goes from the last slot to the digger and back (turned off in Options > Controls).
- **Version of each save:** the saves list says which game version created and last saved each one.
- **New planet generator:** it follows the original's steps, but each step and structure has its own randomness, so what is added later (new anomalies) will only change the planet where it goes, and each planet remembers the version you visited it with. Planets are no longer identical to the Flash version's.
- **Saves as `.g55` files:** one file per game, with blocks stored by name. Blocks from a newer version are no longer lost: they show as mystery kubes and are kept. Saves are much smaller and faster to write and read.
- **Faster loading:** the planet is generated 2-3 times faster and in the background, with no stops on the loading screen.
- **Star map without the freeze:** taking off stopped the game for about 9 s; now the loading screen keeps responding.

#### Bug fixes (selection)
- With an Intel HD 4600 on Linux, waterfalls, gems and glass show up again, and so does the main menu.
- A click outside a dialog no longer reaches the menu below (behind Rename, a click on another save played it).
- A thrown stack of charge blocks can be picked up again.
- The door and plane variants of a kube editor kube no longer show up in the creative palette.
- Acid water seen at a grazing angle is no longer covered in thin streaks.

Everything is in the [CHANGELOG](../CHANGELOG.en.md), and the known bugs in `BUGS.md`. Thanks also to the player who tested the invisible waterfall fixes on their Intel HD 4600.

### Your old saves
v0.8.1 saves open, but they **change**: their planets are now generated with the new generator. What you built is still there, but the terrain around it may have changed (holes, blocks floating or buried). The list marks them as "Old save" and warns every time they are opened. When you play them they are converted to the new format (`.g55`) and the old file stays in `saves/backups`; older versions can't read the new format. **The save format may still change between versions.**

---

## Galaxy 55 (offline) v0.9 — les nouveautés

La version 0.9 du portage natif **non officiel** de Galaxy 55 (Motion Twin, 2012) est sortie. Sans Flash, sans navigateur et sans serveur.

**Comment jouer (Windows) :** décompresse tout le dossier et double-clique sur `jugar.bat`. S'il ne s'ouvre pas (PC sans OpenGL 3.2 ou machines virtuelles), utilise `jugar_dx.bat`, la version DirectX. Rien à installer. Les parties sont enregistrées dans `%APPDATA%\Galaxy55\`.
**Linux et macOS :** zip séparé ; il faut HashLink 1.16 installé (voir son `LEEME.txt`).

Tout ce qui est nouveau est de **Cornor923** (merci !, PR 126-148). Cinq grandes nouveautés qui n'étaient pas dans le jeu original : le stockage du vaisseau, l'équipement qui reste au sol à la mort, le menu « Contacter l'ESCorp », les tableaux et tes kubes de l'éditeur dans les parties créatives. En dessous, le générateur de planètes et le format des parties changent aussi : lis « Tes anciennes parties » avant d'ouvrir une ancienne partie.

### Les cinq grandes nouveautés

#### Le stockage du vaisseau
Nouveau bouton « Stockage » sur l'ordinateur de bord, après « Modifier le vaisseau » : 4 cases de blocs, comme un Conteneur ESCorp, et les charges à part, sans cases (jaunes jusqu'à 24, bleues 12, roses 5 et bonus sans limite). Le glisser-déposer marche comme dans l'écran d'inventaire. Dans le vaisseau-mère, l'ordinateur de ton vaisseau garé l'ouvre aussi. Il y en a un par partie, et il reste quand tu refais le vaisseau dans le hangar.

#### À la mort, l'équipement reste au sol
À la mort ou en revenant au vaisseau avec Maj+K, ce que tu portes (blocs, gemmes et charges ; pas les crédits) tombe dans un petit Conteneur ESCorp, là où tu étais. Il n'expire pas : tu peux revenir le chercher. Rien n'est laissé en créatif, dans le tutoriel, dans le hangar ni dans le vaisseau-mère.
C'est une option de chaque partie, activée sauf changement. Dans Nouvelle partie, le nouveau bouton « Personnaliser » contient la graine (« Seed ») et la case « Dépôt de l'équipement à la mort » ; dans Continuer, « Renommer » devient « Modifier » et la change ensuite.

#### Contacter l'ESCorp
L'ordinateur de bord regroupe « Commercer », « Contrats ESCorp » et « Améliorations ESCorp » dans un nouveau sous-menu, « Contacter l'ESCorp ». Les améliorations, payées en charges bonus, viendront plus tard : pour l'instant l'écran montre tes charges bonus et qu'il n'y en a aucune. Le contrat spécial arrive maintenant en premier dans le panneau des contrats et, dans le tutoriel, le bouton à choisir est marqué en vert.

#### Tableaux
Les 16 tableaux de CroqueMotel (Motion Twin) sont dans la palette créative. Ils s'accrochent au mur visé, tournés vers toi (ni au sol ni au plafond), et tombent si on enlève le mur. L'éditeur de Kubes a une nouvelle forme, « Tableau (au mur) », pour faire les tiens.

#### Tes kubes dans ton monde
Dans une partie créative, les kubes que tu dessines dans l'éditeur de Kubes (ou les `.kube` déposés dans son dossier) arrivent à la fin de la palette, avec un coin cyan, et se posent comme n'importe quel bloc, portes et plans compris. Jusqu'à 128 par partie. Un kube retouché a son nouvel aspect au prochain chargement de la partie.

### Aussi dans la v0.9
- **Monter sur les dalles en marchant :** on monte sur une dalle sans sauter, et sur une dalle puis un bloc en deux pas (dans l'original, il fallait sauter).
- **Conteneur ESCorp en glisser-déposer,** comme l'écran d'inventaire : clic droit, Maj ou Ctrl pour la moitié ou un, double clic pour rassembler, et aussi à la manette.
- **Palette créative :** les trois cristaux verts de bonus et les autres blocs qui donnent des charges.
- **Molette en boucle :** elle passe de la dernière case au laser de minage et inversement (se désactive dans Options > Contrôles).
- **Version de chaque partie :** la liste des parties indique avec quelle version du jeu chacune a été créée et enregistrée.
- **Nouveau générateur de planètes :** il suit les étapes de l'original, mais chaque étape et chaque structure a son propre hasard, donc ce qui sera ajouté plus tard (nouvelles anomalies) ne changera la planète qu'à sa place, et chaque planète retient la version de ta visite. Les planètes ne sont plus identiques à celles de la version Flash.
- **Parties en fichiers `.g55` :** un fichier par partie, avec les blocs gardés par leur nom. Les blocs d'une version plus récente ne sont plus perdus : ils s'affichent en kubes mystère et sont conservés. Les parties prennent bien moins de place et s'enregistrent et se lisent plus vite.
- **Chargement plus rapide :** la planète est générée 2 à 3 fois plus vite et en arrière-plan, sans arrêts sur l'écran de chargement.
- **Carte des étoiles sans blocage :** au décollage, le jeu restait figé environ 9 s ; maintenant l'écran de chargement répond toujours.

#### Corrections (sélection)
- Avec une Intel HD 4600 sous Linux, les cascades, les gemmes et le verre se voient de nouveau, et le menu principal aussi.
- Un clic hors d'une fenêtre n'atteint plus le menu dessous (derrière Renommer, un clic sur une autre partie la lançait).
- Une pile jetée de blocs de charge se ramasse de nouveau.
- Les variantes de porte et de plan d'un kube de l'éditeur n'apparaissent plus dans la palette créative.
- L'eau acide vue en rasant n'est plus couverte de fines rayures.

Tout est dans le [CHANGELOG](../CHANGELOG.fr.md), et les bugs connus dans `BUGS.fr.md`. Merci aussi au joueur qui a testé sur son Intel HD 4600 les corrections des cascades invisibles.

### Tes anciennes parties
Les parties de la v0.8.1 s'ouvrent, mais elles **changent** : leurs planètes sont maintenant générées avec le nouveau générateur. Ce que tu as construit est toujours là, mais le terrain autour peut avoir changé (trous, blocs qui flottent ou se retrouvent enterrés). La liste les marque « Ancienne partie » et prévient à chaque ouverture. Quand tu les joues, elles sont converties au nouveau format (`.g55`) et l'ancien fichier reste dans `saves/backups` ; les versions plus anciennes ne lisent pas le nouveau format. **Le format des parties peut encore changer d'une version à l'autre.**

---

## Galaxy 55 (offline) v0.8.1

Todo lo nuevo desde la v0.8, obra de **Cornor923** (PR 116-125). Las partidas de la v0.8 siguen valiendo.

- **Pantalla de inventario:** en aventura, I (o R3) abre un panel con las 10 casillas de la barra: arrastrar, partir montones y tirar fuera del panel, como en Minecraft. En creativo, I sigue abriendo la paleta.
- **De creativo a supervivencia:** una partida creada en creativo puede pasar a supervivencia y volver (botón en la paleta y en la pantalla de inventario). El modo se guarda con la partida.
- **Buscar en la paleta:** un campo en la paleta creativa filtra bloques y kubes por su nombre.
- **Contrato especial de la ESCorp:** una vez por partida, 16 de Tierra roja dan un Contenedor ESCorp, sin límite de tiempo. Nuevo paso "Contratos" en el tutorial.
- **Teclas a tu gusto:** Opciones > Controles > Personalizar teclas. 28 acciones, hasta 4 teclas o botones del ratón cada una; avisa si una tecla ya está usada y hay un botón para volver a las de siempre. Las ayudas y el tutorial muestran las teclas elegidas.
- **Marco de selección:** nueva opción en Opciones > Interfaz para quitar el marco naranja del bloque apuntado.
- **Más de 255 bloques distintos por mundo:** ya no hay bloques que no se puedan poner por falta de sitio. El mundo ocupa el doble de memoria.

**Arreglos gráficos**
- El visor del casco sigue el tamaño de la ventana al cambiarla con el ordenador de a bordo, la pausa o un panel abiertos (antes quedaban bandas oscuras o los bordes fuera de la pantalla).
- El kube invisible se ve translúcido tirado en el suelo y en la mano (antes no se veía).
- El Agua ácida sale una sola vez en la paleta creativa.

Detalles en el `CHANGELOG.md`.

---

## Galaxy 55 (offline) v0.8.1

Everything new since v0.8, by **Cornor923** (PRs 116-125). v0.8 saves still work.

- **Inventory screen:** in adventure, I (or R3) opens a panel with the 10 slots of the bar: drag, split stacks and throw outside the panel, Minecraft style. In creative, I still opens the palette.
- **Creative to survival:** a game created in creative can switch to survival and back (button in the palette and in the inventory screen). The mode is saved with the game.
- **Palette search:** a field in the creative palette filters blocks and kubes by name.
- **ESCorp special contract:** once per game, 16 Red Earth give an ESCorp Container, no time limit. New "Contracts" step in the tutorial.
- **Custom key bindings:** Options > Controls > Customize keys. 28 actions, up to 4 keys or mouse buttons each; a key already in use is flagged and a button restores the defaults. The help and the tutorial show the chosen keys.
- **Selection frame:** new option in Options > Interface to hide the orange frame on the targeted block.
- **More than 255 different blocks per world:** no more blocks refused for lack of room. The world uses twice the memory.

**Graphics fixes**
- The helmet visor follows window resizes with the on-board computer, the pause menu or a panel open (there were dark bands or its edges went off-screen).
- The invisible kube shows translucent when dropped on the ground and in the hand (it could not be seen).
- Acid Water shows only once in the creative palette.

Details in `CHANGELOG.en.md`.

---

## Galaxy 55 (offline) v0.8.1

Tout ce qui est nouveau depuis la v0.8, par **Cornor923** (PR 116-125). Les parties de la v0.8 restent valables.

- **Écran d'inventaire :** en aventure, I (ou R3) ouvre un panneau avec les 10 cases de la barre : glisser, partager les piles et jeter hors du panneau, comme dans Minecraft. En créatif, I ouvre toujours la palette.
- **Du créatif à la survie :** une partie créée en créatif peut passer en survie et revenir (bouton dans la palette et dans l'écran d'inventaire). Le mode est enregistré avec la partie.
- **Recherche dans la palette :** un champ dans la palette créative filtre blocs et kubes par leur nom.
- **Contrat spécial ESCorp :** une fois par partie, 16 Terre rouge donnent un Conteneur ESCorp, sans limite de temps. Nouvelle étape « Contrats » dans le tutoriel.
- **Touches au choix :** Options > Contrôles > Personnaliser les touches. 28 actions, jusqu'à 4 touches ou boutons de souris chacune ; une touche déjà prise est signalée et un bouton remet celles d'origine. L'aide et le tutoriel montrent les touches choisies.
- **Cadre de sélection :** nouvelle option dans Options > Interface pour cacher le cadre orange du bloc visé.
- **Plus de 255 blocs différents par monde :** plus de blocs refusés faute de place. Le monde prend deux fois plus de mémoire.

**Corrections graphiques**
- La visière du casque suit le redimensionnement de la fenêtre avec l'ordinateur de bord, la pause ou un panneau ouvert (il restait des bandes sombres ou ses bords sortaient de l'écran).
- Le kube invisible se voit translucide posé au sol et en main (avant il ne se voyait pas).
- L'Eau acide n'apparaît qu'une fois dans la palette créative.

Détails dans `CHANGELOG.fr.md`.

---

## Galaxy 55 (offline) v0.8 — novedades

La versión 0.8 del port nativo **no oficial** de Galaxy 55 (Motion Twin, 2012) ya está aquí. Sin Flash, sin navegador y sin servidor.

**Cómo jugar (Windows):** descomprime la carpeta entera y haz doble clic en `jugar.bat`. Si no abre (equipos sin OpenGL 3.2 o máquinas virtuales), usa `jugar_dx.bat`, la versión DirectX. No hay que instalar nada. Las partidas se guardan en `%APPDATA%\Galaxy55\`.
**Linux y macOS:** zip aparte; necesita HashLink 1.16 instalado (ver su `LEEME.txt`).

Casi todo es obra de **Cornor923** (¡gracias!). Cuatro grandes novedades que no estaban en el juego original: los kubes de Kube, la anomalía invisible con sus gemas, la tienda de la nave nodriza y los contratos por partes.

### Las cuatro grandes novedades

#### Los kubes de Kube
Los 77 bloques de Kube, otro juego de Motion Twin (2010), llegan como bloques enteros, con sus texturas, su luz y su transparencia. En creativo están todos en la paleta, y cada uno tiene su ficha en la Base de datos ESCorp. El agua y la lava de Kube corren por sus caras como en Kube, pero no fluyen ni hacen daño.

Cada kube está también como archivo `.kube` en el repositorio (`port/kubes`), para abrirlo y retocarlo en el editor de kubes.

#### La anomalía invisible
En más o menos 1 de cada 8 planetas (no en los cometas), un cubo de 4x4x4 flota a 10-20 bloques del suelo. No se ve: sus kubes Invisibles muestran el cielo de detrás, así que desde arriba parece un trozo de cielo en medio del paisaje. Pasar por debajo o al lado lo identifica en la Base de datos ESCorp.
- A través del vidrio blindado oscuro o del hielo negro se ve como bajo una luz negra, con los bordes en azul.
- Dentro hay 8 Cofres de Kube. En el sintetizador, cada cofre da al azar una gema: Rubí, Zafiro, Esmeralda o Amatista.
- 8 gemas iguales dan una Sombra, y 8 Sombras un Teletransporte (que de momento no hace nada).
- Un vidrio blindado con una gema encima da un vidrio blindado de color: rojo, azul, verde o rosa. Son bloques de la nave, más claros que el vidrio blindado oscuro, y el robot comerciante los compra a 100.

#### La tienda de la nave nodriza
El puesto del robot comerciante se muda al centro del hangar, entre las dos filas de bahías: un puesto abierto con su mostrador, hecho con bloques de la nave. Ya no hay ordenador: el robot se gira hacia ti y, con un clic, hablas con él: 1. comerciar, 2. charlar (consejos, rumores y chistes de robot) y 3. adiós. Se elige con las teclas de número, el ratón, las flechas o el mando.

Además, una partida guardada dentro de la nave nodriza se carga dentro, donde estabas (antes se abría en el mapa de estrellas).

#### Contratos por partes
Ya no hace falta llevar todos los bloques de un contrato de la ESCorp: "Dar" entrega los que tengas y el contrato queda en curso arriba del panel. Ya no caduca con el tablero, lo terminas cuando quieras y cobras la recompensa entera con el último bloque. Cada contrato en curso ocupa una línea del tablero (con 3, está lleno). "Abandonar" pide confirmación: los bloques dados se pierden y no se cobra nada.

### También en la v0.8

#### Sintetizador
- Las recetas dan más: la madera da 4 tablas (antes 2), 4 tablas en cuadrado dan 4 planchas de madera (antes 1) y muchas recetas de construcción dan 2 en vez de 1.
- Recetas nuevas: pilar de piedra, zócalos de volcanita, de roca ácida y de escarcha, y la cantina de ESCorp (8 de hierro), que antes no había manera de conseguir.
- El tronco de lunimosa se hace con 2 lunimosas muertas (antes 2 rocas lunares), que siempre se sueltan: la receta ya sirve en aventura.

#### Robot comerciante
- Lo que se fabrica con lo que él vende ya no se revende por más de lo que cuestan sus ingredientes.
- Las cargas de citronox cuestan 20 (antes 120), el motor espacial 1000 y la cantina de ESCorp 400.
- Ya no vende muros, zócalos, pilares, piezas de la nave (queda el aluminio para fabricarlas), minerales, cristales ni lo que dan las anomalías, pero los sigue comprando.

#### Base de datos ESCorp y editor de kubes
- El Kubindex sigue un orden más cercano al original: planeta por planeta, luego cometas y anomalías, los fabricados en el orden de sus recetas, los especiales y los kubes. Las recetas van por material.
- Editor de kubes: un botón junto a "Girar solo" muestra el kube en un bloque de 2x2x2 o de 3x3x3 para ver cómo se juntan sus caras. La rueda del ratón acerca hacia el punto bajo el cursor (de 50 % a 600 %), la vista gira hacia donde va el ratón, y el vidrio y el hielo se ven como en el mundo.

#### Arreglos (selección)
- Los iconos de los bloques se ven lisos en toda la interfaz, y los translúcidos (vidrio, hielo, agua...) ya no se ven huecos ni oscuros.
- El fundido de pantalla de la bomba exótica ya no parpadea (antes, hasta 15-17 destellos por segundo), por las personas con epilepsia. El daño no cambia.
- Una partida guardada por una versión más nueva, con bloques que esta no conoce, ya no cierra el juego: pregunta antes, guarda una copia en `saves/backups` y quita esos bloques.
- La versión DirectX ya no se cierra al abrir la Base de datos ESCorp con algo nuevo dentro.
- Al llegar a un planeta, la escena ya no debería parpadear unos segundos en algunos PC (por confirmar). Si ves un fallo de dibujo, adjunta al avisarnos el archivo `gpu.txt` de `%APPDATA%\Galaxy55\`.
- En francés, la cantina se llama "Conteneur ESCorp" (antes "EScorp").

Todo en el [CHANGELOG](../CHANGELOG.md) y la lista de errores conocidos en `ERRORES.md`.

### Tus partidas guardadas
Las de la v0.7 siguen funcionando: los planetas sin la anomalía invisible no cambian. Pero una partida que use los bloques nuevos (kubes de Kube, gemas, vidrios de color, pilares, zócalos) puede cerrar la v0.7 al cargarla: no vuelvas a una versión anterior con ella. Un mundo guarda como mucho 255 bloques distintos: si uno nuevo ya no cabe, no se pone y no se gasta. **El formato de las partidas todavía puede cambiar entre versiones.**

---

## Galaxy 55 (offline) v0.8 — what's new

Version 0.8 of the **unofficial** native port of Galaxy 55 (Motion Twin, 2012) is out. No Flash, no browser and no server.

**How to play (Windows):** unzip the whole folder and double-click `jugar.bat`. If it doesn't open (PCs without OpenGL 3.2 or virtual machines), use `jugar_dx.bat`, the DirectX build. Nothing to install. Saves go to `%APPDATA%\Galaxy55\`.
**Linux and macOS:** separate zip; it needs HashLink 1.16 installed (see its `LEEME.txt`).

Almost all of it is by **Cornor923** (thank you!). Four big new features that were not in the original game: the kubes of Kube, the invisible anomaly with its gems, the mothership shop and contracts in parts.

### The four big new features

#### The kubes of Kube
The 77 blocks of Kube, another Motion Twin game (2010), arrive as full blocks, with their textures, light and transparency. In creative they are all in the palette, and each one has its card in the ESCorp database. Kube Water and Kube Lava run down their sides as in Kube, but they do not flow nor hurt.

Each kube is also in the repository as a `.kube` file (`port/kubes`), to open and retouch it in the Kube editor.

#### The invisible anomaly
On about 1 planet in 8 (not on comets), a 4x4x4 cube floats 10 to 20 blocks above the ground. You can't see it: its Invisible kubes show the sky behind them, so from above it looks like a piece of sky in the middle of the landscape. Passing below or beside it identifies it in the ESCorp database.
- Through Tinted Toughened Glass or Black Ice it shows as under a black light, with blue edges.
- Inside are 8 Kube Chests. In the synthesizer, each chest gives a random gem: Ruby, Sapphire, Emerald or Amethyst.
- 8 matching gems make a Shade, and 8 Shades a Teleport (which does nothing yet).
- Toughened Glass with a gem on top makes coloured Toughened Glass: red, blue, green or pink. They are ship blocks, lighter than the Tinted Toughened Glass, and the merchant robot buys them at 100.

#### The mothership shop
The merchant robot's stall moves to the middle of the hangar, between the two rows of bays: an open stall with its counter, built from ship blocks. No more computer: the robot turns to face you and, with a click, you talk to it: 1. trade, 2. chat (tips, rumours and robot jokes) and 3. goodbye. Choose with the number keys, the mouse, the arrows or the gamepad.

Also, a game saved inside the mothership loads inside, where you were (it used to open on the star map).

#### Contracts in parts
You no longer need all the blocks of an ESCorp contract: "Give" hands over what you carry and the contract stays in progress at the top of the panel. It no longer expires with the board, you finish it whenever you want and the full reward is paid with the last block. Each contract in progress takes one line of the board (with 3, it is full). "Abandon" asks for confirmation: the blocks given are lost and nothing is paid.

### Also in v0.8

#### Synthesizer
- Recipes give more: wood makes 4 planks (2 before), 4 planks in a square make 4 wood platings (1 before) and many building recipes make 2 instead of 1.
- New recipes: Rock Column, HardRoq, Soft Rock and Frost Tiles, and the ESCorp Canteen (8 iron), which there was no way to get before.
- The Lumen Rock Trunk is made from 2 Dead Lumen Rocks (2 moon rock before), which always drop: the recipe now works in adventure.

#### Merchant robot
- What is crafted from what it sells no longer resells for more than its ingredients cost.
- Citronox charges cost 20 (120 before), the space engine 1000 and the ESCorp Canteen 400.
- It no longer sells walls, tiles, columns, ship parts (aluminium stays on sale to craft them), ores, crystals or what anomalies give, but it still buys them.

#### ESCorp database and Kube editor
- The Kubindex follows an order closer to the original one: planet by planet, then comets and anomalies, crafted blocks in the order of their recipes, special blocks and the kubes. Recipes go by material.
- Kube editor: a button next to "Auto-rotate" shows the kube as a 2x2x2 or 3x3x3 block, to see how its faces join. The mouse wheel zooms toward the point under the cursor (50% to 600%), the view turns the way the mouse goes, and glass and ice look as in the world.

#### Bug fixes (selection)
- Block icons are smooth in the whole interface, and translucent ones (glass, ice, water...) no longer look hollow or dark.
- The ancient bomb screen fade no longer flickers (up to 15-17 flashes per second before), for people with epilepsy. Damage is unchanged.
- A game saved by a newer version, with blocks this one does not know, no longer closes the game: it asks first, keeps a copy in `saves/backups` and removes those blocks.
- The DirectX build no longer closes when the ESCorp database opens with something new in it.
- On arrival on a planet, the scene should no longer flicker for a few seconds on some PCs (to be confirmed). If you see a drawing bug, attach the `gpu.txt` file from `%APPDATA%\Galaxy55\` when you report it.
- In French, the canteen is named "Conteneur ESCorp" ("EScorp" before).

Everything is in the [CHANGELOG](../CHANGELOG.en.md), and the known bugs in `BUGS.md`.

### Your old saves
v0.7 saves carry on: planets without the invisible anomaly are unchanged. But a game that uses the new blocks (Kube kubes, gems, coloured glass, columns, tiles) may close v0.7 when it loads: do not go back to an older version with it. A world holds at most 255 different blocks: if a new one no longer fits, it is not placed and not used up. **The save format may still change between versions.**

---

## Galaxy 55 (offline) v0.8 — les nouveautés

La version 0.8 du portage natif **non officiel** de Galaxy 55 (Motion Twin, 2012) est là. Sans Flash, sans navigateur et sans serveur.

**Comment jouer (Windows) :** décompresse tout le dossier et double-clique sur `jugar.bat`. S'il ne s'ouvre pas (PC sans OpenGL 3.2 ou machines virtuelles), utilise `jugar_dx.bat`, la version DirectX. Rien à installer. Les parties sont enregistrées dans `%APPDATA%\Galaxy55\`.
**Linux et macOS :** zip séparé ; il faut HashLink 1.16 installé (voir son `LEEME.txt`).

Presque tout est l'œuvre de **Cornor923** (merci !). Quatre grandes nouveautés qui n'existaient pas dans le jeu original : les kubes de Kube, l'anomalie invisible et ses gemmes, la boutique du vaisseau-mère et les contrats en plusieurs fois.

### Les quatre grandes nouveautés

#### Les kubes de Kube
Les 77 blocs de Kube, un autre jeu de Motion Twin (2010), arrivent en blocs pleins, avec leurs textures, leur lumière et leur transparence. En créatif, ils sont tous dans la palette, et chacun a sa fiche dans la base de données ESCorp. L'Eau de Kube et la Lave de Kube coulent sur leurs faces comme dans Kube, mais ne s'écoulent pas et ne blessent pas.

Chaque kube est aussi dans le dépôt en fichier `.kube` (`port/kubes`), pour l'ouvrir et le retoucher dans l'éditeur de Kubes.

#### L'anomalie invisible
Sur environ 1 planète sur 8 (pas sur les comètes), un cube de 4x4x4 flotte à 10-20 blocs du sol. On ne le voit pas : ses kubes Invisibles montrent le ciel derrière eux, alors vu d'en haut il a l'air d'un morceau de ciel au milieu du paysage. Passer dessous ou à côté le repère dans la base de données ESCorp.
- À travers une vitre blindée teintée ou de la glace noire, il apparaît comme sous une lumière noire, avec des arêtes bleues.
- Dedans, 8 Coffres de Kube. Dans le synthétiseur, chaque coffre donne une gemme au hasard : Rubis, Saphir, Émeraude ou Améthyste.
- 8 gemmes identiques font une Ombre, et 8 Ombres un Téléport (qui ne fait rien pour l'instant).
- Une vitre blindée avec une gemme dessus donne une vitre blindée teintée de couleur : rouge, bleue, verte ou rose. Ce sont des blocs du vaisseau, plus clairs que la vitre blindée teintée, et le robot marchand les achète 100.

#### La boutique du vaisseau-mère
L'étal du robot marchand déménage au milieu du hangar, entre les deux rangées de baies : un étal ouvert avec son comptoir, fait de blocs du vaisseau. Plus d'ordinateur : le robot se tourne vers toi et, d'un clic, tu lui parles : 1. commercer, 2. discuter (conseils, rumeurs et blagues de robot) et 3. au revoir. On choisit avec les touches numériques, la souris, les flèches ou la manette.

Et une partie enregistrée dans le vaisseau-mère se charge dedans, là où tu étais (avant, elle s'ouvrait sur la carte stellaire).

#### Contrats en plusieurs fois
Plus besoin d'avoir tous les blocs d'un contrat ESCorp : « Donner » remet ceux que tu portes et le contrat reste en cours en haut du panneau. Il n'expire plus avec le tableau, tu le termines quand tu veux et la récompense entière est payée avec le dernier bloc. Chaque contrat en cours prend une ligne du tableau (avec 3, il est plein). « Abandonner » demande confirmation : les blocs donnés sont perdus et rien n'est payé.

### Aussi dans la v0.8

#### Synthétiseur
- Les recettes donnent plus : le bois donne 4 planches (2 avant), 4 planches en carré donnent 4 dalles en bois (1 avant) et beaucoup de recettes de construction donnent 2 au lieu de 1.
- Nouvelles recettes : Colonne en rosh, Carrelages en rouge'rosh, de roche douce et du frimas, et le Conteneur ESCorp (8 fers), qu'on ne pouvait pas obtenir avant.
- Le tronc de lunimeuse se fait avec 2 lunimeuses mortes (avant 2 roches lunaires), qui tombent toujours : la recette marche maintenant en aventure.

#### Robot marchand
- Ce qui se fabrique avec ce qu'il vend ne se revend plus au-dessus du prix de ses ingrédients.
- Les charges de citronox coûtent 20 (120 avant), le moteur spatial 1000 et le Conteneur ESCorp 400.
- Il ne vend plus les murs, carrelages, colonnes, pièces du vaisseau (l'aluminium reste en vente pour les fabriquer), minerais, cristaux ni ce que donnent les anomalies, mais il les achète toujours.

#### Base de données ESCorp et éditeur de Kubes
- Le Kubindex suit un ordre plus proche de l'original : planète par planète, puis comètes et anomalies, les blocs fabriqués dans l'ordre de leurs recettes, les blocs spéciaux et les kubes. Les recettes vont par matériau.
- Éditeur de Kubes : un bouton à côté de « Rotation auto » montre le kube en bloc de 2x2x2 ou de 3x3x3, pour voir comment ses faces se raccordent. La molette zoome vers le point sous le curseur (de 50 % à 600 %), la vue tourne dans le sens de la souris, et le verre et la glace s'affichent comme dans le monde.

#### Corrections (sélection)
- Les icônes des blocs sont lisses dans toute l'interface, et les translucides (verre, glace, eau...) ne paraissent plus creux ni sombres.
- Le fondu d'écran de la bombe antique ne clignote plus (jusqu'à 15-17 flashs par seconde avant), pour les personnes épileptiques. Les dégâts ne changent pas.
- Une partie enregistrée par une version plus récente, avec des blocs que celle-ci ne connaît pas, ne ferme plus le jeu : il demande d'abord, garde une copie dans `saves/backups` et retire ces blocs.
- La version DirectX ne se ferme plus à l'ouverture de la base de données ESCorp quand elle contient une nouveauté.
- En arrivant sur une planète, la scène ne devrait plus clignoter quelques secondes sur certains PC (à confirmer). Si tu vois un bug d'affichage, joins à ton signalement le fichier `gpu.txt` de `%APPDATA%\Galaxy55\`.
- Le conteneur s'appelle bien « Conteneur ESCorp » (avant « EScorp »).

Tout est dans le [CHANGELOG](../CHANGELOG.fr.md), et les bugs connus dans `BUGS.fr.md`.

### Tes anciennes parties
Celles de la v0.7 continuent : les planètes sans l'anomalie invisible ne changent pas. Mais une partie qui utilise les nouveaux blocs (kubes de Kube, gemmes, vitres de couleur, colonnes, carrelages) peut fermer la v0.7 au chargement : ne reviens pas à une version précédente avec elle. Un monde garde au plus 255 blocs différents : si un nouveau ne tient plus, il n'est pas posé ni consommé. **Le format des sauvegardes peut encore changer d'une version à l'autre.**

---

### Licencia / License / Licence
Código y datos de Galaxy 55 © Motion Twin, **CC BY-NC-SA 4.0**. Este port es una obra derivada bajo la misma licencia: uso no comercial y con crédito. Ver `LICENSE` y `NOTICE`. El icono de "nuevo" de la base de datos es de Mush, las texturas de los kubes de Kube son de Kube y los cuadros son de CroqueMotel (Motion Twin, CC BY-NC-SA 4.0).
