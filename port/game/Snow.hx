import h2d.SpriteBatch;

/**
	Nieve que cae en el mundo (anadido de este port: el juego original no la tiene).

	Cada copo tiene una posicion fija en el mundo: cae despacio y se mece, pero no se mueve cuando
	el jugador camina, vuela o gira. El campo de copos es una red periodica alrededor de la camara
	(un copo que sale por un lado reaparece por el otro lado, lejos y atenuado), asi hay siempre nieve
	sin un numero enorme de particulas. Cada copo se proyecta con la camara 3D y se dibuja como un
	cuadrado 2D; se oculta si hay terreno entre la camara y el copo.
**/
class Snow {

	static inline var N = 1100;
	/** tamano de la red de copos alrededor de la camara */
	static inline var LX = 44.;
	static inline var LZ = 26.;
	/** distancia de atenuacion en el borde de la red */
	static inline var FADE = 6.;

	var batch : SpriteBatch;
	var els = new Array<BatchElement>();
	var bx = new Array<Float>();
	var by = new Array<Float>();
	var bz = new Array<Float>();
	var vs = new Array<Float>();
	var sp = new Array<Float>();
	var sf = new Array<Float>();
	var sz = new Array<Float>();
	var t = 0.;
	var pt = new h3d.Vector();
	/**
	 * nieve solo sobre una zona (anadido del port: la de una anomalia con efecto snow, Structures): la red de copos se centra en
	 * x, y, z en vez de en la camara, y solo se ven los copos a menos de r bloques de x, y (atenuados en el borde). null = la red
	 * sigue a la camara (el planeta de nieve)
	 */
	public var area : { x : Float, y : Float, z : Float, r : Float };
	/** atenuacion en el borde de area */
	static inline var AREA_FADE = 3.;
	/** altura del bloque macizo mas alto de cada columna (no nieva bajo techo ni en cuevas); se recalcula cada medio segundo */
	var roof = new Map<Int, Int>();
	var roofAge = 0.;

	public var visible(get, set) : Bool;

	public function new( parent : h2d.Object ) {
		batch = new SpriteBatch(h2d.Tile.fromColor(0xFFFFFF, 1, 1), parent);
		batch.hasRotationScale = true;
		batch.visible = false;
		for( i in 0...N ) {
			bx.push(Math.random() * LX);
			by.push(Math.random() * LX);
			bz.push(Math.random() * LZ);
			// caida de 1.6 a 3.4 bloques por segundo; copos mas grandes caen un poco mas rapido
			var s = 0.05 + Math.random() * Math.random() * 0.12;
			sz.push(s);
			vs.push(1.6 + (s - 0.05) / 0.12 * 1.0 + Math.random() * 0.8);
			sp.push(Math.random() * 6.28);
			sf.push(0.5 + Math.random() * 0.9);
			var e = new BatchElement(batch.tile);
			e.visible = false;
			batch.add(e);
			els.push(e);
		}
	}

	function get_visible() return batch.visible;

	function set_visible( v : Bool ) {
		return batch.visible = v;
	}

	/** posicion periodica: el valor mas cercano a c que es congruente con u modulo l */
	static inline function wrap( u : Float, c : Float, l : Float ) : Float {
		var d = (u - c) % l;
		if( d < -l * 0.5 ) d += l;
		else if( d > l * 0.5 ) d -= l;
		return c + d;
	}

	/**
	 * Lo que tapa un copo: lo macizo (collidePoint) y el agua, que no choca. Por el agua, en la burbuja de una braise solidificada
	 * bajo el mar nevaba y se veian los copos de encima del mar a traves de ella.
	 */
	static function stops( world : World, x : Float, y : Float, z : Float ) : Bool {
		if( world.collidePoint(x, y, z) ) return true;
		if( z < 0 || z >= World.HEIGHT ) return false;
		var b = world.block(Math.floor(x), Math.floor(y), Std.int(z));
		return b != null && b.hasProp(PLiquid);
	}

	/**
		cam: camara 3D ya colocada; world: para ocultar copos tapados por el terreno.
		offX/offY/visW/visH: rectangulo de la ventana en coordenadas de la escena 2D.
	**/
	public function update( dt : Float, cam : h3d.Camera, world : World, offX : Float, offY : Float, visW : Float, visH : Float ) {
		if( !batch.visible ) return;
		t += dt;
		roofAge += dt;
		if( roofAge > 0.5 ) {
			roofAge = 0;
			roof = new Map();
		}
		cam.update();
		var cx = cam.pos.x, cy = cam.pos.y, cz = cam.pos.z;
		var fx = cam.target.x - cx, fy = cam.target.y - cy, fz = cam.target.z - cz;
		var fl = Math.sqrt(fx * fx + fy * fy + fz * fz);
		if( fl < 1e-6 ) return;
		fx /= fl;
		fy /= fl;
		fz /= fl;
		var focal = (visH * 0.5) / Math.tan(cam.fovY * Math.PI / 360);

		// centro de la red: la camara o la zona (area)
		var ax = area != null ? area.x : cx, ay = area != null ? area.y : cy, az = area != null ? area.z : cz;
		for( i in 0...N ) {
			var e = els[i];
			// posicion sin envolver (caida y balanceo) y despues envuelta alrededor del centro
			var ux = bx[i] + Math.sin(t * sf[i] + sp[i]) * 0.4;
			var uy = by[i] + Math.cos(t * sf[i] * 0.8 + sp[i]) * 0.4;
			var uz = bz[i] - t * vs[i];
			var wx = wrap(ux, ax, LX), wy = wrap(uy, ay, LX), wz = wrap(uz, az, LZ);

			var dx = wx - cx, dy = wy - cy, dz = wz - cz;
			var depth = dx * fx + dy * fy + dz * fz;
			if( depth < 0.4 ) {
				e.visible = false;
				continue;
			}
			// atenuar cerca del borde de la red (o de la zona)
			var fade = if( area != null ) {
				var hx = wx - ax, hy = wy - ay;
				Math.min(1, Math.min((area.r - Math.sqrt(hx * hx + hy * hy)) / AREA_FADE, (LZ * 0.5 - Math.abs(wz - az)) / FADE));
			} else Math.min(1, Math.min((LX * 0.5 - Math.abs(dx)) / FADE, Math.min((LX * 0.5 - Math.abs(dy)) / FADE, (LZ * 0.5 - Math.abs(dz)) / FADE)));
			if( fade <= 0 ) {
				e.visible = false;
				continue;
			}
			cam.project(wx, wy, wz, visW, visH, false, pt);
			if( pt.x < -10 || pt.x > visW + 10 || pt.y < -10 || pt.y > visH + 10 ) {
				e.visible = false;
				continue;
			}
			// no nieva bajo techo: si hay algo macizo encima del copo en su columna, se oculta. Tampoco bajo el agua (stops)
			var fx0 = Math.floor(wx), fy0 = Math.floor(wy);
			var key = fx0 * 8192 + fy0;
			var top = roof.get(key);
			if( top == null ) {
				top = -1;
				var zz = World.HEIGHT - 1;
				while( zz >= 0 ) {
					if( stops(world, fx0 + 0.5, fy0 + 0.5, zz + 0.5) ) {
						top = zz;
						break;
					}
					zz--;
				}
				roof.set(key, top);
			}
			if( wz < top + 1 ) {
				e.visible = false;
				continue;
			}
			// oculto si hay terreno (o agua) entre la camara y el copo
			var hidden = stops(world, wx, wy, wz);
			if( !hidden ) {
				var k = 0.12;
				while( k < 1 ) {
					if( stops(world, cx + dx * k, cy + dy * k, cz + dz * k) ) {
						hidden = true;
						break;
					}
					k += 0.14;
				}
			}
			if( hidden ) {
				e.visible = false;
				continue;
			}
			var px = Math.max(1.6, Math.min(10, sz[i] * 2 * focal / depth));
			e.visible = true;
			e.scaleX = px;
			e.scaleY = px;
			e.x = offX + pt.x - px * 0.5;
			e.y = offY + pt.y - px * 0.5;
			e.alpha = 0.92 * fade;
		}
	}

	public function dispose() {
		batch.remove();
	}
}
