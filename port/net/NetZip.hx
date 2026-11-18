import haxe.io.Bytes;

/**
 * Compresion de lo que viaja grande en el multijugador (anadido del port): partidas en JSON y cambios del terreno. La
 * descompresion tiene un tope: lo que pasa de max se corta y lanza NetError (una bomba zlib no llena la memoria).
 */
class NetZip {

	public static function deflate( b : Bytes ) : Bytes return haxe.zip.Compress.run(b, 6);

	public static function inflate( b : Bytes, max : Int ) : Bytes {
		var u = new haxe.zip.Uncompress();
		var out = new haxe.io.BytesBuffer();
		var buf = Bytes.alloc(1 << 16);
		var pos = 0;
		try {
			while( true ) {
				var r = u.execute(b, pos, buf, 0);
				pos += r.read;
				if( r.write > 0 ) {
					if( out.length + r.write > max ) throw new NetReader.NetError("datos comprimidos demasiado grandes");
					out.addBytes(buf, 0, r.write);
				}
				if( r.done ) break;
				if( r.read == 0 && r.write == 0 ) throw new NetReader.NetError("datos comprimidos cortados");
			}
		} catch( e : NetReader.NetError ) {
			u.close();
			throw e;
		} catch( e : Dynamic ) {
			u.close();
			throw new NetReader.NetError("datos comprimidos invalidos: " + e);
		}
		u.close();
		return out.getBytes();
	}

	public static function packInts( a : Array<Int> ) : Bytes {
		var b = Bytes.alloc(a.length * 4);
		for( i in 0...a.length ) b.setInt32(i * 4, a[i]);
		return deflate(b);
	}

	public static function unpackInts( z : Bytes, max : Int ) : Array<Int> {
		var b = inflate(z, max * 4);
		if( b.length % 4 != 0 ) throw new NetReader.NetError("lista de enteros mal formada");
		return [for( i in 0...b.length >> 2 ) b.getInt32(i * 4)];
	}

	public static function packString( s : String ) : Bytes return deflate(Bytes.ofString(s));

	public static function unpackString( z : Bytes, max : Int ) : String {
		var b = inflate(z, max);
		if( NetReader.utf8Chars(b, 0, b.length) < 0 ) throw new NetReader.NetError("texto UTF-8 invalido");
		return b.toString();
	}
}
