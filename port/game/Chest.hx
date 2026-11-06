import Common;
import Ui;
import IconMesh.Icons;

/**
 * Cantina de ESCorp (BChest, BFContainer(4)): cofre de 4 casillas, copiado de ent/Chest.hx del original.
 * Clic en una casilla para cogerla y clic en otra para dejarla: junta pilas iguales, mueve a una vacia o intercambia.
 * Mayus = la mitad, Ctrl = una. En el original el contenido lo guardaba el servidor; aqui va en la partida (SaveInfo.chests).
 * No es modal, como el original: el juego sigue y la ventana se cierra si el jugador se aleja (far).
 */
class Chest extends h2d.Object {

	public var onClose : Void -> Void;

	static inline var CELL = 60;
	static inline var PX = Theme.W;
	static inline var PY = Theme.H;

	var atlas : h3d.mat.Texture;
	var inv : Inv;
	public var box(default, null) : Protocol.BlockInventory;
	var maxWeight : Int;
	var grid : h2d.Object;
	var info : h2d.Text;
	/** altura del centro del boton Cerrar: la ayuda (o el nombre) se centra con el */
	var infoMid = 0.;
	/** casilla cogida: [0 = cofre / 1 = inventario, indice] */
	var cur : Array<Int>;
	/** añadido del port: casilla marcada con el mando o las flechas [lado, indice] (null = solo raton) */
	var focus : Array<Int>;
	/** posicion del jugador al abrirla (Chest.hpos del original) */
	var hpos : { x : Float, y : Float, z : Float };
	/** zona del panel: un clic fuera de ella mueve la vista (GalaxyApp) */
	var panel : h2d.col.Bounds;
	/** contenido dibujado (stamp): el juego sigue con la ventana abierta y lo recogido entra en el inventario */
	var shown : String;

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture, inv : Inv, box : Protocol.BlockInventory, hpos : { x : Float, y : Float, z : Float } ) {
		super(parent);
		this.atlas = atlas;
		this.inv = inv;
		this.box = box;
		this.hpos = hpos;
		maxWeight = inv.inv.maxWeight;
		var w = 700, h = 330;
		var px = (PX - w) * 0.5, py = 120.;
		panel = h2d.col.Bounds.fromValues(px, py, w, h);
		// sin oscurecer el fondo: no es modal (el original solo ponia el inventario del cofre arriba, sobre el juego)
		var bg = new h2d.Graphics(this);
		Theme.rect(bg, px, py, w, h, Theme.PANEL, 0.96);
		Theme.rect(bg, px, py, w, 4, Theme.ACCENT);
		Theme.text(this, Block.get(BChest).getName(), 2.4, Theme.TEXT, px + 24, py + 18);
		Theme.text(this, Lang.t("chest.yours"), 1.6, Theme.DIM, px + 24, py + 150);
		info = Theme.text(this, "", 1.4, Theme.DIM, px + 24, py + h - 34);
		var close = new h2d.Interactive(140, 34, this);
		close.x = px + w - 160;
		close.y = py + h - 46;
		var cg = new h2d.Graphics(close);
		Theme.rect(cg, 0, 0, 140, 34, 0xFFFFFF, 0.08);
		Theme.center(Theme.text(close, Lang.t("shop.close"), 1.7, Theme.TEXT), 140, 34);
		close.onClick = function(_) if( onClose != null ) onClose();
		// la ayuda no cabe en una linea (en frances pisaba el boton y se salia del panel): se parte antes del boton
		info.maxWidth = (close.x - 20 - info.x) / info.scaleX;
		infoMid = close.y + 17;
		setInfo(Lang.t("chest.hint"));
		grid = new h2d.Object(this);
		grid.x = px + 24;
		grid.y = py + 70;
		refresh();
	}

	function stamp() {
		return [for( s in box.concat(inv.inv.t) ) s == null ? "-" : s.k + "x" + s.n].join(",");
	}

	/** Chest.update del original: se cierra si el jugador se aleja mas de 0.5 de donde la abrio (girar o mirar no cuenta) */
	public function far( g : GameView ) : Bool {
		var dx = g.wrapDist(hpos.x - g.px), dy = g.wrapDist(hpos.y - g.py), dz = hpos.z - g.pz;
		return Math.sqrt(dx * dx + dy * dy + dz * dz) > 0.5;
	}

	/** el punto (de la escena 2D) esta sobre el panel */
	public function isOver( x : Float, y : Float ) : Bool {
		return panel.contains(new h2d.col.Point(x, y));
	}

	function refresh() {
		shown = stamp();
		grid.removeChildren();
		var w = 652;
		for( i in 0...box.length ) slot(0, i, (w - box.length * CELL) * 0.5 + i * CELL, 0, box[i]);
		for( i in 0...inv.inv.t.length ) slot(1, i, (w - inv.inv.t.length * CELL) * 0.5 + i * CELL, 110, inv.inv.t[i]);
	}

	function slot( side : Int, idx : Int, x : Float, y : Float, s : Null<{ k : Int, n : Int }> ) {
		var c = new h2d.Object(grid);
		c.x = x;
		c.y = y;
		var g = new h2d.Graphics(c);
		var sel = cur != null && cur[0] == side && cur[1] == idx;
		var foc = focus != null && focus[0] == side && focus[1] == idx;
		var draw = function(on : Bool) {
			g.clear();
			Theme.rect(g, 2, 2, CELL - 4, CELL - 4, sel || on ? Theme.ACCENT : 0xFFFFFF, sel ? 0.45 : (on ? 0.25 : 0.07));
		};
		draw(foc);
		if( foc ) {
			Theme.rect(g, 0, 0, CELL, 2, Theme.ACCENT);
			Theme.rect(g, 0, CELL - 2, CELL, 2, Theme.ACCENT);
			Theme.rect(g, 0, 0, 2, CELL, Theme.ACCENT);
			Theme.rect(g, CELL - 2, 0, 2, CELL, Theme.ACCENT);
			setInfo(s == null ? Lang.t("chest.hint") : Block.all[s.k].getName() + " x" + s.n);
		}
		if( s != null ) {
			var b = Block.all[s.k];
			var bm = Icons.bitmap(c, b, 48, atlas);
			bm.x = 6;
			bm.y = 3;
			Theme.text(c, "" + s.n, 1.2, s.n >= b.getMax(maxWeight) ? 0xF08080 : Theme.TEXT, 5, CELL - 20);
		}
		var it = new h2d.Interactive(CELL - 4, CELL - 4, c);
		it.onOver = function(_) {
			draw(true);
			setInfo(s == null ? Lang.t("chest.hint") : Block.all[s.k].getName() + " x" + s.n);
		};
		it.onOut = function(_) draw(false);
		it.onClick = function(_) click(side, idx);
	}

	/** texto de abajo (ayuda o "Nombre xN"), centrado en altura con el boton Cerrar */
	function setInfo( s : String ) {
		info.text = s;
		info.y = Math.round(infoMid - info.textHeight * info.scaleY * 0.5);
	}

	/** banco de pruebas (orden chestfocus): marca una casilla como con el mando */
	public function devFocus( side : Int, idx : Int ) {
		focus = [side, idx];
		refresh();
	}

	inline function tab( side : Int ) return side == 0 ? box : inv.inv.t;

	/** Mando y teclado (añadido del port; el original solo tenia raton): cruceta/flechas mueven la marca,
	 * A/Intro = clic, X = la mitad (como Mayus), Y = una (como Ctrl), B/Esc = cerrar.
	 * La palanca izquierda mueve al jugador (la ventana no es modal); las flechas, en cambio, son de la ventana (GameView.actionKeys). */
	public function update( dt : Float, pad : hxd.Pad ) {
		if( stamp() != shown ) refresh();
		var K = hxd.Key;
		var dx = 0, dy = 0;
		if( K.isPressed(K.LEFT) ) dx = -1;
		if( K.isPressed(K.RIGHT) ) dx = 1;
		if( K.isPressed(K.UP) ) dy = -1;
		if( K.isPressed(K.DOWN) ) dy = 1;
		var ok = K.isPressed(K.ENTER) || K.isPressed(K.NUMPAD_ENTER);
		var half = false, one = false, back = K.isPressed(K.ESCAPE);
		if( pad != null ) {
			if( pad.isPressed(pad.config.dpadLeft) ) dx = -1;
			if( pad.isPressed(pad.config.dpadRight) ) dx = 1;
			if( pad.isPressed(pad.config.dpadUp) ) dy = -1;
			if( pad.isPressed(pad.config.dpadDown) ) dy = 1;
			if( pad.isPressed(pad.config.A) ) ok = true;
			if( pad.isPressed(pad.config.X) ) { ok = true; half = true; }
			if( pad.isPressed(pad.config.Y) ) { ok = true; one = true; }
			if( pad.isPressed(pad.config.B) ) back = true;
		}
		if( back ) {
			if( cur != null ) { cur = null; refresh(); }
			else if( onClose != null ) onClose();
			return;
		}
		if( dx != 0 || dy != 0 ) {
			if( focus == null ) focus = [0, 0];
			else {
				var side = focus[0], i = focus[1];
				if( dy != 0 ) {
					var nside = side + dy;
					if( nside >= 0 && nside <= 1 ) {
						// misma posicion relativa en la otra fila
						var from = tab(side).length, to = tab(nside).length;
						i = Std.int(Math.min(to - 1, Math.round((i + 0.5) * to / from - 0.5)));
						side = nside;
					}
				}
				i += dx;
				var n = tab(side).length;
				if( i < 0 ) i = n - 1 else if( i >= n ) i = 0;
				focus = [side, i];
			}
			refresh();
		}
		if( ok && focus != null ) click(focus[0], focus[1], half, one);
	}

	/** Chest.checkSwap del original */
	public function click( side : Int, idx : Int, padHalf = false, padOne = false ) {
		if( cur == null ) {
			if( tab(side)[idx] != null ) cur = [side, idx];
			refresh();
			return;
		}
		var src = tab(cur[0]), isrc = cur[1];
		var dst = tab(side), idst = idx;
		var bsrc = src[isrc], bdst = dst[idst];
		if( bsrc == null || (src == dst && isrc == idst) ) {
			cur = null;
			refresh();
			return;
		}
		var split = padHalf || hxd.Key.isDown(hxd.Key.SHIFT);
		var one = padOne || hxd.Key.isDown(hxd.Key.CTRL);
		var smax = one ? 1 : (split ? Math.ceil(bsrc.n * 0.5) : bsrc.n);
		if( bdst != null && bdst.k == bsrc.k ) {
			// juntar
			var max = Block.all[bdst.k].getMax(maxWeight);
			if( bdst.n >= max ) return;
			var n = max - bdst.n;
			if( n > smax ) n = smax;
			bdst.n += n;
			bsrc.n -= n;
			if( bsrc.n == 0 ) {
				src[isrc] = null;
				cur = null;
			}
		} else if( bdst == null ) {
			// mover o partir
			dst[idst] = { k : bsrc.k, n : smax };
			bsrc.n -= smax;
			if( bsrc.n == 0 ) {
				src[isrc] = null;
				cur = null;
			}
		} else {
			// intercambiar
			dst[idst] = bsrc;
			src[isrc] = bdst;
			cur = null;
		}
		inv.display();
		refresh();
	}
}
