import Common;

/**
	Niebla como en el original: los bloques lejanos se mezclan con el color del cielo, que es un
	degradado vertical de 3 colores por bioma (Data.getBiome(...).fog). El color del cielo depende
	de la elevacion del rayo de vista, asi la niebla del horizonte coincide con el fondo.
**/
class FogShader extends hxsl.Shader {
	static var SRC = {
		@global var camera : {
			var position : Vec3;
				var viewProj : Mat4;
		};
		var transformedPosition : Vec3;
		var projectedPosition : Vec4;
		var pixelColor : Vec4;
		@param var c0 : Vec3;
		@param var c1 : Vec3;
		@param var c2 : Vec3;
		@param var fogK : Float;
			@param var curve : Float;
			/** de la camara al vertice ya bajado por la curvatura */
			@var var fogDelta : Vec3;

			// el planeta es redondo: como en el original (Shaders.hx: fpos.z -= (dx*dx + dy*dy) * cam.w) cada vertice baja
			// con el cuadrado de su distancia horizontal a la camara; curve = 2 / tamano del planeta
			function vertex() {
				var d = transformedPosition.xy - camera.position.xy;
				var p = vec3(transformedPosition.x, transformedPosition.y, transformedPosition.z - dot(d, d) * curve);
				fogDelta = p - camera.position;
				projectedPosition = vec4(p, 1.0) * camera.viewProj;
			}

		function skyAt( e : Float ) : Vec3 {
			var h = clamp(0.65 - 0.5 * e, 0.0, 1.0);
			var t = clamp(h * 3.0 - 0.5, 0.0, 2.0);
			var a = clamp(t, 0.0, 1.0);
			var b = clamp(t - 1.0, 0.0, 1.0);
			return mix(mix(c0, c1, a), c2, b);
		}

		function fragment() {
			var d = normalize(transformedPosition - camera.position);
			var e = asin(clamp(d.z, -1.0, 1.0));
			// cambio del port: el original (Shaders.hx: fog = 1 - (tpos.z - 10) * fogPower) usa la profundidad de vista, que cambia
			// al girar o inclinar la camara (lo del borde de la pantalla y lo lejano mirando hacia abajo salia mas claro); aqui la
			// distancia a la camara, igual mire donde mire. En el centro de la pantalla las dos coinciden
			var f = clamp(1.0 - (length(fogDelta) - 10.0) * fogK, 0.0, 1.0);
			pixelColor.rgb = mix(skyAt(e), pixelColor.rgb, f);
		}
	};
}

/**
	Estrellas como el Skybox del original: un cubo alrededor de la camara con la misma textura en sus 6 caras, leida con la
	direccion local de cada pixel (tuv = pos), sin filtrar (nearest) ni mipmaps. Una estrella es blanca con alfa = skyBoxAlpha
	sobre el degradado. La textura es 2D y la cara se elige aqui (faceUV): con una textura cubica, en un PC con "Mesa Intel(R)
	HD Graphics 4600 (HSW GT2)" (Mesa 25.2, crocus) lo que se pintaba justo despues (cascadas, cristal y gemas, en la pasada
	alpha) salia invisible y luego parpadeaba en negro y blanco, y el menu principal salia a veces sin dibujar. Bajo el agua,
	sin estrellas, todo se veia bien.
**/
class StarShader extends hxsl.Shader {
	static var SRC = {
		var relativePosition : Vec3;
		var pixelColor : Vec4;
		@var var starDir : Vec3;
		@param var tex : Sampler2D;
		@param var alpha : Float;

		/** como una textura cubica con la misma imagen en las 6 caras: la cara del eje mayor y la posicion en ella (0..1) */
		function faceUV( d : Vec3 ) : Vec2 {
			var a = abs(d);
			var uv = d.xy / max(a.z, 0.000001);
			if( a.x >= a.y && a.x >= a.z ) uv = d.yz / a.x;
			else if( a.y >= a.z ) uv = d.xz / a.y;
			return uv * 0.5 + 0.5;
		}

		function vertex() {
			starDir = relativePosition;
		}

		function fragment() {
			pixelColor = vec4(1.0, 1.0, 1.0, tex.get(faceUV(starDir)).r * alpha);
		}
	};
}

/**
	Kube invisible (anadido del port): sus caras pintan el cielo que se veria en esa direccion (el degradado y las estrellas,
	como el fondo) y tapan lo que hay detras. Va despues de FogShader, que da la curvatura y el
	rayo de vista (fogDelta: de la camara al punto ya bajado por la curvatura, el mismo rayo que el pixel de la pantalla).
**/
class InvisibleSkyShader extends hxsl.Shader {
	static var SRC = {
		var pixelColor : Vec4;
		@var var fogDelta : Vec3;
		@param var c0 : Vec3;
		@param var c1 : Vec3;
		@param var c2 : Vec3;
		/** la textura 2D de las estrellas (ver StarShader) */
		@param var stars : Sampler2D;
		@param var starAlpha : Float;
		/** del mundo al cubo de las estrellas (inversa de su giro) */
		@param var starInv : Mat4;

		function skyAt( e : Float ) : Vec3 {
			var h = clamp(0.65 - 0.5 * e, 0.0, 1.0);
			var t = clamp(h * 3.0 - 0.5, 0.0, 2.0);
			var a = clamp(t, 0.0, 1.0);
			var b = clamp(t - 1.0, 0.0, 1.0);
			return mix(mix(c0, c1, a), c2, b);
		}

		/** la misma eleccion de cara que StarShader.faceUV */
		function faceUV( d : Vec3 ) : Vec2 {
			var a = abs(d);
			var uv = d.xy / max(a.z, 0.000001);
			if( a.x >= a.y && a.x >= a.z ) uv = d.yz / a.x;
			else if( a.y >= a.z ) uv = d.xz / a.y;
			return uv * 0.5 + 0.5;
		}

		function fragment() {
			var d = normalize(fogDelta);
			var col = skyAt(asin(clamp(d.z, -1.0, 1.0)));
			var s = stars.get(faceUV((vec4(d, 0.0) * starInv).xyz)).r * starAlpha;
			pixelColor = vec4(mix(col, vec3(1.0, 1.0, 1.0), s), 1.0);
		}
	};
}

/**
	Kube invisible visto a traves de una vitre blindee teintee o de glace noire (anadido del port), como bajo una luz negra: el
	bloque oscuro y violeta, lo claro de su textura fluorescente y las aristas de cada cara en azul, latiendo despacio.
**/
class InvisibleRevealShader extends hxsl.Shader {
	static var SRC = {
		@global var global : { var time : Float; };
		var calculatedUV : Vec2;
		var pixelColor : Vec4;
		/** el atlas de los bloques (la textura sin la niebla que FogShader ya ha mezclado en pixelColor) */
		@param var tex : Sampler2D;

		function fragment() {
			var t = tex.get(calculatedUV).rgb;
			var lum = dot(t, vec3(0.3, 0.59, 0.11));
			// posicion dentro de la casilla del atlas (0..1 en cada cara de bloque)
			var l = fract(calculatedUV * 64.0);
			var m = min(min(l.x, 1.0 - l.x), min(l.y, 1.0 - l.y));
			var edge = 1.0 - smoothstep(0.02, 0.13, m);
			var pulse = 0.8 + 0.2 * sin(global.time * 2.4);
			var base = vec3(0.07, 0.03, 0.2) + vec3(0.3, 0.42, 1.0) * (lum * lum) * 0.9;
			pixelColor = vec4(base + vec3(0.3, 0.72, 1.0) * edge * 1.3 * pulse, 1.0);
		}
	};
}

/** Cielo de un planeta: degradado, estrellas y parametros de niebla. */
class Sky {

	public var fog(default, null) : FogShader;
	/** Kube invisible (anadido del port): el cielo que pintan sus caras y su aspecto a traves del cristal tintado (World) */
	public var invisSky(default, null) : InvisibleSkyShader;
	public var invisReveal(default, null) : InvisibleRevealShader;
	/** cubo negro para invisSky cuando no hay estrellas */
	var noStars : h3d.mat.Texture;
	public var root(default, null) : h3d.scene.Object;
	var cols : Array<Int>;
	var stars : h3d.scene.Mesh;
	var starTex : h3d.mat.Texture;
	var dome : h3d.scene.Mesh;
	var starAlpha : Float;
	/** tamano del planeta en bloques: una vuelta del cielo por circunferencia */
	var psize : Float;
	/** giro acumulado de las estrellas y ultima posicion (skyPos del original, que empieza en 0,0) */
	var starRot : h3d.Matrix;
	var tmpRot = new h3d.Matrix();
	var starQ = new h3d.Quat();
	var starX = 0.;
	var starY = 0.;

	/** menuFog: niebla suave para el fondo del menu (se ve mas planeta). size: tamano del planeta en bloques. */
	public function new( parent : h3d.scene.Object, biome : BiomeKind, menuFog : Bool, size : Int ) {
		psize = size;
		var bd = Data.getBiome(biome);
		cols = bd.fog.copy();
		while( cols.length < 3 ) cols.push(cols[cols.length - 1]);
		root = new h3d.scene.Object(parent);

		fog = new FogShader();
		var k = 0.01 * bd.fogPower;
		// niebla mas suave en el menu para dejar ver el relieve lejano
		fog.fogK = menuFog ? Math.min(k, 0.0065) : k;
		// como el original: con niebla muy densa las estrellas se desvanecen
		starAlpha = Math.max(0, 1 - Math.pow(bd.fogPower - 1, 2) / 10);

		invisSky = new InvisibleSkyShader();
		invisSky.starInv = new h3d.Matrix();
		invisSky.starInv.identity();
		invisReveal = new InvisibleRevealShader();
		skyColors(rgb(cols[0]), rgb(cols[1]), rgb(cols[2]));
		buildDome();
		buildStars();
		updateInvisStars();
	}

	/** colores del degradado de la niebla, y del cielo que pintan los Kubes invisibles */
	function skyColors( a : h3d.Vector, b : h3d.Vector, c : h3d.Vector ) {
		fog.c0 = a;
		fog.c1 = b;
		fog.c2 = c;
		invisSky.c0 = a;
		invisSky.c1 = b;
		invisSky.c2 = c;
	}

	/** las estrellas que pintan los Kubes invisibles: las del cielo mientras se vean, con su giro */
	function updateInvisStars() {
		var on = stars != null && stars.visible;
		if( stars == null && noStars == null ) {
			// propia (no Texture.fromColor, que comparte la suya con todo el juego): dispose() la libera
			noStars = new h3d.mat.Texture(1, 1, null, RGBA);
			var px = hxd.Pixels.alloc(1, 1, RGBA);
			noStars.uploadPixels(px);
			px.dispose();
		}
		invisSky.stars = stars != null ? starTex : noStars;
		invisSky.starAlpha = on ? starAlpha : 0;
		if( on ) {
			// las estrellas se giran con starQ (= starRot): del mundo al cubo, la traspuesta
			var m = invisSky.starInv;
			m.load(starRot);
			m.transpose();
		}
	}

	/** Mueve el cielo con la camara. */
	public function follow( x : Float, y : Float, z : Float ) {
		root.setPosition(x, y, z);
		if( stars == null || (x == starX && y == starY) ) return;
		// como Render.hx del original: al andar, las estrellas giran una vuelta entera por circunferencia del planeta
		// (alrededor de Y al moverse en x, de X al moverse en y), sumando el giro de cada paso
		var rx = ((x - starX) * Math.PI * 2 / psize) % (Math.PI * 2);
		var ry = ((y - starY) * Math.PI * 2 / psize) % (Math.PI * 2);
		var m = tmpRot;
		m.initRotationY(-rx);
		starRot.multiply(starRot, m);
		m.initRotationX(ry);
		starRot.multiply(starRot, m);
		starX = x;
		starY = y;
		starQ.initRotateMatrix(starRot);
		stars.setRotationQuat(starQ);
		updateInvisStars();
	}

	var liquidCol : Null<Int> = null;
	var dryK = 0.;
	/** niebla de antes de pilotar (-1 = no se pilota) */
	var pilotK = -1.;

	/** pilotando la nave (anadido del port): la camara va muy por encima del suelo y con la niebla normal no se veria donde se
	    deja la nave; se suaviza como la del menu mientras dura y se recupera al acabar */
	public function setPilotFog( on : Bool ) {
		if( on && pilotK < 0 ) {
			pilotK = fog.fogK;
			fog.fogK = Math.min(pilotK, 0.004);
		} else if( !on && pilotK >= 0 ) {
			fog.fogK = pilotK;
			pilotK = -1;
		}
	}
	/** color plano que tapa el degradado dentro de un liquido */
	var flatSky = new h3d.shader.FixedColor();

	/** como Game.getEffects del original: con la camara dentro de un liquido con BFColor, la niebla toma su color y se espesa (col null = fuera) */
	public function setLiquid( col : Null<Int>, power : Float ) {
		if( col == null ) {
			if( liquidCol != null ) {
				skyColors(rgb(cols[0]), rgb(cols[1]), rgb(cols[2]));
				fog.fogK = dryK;
				liquidCol = null;
				liquidSky(null);
			}
			return;
		}
		if( liquidCol == null ) dryK = fog.fogK;
		if( col != liquidCol ) liquidSky(col);
		liquidCol = col;
		skyColors(rgb(col), rgb(col), rgb(col));
		fog.fogK = 0.01 * power;
	}

	/**
		Como la pasada de niebla del original (Render.hx): dentro de un liquido los colores de la niebla son todos el del liquido y
		tapan el cielo entero, y skyBoxAlpha = 1 - (fogPower - 1)^2 / 10 queda muy por debajo de 0 (fogPower de unos 29 a 64): sin
		estrellas. Solo al entrar, al salir o al pasar a otro liquido; el degradado no se rehace.
	**/
	function liquidSky( col : Null<Int> ) {
		var p = dome.material.mainPass;
		p.removeShader(flatSky);
		if( col != null ) {
			flatSky.color.setColor(0xFF000000 | col);
			p.addShader(flatSky);
		}
		if( stars != null ) stars.visible = col == null && space == null;
		// nave nodriza (anadido del port): su cielo de espacio tambien queda tapado
		if( space != null ) {
			space.visible = col == null;
			dome.visible = col != null;
		}
		updateInvisStars();
	}

	public function setVisible( v : Bool ) {
		root.visible = v;
	}

	// ---------------------------------------------------------------- espacio (nave nodriza, anadido del port)

	var space : h3d.scene.Object;
	var shooting : Array<{ m : h3d.scene.Mesh, t : Float, life : Float, dx : Float, dy : Float, dz : Float }>;
	var nextShoot = 2.;

	/** cielo de espacio abierto: nebulosas de colores, galaxias que giran despacio, estrellas de colores y estrellas fugaces */
	public function makeSpace() {
		fog.fogK = 0.0025;
		// cielo de espacio profundo generado (SpaceSky): sustituye al degradado y a las estrellas de los planetas
		dome.visible = false;
		if( stars != null ) stars.visible = false;
		updateInvisStars();
		space = new h3d.scene.Object(root);
		spaceTask = SpaceSky.build(space);
		shooting = [];
	}

	/** lo que falta por pintar del cielo de espacio (SpaceSky.build): la pantalla de carga lo pinta poco a poco (stepSpace) */
	var spaceTask : Void -> Bool;

	/** pinta un poco mas del cielo de espacio durante unos budgetMs; true si ya esta entero */
	public function stepSpace( budgetMs : Float ) : Bool {
		if( spaceTask == null ) return true;
		var t0 = haxe.Timer.stamp();
		do {
			if( !spaceTask() ) {
				spaceTask = null;
				return true;
			}
		} while( (haxe.Timer.stamp() - t0) * 1000 < budgetMs );
		return false;
	}

	static function dirRand( rnd : hxd.Rand ) {
		var z = rnd.srand() * 0.9;
		var a = rnd.rand() * Math.PI * 2;
		var r = Math.sqrt(1 - z * z);
		return new h3d.col.Point(Math.cos(a) * r, Math.sin(a) * r, z);
	}

	/** gira el cielo de espacio muy despacio y lanza estrellas fugaces de vez en cuando */
	public function update( dt : Float ) {
		if( space == null ) return;
		space.rotate(0, 0, dt * 0.004);
		nextShoot -= dt;
		if( nextShoot <= 0 ) {
			nextShoot = 1.5 + Math.random() * 4;
			var d = dirRand(new hxd.Rand(Std.random(100000)));
			if( d.z < 0.05 ) d.z = Math.abs(d.z) + 0.15;
			var tex = h3d.mat.Texture.fromColor(0xFFFFFF);
			var len = 40.;
			var dir = new h3d.col.Point(Math.random() - 0.5, Math.random() - 0.5, -0.3);
			dir.normalize();
			var R = 560.;
			var p0 = new h3d.col.Point(d.x * R, d.y * R, d.z * R);
			var pts = [p0.clone(), p0.clone(), new h3d.col.Point(p0.x - dir.x * len, p0.y - dir.y * len, p0.z - dir.z * len + 1.2), new h3d.col.Point(p0.x - dir.x * len, p0.y - dir.y * len, p0.z - dir.z * len)];
			pts[1].z += 1.6;
			var idx = new hxd.IndexBuffer();
			for( i in [0, 1, 2, 0, 2, 3] ) idx.push(i);
			var poly = new h3d.prim.Polygon(pts, idx);
			poly.addNormals(); // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
			poly.colors = [new h3d.col.Point(1, 1, 1), new h3d.col.Point(1, 1, 1), new h3d.col.Point(0, 0, 0), new h3d.col.Point(0, 0, 0)];
			poly.uvs = [new h3d.prim.UV(0, 0), new h3d.prim.UV(1, 0), new h3d.prim.UV(1, 1), new h3d.prim.UV(0, 1)];
			var mat = h3d.mat.Material.create(tex);
			mat.shadows = false;
			mat.mainPass.enableLights = false;
			mat.mainPass.culling = None;
			mat.mainPass.depthWrite = false;
			mat.blendMode = Add;
			mat.mainPass.addShader(new h3d.shader.VertexColor());
			var m = new h3d.scene.Mesh(poly, mat, root);
			shooting.push({ m : m, t : 0., life : 0.9, dx : dir.x * 520, dy : dir.y * 520, dz : dir.z * 520 });
		}
		for( s in shooting.copy() ) {
			s.t += dt;
			s.m.x += s.dx * dt;
			s.m.y += s.dy * dt;
			s.m.z += s.dz * dt;
			s.m.material.color.a = 1 - s.t / s.life;
			s.m.material.color.set(1 - s.t / s.life, 1 - s.t / s.life, 1 - s.t / s.life, 1);
			if( s.t >= s.life ) {
				s.m.remove();
				s.m.primitive.dispose();
				shooting.remove(s);
			}
		}
	}

	public function dispose() {
		dome.primitive.dispose();
		if( stars != null ) {
			stars.primitive.dispose();
			starTex.dispose();
		}
		if( noStars != null ) noStars.dispose();
		root.remove();
	}

	// ---------------------------------------------------------------- colores

	static function rgb( c : Int ) : h3d.Vector {
		return new h3d.Vector(((c >> 16) & 0xFF) / 255, ((c >> 8) & 0xFF) / 255, (c & 0xFF) / 255);
	}

	/** Mismo degradado que el shader: color del cielo para una elevacion e (radianes). */
	function skyAt( e : Float ) : h3d.col.Point {
		var h = Math.max(0, Math.min(1, 0.65 - 0.5 * e));
		var t = Math.max(0, Math.min(2, h * 3 - 0.5));
		var a = Math.min(1, t), b = Math.max(0, t - 1);
		var c0 = rgb(cols[0]), c1 = rgb(cols[1]), c2 = rgb(cols[2]);
		var r = ((c0.x + (c1.x - c0.x) * a) * (1 - b)) + c2.x * b;
		var g = ((c0.y + (c1.y - c0.y) * a) * (1 - b)) + c2.y * b;
		var bl = ((c0.z + (c1.z - c0.z) * a) * (1 - b)) + c2.z * b;
		return new h3d.col.Point(r, g, bl);
	}

	// ---------------------------------------------------------------- geometria

	function buildDome() {
		var R = 700.;
		var seg = 40;
		var pts = new Array<h3d.col.Point>();
		var cl = new Array<h3d.col.Point>();
		var idx = new hxd.IndexBuffer();
		// anillos mas densos donde cambia el color (alrededor del horizonte)
		var elev = [-1.57];
		var e = -1.2;
		while( e < 1.2 ) {
			elev.push(e);
			e += 0.07;
		}
		elev.push(1.57);
		for( ring in 0...elev.length ) {
			var el = elev[ring];
			var c = skyAt(el);
			for( s in 0...seg ) {
				var a = s / seg * Math.PI * 2;
				pts.push(new h3d.col.Point(Math.cos(a) * Math.cos(el) * R, Math.sin(a) * Math.cos(el) * R, Math.sin(el) * R));
				cl.push(c);
			}
		}
		for( ring in 0...elev.length - 1 )
			for( s in 0...seg ) {
				var a = ring * seg + s, b = ring * seg + (s + 1) % seg;
				var c = (ring + 1) * seg + s, d = (ring + 1) * seg + (s + 1) % seg;
				idx.push(a); idx.push(b); idx.push(c);
				idx.push(b); idx.push(d); idx.push(c);
			}
		var poly = new h3d.prim.Polygon(pts, idx);
		poly.addNormals(); // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
		poly.colors = cl;
		var mat = h3d.mat.Material.create();
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		mat.mainPass.depthWrite = false;
		mat.mainPass.addShader(new h3d.shader.VertexColor());
		dome = new h3d.scene.Mesh(poly, mat, root);
	}

	function buildStars() {
		// como el original (Render.hx: skyBoxAlpha > 0): con niebla muy densa no hay estrellas
		if( starAlpha <= 0 ) return;
		// como Game.init del original: 1024 px por cara y size * size * 0.003 = 3 145 estrellas de un texel, blancas y opacas,
		// en sitios al azar (Std.random, otro cielo en cada carga); el mismo dibujo en las 6 caras
		var size = 1024;
		// una textura 2D RGBA como las demas del juego, que StarShader lee como las 6 caras del cubo (ver StarShader)
		var px = hxd.Pixels.alloc(size, size, RGBA);
		for( i in 0...Std.int(size * size * 0.003) ) {
			var x = Std.random(size);
			var y = Std.random(size);
			px.setPixel(x, y, 0xFFFFFFFF);
		}
		starTex = new h3d.mat.Texture(size, size, null, RGBA);
		starTex.filter = Nearest;
		starTex.mipMap = None;
		starTex.wrap = Clamp;
		starTex.uploadPixels(px);
		px.dispose();
		var cube = new h3d.prim.Cube(2, 2, 2, true);
		cube.addNormals(); // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
		var mat = h3d.mat.Material.create();
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		// estrella = blanco * alfa + degradado * (1 - alfa), como la pasada de niebla del original sobre el alfa del cielo
		mat.blendMode = Alpha;
		mat.mainPass.depthWrite = false;
		// orden del original (Render.hx): el agua, luego el cielo y despues los bloques con alfa (hielo, cristal)
		mat.mainPass.layer = World.LAYER_SKY;
		var sh = new StarShader();
		sh.tex = starTex;
		sh.alpha = starAlpha;
		mat.mainPass.addShader(sh);
		stars = new h3d.scene.Mesh(cube, mat, root);
		// mas alla del terreno visible y dentro de zFar (las esquinas a ~700, como el degradado)
		stars.setScale(400);
		starRot = new h3d.Matrix();
		starRot.identity();
		stars.setRotationQuat(starQ);
	}
}
