import Common;

/**
 * Geometria de los modelos de bloque (BFModel), copiada de r3d/Builder.hx initModels() del original.
 * Cada vertice son 6 floats: x, y, z, u, v, sombra. Cada 4 vertices forman una cara (tira de triangulos).
 * En los modelos "multi" la parte entera de u elige la textura: 0 = lados, 1 = arriba, 2 = abajo.
 */
typedef ModelData = {
	var v : Array<Float>;
	var multi : Bool;
	var box : { x1 : Float, y1 : Float, z1 : Float, x2 : Float, y2 : Float, z2 : Float };
}

class Models {

	static inline var TE = 0.999;
	static inline var STRIDE = 6;
	static var cache = new Map<Int, ModelData>();

	/** la malla de un bloque dibujado como modelo: la de su BFModel (MCross si no tiene), o la de su placa si es un tableau */
	public static function of( b : Block ) : ModelData {
		if( b.wall >= 0 && b.size != null ) return Painting.model(b);
		return get(b.model != null ? b.model : MCross);
	}

	public static function get( m : BlockModel ) : ModelData {
		var i = Type.enumIndex(m);
		var d = cache.get(i);
		if( d == null ) {
			d = build(m);
			cache.set(i, d);
		}
		return d;
	}

	/**
	 * Puerta abierta (Macro.getModel + Builder.load/flip): door.md = 1 byte, numero de vertices (entero de 32 bits) y 6 decimales por
	 * vertice (x, y, z, u, v, sombra). La variante Y es la X con los ejes cambiados y el orden de cada cara corregido.
	 */
	static function loadDoor( flip : Bool ) : { v : Array<Float>, box : { x1 : Float, y1 : Float, z1 : Float, x2 : Float, y2 : Float, z2 : Float } } {
		var i = new haxe.io.BytesInput(Res.bytes("door.md"));
		i.readByte();
		var count = i.readInt32();
		var raw = [for( _ in 0...count * 6 ) i.readFloat()];
		var out = new Array<Float>();
		if( !flip )
			out = raw;
		else {
			// cada cara son 4 vertices: se emiten en el orden 0, 2, 1, 3 con x e y intercambiados
			for( q in 0...Std.int(count / 4) )
				for( k in [0, 2, 1, 3] ) {
					var o = (q * 4 + k) * 6;
					out.push(raw[o + 1]);
					out.push(raw[o]);
					out.push(raw[o + 2]);
					out.push(raw[o + 3]);
					out.push(raw[o + 4]);
					out.push(raw[o + 5]);
				}
		}
		var x1 = 1., y1 = 1., z1 = 1., x2 = 0., y2 = 0., z2 = 0.;
		for( k in 0...Std.int(out.length / 6) ) {
			var x = out[k * 6], y = out[k * 6 + 1], z = out[k * 6 + 2];
			if( x < x1 ) x1 = x;
			if( y < y1 ) y1 = y;
			if( z < z1 ) z1 = z;
			if( x > x2 ) x2 = x;
			if( y > y2 ) y2 = y;
			if( z > z2 ) z2 = z;
		}
		return { v : out, box : { x1 : x1, y1 : y1, z1 : z1, x2 : x2, y2 : y2, z2 : z2 } };
	}

	static function build( m : BlockModel ) : ModelData {
		var v = new Array<Float>();
		var multi = false;
		var size = null;
		// sombras por defecto de Block (el original usa un Block vacio para los cubos de los modelos)
		var shadeX = 0.8, shadeY = 0.68, shadeUp = 1.0, shadeDown = 0.5;

		function addVert( x : Float, y : Float, z : Float, tu : Float, tv : Float, t = 0, s = 1.0 ) {
			v.push(x);
			v.push(y);
			v.push(z);
			v.push(tu * TE * (1 / 64) + t);
			v.push((1 - tv) * TE * (1 / 64));
			v.push(s);
		}

		function addCube( x : Float, y : Float, z : Float, x2 : Float, y2 : Float, z2 : Float, u = 1., v_ = 1., u2 = 1., v2 = 1. ) {
			// arriba
			addVert(x, y, z2, 0, 0, 1, shadeUp);
			addVert(x2, y, z2, 0, v_, 1, shadeUp);
			addVert(x, y2, z2, u, 0, 1, shadeUp);
			addVert(x2, y2, z2, u, v_, 1, shadeUp);
			// abajo
			addVert(x, y, z, 0, 0, 2, shadeDown);
			addVert(x, y2, z, u, 0, 2, shadeDown);
			addVert(x2, y, z, 0, v_, 2, shadeDown);
			addVert(x2, y2, z, u, v_, 2, shadeDown);
			// 4 lados
			addVert(x, y, z, 0, 0, 0, shadeX);
			addVert(x, y, z2, 0, v2, 0, shadeX);
			addVert(x, y2, z, u2, 0, 0, shadeX);
			addVert(x, y2, z2, u2, v2, 0, shadeX);

			addVert(x, y2, z, 0, 0, 0, shadeY);
			addVert(x, y2, z2, 0, v2, 0, shadeY);
			addVert(x2, y2, z, u2, 0, 0, shadeY);
			addVert(x2, y2, z2, u2, v2, 0, shadeY);

			addVert(x2, y, z, u2, 0, 0, shadeX);
			addVert(x2, y2, z, 0, 0, 0, shadeX);
			addVert(x2, y, z2, u2, v2, 0, shadeX);
			addVert(x2, y2, z2, 0, v2, 0, shadeX);

			addVert(x, y, z, u2, 0, 0, shadeY);
			addVert(x2, y, z, 0, 0, 0, shadeY);
			addVert(x, y, z2, u2, v2, 0, shadeY);
			addVert(x2, y, z2, 0, v2, 0, shadeY);

			return { x1 : x, y1 : y, z1 : z, x2 : x2, y2 : y2, z2 : z2 };
		}

		switch( m ) {
		case MCross:
			addVert(0, 0, 0, 0, 0);
			addVert(0, 0, 1, 0, 1);
			addVert(1, 1, 0, 1, 0);
			addVert(1, 1, 1, 1, 1);

			addVert(0, 1, 0, 0, 0);
			addVert(0, 1, 1, 0, 1);
			addVert(1, 0, 0, 1, 0);
			addVert(1, 0, 1, 1, 1);
		case MPlanX:
			addVert(0.5, 0, 0, 0, 0);
			addVert(0.5, 0, 1, 0, 1);
			addVert(0.5, 1, 0, 1, 0);
			addVert(0.5, 1, 1, 1, 1);
			size = { x1 : 0.45, y1 : 0., z1 : 0., x2 : 0.55, y2 : 1., z2 : 1. };
		case MPlanY:
			addVert(0, 0.5, 0, 0, 0);
			addVert(0, 0.5, 1, 0, 1);
			addVert(1, 0.5, 0, 1, 0);
			addVert(1, 0.5, 1, 1, 1);
			size = { x1 : 0., y1 : 0.45, z1 : 0., x2 : 1., y2 : 0.55, z2 : 1. };
		case MPlanZ:
			addVert(0, 0, 0.5, 0, 0);
			addVert(0, 1, 0.5, 0, 1);
			addVert(1, 0, 0.5, 1, 0);
			addVert(1, 1, 0.5, 1, 1);
			size = { x1 : 0., y1 : 0., z1 : 0.45, x2 : 1., y2 : 1., z2 : 0.55 };
		case MHalf:
			size = addCube(0, 0, 0, 1, 1, 0.5, 1, 1, 1, 0.5);
			multi = true;
		case MMini:
			size = addCube(0.25, 0.25, 0, 0.75, 0.75, 0.5);
			multi = true;
		case MMiniTop:
			var start = v.length;
			size = addCube(0.2, 0.2, 0.4, 0.8, 0.8, 1);
			// sin sombras
			var p = start;
			for( _ in 0...6 * 4 ) {
				v[p + 5] = 1.0;
				p += STRIDE;
			}
			multi = true;
		case MColumn:
			var w = 8 / 32;
			var p = v.length;
			size = addCube(0.35, 0.35, 0, 0.65, 0.65, 1, w, w, w, 1);
			// u envuelto
			p += STRIDE * 8;
			for( k in 0...4 * 4 ) {
				v[p + 3] += w * Std.int(k / 4) * 1 / 64;
				p += STRIDE;
			}
			multi = true;
		case MBigColumn:
			var p = v.length;
			size = addCube(0.25, 0.25, 0, 0.75, 0.75, 1, 0.5, 0.5, 0.5, 1);
			p += STRIDE * 8;
			for( k in 0...4 ) {
				v[p + 3] += 0.5 * 1 / 64;
				p += STRIDE;
			}
			p += STRIDE * 4;
			for( k in 0...4 ) {
				v[p + 3] += 0.5 * 1 / 64;
				p += STRIDE;
			}
			multi = true;
		case MPipeX, MPipeY:
			var w = 8 / 32;
			var p = v.length;
			var start = p;
			size = addCube(0.35, 0.35, 0, 0.65, 0.65, 1, w, w, w, 1);
			p += STRIDE * 8;
			for( k in 0...4 ) {
				v[p + 3] += w * Std.int(k / 4) * 1 / 64;
				p += STRIDE;
			}
			// ejes invertidos
			p = start;
			for( k in 0...6 * 4 ) {
				if( m == MPipeX ) {
					var x = v[p];
					v[p] = 1 - v[p + 2];
					v[p + 2] = x;
				} else {
					var y = v[p + 1];
					v[p + 1] = 1 - v[p + 2];
					v[p + 2] = y;
				}
				p += STRIDE;
			}
			multi = true;
		case MDoorOpenX, MDoorOpenY:
			var door = loadDoor(m == MDoorOpenY);
			for( f in door.v ) v.push(f);
			size = door.box;
			// (la caja sale del propio modelo)
		case MCrossSquare:
			addVert(0.25, 0, 0, 0, 0);
			addVert(0.25, 0, 1, 0, 1);
			addVert(0.25, 1, 0, 1, 0);
			addVert(0.25, 1, 1, 1, 1);

			addVert(0.75, 0, 0, 0, 0);
			addVert(0.75, 0, 1, 0, 1);
			addVert(0.75, 1, 0, 1, 0);
			addVert(0.75, 1, 1, 1, 1);

			addVert(0, 0.25, 0, 0, 0);
			addVert(0, 0.25, 1, 0, 1);
			addVert(1, 0.25, 0, 1, 0);
			addVert(1, 0.25, 1, 1, 1);

			addVert(0, 0.75, 0, 0, 0);
			addVert(0, 0.75, 1, 0, 1);
			addVert(1, 0.75, 0, 1, 0);
			addVert(1, 0.75, 1, 1, 1);
		case MCrossBox:
			addVert(0, 0, 0, 0, 0);
			addVert(0, 0, 1, 0, 1);
			addVert(0, 1, 0, 1, 0);
			addVert(0, 1, 1, 1, 1);

			addVert(1, 0, 0, 0, 0);
			addVert(1, 0, 1, 0, 1);
			addVert(1, 1, 0, 1, 0);
			addVert(1, 1, 1, 1, 1);

			addVert(0, 0, 0, 0, 0);
			addVert(0, 0, 1, 0, 1);
			addVert(1, 0, 0, 1, 0);
			addVert(1, 0, 1, 1, 1);

			addVert(0, 1, 0, 0, 0);
			addVert(0, 1, 1, 0, 1);
			addVert(1, 1, 0, 1, 0);
			addVert(1, 1, 1, 1, 1);

			addVert(0, 0, 0, 0, 0);
			addVert(0, 1, 0, 0, 1);
			addVert(1, 0, 0, 1, 0);
			addVert(1, 1, 0, 1, 1);

			addVert(0, 0, 1, 0, 0);
			addVert(0, 1, 1, 0, 1);
			addVert(1, 0, 1, 1, 0);
			addVert(1, 1, 1, 1, 1);

			// cruz
			multi = true;
			addVert(0, 0, 0, 0, 0, 1);
			addVert(0, 0, 1, 0, 1, 1);
			addVert(1, 1, 0, 1, 0, 1);
			addVert(1, 1, 1, 1, 1, 1);

			addVert(0, 1, 0, 0, 0, 1);
			addVert(0, 1, 1, 0, 1, 1);
			addVert(1, 0, 0, 1, 0, 1);
			addVert(1, 0, 1, 1, 1, 1);
		case MCrossPyramid:
			addVert(0.1, 0, 0, 0, 0);
			addVert(0.5, 0, 1, 0, 1);
			addVert(0.1, 1, 0, 1, 0);
			addVert(0.5, 1, 1, 1, 1);

			addVert(0.9, 0, 0, 0, 0);
			addVert(0.5, 0, 1, 0, 1);
			addVert(0.9, 1, 0, 1, 0);
			addVert(0.5, 1, 1, 1, 1);

			addVert(0, 0.1, 0, 0, 0);
			addVert(0, 0.5, 1, 0, 1);
			addVert(1, 0.1, 0, 1, 0);
			addVert(1, 0.5, 1, 1, 1);

			addVert(0, 0.9, 0, 0, 0);
			addVert(0, 0.5, 1, 0, 1);
			addVert(1, 0.9, 0, 1, 0);
			addVert(1, 0.5, 1, 1, 1);
		}
		return { v : v, multi : multi, box : size };
	}
}
