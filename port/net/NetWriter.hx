import haxe.io.Bytes;

/**
 * Escritura de los mensajes del multijugador (anadido del port): enteros de longitud variable (varint, zigzag para los que
 * pueden ser negativos), reales de 32 bits, cadenas UTF-8 y bytes con su longitud delante. Lo lee NetReader.
 */
class NetWriter {

	var buf : Bytes;
	public var length(default, null) = 0;

	public function new( size = 256 ) {
		buf = Bytes.alloc(size);
	}

	inline function need( n : Int ) {
		if( length + n <= buf.length ) return;
		var nb = Bytes.alloc(Std.int(Math.max(buf.length * 2, length + n)));
		nb.blit(0, buf, 0, length);
		buf = nb;
	}

	public function byte( v : Int ) {
		need(1);
		buf.set(length++, v);
	}

	public inline function bool( v : Bool ) byte(v ? 1 : 0);

	/** entero sin signo de 0 a 2^31-1, 1 a 5 bytes */
	public function uint( v : Int ) {
		if( v < 0 ) throw "NetWriter.uint negativo: " + v;
		need(5);
		while( v >= 0x80 ) {
			buf.set(length++, (v & 0x7F) | 0x80);
			v >>>= 7;
		}
		buf.set(length++, v);
	}

	/** entero con signo (zigzag) */
	public inline function int( v : Int ) {
		var z = (v << 1) ^ (v >> 31);
		need(5);
		while( (z & ~0x7F) != 0 ) {
			buf.set(length++, (z & 0x7F) | 0x80);
			z >>>= 7;
		}
		buf.set(length++, z);
	}

	public function float( v : Float ) {
		need(4);
		buf.setFloat(length, v);
		length += 4;
	}

	public function double( v : Float ) {
		need(8);
		buf.setDouble(length, v);
		length += 8;
	}

	public function string( s : String ) {
		var b = Bytes.ofString(s == null ? "" : s);
		bytes(b);
	}

	public function bytes( b : Bytes ) {
		uint(b.length);
		need(b.length);
		buf.blit(length, b, 0, b.length);
		length += b.length;
	}

	/** bytes sin longitud delante (tamano fijo que conoce el lector: claves, firmas) */
	public function raw( b : Bytes ) {
		need(b.length);
		buf.blit(length, b, 0, b.length);
		length += b.length;
	}

	public function getBytes() : Bytes return buf.sub(0, length);

	public function reset() length = 0;
}
