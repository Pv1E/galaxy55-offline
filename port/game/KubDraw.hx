import Ui;
import Common;
import Kubindex.KubState;
import SaveData.SaveInfo;
import IconMesh.Icons;

/** Dibujos compartidos por las pestanas de la Base de datos ESCorp: iconos segun lo que se sabe y lineas de receta. */
class KubDraw {

	/** ancho y alto de un ingrediente (o del resultado) en una linea de receta */
	public static inline var ITEM_W = 140;
	public static inline var ITEM_H = 64;
	static inline var ARROW_W = 28;
	/** alto de una linea de receta (con la etiqueta del nivel encima) */
	public static inline var RECIPE_H = 82;

	/**
	 * icono de una ficha: normal (recuperada), oscurecido (localizada) o sombra negra (desconocida). Si el icono grande aun no
	 * esta hecho, la casilla queda vacia hasta que lo esta (Icons.bitmap)
	 */
	public static function icon( parent : h2d.Object, e : Block, st : KubState, size : Float, atlas : h3d.mat.Texture ) : h2d.Bitmap {
		var bm = Icons.bitmap(parent, e, size, atlas);
		switch( st ) {
			case Got:
			case Seen: bm.color.set(0.3, 0.3, 0.36, 1);
			case Unknown: bm.color.set(0, 0, 0, 0.92);
		}
		return bm;
	}

	static var freshTile : h2d.Tile;

	/**
	 * marca de lo nuevo en la Base de datos ESCorp, 16x16: recent.png de Mush (Motion Twin, CC BY-NC-SA 4.0, ver NOTICE),
	 * metida en el .hl (game.hxml, -resource) para no tener que copiarla con el juego
	 */
	public static function fresh( parent : h2d.Object ) : h2d.Bitmap {
		if( freshTile == null ) freshTile = hxd.res.Any.fromBytes("mush_recent.png", haxe.Resource.getBytes("mush_recent.png")).toTile();
		return new h2d.Bitmap(freshTile, parent);
	}

	/** nombre de una ficha, o "???" si no se conoce */
	public static function name( info : SaveInfo, e : Block ) : String {
		return Kubindex.known(info, e) ? e.getName() : KubText.get("kub.unknown");
	}

	/** recorta un texto para que no pase de maxW (con su escala) */
	public static function fit( t : h2d.Text, maxW : Float ) {
		if( t.calcTextWidth(t.text) * t.scaleX <= maxW ) return;
		var s = t.text;
		while( s.length > 1 && t.calcTextWidth(s + "...") * t.scaleX > maxW ) s = s.substr(0, s.length - 1);
		t.text = StringTools.rtrim(s) + "...";
	}

	/** color de cada carga (amarilla, azul, rosa, bonus verde) */
	public static function chargeColor( c : ChargeKind ) : Int {
		return switch( c ) {
			case CYellow: 0xFFD23F;
			case CBlue: 0x5AB4FF;
			case CPink: 0xFF7AD9;
			case CBonus: 0x7CE85A;
		}
	}

	/**
	 * Linea de una receta: sus niveles de abajo arriba (cada uno con su ficha, cuantos y la forma) y el resultado. Lo que no se
	 * conoce sale como sombra negra con "???" y donde encontrarlo. onPick: clic en una ficha conocida. Devuelve el ancho.
	 */
	public static function recipe( parent : h2d.Object, r : CraftRule, info : SaveInfo, atlas : h3d.mat.Texture, onPick : Block -> Void, ?box : KubScroll ) : Float {
		var x = 0.;
		var layered = r.schema.length > 1;
		for( i in 0...r.schema.length ) {
			var s = r.schema[i];
			var b = null, n = 1, shape = "";
			switch( s ) {
				case CSSingle(k): b = k;
				case CSBase(k, size): b = k; n = size * size; shape = KubText.get("rc.square").split("%n%").join("" + size);
				case CSLine(k, len): b = k; n = len; shape = KubText.get("rc.line").split("%n%").join("" + len);
			}
			if( layered ) Theme.text(parent, KubText.get("rc.layer").split("%n%").join("" + (i + 1)), 1.05, Theme.DIM, x + 2, 0);
			item(parent, Block.get(b), n, shape, info, atlas, x, 16, onPick, box);
			x += ITEM_W;
		}
		var g = new h2d.Graphics(parent);
		var ay = 16 + ITEM_H * 0.5;
		Theme.rect(g, x + 4, ay - 2, ARROW_W - 14, 4, Theme.ACCENT);
		g.beginFill(Theme.ACCENT);
		g.moveTo(x + ARROW_W - 10, ay - 8);
		g.lineTo(x + ARROW_W - 2, ay);
		g.lineTo(x + ARROW_W - 10, ay + 8);
		g.endFill();
		x += ARROW_W;
		item(parent, Block.get(r.out), r.count == null ? 1 : r.count, "", info, atlas, x, 16, onPick, box);
		return x + ITEM_W;
	}

	/** un ingrediente o el resultado (b: el bloque de la receta); las cargas se ven siempre, y se pinchan una vez recuperadas */
	static function item( parent : h2d.Object, b : Block, n : Int, shape : String, info : SaveInfo, atlas : h3d.mat.Texture, x : Float, y : Float,
			onPick : Block -> Void, box : KubScroll ) {
		var o = new h2d.Object(parent);
		o.setPosition(x, y);
		var g = new h2d.Graphics(o);
		var charge = b.charge != null;
		var e = charge ? b : KubData.get().entryOf(b);
		var st = e == null ? Unknown : charge ? Got : Kubindex.state(info, e);
		Theme.rect(g, 0, 0, ITEM_W - 6, ITEM_H, 0xFFFFFF, st == Unknown ? 0.09 : 0.05);
		if( e != null ) icon(o, e, st, 42, atlas).setPosition(4, 4);
		// cuantos, en la esquina del icono
		if( n > 1 ) {
			var c = Theme.text(o, "x" + n, 1.15, Theme.TEXT);
			c.setPosition(4, 44);
		}
		var tx = 52, tw = ITEM_W - 6 - tx - 4;
		var nm = Theme.text(o, e == null ? "-" : charge ? b.getName() : name(info, e), 1.15, st == Got ? Theme.TEXT : st == Seen ? Theme.DIM : Theme.DISABLED, tx, 4);
		// sin forma ni sitio debajo, el nombre puede ocupar dos lineas (cargas de citronox)
		if( shape == "" && st != Unknown ) nm.maxWidth = tw / nm.scaleX else fit(nm, tw);
		var ly = 22.;
		if( shape != "" ) {
			fit(Theme.text(o, shape, 1.05, Theme.DIM, tx, ly), tw);
			ly += 15;
		}
		if( st == Unknown && e != null ) fit(Theme.text(o, KubData.get().placeShort(info, e), 1.05, Theme.CYAN, tx, ly), tw);
		if( e != null && st != Unknown && (!charge || Kubindex.known(info, e)) && onPick != null ) {
			var it = new h2d.Interactive(ITEM_W - 6, ITEM_H, o);
			it.onClick = function(_) if( box == null || box.mouseIn() ) onPick(e);
		}
	}
}
