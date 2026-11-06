import Common;
import Ui;
import IconMesh.Icons;

/**
 * Barra de inventario de arriba al centro, como en el original (Interface.hx / InterfInvent.hx):
 * casillas de 40 px cada 44, la primera es el excavador; el resto, bloques con su icono 3D y la cantidad debajo.
 * La casilla elegida se resalta; las cargas van a la izquierda (16 px por fila).
 */
class InvBar extends h2d.Object {

	public static inline var STEP = 44;
	static var CHARGE_COLORS = [0xFFBF00, 0x7DC9F7, 0xE8B3FF, 0xFFFFFF];

	var inv : Inv;
	var atlas : h3d.mat.Texture;
	var digger : h2d.Tile;
	var chargeIcons : h2d.Tile;
	var width : Int;
	var snapshot = new Array<String>();
	var nameText : h2d.Text;
	var nameTime = 0.;
	var bump = -1;
	var bumpTime = 0.;
	var slotObjs = new Array<h2d.Object>();

	public function new( parent : h2d.Object, inv : Inv, atlas : h3d.mat.Texture, width : Int ) {
		super(parent);
		this.inv = inv;
		this.atlas = atlas;
		this.width = width;
		digger = hxd.res.Any.fromBytes("digger.png", Res.bytes("digger.png")).toTile();
		chargeIcons = hxd.res.Any.fromBytes("icons.png", Res.bytes("icons.png")).toTile();
		inv.onChange = refresh;
		refresh();
	}

	function stateOf() : Array<String> {
		return [for( s in inv.inv.t ) s == null ? "" : s.k + ":" + s.n];
	}

	public function refresh() {
		removeChildren();
		slotObjs = [];
		var n = inv.inv.t.length + 1;
		var x0 = (width - n * STEP) >> 1;
		var cur = stateOf();
		var changed = -1;
		for( i in 0...cur.length )
			if( i < snapshot.length && cur[i] != snapshot[i] && cur[i] != "" ) { changed = i + 1; break; }
		var first = snapshot.length == 0;
		snapshot = cur;

		for( i in 0...n ) {
			var slot = new h2d.Object(this);
			slot.x = x0 + i * STEP;
			slot.y = 5;
			slotObjs.push(slot);
			var bg = new h2d.Graphics(slot);
			var selected = i == inv.blockIndex;
			// rombo de fondo (InterfInvent.drawInvBase)
			bg.beginFill(selected ? 0xFFFFFF : 0x000000, selected ? 0.28 : 0.2);
			bg.moveTo(20, 20);
			bg.lineTo(40, 30);
			bg.lineTo(20, 40);
			bg.lineTo(0, 30);
			bg.endFill();
			if( selected ) {
				bg.lineStyle(1.5, 0xFFFFFF, 0.9);
				bg.moveTo(20, 20);
				bg.lineTo(40, 30);
				bg.lineTo(20, 40);
				bg.lineTo(0, 30);
				bg.lineTo(20, 20);
			}
			if( i == 0 ) {
				var bm = new h2d.Bitmap(digger, slot);
				bm.x = Std.int(20 - digger.width * 0.5);
				bm.y = Std.int(20 - digger.height * 0.5);
				continue;
			}
			var s = inv.inv.t[i - 1];
			if( s == null ) continue;
			var b = Block.all[s.k];
			// liso a cualquier tamano de ventana (el de 90 px, con el nearest de h2d, salia pixelado en una pequena); hecho ya, sin
			// casilla vacia ni un fotograma
			var bm = Icons.bitmap(slot, b, 45, atlas, true);
			// el icono (45 px) se centra sobre el rombo (40 px): el centro de la base del cubo cae en (20, 30)
			bm.x = -2.5;
			if( i == changed && !first ) { bump = i; bumpTime = 0.45; }
			var max = b.getMax(inv.inv.maxWeight);
			var tf = Theme.text(slot, "" + s.n, 1.0, s.n >= max ? 0xF08080 : 0xE0E0E0, 0, 32);
			tf.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 1 };
			tf.x = Std.int(20 - tf.textWidth * 0.5);
			if( i == changed && !first ) showName(b, slot.x + 20);
		}

		// cargas a la izquierda
		var cs = inv.inv.charges.copy();
		cs.sort(function(a, b) return a.c - b.c);
		for( i in 0...cs.length ) {
			var c = cs[i];
			var bm = new h2d.Bitmap(chargeIcons.sub(c.c * 16, 0, 16, 16), this);
			bm.x = x0 - 20;
			bm.y = 5 + i * 16;
			var tf = Theme.text(this, "" + c.n, 1.0, c.c >= 0 && c.c < 4 ? CHARGE_COLORS[c.c] : 0xFFFFFF);
			tf.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 1 };
			tf.x = Std.int(x0 - 20 - tf.textWidth - 3);
			tf.y = 5 + i * 16 + 2;
		}
	}

	/** nombre del bloque bajo la casilla, que se desvanece (InterfInvent.bumpBlock) */
	function showName( b : Block, cx : Float ) {
		if( nameText != null ) nameText.remove();
		nameText = Theme.text(this, b.getName(), 1.1, 0xE0E0E0);
		nameText.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 1 };
		nameText.x = Std.int(cx - nameText.textWidth * 0.55);
		nameText.y = 5 + 46;
		nameTime = 2.0;
	}

	public function update( dt : Float ) {
		if( bumpTime > 0 && bump >= 0 && bump < slotObjs.length ) {
			bumpTime -= dt;
			var k = Math.max(0, bumpTime / 0.45);
			slotObjs[bump].y = 5 + 10 * k * k;
		}
		if( nameText != null ) {
			nameTime -= dt;
			if( nameTime < 0.5 ) nameText.alpha = Math.max(0, nameTime / 0.5);
			if( nameTime <= 0 ) {
				nameText.remove();
				nameText = null;
			}
		}
	}
}
