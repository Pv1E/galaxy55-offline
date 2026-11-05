import Ui;
import Kubindex.KubState;

/** Un aviso de la Base de datos ESCorp: que ha pasado, el nombre y el kube (o el color del tipo de planeta o cometa). */
typedef KubNews = {
	var title : String;
	var name : String;
	@:optional var block : Block;
	@:optional var state : KubState;
	@:optional var colors : Array<Int>;
}

/**
 * Avisos ligeros de la Base de datos ESCorp, arriba a la derecha de la ventana (anadido del port): un kube localizado o
 * recuperado por primera vez, un tipo de planeta o de cometa nuevo. Entran por la derecha, duran unos segundos y se apilan
 * (los mas nuevos arriba, MAX como mucho).
 */
class KubNotify extends h2d.Object {

	static inline var W = 300;
	static inline var H = 52;
	static inline var GAP = 6;
	static inline var TIME = 3.5;
	static inline var FADE = 0.5;
	static inline var SLIDE = 0.25;
	static inline var MAX = 4;

	var atlas : h3d.mat.Texture;
	var list : Array<{ o : h2d.Object, t : Float, block : Block }> = [];

	public function new( parent : h2d.Object, atlas : h3d.mat.Texture ) {
		super(parent);
		this.atlas = atlas;
	}

	public function push( n : KubNews ) {
		// recuperado justo despues de localizado (romper hielo, recoger): el aviso nuevo sustituye al anterior del mismo kube
		for( old in list.copy() )
			if( n.block != null && old.block == n.block ) {
				old.o.remove();
				list.remove(old);
			}
		var o = new h2d.Object(this);
		var g = new h2d.Graphics(o);
		Theme.rect(g, 0, 0, W, H, Theme.PANEL, 0.9);
		Theme.rect(g, 0, 0, 3, H, Theme.ACCENT);
		if( n.block != null ) KubDraw.icon(o, n.block, n.state == null ? Got : n.state, 40, atlas).setPosition(10, 6);
		else if( n.colors != null && n.colors.length > 0 ) {
			Theme.rect(g, 14, 10, 32, 32, n.colors[0]);
			if( n.colors.length > 1 ) Theme.rect(g, 30, 10, 16, 32, n.colors[1]);
		}
		Theme.text(o, n.title, 1.1, Theme.ACCENT, 58, 8);
		KubDraw.fit(Theme.text(o, n.name, 1.5, Theme.TEXT, 58, 24), W - 66);
		list.unshift({ o : o, t : 0., block : n.block });
		while( list.length > MAX ) list.pop().o.remove();
		update(0);
	}

	public function update( dt : Float ) {
		var i = list.length;
		while( i-- > 0 ) {
			var n = list[i];
			n.t += dt;
			if( n.t >= TIME ) {
				n.o.remove();
				list.splice(i, 1);
			}
		}
		// pegado al borde real de la ventana (Theme.visibleArea), no al de la zona 1280x720
		var va = Theme.visibleArea();
		for( i in 0...list.length ) {
			var n = list[i];
			var s = Math.min(1, n.t / SLIDE);
			s = 1 - (1 - s) * (1 - s);
			n.o.x = va.x + va.w - W - 12 + (1 - s) * (W + 24);
			n.o.y = va.y + 12 + i * (H + GAP);
			n.o.alpha = n.t > TIME - FADE ? (TIME - n.t) / FADE : 1;
		}
	}

	/** pruebas (print kub): los avisos en pantalla */
	public function devInfo() : String return [for( n in list ) cast(n.o.getChildAt(n.o.numChildren - 1), h2d.Text).text].join(" | ");
}
