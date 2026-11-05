import Ui;
import Common;
import Kubindex.KubState;
import KubData.KubCat;

/**
 * Ficha de un kube en el Kubindex: imagen (oscurecida si solo se ha localizado), nombre, donde encontrarlo y, una vez
 * recuperado, lo que da al minarlo, la carga que pide, cuantos se han puesto y roto y sus recetas (las que lo fabrican y las
 * que lo usan; lo que no se conoce sale como sombra con "???").
 */
class KubDetail extends h2d.Object {

	public var box(default, null) : KubScroll;
	var panel : DatabasePanel;
	var w : Int;
	var cy = 0.;

	public function new( panel : DatabasePanel, parent : h2d.Object, w : Int, h : Int ) {
		super(parent);
		this.panel = panel;
		this.w = w;
		box = new KubScroll(this, w, h);
	}

	public function show( e : Block ) {
		box.clear();
		cy = 0;
		if( e == null ) {
			line(KubText.get("kub.choose"), 1.5, Theme.DIM);
			box.done();
			return;
		}
		if( e.charge != null ) {
			showCharge(e);
			return;
		}
		var info = panel.info, d = KubData.get();
		var st = Kubindex.state(info, e);
		var o = box.content;
		var g = new h2d.Graphics(o);
		Theme.rect(g, 0, 0, 104, 104, 0xFFFFFF, 0.06);
		KubDraw.icon(o, e, st, 96, panel.atlas).setPosition(4, 4);
		var n = Theme.text(o, e.getName(), 2.1, Theme.TEXT, 118, 4);
		n.maxWidth = (w - 126) / n.scaleX;
		// bajo el nombre: el estado, las categorias y, con su color, la carga que pide el laser (posiciones enteras: con el filtro
		// nearest de h2d, una y con decimales se comia la ultima fila de pixeles de las letras)
		var sy = Math.round(8 + n.textHeight * n.scaleY);
		Theme.text(o, KubText.get(st == Got ? "kub.status.got" : "kub.status.seen"), 1.4, st == Got ? Theme.CYAN : Theme.DIM, 118, sy);
		sy += 24;
		var tags = [for( c in [CPlanet, CAnomaly, CComet, CCraft, CSpecial] ) if( d.has(e, c) ) KubText.get(tagKey(c))];
		Theme.text(o, tags.join("  ·  "), 1.5, Theme.ACCENT, 118, sy);
		sy += 24;
		var charge = d.chargeFor(e);
		if( charge != null ) {
			Theme.text(o, KubText.get("chargetag." + Type.enumConstructor(charge)), 1.5, KubDraw.chargeColor(charge), 118, sy);
			sy += 24;
		}
		cy = Math.max(116, sy + 8);
		for( l in d.placeLines(info, e) ) line(l, 1.3, Theme.TEXT);
		if( st != Got ) {
			cy += 8;
			line(KubText.get("kub.locked"), 1.3, Theme.DIM);
			box.contentH = cy;
			box.done();
			return;
		}
		cy += 6;
		// en creativo no se apunta nada: sin estadisticas, que siempre estarian a 0
		if( !Kubindex.full(info) ) {
			var s = Kubindex.stat(info, e, false);
			// fabricados: los que han salido del sintetizador (veces que se hizo cada receta que lo da, por lo que da cada vez)
			var made = 0;
			for( r in d.recipesMaking(e) ) made += Kubindex.craftCount(info, r) * (r.count == null ? 1 : r.count);
			line(KubText.get("kub.stats").split("%p%").join("" + (s == null ? 0 : s.p)).split("%b%").join("" + (s == null ? 0 : s.b)).split("%c%").join("" + made), 1.3, Theme.TEXT);
		}
		// las cargas que da al romperlo (citronox viejo, plantas...), como una receta: el kube -> sus cargas
		var drop = e.getDrop();
		if( drop != null && drop.b.charge != null )
			recipes(KubText.get("kub.broken"), [{ id : -1, schema : [CSSingle(e.k)], out : drop.b.k, count : drop.count }]);
		recipes(KubText.get("kub.made"), d.recipesMaking(e));
		recipes(KubText.get("kub.uses"), d.recipesUsing(e));
		box.contentH = cy;
		box.done();
	}

	/**
	 * Ficha de una carga: lo que la suelta al romperlo (con cuantas), lo que la fabrica en el sintetizador y los kubes que la
	 * piden para minarlos. La rosa no la suelta ningun bloque: esta tal cual en algunas anomalias.
	 */
	function showCharge( e : Block ) {
		var info = panel.info, d = KubData.get();
		var o = box.content;
		var g = new h2d.Graphics(o);
		Theme.rect(g, 0, 0, 104, 104, 0xFFFFFF, 0.06);
		KubDraw.icon(o, e, Got, 96, panel.atlas).setPosition(4, 4);
		var n = Theme.text(o, e.getName(), 2.1, Theme.TEXT, 118, 4);
		n.maxWidth = (w - 126) / n.scaleX;
		var sy = Math.round(8 + n.textHeight * n.scaleY);
		Theme.text(o, KubText.get("kub.status.got"), 1.4, Theme.CYAN, 118, sy);
		Theme.text(o, KubText.get("kub.tag.charge"), 1.5, KubDraw.chargeColor(e.charge), 118, sy + 24);
		cy = Math.max(116, sy + 56);
		for( l in d.placeLines(info, e) ) line(l, 1.3, Theme.TEXT);
		var src = d.chargeSources(e);
		if( src.length > 0 ) {
			header(KubText.get("ch.break"));
			cells([for( s in src ) s.e], function(b) {
				for( s in src ) if( s.e == b ) return " x" + s.n;
				return "";
			});
		}
		recipes(KubText.get("ch.craft"), d.chargeRecipes(e));
		var need = d.chargeNeeded(e);
		if( need.length > 0 ) {
			header(KubText.get("ch.needed"));
			cells(need, function(_) return "");
		}
		box.contentH = cy;
		box.done();
	}

	/** rejilla de kubes (desconocidos en sombra); al pasar el raton, su nombre (o ??? y donde encontrarlo) y extra */
	function cells( list : Array<Block>, extra : Block -> String ) {
		var info = panel.info, d = KubData.get();
		var pitch = KubCell.SIZE + 2, cols = Std.int((w - 10) / pitch);
		for( i in 0...list.length ) {
			var b = list[i];
			var st = Kubindex.state(info, b);
			var c = new KubCell(box.content, b, st, false, panel.atlas);
			c.setPosition((i % cols) * pitch, cy + Std.int(i / cols) * pitch);
			c.box = box;
			c.onOver = function(_) panel.setHover((st == Unknown ? KubText.get("kub.unknown") + "  ·  " + d.placeShort(info, b) : b.getName()) + extra(b));
			c.onOut = function(_) panel.setHover(null);
			c.onClick = function(_) panel.pick(b);
		}
		cy += Math.ceil(list.length / cols) * pitch + 8;
	}

	static function tagKey( c : KubCat ) : String {
		return switch( c ) {
			case CPlanet: "kub.tag.planet";
			case CAnomaly: "kub.tag.anomaly";
			case CComet: "kub.tag.comet";
			case CCraft: "kub.tag.craft";
			case CSpecial: "kub.tag.special";
			case CCharge: "kub.tag.charge";
		}
	}

	function header( s : String ) {
		cy += 4;
		Theme.text(box.content, s, 1.6, Theme.ACCENT, 0, cy);
		cy += 26;
	}

	function line( s : String, scale : Float, col : Int ) {
		var t = Theme.text(box.content, s, scale, col, 0, cy);
		t.maxWidth = (w - 10) / scale;
		cy += t.textHeight * scale + 6;
	}

	function recipes( title : String, list : Array<CraftRule> ) {
		if( list.length == 0 ) return;
		header(title);
		for( r in list ) {
			var o = new h2d.Object(box.content);
			o.y = cy;
			KubDraw.recipe(o, r, panel.info, panel.atlas, panel.pick, box);
			cy += KubDraw.RECIPE_H;
		}
	}
}
