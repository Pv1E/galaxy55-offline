import Ui;
/** Pestana de la Base de datos ESCorp (DatabasePanel): se rehace con refresh y recibe el teclado, el mando y la rueda. */
class KubView extends h2d.Object {

	var panel : DatabasePanel;

	public function new( panel : DatabasePanel, parent : h2d.Object ) {
		super(parent);
		this.panel = panel;
	}

	public function refresh() {}

	/** flechas o cruceta */
	public function nav( dx : Int, dy : Int ) {}

	/** RePag/AvPag o X del mando: otra categoria o seccion */
	public function page( d : Int ) {}

	/** Intro o A */
	public function activate() {}

	/** rueda del raton: desplaza la zona que esta bajo el raton */
	public function scroll( delta : Float ) {}

	/** varias zonas desplazables: la que tiene el raton encima */
	function scrollUnder( delta : Float, boxes : Array<KubScroll> ) {
		for( b in boxes )
			if( b != null && b.mouseIn() ) {
				b.scroll(delta);
				return;
			}
	}
}
