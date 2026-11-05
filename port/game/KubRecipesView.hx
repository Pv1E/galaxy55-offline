import Ui;
import Common;

/**
 * Pestana Recetas: las recetas descubiertas (se recupero uno de sus kubes), en dos columnas (cuantos se han fabricado sale en la
 * ficha de cada kube).
 * Clic en una ficha conocida: su ficha en el Kubindex.
 */
class KubRecipesView extends KubView {

	static inline var COL_W = 570;
	static inline var ROW_H = KubDraw.RECIPE_H + 8;

	var list : KubScroll;

	override function refresh() {
		removeChildren();
		var info = panel.info;
		var known = [for( r in Data.CRAFT ) if( Kubindex.recipeKnown(info, r) ) r];
		Theme.text(this, KubText.get("rc.count").split("%n%").join("" + known.length).split("%t%").join("" + Data.CRAFT.length), 1.6, Theme.TEXT, 0, 0);
		list = new KubScroll(this, DatabasePanel.CW, DatabasePanel.CH - 34);
		list.y = 34;
		// cada linea se hace cuando entra en la zona (hacer las 60 al abrir la pestana la paraba ~100 ms)
		list.itemH = ROW_H;
		if( known.length == 0 ) Theme.text(list.content, KubText.get("rc.empty"), 1.5, Theme.DIM, 0, 8);
		for( i in 0...known.length ) {
			var r = known[i];
			list.lazy((i % 2) * COL_W, Std.int(i / 2) * ROW_H, function(o) {
				var g = new h2d.Graphics(o);
				Theme.rect(g, -4, -2, COL_W - 12, ROW_H - 4, 0xFFFFFF, 0.04);
				KubDraw.recipe(o, r, info, panel.atlas, panel.pick, list);
			});
		}
		list.contentH = Math.ceil(known.length / 2) * ROW_H;
		list.done();
	}

	override function nav( dx : Int, dy : Int ) list.scroll(dy != 0 ? dy : dx);

	override function scroll( delta : Float ) list.scroll(delta);
}
