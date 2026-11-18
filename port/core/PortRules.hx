import Common;

/**
 * Cambios del port a las reglas de los bloques del original (src/G55/com/Block.hx no se toca).
 * Se aplican una vez al arrancar.
 */
@:access(Block)
class PortRules {

	/**
	 * Hierbas de decoracion y estalactitas de hielo: en el original llevan BFDetail y no se pueden apuntar ni romper.
	 * Aqui se rompen y dan, con una probabilidad:
	 * - hierbas -> la misma hierba un 33 %, como las plantas recogibles (BAcidHerb*: BFDropChance(33)). Antes daban hierba alta
	 *   (BHighHerb1), que no se parece a ninguna (la hierba helada daba una hierba verde). Para ponerlas se apoyan en el suelo y no
	 *   sujetan nada, como las flores (BFAnchor(Down), BFMagnet(None)); la de los arboles cuelga;
	 * - estalactitas de hielo -> hielo (BIce) un 7 %, como el hielo negro (BBlackIce: matter BIce, BFDropChance(7));
	 * - restos de las plantas de cargas -> nada (para no sacar cargas sin fin).
	 * Siguen sin chocar y conservan BFDetail (se dibujan igual): solo cambia que se pueden apuntar (PCanPick) y lo que dan.
	 */
	static var BREAKABLE : Array<{ k : BlockKind, drop : BlockKind, chance : Int }> = [
		{ k : BAutumnHerbs1, drop : BAutumnHerbs1, chance : 33 },
		{ k : BAutumnHerbs2, drop : BAutumnHerbs2, chance : 33 },
		{ k : BTreeHerbs, drop : BTreeHerbs, chance : 33 },
		{ k : BMoonHerbs1, drop : BMoonHerbs1, chance : 33 },
		{ k : BMoonHerbs2, drop : BMoonHerbs2, chance : 33 },
		{ k : BWinterHerb1, drop : BWinterHerb1, chance : 33 },
		{ k : BWinterHerb2, drop : BWinterHerb2, chance : 33 },
		{ k : BWinterHerb3, drop : BWinterHerb3, chance : 33 },
		{ k : BMarsHerb1, drop : BMarsHerb1, chance : 33 },
		{ k : BMarsHerb2, drop : BMarsHerb2, chance : 33 },
		{ k : BMarsHerb3, drop : BMarsHerb3, chance : 33 },
		{ k : BIceStalactite1, drop : BIce, chance : 7 },
		{ k : BIceStalactite2, drop : BIce, chance : 7 },
		{ k : BBonusHerb1, drop : null, chance : 0 },
		{ k : BBonusHerb2, drop : null, chance : 0 },
		{ k : BBonusMediumRemain, drop : null, chance : 0 },
	];

	/**
	 * Hierba alta y sbelelebs: en el original no llevan BFDetail y, sin iman, no sostienen nada. Apuntando a ellas con un bloque en
	 * la mano no se podia poner: la sombra salia encima de la hierba y el clic no ponia nada. Aqui se pisan al poner, como las
	 * hierbas (Block.canOverride), y sueltan lo que darian al romperlas.
	 */
	static var PLACE_OVER = [BHighHerb1, BHighHerb2, BHighHerb3, BHighHerb4, BHighHerb5, BHighHerb6];
	static var placeOverIdx = new Map<Int, Bool>();

	public static inline function placeOver( b : Block ) : Bool {
		return placeOverIdx.exists(b.index);
	}

	/** radio del turbo minero (BFTrack): cambio del port, 5 en el original */
	static inline var TURBO_RADIUS = 15;

	static var done = false;

	public static function apply() {
		if( done ) return;
		done = true;
		// el monticulo de nieve con una planta escondida (BWinterHidden) brillaba con luz propia y sombreado 1.5-2.0: con su
		// textura casi blanca saturaba a blanco puro. Se dibuja como la nieve normal (BWinterSoilCover) y sin luz propia.
		var hidden = Block.get(BWinterHidden), snow = Block.get(BWinterSoilCover);
		hidden.shadeX = snow.shadeX;
		hidden.shadeY = snow.shadeY;
		hidden.shadeUp = snow.shadeUp;
		hidden.shadeDown = snow.shadeDown;
		hidden.special = null;
		// en el original algunos bloques llevan BFNoDrop y desaparecen al romperlos (turbo minero, tornillos, lampara de
		// minero...). El hielo sigue sin soltar nada, como en el original. Aqui se pueden comprar y fabricar, asi que al romperlos se recuperan.
		for( k in [BMiningGenerator, BWoodScrew, BIronLight, BFreezer, BFrozenRock, BStainEmpty] ) {
			var b = Block.get(k);
			b.drop = b;
			b.dropCount = 1;
		}
		// cambio del port: el turbo minero da potencia 3 a menos de 15 bloques (en el original, BFTrack(TMiningSpeed, 5))
		var turbo = Block.get(BMiningGenerator);
		for( i in 0...turbo.flags.length )
			switch( turbo.flags[i] ) {
			case BFTrack(t, _): turbo.flags[i] = BFTrack(t, TURBO_RADIUS);
			default:
			}
		for( k in PLACE_OVER ) placeOverIdx.set(Block.get(k).index, true);
		for( r in BREAKABLE ) {
			var b = Block.get(r.k);
			b.props.set(PCanPick);
			if( r.drop == null ) {
				b.drop = null;
			} else {
				b.drop = Block.get(r.drop);
				b.dropCount = 1;
				b.flags.push(BFDropChance(r.chance));
			}
			if( r.drop == r.k ) {
				b.anchors = Type.enumIndex(r.k == BTreeHerbs ? Up : Down);
				b.magnets = 0;
			}
		}
	}
}
