import Common;

/**
 * El bloque elegido, en la mano (Render.render del original, "in-hand block"): se dibuja con una camara propia en el origen
 * que mira a +x, en (1, 0.8, -0.8), girado 120 grados, delante de todo (depthScale 0.01). Se mueve con el vaiven del
 * casco (bobbing / 50) y su luz sigue a la del jugador con suavizado (curLight * 0.7 + luz * 0.3).
 * Aqui se coloca en el mundo con los ejes de la camara del juego, que da lo mismo en pantalla.
 */
class Hand {

	var world : World;
	var atlas : h3d.mat.Texture;
	public var frame(default, null) : h3d.scene.Object;
	var turn : h3d.scene.Object;
	var mesh : h3d.scene.Mesh;
	var mat : h3d.mat.Material;
	var block : Block;
	var curLight : Null<Float>;

	public function new( world : World, atlas : h3d.mat.Texture ) {
		this.world = world;
		this.atlas = atlas;
		frame = new h3d.scene.Object(world.root);
		turn = new h3d.scene.Object(frame);
		turn.setRotation(0, 0, Math.PI * 2 / 3);
		mat = h3d.mat.Material.create(atlas);
		mat.shadows = false;
		mat.blendMode = None;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		mat.mainPass.depth(true, Always);
		mat.mainPass.setPassName("additive");
		mat.mainPass.addShader(new h3d.shader.VertexColor());
		mat.textureShader.killAlpha = true;
		mat.textureShader.killAlphaThreshold = 0.5;
		frame.visible = false;
	}

	public function update( b : Block, cam : h3d.Camera, bobX : Float, bobY : Float ) {
		if( b != block ) {
			block = b;
			if( mesh != null ) {
				mesh.primitive.dispose();
				mesh.remove();
				mesh = null;
			}
			// el Kube invisible y los que el recorte borraria enteros: translucidos como su icono (IconMesh.seeThrough), con sus 6
			// caras; con el recorte la mano se quedaba vacia
			var clear = b != null && IconMesh.seeThrough(b);
			var poly = b == null ? null : IconMesh.polygon(b, true, 1.0, clear);
			if( poly != null ) {
				mesh = new h3d.scene.Mesh(poly, mat, turn);
				mesh.setPosition(-0.5, -0.5, -0.5);
				// los cubos son convexos: sin profundidad basta con no dibujar las caras de atras
				mat.mainPass.culling = clear || b.type == BTModel || b.type == BTModel2Side || b.type == BTSprite ? None : Back;
				// en la misma pasada (additive, delante de todo): mainPass.setBlendMode no la cambia, Material.blendMode si
				mat.mainPass.setBlendMode(clear ? Alpha : None);
				mat.mainPass.depthWrite = !clear;
				mat.textureShader.killAlpha = !clear;
			}
		}
		if( mesh == null ) {
			frame.visible = false;
			curLight = null;
			return;
		}
		frame.visible = true;
		var dz = b.model == MCross ? 0.5 : 0.;
		turn.setPosition(1, 0.8 + bobX / 50, -0.8 - bobY / 50 + dz);

		// ejes de la camara: x = adelante, y = izquierda, z = arriba
		var f = cam.target.sub(cam.pos);
		f.normalize();
		var l = new h3d.Vector(0, 0, 1).cross(f);
		l.normalize();
		var u = f.cross(l);
		var m = new h3d.Matrix();
		m.identity();
		m._11 = f.x; m._12 = f.y; m._13 = f.z;
		m._21 = l.x; m._22 = l.y; m._23 = l.z;
		m._31 = u.x; m._32 = u.y; m._33 = u.z;
		m._41 = cam.pos.x; m._42 = cam.pos.y; m._43 = cam.pos.z;
		frame.setTransform(m);

		var tl = world.lightAt(Math.floor(cam.pos.x), Math.floor(cam.pos.y), Math.floor(cam.pos.z)) / World.LBASE;
		curLight = curLight == null ? tl : curLight * 0.7 + tl * 0.3;
		var c = Math.min(1.3, curLight);
		mat.color.set(c, c, c, 1);
	}

	public function dispose() {
		if( mesh != null ) mesh.primitive.dispose();
		frame.remove();
	}
}
