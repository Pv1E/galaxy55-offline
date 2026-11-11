# Bugs connus (version native)

[Español : `ERRORES.md`](ERRORES.md) · [English: `BUGS.md`](BUGS.md)

Si tu en trouves un qui n'est pas dans la liste, ouvre une *issue* avec ce que tu faisais et, si possible, une capture d'écran.
Les bugs corrigés sont déplacés à la fin. Les détails techniques sont dans [`port/RESUMEN.md`](port/RESUMEN.md) (en espagnol).

## Ouverts

| # | Où | Ce qui se passe |
|---|---|---|
| 4 | Éclairage | **À vérifier en jouant :** les blocs partiels (plaques, fer, coffres…) prennent maintenant la lumière de chaque coin dans les cellules voisines, comme l'original (`Builder.addCustomQuad`) ; avant, toute la face avait une seule lumière. Les modèles utilisaient déjà la lumière de l'original. |
| 8 | Hiver | Les **feuilles d'épicéa** donnent du matériau ; dans l'original, peut-être pas. |
| 10 | Rendu | Les **cristaux** tombés (charges) paraissent trop larges. |
| 14 | Eau | **(À corriger ?)** Quand on ouvre une grotte à côté de la mer, l'eau entre et la remplit d'un coup à la même hauteur que la mer, sans baisser en avançant. Désormais, comme dans l'original (`net/Local.hx` et `SReduceWater`), l'eau qui entre est comptée et, chaque fois qu'elle atteint le volume d'une couche de la mer (des centaines ou des milliers de blocs, selon la planète), la couche du dessus disparaît sur toute la planète : la mer baisse d'un bloc. Une petite grotte n'y arrive pas et se remplit toujours d'un coup jusqu'au niveau de la mer, comme dans l'original. |

## Corrigés

- v0.8 (corrigés par **Cornor923**, PR 96-112) : les icônes des blocs translucides ne paraissent plus creuses ni sombres et aucune icône n'est crénelée dans une petite fenêtre ; le fondu de la bombe antique ne clignote plus ; la version DirectX ne se ferme plus à l'ouverture de la base de données ESCorp ; une partie avec des blocs que cette version ne connaît pas ne ferme plus le jeu au chargement ; la scène ne devrait plus clignoter en arrivant sur une planète (à confirmer) ; dans l'aperçu de l'éditeur de Kubes, les faces arrière du verre et de la glace ne passent plus par-dessus et le kube tourne dans le sens de la souris ; le Conteneur ESCorp s'écrit avec « ESCorp ».
- v0.8 : une partie enregistrée dans le vaisseau-mère ne s'ouvre plus sur la carte stellaire.
- v0.7 (de **Sekhmet**, corrigés par **Cornor923**) : le volume à 0 ne fait plus de bruit ; une cascade derrière du verre se voit.
- v0.7 : le sol sous quatre lingots collés dans le vaisseau n'est plus noir (changement du portage).
- v0.7 (corrigés par **Cornor923**, PR 81-86) : les hautes herbes rouges ne lâchent plus de morceaux blancs ; le tutoriel ne reste plus bloqué si l'aluminium part dans une autre recette ; la flèche verte du tutoriel s'affiche ; la fenêtre n'apparaît plus petite au lancement.
- v0.7 (corrigés par **Cornor923**, PR 87-94) : tomber dans le sable mouvant ne laisse plus les dégâts de toute la chute pour la fin ; un bloc qui ne tombe qu'avec de la chance n'est plus perdu quand on le casse dans la zone du synthétiseur ou dans le hangar ; un bloc tombé enterré dans la zone du synthétiseur ne finit plus sur le toit du vaisseau ; les félicitations du tutoriel ne restent plus sur la carte et ne disent plus « ta planète principale » sur une autre planète ; plus de blocages à l'apparition du menu, au chargement d'une planète ni du vaisseau-mère ; en français, l'aide de l'éditeur de Kubes dit de nouveau « enregistrer ».
- v0.6 (trouvés par **Sekhmet**, merci !) : poser un bloc au-dessus de la couche la plus haute ne le consomme plus sans le poser (rien n'est visé, comme l'original) ; la tête dans une source de cascade ou dans des sables mouvants, on vise et on creuse ce qui est devant (l'original ne compte pas la cellule de la caméra) ; les sables mouvants, la glace et le verre ne paraissent plus creux à côté d'une cascade (changement du port : leur face contre la cascade est dessinée, car ici la cascade descend).
- v0.5 (#15, de **Sekhmet**) : le vaisseau ne change plus de place en rouvrant la partie. Jusqu'à la v0.4, le lieu d'atterrissage
  était calculé avec les modifications du joueur : creuser ou construire là où il atterrit mettait le vaisseau ailleurs et le
  joueur, enregistré dedans, tombait au sol. Depuis la v0.5, il est calculé sur le terrain d'origine (vérifié avec
  `port/dev/nave_sitio.txt`). Une partie de la v0.4 où le vaisseau avait déjà bougé le voit revenir une fois à sa place habituelle en passant à la v0.5.
- v0.4 : le menu utilise une seule petite planète de fond (avant, trois grandes qui changeaient toutes les 22 s) : plus de saccades pendant leur génération ; il reste un arrêt d'environ 0,4 s au début, quand la planète est dessinée pour la première fois (#13). La cascade ne gèle pas à côté de la glace, seulement avec le congélateur, comme l'original (#12, vérifié).
- v0.4 (signalés par **Sekhmet**, merci !) : l'eau s'écoule (`WorldProcess.hx`, le `Process.hx` d'origine) ; on peut poser des blocs sous l'eau ; il ne neige plus sous un toit ni dans les grottes ; la glace ne laisse plus de bloc en la cassant (comme l'original) ; raccourcis clavier (Tab creuse et 1–0 sont les 10 cases ; la dernière n'avait pas de touche).
- v0.4 : le bloc tenu en main ne tremble plus en marchant ; la surbrillance de la palette du mode créatif ne reste plus collée.
- v0.4 (corrigés par **Cornor923**, merci !, PR 17-30, changement du port) : pas de consommation d'oxygène sous l'eau en créatif ; la glace près de l'eau n'est plus découpée en triangles vue d'en dessous ; l'aide de la palette créative tient dans son panneau et aucun bloc n'est marqué à l'ouverture ; plus de bande sans eau sous un bloc sur la mer avec les vagues ; après la mort on reste dans le vaisseau (aussi en chargeant une partie sauvée à 0 de vie) ; pas de dégâts dans le hangar ; les échanges avec le robot ne sont plus perdus en sauvegardant dans le vaisseau-mère et le temps de jeu y est compté ; sur la carte, le vaisseau a les mêmes couleurs sur toutes les planètes, garde son cap à l'arrêt et est centré sur celui du hangar.
- v0.4 : le jeu fonctionne aussi avec DirectX (`port/game_dx.hxml`), utile là où OpenGL 3.2 manque (par ex. les machines virtuelles).
- v0.4 : la couche 0 (roche mère) est dessinée, comme dans l'original : le fond d'un trou creusé jusqu'à elle ne laisse plus voir le vide et le ciel sous la planète.
- v0.4 : le synthétiseur utilise d'abord les blocs de l'inventaire, comme l'original : tant que l'inventaire les a tous, les blocs posés dans sa zone restent comme modèle et on peut fabriquer la même recette encore et encore ; s'il en manque un, ce sont les blocs posés qui sont consommés (le changement de la v0.2 est annulé).
- v0.3 (trouvés et signalés par **Sekhmet**, merci !) : les sables mouvants et l'eau ne paraissent plus transparents de l'intérieur (voile et brouillard de la couleur du liquide, comme l'original) ; il ne neige plus sous l'eau ; l'eau a des faces latérales et de fond ; la glace immergée reste derrière l'eau ; les textes de la carte stellaire suivent la langue choisie.

- v0.2 (changement par rapport à l'original) : les monticules de neige qui cachent une plante (`BWinterHidden`) ressemblent à la neige normale, sans lueur propre.
- v0.2 : supprimer une partie depuis le menu (bouton Supprimer, puis choisir la partie ; la confirmation ne s'ouvre plus deux fois).
- v0.2 : il ne neige plus dans le vaisseau.
- v0.2 : la carte ne se bloque plus en entrant dans un système (il est généré en arrière-plan pendant le voyage).
- v0.2 (changement par rapport à l'original) : en entrant sur une planète, la caméra s'en approche au lieu d'un fondu au noir, et le nom ne s'affiche qu'une fois.
- v0.2 : on peut retirer la source de cascade (on la vise comme dans l'original).
- v0.2 : des particules quand on casse un bloc ; les blocs tombés tournent à la vitesse de l'original.
- v0.2 : la Cité morte peut être choisie dans Nouvelle partie (Shed pas encore).
- v0.2 (changement par rapport à l'original) : la courbure de la planète vaut 60 % de celle de l'original (elle se voyait trop, surtout sur les petites planètes).
- v0.2 : le bloc choisi se voit dans la main.
- v0.2 : carte stellaire avec les animations d'origine : entrer dans un système et en sortir (zoom, hyperespace, éclats ; la sortie laisse passer l'anneau et t'éjecte un peu plus tard), scanner (fondu, nom et barre) et atterrir ; fond commun avec tourbillon.
- v0.2 (changement par rapport à l'original) : le synthétiseur consomme toujours les blocs posés dans sa zone.
- v0.2 (changement par rapport à l'original) : les herbes du sol et les stalactites de glace se cassent ; elles donnent de l'herbe haute (33 %) ou de la glace (7 %), comme les plantes et la glace noire de l'original.

- Apparaître « dans le ciel » en entrant dans le synthétiseur (pas revu depuis).
- Les blocs du synthétiseur se dupliquaient quand on les posait.
- Écran noir au décollage vers la carte stellaire.
- Revenir d'une planète laissait le vaisseau hors de sa galaxie (il revient maintenant à côté de la planète).
