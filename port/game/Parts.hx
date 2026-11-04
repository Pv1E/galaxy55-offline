import Common;

private class Part {
	public var x : Float;
	public var y : Float;
	public var z : Float;
	public var vx : Float;
	public var vy : Float;
	public var vz : Float;
	public var life = 50.;
	public var light : Float;
	/** 3 vertices: desplazamiento en pantalla (dx, dy) y uv */
	public var v : Array<Float>;
	public function new() {}
}

/**
 * Trozos que saltan al romper un bloque, copia de r3d/Particles.hx del original (doBreak, doBreakParts, MovingPart):
 * 75 triangulos con un pedazo de la textura de la cara de la que salen, gravedad 0.009, y en el suelo se frenan y se gastan.
 * Como en PartShader, el triangulo mira siempre a la camara y su tamano se suma despues de proyectar (igual en todo el campo de vision).
 */
class Parts {

	var world : World;
	var mesh : h3d.scene.Mesh;
	var mat : h3d.mat.Material;
	var list : Array<Part> = [];
	var partStep = 0;
	static inline var MAX = 20000;

	public function new( world : World, atlas : h3d.mat.Texture ) {
		this.world = world;
		mat = h3d.mat.Material.create(atlas);
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		mat.mainPass.addShader(new h3d.shader.VertexColor());
		mat.mainPass.addShader(world.sky.fog);
		mat.textureShader.killAlpha = true;
		// cambio del port: el original corta en 0.001, pero el png tiene texeles casi transparentes (alfa 1/255 a 6/255, blancos en
		// la hierba roja) que el mundo no muestra (corte 0.5) y aqui salian opacos: trozos blancos al romper las hierbas que el
		// port hace rompibles. Con 0.03 desaparecen; el hielo (alfa >= 0.28) no cambia y el cristal solo pierde sus pocos texeles de 6/255
		mat.textureShader.killAlphaThreshold = 0.03;
	}

	/** Particles.doBreak (count: intentos, 75 en el original) */
	public function doBreak( x : Int, y : Int, z : Int, b : Block, count = 75 ) {
		var h = b.getHeight();
		for( i in 0...count ) {
			var fx : Float = x, fy : Float = y, fz : Float = z;
			var face = Std.random(6);
			switch( face ) {
			case 0, 1:
				fy += Math.random();
				fz += Math.random() * h;
				fx += face;
			case 2, 3:
				fx += Math.random();
				fz += Math.random() * h;
				fy += face & 1;
			default:
				fx += Math.random();
				fy += Math.random();
				fz += face & 1;
			}
			if( world.lightAt(Math.floor(fx), Math.floor(fy), Math.floor(fz)) <= 0 ) continue;
			add(fx, fy, fz, b, x, y, z, 2.);
		}
	}

	/** Game.update: un trozo en el punto de impacto del laser (doBreakParts con scale 1); (bx, by, bz) el bloque golpeado */
	public function doLaser( sx : Float, sy : Float, sz : Float, b : Block, bx : Int, by : Int, bz : Int ) {
		add(sx, sy, sz, b, bx, by, bz, 1.);
	}

	/** Particles.doBreakParts (la velocidad inicial que depende de la direccion se sustituye enseguida, como en el original) */
	function add( sx : Float, sy : Float, sz : Float, b : Block, bx : Int, by : Int, bz : Int, scale : Float ) {
		// cambio del port: como mucho MAX trozos a la vez (una cadena de bombas antiguas soltaba decenas de miles)
		if( list.length >= MAX ) return;
		var p = new Part();
		p.x = sx;
		p.y = sy;
		p.z = sz;
		p.light = Math.min(1.3, lightAt(sx, sy, sz) / World.LBASE);
		if( p.x % 1 > 0.01 ) {
			var d;
			do d = Math.random() * 0.3 - 0.25 while( Std.int(p.x) != Std.int(p.x + d) );
			p.x += d;
		}
		if( p.y % 1 > 0.01 ) {
			var d;
			do d = Math.random() * 0.3 - 0.25 while( Std.int(p.y) != Std.int(p.y + d) );
			p.y += d;
		}
		if( p.z % 1 > 0.01 ) {
			var d;
			do d = Math.random() * 0.3 - 0.25 while( Std.int(p.z) != Std.int(p.z + d) );
			p.z += d;
		}
		p.vx = Math.random() * 0.05 * (Std.random(2) * 2 - 1);
		p.vy = Math.random() * 0.05 * (Std.random(2) * 2 - 1);
		p.vz = Std.random(100) < 30 ? 0.05 + Math.random() * 0.05 : Math.random() * 0.05;

		var dx = p.x - bx, dy = p.y - by, dz = p.z - bz;
		var tex = b.tlr;
		if( dx == 0 || dx == 1 ) {
			dx = dy;
			dy = dz;
		} else if( dy == 0 || dy == 1 ) {
			dy = dz;
		} else
			tex = dz == 0 ? b.td : b.tu;
		if( tex < 0 || tex >= 0xFFF ) return;
		var size = (Math.random() * 0.15 + 0.05) * scale;
		var a = 0.;
		var tu = (tex & 63) / 64, tv = (tex >> 6) / 64;
		p.v = [];
		for( i in 0...3 ) {
			a += Math.random() * Math.PI / 2 + Math.PI / 3;
			var x = Math.cos(a) * size, y = Math.sin(a) * size;
			var tx = dx + x, ty = 1 - (dy + y);
			if( tx < 0 ) tx = 0 else if( tx > 1 ) tx = 1;
			if( ty < 0 ) ty = 0 else if( ty > 1 ) ty = 1;
			p.v.push(x * 0.7);
			p.v.push(y * 0.7);
			p.v.push(tu + tx / 64);
			p.v.push(tv + ty / 64);
		}
		list.push(p);
	}

	/** Level.getLightAt: dentro de un bloque cuenta tambien la luz de la celda de su cara mas cercana (los trozos del laser
	    salen en la cara del bloque golpeado, que no tiene luz) */
	function lightAt( x : Float, y : Float, z : Float ) : Int {
		var ix = Math.floor(x), iy = Math.floor(y), iz = Math.floor(z);
		var l = world.lightAt(ix, iy, iz);
		var b = world.block(ix, iy, iz);
		if( b == null ) return l;
		var h = b.getHeight();
		var distX = x - ix, dx = -1;
		if( distX >= 0.5 ) { distX = 1 - distX; dx = 1; }
		var distY = y - iy, dy = -1;
		if( distY >= 0.5 ) { distY = 1 - distY; dy = 1; }
		var distZ = z - iz, dz = -1;
		if( distZ >= h * 0.5 ) { distZ = h - distZ; dz = 1; }
		var x2 = ix, y2 = iy, z2 = iz;
		if( distX < distY ) {
			if( distX < distZ ) x2 += dx else z2 += dz;
		} else if( distY < distZ )
			y2 += dy;
		else
			z2 += dz;
		var l2 = world.lightAt(x2, y2, z2);
		return l2 > l ? l2 : l;
	}

	/** MovingPart.update y Particles.update; dt en tmod (30 por segundo) */
	public function update( dt : Float, cam : h3d.Camera, eyeX : Float, eyeY : Float ) {
		if( mesh != null ) {
			mesh.primitive.dispose();
			mesh.remove();
			mesh = null;
		}
		if( list.length == 0 ) return;
		var partCount = Std.int(list.length / 1000) + 1;
		var wear = Math.max(1, Math.sqrt(list.length) / 8);
		var i = 0;
		while( i < list.length ) {
			var p = list[i];
			p.x += p.vx * dt;
			p.y += p.vy * dt;
			p.z += p.vz * dt;
			p.vz -= 0.009 * dt;
			if( (partStep++ % partCount) == 0 && world.collidePoint(p.x, p.y, p.z) ) {
				p.life -= wear * dt;
				p.vz = 0;
				p.vx *= Math.pow(0.95, dt);
				p.vy *= Math.pow(0.95, dt);
			}
			// cambio del port: con muchos trozos el choque se mira cada partCount pasos y alguno atravesaba el suelo y caia
			// para siempre; por debajo del mundo desaparece
			if( p.life <= 0 || p.z < 0 ) {
				list[i] = list[list.length - 1];
				list.pop();
				continue;
			}
			i++;
		}
		if( list.length == 0 ) return;

		// ejes de la pantalla; tamano en el mundo = desplazamiento tras proyectar / escala de la proyeccion
		var fwd = cam.target.sub(cam.pos);
		fwd.normalize();
		var right = fwd.cross(new h3d.Vector(0, 0, 1));
		right.normalize();
		var up = right.cross(fwd);
		up.normalize();
		var ty = Math.tan(cam.fovY * Math.PI / 360);
		var tx = ty * cam.screenRatio;
		var s = world.size;
		var pts = [], uvs = [], cols = [], idx = new hxd.IndexBuffer();
		for( p in list ) {
			var x = p.x + s * Math.round((eyeX - p.x) / s), y = p.y + s * Math.round((eyeY - p.y) / s);
			var b = pts.length;
			for( k in 0...3 ) {
				var ox = p.v[k * 4] * tx, oy = p.v[k * 4 + 1] * ty;
				pts.push(new h3d.col.Point(x + right.x * ox + up.x * oy, y + right.y * ox + up.y * oy, p.z + right.z * ox + up.z * oy));
				uvs.push(new h3d.prim.UV(p.v[k * 4 + 2], p.v[k * 4 + 3]));
				cols.push(new h3d.col.Point(p.light, p.light, p.light));
				idx.push(b + k);
			}
		}
		var poly = new h3d.prim.Polygon(pts, idx);
		poly.addNormals(); // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
		poly.uvs = uvs;
		poly.colors = cols;
		mesh = new h3d.scene.Mesh(poly, mat, world.root);
	}

	public function dispose() {
		if( mesh != null ) {
			mesh.primitive.dispose();
			mesh.remove();
		}
		list = [];
	}
}
