import Common;
import Ui;
import SaveData.SaveInfo;
import IconMesh.Icons;
import Contracts.ActiveContract;

/** Lo que hace un boton del panel: entregar una linea del tablero, dar bloques a un contrato en curso o abandonarlo. */
private enum ContractAction {
	Deliver( i : Int );
	Give( a : ActiveContract );
	Abandon( a : ActiveContract );
	/** dar tierra roja al contrato especial */
	Special;
}

/**
 * Contratos de la ESCorp (anadido del port, ver Contracts): una linea por contrato con el bloque, lo que llevas de lo que
 * piden, la recompensa y el boton de entregar (o de dar los bloques que haya, y el contrato queda en curso). Arriba van los
 * contratos en curso, con dos botones: dar lo que llevas y abandonar (con confirmacion, onAbandon). Encima, el tiempo que
 * falta para el tablero siguiente; al cumplirse, el panel se rehace solo. Debajo del tablero, el contrato especial (sin plazo,
 * una vez por partida), con su rotulo y en dorado; tras cobrarlo sigue en el panel como Entregado hasta cerrarlo.
 */
class ContractPanel extends h2d.Object {

	public var onClose : Void -> Void;
	/** boton Abandonar de un contrato en curso: GalaxyApp pide confirmacion y llama a abandon */
	public var onAbandon : ActiveContract -> Void;
	/** mientras se pide la confirmacion: el panel no hace caso del teclado, del mando ni de los clics */
	public var paused = false;

	static inline var PW = 800;
	static inline var ROW = 92;
	static inline var BTN_W = 170;
	static inline var BTN_H = 44;
	/** botones apilados de los contratos en curso */
	static inline var BTN2_H = 36;
	/** rotulo del contrato especial, entre el tablero y su linea */
	static inline var HEAD = 34;

	var atlas : h3d.mat.Texture;
	var info : SaveInfo;
	var inv : Inv;
	var slot : Int;
	/** lineas del panel: contratos en curso y luego los del tablero que se ofrecen (el especial va aparte) */
	var count = -1;
	/** el contrato especial sale en el panel: sin cumplir al abrirlo */
	var special : Bool;
	var px : Float;
	var py : Float;
	var bg : h2d.Graphics;
	var title : h2d.Text;
	var rows : h2d.Object;
	var creditsText : h2d.Text;
	var timerText : h2d.Text;
	var close : h2d.Interactive;
	/** botones que se eligen con el mando o las flechas, en orden: su linea (y su altura en el panel), su sitio y lo que hacen */
	var items : Array<{ row : Int, ry : Float, x : Float, y : Float, w : Float, h : Float, action : ContractAction }> = [];
	/** boton elegido con el mando o las flechas (-1 = solo raton) */
	var focus = -1;
	var focusG : h2d.Graphics;
	/** Abandonar pulsado: la confirmacion se abre en la siguiente actualizacion, para que la misma pulsacion de Intro o A no
	    conteste tambien a la ventana */
	var pendingAbandon : ActiveContract;

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture, info : SaveInfo, inv : Inv ) {
		super(parent);
		this.atlas = atlas;
		this.info = info;
		this.inv = inv;
		special = !Contracts.specialDone(info);
		px = (Theme.W - PW) * 0.5;
		bg = new h2d.Graphics(this);
		title = Theme.text(this, Lang.t("contracts.title"), 2.6, Theme.TEXT);
		creditsText = Theme.text(this, "", 2.4, Theme.ACCENT);
		timerText = Theme.text(this, "", 1.8, Theme.CYAN);
		rows = new h2d.Object(this);
		focusG = new h2d.Graphics(this);
		close = new h2d.Interactive(160, 36, this);
		var cg = new h2d.Graphics(close);
		Theme.rect(cg, 0, 0, 160, 36, 0xFFFFFF, 0.08);
		Theme.center(Theme.text(close, Lang.t("shop.close"), 1.8, Theme.TEXT), 160, 36);
		close.onClick = function(_) if( !paused && onClose != null ) onClose();
		refresh();
	}

	/** alto segun el numero de lineas del tablero (470 con 3), mas el contrato especial con su rotulo (596 con 3) */
	function layout( n : Int ) {
		var PH = 194 + Std.int(Math.max(ROW, n * ROW + (special ? HEAD + ROW : 0)));
		py = (Theme.H - PH) * 0.5;
		bg.clear();
		Theme.fullRect(bg, 0x000000, 0.55);
		Theme.rect(bg, px, py, PW, PH, Theme.PANEL, 0.96);
		Theme.rect(bg, px, py, PW, 4, Theme.ACCENT);
		title.setPosition(px + 24, py + 20);
		creditsText.setPosition(px + PW - 300, py + 22);
		timerText.setPosition(px + 24, py + 70);
		rows.setPosition(px + 24, py + 108);
		close.setPosition(px + PW - 184, py + PH - 52);
	}

	function refresh() {
		slot = Contracts.slot();
		creditsText.text = Lang.t("shop.credits") + " " + (info.credits == null ? Market.START_CREDITS : info.credits);
		rows.removeChildren();
		items = [];
		var active = Contracts.active(info).copy(), offered = Contracts.offered(info), board = Contracts.board(slot);
		var n = active.length + offered.length;
		if( n != count ) layout(n);
		count = n;
		for( k in 0...active.length ) activeRow(k, active[k]);
		for( k in 0...offered.length ) boardRow(active.length + k, offered[k], board[offered[k]]);
		if( special ) specialRow(n);
		if( focus >= items.length ) focus = items.length - 1;
		updateTimer();
		drawFocus();
	}

	/** altura de la linea r en el panel: la del contrato especial (r = count) va debajo de su rotulo */
	function rowY( r : Int ) : Float return r * ROW + (r >= count ? HEAD : 0);

	/** fondo, icono, nombre (con la etiqueta tag detras, si la hay), cantidad y recompensa (en creditos si no se da) de una linea */
	function rowBase( r : Int, c : Contracts.Contract, dim : Bool, tint : Int, progress : String, progressCol : Int, ?tag : String, ?reward : String ) : h2d.Object {
		var o = new h2d.Object(rows);
		o.y = rowY(r);
		var g = new h2d.Graphics(o);
		Theme.rect(g, 0, 0, PW - 48, ROW - 10, tint, tint == 0xFFFFFF ? 0.06 : 0.1);
		var bm = Icons.bitmap(o, c.block, 64, atlas);
		bm.x = 10;
		bm.y = 9;
		if( dim ) bm.alpha = 0.4;
		var name = Theme.text(o, c.block.getName(), 1.9, dim ? Theme.DIM : Theme.TEXT, 92, 12);
		if( tag != null ) Theme.text(o, tag, 1.4, tint, 92 + name.textWidth * name.scaleX + 16, 17);
		Theme.text(o, progress, 1.6, progressCol, 92, 46);
		if( reward == null ) reward = Lang.t("contracts.reward").split("%n%").join("" + c.reward);
		var rt = Theme.text(o, reward, 1.6, dim ? Theme.DIM : Theme.ACCENT, 250, 46);
		// una recompensa larga (la del contrato especial en frances) se corre a la izquierda para no llegar al boton
		var room = PW - 48 - BTN_W - 24 - rt.textWidth * rt.scaleX;
		if( rt.x > room ) rt.x = Math.max(170, room);
		return o;
	}

	/** boton de una linea: activo (de color col) o apagado; lo que hace va a la lista del mando */
	function button( o : h2d.Object, r : Int, x : Float, y : Float, w : Int, h : Int, text : String, ok : Bool, col : Int, action : ContractAction, textCol = -1 ) {
		var b = new h2d.Interactive(w, h, o);
		b.setPosition(x, y);
		var g = new h2d.Graphics(b);
		Theme.rect(g, 0, 0, w, h, ok ? col : 0xFFFFFF, ok ? 0.35 : 0.06);
		var t = Theme.text(b, text, h < BTN_H ? 1.6 : 1.8, textCol >= 0 ? textCol : ok ? Theme.TEXT : Theme.DISABLED);
		// un texto largo ("Inventaire plein") se achica hasta caber en el boton
		if( t.textWidth * t.scaleX > w - 16 ) t.setScale((w - 16) / t.textWidth);
		Theme.center(t, w, h);
		if( ok )
			b.onClick = function(_) {
				if( !paused ) run(action);
			}
		else
			b.cursor = Default;
		if( action != null ) items.push({ row : r, ry : o.y, x : x, y : o.y + y, w : w, h : h, action : action });
	}

	/** linea i del tablero: entregar con todos los bloques, dar los que haya con parte, o entregada / abandonada */
	function boardRow( r : Int, i : Int, c : Contracts.Contract ) {
		var done = Contracts.isDone(info, i), dropped = Contracts.isAbandoned(info, i);
		var have = Contracts.have(inv, c.block), give = Contracts.canDeliver(info, inv, i);
		var blocked = done || dropped;
		var o = rowBase(r, c, blocked, 0xFFFFFF, (done ? c.n : Std.int(Math.min(have, c.n))) + " / " + c.n, have >= c.n || done ? Theme.CYAN : Theme.DIM);
		var x = PW - 48 - BTN_W - 12, y = (ROW - 10 - BTN_H) * 0.5;
		if( blocked )
			button(o, r, x, y, BTN_W, BTN_H, Lang.t(done ? "contracts.done" : "contracts.abandoned"), false, 0, Deliver(i), done ? Theme.CYAN : Theme.DIM);
		else if( give > 0 && give < c.n )
			button(o, r, x, y, BTN_W, BTN_H, giveLabel(give), true, Theme.CYAN, Deliver(i));
		else
			button(o, r, x, y, BTN_W, BTN_H, Lang.t("contracts.deliver"), give > 0, Theme.ACCENT, Deliver(i));
	}

	/** contrato en curso: lo dado de lo que piden y dos botones apilados, dar lo que llevas y abandonar */
	function activeRow( r : Int, a : ActiveContract ) {
		var c = Contracts.contractOf(a), give = Contracts.canGive(inv, a);
		var o = rowBase(r, c, false, Theme.CYAN, a.given + " / " + a.n, Theme.CYAN, Lang.t("contracts.active"));
		var x = PW - 48 - BTN_W - 12, gap = ROW - 10 - 2 * BTN2_H;
		button(o, r, x, gap / 3, BTN_W, BTN2_H, giveLabel(give), give > 0, a.given + give >= a.n ? Theme.ACCENT : Theme.CYAN, Give(a));
		button(o, r, x, gap / 3 * 2 + BTN2_H, BTN_W, BTN2_H, Lang.t("contracts.abandon"), true, Theme.DANGER, Abandon(a));
	}

	/**
	 * contrato especial (Contracts.giveSpecial), debajo del tablero: rotulo, fondo y marco dorados y la etiqueta Especial. Sin
	 * plazo y sin abandonar: entregar con lo que falta, dar los que haya con parte (como un contrato en curso), inventario lleno
	 * si con el ultimo bloque no cabe el conteneur, o entregado (hasta cerrar el panel)
	 */
	function specialRow( r : Int ) {
		var soil = Contracts.specialBlock(), N = Contracts.SPECIAL_N;
		var done = Contracts.specialDone(info), given = Contracts.specialGiven(info), give = Contracts.canGiveSpecial(info, inv);
		var have = Contracts.have(inv, soil);
		Theme.text(rows, Lang.t("contracts.special"), 1.6, Theme.ACCENT, 0, rowY(r) - HEAD + 6);
		var progress = done ? N : given > 0 ? given : Std.int(Math.min(have, N));
		var c : Contracts.Contract = { block : soil, n : N, reward : 0 };
		var reward = Lang.t("contracts.special.reward").split("%name%").join(Contracts.specialReward().getName());
		var o = rowBase(r, c, done, Theme.ACCENT, progress + " / " + N, done || given > 0 || given + give >= N ? Theme.CYAN : Theme.DIM,
			Lang.t("contracts.special.tag"), reward);
		// marco dorado: se distingue de las lineas del tablero (blancas) y de las en curso (azules)
		var g = new h2d.Graphics(o);
		var w = PW - 48, h = ROW - 10;
		Theme.rect(g, 0, 0, w, 2, Theme.ACCENT, done ? 0.4 : 1);
		Theme.rect(g, 0, h - 2, w, 2, Theme.ACCENT, done ? 0.4 : 1);
		Theme.rect(g, 0, 0, 2, h, Theme.ACCENT, done ? 0.4 : 1);
		Theme.rect(g, w - 2, 0, 2, h, Theme.ACCENT, done ? 0.4 : 1);
		var x = w - BTN_W - 12, y = (h - BTN_H) * 0.5;
		var last = give > 0 && given + give >= N;
		if( done )
			button(o, r, x, y, BTN_W, BTN_H, Lang.t("contracts.done"), false, 0, Special, Theme.CYAN);
		else if( last && !Contracts.specialRoom(inv, give) )
			button(o, r, x, y, BTN_W, BTN_H, Lang.t("contracts.invfull"), false, 0, Special, Theme.DANGER);
		else if( give > 0 && !last )
			button(o, r, x, y, BTN_W, BTN_H, giveLabel(give), true, Theme.CYAN, Special);
		else
			button(o, r, x, y, BTN_W, BTN_H, Lang.t("contracts.deliver"), give > 0, Theme.ACCENT, Special);
	}

	/** "Dar 12"; sin bloques, solo "Dar" */
	static function giveLabel( n : Int ) : String {
		var t = Lang.t("contracts.give");
		return n > 0 ? t.split("%n%").join("" + n) : StringTools.trim(t.split("%n%").join(""));
	}

	function run( action : ContractAction ) {
		switch( action ) {
		case Deliver(i): deliver(i);
		case Give(a): give(a);
		case Abandon(a): askAbandon(a);
		case Special: giveSpecial();
		}
	}

	/** da lo que llevas al contrato especial (Contracts.giveSpecial): con el ultimo bloque se cobra el conteneur */
	public function giveSpecial() : Bool {
		if( !Contracts.giveSpecial(info, inv) ) return false;
		refresh();
		return true;
	}

	/** da lo que llevas a la linea i del tablero (Contracts.deliver): se entrega o queda en curso */
	public function deliver( i : Int ) : Bool {
		if( !Contracts.deliver(info, inv, i) ) return false;
		refresh();
		return true;
	}

	/** da lo que llevas al contrato en curso a (Contracts.give) */
	public function give( a : ActiveContract ) : Bool {
		if( a == null || !Contracts.give(info, inv, a) ) return false;
		refresh();
		return true;
	}

	/** boton Abandonar: la confirmacion (onAbandon) se pide en la siguiente actualizacion */
	public function askAbandon( a : ActiveContract ) {
		if( a != null && Contracts.active(info).indexOf(a) >= 0 ) pendingAbandon = a;
	}

	/** abandona el contrato en curso a (ya confirmado): los bloques dados se pierden */
	public function abandon( a : ActiveContract ) : Bool {
		if( !Contracts.abandon(info, a) ) return false;
		refresh();
		return true;
	}

	function updateTimer() {
		if( count > 0 && Contracts.offered(info).length == 0 ) {
			timerText.text = Lang.t("contracts.full");
			return;
		}
		var s = Std.int(Math.ceil(Contracts.remaining()));
		var p = function(n : Int) return StringTools.lpad("" + n, "0", 2);
		timerText.text = Lang.t("contracts.renew").split("%t%").join(p(Std.int(s / 60)) + ":" + p(s % 60));
	}

	/** marco de la linea elegida y, si tiene dos botones, otro mas fino en el boton */
	function drawFocus() {
		focusG.clear();
		if( focus < 0 || focus >= items.length ) return;
		var it = items[focus];
		frame(rows.x - 3, rows.y + it.ry - 3, PW - 42, ROW - 4, 3);
		if( it.h < BTN_H ) frame(rows.x + it.x - 3, rows.y + it.y - 3, it.w + 6, it.h + 6, 2);
	}

	function frame( x : Float, y : Float, w : Float, h : Float, t : Float ) {
		Theme.rect(focusG, x, y, w, t, Theme.ACCENT);
		Theme.rect(focusG, x, y + h - t, w, t, Theme.ACCENT);
		Theme.rect(focusG, x, y, t, h, Theme.ACCENT);
		Theme.rect(focusG, x + w - t, y, t, h, Theme.ACCENT);
	}

	/** solo pruebas (Dev): el boton elegido y lo que hace */
	public function devFocus() : String {
		if( focus < 0 || focus >= items.length ) return "-";
		var it = items[focus], all = Contracts.active(info);
		var what = switch( it.action ) {
			case Deliver(i): "entregar " + i;
			case Give(a): "dar en curso " + all.indexOf(a);
			case Abandon(a): "abandonar en curso " + all.indexOf(a);
			case Special: "especial";
		}
		return focus + " (linea " + it.row + ": " + what + ")";
	}

	/**
	 * Teclado y mando: arriba/abajo eligen el boton (linea a linea; en un contrato en curso, Dar y luego Abandonar), Intro/A lo
	 * pulsa, Esc/B cierra. El tablero cambia solo al cumplirse el tiempo
	 */
	public function update( dt : Float, pad : hxd.Pad ) {
		if( pendingAbandon != null ) {
			var a = pendingAbandon;
			pendingAbandon = null;
			if( onAbandon != null ) onAbandon(a) else abandon(a);
		}
		if( !paused ) input(pad);
		if( parent == null ) return;
		if( Contracts.slot() != slot ) refresh() else updateTimer();
	}

	function input( pad : hxd.Pad ) {
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
		if( dy != 0 && items.length > 0 ) {
			focus = focus < 0 ? 0 : (focus + dy + items.length) % items.length;
			drawFocus();
		}
		if( ok && focus >= 0 && focus < items.length ) run(items[focus].action);
	}
}
