import Common;

/** Iconos de las mejoras de la ESCorp (EscorpUpgrades, port/core: las reglas, sin nada de Heaps). */
class EscorpIcons {

	/** icono de 16 px de la hexalita, el de la barra del inventario (InvBar) */
	public static function hexalite() : h2d.Tile {
		var icons = hxd.res.Any.fromBytes("icons.png", Res.bytes("icons.png")).toTile();
		return icons.sub(Type.enumIndex(CBonus) * 16, 0, 16, 16);
	}
}
