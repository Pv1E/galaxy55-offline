import Common;

/**
 * Textos del tutorial (Tutorial) en español, inglés y francés, aparte de Lang para no alargarlo.
 * %bauxite%, %cit%, %eth%, %rock%, %alu% y %hull% son nombres de bloques en el idioma elegido; %gift% las cargas de la ESCorp y %credits% sus creditos.
 */
class TutoText {

	// clave => [es, en, fr]
	static var T : Map<String, Array<String>> = [
		"title" => ["TUTORIAL", "TUTORIAL", "TUTORIEL"],
		"space" => [
			"¡Alerta! El casco de la nave está perforado. Aterriza de emergencia en el planeta que indica la flecha verde.",
			"Alert! The ship's hull is breached. Make an emergency landing on the planet shown by the green arrow.",
			"Alerte ! La coque du vaisseau est percée. Pose-toi en urgence sur la planète indiquée par la flèche verte."],
		"badplanet" => [
			"Este planeta no sirve para nuestro aterrizaje de emergencia.",
			"This planet is not suitable for our emergency landing.",
			"Cette planète n'est pas adaptée à notre atterrissage d'urgence."],
		"noleave" => [
			"La nave está demasiado dañada para salir del sistema.",
			"The ship is too damaged to leave the system.",
			"Le vaisseau est trop endommagé pour quitter le système."],
		"notakeoff" => [
			"La nave está demasiado dañada para despegar: repara primero el casco.",
			"The ship is too damaged to take off: repair the hull first.",
			"Le vaisseau est trop endommagé pour décoller : répare d'abord la coque."],
		"exit" => [
			"Ya has aterrizado. Para bajar al planeta, sal del teletransportador (en verde) y vuelve a subirte.",
			"You have landed. To go down to the planet, step off the teleporter (in green), then step back on.",
			"Te voilà posé. Pour descendre sur la planète, quitte le téléporteur (en vert) puis remonte dessus."],
		"hull" => [
			"El techo de la nave tiene dos agujeros. Para taparlos necesitas %bauxite%. Se encuentra en la mayoría de los planetas, pero tu láser necesita cargas para extraerlo.",
			"The ship's roof has two holes. To fill them you need %bauxite%. It is found on most planets, but your laser needs charges to mine it.",
			"Le toit du vaisseau a deux trous. Pour les boucher, il te faut de la %bauxite%. On en trouve sur la plupart des planètes, mais ton laser a besoin de charges pour la miner."],
		"citronox" => [
			"Recoge %cit% (en verde): dan cargas amarillas, necesarias para picar %rock%.",
			"Pick up %cit% (in green): they give yellow charges, needed to mine %rock%.",
			"Ramasse des %cit% (en vert) : ils donnent des charges jaunes, nécessaires pour miner la %rock%."],
		"etherium" => [
			"Pica %eth% con tus cargas amarillas: el etherium da cargas azules, necesarias para extraer %bauxite%.",
			"Mine %eth% with your yellow charges: etherium gives blue charges, needed to mine %bauxite%.",
			"Mine des %eth% avec tes charges jaunes : l'etherium donne les charges bleues, nécessaires pour miner la %bauxite%."],
		"bauxite" => [
			"Extrae el %bauxite% (en verde) y recógelo.",
			"Mine the %bauxite% (in green) and pick it up.",
			"Mine la %bauxite% (en vert) et ramasse-la."],
		"return" => [
			"Vuelve a la nave: ponte en el rayo de luz.",
			"Go back to the ship: step into the light beam.",
			"Retourne au vaisseau : place-toi dans le rayon de lumière."],
		"alu" => [
			"Pon 1 %bauxite% en la zona del sintetizador (en verde), apunta al sintetizador con la mano vacía y haz clic para fabricar %alu%. Recoge lo que salga.",
			"Put 1 %bauxite% on the synthesis area (in green), then aim at the synthesizer with an empty hand and click to make %alu%. Pick up what comes out.",
			"Pose 1 %bauxite% sur la zone de synthèse (en vert), puis vise le synthétiseur main vide et clique pour fabriquer de l'%alu%. Ramasse ce qui en sort."],
		"plates" => [
			"Haz lo mismo con el %alu%: el sintetizador lo convierte en %hull%.",
			"Do the same with the %alu%: the synthesizer turns it into %hull%.",
			"Fais de même avec l'%alu% : le synthétiseur le transforme en %hull%."],
		"computer" => [
			"Activa el ordenador de a bordo (en verde) y elige \"Modificar la nave (hangar)\".",
			"Activate the on-board computer (in green) and choose \"Modify the ship (hangar)\".",
			"Active l'ordinateur de bord (en vert) et choisis \"Modifier le vaisseau (hangar)\"."],
		"hangar" => [
			"Apunta a la puerta de la nave y haz clic una vez para abrirla. Luego tapa los agujeros del techo (en verde) con tu %hull%: la nave tiene que ser estanca.",
			"Aim at the ship's door and click once to open it. Then fill the holes in the roof (in green) with your %hull%: the ship must be airtight.",
			"Vise la porte du vaisseau et clique une fois pour l'ouvrir. Bouche ensuite les trous du toit (en vert) avec ton %hull% : le vaisseau doit être étanche."],
		"hangarearly" => [
			"Primero necesitas %hull%: sal del hangar y usa el sintetizador.",
			"You need %hull% first: leave the hangar and use the synthesizer.",
			"Il te faut d'abord du %hull% : sors du hangar et utilise le synthétiseur."],
		"leave" => [
			"¡La nave es estanca! Sal del hangar por la salida grande o por el teletransportador de la nave.",
			"The ship is airtight! Leave the hangar through the big exit or the ship's teleporter.",
			"Le vaisseau est étanche ! Sors du hangar par la grande sortie ou par le téléporteur du vaisseau."],
		"done" => [
			"¡Bien hecho! La ESCorp te envía %gift% cargas azules, %gift% cargas amarillas y %credits% créditos. Ya puedes salir del sistema y explorar otros planetas, vender tus recursos al robot comerciante y cumplir los contratos de la ESCorp desde el ordenador de a bordo.",
			"Well done! ESCorp sends you %gift% blue charges, %gift% yellow charges and %credits% credits. You can now leave the system and explore other planets, sell your resources to the merchant robot and fulfil ESCorp contracts from the on-board computer.",
			"Bravo ! L'ESCorp t'envoie %gift% charges bleues, %gift% charges jaunes et %credits% crédits. Tu peux maintenant quitter le système et explorer d'autres planètes, vendre tes ressources au robot marchand et remplir les contrats de l'ESCorp depuis l'ordinateur de bord."],
		"nobreak" => [
			"No rompas nada en el hangar: solo tapa los agujeros.",
			"Don't break anything in the hangar: just fill the holes.",
			"Ne casse rien dans le hangar : bouche seulement les trous."],
		"onlyhull" => [
			"Este agujero se tapa con %hull%.",
			"This hole is filled with %hull%.",
			"Ce trou se bouche avec du %hull%."],
		"onlyholes" => [
			"Pon el %hull% solo en los agujeros del techo (en verde).",
			"Only put %hull% in the holes in the roof (in green).",
			"Pose le %hull% seulement dans les trous du toit (en vert)."],
		"skip" => ["Saltar el tutorial", "Skip the tutorial", "Passer le tutoriel"],
		"skip.ask" => ["¿Saltar el tutorial?", "Skip the tutorial?", "Passer le tutoriel ?"],
		"skip.warn" => [
			"Tu inventario, tu nave y el planeta volverán a su estado inicial.",
			"Your inventory, your ship and the planet will be reset.",
			"Ton inventaire, ton vaisseau et la planète seront réinitialisés."],
		"skipped" => [
			"Tutorial saltado: la ESCorp te envía %gift% cargas azules, %gift% amarillas y %credits% créditos.",
			"Tutorial skipped: ESCorp sends you %gift% blue and %gift% yellow charges and %credits% credits.",
			"Tutoriel passé : l'ESCorp t'envoie %gift% charges bleues, %gift% jaunes et %credits% crédits."],
	];

	static var NAMES = [
		"%bauxite%" => BMinAluminium, "%cit%" => BYellowCrystalLight, "%eth%" => BBlueCrystalLight,
		"%rock%" => BRock, "%alu%" => BAluminium, "%hull%" => BShipHull,
	];

	/** texto en el idioma elegido; con max >= 0 se le anade el recuento (n/max) */
	public static function get( key : String, n = 0, max = -1 ) : String {
		var a = T.get(key);
		var s = a == null ? key : a[Lang.cur];
		for( k => b in NAMES ) if( s.indexOf(k) >= 0 ) s = s.split(k).join(Block.get(b).getName());
		s = s.split("%gift%").join("" + TutoSetup.GIFT).split("%credits%").join("" + Market.START_CREDITS);
		return max >= 0 ? s + " (" + n + "/" + max + ")" : s;
	}
}
