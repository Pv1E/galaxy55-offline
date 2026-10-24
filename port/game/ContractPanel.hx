import Common;
import Ui;
import SaveData.SaveInfo;
import IconMesh.Icons;

/**
 * Contratos de la ESCorp (anadido del port, ver Contracts): una linea por contrato con el bloque, lo que llevas de lo que
 * piden, la recompensa y el boton de entregar. Arriba, el tiempo que falta para el tablero siguiente; al cumplirse, el
 * panel se rehace solo.
 */
class ContractPanel extends h2d.Object {

	public var onClose : Void -> Void;

	static inline var PW = 800;
	static inline var PH = 470;
	static inline var ROW = 92;
	static inline var BTN_W = 170;
	static inline var BTN_H = 44;

	var atlas : h3d.mat.Texture;
	var info : SaveInfo;
	var inv : Inv;
	var slot : Int;
	var px : Float;
	var py : Float;
	var rows : h2d.Object;
	var creditsText : h2d.Text;
	var timerText : h2d.Text;
	/** linea elegida con el mando o las flechas (-1 = solo raton) */
	var focus = -1;
	var focusG : h2d.Graphics;

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture, info : SaveInfo, inv : Inv ) {
		super(parent);
		this.atlas = atlas;
		this.info = info;
		this.inv = inv;

		px = (Theme.W - PW) * 0.5;
		py = (Theme.H - PH) * 0.5;
		var bg = new h2d.Graphics(this);
		Theme.fullRect(bg, 0x000000, 0.55);
		Theme.rect(bg, px, py, PW, PH, Theme.PANEL, 0.96);
		Theme.rect(bg, px, py, PW, 4, Theme.ACCENT);
		Theme.text(this, Lang.t("contracts.title"), 2.6, Theme.TEXT, px + 24, py + 20);
		creditsText = Theme.text(this, "", 2.4, Theme.ACCENT, px + PW - 300, py + 22);
		timerText = Theme.text(this, "", 1.8, Theme.CYAN, px + 24, py + 70);
		rows = new h2d.Object(this);
		rows.x = px + 24;
		rows.y = py + 108;
		focusG = new h2d.Graphics(this);
		var close = new h2d.Interactive(160, 36, this);
		close.x = px + PW - 184;
		close.y = py + PH - 52;
		var cg = new h2d.Graphics(close);
		Theme.rect(cg, 0, 0, 160, 36, 0xFFFFFF, 0.08);
		Theme.center(Theme.text(close, Lang.t("shop.close"), 1.8, Theme.TEXT), 160, 36);
		close.onClick = function(_) if( onClose != null ) onClose();
		refresh();
	}

	function refresh() {
		slot = Contracts.slot();
		creditsText.text = Lang.t("shop.credits") + " " + (info.credits == null ? Market.START_CREDITS : info.credits);
		rows.removeChildren();
		var board = Contracts.board(slot);
		for( i in 0...board.length ) row(i, board[i]);
		updateTimer();
		drawFocus();
	}

	function row( i : Int, c : Contracts.Contract ) {
		var r = new h2d.Object(rows);
		r.y = i * ROW;
		var w = PW - 48;
		var g = new h2d.Graphics(r);
		Theme.rect(g, 0, 0, w, ROW - 10, 0xFFFFFF, 0.06);
		var done = Contracts.isDone(info, i);
		var have = Contracts.have(inv, c.block);
		var bm = new h2d.Bitmap(Icons.get(c.block, atlas), r);
		bm.setScale(64 / Icons.SIZE);
		bm.x = 10;
		bm.y = 9;
		if( done ) bm.alpha = 0.4;
		Theme.text(r, c.block.getName(), 1.9, done ? Theme.DIM : Theme.TEXT, 92, 12);
		Theme.text(r, (done ? c.n : Std.int(Math.min(have, c.n))) + " / " + c.n, 1.6, have >= c.n || done ? Theme.CYAN : Theme.DIM, 92, 46);
		Theme.text(r, Lang.t("contracts.reward").split("%n%").join("" + c.reward), 1.6, done ? Theme.DIM : Theme.ACCENT, 250, 46);
		var bx = w - BTN_W - 12, by = (ROW - 10 - BTN_H) * 0.5;
		var b = new h2d.Interactive(BTN_W, BTN_H, r);
		b.x = bx;
		b.y = by;
		var bg = new h2d.Graphics(b);
		var ok = !done && have >= c.n;
		Theme.rect(bg, 0, 0, BTN_W, BTN_H, ok ? Theme.ACCENT : 0xFFFFFF, ok ? 0.35 : 0.06);
		var label = Theme.text(b, Lang.t(done ? "contracts.done" : "contracts.deliver"), 1.8, ok ? Theme.TEXT : done ? Theme.CYAN : Theme.DISABLED);
		Theme.center(label, BTN_W, BTN_H);
		if( ok ) b.onClick = function(_) deliver(i) else b.cursor = Default;
	}

	/** entrega el contrato i si llevas todo lo que piden (Contracts.deliver) */
	public function deliver( i : Int ) : Bool {
		if( !Contracts.deliver(info, inv, i) ) return false;
		refresh();
		return true;
	}

	function updateTimer() {
		var s = Std.int(Math.ceil(Contracts.remaining()));
		var p = function(n : Int) return StringTools.lpad("" + n, "0", 2);
		timerText.text = Lang.t("contracts.renew").split("%t%").join(p(Std.int(s / 60)) + ":" + p(s % 60));
	}

	function drawFocus() {
		focusG.clear();
		if( focus < 0 ) return;
		var x = rows.x - 3, y = rows.y + focus * ROW - 3, w = PW - 42, h = ROW - 4;
		Theme.rect(focusG, x, y, w, 3, Theme.ACCENT);
		Theme.rect(focusG, x, y + h - 3, w, 3, Theme.ACCENT);
		Theme.rect(focusG, x, y, 3, h, Theme.ACCENT);
		Theme.rect(focusG, x + w - 3, y, 3, h, Theme.ACCENT);
	}

	/** teclado y mando: arriba/abajo eligen la linea, Intro/A entrega, Esc/B cierra. El tablero cambia solo al cumplirse el tiempo */
	public function update( dt : Float, pad : hxd.Pad ) {
		var K = hxd.Key;
		var dy = 0;
		if( K.isPressed(K.UP) ) dy = -1;
		if( K.isPressed(K.DOWN) ) dy = 1;
		var ok = K.isPressed(K.ENTER) || K.isPressed(K.NUMPAD_ENTER), back = K.isPressed(K.ESCAPE);
		if( pad != null ) {
			if( pad.isPressed(pad.config.dpadUp) ) dy = -1;
			if( pad.isPressed(pad.config.dpadDown) ) dy = 1;
			if( pad.isPressed(pad.config.A) ) ok = true;
			if( pad.isPressed(pad.config.B) ) back = true;
		}
		if( back ) {
			if( onClose != null ) onClose();
			return;
		}
		if( dy != 0 ) {
			focus = focus < 0 ? 0 : (focus + dy + Contracts.COUNT) % Contracts.COUNT;
			drawFocus();
		}
		if( ok && focus >= 0 ) deliver(focus);
		if( Contracts.slot() != slot ) refresh() else updateTimer();
	}
}
