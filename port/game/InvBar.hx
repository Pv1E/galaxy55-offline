import Common;
import Ui;
import IconMesh.Icons;

/**
 * Barra de inventario de arriba al centro, como en el original (Interface.hx / InterfInvent.hx):
 * casillas de 40 px cada 44, la primera es el excavador; el resto, bloques con su icono 3D y la cantidad debajo.
 * La casilla elegida se resalta; las cargas van a la izquierda (16 px por fila).
 * Anadido del port, en el tutorial: la carga que se acaba de recoger late y se dice al lado ("+3 charges de Citronox"); con
 * iconos de 16 px el jugador no veia que las tenia. La carga que falta al minar va en los avisos (KubNotify.missingCharge).
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
	/** el tutorial esta en marcha (GalaxyApp): las cargas que suben se resaltan */
	public var tutorial = false;
	/** cargas del ultimo refresh (color -> cantidad); null hasta el primero, que no resalta nada */
	var chargeSnap : Map<Int, Int>;
	/** icono de cada carga del ultimo refresh, por color (update lo hace latir) */
	var chargeBms = new Map<Int, h2d.Bitmap>();
	/** x del icono de las cargas: el aviso va a su izquierda, pasada la cantidad */
	var chargesX = 0.;
	/** halo detras de la carga que late */
	var glow = new h2d.Graphics();
	var flashCharge = -1;
	var flashGain = 0;
	var flashTime = 0.;
	var pulseTime = 0.;
	/** aviso junto a las cargas (icono y texto): lo recogido en el tutorial */
	var notice = new h2d.Object();
	var noticeKey : String;
	var noticeTime = 0.;
	static inline var FLASH_TIME = 3.;

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
		addChild(glow);
		chargeBms = new Map();
		chargesX = x0 - 20;
		for( i in 0...cs.length ) {
			var c = cs[i];
			// el icono centrado en su casilla de 16 px, para que lata desde el centro
			var bm = new h2d.Bitmap(chargeIcons.sub(c.c * 16, 0, 16, 16, -8, -8), this);
			bm.x = x0 - 20 + 8;
			bm.y = 5 + i * 16 + 8;
			chargeBms.set(c.c, bm);
			var tf = Theme.text(this, "" + c.n, 1.0, c.c >= 0 && c.c < 4 ? CHARGE_COLORS[c.c] : 0xFFFFFF);
			tf.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 1 };
			tf.x = Std.int(x0 - 20 - tf.textWidth - 3);
			tf.y = 5 + i * 16 + 2;
		}
		if( chargeSnap != null && tutorial )
			for( c in cs ) {
				var before = chargeSnap.exists(c.c) ? chargeSnap.get(c.c) : 0;
				if( c.n > before ) gainedCharge(c.c, c.n - before);
			}
		chargeSnap = [for( c in cs ) c.c => c.n];
		addChild(notice);
	}

	static inline function chargeColor( c : Int ) return c >= 0 && c < 4 ? CHARGE_COLORS[c] : 0xFFFFFF;

	static function chargeName( c : Int ) return Type.getEnumConstructs(ChargeKind)[c];

	/** tutorial: la carga c ha subido n; lo seguido en la misma carga se suma ("+1", luego "+2"...) */
	function gainedCharge( c : Int, n : Int ) {
		flashGain = flashCharge == c && flashTime > 0 ? flashGain + n : n;
		if( flashCharge != c ) pulseTime = 0;
		flashCharge = c;
		flashTime = FLASH_TIME;
		var msg = Lang.t((flashGain == 1 ? "charge.got." : "charges.got.") + chargeName(c)).split("%n%").join("" + flashGain);
		showNotice("got" + c + ":" + flashGain, c, msg, 1.5, FLASH_TIME);
	}

	/** el aviso a la izquierda de las cargas: el texto (en su color, alineado a la derecha) y el icono de la carga */
	function showNotice( key : String, c : Int, msg : String, scale : Float, time : Float ) {
		notice.removeChildren();
		noticeKey = key;
		noticeTime = time;
		notice.alpha = 1;
		notice.visible = true;
		// fondo oscuro: el texto va en el color de la carga y el amarillo no se leia sobre el cielo de Terres Rouges
		var bg = new h2d.Graphics(notice);
		var ic = new h2d.Bitmap(chargeIcons.sub(c * 16, 0, 16, 16), notice);
		ic.setScale(1.5);
		ic.x = Std.int(chargesX - 34 - 24);
		ic.y = 6;
		var tf = Theme.text(notice, msg, scale, chargeColor(c));
		tf.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 1 };
		// lo que quepa entre el borde y el icono (a 1280 de ancho, unos 300 px); si no, en dos lineas, centrado en el icono
		var room = Math.min(ic.x - 8 - 12, 420);
		tf.maxWidth = room / tf.scaleX;
		tf.textAlign = Right;
		tf.x = Std.int(ic.x - 8 - room);
		tf.y = Std.int(Math.max(2, 6 + 12 - tf.textHeight * tf.scaleY * 0.5));
		var left = ic.x - 8 - tf.textWidth * tf.scaleX, top = Math.min(tf.y, ic.y), bottom = Math.max(tf.y + tf.textHeight * tf.scaleY, ic.y + 24);
		Theme.rect(bg, left - 8, top - 3, ic.x + 24 + 6 - (left - 8), bottom - top + 6, 0x000000, 0.5);
	}

	/** lo que dice el aviso de las cargas, para las pruebas (Dev): null si no se ve */
	public function devNotice() : String {
		if( noticeTime <= 0 ) return null;
		for( c in notice ) if( Std.isOfType(c, h2d.Text) ) return noticeKey + " \"" + cast(c, h2d.Text).text + "\"";
		return noticeKey;
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
		if( flashTime > 0 ) {
			flashTime -= dt;
			pulseTime += dt;
			var bm = chargeBms.get(flashCharge);
			var fade = Math.max(0, Math.min(1, flashTime / 0.6));
			var k = Math.abs(Math.sin(pulseTime * 5)) * fade;
			glow.clear();
			if( bm != null ) bm.setScale(1 + 1.1 * k);
			// al acabar, el icono vuelve a su tamano y el halo se borra
			if( bm != null && flashTime > 0 ) {
				glow.beginFill(chargeColor(flashCharge), (0.15 + 0.35 * k) * fade);
				glow.drawCircle(bm.x, bm.y, 9 + 9 * k);
				glow.endFill();
			}
		}
		if( noticeTime > 0 ) {
			noticeTime -= dt;
			notice.alpha = Math.max(0, Math.min(1, noticeTime / 0.5));
			notice.visible = noticeTime > 0;
		}
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
