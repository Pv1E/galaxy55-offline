/**
 * Kubes del editor de una partida guardada (SaveInfo.editorKubes): el tipo y su lectura, sin nada de dibujo (separado de
 * EditorKubes para el multijugador, anadido del port). Los campos de siempre (edits, inv, chests...) llevan aire o una casilla
 * vacia en su sitio: una version sin los kubes del editor los ignora sin mas (y los pierde si guarda la partida). Cada kube va
 * como un numero n = posicion en ids * 4 + variante (0 = el bloque; la puerta y el plano tienen mas, EditorKubes.PER).
 */
typedef EditorKubesSave = {
	/** archivo de cada kube (nombre del .kube sin la extension, en minusculas) */
	var ids : Array<String>;
	/** planeta actual: pares [celda, n] */
	@:optional var edits : Array<Int>;
	/** nave: pares [celda, n] */
	@:optional var shipEdits : Array<Int>;
	/** planetas visitados (uni.planets): sus pares [celda, n] */
	@:optional var planets : Array<{ id : Int, edits : Array<Int> }>;
	/** inventario: [casilla, n, cantidad, ...] */
	@:optional var inv : Array<Int>;
	/** equipo dejado al morir (id de SaveInfo.deathDrops): [casilla, n, cantidad, ...] */
	@:optional var drops : Array<{ id : Int, t : Array<Int> }>;
	/** cantinas (clave de SaveInfo.chests): [casilla, n, cantidad, ...] */
	@:optional var chests : Array<{ key : String, t : Array<Int> }>;
	/** stockage de la nave (SaveInfo.storage): [casilla, n, cantidad, ...] */
	@:optional var storage : Array<Int>;
}

class KubeSaveData {
	/** editorKubes de una partida leida de disco; null si no hay o esta mal formado */
	public static function read( o : Dynamic ) : EditorKubesSave {
		try {
			if( o == null || o.ids == null ) return null;
			inline function ints( a : Dynamic ) : Array<Int> return a == null ? null : [for( v in (a : Array<Dynamic>) ) Std.int(v)];
			var r : EditorKubesSave = { ids : [for( v in (o.ids : Array<Dynamic>) ) Std.string(v).toLowerCase()] };
			r.edits = ints(o.edits);
			r.shipEdits = ints(o.shipEdits);
			r.inv = ints(o.inv);
			if( o.drops != null ) r.drops = [for( d in (o.drops : Array<Dynamic>) ) { id : Std.int(d.id), t : ints(d.t) }];
			if( o.planets != null ) r.planets = [for( p in (o.planets : Array<Dynamic>) ) { id : Std.int(p.id), edits : ints(p.edits) }];
			if( o.chests != null ) r.chests = [for( c in (o.chests : Array<Dynamic>) ) { key : Std.string(c.key), t : ints(c.t) }];
			r.storage = ints(o.storage);
			return r;
		} catch( e : Dynamic ) {
			return null;
		}
	}
}
