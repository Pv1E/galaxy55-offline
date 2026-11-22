import Common;

/** Geometria acumulada de un chunk para un material. */
class MeshBuf {
	public var pts = new Array<h3d.col.Point>();
	public var uvs = new Array<h3d.prim.UV>();
	public var cols = new Array<h3d.col.Point>();
	public var idx = new hxd.IndexBuffer();
	public function new() {}
}

/**
	Prueba de viabilidad del juego nativo: genera un planeta con los generadores originales,
	construye la geometria por chunks de 16x16 y permite recorrerlo en primera persona.

	Uso: hl render.hl [semilla] [bioma] [tamano_en_chunks_de_128] [captura.png]
	Con captura.png guarda una imagen desde el punto de aparicion y sale.

	Controles: WASD mover, raton mirar, Espacio saltar (o subir en vuelo), Shift correr (o bajar en vuelo),
	F alternar vuelo, Esc soltar/capturar el raton. Mando: sticks, A salta, LB/RB bajar/subir en vuelo, Y vuelo.
**/
class RenderMain extends hxd.App {

	static inline var CSIZE = 16;
	static inline var ZBITS = 7;
	static inline var HEIGHT = 128;
	static inline var TE = 0.999;
	static inline var EYE = 1.62;
	static inline var RADIUS = 0.3;
	static inline var BODY = 1.8;

	var seed = 1234;
	var biomeName = "BIAutumn";
	var sizeChunks = 1;
	var shotPath : String = null;

	var gen : gen.DetailsGenerator;
	var world : haxe.io.Bytes;
	var size : Int;
	var atlas : h3d.mat.Texture;
	var frames = 0;
	var faces = 0;
	var shotDone = false;

	// jugador
	var px = 0.;
	var py = 0.;
	var pz = 0.;
	var vz = 0.;
	var yaw = 0.;
	var pitch = 0.;
	var fly = false;
	var onGround = false;
	var captured = false;
	var pad : hxd.Pad;
	var hud : h2d.Text;

	override function init() {
		var args = Sys.args();
		if( args.length > 0 ) seed = Std.parseInt(args[0]);
		if( args.length > 1 ) biomeName = args[1];
		if( args.length > 2 ) sizeChunks = Std.parseInt(args[2]);
		if( args.length > 3 ) shotPath = args[3];

		var t0 = haxe.Timer.stamp();
		generate();
		var t1 = haxe.Timer.stamp();

		var png = sys.io.File.getBytes("src/G55/fla/client/gfx/texture.png");
		atlas = hxd.res.Any.fromBytes("texture.png", png).toTexture();
		atlas.filter = Nearest;
		atlas.mipMap = None;

		var counts = new Map<String, Int>();
		for( i in 0...world.length ) {
			var id = world.get(i);
			if( id == 0 ) continue;
			var b = gen.blocks[id];
			var k = b == null ? "null" : Std.string(b.type) + " (" + Type.enumConstructor(b.k) + (b.collide ? ",choca" : ",NO choca") + ")";
			counts.set(k, (counts.exists(k) ? counts.get(k) : 0) + 1);
		}
		var ks = [for( k in counts.keys() ) k];
		ks.sort(function(a, b) return counts.get(b) - counts.get(a));
		Sys.println("tipos de bloque: " + [for( k in ks.slice(0, 14) ) k + "=" + counts.get(k)].join(", "));

		var meshes = 0;
		for( cy in 0...size >> 4 )
			for( cx in 0...size >> 4 )
				meshes += buildChunk(cx, cy);
		var t2 = haxe.Timer.stamp();
		Sys.println('seed=$seed biome=$biomeName size=$size generar=${Std.int((t1 - t0) * 1000)}ms mallar=${Std.int((t2 - t1) * 1000)}ms mallas=$meshes caras=$faces');

		var c = s3d.camera;
		c.zNear = 0.1;
		c.zFar = 1500;
		c.fovY = 70;
		engine.backgroundColor = 0xFF6FA8DC;

		spawn();

		hud = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
		hud.x = 8;
		hud.y = 6;
		hud.textColor = 0xFFFFFF;
		hud.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 0.8 };

		if( shotPath == null ) {
			hxd.Pad.wait(function(p) pad = p);
			captureMouse(true);
		}
	}

	function generate() {
		var biome : BiomeKind = Type.createEnum(BiomeKind, biomeName);
		size = sizeChunks << Const.BITS;
		gen = new gen.DetailsGenerator(size, seed);
		gen.reserveBlocks(biome);
		gen.startGenerate(biome);
		while( gen.process(1000000) ) {}
		world = gen.getBytes().b;
	}

	// ---------------------------------------------------------------- mundo

	inline function voxel( x : Int, y : Int, z : Int ) : Int {
		if( x < 0 ) x += size else if( x >= size ) x -= size;
		if( y < 0 ) y += size else if( y >= size ) y -= size;
		if( z < 0 ) return 1;
		if( z >= HEIGHT ) return 0;
		return world.get(((x + y * size) << ZBITS) | z);
	}

	/** true si la cara contra este voxel se ve (aire o bloque que deja pasar la luz) */
	inline function open( x : Int, y : Int, z : Int ) : Bool {
		var id = voxel(x, y, z);
		return id == 0 || gen.btrans[id];
	}

	/** bloque con el que se choca: usa el atributo collide del original (hojas si, agua y detalles no) */
	inline function solid( x : Int, y : Int, z : Int ) : Bool {
		var id = voxel(x, y, z);
		if( id == 0 ) return false;
		var b = gen.blocks[id];
		return b != null && b.collide;
	}

	/** suelo opaco (para elegir el punto de aparicion) */
	inline function opaque( x : Int, y : Int, z : Int ) : Bool {
		var id = voxel(x, y, z);
		return id != 0 && !gen.btrans[id];
	}

	// ---------------------------------------------------------------- mallado

	function addQuad( m : MeshBuf, p : Array<Float>, tile : Int, shade : Float ) {
		if( tile < 0 || tile >= 0xFFF ) return;
		var tx = tile & 63, ty = tile >> 6;
		var u0 = tx / 64 + (1 - TE) / 128, v0 = ty / 64 + (1 - TE) / 128;
		var u1 = u0 + TE / 64, v1 = v0 + TE / 64;
		var b = m.pts.length;
		m.pts.push(new h3d.col.Point(p[0], p[1], p[2]));
		m.pts.push(new h3d.col.Point(p[3], p[4], p[5]));
		m.pts.push(new h3d.col.Point(p[6], p[7], p[8]));
		m.pts.push(new h3d.col.Point(p[9], p[10], p[11]));
		m.uvs.push(new h3d.prim.UV(u0, v1));
		m.uvs.push(new h3d.prim.UV(u1, v1));
		m.uvs.push(new h3d.prim.UV(u1, v0));
		m.uvs.push(new h3d.prim.UV(u0, v0));
		for( i in 0...4 ) m.cols.push(new h3d.col.Point(shade, shade, shade));
		m.idx.push(b); m.idx.push(b + 1); m.idx.push(b + 2);
		m.idx.push(b); m.idx.push(b + 2); m.idx.push(b + 3);
		faces++;
	}

	function emitMesh( m : MeshBuf, kind : Int ) : Int {
		if( m.pts.length == 0 ) return 0;
		var poly = new h3d.prim.Polygon(m.pts, m.idx);
		poly.addNormals(); // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
		poly.uvs = m.uvs;
		poly.colors = m.cols;
		var mat = h3d.mat.Material.create(atlas);
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		mat.mainPass.addShader(new h3d.shader.VertexColor());
		if( kind == 1 ) {
			// bloques con alfa (hojas): se descartan los pixeles transparentes
			mat.textureShader.killAlpha = true;
			mat.textureShader.killAlphaThreshold = 0.5;
		} else if( kind == 2 ) {
			// agua: translucida y sin escribir profundidad
			mat.blendMode = Alpha;
			mat.color.a = 0.6;
			mat.mainPass.depthWrite = false;
			mat.mainPass.setPassName("alpha");
		}
		new h3d.scene.Mesh(poly, mat, s3d);
		return 1;
	}

	function buildChunk( cx : Int, cy : Int ) : Int {
		var solidBuf = new MeshBuf();
		var alphaBuf = new MeshBuf();
		var waterBuf = new MeshBuf();

		for( y in cy * CSIZE...(cy + 1) * CSIZE )
			for( x in cx * CSIZE...(cx + 1) * CSIZE )
				for( z in 1...HEIGHT ) {
					var id = voxel(x, y, z);
					if( id == 0 ) continue;
					var b = gen.blocks[id];
					if( b == null ) continue;
					var su = Math.sqrt(b.shadeUp), sd = Math.sqrt(b.shadeDown);
					var sx = Math.sqrt(b.shadeX), sy = Math.sqrt(b.shadeY);
					var fx = x, fy = y, fz = z;
					switch( b.type ) {
					case BTWater:
						// solo la superficie
						if( voxel(x, y, z + 1) == 0 )
							addQuad(waterBuf, [fx, fy, fz + 0.9, fx + 1, fy, fz + 0.9, fx + 1, fy + 1, fz + 0.9, fx, fy + 1, fz + 0.9], b.tu, su);
					case BTFull, BTAlpha, BTTransp:
						var m = b.type == BTFull ? solidBuf : alphaBuf;
						if( open(x, y, z + 1) ) addQuad(m, [fx, fy, fz + 1, fx + 1, fy, fz + 1, fx + 1, fy + 1, fz + 1, fx, fy + 1, fz + 1], b.tu, su);
						if( open(x, y, z - 1) ) addQuad(m, [fx, fy + 1, fz, fx + 1, fy + 1, fz, fx + 1, fy, fz, fx, fy, fz], b.td, sd);
						if( open(x - 1, y, z) ) addQuad(m, [fx, fy + 1, fz, fx, fy, fz, fx, fy, fz + 1, fx, fy + 1, fz + 1], b.tlr, sx);
						if( open(x + 1, y, z) ) addQuad(m, [fx + 1, fy, fz, fx + 1, fy + 1, fz, fx + 1, fy + 1, fz + 1, fx + 1, fy, fz + 1], b.tlr, sx);
						if( open(x, y - 1, z) ) addQuad(m, [fx, fy, fz, fx + 1, fy, fz, fx + 1, fy, fz + 1, fx, fy, fz + 1], b.tlr, sy);
						if( open(x, y + 1, z) ) addQuad(m, [fx + 1, fy + 1, fz, fx, fy + 1, fz, fx, fy + 1, fz + 1, fx + 1, fy + 1, fz + 1], b.tlr, sy);
					default:
					}
				}

		return emitMesh(solidBuf, 0) + emitMesh(alphaBuf, 1) + emitMesh(waterBuf, 2);
	}

	// ---------------------------------------------------------------- jugador

	function spawn() {
		var x = size >> 1, y = size >> 1;
		var z = HEIGHT - 1;
		while( z > 1 && !opaque(x, y, z) ) z--;
		px = x + 0.5;
		py = y + 0.5;
		pz = z + 1.01;
		vz = 0;
		yaw = Math.PI * 0.25;
		pitch = -0.25;
	}

	function captureMouse( on : Bool ) {
		captured = on;
		hxd.Window.getInstance().mouseMode = on ? Relative(onMouse, true) : Absolute;
	}

	function onMouse( e : hxd.Event ) {
		yaw += e.relX * 0.0025;
		pitch -= e.relY * 0.0025;
		if( pitch > 1.5 ) pitch = 1.5;
		if( pitch < -1.5 ) pitch = -1.5;
	}

	function collides( x : Float, y : Float, z : Float ) : Bool {
		var x0 = Math.floor(x - RADIUS), x1 = Math.floor(x + RADIUS);
		var y0 = Math.floor(y - RADIUS), y1 = Math.floor(y + RADIUS);
		var z0 = Math.floor(z), z1 = Math.floor(z + BODY);
		for( ix in x0...x1 + 1 )
			for( iy in y0...y1 + 1 )
				for( iz in z0...z1 + 1 )
					if( solid(ix, iy, iz) ) return true;
		return false;
	}

	inline function clampPos( v : Float ) : Float {
		return v < RADIUS ? RADIUS : (v > size - RADIUS ? size - RADIUS : v);
	}

	function updatePlayer( dt : Float ) {
		if( dt > 0.05 ) dt = 0.05;
		var K = hxd.Key;
		if( K.isPressed(K.F) || (pad != null && pad.isPressed(pad.config.Y)) ) {
			fly = !fly;
			vz = 0;
		}
		if( K.isPressed(K.ESCAPE) ) captureMouse(!captured);

		var fwd = 0., side = 0., up = 0.;
		if( K.isDown(K.W) || K.isDown(K.UP) ) fwd += 1;
		if( K.isDown(K.S) || K.isDown(K.DOWN) ) fwd -= 1;
		if( K.isDown(K.D) ) side += 1;
		if( K.isDown(K.A) ) side -= 1;
		var run = K.isDown(K.SHIFT) || K.isDown(K.CTRL);
		var jump = K.isDown(K.SPACE);
		var down = K.isDown(K.SHIFT);
		if( pad != null ) {
			var dead = 0.2;
			var lx = pad.xAxis, ly = pad.yAxis, rx = pad.rxAxis, ry = pad.ryAxis;
			if( Math.abs(lx) > dead ) side += lx;
			if( Math.abs(ly) > dead ) fwd -= ly;
			if( Math.abs(rx) > dead ) yaw += rx * 2.5 * dt;
			if( Math.abs(ry) > dead ) pitch -= ry * 2.0 * dt;
			if( pad.isDown(pad.config.A) ) jump = true;
			if( pad.isDown(pad.config.LB) ) down = true;
			if( pad.isDown(pad.config.RB) ) jump = true;
			if( pad.isDown(pad.config.analogClick) ) run = true;
		}
		if( pitch > 1.5 ) pitch = 1.5;
		if( pitch < -1.5 ) pitch = -1.5;

		var cy = Math.cos(yaw), sy = Math.sin(yaw);
		var speed : Float;
		var dx : Float, dy : Float;
		if( fly ) {
			speed = run ? 36 : 14;
			var cp = Math.cos(pitch), sp = Math.sin(pitch);
			dx = (cy * cp * fwd - sy * side) * speed * dt;
			dy = (sy * cp * fwd + cy * side) * speed * dt;
			var dz = (sp * fwd + (jump ? 1 : 0) - (down ? 1 : 0)) * speed * dt;
			moveAxis(dx, 0, 0);
			moveAxis(0, dy, 0);
			moveAxis(0, 0, dz);
		} else {
			speed = run ? 9 : 5.5;
			var len = Math.sqrt(fwd * fwd + side * side);
			if( len > 1 ) { fwd /= len; side /= len; }
			dx = (cy * fwd - sy * side) * speed * dt;
			dy = (sy * fwd + cy * side) * speed * dt;
			if( jump && onGround ) {
				vz = 8.5;
				onGround = false;
			}
			vz -= 28 * dt;
			if( vz < -60 ) vz = -60;
			moveAxis(dx, 0, 0);
			moveAxis(0, dy, 0);
			var hitZ = moveAxis(0, 0, vz * dt);
			onGround = hitZ && vz < 0;
			if( hitZ ) vz = 0;
		}
		px = clampPos(px);
		py = clampPos(py);
	}

	/** mueve en un eje con colision; devuelve true si choco */
	function moveAxis( dx : Float, dy : Float, dz : Float ) : Bool {
		if( dx == 0 && dy == 0 && dz == 0 ) return false;
		var steps = Std.int(Math.max(1, Math.ceil(Math.max(Math.abs(dx), Math.max(Math.abs(dy), Math.abs(dz))) / 0.25)));
		var sx = dx / steps, sy = dy / steps, sz = dz / steps;
		for( i in 0...steps ) {
			var nx = px + sx, ny = py + sy, nz = pz + sz;
			if( collides(nx, ny, nz) ) return true;
			px = nx;
			py = ny;
			pz = nz;
		}
		return false;
	}

	function updateCamera() {
		var ex = px, ey = py, ez = pz + EYE;
		var cp = Math.cos(pitch);
		var c = s3d.camera;
		c.pos.set(ex, ey, ez);
		c.target.set(ex + Math.cos(yaw) * cp, ey + Math.sin(yaw) * cp, ez + Math.sin(pitch));
		c.up.set(0, 0, 1);
	}

	override function update( dt : Float ) {
		frames++;
		if( shotPath == null ) updatePlayer(dt);
		updateCamera();
		hud.text = (fly ? "VUELO" : "CAMINAR") + "  pos " + Std.int(px) + "," + Std.int(py) + "," + Std.int(pz) + "  " + Std.int(engine.fps) + " fps"
			+ "\nWASD mover  Espacio saltar  F vuelo  Shift correr  Esc raton";

		if( shotPath != null && frames == 4 && !shotDone ) {
			shotDone = true;
			var w = engine.width, h = engine.height;
			var tex = new h3d.mat.Texture(w, h, [Target]);
			tex.depthBuffer = new h3d.mat.Texture(w, h, [Target], Depth24Stencil8);
			engine.pushTarget(tex);
			engine.clear(0xFF6FA8DC, 1, 0);
			s3d.render(engine);
			s2d.render(engine);
			engine.popTarget();
			var px = tex.capturePixels();
			sys.io.File.saveBytes(shotPath, px.toPNG());
			Sys.println("captura guardada: " + shotPath);
			Sys.exit(0);
		}
	}

	static function main() {
		new RenderMain();
	}
}
