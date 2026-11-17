import Common;
import Models.ModelData;

typedef PaintingBox = { x1 : Float, y1 : Float, z1 : Float, x2 : Float, y2 : Float, z2 : Float };

/**
 * Tableau colgado de una pared (anadido del port, BFOnWall): una placa pegada a uno de los 4 lados de su celda, como el neon pegado
 * al techo. La cara de delante muestra la parte de su casilla del atlas que queda dentro de la placa (el mismo recorte que ve el
 * jugador mirandola de frente, sin dar la vuelta a la imagen) y sus cuatro cantos los pixeles del borde de esa parte, como el
 * grosor de un marco. La de atras no se dibuja: esta contra la pared, y las mallas de los modelos se ven por los dos lados.
 * - Son 4 bloques seguidos (Block.wall): el primero tiene la pared en +y y cada uno es el anterior girado un cuarto de vuelta.
 * - Sus cajas (BFSize) son las de la placa; un tableau se apunta, se ve resaltado y choca (si no es atravesable) con ella.
 * - Se dibuja como un modelo (BTModel, Models.of): deja pasar la luz y el agua o la lava lo rompen, como las plantas.
 * - En el editor de kubes la caja va en pixeles de la imagen vista de frente (editorBox): x de izquierda a derecha, y el grosor
 *   desde la pared y z de abajo arriba.
 */
class Painting {

	static inline var TE = 0.999;
	static inline var S = 32;
	static var cache = new Map<Int, { size : PaintingBox, wall : Int, data : ModelData }>();

	/** la caja b girada t cuartos de vuelta alrededor del centro de la celda: la pared pasa de +y a -x, a -y y a +x */
	public static function turn( b : PaintingBox, t : Int ) : PaintingBox {
		for( _ in 0...(t & 3) ) b = { x1 : 1 - b.y2, y1 : b.x1, z1 : b.z1, x2 : 1 - b.y1, y2 : b.x2, z2 : b.z2 };
		return b;
	}

	/**
	 * Cajas de los 4 bloques de un tableau a partir de la del editor (pixeles de la imagen vista de frente: columnas x1..x2,
	 * grosor y1..y2 desde la pared, alturas z1..z2). El primero tiene la pared detras en +y y se mira hacia +y, con -x a la
	 * derecha (camara de Heaps).
	 */
	public static function sizes( box : Array<Int> ) : Array<PaintingBox> {
		var first = { x1 : 1 - box[3] / S, y1 : 1 - box[4] / S, z1 : box[2] / S, x2 : 1 - box[0] / S, y2 : 1 - box[1] / S, z2 : box[5] / S };
		return [for( t in 0...4 ) turn(first, t)];
	}

	/** la caja del editor (sizes al reves) de un bloque de tableau */
	public static function editorBox( b : Block ) : Array<Int> {
		var c = turn(b.size, 4 - b.wall);
		inline function px( v : Float ) return Math.round(v * S);
		return [px(1 - c.x2), px(1 - c.y2), px(c.z1), px(1 - c.x1), px(1 - c.y1), px(c.z2)];
	}

	/**
	 * El bloque que se dibuja en la mano (Hand): de un tableau, el giro con la pared en -y, que con el giro de 120 grados de la mano
	 * mira a su camara (el primero se veria por detras). Los demas bloques, ellos mismos
	 */
	public static function inHand( b : Block ) : Block return b.wall >= 0 ? Block.all[b.index - b.wall + 2] : b;

	/**
	 * Punto de la celda que va en el centro de la mano (Hand) o en el eje de giro de un bloque suelto (Drops): el de la placa de
	 * un tableau, que si no quedaba en un borde de la celda; el centro de la celda para los demas
	 */
	public static function center( b : Block ) : h3d.col.Point {
		if( b.wall < 0 || b.size == null ) return new h3d.col.Point(0.5, 0.5, 0.5);
		var s = b.size;
		return new h3d.col.Point((s.x1 + s.x2) * 0.5, (s.y1 + s.y2) * 0.5, (s.z1 + s.z2) * 0.5);
	}

	/** malla del tableau en el formato de los modelos (Models.ModelData), hecha una vez por bloque */
	public static function model( b : Block ) : ModelData {
		var c = cache.get(b.index);
		if( c != null && c.size == b.size && c.wall == b.wall ) return c.data;
		var data = build(b);
		cache.set(b.index, { size : b.size, wall : b.wall, data : data });
		return data;
	}

	static function build( b : Block ) : ModelData {
		var t = b.wall & 3;
		// la placa como en el primer bloque: pared en y2 (= 1), cara de delante en y1
		var p = turn(b.size, 4 - t);
		var v = new Array<Float>();
		var sx = Math.sqrt(b.shadeX), sy = Math.sqrt(b.shadeY), su = Math.sqrt(b.shadeUp), sd = Math.sqrt(b.shadeDown);
		// vista de frente: la columna de la imagen crece hacia -x, la fila hacia abajo; medio pixel para los cantos
		inline function col( x : Float ) return 1 - x;
		inline function row( z : Float ) return 1 - z;
		var half = 0.5 / S;
		function vert( x : Float, y : Float, z : Float, u : Float, w : Float, shade : Float ) {
			for( _ in 0...t ) {
				var nx = 1 - y;
				y = x;
				x = nx;
			}
			v.push(x);
			v.push(y);
			v.push(z);
			v.push(Math.max(0, Math.min(1, u)) * TE / 64);
			v.push(Math.max(0, Math.min(1, w)) * TE / 64);
			v.push(shade);
		}
		// la sombra de cada cara segun hacia donde mira despues de girar: las de +-y del primero pasan a +-x en los giros impares
		var odd = t & 1 == 1;
		var front = odd ? sx : sy, edge = odd ? sy : sx;
		// delante (y = p.y1)
		vert(p.x1, p.y1, p.z1, col(p.x1), row(p.z1), front);
		vert(p.x1, p.y1, p.z2, col(p.x1), row(p.z2), front);
		vert(p.x2, p.y1, p.z1, col(p.x2), row(p.z1), front);
		vert(p.x2, p.y1, p.z2, col(p.x2), row(p.z2), front);
		// arriba: la fila de pixeles de arriba
		var r = row(p.z2) + half;
		vert(p.x1, p.y1, p.z2, col(p.x1), r, su);
		vert(p.x1, p.y2, p.z2, col(p.x1), r, su);
		vert(p.x2, p.y1, p.z2, col(p.x2), r, su);
		vert(p.x2, p.y2, p.z2, col(p.x2), r, su);
		// abajo: la de abajo
		r = row(p.z1) - half;
		vert(p.x1, p.y1, p.z1, col(p.x1), r, sd);
		vert(p.x1, p.y2, p.z1, col(p.x1), r, sd);
		vert(p.x2, p.y1, p.z1, col(p.x2), r, sd);
		vert(p.x2, p.y2, p.z1, col(p.x2), r, sd);
		// los lados: la columna de cada borde (x1 es la de la derecha vista de frente)
		var k = col(p.x1) - half;
		vert(p.x1, p.y1, p.z1, k, row(p.z1), edge);
		vert(p.x1, p.y1, p.z2, k, row(p.z2), edge);
		vert(p.x1, p.y2, p.z1, k, row(p.z1), edge);
		vert(p.x1, p.y2, p.z2, k, row(p.z2), edge);
		k = col(p.x2) + half;
		vert(p.x2, p.y1, p.z1, k, row(p.z1), edge);
		vert(p.x2, p.y1, p.z2, k, row(p.z2), edge);
		vert(p.x2, p.y2, p.z1, k, row(p.z1), edge);
		vert(p.x2, p.y2, p.z2, k, row(p.z2), edge);
		return { v : v, multi : false, box : b.size };
	}
}
