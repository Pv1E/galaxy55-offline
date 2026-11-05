import Ui;
import KubData.KubCat;

/**
 * Pestana Kubindex: a la izquierda las categorias, en medio los kubes localizados o recuperados de la categoria (los
 * desconocidos no salen: se ven en la pestana de los planetas) y a la derecha la ficha del elegido (KubDetail).
 */
class KubBlocksView extends KubView {

	static var CATS : Array<Null<KubCat>> = [null, CPlanet, CAnomaly, CComet, CCraft, CSpecial, CCharge];
	static var CAT_KEYS = ["kub.cat.all", "kub.cat.planet", "kub.cat.anomaly", "kub.cat.comet", "kub.cat.craft", "kub.cat.special", "kub.cat.charge"];
	static inline var FILTER_W = 190;
	static inline var COLS = 7;
	static inline var PITCH = KubCell.SIZE + 2;
	static inline var GRID_X = 206;
	static inline var DETAIL_X = 690;

	/** ultima categoria y ficha elegidas (se conservan al cerrar y volver a abrir) */
	static var lastCat = 0;
	static var lastSel : Block;

	var cat = 0;
	var list : Array<Block> = [];
	var cells : Array<KubCell> = [];
	var sel = -1;
	var filters : h2d.Object;
	var grid : KubScroll;
	var detail : KubDetail;

	override function refresh() {
		removeChildren();
		cat = lastCat;
		filters = new h2d.Object(this);
		grid = new KubScroll(this, COLS * PITCH + 8, DatabasePanel.CH);
		grid.x = GRID_X;
		grid.itemH = PITCH;
		detail = new KubDetail(panel, this, DatabasePanel.CW - DETAIL_X, DatabasePanel.CH);
		detail.x = DETAIL_X;
		fill();
		var i = lastSel == null ? -1 : list.indexOf(lastSel);
		select(i >= 0 ? i : list.length > 0 ? 0 : -1);
	}

	function known( c : Null<KubCat> ) : Array<Block> {
		var d = KubData.get();
		// las cargas solo salen en su categoria
		if( c == CCharge ) return [for( e in d.charges ) if( Kubindex.known(panel.info, e) ) e];
		return [for( e in d.entries ) if( Kubindex.known(panel.info, e) && (c == null || d.has(e, c)) ) e];
	}

	function fill() {
		filters.removeChildren();
		var g = new h2d.Graphics(filters);
		for( i in 0...CATS.length ) {
			var y = i * 44;
			Theme.rect(g, 0, y, FILTER_W, 40, i == cat ? Theme.ACCENT : 0xFFFFFF, i == cat ? 0.3 : 0.05);
			var it = new h2d.Interactive(FILTER_W, 40, filters);
			it.y = y;
			Theme.text(it, KubText.get(CAT_KEYS[i]), 1.5, i == cat ? Theme.TEXT : Theme.DIM, 12, 11);
			var n = Theme.text(it, "" + known(CATS[i]).length, 1.5, Theme.CYAN, 0, 11);
			n.x = FILTER_W - 12 - n.textWidth * n.scaleX;
			it.onClick = function(_) setCat(i);
		}
		var all = known(null);
		var got = [for( e in all ) if( Kubindex.got(panel.info, e) ) e].length;
		var c = Theme.text(filters, KubText.get("kub.count").split("%g%").join("" + got).split("%s%").join("" + (all.length - got)), 1.3, Theme.DIM, 0, CATS.length * 44 + 10);
		c.maxWidth = FILTER_W / c.scaleX;
		list = known(CATS[cat]);
		grid.clear();
		cells = [];
		for( i in 0...list.length ) {
			var e = list[i];
			var cell = new KubCell(grid.content, e, Kubindex.state(panel.info, e), Kubindex.isFresh(panel.info, e), panel.atlas);
			cell.setPosition((i % COLS) * PITCH, Std.int(i / COLS) * PITCH);
			cell.box = grid;
			cell.onOver = function(c) panel.setHover(c.block.getName());
			cell.onOut = function(_) panel.setHover(null);
			cell.onClick = function(_) select(i);
			cells.push(cell);
		}
		grid.contentH = Math.ceil(list.length / COLS) * PITCH;
		grid.done();
		if( list.length == 0 ) {
			var t = Theme.text(grid.content, KubText.get("kub.empty"), 1.5, Theme.DIM, 0, 8);
			t.maxWidth = (COLS * PITCH) / t.scaleX;
		}
	}

	function setCat( i : Int ) {
		if( i == cat ) return;
		cat = lastCat = i;
		var keep = sel >= 0 ? list[sel] : null;
		fill();
		var j = keep == null ? -1 : list.indexOf(keep);
		sel = -1;
		select(j >= 0 ? j : list.length > 0 ? 0 : -1);
	}

	function select( i : Int ) {
		if( sel >= 0 && sel < cells.length ) cells[sel].select(false);
		sel = i;
		var e = i >= 0 && i < list.length ? list[i] : null;
		lastSel = e;
		if( e != null ) {
			cells[i].select(true);
			grid.ensure(Std.int(i / COLS) * PITCH, PITCH);
			Kubindex.viewed(panel.info, e);
		}
		detail.show(e);
	}

	/** muestra la ficha de e (desde una receta o un planeta): con la categoria Todos (las cargas, con la suya) */
	public function show( e : Block ) {
		var want = e.charge != null ? CATS.indexOf(CCharge) : 0;
		// tambien si se ha recuperado con el panel abierto (el juego sigue): la lista se rehace
		if( cat != want || list.indexOf(e) < 0 ) {
			cat = lastCat = want;
			fill();
		}
		var i = list.indexOf(e);
		if( i >= 0 ) select(i);
	}

	override function nav( dx : Int, dy : Int ) {
		if( list.length == 0 ) return;
		var i = sel < 0 ? 0 : sel + dx + dy * COLS;
		if( i < 0 || i >= list.length ) return;
		select(i);
	}

	override function page( d : Int ) setCat((cat + d + CATS.length) % CATS.length);

	override function scroll( delta : Float ) scrollUnder(delta, [grid, detail.box]);
}
