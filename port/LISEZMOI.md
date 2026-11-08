# Port natif (Haxe 4 + Heaps + HashLink)

[Español : `LEEME.md`](LEEME.md) · [English: `README.md`](README.md)

Ce dossier contient le portage du jeu en application de bureau native, sans Flash. C'est un travail en cours (avec des bugs
connus, voir `BUGS.fr.md` à la racine du dépôt) ; le jeu Flash d'origine, avec ses fichiers de compilation et ses SWF, reste intact dans la branche `flash` (ici ne reste que le code original que compile le port).

## Jouer

Compile-le (voir plus bas) et double-clique sur `jugar.bat`, ou télécharge le zip portable depuis la
[release](../../../releases/tag/v0.7). Le menu de démarrage propose Continuer (la liste des parties : jouer, renommer ou supprimer), Nouvelle partie, Éditeur de Kubes (ajout du portage : dessiner de nouveaux blocs et les enregistrer en `.kube` dans le dossier `kubes` des données), Options et Quitter.
Dans Nouvelle partie, tu choisis le nom, la graine et le mode : **Aventure** (comme dans l'original, inventaire vide) ou **Créatif** (notre ajout, avec biome et taille).
Les parties et les réglages sont enregistrés dans `%APPDATA%\Galaxy55\` (modifiable avec la variable d'environnement `GALAXY55_DATA`), et les captures d'écran (F2) dans son dossier `screenshots`.
Le format des sauvegardes peut changer d'une version à l'autre : ne compte pas sur le fait que les parties d'aujourd'hui fonctionnent toujours.

## Commandes

Ce sont celles du jeu original (le déplacement et la physique sont copiés de `ent/Hero.hx` et `Game.moveHero`).

| Action | Touches |
|---|---|
| Se déplacer | W/Z/↑ avancer, S/↓ reculer, A/D et ←/→ de côté (dans les Options, elles peuvent faire tourner, comme dans l'original) |
| Regarder | souris (ou manette) |
| Sauter et jetpack | Espace ou Ctrl ; en l'air, jetpack (consomme du carburant, se recharge au sol) |
| Marcher lentement | X |
| Casque | H l'enlève ou le remet |
| Coordonnées et FPS | F les affiche ou les masque (masquées au départ, comme dans l'original) |
| Creuser ou poser | clic gauche, E ou Maj (maintenir). Main vide : tu creuses ; avec un bloc, tu le poses si quelque chose le soutient |
| Choisir une case | 1–0 ou molette de la souris ; Tab = laser de minage (main vide) |
| Jeter la pile choisie | R ou Suppr |
| Activer (ordinateur de bord, portes, bombe antique) | viser, appuyer et relâcher. En maintenant jusqu'à ce que le bloc casse, on le creuse : c'est ainsi qu'on ramasse une bombe antique sans la faire exploser (il faut la charge rose, comme pour la roche antique). L'ordinateur du synthétiseur marche aussi avec un bloc en main et au clic droit (changement du portage) |
| Conteneur ESCorp (coffre) | viser, appuyer et relâcher. Le jeu continue : clic prend et pose (Maj la moitié, Ctrl un ; ou flèches et Entrée, ou croix et A), glisser hors de la fenêtre fait regarder et s'éloigner le ferme (Échap et B aussi) |
| Retourner au vaisseau | Maj+K, ou entrer dans le rayon de lumière d'atterrissage |
| Piloter le vaisseau (ajout du portage) | ordinateur de bord > Piloter le vaisseau : WASD ou stick gauche le déplacent au-dessus de la planète, la souris ou le stick droit tournent la caméra, E, Échap, B ou Start le laissent où il est (il freine, se redresse et atterrit tout seul) |
| Créatif : palette de blocs | I (clic = mettre le bloc dans la case choisie, molette = page) |
| Pause | Échap |
| Sauvegarde rapide | F5 |
| Capture d'écran | F2 : un PNG sans le casque ni le HUD, à la taille de la fenêtre, dans `%APPDATA%\Galaxy55\screenshots\` |

Il n'y a pas de touche pour courir, comme dans l'original. Manette : stick gauche pour se déplacer, stick droit pour regarder,
A saute et jetpack, B marche lentement, RT creuse, LT pose, RB/LB ou croix droite/gauche changent de case, Y jette, Back casque,
Start pause. Menus : flèches/Entrée/Échap, souris ou manette.

## Compiler

Il faut (Windows) :
1. **Haxe 4.3.x** (https://haxe.org/download/) et **HashLink 1.16** pour Windows (https://github.com/HaxeFoundation/hashlink/releases).
   Ajoute les dossiers au `PATH` ; `haxe` et `hl` doivent fonctionner dans un terminal.
2. Les bibliothèques Haxe :

       haxelib install format
       haxelib git heaps https://github.com/HeapsIO/heaps
       haxelib git hashlink https://github.com/HaxeFoundation/hashlink
       haxelib dev hlsdl <dossier-où-tu-as-cloné-hashlink>/libs/sdl

   (`hlsdl` a besoin des sources de HashLink : clone ce dépôt et fais pointer `haxelib dev` vers son dossier `libs/sdl`.)
   C'est ainsi qu'est configurée la machine de développement (Heaps de la branche principale, HashLink 1.16, sans droits
   d'administrateur). **Ce n'a pas été testé depuis zéro sur une autre machine** : si quelque chose échoue, ouvre une *issue*.
3. Depuis la racine du dépôt :

       haxe port\game.hxml          jeu complet avec les menus   (-> port\out\galaxy55.hl)
       haxe port\render.hxml        test technique du rendu      (-> port\out\render.hl)
       haxe port\headless.hxml      générateur de planètes sans écran, HashLink
       haxe port\headless_flash.hxml  le même programme pour Flash (référence)

`jugar.bat` cherche `hl` dans le `PATH` ; s'il est ailleurs, indique d'abord son chemin dans la variable `HL`.

### Version DirectX (optionnelle)

Pour les machines sans OpenGL 3.2 (par exemple des machines virtuelles avec un GPU partagé), il existe une version DirectX 11 :

       haxelib dev hldx <dossier-où-tu-as-cloné-hashlink>/libs/directx
       haxe port\game_dx.hxml       (-> port\out\galaxy55_dx.hl, à lancer avec jugar_dx.bat)

Problème connu : si les sources de `hldx` sont plus récentes que ton `directx.hdll` (binaire de HashLink 1.16 + hashlink de git),
changer le mode d'affichage échoue avec « Primitive or library is missing ». Corrige-le dans `libs/directx/dx/Window.hx`,
`set_displayMode` : entoure le corps de `try { ... } catch( e : Dynamic ) { winSetFullscreen(win, mode != Windowed); }`. Utiliser
un `hldx` qui correspond à ta version de HashLink évite le problème.
Le jeu cherche les graphismes d'origine dans `res\` (paquet portable) ou, à défaut, dans `src\G55\fla\client\gfx\` ; la variable `GALAXY55_RES` impose un autre dossier.

### Autres plateformes

Procure-toi une version de HashLink pour ta plateforme, copie `galaxy55.hl` dans son dossier sous le nom `hlboot.dat`, place le
dossier `res/` à côté et lance `hl`. Un joueur l'a fait fonctionner ainsi sous Linux ; nous ne l'avons pas testé.

## Contenu du dossier

- `game/` le jeu : menus (`GalaxyApp`, `Ui`), langues (`Lang`), réglages (`Settings`), sauvegardes (`SaveData`), planète, lumière et
  maillage (`World`), écoulement de l'eau (`WorldProcess`), modèles de blocs (`Models`), ciel et brouillard (`Sky`), neige (`Snow`),
  joueur, creuser et poser (`GameView`), inventaire (`Inv`, `InvBar`, `Palette`), effets et objets tombés (`Fx`, `Drops`), le
  vaisseau (`Ship`, `ShipData`), les comètes (`Comets`, `CometGenerator`) et la base de données ESCorp (`Kubindex`, `KubData`,
  `DatabasePanel` et les vues `Kub*`).
- `explore/` la carte stellaire (`Explorer`, avec le robot marchand et les flèches GPS).
- `shim/` couche de compatibilité `flash.*` pour que les générateurs d'origine compilent en HashLink.
- `headless/` programmes de vérification : les mondes sont identiques à ceux de Flash (empreinte Adler-32, eau et blocs) ; ils lisent aussi le vaisseau et les sauvegardes.

## Différences avec l'original

- La neige du biome d'hiver est un ajout du port : l'original ne l'a pas.
- Le mode créatif et sa palette sont un ajout du port.
- Le menu de l'ordinateur de bord a son propre style, comme dans la version Flash (l'original était une page web).
- La fenêtre du conteneur ESCorp montre aussi ton inventaire, se ferme aussi avec Échap, B ou Fermer et se manie au clavier
  et à la manette (tant qu'elle est ouverte, les flèches déplacent sa sélection et pas le joueur). Son contenu est gardé dans
  la partie (dans l'original, sur le serveur) et tombe au sol quand on le casse.
- La boutique du robot marchand (dans l'original, c'était un panneau web), son vaisseau sur la carte stellaire et la flèche
  GPS orange qui le désigne sont des ajouts du port.
- Les contrats ESCorp (ordinateur de bord > Contrats) sont un ajout du port (dans l'original, ils venaient du serveur ; seule
  reste la liste des blocs triviaux des contrats de base). Ils se modifient dans `contracts.json`. Les crédits de départ sont
  de 200 et arrivent à la fin du tutoriel (avant : 500 dès le début).
- La lave fait exploser la bombe antique (changement du port) : l'original la cassait et la lâchait, comme l'eau le fait toujours.
- Les licences d'exploration ESCorp sont un ajout du port (dans l'original, le serveur les gérait) : en aventure on scanne
  4 planètes (1 principale et 3 d'exploration) et le vaisseau ne se pilote qu'au-dessus de la principale.
- Les cascades et l'eau posée par le joueur baissent à chaque pas, avec une surface inclinée : ajout du port. La mer remplit
  les trous jusqu'à son niveau et, quand l'eau qui entre atteint le volume d'une couche de la mer, le niveau baisse d'un bloc
  sur toute la planète, comme l'original.
- Les plantes et autres modèles se visent par ce qu'on voit (les pixels de leurs feuilles), pas par toute la case (l'original les traitait comme un bloc entier).
- La bombe antique fait aussi exploser les bombes prises dans son explosion, une par image : l'original avait le code, mais
  une vérification l'empêchait de se déclencher. L'explosion laisse la roche mère (couche 0) en place (l'original l'enlevait
  aussi), la bombe n'explose pas dans le hangar et elle projette 8 éclats par bloc au lieu de 75 pour que le jeu ne se
  fige pas.
- Les textures lointaines utilisent des mipmaps comme l'original, mais les plantes ne s'effacent pas avec la distance et chaque
  bloc lointain garde sa couleur (dans l'original, les plantes fines disparaissaient de loin et, plus loin encore, les textures
  voisines se mélangeaient).
- Le rayon de lumière d'atterrissage suit tout changement dans la colonne sous le vaisseau et part du dessus des blocs bas comme
  les plaques (l'original ne le bougeait qu'en cassant un bloc à cet endroit) ; on ne retourne au vaisseau que debout sur sa
  base, pas de plus haut.
- Piloter le vaisseau au-dessus de la planète est un ajout de ce portage (l'original le laissait toujours au même endroit de
  chaque planète) : depuis l'ordinateur de bord, seulement sur les planètes jouables (pas dans le vaisseau-mère, le hangar, les comètes ni
  pendant le tutoriel ; en aventure, seulement au-dessus de la planète principale). Il reste toujours à la même hauteur, sans coût, avec une caméra derrière et au-dessus et un brouillard
  plus léger pendant ce temps ; le rayon de lumière montre où il restera (il s'efface à pleine vitesse et revient en allant
  doucement, à l'arrêt et à l'atterrissage). Il accélère et freine en douceur, se tourne vers où il
  va et s'incline dans les virages ; quand on le laisse, il reprend son orientation habituelle avant d'atterrir (ses blocs,
  coffres et synthétiseurs ne tournent pas). L'endroit est enregistré par planète ; sans le
  piloter, le vaisseau atterrit au même endroit que d'habitude.
- Options ajoutées : ombre du bloc que tu vas poser, nom du bloc visé et désactiver les vagues de l'eau.
- Le turbo mineur fait creuser trois fois plus vite jusqu'à 15 blocs autour de lui (5 dans l'original) et se récupère quand
  on le casse (dans l'original, il était perdu).
- La capture d'écran de F2 est enregistrée directement dans le dossier `screenshots` et un message indique où (l'original ouvrait la boîte de dialogue de Flash pour l'enregistrer).
- Dans le hangar, on ne peut poser ni liquides (eau, cascades, sable mouvant, lave...) ni la bombe antique : un message dit
  qu'ils ne sont pas autorisés à bord. L'original n'empêchait de poser que ce qui se propage (source de cascade et lave), sans message.
- Dans le hangar, on creuse quatre fois plus vite et sans charges, comme dans les zones de synthétiseur du vaisseau : changement
  du port, pour modifier le vaisseau confortablement. Dans l'original, on y creusait comme sur une planète, avec les charges.
- Tomber dans le sable mouvant (changement du port) : en le touchant, on prend le choc de la chute jusqu'à lui, comme sur le
  sol, et le sable arrête la chute ; en le quittant par le bas, la chute se compte depuis la sortie. Dans l'original, il ne
  faisait que ralentir le temps : la vitesse continuait d'augmenter dedans et les dégâts arrivaient à la fin, ceux de toute la
  chute. Comme dans l'original, le sable fait perdre de la vie quand les yeux sont dedans et, de l'intérieur, on ne vise rien
  en regardant vers le bas.
- La base de données ESCorp (ordinateur de bord) est un ajout de ce portage : le Kubindex avec tous les kubes, les types de
  planète et de comète, les anomalies et les recettes, qui se remplissent en jouant. La marque des nouveautés est une icône de
  Mush (`recent.png`, Motion Twin, CC BY-NC-SA 4.0).
- Les comètes sont un ajout de ce portage : des mondes de 96x96 qui passent un moment dans les systèmes (un tirage fixe par
  système et par tranche de 2 heures, pas le serveur). Elles n'utilisent pas de licence et le temps d'amarrage dépend de la
  vitesse du vaisseau.
- Dans la zone du synthétiseur et dans le hangar, ce qu'on casse tombe toujours (changement du portage : dans l'original, ce qui
  ne tombe qu'avec de la chance était souvent perdu quand on le reprenait là). Un bloc tombé enterré sous des blocs posés
  ressort par le côté ; dans l'original, il montait à travers eux et, dans le vaisseau, finissait sur le toit.
- Ce qui manque est dans `TODO.fr.md`, les bugs dans `BUGS.fr.md` et les idées pour plus tard dans `IDEAS.fr.md` (racine du dépôt).
