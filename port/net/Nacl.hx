import haxe.io.Bytes;
import haxe.ds.Vector;
import haxe.Int64;

/**
 * Criptografia del multijugador (anadido del port): port a Haxe de TweetNaCl (tweetnacl-js, dominio publico). SHA-512,
 * Ed25519 (firmas), X25519 (intercambio de claves), HSalsa20/XSalsa20 y Poly1305 (secretbox). Comprobado con los vectores de
 * las RFC 8032, 7748 y 8439 y los de NaCl en port/headless/CryptoTest.hx.
 * No comprueba que S < L en las firmas (como TweetNaCl): una firma valida puede tener otra forma, sin falsificar nada.
 */
class Nacl {

	public static inline var SIGN_PK = 32;
	public static inline var SIGN_SK = 64;
	public static inline var SIGN_SEED = 32;
	public static inline var SIGNATURE = 64;
	public static inline var DH = 32;
	public static inline var KEY = 32;
	public static inline var NONCE = 24;
	public static inline var TAG = 16;

	// ---------------------------------------------------------------- SHA-512

	static var K512 : Vector<Int64> = initK512();
	static var H512 = [
		0x6a09e667, 0xf3bcc908, 0xbb67ae85, 0x84caa73b, 0x3c6ef372, 0xfe94f82b, 0xa54ff53a, 0x5f1d36f1,
		0x510e527f, 0xade682d1, 0x9b05688c, 0x2b3e6c1f, 0x1f83d9ab, 0xfb41bd6b, 0x5be0cd19, 0x137e2179,
	];

	static function initK512() : Vector<Int64> {
		var k = [
			0x428a2f98, 0xd728ae22, 0x71374491, 0x23ef65cd, 0xb5c0fbcf, 0xec4d3b2f, 0xe9b5dba5, 0x8189dbbc,
			0x3956c25b, 0xf348b538, 0x59f111f1, 0xb605d019, 0x923f82a4, 0xaf194f9b, 0xab1c5ed5, 0xda6d8118,
			0xd807aa98, 0xa3030242, 0x12835b01, 0x45706fbe, 0x243185be, 0x4ee4b28c, 0x550c7dc3, 0xd5ffb4e2,
			0x72be5d74, 0xf27b896f, 0x80deb1fe, 0x3b1696b1, 0x9bdc06a7, 0x25c71235, 0xc19bf174, 0xcf692694,
			0xe49b69c1, 0x9ef14ad2, 0xefbe4786, 0x384f25e3, 0x0fc19dc6, 0x8b8cd5b5, 0x240ca1cc, 0x77ac9c65,
			0x2de92c6f, 0x592b0275, 0x4a7484aa, 0x6ea6e483, 0x5cb0a9dc, 0xbd41fbd4, 0x76f988da, 0x831153b5,
			0x983e5152, 0xee66dfab, 0xa831c66d, 0x2db43210, 0xb00327c8, 0x98fb213f, 0xbf597fc7, 0xbeef0ee4,
			0xc6e00bf3, 0x3da88fc2, 0xd5a79147, 0x930aa725, 0x06ca6351, 0xe003826f, 0x14292967, 0x0a0e6e70,
			0x27b70a85, 0x46d22ffc, 0x2e1b2138, 0x5c26c926, 0x4d2c6dfc, 0x5ac42aed, 0x53380d13, 0x9d95b3df,
			0x650a7354, 0x8baf63de, 0x766a0abb, 0x3c77b2a8, 0x81c2c92e, 0x47edaee6, 0x92722c85, 0x1482353b,
			0xa2bfe8a1, 0x4cf10364, 0xa81a664b, 0xbc423001, 0xc24b8b70, 0xd0f89791, 0xc76c51a3, 0x0654be30,
			0xd192e819, 0xd6ef5218, 0xd6990624, 0x5565a910, 0xf40e3585, 0x5771202a, 0x106aa070, 0x32bbd1b8,
			0x19a4c116, 0xb8d2d0c8, 0x1e376c08, 0x5141ab53, 0x2748774c, 0xdf8eeb99, 0x34b0bcb5, 0xe19b48a8,
			0x391c0cb3, 0xc5c95a63, 0x4ed8aa4a, 0xe3418acb, 0x5b9cca4f, 0x7763e373, 0x682e6ff3, 0xd6b2b8a3,
			0x748f82ee, 0x5defb2fc, 0x78a5636f, 0x43172f60, 0x84c87814, 0xa1f0ab72, 0x8cc70208, 0x1a6439ec,
			0x90befffa, 0x23631e28, 0xa4506ceb, 0xde82bde9, 0xbef9a3f7, 0xb2c67915, 0xc67178f2, 0xe372532b,
			0xca273ece, 0xea26619c, 0xd186b8c7, 0x21c0c207, 0xeada7dd6, 0xcde0eb1e, 0xf57d4f7f, 0xee6ed178,
			0x06f067aa, 0x72176fba, 0x0a637dc5, 0xa2c898a6, 0x113f9804, 0xbef90dae, 0x1b710b35, 0x131c471b,
			0x28db77f5, 0x23047d84, 0x32caab7b, 0x40c72493, 0x3c9ebe0a, 0x15c9bebc, 0x431d67c4, 0x9c100d4c,
			0x4cc5d4be, 0xcb3e42b6, 0x597f299c, 0xfc657e2a, 0x5fcb6fab, 0x3ad6faec, 0x6c44198c, 0x4a475817,
		];
		var v = new Vector<Int64>(80);
		for( i in 0...80 ) v[i] = Int64.make(k[i * 2], k[i * 2 + 1]);
		return v;
	}

	static inline function rotr( x : Int64, n : Int ) : Int64 return (x >>> n) | (x << (64 - n));

	static inline function getI64( b : Bytes, p : Int ) : Int64 {
		var hi = (b.get(p) << 24) | (b.get(p + 1) << 16) | (b.get(p + 2) << 8) | b.get(p + 3);
		var lo = (b.get(p + 4) << 24) | (b.get(p + 5) << 16) | (b.get(p + 6) << 8) | b.get(p + 7);
		return Int64.make(hi, lo);
	}

	static inline function setI64( b : Bytes, p : Int, v : Int64 ) {
		var hi = v.high, lo = v.low;
		b.set(p, hi >>> 24); b.set(p + 1, hi >>> 16); b.set(p + 2, hi >>> 8); b.set(p + 3, hi);
		b.set(p + 4, lo >>> 24); b.set(p + 5, lo >>> 16); b.set(p + 6, lo >>> 8); b.set(p + 7, lo);
	}

	static function sha512Blocks( h : Vector<Int64>, m : Bytes, pos : Int, blocks : Int ) {
		var w = new Vector<Int64>(80);
		for( blk in 0...blocks ) {
			var p = pos + blk * 128;
			for( i in 0...16 ) w[i] = getI64(m, p + i * 8);
			for( i in 16...80 ) {
				var w2 = w[i - 2], w15 = w[i - 15];
				var s1 = rotr(w2, 19) ^ rotr(w2, 61) ^ (w2 >>> 6);
				var s0 = rotr(w15, 1) ^ rotr(w15, 8) ^ (w15 >>> 7);
				w[i] = s1 + w[i - 7] + s0 + w[i - 16];
			}
			var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
			for( i in 0...80 ) {
				var S1 = rotr(e, 14) ^ rotr(e, 18) ^ rotr(e, 41);
				var ch = (e & f) ^ (~e & g);
				var t1 = hh + S1 + ch + K512[i] + w[i];
				var S0 = rotr(a, 28) ^ rotr(a, 34) ^ rotr(a, 39);
				var maj = (a & b) ^ (a & c) ^ (b & c);
				var t2 = S0 + maj;
				hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
			}
			h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
		}
	}

	public static function sha512( m : Bytes, ?pos = 0, ?len = -1 ) : Bytes {
		if( len < 0 ) len = m.length - pos;
		var h = new Vector<Int64>(8);
		for( i in 0...8 ) h[i] = Int64.make(H512[i * 2], H512[i * 2 + 1]);
		var full = len >> 7;
		sha512Blocks(h, m, pos, full);
		var rest = len - (full << 7);
		var tail = Bytes.alloc(rest < 112 ? 128 : 256);
		tail.fill(0, tail.length, 0);
		tail.blit(0, m, pos + (full << 7), rest);
		tail.set(rest, 0x80);
		setI64(tail, tail.length - 8, Int64.make(len >>> 29, len << 3));
		sha512Blocks(h, tail, 0, tail.length >> 7);
		var out = Bytes.alloc(64);
		for( i in 0...8 ) setI64(out, i * 8, h[i]);
		return out;
	}

	// ---------------------------------------------------------------- Salsa20 / Poly1305

	static var SIGMA = Bytes.ofString("expand 32-byte k");

	static inline function L32( x : Int, c : Int ) : Int return (x << c) | (x >>> (32 - c));

	static function core( out : Bytes, inp : Bytes, inpPos : Int, k : Bytes, c : Bytes, h : Bool ) {
		var j0 = c.getInt32(0), j1 = k.getInt32(0), j2 = k.getInt32(4), j3 = k.getInt32(8), j4 = k.getInt32(12);
		var j5 = c.getInt32(4), j6 = inp.getInt32(inpPos), j7 = inp.getInt32(inpPos + 4), j8 = inp.getInt32(inpPos + 8);
		var j9 = inp.getInt32(inpPos + 12), j10 = c.getInt32(8), j11 = k.getInt32(16), j12 = k.getInt32(20);
		var j13 = k.getInt32(24), j14 = k.getInt32(28), j15 = c.getInt32(12);
		var x0 = j0, x1 = j1, x2 = j2, x3 = j3, x4 = j4, x5 = j5, x6 = j6, x7 = j7;
		var x8 = j8, x9 = j9, x10 = j10, x11 = j11, x12 = j12, x13 = j13, x14 = j14, x15 = j15;
		for( r in 0...10 ) {
			x4 ^= L32(x0 + x12, 7); x8 ^= L32(x4 + x0, 9); x12 ^= L32(x8 + x4, 13); x0 ^= L32(x12 + x8, 18);
			x9 ^= L32(x5 + x1, 7); x13 ^= L32(x9 + x5, 9); x1 ^= L32(x13 + x9, 13); x5 ^= L32(x1 + x13, 18);
			x14 ^= L32(x10 + x6, 7); x2 ^= L32(x14 + x10, 9); x6 ^= L32(x2 + x14, 13); x10 ^= L32(x6 + x2, 18);
			x3 ^= L32(x15 + x11, 7); x7 ^= L32(x3 + x15, 9); x11 ^= L32(x7 + x3, 13); x15 ^= L32(x11 + x7, 18);
			x1 ^= L32(x0 + x3, 7); x2 ^= L32(x1 + x0, 9); x3 ^= L32(x2 + x1, 13); x0 ^= L32(x3 + x2, 18);
			x6 ^= L32(x5 + x4, 7); x7 ^= L32(x6 + x5, 9); x4 ^= L32(x7 + x6, 13); x5 ^= L32(x4 + x7, 18);
			x11 ^= L32(x10 + x9, 7); x8 ^= L32(x11 + x10, 9); x9 ^= L32(x8 + x11, 13); x10 ^= L32(x9 + x8, 18);
			x12 ^= L32(x15 + x14, 7); x13 ^= L32(x12 + x15, 9); x14 ^= L32(x13 + x12, 13); x15 ^= L32(x14 + x13, 18);
		}
		if( h ) {
			out.setInt32(0, x0); out.setInt32(4, x5); out.setInt32(8, x10); out.setInt32(12, x15);
			out.setInt32(16, x6); out.setInt32(20, x7); out.setInt32(24, x8); out.setInt32(28, x9);
		} else {
			out.setInt32(0, x0 + j0); out.setInt32(4, x1 + j1); out.setInt32(8, x2 + j2); out.setInt32(12, x3 + j3);
			out.setInt32(16, x4 + j4); out.setInt32(20, x5 + j5); out.setInt32(24, x6 + j6); out.setInt32(28, x7 + j7);
			out.setInt32(32, x8 + j8); out.setInt32(36, x9 + j9); out.setInt32(40, x10 + j10); out.setInt32(44, x11 + j11);
			out.setInt32(48, x12 + j12); out.setInt32(52, x13 + j13); out.setInt32(56, x14 + j14); out.setInt32(60, x15 + j15);
		}
	}

	/** HSalsa20: 32 bytes de salida a partir de 16 de entrada y una clave */
	public static function hsalsa20( inp : Bytes, inpPos : Int, k : Bytes ) : Bytes {
		var out = Bytes.alloc(32);
		core(out, inp, inpPos, k, SIGMA, true);
		return out;
	}

	static function salsa20Xor( c : Bytes, cpos : Int, m : Null<Bytes>, mpos : Int, b : Int, n : Bytes, npos : Int, k : Bytes ) {
		var z = Bytes.alloc(16), x = Bytes.alloc(64);
		z.fill(0, 16, 0);
		for( i in 0...8 ) z.set(i, n.get(npos + i));
		while( b >= 64 ) {
			core(x, z, 0, k, SIGMA, false);
			if( m != null ) {
				var i = 0;
				while( i < 64 ) {
					c.setInt32(cpos + i, m.getInt32(mpos + i) ^ x.getInt32(i));
					i += 4;
				}
			} else
				c.blit(cpos, x, 0, 64);
			var u = 1;
			for( i in 8...16 ) {
				u = u + z.get(i);
				z.set(i, u & 0xff);
				u >>>= 8;
			}
			b -= 64;
			cpos += 64;
			if( m != null ) mpos += 64;
		}
		if( b > 0 ) {
			core(x, z, 0, k, SIGMA, false);
			for( i in 0...b ) c.set(cpos + i, (m != null ? m.get(mpos + i) : 0) ^ x.get(i));
		}
	}

	/** XSalsa20: cifra (o descifra) len bytes de m con el nonce de 24 bytes */
	public static function xsalsa20Xor( c : Bytes, cpos : Int, m : Null<Bytes>, mpos : Int, len : Int, n : Bytes, k : Bytes ) {
		var s = hsalsa20(n, 0, k);
		salsa20Xor(c, cpos, m, mpos, len, n, 16, s);
	}

	static inline function mul( a : Int, b : Int ) : Int64 return Int64.ofInt(a) * Int64.ofInt(b);

	/** Poly1305 (version poly1305-donna de 26 bits): etiqueta de 16 bytes de m[mpos..mpos+n] con la clave de un solo uso k */
	public static function poly1305( out : Bytes, outpos : Int, m : Bytes, mpos : Int, n : Int, k : Bytes, kpos : Int ) {
		var r0 = k.getInt32(kpos) & 0x3ffffff;
		var r1 = (k.getInt32(kpos + 3) >>> 2) & 0x3ffff03;
		var r2 = (k.getInt32(kpos + 6) >>> 4) & 0x3ffc0ff;
		var r3 = (k.getInt32(kpos + 9) >>> 6) & 0x3f03fff;
		var r4 = (k.getInt32(kpos + 12) >>> 8) & 0x00fffff;
		var s1 = r1 * 5, s2 = r2 * 5, s3 = r3 * 5, s4 = r4 * 5;
		var h0 = 0, h1 = 0, h2 = 0, h3 = 0, h4 = 0;
		var block = Bytes.alloc(16);
		var mask = 0x3ffffff;
		while( n > 0 ) {
			var src = m, p = mpos, hibit = 1 << 24;
			if( n < 16 ) {
				block.fill(0, 16, 0);
				block.blit(0, m, mpos, n);
				block.set(n, 1);
				src = block;
				p = 0;
				hibit = 0;
			}
			h0 += src.getInt32(p) & mask;
			h1 += (src.getInt32(p + 3) >>> 2) & mask;
			h2 += (src.getInt32(p + 6) >>> 4) & mask;
			h3 += (src.getInt32(p + 9) >>> 6) & mask;
			h4 += (src.getInt32(p + 12) >>> 8) | hibit;
			var d0 = mul(h0, r0) + mul(h1, s4) + mul(h2, s3) + mul(h3, s2) + mul(h4, s1);
			var d1 = mul(h0, r1) + mul(h1, r0) + mul(h2, s4) + mul(h3, s3) + mul(h4, s2);
			var d2 = mul(h0, r2) + mul(h1, r1) + mul(h2, r0) + mul(h3, s4) + mul(h4, s3);
			var d3 = mul(h0, r3) + mul(h1, r2) + mul(h2, r1) + mul(h3, r0) + mul(h4, s4);
			var d4 = mul(h0, r4) + mul(h1, r3) + mul(h2, r2) + mul(h3, r1) + mul(h4, r0);
			var c = (d0 >>> 26).low; h0 = d0.low & mask;
			d1 += c; c = (d1 >>> 26).low; h1 = d1.low & mask;
			d2 += c; c = (d2 >>> 26).low; h2 = d2.low & mask;
			d3 += c; c = (d3 >>> 26).low; h3 = d3.low & mask;
			d4 += c; c = (d4 >>> 26).low; h4 = d4.low & mask;
			h0 += c * 5; c = h0 >>> 26; h0 &= mask;
			h1 += c;
			var used = n < 16 ? n : 16;
			mpos += used;
			n -= used;
		}
		var c = h1 >>> 26; h1 &= mask;
		h2 += c; c = h2 >>> 26; h2 &= mask;
		h3 += c; c = h3 >>> 26; h3 &= mask;
		h4 += c; c = h4 >>> 26; h4 &= mask;
		h0 += c * 5; c = h0 >>> 26; h0 &= mask;
		h1 += c;
		var g0 = h0 + 5; c = g0 >>> 26; g0 &= mask;
		var g1 = h1 + c; c = g1 >>> 26; g1 &= mask;
		var g2 = h2 + c; c = g2 >>> 26; g2 &= mask;
		var g3 = h3 + c; c = g3 >>> 26; g3 &= mask;
		var g4 = h4 + c - (1 << 26);
		var sel = (g4 >>> 31) - 1;
		g0 &= sel; g1 &= sel; g2 &= sel; g3 &= sel; g4 &= sel;
		var keep = ~sel;
		h0 = (h0 & keep) | g0; h1 = (h1 & keep) | g1; h2 = (h2 & keep) | g2; h3 = (h3 & keep) | g3; h4 = (h4 & keep) | g4;
		var w0 = h0 | (h1 << 26);
		var w1 = (h1 >>> 6) | (h2 << 20);
		var w2 = (h2 >>> 12) | (h3 << 14);
		var w3 = (h3 >>> 18) | (h4 << 8);
		var u32 = function( v : Int ) return Int64.make(0, v);
		var f = u32(w0) + u32(k.getInt32(kpos + 16));
		out.setInt32(outpos, f.low);
		f = u32(w1) + u32(k.getInt32(kpos + 20)) + (f >>> 32);
		out.setInt32(outpos + 4, f.low);
		f = u32(w2) + u32(k.getInt32(kpos + 24)) + (f >>> 32);
		out.setInt32(outpos + 8, f.low);
		f = u32(w3) + u32(k.getInt32(kpos + 28)) + (f >>> 32);
		out.setInt32(outpos + 12, f.low);
	}

	/** comparacion en tiempo constante de n bytes; true si son iguales */
	public static function equals( x : Bytes, xi : Int, y : Bytes, yi : Int, n : Int ) : Bool {
		var d = 0;
		for( i in 0...n ) d |= x.get(xi + i) ^ y.get(yi + i);
		return d == 0;
	}

	/** secretbox (XSalsa20-Poly1305): devuelve etiqueta (16) + cifrado; la clave y el nonce no se pueden reutilizar juntos */
	public static function secretbox( msg : Bytes, nonce : Bytes, key : Bytes ) : Bytes {
		var len = msg.length;
		var stream = Bytes.alloc(32 + len);
		var padded = Bytes.alloc(32 + len);
		padded.fill(0, 32, 0);
		padded.blit(32, msg, 0, len);
		xsalsa20Xor(stream, 0, padded, 0, 32 + len, nonce, key);
		var out = Bytes.alloc(TAG + len);
		poly1305(out, 0, stream, 32, len, stream, 0);
		out.blit(TAG, stream, 32, len);
		return out;
	}

	/** abre un secretbox; null si la etiqueta no cuadra (mensaje alterado, clave o nonce equivocados) */
	public static function secretboxOpen( box : Bytes, nonce : Bytes, key : Bytes ) : Null<Bytes> {
		if( box.length < TAG ) return null;
		var len = box.length - TAG;
		var sub = Bytes.alloc(32);
		xsalsa20Xor(sub, 0, null, 0, 32, nonce, key);
		var tag = Bytes.alloc(TAG);
		poly1305(tag, 0, box, TAG, len, sub, 0);
		if( !equals(tag, 0, box, 0, TAG) ) return null;
		var padded = Bytes.alloc(32 + len);
		padded.fill(0, 32, 0);
		padded.blit(32, box, TAG, len);
		var out = Bytes.alloc(32 + len);
		xsalsa20Xor(out, 0, padded, 0, 32 + len, nonce, key);
		return out.sub(32, len);
	}

	// ---------------------------------------------------------------- Curve25519

	static inline function gf() : Vector<Float> {
		var r = new Vector<Float>(16);
		for( i in 0...16 ) r[i] = 0;
		return r;
	}

	static function gfOf( a : Array<Int> ) : Vector<Float> {
		var r = gf();
		for( i in 0...a.length ) r[i] = a[i];
		return r;
	}

	static var GF0 = gf();
	static var GF1 = gfOf([1]);
	static var C121665 = gfOf([0xdb41, 1]);
	static var D = gfOf([0x78a3, 0x1359, 0x4dca, 0x75eb, 0xd8ab, 0x4141, 0x0a4d, 0x0070, 0xe898, 0x7779, 0x4079, 0x8cc7, 0xfe73, 0x2b6f, 0x6cee, 0x5203]);
	static var D2 = gfOf([0xf159, 0x26b2, 0x9b94, 0xebd6, 0xb156, 0x8283, 0x149a, 0x00e0, 0xd130, 0xeef3, 0x80f2, 0x198e, 0xfce7, 0x56df, 0xd9dc, 0x2406]);
	static var X = gfOf([0xd51a, 0x8f25, 0x2d60, 0xc956, 0xa7b2, 0x9525, 0xc760, 0x692c, 0xdc5c, 0xfdd6, 0xe231, 0xc0a4, 0x53fe, 0xcd6e, 0x36d3, 0x2169]);
	static var Y = gfOf([0x6658, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666]);
	static var I = gfOf([0xa0b0, 0x4a0e, 0x1b27, 0xc4ee, 0xe478, 0xad2f, 0x1806, 0x2f43, 0xd7a7, 0x3dfb, 0x0099, 0x2b4d, 0xdf0b, 0x4fc1, 0x2480, 0x2b83]);

	static inline function set25519( r : Vector<Float>, a : Vector<Float> ) for( i in 0...16 ) r[i] = a[i];

	static function car25519( o : Vector<Float> ) {
		for( i in 0...16 ) {
			o[i] += 65536;
			var c = Math.ffloor(o[i] / 65536);
			if( i < 15 ) o[i + 1] += c - 1 else o[0] += 38 * (c - 1);
			o[i] -= c * 65536;
		}
	}

	static function sel25519( p : Vector<Float>, q : Vector<Float>, b : Int ) {
		var c = ~(b - 1);
		for( i in 0...16 ) {
			var pi = Std.int(p[i]), qi = Std.int(q[i]);
			var t = c & (pi ^ qi);
			p[i] = pi ^ t;
			q[i] = qi ^ t;
		}
	}

	static function pack25519( o : Bytes, opos : Int, n : Vector<Float> ) {
		var tf = gf();
		for( i in 0...16 ) tf[i] = n[i];
		car25519(tf);
		car25519(tf);
		car25519(tf);
		var t = new Vector<Int>(16), m = new Vector<Int>(16);
		for( i in 0...16 ) t[i] = Std.int(tf[i]);
		for( j in 0...2 ) {
			m[0] = t[0] - 0xffed;
			for( i in 1...15 ) {
				m[i] = t[i] - 0xffff - ((m[i - 1] >> 16) & 1);
				m[i - 1] &= 0xffff;
			}
			m[15] = t[15] - 0x7fff - ((m[14] >> 16) & 1);
			var b = (m[15] >> 16) & 1;
			m[14] &= 0xffff;
			var c = ~((1 - b) - 1);
			for( i in 0...16 ) {
				var x = c & (t[i] ^ m[i]);
				t[i] ^= x;
				m[i] ^= x;
			}
		}
		for( i in 0...16 ) {
			o.set(opos + 2 * i, t[i] & 0xff);
			o.set(opos + 2 * i + 1, (t[i] >> 8) & 0xff);
		}
	}

	static function neq25519( a : Vector<Float>, b : Vector<Float> ) : Bool {
		var c = Bytes.alloc(32), d = Bytes.alloc(32);
		pack25519(c, 0, a);
		pack25519(d, 0, b);
		return !equals(c, 0, d, 0, 32);
	}

	static function par25519( a : Vector<Float> ) : Int {
		var d = Bytes.alloc(32);
		pack25519(d, 0, a);
		return d.get(0) & 1;
	}

	static function unpack25519( o : Vector<Float>, n : Bytes, npos : Int ) {
		for( i in 0...16 ) o[i] = n.get(npos + 2 * i) + (n.get(npos + 2 * i + 1) << 8);
		o[15] = Std.int(o[15]) & 0x7fff;
	}

	static inline function A( o : Vector<Float>, a : Vector<Float>, b : Vector<Float> ) for( i in 0...16 ) o[i] = a[i] + b[i];

	static inline function Z( o : Vector<Float>, a : Vector<Float>, b : Vector<Float> ) for( i in 0...16 ) o[i] = a[i] - b[i];

	static var mt = new Vector<Float>(31);

	static function M( o : Vector<Float>, a : Vector<Float>, b : Vector<Float> ) {
		var t = mt;
		for( i in 0...31 ) t[i] = 0;
		for( i in 0...16 ) {
			var ai = a[i];
			for( j in 0...16 ) t[i + j] += ai * b[j];
		}
		for( i in 0...15 ) t[i] += 38 * t[i + 16];
		for( i in 0...16 ) o[i] = t[i];
		car25519(o);
		car25519(o);
	}

	static inline function S( o : Vector<Float>, a : Vector<Float> ) M(o, a, a);

	static function inv25519( o : Vector<Float>, i : Vector<Float> ) {
		var c = gf();
		for( a in 0...16 ) c[a] = i[a];
		var a = 253;
		while( a >= 0 ) {
			S(c, c);
			if( a != 2 && a != 4 ) M(c, c, i);
			a--;
		}
		for( a in 0...16 ) o[a] = c[a];
	}

	static function pow2523( o : Vector<Float>, i : Vector<Float> ) {
		var c = gf();
		for( a in 0...16 ) c[a] = i[a];
		var a = 250;
		while( a >= 0 ) {
			S(c, c);
			if( a != 1 ) M(c, c, i);
			a--;
		}
		for( a in 0...16 ) o[a] = c[a];
	}

	/** X25519: n (32 bytes secretos) por el punto p (32 bytes) */
	public static function scalarmult( n : Bytes, p : Bytes ) : Bytes {
		var z = Bytes.alloc(32);
		z.blit(0, n, 0, 32);
		z.set(31, (n.get(31) & 127) | 64);
		z.set(0, z.get(0) & 248);
		var x = gf();
		unpack25519(x, p, 0);
		var a = gf(), b = gf(), c = gf(), d = gf(), e = gf(), f = gf();
		for( i in 0...16 ) b[i] = x[i];
		a[0] = 1;
		d[0] = 1;
		var i = 254;
		while( i >= 0 ) {
			var r = (z.get(i >>> 3) >>> (i & 7)) & 1;
			sel25519(a, b, r);
			sel25519(c, d, r);
			A(e, a, c);
			Z(a, a, c);
			A(c, b, d);
			Z(b, b, d);
			S(d, e);
			S(f, a);
			M(a, c, a);
			M(c, b, e);
			A(e, a, c);
			Z(a, a, c);
			S(b, a);
			Z(c, d, f);
			M(a, c, C121665);
			A(a, a, d);
			M(c, c, a);
			M(a, d, f);
			M(d, b, x);
			S(b, e);
			sel25519(a, b, r);
			sel25519(c, d, r);
			i--;
		}
		inv25519(c, c);
		M(a, a, c);
		var q = Bytes.alloc(32);
		pack25519(q, 0, a);
		return q;
	}

	static var NINE : Bytes = { var b = Bytes.alloc(32); b.fill(0, 32, 0); b.set(0, 9); b; };

	/** X25519: clave publica de la clave secreta n */
	public static function scalarmultBase( n : Bytes ) : Bytes return scalarmult(n, NINE);

	/** clave compartida de un intercambio X25519 lista para secretbox (crypto_box_beforenm) */
	public static function boxBeforenm( theirPk : Bytes, mySk : Bytes ) : Bytes {
		var s = scalarmult(mySk, theirPk);
		var zero = Bytes.alloc(16);
		zero.fill(0, 16, 0);
		return hsalsa20(zero, 0, s);
	}

	// ---------------------------------------------------------------- Ed25519

	static function add( p : Array<Vector<Float>>, q : Array<Vector<Float>> ) {
		var a = gf(), b = gf(), c = gf(), d = gf(), e = gf(), f = gf(), g = gf(), h = gf(), t = gf();
		Z(a, p[1], p[0]);
		Z(t, q[1], q[0]);
		M(a, a, t);
		A(b, p[0], p[1]);
		A(t, q[0], q[1]);
		M(b, b, t);
		M(c, p[3], q[3]);
		M(c, c, D2);
		M(d, p[2], q[2]);
		A(d, d, d);
		Z(e, b, a);
		Z(f, d, c);
		A(g, d, c);
		A(h, b, a);
		M(p[0], e, f);
		M(p[1], h, g);
		M(p[2], g, f);
		M(p[3], e, h);
	}

	static function cswap( p : Array<Vector<Float>>, q : Array<Vector<Float>>, b : Int ) {
		for( i in 0...4 ) sel25519(p[i], q[i], b);
	}

	static function pack( r : Bytes, rpos : Int, p : Array<Vector<Float>> ) {
		var tx = gf(), ty = gf(), zi = gf();
		inv25519(zi, p[2]);
		M(tx, p[0], zi);
		M(ty, p[1], zi);
		pack25519(r, rpos, ty);
		r.set(rpos + 31, r.get(rpos + 31) ^ (par25519(tx) << 7));
	}

	static function scalarmultPoint( p : Array<Vector<Float>>, q : Array<Vector<Float>>, s : Bytes, spos : Int ) {
		set25519(p[0], GF0);
		set25519(p[1], GF1);
		set25519(p[2], GF1);
		set25519(p[3], GF0);
		var i = 255;
		while( i >= 0 ) {
			var b = (s.get(spos + (i >> 3)) >> (i & 7)) & 1;
			cswap(p, q, b);
			add(q, p);
			add(p, p);
			cswap(p, q, b);
			i--;
		}
	}

	static function scalarbase( p : Array<Vector<Float>>, s : Bytes, spos : Int ) {
		var q = [gf(), gf(), gf(), gf()];
		set25519(q[0], X);
		set25519(q[1], Y);
		set25519(q[2], GF1);
		M(q[3], X, Y);
		scalarmultPoint(p, q, s, spos);
	}

	static var L = [0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x10];

	static function modL( r : Bytes, rpos : Int, x : Vector<Float> ) {
		var i = 63;
		while( i >= 32 ) {
			var carry = 0.;
			var j = i - 32, k = i - 12;
			while( j < k ) {
				x[j] += carry - 16 * x[i] * L[j - (i - 32)];
				carry = Math.ffloor((x[j] + 128) / 256);
				x[j] -= carry * 256;
				j++;
			}
			x[j] += carry;
			x[i] = 0;
			i--;
		}
		var carry = 0;
		for( j in 0...32 ) {
			x[j] += carry - (Std.int(x[31]) >> 4) * L[j];
			carry = Std.int(x[j]) >> 8;
			x[j] = Std.int(x[j]) & 255;
		}
		for( j in 0...32 ) x[j] -= carry * L[j];
		for( i in 0...32 ) {
			x[i + 1] += Std.int(x[i]) >> 8;
			r.set(rpos + i, Std.int(x[i]) & 255);
		}
	}

	static function reduce( r : Bytes ) {
		var x = new Vector<Float>(64);
		for( i in 0...64 ) x[i] = r.get(i);
		r.fill(0, 64, 0);
		modL(r, 0, x);
	}

	/** paire de claves Ed25519 a partir de una semilla de 32 bytes: sk = semilla + pk (64 bytes) */
	public static function signKeyPair( seed : Bytes ) : { pk : Bytes, sk : Bytes } {
		var d = sha512(seed, 0, 32);
		d.set(0, d.get(0) & 248);
		d.set(31, (d.get(31) & 127) | 64);
		var p = [gf(), gf(), gf(), gf()];
		scalarbase(p, d, 0);
		var pk = Bytes.alloc(32);
		pack(pk, 0, p);
		var sk = Bytes.alloc(64);
		sk.blit(0, seed, 0, 32);
		sk.blit(32, pk, 0, 32);
		return { pk : pk, sk : sk };
	}

	/** firma Ed25519 (64 bytes) de msg con la clave secreta de 64 bytes */
	public static function sign( msg : Bytes, sk : Bytes ) : Bytes {
		var n = msg.length;
		var d = sha512(sk, 0, 32);
		d.set(0, d.get(0) & 248);
		d.set(31, (d.get(31) & 127) | 64);
		var sm = Bytes.alloc(64 + n);
		sm.blit(64, msg, 0, n);
		sm.blit(32, d, 32, 32);
		var r = sha512(sm, 32, n + 32);
		reduce(r);
		var p = [gf(), gf(), gf(), gf()];
		scalarbase(p, r, 0);
		pack(sm, 0, p);
		sm.blit(32, sk, 32, 32);
		var h = sha512(sm, 0, n + 64);
		reduce(h);
		var x = new Vector<Float>(64);
		for( i in 0...64 ) x[i] = 0;
		for( i in 0...32 ) x[i] = r.get(i);
		for( i in 0...32 ) for( j in 0...32 ) x[i + j] += h.get(i) * d.get(j);
		modL(sm, 32, x);
		return sm.sub(0, 64);
	}

	static function unpackneg( r : Array<Vector<Float>>, p : Bytes ) : Bool {
		var t = gf(), chk = gf(), num = gf(), den = gf(), den2 = gf(), den4 = gf(), den6 = gf();
		set25519(r[2], GF1);
		unpack25519(r[1], p, 0);
		S(num, r[1]);
		M(den, num, D);
		Z(num, num, r[2]);
		A(den, r[2], den);
		S(den2, den);
		S(den4, den2);
		M(den6, den4, den2);
		M(t, den6, num);
		M(t, t, den);
		pow2523(t, t);
		M(t, t, num);
		M(t, t, den);
		M(t, t, den);
		M(r[0], t, den);
		S(chk, r[0]);
		M(chk, chk, den);
		if( neq25519(chk, num) ) M(r[0], r[0], I);
		S(chk, r[0]);
		M(chk, chk, den);
		if( neq25519(chk, num) ) return false;
		if( par25519(r[0]) == (p.get(31) >> 7) ) Z(r[0], GF0, r[0]);
		M(r[3], r[0], r[1]);
		return true;
	}

	/** comprueba una firma Ed25519 */
	public static function verify( msg : Bytes, sig : Bytes, pk : Bytes ) : Bool {
		if( sig == null || sig.length != 64 || pk == null || pk.length != 32 ) return false;
		var q = [gf(), gf(), gf(), gf()];
		if( !unpackneg(q, pk) ) return false;
		var n = msg.length;
		var m = Bytes.alloc(64 + n);
		m.blit(0, sig, 0, 64);
		m.blit(32, pk, 0, 32);
		m.blit(64, msg, 0, n);
		var h = sha512(m, 0, 64 + n);
		reduce(h);
		var p = [gf(), gf(), gf(), gf()];
		scalarmultPoint(p, q, h, 0);
		scalarbase(q, sig, 32);
		add(p, q);
		var t = Bytes.alloc(32);
		pack(t, 0, p);
		return equals(sig, 0, t, 0, 32);
	}
}
