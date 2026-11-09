import Ui;
import Common;
import Kubindex.KubState;

/**
 * Pestana Planetas: a la izquierda los tipos de planeta y de cometa (desconocidos hasta aterrizar en uno) con cuantos se han
 * explorado, y las anomalias (desconocidas hasta localizar uno de sus kubes propios). A la derecha, los kubes del elegido: el
 * terreno de un planeta o una cometa (y el nombre de las anomalias que pueden salir en el), o los de una anomalia. Los
 * recuperados en color, los localizados oscurecidos y los que faltan como sombra negra.
 */
class KubPlanetsView extends KubView {

	/** los tipos de planeta que salen en el mapa (ExpData); la Ciudad muerta (nunca sale) no esta en la base de datos */
	static var PLANETS = KubData.PLANETS;
	static inline var LIST_W = 330;
	static inline var ROW_H = 56;
	static inline var RIGHT_X = 350;
	static inline var PITCH = KubCell.SIZE + 2;

	/** ultimo elegido: un bioma o "a:" + anomalia */
	static var lastType : String;

	var types : Array<String> = [];
	var rows : Array<{ y : Float, g : h2d.Graphics }> = [];
	var sel = -1;
	var left : KubScroll;
	var right : KubScroll;
	var ly = 0.;

	override function refresh() {
		removeChildren();
		left = new KubScroll(this, LIST_W, DatabasePanel.CH);
		left.itemH = ROW_H;
		right = new KubScroll(this, DatabasePanel.CW - RIGHT_X, DatabasePanel.CH);
		right.x = RIGHT_X;
		var info = panel.info, d = KubData.get();
		ly = 0;
		types = [];
		rows = [];
		section("pl.planets");
		for( b in PLANETS ) biomeRow(b);
		section("pl.comets");
		for( b in Comets.KINDS ) biomeRow(b);
		section("pl.anomalytypes");
		for( a in d.anomalies ) anomalyRow(a);
		left.contentH = ly;
		left.done();
		var i = types.indexOf(lastType);
		if( i < 0 ) {
			// el primer tipo explorado
			for( j in 0...types.length ) if( Kubindex.biomeKnown(info, types[j]) ) { i = j; break; }
		}
		select(i < 0 ? 0 : i);
	}

	function section( key : String ) {
		if( ly > 0 ) ly += 8;
		Theme.text(left.content, KubText.get(key), 1.5, Theme.ACCENT, 0, ly + 4);
		ly += 30;
	}

	function row( id : String, name : String, sub : String, known : Bool, colors : Array<Int> ) {
		var i = types.length;
		types.push(id);
		var o = new h2d.Object(left.content);
		o.y = ly;
		var g = new h2d.Graphics(o);
		var sw = new h2d.Graphics(o);
		Theme.rect(sw, 10, 12, 30, 30, known && colors.length > 0 ? colors[0] : 0x000000, known ? 1 : 0.9);
		if( known && colors.length > 1 ) Theme.rect(sw, 25, 12, 15, 30, colors[1]);
		// sin linea de debajo (creativo), el nombre queda centrado en la fila
		KubDraw.fit(Theme.text(o, name, 1.5, known ? Theme.TEXT : Theme.DIM, 52, sub != null ? 8 : 18), LIST_W - 70);
		if( sub != null ) Theme.text(o, sub, 1.2, Theme.CYAN, 52, 30);
		var it = new h2d.Interactive(LIST_W - 10, ROW_H - 4, o);
		it.onClick = function(_) if( left.mouseIn() ) select(i);
		rows.push({ y : ly, g : g });
		ly += ROW_H;
	}

	function biomeRow( biome : String ) {
		var info = panel.info;
		var known = Kubindex.biomeKnown(info, biome);
		// en creativo no se apunta nada: sin "Explorados", que siempre estaria a 0
		row(biome, known ? ExpData.ExpOffline.biomeName(biome) : KubText.get("pl.unknown") + " ???",
			Kubindex.full(info) ? null : KubText.get("pl.explored").split("%n%").join("" + Kubindex.explored(info, biome)), known,
			Data.getBiome(Type.createEnum(BiomeKind, biome)).exploreColors);
	}

	function anomalyRow( a : KubData.KubAnomaly ) {
		var info = panel.info, d = KubData.get();
		var known = Kubindex.anomalyKnown(info, a.id);
		var list = d.anomalyBlocks(a.id);
		var seen = [for( e in list ) if( Kubindex.known(info, e) ) e].length;
		row("a:" + a.id, known ? d.anomalyName(a.id) : KubText.get("pl.anomalyunknown") + " ???",
			KubText.get("pl.found").split("%g%").join("" + seen).split("%t%").join("" + list.length), known, known ? [Theme.ACCENT] : []);
	}

	function select( i : Int ) {
		sel = i;
		lastType = types[i];
		for( j in 0...rows.length ) {
			var r = rows[j];
			r.g.clear();
			Theme.rect(r.g, 0, 2, LIST_W - 10, ROW_H - 4, j == i ? Theme.ACCENT : 0xFFFFFF, j == i ? 0.3 : 0.05);
		}
		left.ensure(rows[i].y, ROW_H);
		right.clear();
		var y = StringTools.startsWith(types[i], "a:") ? showAnomaly(types[i].substr(2)) : showBiome(types[i]);
		right.contentH = y;
		right.done();
	}

	function title( s : String ) : Float {
		var t = Theme.text(right.content, s, 2.2, Theme.TEXT, 0, 0);
		return t.textHeight * t.scaleY + 6;
	}

	function line( s : String, scale : Float, col : Int, y : Float ) : Float {
		var t = Theme.text(right.content, s, scale, col, 0, y);
		t.maxWidth = (right.w - 10) / scale;
		return y + t.textHeight * scale + 8;
	}

	function showBiome( biome : String ) : Float {
		var info = panel.info, d = KubData.get();
		var known = Kubindex.biomeKnown(info, biome);
		var y = title(known ? ExpData.ExpOffline.biomeName(biome) : KubText.get("pl.unknown") + " ???");
		if( !Kubindex.full(info) ) y = line(KubText.get("pl.explored").split("%n%").join("" + Kubindex.explored(info, biome)), 1.4, Theme.CYAN, y);
		if( !known ) return line(KubText.get("pl.notexplored"), 1.4, Theme.DIM, y);
		var terrain = d.ofBiome(biome);
		var got = [for( e in terrain ) if( Kubindex.got(info, e) ) e].length;
		y = line(KubText.get("pl.progress").split("%g%").join("" + got).split("%t%").join("" + terrain.length), 1.4, Theme.TEXT, y) + 4;
		y = grid(KubText.get("pl.terrain"), terrain, y);
		// las anomalias que pueden salir aqui: las conocidas por su nombre, las demas solo contadas
		Theme.text(right.content, KubText.get("pl.anomalies"), 1.6, Theme.ACCENT, 0, y + 10);
		y += 40;
		var list = d.anomaliesIn(biome);
		if( list.length == 0 ) return line(KubText.get("pl.anomalynone"), 1.3, Theme.DIM, y);
		var names = [for( a in list ) if( Kubindex.anomalyKnown(info, a.id) ) d.anomalyName(a.id)];
		var unknown = list.length - names.length;
		if( unknown > 0 ) names.push(KubText.get("pl.anomalymore").split("%n%").join("" + unknown));
		return line(names.join(", "), 1.3, Theme.TEXT, y);
	}

	function showAnomaly( id : String ) : Float {
		var info = panel.info, d = KubData.get();
		var a = d.anomaly(id);
		var known = Kubindex.anomalyKnown(info, id);
		var y = title(known ? d.anomalyName(id) : KubText.get("pl.anomalyunknown") + " ???");
		var where = a.biomes == null ? KubText.get("pl.everywhere")
			: [for( b in a.biomes ) ExpData.ExpOffline.biomeName(b)].join(", ") + " " + KubText.get("pl.caves");
		y = line(where, 1.3, Theme.CYAN, y);
		var list = d.anomalyBlocks(id);
		var got = [for( e in list ) if( Kubindex.got(info, e) ) e].length;
		y = line(KubText.get("pl.progress").split("%g%").join("" + got).split("%t%").join("" + list.length), 1.4, Theme.TEXT, y);
		return grid(KubText.get("pl.blocks"), list, y + 4);
	}

	/** una rejilla de kubes con su titulo; devuelve donde acaba */
	function grid( title : String, list : Array<Block>, y : Float ) : Float {
		var info = panel.info;
		Theme.text(right.content, title, 1.6, Theme.ACCENT, 0, y);
		y += 28;
		var cols = Std.int((right.w - 10) / PITCH);
		for( i in 0...list.length ) {
			var e = list[i];
			var st = Kubindex.state(info, e);
			var c = new KubCell(right.content, e, st, st != Unknown && Kubindex.isFresh(info, e), panel.atlas);
			c.setPosition((i % cols) * PITCH, y + Std.int(i / cols) * PITCH);
			c.box = right;
			c.onOver = function(c) panel.setHover(st == Unknown ? KubText.get("kub.unknown") + "  ·  " + KubData.get().placeShort(info, e) : e.getName());
			c.onOut = function(_) panel.setHover(null);
			c.onClick = function(c) panel.pick(e);
		}
		return y + Math.ceil(list.length / cols) * PITCH;
	}

	override function nav( dx : Int, dy : Int ) {
		var d = dy != 0 ? dy : dx;
		if( types.length > 0 ) select(((sel + d) % types.length + types.length) % types.length);
	}

	/** RePag/AvPag: seccion siguiente o anterior (planetas, cometas, anomalias) */
	override function page( d : Int ) {
		var cometAt = -1, anomalyAt = -1;
		for( j in 0...types.length ) {
			if( cometAt < 0 && Comets.isComet(types[j]) ) cometAt = j;
			if( anomalyAt < 0 && StringTools.startsWith(types[j], "a:") ) anomalyAt = j;
		}
		var firsts = [0, cometAt, anomalyAt];
		var cur = sel >= anomalyAt ? 2 : sel >= cometAt ? 1 : 0;
		select(firsts[(cur + d + 3) % 3]);
	}

	override function scroll( delta : Float ) scrollUnder(delta, [left, right]);
}
