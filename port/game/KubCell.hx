import Ui;
import Kubindex.KubState;
import IconMesh.Icons;

/**
 * Casilla de una ficha en las rejillas de la Base de datos ESCorp: el icono normal (recuperado), oscurecido (localizado) o una
 * sombra negra con "?" (desconocido); arriba a la derecha, la marca de lo nuevo (KubDraw.fresh) si es nueva. Elegida: marco naranja.
 */
class KubCell extends h2d.Object {

	public static inline var SIZE = 64;

	public var block(default, null) : Block;
	public var st(default, null) : KubState;
	public var onOver : KubCell -> Void;
	public var onOut : KubCell -> Void;
	public var onClick : KubCell -> Void;
	/** la casilla esta en una zona desplazable: solo responde si el raton esta en su parte visible */
	public var box : KubScroll;
	var bg : h2d.Graphics;
	var dot : h2d.Bitmap;
	var selected = false;
	var over = false;

	public function new( parent : h2d.Object, e : Block, st : KubState, fresh : Bool, atlas : h3d.mat.Texture ) {
		super(parent);
		block = e;
		this.st = st;
		bg = new h2d.Graphics(this);
		KubDraw.icon(this, e, st, SIZE - 12, atlas).setPosition(6, 6);
		if( st == Unknown ) Theme.center(Theme.text(this, "?", 2.2, Theme.DIM), SIZE, SIZE);
		if( fresh ) {
			// 16x16 centrada en (54, 10), en la esquina de arriba a la derecha
			dot = KubDraw.fresh(this);
			dot.setPosition(SIZE - 18, 2);
		}
		var it = new h2d.Interactive(SIZE, SIZE, this);
		it.onOver = function(_) {
			if( box != null && !box.mouseIn() ) return;
			over = true;
			paint();
			if( onOver != null ) onOver(this);
		};
		it.onOut = function(_) {
			over = false;
			paint();
			if( onOut != null ) onOut(this);
		};
		it.onClick = function(_) if( (box == null || box.mouseIn()) && onClick != null ) onClick(this);
		paint();
	}

	public function select( on : Bool ) {
		selected = on;
		// elegida = vista: ya no es nueva
		if( on && dot != null ) dot.visible = false;
		paint();
	}

	function paint() {
		bg.clear();
		Theme.rect(bg, 1, 1, SIZE - 2, SIZE - 2, 0xFFFFFF, st == Unknown ? 0.1 : over ? 0.16 : 0.06);
		if( selected ) {
			Theme.rect(bg, 0, 0, SIZE, 3, Theme.ACCENT);
			Theme.rect(bg, 0, SIZE - 3, SIZE, 3, Theme.ACCENT);
			Theme.rect(bg, 0, 0, 3, SIZE, Theme.ACCENT);
			Theme.rect(bg, SIZE - 3, 0, 3, SIZE, Theme.ACCENT);
		}
	}
}
