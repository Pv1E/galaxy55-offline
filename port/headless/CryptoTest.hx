import haxe.io.Bytes;

/**
 * Pruebas de port/net/Nacl.hx (anadido del port) con los vectores publicados: SHA-512 (FIPS 180), Ed25519 (RFC 8032),
 * X25519 (RFC 7748), Poly1305 (RFC 8439) y crypto_box_beforenm / secretbox de las pruebas de NaCl. Sale con 1 si algo falla.
 */
class CryptoTest {

	static var fails = 0;

	static function hex( s : String ) : Bytes return Bytes.ofHex(s);

	static function check( name : String, got : Bytes, want : String ) {
		var g = got.toHex();
		if( g == want ) Sys.println("ok   " + name);
		else {
			fails++;
			Sys.println("MAL  " + name + "\n     obtenido " + g + "\n     esperado " + want);
		}
	}

	static function checkBool( name : String, v : Bool ) {
		if( v ) Sys.println("ok   " + name) else {
			fails++;
			Sys.println("MAL  " + name);
		}
	}

	static function main() {
		check("sha512 vacio", Nacl.sha512(Bytes.alloc(0)),
			"cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e");
		check("sha512 abc", Nacl.sha512(Bytes.ofString("abc")),
			"ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f");
		check("sha512 2 bloques", Nacl.sha512(Bytes.ofString("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu")),
			"8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909");

		var vectors = [
			["9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60", "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a", "",
				"e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"],
			["4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb", "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c", "72",
				"92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"],
			["c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7", "fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025", "af82",
				"6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a"],
		];
		for( i in 0...vectors.length ) {
			var v = vectors[i];
			var kp = Nacl.signKeyPair(hex(v[0]));
			check("ed25519 pk " + (i + 1), kp.pk, v[1]);
			var msg = hex(v[2]);
			var sig = Nacl.sign(msg, kp.sk);
			check("ed25519 firma " + (i + 1), sig, v[3]);
			checkBool("ed25519 verifica " + (i + 1), Nacl.verify(msg, sig, kp.pk));
			var bad = sig.sub(0, 64);
			bad.set(10, bad.get(10) ^ 1);
			checkBool("ed25519 rechaza firma alterada " + (i + 1), !Nacl.verify(msg, bad, kp.pk));
			var msg2 = Bytes.ofString("otro mensaje " + i);
			checkBool("ed25519 rechaza otro mensaje " + (i + 1), !Nacl.verify(msg2, sig, kp.pk));
		}

		var alice = hex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a");
		var bob = hex("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb");
		var alicePk = Nacl.scalarmultBase(alice), bobPk = Nacl.scalarmultBase(bob);
		check("x25519 pk alice", alicePk, "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a");
		check("x25519 pk bob", bobPk, "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f");
		check("x25519 compartida alice", Nacl.scalarmult(alice, bobPk), "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742");
		check("x25519 compartida bob", Nacl.scalarmult(bob, alicePk), "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742");
		check("box beforenm (NaCl firstkey)", Nacl.boxBeforenm(bobPk, alice), "1b27556473e985d462cd51197a9a46c76009549eac6474f206c4ee0844f68389");

		var tag = Bytes.alloc(16);
		var pkey = hex("85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b");
		var pmsg = Bytes.ofString("Cryptographic Forum Research Group");
		Nacl.poly1305(tag, 0, pmsg, 0, pmsg.length, pkey, 0);
		check("poly1305 rfc8439", tag, "a8061dc1305136c6c22b8baf0c0127a9");

		var key = hex("1b27556473e985d462cd51197a9a46c76009549eac6474f206c4ee0844f68389");
		var nonce = hex("69696ee955b62b73cd62bda875fc73d68219e0036b7a0b37");
		var msg = hex("be075fc53c81f2d5cf141316ebeb0c7b5228c52a4c62cbd44b66849b64244ffce5ecbaaf33bd751a1ac728d45e6c61296cdc3c01233561f41db66cce314adb310e3be8250c46f06dceea3a7fa1348057e2f6556ad6b1318a024a838f21af1fde048977eb48f59ffd4924ca1c60902e52f0a089bc76897040e082f937763848645e0705");
		var box = Nacl.secretbox(msg, nonce, key);
		check("secretbox (NaCl)", box, "f3ffc7703f9400e52a7dfb4b3d3305d98e993b9f48681273c29650ba32fc76ce48332ea7164d96a4476fb8c531a1186ac0dfc17c98dce87b4da7f011ec48c97271d2c20f9b928fe2270d6fb863d51738b48eeee314a7cc8ab932164548e526ae90224368517acfeabd6bb3732bc0e9da99832b61ca01b6de56244a9e88d5f9b37973f622a43d14a6599b1f654cb45a74e355a5");
		var open = Nacl.secretboxOpen(box, nonce, key);
		checkBool("secretbox abre", open != null && open.compare(msg) == 0);
		var alt = box.sub(0, box.length);
		alt.set(40, alt.get(40) ^ 0x20);
		checkBool("secretbox rechaza alterado", Nacl.secretboxOpen(alt, nonce, key) == null);
		var empty = Nacl.secretbox(Bytes.alloc(0), nonce, key);
		var emptyOpen = Nacl.secretboxOpen(empty, nonce, key);
		checkBool("secretbox vacio", empty.length == 16 && emptyOpen != null && emptyOpen.length == 0);

		var t0 = haxe.Timer.stamp();
		var n = 20;
		var kp = Nacl.signKeyPair(hex(vectors[0][0]));
		var sig = null;
		for( i in 0...n ) sig = Nacl.sign(Bytes.ofString("transcripcion " + i), kp.sk);
		var tSign = (haxe.Timer.stamp() - t0) / n;
		t0 = haxe.Timer.stamp();
		for( i in 0...n ) Nacl.verify(Bytes.ofString("transcripcion " + (n - 1)), sig, kp.pk);
		var tVerify = (haxe.Timer.stamp() - t0) / n;
		t0 = haxe.Timer.stamp();
		for( i in 0...n ) Nacl.scalarmult(alice, bobPk);
		var tDh = (haxe.Timer.stamp() - t0) / n;
		var big = Bytes.alloc(1 << 20);
		t0 = haxe.Timer.stamp();
		var bigBox = Nacl.secretbox(big, nonce, key);
		var tBox = haxe.Timer.stamp() - t0;
		t0 = haxe.Timer.stamp();
		Nacl.secretboxOpen(bigBox, nonce, key);
		var tOpen = haxe.Timer.stamp() - t0;
		Sys.println('tiempos: firma ${ms(tSign)} ms, verificacion ${ms(tVerify)} ms, x25519 ${ms(tDh)} ms, secretbox 1 MB ${ms(tBox)} ms, abrir 1 MB ${ms(tOpen)} ms');

		Sys.println(fails == 0 ? "FIN OK" : "FALLOS: " + fails);
		Sys.exit(fails == 0 ? 0 : 1);
	}

	static function ms( t : Float ) return Math.round(t * 10000) / 10;
}
