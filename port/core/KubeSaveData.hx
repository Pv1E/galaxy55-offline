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
	/** los kubes de la partida guardada pasan a los campos de siempre, donde los campos de siempre tienen aire o una casilla vacia;
	    decode da el bloque de cada numero (null: ya no esta). Lo usan el juego (EditorKubes) y el servidor (importHost) */
	public static function merge( info : SaveData.SaveInfo, raw : EditorKubesSave, decode : Int -> Block ) {
		function edits( e : Array<Int>, add : Array<Int> ) : Array<Int> {
			if( add == null ) return e;
			if( e == null ) e = [];
			var at = new Map<Int, Int>();
			var i = 0;
			while( i + 1 < e.length ) {
				if( e[i] >= 0 ) at.set(e[i], i + 1);
				i += 2;
			}
			i = 0;
			while( i + 1 < add.length ) {
				var cell = add[i], b = decode(add[i + 1]);
				i += 2;
				if( cell < 0 || b == null ) continue;
				var p = at.get(cell);
				if( p == null ) {
					e.push(cell);
					e.push(b.index);
				} else if( (e[p] & 0xFFFF) == 0 )
					e[p] = b.index;
			}
			return e;
		}
		function slotsOf( t : Protocol.BlockInventory, add : Array<Int> ) {
			if( t == null || add == null ) return;
			var i = 0;
			while( i + 2 < add.length ) {
				var c = add[i], b = decode(add[i + 1]), n = add[i + 2];
				i += 3;
				if( b != null && c >= 0 && c < t.length && t[c] == null && n > 0 ) t[c] = { k : b.index, n : n };
			}
		}
		info.edits = edits(info.edits, raw.edits);
		info.shipEdits = edits(info.shipEdits, raw.shipEdits);
		if( raw.planets != null && info.uni != null && info.uni.planets != null )
			for( rp in raw.planets )
				for( p in info.uni.planets )
					if( p.id == rp.id ) p.edits = edits(p.edits, rp.edits);
		if( raw.drops != null && info.deathDrops != null )
			for( rd in raw.drops )
				for( d in info.deathDrops )
					if( d.id == rd.id ) slotsOf(d.t, rd.t);
		if( info.inv != null ) slotsOf(info.inv.t, raw.inv);
		if( raw.chests != null && info.chests != null )
			for( rc in raw.chests )
				for( c in info.chests )
					if( c.key == rc.key ) slotsOf(c.t, rc.t);
		if( info.storage != null ) slotsOf(info.storage.t, raw.storage);
	}

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
