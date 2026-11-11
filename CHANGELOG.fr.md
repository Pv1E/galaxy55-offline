# Nouveautés (version native)

[Español : `CHANGELOG.md`](CHANGELOG.md) · [English: `CHANGELOG.en.md`](CHANGELOG.en.md)

## v0.8 — pre-release
- **Kubes de Kube** (ajout du portage) : les 77 blocs de Kube (Motion Twin, 2010) sont dans le jeu en blocs pleins, avec
  leurs textures, leur lumière et leur transparence, dans la palette créative et la base de données ESCorp. L'Eau de Kube et
  la Lave de Kube coulent sur leurs faces comme dans Kube, mais ne s'écoulent pas et ne blessent pas. Chacun est aussi dans
  `port/kubes` en fichier `.kube`, pour le retoucher dans l'éditeur de Kubes. Un monde ne garde que 255 blocs différents :
  si un nouveau ne tient plus, il n'est pas posé ni consommé.
- **Anomalie invisible** (ajout du portage) : sur environ 1 planète normale sur 8 (pas sur les comètes), un cube de 4x4x4
  flotte à 10-20 blocs du sol : 8 Coffres de Kube entourés de kubes Invisibles. Le kube invisible a l'air du ciel derrière
  lui et cache ce qui est plus loin ; à travers une vitre blindée teintée ou de la glace noire, il apparaît comme sous une
  lumière noire, avec des arêtes bleues. La base de données ESCorp la compte comme anomalie (repérée en passant dessous ou à
  côté). Les planètes sans elle ne changent pas et les sauvegardes restent valables.
- **Gemmes de Kube** (ajout du portage) : dans le synthétiseur, un Coffre de Kube donne au hasard un Rubis, un Saphir, une
  Émeraude ou une Améthyste (un Kube mystère s'affiche avant la fabrication) ; 8 gemmes identiques font une Ombre et 8 Ombres
  un Téléport, qui ne fait rien pour l'instant. Dans la base de données, la recette du coffre montre ses quatre résultats
  possibles.
- **Vitres blindées de couleur** (ajout du portage) : une vitre blindée avec une gemme dessus donne une vitre blindée teintée
  rouge (Rubis), bleue (Saphir), verte (Émeraude) ou rose (Améthyste). Ce sont des blocs du vaisseau, plus clairs que la
  vitre blindée teintée et, contrairement à elle, ils ne révèlent pas les kubes invisibles. Le robot marchand les achète
  100 et ne les vend pas.
- **Boutique du vaisseau-mère** (ajout du portage) : l'étal du robot marchand est au milieu du hangar, entre les deux rangées
  de baies (avant, dans la proue, loin de tout). C'est un étal ouvert, fait de blocs du vaisseau, avec un mur invisible
  au-dessus du comptoir. Plus d'ordinateur : le robot se tourne vers toi et, en cliquant dessus, on lui parle dans une
  fenêtre comme celle des contrats : 1. commercer (la boutique), 2. discuter (conseils, rumeurs et blagues de robot) et
  3. au revoir, avec les touches numériques, la souris, les flèches ou la manette. Pendant le tutoriel, on ne peut pas
  commercer.
- Une partie enregistrée dans le vaisseau-mère se charge dedans, là où tu étais (avant, elle s'ouvrait sur la carte
  stellaire).
- Synthétiseur (changement du portage) : les recettes donnent plus. Le bois (aussi celui de Grozarb et le bois Frimas) donne
  4 planches (2 avant), 4 planches en carré donnent 4 dalles en bois (1 avant) et beaucoup de recettes donnent 2 au lieu de 1
  (barreaux de fenêtre, colonnes, carrelage en rosh, rideau de feuilles, verre, porte et dalle blindées, agrégats...).
- Recettes et blocs nouveaux (ajout du portage) : **Colonne en rosh** (2 rosh l'un sur l'autre) et **Carrelages en
  rouge'rosh, de roche douce et du frimas** (8 de leur roche en deux couches de 2x2), 2 par recette. Le **Conteneur ESCorp**
  se fabrique avec 8 fers en deux couches de 2x2 et apparaît dans la palette créative (avant, impossible d'en avoir un). Le
  tronc de lunimeuse se fait avec 2 lunimeuses mortes (avant 2 roches lunaires), qui tombent toujours : la recette marche en
  aventure.
- Robot marchand (changement du portage) : ce qui se fabrique avec ce qu'il vend ne se revend plus au-dessus du prix de ses
  ingrédients (planches 3, verre basique 4, lumine et lanterne 12, blindage et vitre blindée 100...). Les charges de
  citronox coûtent 20 (120 avant), le moteur spatial 1000 et le Conteneur ESCorp 400. Il ne vend plus, mais achète toujours,
  les murs et carrelages, les colonnes, les pièces du vaisseau (l'aluminium reste en vente pour les fabriquer), les minerais
  et cristaux trouvés sur les planètes, ce que seules les anomalies donnent et d'autres trouvailles rares. Il ne vend ni
  n'achète les kubes, les blocs spéciaux (sauf le moteur spatial et le conteneur), le vieux citronox et les fragments
  d'etherium bleu.
- **Contrats ESCorp en plusieurs fois** : avec une partie des blocs seulement, « Donner » remet ceux que tu portes et le
  contrat reste en cours en haut du panneau. Il n'expire plus avec le tableau, se termine quand tu veux et la récompense
  entière est payée avec le dernier bloc. Il prend une ligne du tableau (avec 3 en cours, il est plein). « Abandonner »
  demande confirmation : les blocs donnés sont perdus et rien n'est payé. Il est enregistré avec la partie.
- Base de données ESCorp : les kubes suivent un ordre plus proche de l'original : d'abord ceux des planètes, planète par
  planète (dans l'ordre de l'onglet Espace), puis ceux des comètes et ceux que seules les anomalies donnent, les blocs
  fabriqués dans l'ordre de leurs recettes, les blocs spéciaux et les kubes. Les recettes vont par matériau : bois, pierre,
  vaisseau, verre et lumière, agrégats, fer et appareils, charges.
- Éditeur de Kubes : un bouton à côté de « Rotation auto » montre un bloc de 2x2x2 ou de 3x3x3 du même kube, pour voir comment
  ses faces se raccordent. La molette zoome vers le point sous le curseur (de 50 % à 600 %), et + et - du pavé numérique vers
  le centre. En faisant glisser la vue, le kube tourne dans le sens de la souris (avant, à l'envers). Le verre et la glace
  s'affichent comme dans le monde, faces avant seulement (avant, celles de derrière passaient par-dessus).
- Les icônes des blocs sont lisses dans toute l'interface (barre d'inventaire, palette, coffre, boutique, contrats, éditeur
  de Kubes), comme dans la base de données : plus de pixels sautés ni d'icônes crénelées dans une petite fenêtre, et les
  translucides (verre, glace, eau, sable mouvant, HUD blindé, champ de force...) ne paraissent plus creux ni sombres.
- Le fondu d'écran de la bombe antique ne clignote plus (changement du portage, pour les personnes épileptiques) : dans une
  réaction en chaîne ou avec plusieurs bombes d'affilée, il se prolonge au lieu de recommencer et ne remonte qu'une fois par
  seconde au plus (avant, jusqu'à 15-17 flashs rouges et blancs par seconde). Les dégâts et les secousses ne changent pas.
- Charger une partie enregistrée par une version plus récente, avec des blocs que celle-ci ne connaît pas, ne ferme plus le
  jeu : il demande d'abord et, si on accepte, garde une copie dans `saves/backups`, supprime ces blocs et dit ce qu'il a
  supprimé et où est la copie.
- La version DirectX ne se ferme plus à l'ouverture de la base de données ESCorp quand elle contient une nouveauté.
- En arrivant sur une planète, la scène ne devrait plus clignoter quelques secondes sur certains PC (à confirmer sur un PC
  où ça arrivait) : les icônes de réserve de la base de données sont terminées sur l'écran de chargement. Le jeu écrit
  `gpu.txt` (carte graphique et pilote) dans son dossier de données, à joindre quand on signale un bug d'affichage.
- Le conteneur s'appelle « Conteneur ESCorp » (avant « EScorp »).
- `jugar.bat` et `jugar_dx.bat` (à la compilation) trouvent aussi `hl.exe` directement dans `tools-portable\hashlink`.

## v0.7 — pre-release
- **Base de données ESCorp** (ajout du portage), dans l'ordinateur de bord, avec trois onglets : le **Kubindex**, avec tous
  les kubes du jeu par catégorie (viser un kube au laser le repère ; l'avoir dans l'inventaire le récupère, avec le nombre de
  fois où il a été posé, cassé et fabriqué, les recettes qui le donnent et celles qui l'utilisent) ; **Espace**, avec les types
  de planète et de comète explorés et les anomalies croisées ; et **Recettes**, découvertes en récupérant un de leurs kubes.
  Une notification en haut à droite annonce les nouveautés et les nouvelles fiches sont marquées jusqu'à ce qu'on les
  regarde. Elle s'ouvre instantanément. En créatif, tout est connu ; dans le tutoriel, elle s'ouvre après la fabrication
  du blindage.
- **Comètes** (ajout du portage) : de petits mondes qui passent un moment dans les systèmes solaires (à chaque tranche de
  2 heures, un système a 1 chance sur 6). Scanner une comète, c'est y atterrir, sans utiliser de licence. Le temps d'amarrage
  est compté (de 1:30 à 15:00 selon la vitesse du vaisseau ; il ne s'écoule qu'au sol) et, une fois écoulé, on revient au
  vaisseau. Au décollage, elle est perdue. La comète calcinée a un sol de roche de cratère, des débris calcinés, des filons
  d'etherium avec des météorites d'etherium et de la lave, sans eau.
- Plus de blocages à l'apparition du menu de démarrage, sur les écrans de chargement, en arrivant sur une planète ni au
  chargement du vaisseau-mère (avant, jusqu'à près d'une seconde, et environ 6 s à la première visite du vaisseau-mère).
- Tomber dans le sable mouvant : en le touchant, on prend le choc de la chute, comme sur le sol, et le sable arrête la chute
  (changement du portage : dans l'original, les dégâts arrivaient à la fin, pour toute la chute).
- Un bloc cassé dans la zone du synthétiseur ou dans le hangar tombe toujours, même s'il ne tombe ailleurs qu'avec de la
  chance ; un bloc tombé enterré sous des blocs posés ressort par le côté au lieu de finir sur le toit du vaisseau
  (changements du portage).
- Hors de la planète principale, l'ordinateur de bord ne propose plus « Piloter le vaisseau » (avant, il s'affichait puis
  refusait).
- Les félicitations de la fin du tutoriel disparaissent au décollage et durent 12 s (16 avant) : elles ne reviennent plus sur
  la planète suivante, suivies de « voici ta planète principale ».
- Éditeur de Kubes : en français, l'aide dit de nouveau « enregistrer » pour Ctrl+S.
- Avec la base de données ESCorp ouverte, l'aide des touches ne se voit plus derrière ses onglets.
- **Éditeur de Kubes** (ajout du portage) : dans le menu de démarrage, sous Nouvelle partie. On dessine les faces d'un bloc
  pixel par pixel dans une des formes que le jeu sait déjà dessiner (cube, cube à 6 faces, boîte, porte, plante, panneau,
  colonne...), on le voit tourner en 3D et on l'enregistre en fichier `.kube` dans le dossier `kubes` des données du jeu pour
  nous l'envoyer. On peut partir de n'importe quel bloc du jeu.
- L'ordinateur du synthétiseur marche aussi avec un bloc en main et au clic droit (changement du portage).
- Deux clics rapides posent les deux blocs (changement du portage : l'original ne posait pas le second avant 0,47 s).
- Pendant le tutoriel, le synthétiseur ne fabrique que de l'aluminium et du blindage : on ne peut plus gaspiller l'aluminium
  dans une autre recette et rester bloqué.
- Le tutoriel affiche la flèche verte vers la planète de l'atterrissage d'urgence.
- En ouvrant l'ordinateur de bord ou le menu pause, le pointeur va au centre de la fenêtre.
- La fenêtre du jeu s'ouvre directement à sa taille et avec son titre (avant, elle apparaissait petite un instant).
- Les hautes herbes rouges ne lâchent plus de morceaux blancs en cassant.
- Le sol sous des blocs partiels collés (p. ex. quatre lingots de fer ou d'aluminium dans le vaisseau) n'est plus noir
  (changement du portage : dans l'original ces blocs ne laissent pas passer la lumière ; murs et plafonds inchangés).
- Éditeur de Kubes : un kube nommé comme un nom réservé de Windows (con, aux, nul...) peut maintenant être enregistré.
- **Licences d'exploration ESCorp** (ajout du port ; dans l'original, le serveur les gérait) : en aventure, scanner une
  planète utilise une licence, 4 en tout (1 principale et 3 d'exploration) ; illimité en créatif. La première planète
  scannée est la principale (avec le tutoriel, la sienne). **Le vaisseau ne se pilote qu'au-dessus de la planète
  principale** : ailleurs, l'ordinateur de bord ne propose pas « Piloter le vaisseau ». Là, « Licences d'exploration » les
  montre et permet de changer de planète principale
  (gratuit la première fois, puis 1000 crédits et 24 heures réelles entre deux changements) ; sur la carte, « Abandonner »
  libère la licence d'une planète. Les anciennes parties donnent une licence aux planètes visitées et celle de départ est la principale.
- Le volume des Options s'applique enfin aux sons (à 0, plus rien).
- Une cascade derrière du verre se voit ; la caméra n'entre plus dans le bloc du dessus en montant une cascade.
- On pose un bloc sur les hautes herbes (elles sont écrasées) et l'aperçu de pose n'apparaît que là où l'on peut poser.
- Les blocs lâchés ne tremblent plus au sol ; les herbes donnent leur propre herbe.
- La neige ne couvre les blocs que sur la planète enneigée et à ciel ouvert.
- Le brouillard dépend de la distance et ne change plus en tournant la caméra.
- L'ordinateur de bord, la boutique, les contrats et les licences ne mettent plus le jeu en pause (on continue à guérir dans le vaisseau).
- Le robot marchand ne saute plus avec le vaisseau dans un système ; ouvrir la carte ne ferme plus le jeu sur un PC lent.
- Boutons de l'ordinateur de bord sans les notes entre parenthèses.
- Les blocs partiels à côté d'un néon sont de nouveau éclairés ; le vaisseau reste visible en passant le bord du monde.

## v0.6 — pre-release
- Dépôt : les fichiers qui servaient seulement à compiler la version Flash (`client*.hxml`, `build.bat`/`build.sh`, les SWF de
  `release/`, `libs/heaps` et `libs/format_old`) sont retirés de `main`. Ils restent intacts dans la branche `flash`. Le jeu ne change pas.
- **Piloter le vaisseau** (ajout du portage) : dans l'ordinateur de bord, « Piloter le vaisseau » le déplace au-dessus de la
  planète avec WASD ou le stick gauche (la souris ou le stick droit tournent la caméra) et E, Échap, B ou Start l'y laissent.
  Toujours à la même hauteur et sans coût ; il accélère et freine en douceur, se tourne vers où il va et s'incline dans les
  virages, et quand on le laisse il freine, se redresse et atterrit tout seul. Le rayon de lumière montre où il restera : il s'efface à pleine vitesse
  et revient en allant doucement, à l'arrêt et à l'atterrissage. Seulement sur les planètes jouables : pas
  dans le vaisseau-mère, le hangar ni pendant le tutoriel. L'endroit est enregistré par planète, même en plein vol ; les
  parties précédentes ne changent pas.
- De **Cornor923** (merci !, PR 60-63) :
  - **Contrats ESCorp** (ajout du portage ; dans l'original ils étaient gérés par le serveur et sont perdus) : bouton
    « Contrats (ESCorp) » de l'ordinateur de bord avec 3 contrats pour livrer des blocs contre des crédits (un contrat de base
    parmi les blocs triviaux de l'original et deux commandes). Le tableau est le même pour tous et change toutes les 30 minutes
    réelles ; les livraisons sont enregistrées avec la partie. Réglable dans `contracts.json` sans recompiler. Désactivé pendant
    le tutoriel. Les crédits de départ passent de 500 à 200, envoyés par l'ESCorp à la fin du tutoriel (0 pendant).
  - La lave fait exploser la bombe antique (changement du portage : l'original la cassait et la lâchait, comme l'eau le fait toujours).
  - Avec un bloc en main, il se pose devant les plantes, les modèles et les blocs partiels (impossible avant), et les herbes et
    stalactites sont écrasées en posant, comme dans l'original.
  - Depuis l'intérieur du vaisseau, le cadre d'une fenêtre ne se mélange plus avec un néon collé dehors (faces arrière cachées, comme l'original).
- Corrections de bugs trouvés par **Sekhmet** : poser un bloc au-dessus de la couche la plus haute ne le consomme plus sans le
  poser ; la tête dans une source de cascade ou dans des sables mouvants, on peut viser et creuser ce qui est devant, comme dans
  l'original ; les sables mouvants, la glace et le verre ne paraissent plus creux à côté d'une cascade (changement du port).

## v0.5 — pre-release
- Corrections de Cornor923 (merci !), intégrées depuis leurs PR 17-30 (changement du port) : pas de consommation d'oxygène sous
  l'eau en créatif ; la glace près de l'eau n'est plus découpée en triangles vue d'en dessous ; l'aide de la palette créative
  tient dans son panneau et aucun bloc n'est marqué à l'ouverture ; plus de bande sans eau sous un bloc sur la mer avec les
  vagues ; après la mort on reste dans le vaisseau (aussi en chargeant une partie sauvée à 0 de vie) ; pas de dégâts dans le
  hangar ; les échanges avec le robot ne sont plus perdus en sauvegardant dans le vaisseau-mère et le temps de jeu y est compté ;
  sur la carte, le vaisseau a les mêmes couleurs sur toutes les planètes, garde son cap à l'arrêt et est centré sur celui du hangar.
- De l'original, apporté par **Cornor923** (merci !, PR 31-51) :
  - la caméra et le HUD tremblent quand un bloc casse et à l'atterrissage ;
  - le turbo minier fonctionne (puissance 3 à moins de 15 blocs, avec son icône dans le HUD) ;
  - dans ton vaisseau, tu récupères de la vie peu à peu ;
  - la bombe antique explose quand on l'active (et fait sauter les bombes qu'elle atteint) ;
  - Maj+K fait un fondu blanc d'environ 3 secondes et te remet au vaisseau avec la vie et l'oxygène pleins ;
  - la vue baisse quand tu meurs, remonte avec Maj+K et le téléporteur, et plonge un peu quand tu prends un coup ;
  - sous l'eau, le champ de vision se resserre et le ciel prend la couleur du liquide, sans étoiles ;
  - le niveau de la mer baisse d'un bloc quand l'eau qui inonde les trous remplit une couche de la mer ;
  - des éclats du bloc jaillissent là où frappe le laser ;
  - le ciel étoilé de l'original sur les planètes, qui tourne quand tu marches ;
  - textures avec mipmaps : le paysage lointain ne scintille plus (changement du port : les plantes ne s'effacent pas au loin) ;
  - cadre de sélection visible, blocs lâchés à la taille de l'original, icônes et barre de chargement de la planète comme l'original ;
  - F2 enregistre une capture sans le HUD et F affiche ou cache les coordonnées et les FPS (cachés au départ) ;
  - le son de casse joue une fois par bloc lâché, chaînes comprises ;
  - la fenêtre de la cantine ne met plus le jeu en pause et se ferme quand tu t'éloignes ;
  - le rayon d'atterrissage suit le sol sous le vaisseau (creuser ou poser des blocs dessous ne le laisse plus flotter) ;
  - dans le hangar : pas de liquides ni de bombe, les supports fonctionnent (une porte ou un néon sans appui tombe) et on
    creuse plus vite, sans charges (changement du port).
- Encore de **Cornor923** (merci !, PR 52-59, changement du port sauf mention) :
  - **nouveau menu de démarrage** : Continuer ouvre la liste des parties (jouer, renommer, supprimer) ; Nouvelle partie demande
    le nom, la graine et le mode (Créatif : biome et taille ; Aventure : tutoriel oui/non) ;
  - **tutoriel guidé** (ajout du port) pour les nouvelles parties aventure, qui commencent dans l'espace avec l'inventaire vide,
    comme l'original ; on peut le passer depuis la pause ou l'ordinateur de bord ;
  - l'ordinateur de bord n'a plus le raccourci de test vers le vaisseau-mère ;
  - la flèche « < » des sélecteurs va au choix précédent ; la Cité morte a son nom et sa couleur sur la carte ;
  - en créatif, une forte chute ne secoue plus l'écran comme un coup ;
  - une porte ouverte du vaisseau ne compte plus comme un trou dans le hangar et les portes sont sauvées fermées, comme l'original ;
  - corrections perdues lors de l'intégration des PR 31-51 (icône du turbo avec le tremblement, aide des commandes de test, README).

## v0.4 — pre-release
- **Vie et oxygène**, comme l'original : les grosses chutes, la lave, l'eau acide, le charbon ardent et les herbes acides
  blessent ; sous l'eau l'oxygène s'épuise, puis tu te noies ; les sables mouvants noient aussi ; la plante et la boîte de
  soin soignent. Barres de vie et d'oxygène en bas (visibles seulement si elles ne sont pas pleines) et éclair rouge ou bleu.
  Quand tu meurs, tu reviens au vaisseau avec toute ta vie, sans rien perdre. Pas de dégâts en mode créatif.
- Options séparées en sections (Général, Commandes, Graphismes, Interface) : tout ne tenait plus sur un écran.
- Plantes et autres modèles : on vise ce qu'on voit (leurs feuilles, pas toute la case) ; avec plusieurs plantes ensemble, on casse facilement celle qu'on regarde (changement du port).
- **Vagues de l'eau**, celles de l'original ; on peut les désactiver dans les Options.
- Blocs partiels (plaques, fer, coffres…) : lumière par coin comme l'original.
- Menu : une seule petite planète de fond ; plus de saccades pendant sa génération.
- **L'eau s'écoule** (le `Process.hx` d'origine) : la mer remplit ce que tu creuses à côté d'elle jusqu'à son niveau ; les
  cascades et la lave tombent, s'étendent et disparaissent sans source ; l'herbe se couvre et se découvre ; les blocs
  accrochés et les détails cassent quand on retire leur support. Les cascades et l'eau que tu poses baissent à chaque pas,
  avec une surface inclinée (ajout du port).
- **Robot marchand sur la carte stellaire :** il voyage entre les systèmes du secteur ; clique dessus et il s'arrête pour
  t'attendre, et en t'amarrant tu entres dans son vaisseau (le vaisseau mère), avec la boutique. En sortant, tu reviens sur la carte. Sur la
  carte, son vaisseau a la forme du vaisseau mère vu d'en haut.
- **Décoller, c'est quitter la planète**, comme dans l'original : la planète est déchargée (ses changements sont enregistrés)
  et rien n'est dessiné derrière la carte. Pour revenir, tu atterris. Si tu sauvegardes ou fermes le jeu dans l'espace (ou dans
  le vaisseau du robot), « Continuer » te ramène sur la carte là où tu étais ; la liste des parties indique « Dans l'espace ».
- Carte stellaire : Échap (ou Start sur la manette) ouvre un menu de pause (Reprendre, Options, Menu principal).
- Les **flèches GPS** d'origine sur la carte : elles pointent vers les planètes visitées (et leurs systèmes) et vers le robot (en orange).
- Options : ombre du bloc que tu vas poser et nom du bloc visé (petit, en bas à droite) ; les deux peuvent être désactivés.
- Mode créatif : les quatre eaux (normale, sombre, acide et d'hiver) sont dans la palette.
- Corrections de **Cornor923** (merci !) : la roche mère (couche 0) est dessinée et on peut construire dessus ; le menu
  principal se colle aux bords des fenêtres larges ; le synthétiseur utilise d'abord les blocs de l'inventaire et garde la zone
  comme modèle (comme l'original) ; le jeu se lance en `galaxy55.exe`, avec son icône (Discord n'affiche plus « Half-Life ») ;
  l'eau et la glace sont dessinées dans le bon ordre ; on ne peut plus poser de bloc dans une source de cascade ni dans les
  sables mouvants ; les fonds de la boutique, du coffre, de la palette et de la carte couvrent toute la fenêtre ; textes
  centrés dans les boutons de la carte et sans chevaucher le bouton Fermer ; des noms pour beaucoup de blocs qui n'en avaient
  pas (variantes enneigées, charges, plantes, cristaux bonus).
- Le bloc tenu en main ne tremble plus en marchant.
- Corrections signalées par Sekhmet (merci !) : raccourcis clavier (Tab creuse et 1-0 sont les 10 cases), on peut poser des blocs
  sous l'eau, il ne neige plus sous un toit ni dans les grottes, la glace ne laisse plus de bloc en la cassant, ombre du bloc à
  poser, nom du bloc visé, et le congélateur gèle de nouveau l'eau et la lave proches.
- Linux : les zips utilisent `/` dans les chemins (ils extrayaient des fichiers avec `\`) ; étapes Linux de Sekhmet dans le `LEEME` du zip.
## v0.3.1 — pre-release
- Options : synchronisation verticale (VSync) et limite d'images par seconde (30, 60, 120, 144, 240 ou illimité).
- Corrections de **Cornor923** (merci !) : le voile des liquides et les fonds des menus couvrent les fenêtres plus larges
  que 16:9, plus de taches sombres à travers la glace, la tête ne rentre plus dans les kubes en tombant ou en flottant,
  `jugar.bat` utilise `hlw.exe` (sans console) s'il est présent, et un README en français.

## v0.3 — pre-release
- Hangar : refais ton vaisseau kube par kube, comme dans l'original ; on sort par le téléporteur pour l'enregistrer.
- Boutique : achète et vends des kubes contre des crédits, auprès du robot marchand.
- Son : les 12 effets de l'original (pas, saut, atterrissage, chute violente, jetpack, laser, casser et ramasser des kubes).
- Viseur fixe au centre de l'écran.
- Noms des kubes complets en espagnol, anglais et français (avant, ils sortaient en espagnol ou mélangés).
- Cantines : une pression les ouvre et maintenir le laser les casse (leur contenu tombe par terre). Dans ton vaisseau,
  l'ordinateur et les portes ne se cassent pas.
- Créatif : palette à la manette (R3), copier le kube visé (L3 ou clic du milieu) et deux nouveaux kubes, blindage jaune
  et noir, pour des bandes de danger.
- Vaisseau-mère : ciel d'espace profond (Voie lactée, nébuleuses, des milliers d'étoiles et des galaxies lointaines),
  places avec des bordures à bandes de danger et un éditeur (`editar_nodriza.bat`).
- Moins d'à-coups en cassant ou en posant des kubes, surtout dans le vaisseau-mère.
- Le rayon du téléporteur du vaisseau ne disparaît plus dans le brouillard de l'hiver.
- Corrections signalées par Sekhmet (merci !) : dans un liquide, l'écran et le brouillard prennent sa couleur, comme dans
  l'original (le sable mouvant ne paraît plus transparent) ; il ne neige plus sous l'eau ; l'eau a des faces latérales ;
  la glace immergée reste derrière l'eau ; textes de la carte stellaire traduits.
- Noms français originaux des biomes (Terres Rouges, Rocaille sombre, Sables arides), retrouvés par Sekhmet sur
  l'ancienne Twinpedia.
- Version DirectX en option (`haxe port\game_dx.hxml`, `jugar_dx.bat`), en plus de la version OpenGL.
- Vaisseau-mère : incassable, mieux éclairé, portes fermées, champs de force laser sur les hangars, 10 places marquées,
  ton vaisseau garé à la tienne (tu apparais dedans et son ordinateur te ramène), et une boutique avec un robot marchand
  animé dans le tunnel d'entrée.
- Manette : cantines, boutique et changement de case (LB/RB).
- Le jeu ne se fige plus quelques secondes au démarrage.
- `jugar.bat` fonctionne même si le PATH contient des dossiers avec des parenthèses.

## v0.2 — pre-release
- Carte stellaire avec les animations de l'original (entrée et sortie d'un système, hyperespace, flashs, attente du
  serveur), fond commun avec tourbillon ; les systèmes sont générés en arrière-plan, donc plus de blocage.
- Kube tenu en main et éclats en cassant, copiés de l'original.
- Cité morte au choix dans Nouvelle partie.
- Corrections : supprimer des parties, retirer la source de cascade du vaisseau, rotation des kubes lâchés, neige dans
  le vaisseau.
- Changements par rapport à l'original : le synthétiseur utilise les kubes de sa zone ; herbes et stalactites cassables ;
  courbure à 60 % ; les monticules de neige qui cachent une plante ressemblent à de la neige ; la caméra zoome sur la
  planète en y entrant.

## v0.1 — pre-release
Première version native publiée : menus et parties enregistrées, planètes identiques à celles de Flash,
creuser/poser/jetpack, mode créatif, vaisseau (téléporteur, portes, synthétiseur avec les recettes de l'original,
ordinateur), carte stellaire (secteur, systèmes, scan et atterrissage ; l'univers fait partie de la partie enregistrée)
et un paquet portable avec `jugar.bat`. Bugs connus : [`BUGS.md`](BUGS.md) (anglais).

L'ancienne version Flash a son propre historique dans [`docs/flash/CHANGELOG_flash.md`](docs/flash/CHANGELOG_flash.md) (espagnol).
