import Common;
import GameView.Select;

/**
 * SelectShader del original: los vertices con uv.x = 1 se desplazan max(1 / ancho, 1 / alto) * 2 en x y en y de la pantalla,
 * asi cada arista de la caja es una linea de ~1 px sea cual sea la distancia.
 */
class SelectShader extends hxsl.Shader {
	static var SRC = {
		@input var input : {
			var uv : Vec2;
		};
		@global var global : {
			var pixelSize : Vec2;
		};
		var projectedPosition : Vec4;
		function vertex() {
			projectedPosition.xy += input.uv.x * max(global.pixelSize.x, global.pixelSize.y) * projectedPosition.w;
		}
	};

	public function new() {
		super();
		setPriority(-1); // despues de la curvatura del planeta (Sky.FogShader rehace projectedPosition)
	}
}

/**
 * Efectos de excavar, copiados de Render.hx del original:
 * - caja de seleccion naranja (SelectShader: 1, 0.3, 0, 0.5) cuando no se esta usando el laser;
 * - al excavar, una copia del bloque un poco mas grande que tiembla (escala 1.015 + rand * 0.075) con alfa 0.5;
 * - si el bloque no se puede romper (roca madre...), un cubo 1.15 con la casilla (51,0) del atlas que parpadea (alfa 0.1 + 0.7 * rand);
 * - el rayo: cuatro planos cruzados con una de las 4 texturas (sin carga, amarilla, azul, rosa), mezcla aditiva,
 *   que giran y se desplazan a la velocidad propia de cada tipo.
 */
class Fx {

	var world : World;
	var atlas : h3d.mat.Texture;
	var box : h3d.scene.Mesh;
	var overlay : h3d.scene.Mesh;
	var overlayBlock : Block;
	var denied : h3d.scene.Mesh;
	var beam : h3d.scene.Mesh;
	var beamRoot : h3d.scene.Object;
	var beamUv : h3d.shader.UVDelta;
	var beamTex : Array<h3d.mat.Texture>;
	var beamId = -1;
	var time = 0.;
	/** excavando: overlay es la copia que tiembla; si no, la sombra del bloque que se va a poner */
	var mining = false;

	public function new( world : World, atlas : h3d.mat.Texture ) {
		this.world = world;
		this.atlas = atlas;
		var root = world.root;

		// Render.initSelect: cada arista es un quad (a, b, a + pixel, b + pixel); SelectShader desplaza los dos ultimos en la pantalla
		var edges = [
			[0, 0, 0, 1, 0, 0], [0, 0, 0, 0, 1, 0], [0, 0, 0, 0, 0, 1],
			[1, 0, 0, 1, 1, 0], [1, 0, 0, 1, 0, 1],
			[0, 1, 0, 1, 1, 0], [0, 1, 0, 0, 1, 1],
			[0, 0, 1, 1, 0, 1], [0, 0, 1, 0, 1, 1],
			[1, 1, 1, 0, 1, 1], [1, 1, 1, 1, 0, 1], [1, 1, 1, 1, 1, 0],
		];
		var pts = [], uvs = [], nrm = [], idx = new hxd.IndexBuffer();
		for( e in edges ) {
			var p = pts.length;
			for( d in 0...2 )
				for( k in 0...2 ) {
					pts.push(new h3d.col.Point(e[k * 3], e[k * 3 + 1], e[k * 3 + 2]));
					uvs.push(new h3d.prim.UV(d, 0));
					nrm.push(new h3d.col.Point(0, 0, 1));
				}
			idx.push(p); idx.push(p + 1); idx.push(p + 3);
			idx.push(p); idx.push(p + 3); idx.push(p + 2);
		}
		var poly = new h3d.prim.Polygon(pts, idx);
		poly.uvs = uvs;
		poly.normals = nrm; // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
		var mat = h3d.mat.Material.create();
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		mat.color.set(1, 0.3, 0, 0.5);
		mat.blendMode = Alpha;
		mat.mainPass.depthWrite = false;
		// world.sky.fog solo pone la curvatura del planeta: la niebla empieza a 10 bloques y la caja esta a menos de 7 (sin niebla, como el original)
		mat.mainPass.addShader(world.sky.fog);
		mat.mainPass.addShader(new SelectShader());
		box = new h3d.scene.Mesh(poly, mat, root);
		box.visible = false;

		denied = new h3d.scene.Mesh(IconMesh.cube(51), blendMaterial(), root);
		denied.visible = false;

		// el rayo: 4 planos que giran alrededor del eje (Render.initLazer), de longitud 1 a lo largo de +x
		var pts = [], uvs = [], idx = new hxd.IndexBuffer();
		for( r in 0...4 ) {
			var ang = r * Math.PI / 4;
			var y = Math.cos(ang), z = Math.sin(ang);
			var b = pts.length;
			pts.push(new h3d.col.Point(0, y, z));
			pts.push(new h3d.col.Point(0, -y, -z));
			pts.push(new h3d.col.Point(1, y, z));
			pts.push(new h3d.col.Point(1, -y, -z));
			uvs.push(new h3d.prim.UV(0, 1));
			uvs.push(new h3d.prim.UV(0, 0));
			uvs.push(new h3d.prim.UV(1, 1));
			uvs.push(new h3d.prim.UV(1, 0));
			idx.push(b); idx.push(b + 1); idx.push(b + 2);
			idx.push(b + 1); idx.push(b + 3); idx.push(b + 2);
		}
		var poly = new h3d.prim.Polygon(pts, idx);
		poly.addNormals(); // DirectX exige la entrada 'normal' del shader aunque no se use (OpenGL la descarta)
		poly.uvs = uvs;
		beamTex = [];
		for( n in ["lazer.png", "lazer2.png", "lazer3.png", "lazer4.png"] ) {
			var t = hxd.res.Any.fromBytes(n, Res.bytes(n)).toTexture();
			t.wrap = Repeat;
			t.filter = Linear;
			beamTex.push(t);
		}
		var mat = h3d.mat.Material.create(beamTex[0]);
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		mat.blendMode = Add;
		// como el original (PolyTexShader.zScale = 0): el rayo siempre se ve, nada lo tapa
		mat.mainPass.depth(false, Always);
		mat.mainPass.setPassName("alpha");
		beamUv = new h3d.shader.UVDelta();
		mat.mainPass.addShader(beamUv);
		// el padre orienta y escala el rayo; el hijo gira sobre su propio eje (rotate() de Heaps gira sobre el eje X del mundo)
		beamRoot = new h3d.scene.Object(root);
		beam = new h3d.scene.Mesh(poly, mat, beamRoot);
		beamRoot.visible = false;
	}

	function blendMaterial() : h3d.mat.Material {
		var mat = h3d.mat.Material.create(atlas);
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		mat.blendMode = Alpha;
		mat.mainPass.depthWrite = false;
		mat.mainPass.setPassName("alpha");
		mat.mainPass.addShader(new h3d.shader.VertexColor());
		mat.mainPass.addShader(world.sky.fog);
		mat.textureShader.killAlpha = true;
		mat.textureShader.killAlphaThreshold = 0.02;
		return mat;
	}

	/** el planeta da la vuelta: lleva la coordenada a la copia mas cercana a la camara */
	inline function near( v : Float, ref : Float ) : Float {
		var s = world.size;
		return v + s * Math.round((ref - v) / s);
	}

	public function update( g : GameView, dt : Float, tmod : Float ) {
		time += tmod;
		var sel = g.select;
		var laser = g.laserActive;
		var hand = g.synthAimed ? null : g.inv.getCurrentBlock(); // el ordenador del sintetizador se usa como con la mano vacia

		if( sel == null || (hand != null && !laser && false) ) {
			box.visible = false;
			overlay_hide();
			denied.visible = false;
			beamRoot.visible = false;
			return;
		}

		// cubo que se resalta: el bloque (excavando) o la celda donde se pondra el de la mano
		var x = hand == null ? sel.x : sel.tx, y = hand == null ? sel.y : sel.ty, z = hand == null ? sel.z : sel.tz;
		var b = hand == null ? sel.b : hand.getFlip(g.yaw);
		var fx = near(x, g.px), fy = near(y, g.py), fz = z;
		var bx = 0., by = 0., bz = 0., sx = 1., sy = 1., sz = 1.;
		// la misma caja con la que se apunta (plantas y modelos: la de su dibujo)
		var pb = b != null ? GameView.pickBox(b) : null;
		if( pb != null ) {
			bx = pb.x1; by = pb.y1; bz = pb.z1;
			sx = pb.x2 - pb.x1; sy = pb.y2 - pb.y1; sz = pb.z2 - pb.z1;
		}

		box.visible = !laser;
		if( box.visible ) {
			box.setPosition(fx + bx - 0.0015, fy + by - 0.0015, fz + bz - 0.0015);
			box.setScale(1);
			box.scaleX = sx + 0.003;
			box.scaleY = sy + 0.003;
			box.scaleZ = sz + 0.003;
		}

		mining = laser && hand == null;
		// copia temblorosa del bloque
		if( mining && g.canBreak ) {
			if( overlayBlock != sel.b ) {
				overlay_hide(true);
				overlayBlock = sel.b;
				var poly = IconMesh.polygon(sel.b, true);
				if( poly != null ) {
					var m = blendMaterial();
					m.color.a = 0.5;
					overlay = new h3d.scene.Mesh(poly, m, world.root);
				}
			}
			if( overlay != null ) {
				overlay.visible = true;
				var s = 1 + 0.015 + Math.random() * 0.075;
				overlay.setPosition(fx - (s - 1) * 0.5, fy - (s - 1) * 0.5, fz - (s - 1) * 0.5);
				overlay.setScale(s);
			}
			denied.visible = false;
		} else if( mining ) {
			overlay_hide();
			denied.visible = true;
			var s = 1.15;
			denied.setPosition(fx - (s - 1) * 0.5, fy - (s - 1) * 0.5, fz - (s - 1) * 0.5);
			denied.setScale(s);
			var mat = denied.material;
			mat.color.a = 0.1 + 0.7 * Math.random();
		} else if( Settings.placePreview && hand != null && !laser && b != null && g.canPlace(sel, hand) ) {
			// sombra del bloque de la mano en la celda donde se pondra (pedido por los jugadores: sin ella construir es dificil)
			denied.visible = false;
			if( overlayBlock != b ) {
				overlay_hide(true);
				overlayBlock = b;
				var poly = IconMesh.polygon(b, true);
				if( poly != null ) {
					var m = blendMaterial();
					m.color.a = 0.22;
					overlay = new h3d.scene.Mesh(poly, m, world.root);
				}
			}
			if( overlay != null ) {
				overlay.visible = true;
				overlay.setPosition(fx, fy, fz);
				overlay.setScale(1);
			}
		} else {
			overlay_hide();
			denied.visible = false;
		}

		// rayo desde la mano (abajo a la derecha) hasta el punto de impacto
		if( mining ) {
			var id = g.laserCharge == null ? 0 : 1 + Type.enumIndex(g.laserCharge);
			if( id > 3 ) id = 0;
			if( id != beamId ) {
				beamId = id;
				beam.material.texture = beamTex[id];
			}
			var cp = Math.cos(g.pitch);
			var fwd = new h3d.Vector(Math.cos(g.yaw) * cp, Math.sin(g.yaw) * cp, Math.sin(g.pitch));
			var right = new h3d.Vector(-Math.sin(g.yaw), Math.cos(g.yaw), 0);
			var down = new h3d.Vector(0, 0, -1);
			var ex = g.px, ey = g.py, ez = g.pz + g.viewZ + g.shakeZ; // sale de la camara, que tiembla (Render: lazer)
			var start = new h3d.Vector(
				ex + fwd.x * 1.0 + right.x * 0.8 + down.x * 0.8 + right.x * g.bobX / 50,
				ey + fwd.y * 1.0 + right.y * 0.8 + down.y * 0.8 + right.y * g.bobX / 50,
				ez + fwd.z * 1.0 + right.z * 0.8 + down.z * 0.8 - g.bobY / 50
			);
			var end = new h3d.Vector(near(sel.hx, g.px), near(sel.hy, g.py), sel.hz);
			// lo que se ve esta curvado (el planeta es redondo): el rayo termina donde se ve el impacto, no en su altura real
			var edx = end.x - g.px, edy = end.y - g.py;
			end.z -= (edx * edx + edy * edy) * (2.0 / world.size);
			var d = end.sub(start);
			var len = d.length();
			if( len < 0.05 ) {
				beamRoot.visible = false;
			} else {
				var rspeed = 3., tspeed = 1.;
				switch( id ) {
				case 0: tspeed = 0.8; rspeed = 5;
				case 1: tspeed = 3; rspeed = 4;
				case 2: tspeed = 2; rspeed = 5;
				case 3: tspeed = 2; rspeed = 5;
				}
				beamRoot.visible = true;
				beamRoot.setPosition(start.x, start.y, start.z);
				beamRoot.setDirection(d);
				beam.setRotation(rspeed * time / 32, 0, 0);
				beamRoot.scaleX = len;
				beamRoot.scaleY = 0.2;
				beamRoot.scaleZ = 0.2;
				var tscale = len / 2;
				beamUv.uvScale.set(tscale, 1);
				beamUv.uvDelta.set(-tspeed * time / 32 / tscale, 0);
			}
		} else
			beamRoot.visible = false;
	}

	/** Render.render(screenShot) del original: la captura de F2 no lleva la caja de seleccion (ni la sombra del bloque que se va
	    a poner, anadido del port); el rayo y el bloque que tiembla al excavar si salen */
	public function screenShotHidden() : Array<h3d.scene.Object> {
		var l : Array<h3d.scene.Object> = [box];
		if( overlay != null && !mining ) l.push(overlay);
		return l;
	}

	function overlay_hide( drop = false ) {
		if( overlay != null ) {
			overlay.visible = false;
			if( drop ) {
				overlay.primitive.dispose();
				overlay.remove();
				overlay = null;
				overlayBlock = null;
			}
		}
	}

	public function dispose() {
		overlay_hide(true);
		box.primitive.dispose();
		box.remove();
		denied.remove();
		beamRoot.remove();
	}
}
