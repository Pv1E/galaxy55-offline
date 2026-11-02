/** Textos del juego en español, inglés y francés (los tres idiomas del original). */
class Lang {

	public static var CODES = ["es", "en", "fr"];
	public static var LABELS = ["Español", "English", "Français"];
	public static var cur = 0;

	// clave => [es, en, fr]
	static var T : Map<String, Array<String>> = [
		"subtitle" => ["VERSIÓN OFFLINE", "OFFLINE VERSION", "VERSION HORS LIGNE"],
		"continue" => ["Continuar", "Continue", "Continuer"],
		"new" => ["Nueva partida", "New game", "Nouvelle partie"],
		"lastgame" => ["Última partida", "Last game", "Dernière partie"],
		"options" => ["Opciones", "Options", "Options"],
		"quit" => ["Salir", "Quit", "Quitter"],
		"back" => ["Volver", "Back", "Retour"],
		"create" => ["Crear partida", "Create game", "Créer la partie"],
		"name" => ["Nombre", "Name", "Nom"],
		// nombre por defecto de una partida nueva (%n% = partidas + 1, o el siguiente que este libre)
		"newgame.name" => ["Partida %n%", "Game %n%", "Partie %n%"],
		"tutorial" => ["Tutorial", "Tutorial", "Tutoriel"],
		"seed" => ["Semilla", "Seed", "Graine"],
		"seed.random" => ["Aleatoria", "Random", "Aléatoire"],
		"biome" => ["Bioma", "Biome", "Biome"],
		"size" => ["Tamaño", "Size", "Taille"],
		"size.small" => ["Pequeño (128)", "Small (128)", "Petit (128)"],
		"size.normal" => ["Normal (256)", "Normal (256)", "Normal (256)"],
		"computer.title" => ["ORDENADOR DE A BORDO", "BOARD COMPUTER", "ORDINATEUR DE BORD"],
		"computer.takeoff" => ["Despegar (mapa de estrellas)", "Take off (star map)", "Décoller (carte stellaire)"],
		"computer.edit" => ["Modificar la nave (hangar)", "Modify the ship (hangar)", "Modifier le vaisseau (hangar)"],
		// anadido del port: pilotar la nave sobre el planeta
		"computer.pilot" => ["Pilotar la nave (sobre el planeta)", "Pilot the ship (over the planet)", "Piloter le vaisseau (survol)"],
		"computer.trade" => ["Comerciar (ESCorp)", "Trade (ESCorp)", "Commercer (ESCorp)"],
		"computer.contracts" => ["Contratos (ESCorp)", "Contracts (ESCorp)", "Contrats (ESCorp)"],
		"contracts.title" => ["Contratos de la ESCorp", "ESCorp contracts", "Contrats ESCorp"],
		// %t% = mm:ss hasta el siguiente tablero
		"contracts.renew" => ["Nuevos contratos dentro de %t%", "New contracts in %t%", "Nouveaux contrats dans %t%"],
		"contracts.reward" => ["Recompensa: %n% créditos", "Reward: %n% credits", "Récompense : %n% crédits"],
		"contracts.deliver" => ["Entregar", "Deliver", "Livrer"],
		"contracts.done" => ["Entregado", "Delivered", "Livré"],
		"shop.title" => ["Robot comerciante", "Merchant robot", "Robot marchand"],
		"shop.yours" => ["Lo que llevas (clic: vender)", "Your items (click: sell)", "Ton inventaire (clic : vendre)"],
		"shop.robot" => ["Lo que vende el robot (clic: comprar)", "Robot's stock (click: buy)", "Stock du robot (clic : acheter)"],
		"shop.hint" => ["Mayús + clic: 10 unidades. Rueda: página. Mando: A 1, X 10, LB/RB página, B cerrar. Los precios cambian según lo que se compra y se vende.", "Shift + click: 10 units. Wheel: page. Gamepad: A 1, X 10, LB/RB page, B close. Prices change with what is bought and sold.", "Maj + clic : 10 unités. Molette : page. Manette : A 1, X 10, LB/RB page, B fermer. Les prix changent selon ce qui est acheté et vendu."],
		"shop.close" => ["Cerrar", "Close", "Fermer"],
		"shop.credits" => ["Créditos:", "Credits:", "Crédits :"],
		"shop.buy" => ["comprar", "buy", "acheter"],
		"shop.sell" => ["vender", "sell", "vendre"],
		"chest.yours" => ["Tu inventario", "Your inventory", "Ton inventaire"],
		"chest.hint" => ["Clic: coger y dejar. Mayús: la mitad. Ctrl: una. Mando: A, X mitad, Y una, B cerrar.", "Click: pick up and drop. Shift: half. Ctrl: one. Gamepad: A, X half, Y one, B close.", "Clic : prendre et poser. Maj : la moitié. Ctrl : un. Manette : A, X moitié, Y un, B fermer."],
		"hangar.ship_valid" => ["Nave válida - velocidad: %speed% PC/s", "Valid ship - speed: %speed% PC/s", "Vaisseau valide - vitesse : %speed% PC/s"],
		"hangar.hull_hole" => ["La nave no es estanca: hay un agujero en el casco.", "The ship is not airtight: there is a hole in the hull.", "Le vaisseau n'est pas étanche : il y a un trou dans la coque."],
		"hangar.access_computer" => ["No se puede usar el ordenador de a bordo: una cara debe dar al interior.", "The board computer cannot be used: one face must open to the inside.", "L'ordinateur de bord est inutilisable : une face doit donner sur l'intérieur."],
		"hangar.access_craft" => ["No se puede acceder a la losa de ensamblaje.", "The assembly slab is not accessible.", "La dalle d'assemblage n'est pas accessible."],
		"hangar.access_craft_computer" => ["No se puede acceder al sintetizador.", "The synthesizer is not accessible.", "Le synthétiseur n'est pas accessible."],
		"hangar.multiple_spawn" => ["Solo puede haber un teletransportador.", "There can be only one teleporter.", "Il ne peut y avoir qu'un seul téléporteur."],
		"hangar.no_spawn" => ["Falta el teletransportador.", "The teleporter is missing.", "Il manque le téléporteur."],
		"hangar.no_spawn_air" => ["Deja 2 bloques completamente vacíos sobre el teletransportador.", "Leave 2 completely empty blocks above the teleporter.", "Laisse 2 kubes complètement vides au-dessus du téléporteur."],
		"hangar.no_spawn_light" => ["No hay luz sobre el teletransportador.", "There is no light above the teleporter.", "Il n'y a pas de lumière au-dessus du téléporteur."],
		"hangar.need_computer" => ["Falta el ordenador de a bordo.", "The board computer is missing.", "Il manque l'ordinateur de bord."],
		"hangar.need_craft" => ["Falta una losa de ensamblaje.", "An assembly slab is missing.", "Il manque une dalle d'assemblage."],
		"hangar.need_craft_computer" => ["Falta el sintetizador.", "The synthesizer is missing.", "Il manque le synthétiseur."],
		"hangar.need_engine" => ["Falta un motor.", "An engine is missing.", "Il manque un moteur."],
		"hangar.need_engine_out" => ["Ningún motor da al exterior: su cara trasera debe quedar libre.", "No engine faces the outside: its rear face must be free.", "Aucun moteur ne donne sur l'extérieur : sa face arrière doit être libre."],
		"hangar.need_engines_min2" => ["Se necesitan al menos 2 motores bien colocados.", "At least 2 well-placed engines are needed.", "Il faut au moins 2 moteurs bien placés."],
		"hangar.need_engines" => ["Demasiados bloques para tus motores: añade motores o quita bloques.", "Too many blocks for your engines: add engines or remove blocks.", "Trop de kubes pour tes moteurs : ajoute des moteurs ou retire des kubes."],
		"hangar.separate_part" => ["Hay partes separadas: todos los bloques deben estar unidos.", "There are separate parts: all blocks must be connected.", "Il y a des parties séparées : tous les kubes doivent être reliés."],
		"hangar.no_liquid" => ["Los líquidos no están permitidos a bordo de la nave.", "Liquids are not allowed on board the ship.", "Les liquides ne sont pas autorisés à bord du vaisseau."],
		"hangar.no_bomb" => ["La bomba exótica no está permitida a bordo de la nave.", "The Ancient Bomb is not allowed on board the ship.", "La bombe antique n'est pas autorisée à bord du vaisseau."],
		"hangar.exit_ship_no_save" => ["La nave no es válida: los cambios no se guardarán. ¿Salir?", "The ship is not valid: changes will not be saved. Leave?", "Le vaisseau n'est pas valide : les modifications ne seront pas sauvegardées. Quitter ?"],
		"hangar.help" => ["HANGAR - rompe y coloca bloques para rehacer tu nave. Sal por las casillas de teletransporte para guardar.", "HANGAR - break/place blocks to rebuild your ship. Leave through the teleporter tiles to save.", "HANGAR - retire et pose des kubes pour refaire ton vaisseau. Sors par les téléporteurs pour sauvegarder."],
		"helptext" => ["Ayuda en pantalla", "On-screen help", "Aide à l'écran"],
		"placepreview" => ["Sombra del bloque al poner", "Shadow of the block to place", "Ombre du bloc à poser"],
		"waterwaves" => ["Olas del agua", "Water waves", "Vagues de l'eau"],
		"targetname" => ["Nombre del bloque apuntado", "Name of the targeted block", "Nom du bloc visé"],
		"vsync" => ["Sincronización vertical (VSync)", "Vertical sync (VSync)", "Synchronisation verticale (VSync)"],
		"maxfps" => ["Límite de FPS", "FPS limit", "Limite d'images par seconde"],
		"maxfps.none" => ["Sin límite", "Unlimited", "Illimité"],
		"computer.mothership" => ["Visitar la nave nodriza (prueba)", "Visit the mothership (test)", "Visiter le vaisseau-mère (test)"],
		"shop.nosale" => ["el robot no compra esto", "the robot does not buy this", "le robot n'achete pas ca"],
		"shop.full" => ["el robot ya tiene demasiado de esto, vuelve mas tarde", "the robot has too much of this, come back later", "le robot en a trop, reviens plus tard"],
		"computer.close" => ["Cerrar", "Close", "Fermer"],
		"explore.loading" => ["Generando el mapa de estrellas...", "Generating the star map...", "Génération de la carte stellaire..."],
		"computer.soon" => ["Todavia no esta disponible en esta version", "Not available in this version yet", "Pas encore disponible dans cette version"],
		"mode" => ["Modo", "Mode", "Mode"],
		"mode.adventure" => ["Aventura (original)", "Adventure (original)", "Aventure (original)"],
		"mode.creative" => ["Creativo", "Creative", "Créatif"],
		"palette.title" => ["Bloques (modo creativo)", "Blocks (creative mode)", "Blocs (mode créatif)"],
		"palette.hint" => ["Clic / A: poner en la casilla elegida   Rueda / LB RB: cambiar de pagina   I / Esc / B: cerrar", "Click / A: put in the selected slot   Wheel / LB RB: change page   I / Esc / B: close", "Clic / A : mettre dans la case choisie   Molette / LB RB : changer de page   I / Échap / B : fermer"],
		"hud.pilot" => ["Pilotando: WASD mover la nave   Ratón girar la cámara   E / Esc dejar la nave aquí", "Piloting: WASD move the ship   Mouse turn the camera   E / Esc leave the ship here", "Pilotage : WASD déplacer le vaisseau   Souris tourner la caméra   E / Échap laisser le vaisseau ici"],
		"hud.creative" => ["Creativo: I abre la paleta de bloques", "Creative: I opens the block palette", "Créatif : I ouvre la palette de blocs"],
		"size.large" => ["Grande (384)", "Large (384)", "Grand (384)"],
		"newgame.title" => ["NUEVA PARTIDA", "NEW GAME", "NOUVELLE PARTIE"],
		"load.title" => ["PARTIDAS GUARDADAS", "SAVED GAMES", "PARTIES SAUVEGARDÉES"],
		"options.title" => ["OPCIONES", "OPTIONS", "OPTIONS"],
		"options.general" => ["General", "General", "Général"],
		"options.controls" => ["Controles", "Controls", "Commandes"],
		"options.graphics" => ["Gráficos", "Graphics", "Graphismes"],
		"options.interface" => ["Interfaz", "Interface", "Interface"],
		"pause.title" => ["PAUSA", "PAUSED", "PAUSE"],
		"save.space" => ["En el espacio", "In space", "Dans l'espace"],
		"nosaves" => ["No hay partidas guardadas", "No saved games", "Aucune partie sauvegardée"],
		"play" => ["Jugar", "Play", "Jouer"],
		"rename" => ["Renombrar", "Rename", "Renommer"],
		"rename.title" => ["RENOMBRAR PARTIDA", "RENAME GAME", "RENOMMER LA PARTIE"],
		"delete" => ["Borrar", "Delete", "Supprimer"],
		"delete.ask" => ["¿Borrar esta partida?", "Delete this save?", "Supprimer cette partie ?"],
		"accept" => ["Aceptar", "OK", "Valider"],
		"cancel" => ["Cancelar", "Cancel", "Annuler"],
		"yes" => ["Sí", "Yes", "Oui"],
		"no" => ["No", "No", "Non"],
		"played" => ["Jugado", "Played", "Temps de jeu"],
		"saved" => ["Guardado", "Saved", "Sauvegardé"],
		"language" => ["Idioma", "Language", "Langue"],
		"sens" => ["Sensibilidad del ratón", "Mouse sensitivity", "Sensibilité de la souris"],
		"fov" => ["Campo de visión", "Field of view", "Champ de vision"],
		"volume" => ["Volumen", "Volume", "Volume"],
		"fullscreen" => ["Pantalla completa", "Fullscreen", "Plein écran"],
		"invert" => ["Invertir eje vertical", "Invert vertical axis", "Inverser l'axe vertical"],
		"turnkeys" => ["Teclas A/D y flechas", "A/D and arrow keys", "Touches A/D et flèches"],
		"turnkeys.strafe" => ["Desplazarse de lado", "Strafe", "Se déplacer de côté"],
		"turnkeys.turn" => ["Girar (como el original)", "Turn (like the original)", "Tourner (comme l'original)"],
		"on" => ["Sí", "On", "Oui"],
		"off" => ["No", "Off", "Non"],
		"resume" => ["Reanudar", "Resume", "Reprendre"],
		"save" => ["Guardar partida", "Save game", "Sauvegarder"],
		"saved.ok" => ["Partida guardada", "Game saved", "Partie sauvegardée"],
		// captura con F2 (anadido del port: el original abria el dialogo de Flash para guardarla y no decia nada mas)
		"shot.saved" => ["Captura guardada en %dir%", "Screenshot saved to %dir%", "Capture d'écran enregistrée dans %dir%"],
		"mainmenu" => ["Menú principal", "Main menu", "Menu principal"],
		"loading" => ["Generando el planeta...", "Generating the planet...", "Génération de la planète..."],
		"hud.help" => ["WASD mover   Espacio saltar y jetpack   X caminar despacio   H casco   Esc pausa\nClic / E / Mayus excavar o colocar   1-0 / rueda elegir casilla   Tab excavador   R tirar   Mayus+K volver a la nave", "WASD move   Space jump and jetpack   X walk slowly   H helmet   Esc pause\nClick / E / Shift dig or place   1-0 / wheel pick slot   Tab digger   R drop   Shift+K back to ship", "WASD bouger   Espace sauter et jetpack   X marcher lentement   H casque   Échap pause\nClic / E / Maj creuser ou poser   1-0 / molette choisir   Tab pelle   R jeter   Maj+K retour au vaisseau"],
		"craft.norecipe" => ["Sin resultado :-(", "No result :-(", "Aucun résultat :-("],
		"mode.walk" => ["CAMINAR", "WALK", "MARCHE"],
		"mode.fly" => ["VUELO", "FLY", "VOL"],
		"gen.error" => ["No se pudo generar este planeta", "This planet could not be generated", "Impossible de générer cette planète"],
		"biome.BIAutumn" => ["Otoño", "Autumn", "Terres Rouges"],
		"biome.BIMoon" => ["Luna", "Moon", "Rocaille sombre"],
		"biome.BIMars" => ["Marte", "Mars", "Sables arides"],
		"biome.BIWinterPeaks" => ["Cumbres nevadas", "Winter peaks", "Sommets enneigés"],
		"biome.BIAcidForest" => ["Bosque ácido", "Acid forest", "Forêt acide"],
		"biome.BIDeadCity" => ["Ciudad muerta", "Dead city", "Cité morte"],
		"biome.random" => ["Aleatorio", "Random", "Aléatoire"],
		// mapa de estrellas (textos de exp.OfflineData)
		"exp.system" => ["Sistema", "System", "Système"],
		"exp.sector" => ["Sector", "Sector", "Secteur"],
		"exp.land" => ["Aterrizar", "Land", "Atterrir"],
		"exp.robot" => ["Robot comerciante", "Merchant robot", "Robot marchand"],
		"exp.dock" => ["Acoplarse", "Dock", "S'amarrer"],
		"exp.scan" => ["Escanear", "Scan", "Scanner cette planète"],
		"exp.nolicense" => ["Sin licencia", "No license", "Pas de licence"],
		// licencias de la ESCorp y planeta principal (Licenses, anadido del port)
		"exp.abandon" => ["Abandonar", "Abandon", "Abandonner"],
		"exp.abandoned" => ["abandonado", "abandoned", "abandonnée"],
		"exp.main" => ["planeta principal", "main planet", "planète principale"],
		"computer.licenses" => ["Licencias (ESCorp)", "Licenses (ESCorp)", "Licences (ESCorp)"],
		"licenses.title" => ["LICENCIAS DE LA ESCORP", "ESCORP LICENSES", "LICENCES ESCORP"],
		// %n% en uso de %max%; %e% = licencias de exploracion (%max% - 1)
		"licenses.count" => ["Licencias en uso: %n% / %max% (1 principal y %e% de exploración)", "Licenses in use: %n% / %max% (1 main and %e% exploration)", "Licences utilisées : %n% / %max% (1 principale et %e% d'exploration)"],
		"licenses.unlimited" => ["Licencias en uso: %n% (sin límite en creativo)", "Licenses in use: %n% (unlimited in creative)", "Licences utilisées : %n% (illimitées en créatif)"],
		"licenses.main" => ["Planeta principal: %name%", "Main planet: %name%", "Planète principale : %name%"],
		"licenses.nomain" => ["Aún no tienes planeta principal: lo será el primero que escanees.", "You have no main planet yet: the first planet you scan will be.", "Tu n'as pas encore de planète principale : ce sera la première que tu scanneras."],
		"licenses.price.free" => ["El primer cambio de planeta principal es gratis; los siguientes cuestan %n% créditos, como mucho uno cada 24 h.", "Your first main planet change is free; later ones cost %n% credits, at most one every 24 h.", "Le premier changement de planète principale est offert ; les suivants coûtent %n% crédits, un toutes les 24 h au plus."],
		"licenses.price" => ["Cambiar de planeta principal cuesta %n% créditos, como mucho una vez cada 24 h.", "Changing your main planet costs %n% credits, at most once every 24 h.", "Changer de planète principale coûte %n% crédits, une fois toutes les 24 h au plus."],
		// %t% = 13h 05m
		"licenses.wait" => ["Podrás volver a cambiar de planeta principal dentro de %t%.", "You can change your main planet again in %t%.", "Tu pourras de nouveau changer de planète principale dans %t%."],
		"licenses.pick" => ["Elige otro de tus planetas para hacerlo principal:", "Pick another of your planets to make it your main one:", "Choisis une autre de tes planètes pour en faire la principale :"],
		"licenses.none" => ["No tienes ningún otro planeta con licencia.", "You have no other licensed planet.", "Tu n'as aucune autre planète sous licence."],
		"licenses.more" => ["... y %n% más", "... and %n% more", "... et %n% autres"],
		"licenses.ask" => ["¿Hacer de %name% tu planeta principal?", "Make %name% your main planet?", "Faire de %name% ta planète principale ?"],
		"licenses.ask.free" => ["La ESCorp te regala este primer cambio. Los siguientes costarán %n% créditos, y no podrás volver a cambiar hasta dentro de 24 h.", "ESCorp gives you this first change for free. Later ones will cost %n% credits, and you won't be able to change again for 24 h.", "L'ESCorp t'offre ce premier changement. Les suivants coûteront %n% crédits, et tu ne pourras plus changer avant 24 h."],
		"licenses.ask.paid" => ["La ESCorp te cobrará %n% créditos y no podrás volver a cambiar hasta dentro de 24 h.", "ESCorp will charge you %n% credits and you won't be able to change again for 24 h.", "L'ESCorp te prélèvera %n% crédits et tu ne pourras plus changer avant 24 h."],
		"licenses.nocredits" => ["Te faltan créditos: el cambio cuesta %n%.", "Not enough credits: the change costs %n%.", "Pas assez de crédits : le changement coûte %n%."],
		"licenses.notyours" => ["Ese planeta no puede ser tu planeta principal.", "That planet cannot be your main planet.", "Cette planète ne peut pas devenir ta planète principale."],
		"license.full" => ["No te queda ninguna licencia libre (%max%: 1 principal y %n% de exploración). Abandona uno de tus planetas para liberar una.", "You have no free license left (%max%: 1 main and %n% exploration). Abandon one of your planets to free one.", "Tu n'as plus de licence libre (%max% : 1 principale et %n% d'exploration). Abandonne une de tes planètes pour en libérer une."],
		"license.pilotmain" => ["Solo puedes pilotar la nave sobre tu planeta principal (%name%).", "You can only pilot the ship over your main planet (%name%).", "Tu ne peux piloter le vaisseau qu'au-dessus de ta planète principale (%name%)."],
		"license.keepmain" => ["No puedes abandonar tu planeta principal: elige antes otro desde el ordenador de a bordo.", "You cannot abandon your main planet: pick another one from the board computer first.", "Tu ne peux pas abandonner ta planète principale : choisis-en d'abord une autre depuis l'ordinateur de bord."],
		"abandon.ask" => ["¿Abandonar %name%?", "Abandon %name%?", "Abandonner %name% ?"],
		"abandon.warn" => ["Perderás su licencia y todo lo que hayas cambiado en él, y no podrás volver nunca.", "You will lose its license and everything you changed there, and you will never be able to go back.", "Tu perdras sa licence et tout ce que tu y as modifié, et tu ne pourras plus jamais y retourner."],
		"abandon.freed" => ["Planeta abandonado: licencia liberada.", "Planet abandoned: license freed.", "Planète abandonnée : licence libérée."],
		"abandon.gone" => ["Has abandonado todos los planetas de este sistema: va a desaparecer del mapa y aparecerá otro sistema no muy lejos.", "You have abandoned every planet in this system: it will vanish from the map, and a new system will appear not far away.", "Tu as abandonné toutes les planètes de ce système : il va disparaître de la carte, et un nouveau système apparaîtra non loin."],
	];

	public static function t( key : String ) : String {
		var a = T.get(key);
		if( a == null ) return key;
		return a[cur];
	}

	public static function setCode( code : String ) {
		var i = CODES.indexOf(code);
		cur = i < 0 ? 0 : i;
		// nombres de los bloques: el original los elegia al compilar (lang_en/lang_fr); aqui siguen al idioma elegido
		Names.NAMES = BlockNames.table(cur);
	}

	public static function code() : String return CODES[cur];

	/** 1h 05m / 12m 30s */
	public static function duration( secs : Float ) : String {
		var s = Std.int(secs);
		var h = Std.int(s / 3600), m = Std.int((s % 3600) / 60);
		if( h > 0 ) return h + "h " + StringTools.lpad("" + m, "0", 2) + "m";
		return m + "m " + StringTools.lpad("" + (s % 60), "0", 2) + "s";
	}

	public static function date( ms : Float ) : String {
		var d = Date.fromTime(ms);
		var p = function(n : Int) return StringTools.lpad("" + n, "0", 2);
		return p(d.getDate()) + "/" + p(d.getMonth() + 1) + "/" + d.getFullYear() + " " + p(d.getHours()) + ":" + p(d.getMinutes());
	}
}
