import Common;

/**
 * Robots de la nave nodriza (añadido del port: el original no tiene ningun modelo de robot). Estan hechos de piezas con las
 * texturas de los bloques (IconMesh.polygon) y se animan: flotan, mueven los brazos y miran al jugador cuando se acerca.
 * Tipos: 0 = comerciante (detras del mostrador del puesto), 1 = dron (vuela en circulos).
 */
class Robot {

	public static inline var MERCHANT = 0;
	public static inline var DRONE = 1;

	public var root(default, null) : h3d.scene.Object;
	var kind : Int;
	var world : World;
	var atlas : h3d.mat.Texture;
	var mats : Array<h3d.mat.Material> = [];
	var x : Float;
	var y : Float;
	var z : Float;
	var face : Float;
	/** hacia donde mira detras del mostrador cuando no hay nadie cerca */
	var face0 : Float;
	var t = 0.;
	var head : h3d.scene.Object;
	var armL : h3d.scene.Object;
	var armR : h3d.scene.Object;
	var tip : h3d.scene.Object;
	var eyes : Array<h3d.scene.Object> = [];
	var headYaw = 0.;
	/** segundos que le quedan hablando (RobotBubble lo renueva mientras escribe): mueve la cabeza y los ojos parpadean rapido */
	public var talk = 0.;

	public function isMerchant() return kind == MERCHANT;

	/** encima de la cabeza, en el mundo (para el globo de dialogo) */
	public function headPos() return { x : x, y : y, z : z + 1.75 };

	/** (x, y, z): centro de la celda donde esta; face: hacia donde mira (radianes, 0 = +x) */
	public function new( world : World, atlas : h3d.mat.Texture, kind : Int, x : Float, y : Float, z : Float, face : Float ) {
		this.world = world;
		this.atlas = atlas;
		this.kind = kind;
		this.x = x;
		this.y = y;
		this.z = z;
		this.face = face;
		this.face0 = face;
		t = Math.random() * 10;
		root = new h3d.scene.Object(world.root);
		if( kind == DRONE ) buildDrone() else buildMerchant();
		place();
	}

	// ---------------------------------------------------------------- piezas

	function mat() : h3d.mat.Material {
		var m = h3d.mat.Material.create(atlas);
		m.shadows = false;
		m.mainPass.enableLights = false;
		m.mainPass.addShader(new h3d.shader.VertexColor());
		m.mainPass.addShader(world.sky.fog);
		m.textureShader.killAlpha = true;
		m.textureShader.killAlphaThreshold = 0.5;
		mats.push(m);
		return m;
	}

	/** caja de tamano (sx, sy, sz) centrada en (ox, oy, oz) dentro de parent, con la textura del bloque k */
	function part( parent : h3d.scene.Object, k : BlockKind, sx : Float, sy : Float, sz : Float, ox : Float, oy : Float, oz : Float, glow = false ) {
		var poly = IconMesh.polygon(Block.get(k), true);
		var holder = new h3d.scene.Object(parent);
		holder.setPosition(ox, oy, oz);
		var m = new h3d.scene.Mesh(poly, glow ? glowMat() : mat(), holder);
		m.setPosition(-sx * 0.5, -sy * 0.5, -sz * 0.5);
		m.scaleX = sx;
		m.scaleY = sy;
		m.scaleZ = sz;
		return holder;
	}

	/** las luces (ojos, propulsor, antena) no se oscurecen con la luz del sitio */
	function glowMat() : h3d.mat.Material {
		var m = h3d.mat.Material.create(atlas);
		m.shadows = false;
		m.mainPass.enableLights = false;
		m.mainPass.addShader(world.sky.fog);
		return m;
	}

	function buildMerchant() {
		// base que flota con su propulsor
		part(root, BShipTubes, 0.8, 0.8, 0.25, 0, 0, 0.35);
		part(root, BLamp, 0.45, 0.45, 0.08, 0, 0, 0.19, true);
		// cuerpo y pantalla del pecho
		part(root, BShipHull, 0.9, 0.75, 0.85, 0, 0, 0.92);
		part(root, BMotherPanel, 0.95, 0.8, 0.12, 0, 0, 1.38);
		part(root, BShipComputer, 0.06, 0.45, 0.35, 0.46, 0, 0.95);
		// cabeza (gira), con dos ojos y una antena
		head = new h3d.scene.Object(root);
		head.setPosition(0, 0, 1.47);
		part(head, BMotherPanel, 0.18, 0.18, 0.1, 0, 0, 0.03);
		part(head, BShipHull, 0.55, 0.6, 0.45, 0, 0, 0.3);
		part(head, BMotherDark, 0.04, 0.5, 0.22, 0.28, 0, 0.33);       // visor
		eyes.push(part(head, BLamp, 0.04, 0.13, 0.08, 0.31, -0.13, 0.33, true));
		eyes.push(part(head, BLamp, 0.04, 0.13, 0.08, 0.31, 0.13, 0.33, true));
		part(head, BIron, 0.05, 0.05, 0.35, -0.1, 0.18, 0.7);
		tip = part(head, BLamp, 0.1, 0.1, 0.1, -0.1, 0.18, 0.9, true);
		// brazos con hombro, brazo y pinza
		armL = arm(-1);
		armR = arm(1);
	}

	function arm( side : Int ) : h3d.scene.Object {
		var sh = new h3d.scene.Object(root);
		sh.setPosition(0, side * 0.5, 1.25);
		part(sh, BShipTubes, 0.22, 0.22, 0.22, 0, 0, 0);
		part(sh, BMotherPanel, 0.16, 0.16, 0.5, 0, 0, -0.33);
		part(sh, BShipTubes, 0.2, 0.24, 0.16, 0.04, 0, -0.62);
		return sh;
	}

	function buildDrone() {
		part(root, BShipGlassBlack, 0.45, 0.45, 0.3, 0, 0, 0);
		part(root, BMotherPanel, 0.6, 0.6, 0.06, 0, 0, 0.17);
		for( a in 0...4 ) {
			var ang = a * Math.PI / 2 + Math.PI / 4;
			part(root, BIron, 0.05, 0.05, 0.05, Math.cos(ang) * 0.35, Math.sin(ang) * 0.35, 0.22);
			part(root, BIronFence, 0.3, 0.3, 0.02, Math.cos(ang) * 0.45, Math.sin(ang) * 0.45, 0.25);
		}
		eyes.push(part(root, BLamp, 0.05, 0.16, 0.08, 0.23, 0, 0.02, true));
		tip = part(root, BLamp, 0.2, 0.2, 0.05, 0, 0, -0.18, true);
	}

	// ---------------------------------------------------------------- animacion

	function place() {
		var l = world.lightAt(Std.int(x), Std.int(y), Std.int(z + 1)) / 15;
		if( l < 0.45 ) l = 0.45;
		for( m in mats ) m.color.set(l, l, l);
	}

	public function update( dt : Float, px : Float, py : Float, pz : Float ) {
		t += dt;
		if( kind == DRONE ) {
			// vuela en un circulo amplio, inclinado hacia donde va
			var r = 3.0, a = t * 0.35;
			root.setPosition(x + Math.cos(a) * r, y + Math.sin(a) * r, z + Math.sin(t * 1.3) * 0.25);
			root.setRotation(0.12 * Math.cos(a), 0.12 * Math.sin(a), a + Math.PI / 2);
			tip.visible = Std.int(t * 3) % 4 != 0;
			return;
		}
		root.setPosition(x, y, z + Math.sin(t * 1.8) * 0.06);
		// el cuerpo entero se gira hacia el jugador si esta cerca (la tienda esta abierta por todos lados: se le ve desde detras);
		// si no, vuelve poco a poco a mirar hacia delante
		var dx = px - x, dy = py - y;
		var near = Math.sqrt(dx * dx + dy * dy) < 9;
		var turn = (near ? Math.atan2(dy, dx) : face0) - face;
		while( turn > Math.PI ) turn -= Math.PI * 2;
		while( turn < -Math.PI ) turn += Math.PI * 2;
		face += turn * Math.min(1, dt * 2.5);
		root.setRotation(0, 0, face);
		// la cabeza va un poco por delante del cuerpo; lejos, mira a un lado y a otro
		var target = near ? Math.atan2(dy, dx) - face : Math.sin(t * 0.4) * 0.6;
		while( target > Math.PI ) target -= Math.PI * 2;
		while( target < -Math.PI ) target += Math.PI * 2;
		if( target > 1.2 ) target = 1.2 else if( target < -1.2 ) target = -1.2;
		headYaw += (target - headYaw) * Math.min(1, dt * 4);
		// hablando: asiente y ladea la cabeza un poco, deprisa
		var nod = 0., tilt = 0.;
		if( talk > 0 ) {
			talk -= dt;
			nod = Math.sin(t * 15) * 0.12 + Math.sin(t * 6.3) * 0.05;
			tilt = Math.sin(t * 4.1) * 0.08;
		}
		head.setRotation(tilt, nod, headYaw + (talk > 0 ? Math.sin(t * 3.2) * 0.12 : 0));
		// brazos: como si atendiera el mostrador
		armL.setRotation(0, -0.35 + Math.sin(t * 1.1) * 0.25, 0);
		armR.setRotation(0, -0.35 + Math.sin(t * 1.1 + 2.0) * 0.25, 0);
		// ojos que parpadean y antena que destella
		var blink = talk > 0 ? (t * 10) % 1 < 0.3 : (t % 4.0) < 0.12;
		for( e in eyes ) e.visible = !blink;
		tip.visible = (t % 1.5) < 0.9;
	}

	public function remove() {
		root.remove();
	}
}
