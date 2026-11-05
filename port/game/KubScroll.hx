import Ui;
/**
 * Zona de w x h con su contenido desplazable con la rueda (Base de datos ESCorp). Lo que sale de la zona no se dibuja (h2d.Mask),
 * pero sus h2d.Interactive siguen ahi: los clics se filtran con mouseIn().
 */
class KubScroll extends h2d.Object {

	public var content(default, null) : h2d.Object;
	/** alto del contenido (lo pone quien lo llena) */
	public var contentH = 0.;
	/**
	 * alto maximo de cada hijo del contenido (filas o casillas). Si se pone, los que quedan fuera de la zona no se dibujan: con
	 * cientos de textos (las recetas), dibujarlos todos la primera vez tardaba decenas de ms
	 */
	public var itemH = 0.;
	public var w(default, null) : Int;
	public var h(default, null) : Int;
	var mask : h2d.Mask;
	var bar : h2d.Graphics;
	/** hijos que se construyen la primera vez que entran en la zona (lazy) */
	var pending : Array<{ o : h2d.Object, build : h2d.Object -> Void }> = [];

	public function new( parent : h2d.Object, w : Int, h : Int ) {
		super(parent);
		this.w = w;
		this.h = h;
		mask = new h2d.Mask(w, h, this);
		content = new h2d.Object(mask);
		bar = new h2d.Graphics(this);
	}

	public function clear() {
		content.removeChildren();
		pending = [];
		contentH = 0;
		mask.scrollY = 0;
		drawBar();
	}

	/** un hijo en x, y que build llena la primera vez que entra en la zona (necesita itemH) */
	public function lazy( x : Float, y : Float, build : h2d.Object -> Void ) : h2d.Object {
		var o = new h2d.Object(content);
		o.setPosition(x, y);
		pending.push({ o : o, build : build });
		return o;
	}

	public var top(get, never) : Float;
	inline function get_top() return mask.scrollY;

	public function scrollTo( y : Float ) {
		var max = Math.max(0, contentH - h);
		mask.scrollY = Math.round(Math.max(0, Math.min(max, y)));
		drawBar();
		cull();
	}

	/** con itemH: se ve lo que entra en la zona; lo pendiente que entra, se construye */
	function cull() {
		if( itemH <= 0 ) return;
		for( c in content ) c.visible = c.y > top - itemH && c.y < top + h;
		var i = 0;
		while( i < pending.length ) {
			var p = pending[i];
			if( p.o.visible ) {
				pending.splice(i, 1);
				p.build(p.o);
			} else i++;
		}
	}

	/** rueda: delta > 0 = hacia abajo */
	public function scroll( delta : Float ) scrollTo(top + (delta > 0 ? 60 : -60));

	/** desplaza lo justo para que se vea la franja y..y+hh del contenido */
	public function ensure( y : Float, hh : Float ) {
		if( y < top ) scrollTo(y);
		else if( y + hh > top + h ) scrollTo(y + hh - h);
	}

	/** el raton esta sobre la zona visible */
	public function mouseIn() : Bool {
		var s = getScene();
		if( s == null ) return false;
		var p = globalToLocal(new h2d.col.Point(s.mouseX, s.mouseY));
		return p.x >= 0 && p.y >= 0 && p.x < w && p.y < h;
	}

	/** se termina de llenar: barra de desplazamiento a la derecha si no cabe */
	public function done() scrollTo(top);

	function drawBar() {
		bar.clear();
		if( contentH <= h ) return;
		var bh = Math.max(24, h * h / contentH);
		var by = (h - bh) * top / (contentH - h);
		Theme.rect(bar, w - 4, 0, 4, h, 0xFFFFFF, 0.06);
		Theme.rect(bar, w - 4, by, 4, bh, Theme.ACCENT, 0.7);
	}
}
