## Galaxy 55 (offline) v0.7 — novedades

La versión 0.7 del port nativo **no oficial** de Galaxy 55 (Motion Twin, 2012) ya está aquí. Sin Flash, sin navegador y sin servidor.

**Cómo jugar (Windows):** descomprime la carpeta entera y haz doble clic en `jugar.bat`. Si no abre (equipos sin OpenGL 3.2 o máquinas virtuales), usa `jugar_dx.bat`, la versión DirectX. No hay que instalar nada. Las partidas se guardan en `%APPDATA%\Galaxy55\`.
**Linux y macOS:** zip aparte; necesita HashLink 1.16 instalado (ver su `LEEME.txt`).

Casi todo es obra de **Cornor923** (¡gracias!). Cuatro grandes novedades que no estaban en el juego original: la base de datos ESCorp, las licencias de exploración, los cometas y el editor de kubes.

### Las cuatro grandes novedades

#### Base de datos ESCorp y Kubindex
Un botón nuevo en el ordenador de a bordo, "Base de datos ESCorp", guarda todo lo que descubres. Tres pestañas:
- **Kubindex:** todos los kubes del juego, por categorías (Planetas, Anomalías, Cometas, Fabricados, Especiales, Cargas). Apunta a un kube con el láser para identificarlo y mételo en el inventario para recuperarlo. Su ficha dice dónde encontrarlo, cuántas veces lo pusiste, rompiste y fabricaste, las recetas que lo dan y las que lo usan.
- **Espacio:** los tipos de planeta y de cometa que has explorado y las anomalías que has cruzado.
- **Recetas:** cada receta se descubre al recuperar uno de sus kubes.

Un aviso arriba a la derecha anuncia cada descubrimiento, y las fichas nuevas quedan marcadas hasta que las miras.

#### Licencias de exploración
En aventura, escanear un planeta gasta una licencia de la ESCorp: 4 en total, 1 para tu planeta principal y 3 de exploración (sin límite en creativo).
- El primer planeta que escaneas pasa a ser el principal (con el tutorial, el del tutorial), y la nave solo se pilota sobre él, lo que te permite mover tu sitio de aterrizaje en ese planeta.
- En el ordenador de a bordo, "Licencias de exploración" las muestra y deja cambiar de planeta principal: gratis la primera vez, luego 1000 créditos, con 24 horas reales entre cambios.
- En el mapa, "Abandonar" libera la licencia de un planeta (nunca la del principal), pero también lo quita de tu partida para siempre.

#### Cometas
Mundos muy pequeños que pasan por los sistemas solares: cada 2 horas, cada sistema tiene 1 posibilidad entre 6 de tener uno. Lo especial: los cometas no necesitan licencia.
- El tiempo es corto: de 1:30 a 15:00 según la velocidad de tu nave, y solo corre mientras estás en el suelo.
- En cuanto despegas, el cometa desaparece.
- El cometa calcinado tiene roca de cráter, escombros calcinados, vetas de etherium con meteoritos de etherium y lava. Habrá más cometas en próximas versiones.

#### El editor de kubes
En el menú principal, debajo de Nueva partida. Pinta las caras de un bloque píxel a píxel (lápiz, goma, relleno, cuentagotas, espejo, Ctrl+Z) en una de las formas que el juego ya sabe dibujar: cubo, caja (losa, neón...), puerta, planta en cruz, hierba alta, panel, columna, tubo, jaula... Elige su aspecto (opaco, calado como las hojas, translúcido como el cristal), su luz y si se puede atravesar, y míralo girar en 3D.

Empieza desde un kube en blanco o desde cualquier kube del juego. Tus creaciones se guardan en "Mis kubes", como archivos `.kube` en `%APPDATA%\Galaxy55\kubes`: envíanoslas para proponer tus kubes.

### También en la v0.7

#### Arena movediza
Caer en arena movediza ahora es como aterrizar en el suelo: recibes el golpe al tocar la arena y luego la arena frena la caída. Antes, todo el daño de la caída llegaba de golpe, al final. El daño que se recibe dentro de la arena sigue como en el original.

#### Sin parones
Ya no hay parones al aparecer el menú principal, en las pantallas de carga, al llegar a un planeta ni al cargar la nave nodriza. Antes el juego se congelaba hasta casi un segundo, y unos 6 segundos la primera vez en la nave nodriza.

#### Cambios de juego
- El ordenador de a bordo, la tienda, los contratos y las licencias ya no paran el juego: sigues curándote en la nave.
- En la zona del sintetizador y en el hangar, un bloque roto siempre se suelta. Un bloque soltado y enterrado bajo otros sale por un lado.
- El ordenador del sintetizador también funciona con un bloque en la mano y con el clic derecho.
- Dos clics rápidos ahora ponen los dos bloques.
- Tutorial: el sintetizador solo fabrica aluminio y blindaje (ya no te quedas atascado), una flecha verde señala el planeta del aterrizaje de emergencia y las felicitaciones se van al despegar.

#### Arreglos (selección)
- El volumen de Opciones por fin se aplica a los sonidos.
- Una cascada detrás de un cristal se ve, y la cámara ya no se mete en el bloque de arriba al subir por una cascada.
- Se pueden poner bloques sobre la hierba alta, y los bloques soltados ya no tiemblan en el suelo.
- La nieve solo cubre el planeta nevado, a cielo abierto.
- La niebla ya no cambia al girar la cámara.
- La nave del robot comerciante ya no salta junto con la tuya.
- Abrir el mapa ya no cierra el juego en un PC lento.
- El suelo bajo bloques parciales juntos (lingotes en la nave) ya no se ve negro, y los bloques parciales junto a un neón vuelven a verse iluminados.
- La ventana se abre directamente con su tamaño, y la hierba roja alta ya no suelta trozos blancos.

Gracias también a **Sekhmet** por los reportes de errores. Todo en el [CHANGELOG](../CHANGELOG.md) y la lista de errores conocidos en `ERRORES.md`.

### Tus partidas guardadas
Siguen funcionando: los planetas que ya visitaste reciben licencia (el de salida pasa a ser tu planeta principal), y la base de datos ESCorp empieza vacía, salvo los kubes de tu nave, y se va llenando mientras juegas. **El formato de las partidas todavía puede cambiar entre versiones.**

---

## Galaxy 55 (offline) v0.7 — what's new

Version 0.7 of the **unofficial** native port of Galaxy 55 (Motion Twin, 2012) is out. No Flash, no browser and no server.

**How to play (Windows):** unzip the whole folder and double-click `jugar.bat`. If it doesn't open (PCs without OpenGL 3.2 or virtual machines), use `jugar_dx.bat`, the DirectX build. Nothing to install. Saves go to `%APPDATA%\Galaxy55\`.
**Linux and macOS:** separate zip; it needs HashLink 1.16 installed (see its `LEEME.txt`).

Almost all of it is by **Cornor923** (thank you!). Four big new features that were not in the original game: the ESCorp database, exploration licenses, comets and the Kube editor.

### The four big new features

#### ESCorp database and Kubindex
A new button on the on-board computer, "ESCorp database", keeps track of everything you discover. Three tabs:
- **Kubindex:** every kube in the game, sorted by category (Planets, Anomalies, Comets, Crafted, Special, Charges). Point your laser at a kube to get it identified, and get it into your inventory to have it collected. Its card tells you where to find it, how many times you placed, broke and crafted it, the recipes that make it and the ones that use it.
- **Space:** the planet and comet types you have explored and the anomalies you have come across.
- **Recipes:** each recipe is discovered when you collect one of its kubes.

A notice at the top right announces each discovery, and new entries stay marked until you look at them.

#### Exploration licenses
In adventure, scanning a planet uses an ESCorp license: 4 in total, 1 for your main planet and 3 for exploration (unlimited in creative).
- The first planet you scan becomes your main one (with the tutorial, the tutorial planet), and the ship can only be piloted over it, which lets you move your landing spot on that planet.
- On the on-board computer, "Exploration licenses" lists them and lets you change your main planet: free the first time, then 1000 credits, with 24 real hours between changes.
- On the map, "Abandon" frees a planet's license (never your main planet's), but also removes the planet from your game for good.

#### Comets
Very small worlds passing through solar systems: every 2 hours, each system has a 1 in 6 chance of hosting one. What makes them special: comets need no license.
- Time is short: from 1:30 to 15:00 depending on your ship's speed, and it only runs while you are on the ground.
- Once you take off, the comet is gone.
- The cinder comet has crater rock, cinder debris, etherium veins with etherium meteorites, and lava. More comets will come in future updates.

#### The Kube editor
In the main menu, under New game. Paint the faces of a block pixel by pixel (pencil, eraser, fill, picker, mirror, Ctrl+Z) in one of the shapes the game can already draw: cube, box (slab, neon...), door, cross plant, tall grass, panel, column, pipe, cage... Set its look (opaque, cut-out like leaves, translucent like glass), its light and whether it can be walked through, and watch it spin in 3D.

Start from a blank kube or from any kube in the game. Your creations are kept in "My kubes", as `.kube` files in `%APPDATA%\Galaxy55\kubes`: send them to us to suggest your kubes.

### Also in v0.7

#### Quicksand
Falling into quicksand now works like landing on the ground: you take the impact when you touch the sand, then it stops your fall. Before, all the fall damage came at once, at the end. The damage taken inside the sand stays as in the original.

#### No more freezes
No more stops when the main menu appears, on the loading screens, when arriving on a planet or when loading the mothership. Before, the game froze for up to almost a second, and about 6 seconds on the first visit to the mothership.

#### Gameplay changes
- The on-board computer, the shop, contracts and licenses no longer pause the game: you keep healing in the ship.
- In the synthesizer area and in the hangar, a broken block always drops. A dropped block buried under others comes out from the side.
- The synthesizer computer also works with a block in hand and with a right click.
- Two quick clicks now place both blocks.
- Tutorial: the synthesizer only makes aluminium and hull plating (no more getting stuck), a green arrow points to the emergency landing planet, and the congratulations leave when you take off.

#### Bug fixes (selection)
- The volume in Options finally applies to sounds.
- A cascade behind glass is visible, and the camera no longer enters the block above when climbing a cascade.
- Blocks can be placed on tall grass, and dropped blocks no longer jitter on the ground.
- Snow only covers the snowy planet, under open sky.
- Fog no longer changes when you turn the camera.
- The merchant robot's ship no longer jumps along with yours.
- Opening the map no longer closes the game on a slow PC.
- The floor under partial blocks side by side (ingots in the ship) is no longer black, and partial blocks next to a neon are lit again.
- The window opens at its size straight away, and tall red grass no longer drops white bits.

Thanks also to **Sekhmet** for the bug reports. Everything is in the [CHANGELOG](../CHANGELOG.en.md), and the known bugs in `BUGS.md`.

### Your old saves
They carry on: the planets you already visited get a license (the starting one becomes your main planet), and the ESCorp database starts empty, apart from your ship's kubes, then fills up as you play. **The save format may still change between versions.**

---

## Galaxy 55 (offline) v0.7 — les nouveautés

La version 0.7 du portage natif **non officiel** de Galaxy 55 (Motion Twin, 2012) est là. Sans Flash, sans navigateur et sans serveur.

**Comment jouer (Windows) :** décompresse tout le dossier et double-clique sur `jugar.bat`. S'il ne s'ouvre pas (PC sans OpenGL 3.2 ou machines virtuelles), utilise `jugar_dx.bat`, la version DirectX. Rien à installer. Les parties sont enregistrées dans `%APPDATA%\Galaxy55\`.
**Linux et macOS :** zip séparé ; il faut HashLink 1.16 installé (voir son `LEEME.txt`).

Presque tout est l'œuvre de **Cornor923** (merci !). Quatre grandes nouveautés qui n'existaient pas dans le jeu original : la base de données ESCorp, les licences d'exploration, les comètes et l'éditeur de Kubes.

### Les quatre grandes nouveautés

#### Base de données ESCorp et Kubindex
Un nouveau bouton dans l'ordinateur de bord, « Base de données ESCorp », garde la trace de tout ce que tu découvres. Trois onglets :
- **Kubindex :** tous les kubes du jeu, classés par catégorie (Planètes, Anomalies, Comètes, Fabriqués, Spéciaux, Charges). Vise un kube au laser pour l'identifier, et mets-le dans ton inventaire pour le récupérer. Sa fiche indique où le trouver, combien de fois tu l'as posé, cassé et fabriqué, les recettes qui le donnent et celles qui l'utilisent.
- **Espace :** les types de planètes et de comètes que tu as explorés et les anomalies que tu as croisées.
- **Recettes :** chaque recette est découverte quand tu récupères un de ses kubes.

Un avis en haut à droite annonce chaque découverte, et les nouvelles fiches restent marquées jusqu'à ce que tu les regardes.

#### Licences d'exploration
En aventure, scanner une planète dépense une licence ESCorp : 4 au total, 1 pour ta planète principale et 3 d'exploration (illimitées en créatif).
- La première planète scannée devient ta planète principale (avec le tutoriel, celle du tutoriel), et le vaisseau ne se pilote qu'au-dessus d'elle, ce qui te permet de déplacer ton point d'atterrissage sur cette planète.
- Dans l'ordinateur de bord, « Licences d'exploration » les liste et permet de changer de planète principale : gratuit la première fois, puis 1000 crédits, avec 24 heures réelles entre deux changements.
- Sur la carte, « Abandonner » libère la licence d'une planète (jamais celle de la principale), mais la retire aussi de ta partie pour de bon.

#### Comètes
De très petits mondes de passage dans les systèmes solaires : toutes les 2 heures, chaque système a 1 chance sur 6 d'en accueillir une. Leur particularité : les comètes ne demandent pas de licence.
- Le temps est compté : de 1:30 à 15:00 selon la vitesse de ton vaisseau, et il ne s'écoule que quand tu es au sol.
- Dès que tu décolles, la comète disparaît.
- La comète calcinée a de la roche de cratère, des débris calcinés, des veines d'etherium avec des météorites d'etherium, et de la lave. D'autres comètes arriveront dans les prochaines mises à jour.

#### L'éditeur de Kubes
Dans le menu principal, sous Nouvelle partie. Peins les faces d'un bloc pixel par pixel (crayon, gomme, remplissage, pipette, miroir, Ctrl+Z) dans une des formes que le jeu sait déjà dessiner : cube, boîte (dalle, néon...), porte, plante en croix, hautes herbes, panneau, colonne, tuyau, cage... Choisis son rendu (opaque, découpé comme les feuilles, translucide comme le verre), sa lumière et s'il est traversable, et regarde-le tourner en 3D.

Pars d'un kube vierge ou de n'importe quel kube du jeu. Tes créations sont gardées dans « Mes kubes », en fichiers `.kube` dans `%APPDATA%\Galaxy55\kubes` : envoie-les-nous pour proposer tes kubes.

### Aussi dans la v0.7

#### Sable mouvant
Tomber dans le sable mouvant fonctionne maintenant comme atterrir sur le sol : tu prends le choc en touchant le sable, puis il arrête ta chute. Avant, tous les dégâts de la chute arrivaient d'un coup, à la fin. Les dégâts subis dans le sable restent comme dans l'original.

#### Plus de blocages
Plus d'arrêts à l'apparition du menu principal, sur les écrans de chargement, à l'arrivée sur une planète ni au chargement du vaisseau-mère. Avant, le jeu se figeait jusqu'à presque une seconde, et environ 6 secondes lors de la première visite du vaisseau-mère.

#### Changements de jeu
- L'ordinateur de bord, la boutique, les contrats et les licences ne mettent plus le jeu en pause : tu continues à te soigner dans le vaisseau.
- Dans la zone du synthétiseur et dans le hangar, un bloc cassé tombe toujours. Un bloc tombé enterré sous d'autres ressort par le côté.
- L'ordinateur du synthétiseur marche aussi avec un bloc en main et au clic droit.
- Deux clics rapides posent maintenant les deux blocs.
- Tutoriel : le synthétiseur ne fabrique que de l'aluminium et du blindage (plus de blocage), une flèche verte indique la planète de l'atterrissage d'urgence, et les félicitations partent au décollage.

#### Corrections (sélection)
- Le volume des Options s'applique enfin aux sons.
- Une cascade derrière du verre se voit, et la caméra n'entre plus dans le bloc du dessus en montant une cascade.
- On peut poser des blocs sur les hautes herbes, et les blocs tombés ne tremblent plus au sol.
- La neige ne couvre que la planète enneigée, à ciel ouvert.
- Le brouillard ne change plus quand on tourne la caméra.
- Le vaisseau du robot marchand ne saute plus avec le tien.
- Ouvrir la carte ne ferme plus le jeu sur un PC lent.
- Le sol sous des blocs partiels côte à côte (lingots dans le vaisseau) n'est plus noir, et les blocs partiels à côté d'un néon sont de nouveau éclairés.
- La fenêtre s'ouvre directement à sa taille, et les hautes herbes rouges ne lâchent plus de morceaux blancs.

Merci aussi à **Sekhmet** pour les signalements de bugs. Tout est dans le [CHANGELOG](../CHANGELOG.fr.md), et les bugs connus dans `BUGS.fr.md`.

### Tes anciennes parties
Elles continuent : les planètes déjà visitées reçoivent une licence (celle de départ devient ta planète principale), et la base de données ESCorp commence vide, sauf les kubes de ton vaisseau, puis se remplit au fil du jeu. **Le format des sauvegardes peut encore changer d'une version à l'autre.**

---

### Licencia / License / Licence
Código y datos de Galaxy 55 © Motion Twin, **CC BY-NC-SA 4.0**. Este port es una obra derivada bajo la misma licencia: uso no comercial y con crédito. Ver `LICENSE` y `NOTICE`. El icono de "nuevo" de la base de datos es de Mush (Motion Twin, CC BY-NC-SA 4.0).
