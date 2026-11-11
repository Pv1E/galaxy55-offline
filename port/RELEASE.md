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
Código y datos de Galaxy 55 © Motion Twin, **CC BY-NC-SA 4.0**. Este port es una obra derivada bajo la misma licencia: uso no comercial y con crédito. Ver `LICENSE` y `NOTICE`. El icono de "nuevo" de la base de datos es de Mush, y las texturas de los kubes de Kube son de Kube (Motion Twin, CC BY-NC-SA 4.0).
