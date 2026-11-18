import haxe.io.Bytes;

/** Error de un mensaje mal formado: la conexion que lo envia se cierra. */
class NetError {
	public var msg : String;
	public function new( msg : String ) this.msg = msg;
	public function toString() return "NetError: " + msg;
}

/**
 * Lectura de los mensajes del multijugador (anadido del port), lo que escribe NetWriter. Nada se fia del otro lado: cada
 * longitud se comprueba contra lo que queda y contra el maximo que se pide ANTES de reservar memoria, cada cadena contra su
 * maximo de caracteres; cualquier fallo lanza NetError y la conexion se cierra.
 */
class NetReader {

	var buf : Bytes;
	var pos : Int;
	var end : Int;

	public function new( b : Bytes, pos = 0, ?len : Int ) {
		buf = b;
		this.pos = pos;
		end = len == null ? b.length : pos + len;
		if( end > b.length ) throw new NetError("longitud fuera del mensaje");
	}

	public inline function left() return end - pos;

	public function done() {
		if( pos != end ) throw new NetError("sobran " + (end - pos) + " bytes");
	}

	public function byte() : Int {
		if( pos >= end ) throw new NetError("mensaje corto");
		return buf.get(pos++);
	}

	public function bool() : Bool {
		var v = byte();
		if( v > 1 ) throw new NetError("booleano invalido");
		return v == 1;
	}

	public function uint() : Int {
		var v = 0, shift = 0;
		while( true ) {
			var b = byte();
			if( shift == 28 && b > 7 ) throw new NetError("entero demasiado grande");
			v |= (b & 0x7F) << shift;
			if( b & 0x80 == 0 ) break;
			shift += 7;
			if( shift > 28 ) throw new NetError("entero demasiado largo");
		}
		return v;
	}

	/** entero sin signo entre min y max */
	public function uintIn( min : Int, max : Int ) : Int {
		var v = uint();
		if( v < min || v > max ) throw new NetError('valor $v fuera de $min..$max');
		return v;
	}

	public function int() : Int {
		var z = 0, shift = 0;
		while( true ) {
			var b = byte();
			z |= (b & 0x7F) << shift;
			if( b & 0x80 == 0 ) break;
			shift += 7;
			if( shift > 28 ) throw new NetError("entero demasiado largo");
		}
		return (z >>> 1) ^ -(z & 1);
	}

	public function intIn( min : Int, max : Int ) : Int {
		var v = int();
		if( v < min || v > max ) throw new NetError('valor $v fuera de $min..$max');
		return v;
	}

	public function float() : Float {
		if( end - pos < 4 ) throw new NetError("mensaje corto");
		var v = buf.getFloat(pos);
		pos += 4;
		if( Math.isNaN(v) || !Math.isFinite(v) ) throw new NetError("real invalido");
		return v;
	}

	/** real entre min y max */
	public function floatIn( min : Float, max : Float ) : Float {
		var v = float();
		if( v < min || v > max ) throw new NetError('real $v fuera de $min..$max');
		return v;
	}

	public function double() : Float {
		if( end - pos < 8 ) throw new NetError("mensaje corto");
		var v = buf.getDouble(pos);
		pos += 8;
		if( Math.isNaN(v) || !Math.isFinite(v) ) throw new NetError("real invalido");
		return v;
	}

	/** cadena UTF-8 de hasta maxChars caracteres (y como mucho 4 bytes por caracter) */
	public function string( maxChars : Int ) : String {
		var n = uint();
		if( n > maxChars * 4 || n > end - pos ) throw new NetError("cadena demasiado larga");
		var chars = utf8Chars(buf, pos, n);
		if( chars < 0 ) throw new NetError("cadena UTF-8 invalida");
		if( chars > maxChars ) throw new NetError("cadena demasiado larga");
		var s = buf.getString(pos, n);
		pos += n;
		return s;
	}

	/** caracteres de una secuencia UTF-8 bien formada (sin sobrelargas ni sustitutos), -1 si no lo es */
	public static function utf8Chars( b : Bytes, p : Int, n : Int ) : Int {
		var e = p + n, chars = 0;
		while( p < e ) {
			var c = b.get(p++);
			chars++;
			if( c < 0x80 ) continue;
			var more = 0, min = 0, cp = 0;
			if( c & 0xE0 == 0xC0 ) { more = 1; min = 0x80; cp = c & 0x1F; }
			else if( c & 0xF0 == 0xE0 ) { more = 2; min = 0x800; cp = c & 0x0F; }
			else if( c & 0xF8 == 0xF0 ) { more = 3; min = 0x10000; cp = c & 0x07; }
			else return -1;
			if( p + more > e ) return -1;
			for( _ in 0...more ) {
				var d = b.get(p++);
				if( d & 0xC0 != 0x80 ) return -1;
				cp = (cp << 6) | (d & 0x3F);
			}
			if( cp < min || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) ) return -1;
		}
		return chars;
	}

	/** bytes con su longitud delante, como mucho maxLen */
	public function bytes( maxLen : Int ) : Bytes {
		var n = uint();
		if( n > maxLen || n > end - pos ) throw new NetError("bloque de bytes demasiado largo");
		var b = buf.sub(pos, n);
		pos += n;
		return b;
	}

	/** exactamente n bytes (claves, firmas) */
	public function raw( n : Int ) : Bytes {
		if( n > end - pos ) throw new NetError("mensaje corto");
		var b = buf.sub(pos, n);
		pos += n;
		return b;
	}

	/** numero de elementos de una lista, como mucho max (y cada uno ocupa al menos minBytes) */
	public function count( max : Int, minBytes = 1 ) : Int {
		var n = uint();
		if( n > max || n * minBytes > end - pos ) throw new NetError("lista demasiado larga");
		return n;
	}
}
