import Msg;

/** Un jugador que esta en el mismo planeta: su cono, su nombre y su laser */
private class Remote {
	public var id : Int;
	public var name : String;
	public var root : h3d.scene.Object;
	public var label : h2d.Text;
	public var beam : { root : h3d.scene.Object, mesh : h3d.scene.Mesh, uv : h3d.shader.UVDelta, tex : Array<h3d.mat.Texture> };
	public var beamId = -1;
	/** lo que se dibuja (suavizado hacia el ultimo estado recibido, como ent/OnlineHero.hx) */
	public var x = 0.;
	public var y = 0.;
	public var z = 0.;
	public var yaw = 0.;
	public var target : NetState;
	public var fresh = true;
	public function new() {}
}

/**
 * Los demas jugadores del planeta (anadido del port, multijugador), como en el juego original (r3d/Render.hx, initHero): un cono
 * de senalizacion con su base, el nombre encima (en grande cerca, "?" lejos, y una flecha en el borde si esta fuera de la
 * pantalla) y su laser en directo con la textura de su carga. Los que estan dentro de su nave no se ven: cada uno ve solo la suya.
 */
class RemotePlayers {

	var g : GameView;
	var s2d : h2d.Object;
	var root : h3d.scene.Object;
	var remotes = new Map<Int, Remote>();
	var cone : h3d.prim.Primitive;
	var base : h3d.prim.Primitive;
	var tex : h3d.mat.Texture;
	var time = 0.;
	/** nombres de los jugadores por id de sesion (MultiSession.players) */
	public var names : Int -> String;

	public function new( g : GameView, parent3d : h3d.scene.Object, s2d : h2d.Object ) {
		this.g = g;
		this.s2d = s2d;
		root = new h3d.scene.Object(parent3d);
		var pcyl = new h3d.prim.Cylinder(16, 0.4, 1.3);
		pcyl.addUVs();
		pcyl.addNormals();
		for( p in @:privateAccess pcyl.pts )
			if( p.z > 0 ) {
				p.x *= 0.002;
				p.y *= 0.002;
			}
		cone = pcyl;
		var b = new h3d.prim.Cube(0.8, 0.8, 0.1);
		b.translate(-0.4, -0.4, 0);
		b.addUVs();
		b.addNormals();
		base = b;
		tex = hxd.res.Any.fromBytes("cone.png", Res.bytes("cone.png")).toTexture();
		tex.wrap = Repeat;
	}

	function make( id : Int ) : Remote {
		var r = new Remote();
		r.id = id;
		r.root = new h3d.scene.Object(root);
		for( prim in [cone, base] ) {
			var mat = h3d.mat.Material.create(tex);
			mat.shadows = false;
			mat.mainPass.enableLights = false;
			mat.mainPass.culling = None;
			new h3d.scene.Mesh(prim, mat, r.root);
		}
		r.label = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
		r.label.textAlign = Center;
		r.label.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 0.8 };
		r.beam = Fx.newBeam(root);
		r.beam.root.visible = false;
		remotes.set(id, r);
		return r;
	}

	/** estados recibidos (SStates): los que no estan en la lista siguen hasta SGone */
	public function setStates( list : Array<NetState> ) {
		for( s in list ) {
			var r = remotes.get(s.id);
			if( r == null ) r = make(s.id);
			r.target = s;
		}
	}

	public function remove( id : Int ) {
		var r = remotes.get(id);
		if( r == null ) return;
		r.root.remove();
		r.label.remove();
		r.beam.root.remove();
		remotes.remove(id);
	}

	public function dispose() {
		for( id in [for( k in remotes.keys() ) k] ) remove(id);
		root.remove();
	}

	/** la coordenada v (que da la vuelta al planeta) en la copia mas cercana a ref */
	inline function near( v : Float, ref : Float ) : Float {
		var s = g.world.size;
		return v + s * Math.round((ref - v) / s);
	}

	public function update( dt : Float ) {
		var tmod = dt * 32;
		time += tmod;
		var k = Math.pow(0.5, tmod);
		var curve = World.curve(g.world.size);
		var cam = @:privateAccess g.s3d.camera;
		var w = s2d.getScene() == null ? 1280. : s2d.getScene().width, h = s2d.getScene() == null ? 720. : s2d.getScene().height;
		for( r in remotes ) {
			var t = r.target;
			if( t == null ) continue;
			var tx = near(t.x, g.px), ty = near(t.y, g.py);
			if( r.fresh ) {
				r.x = tx; r.y = ty; r.z = t.z; r.yaw = t.yaw;
				r.fresh = false;
			} else {
				r.x = near(r.x, tx) * k + tx * (1 - k);
				r.y = near(r.y, ty) * k + ty * (1 - k);
				r.z = r.z * k + t.z * (1 - k);
				r.yaw = t.yaw;
			}
			var hidden = (t.flags & FInShip) != 0 || r.z >= WorldData.SHIP_Z - 1;
			var dx = r.x - g.px, dy = r.y - g.py;
			var drop = (dx * dx + dy * dy) * curve;
			r.root.visible = !hidden;
			r.root.setPosition(r.x, r.y, r.z - drop);
			r.root.setRotation(0, 0, r.yaw);
			// el nombre encima de la cabeza
			var name = names != null ? names(r.id) : null;
			if( name == null ) name = "?";
			var p = cam.project(r.x, r.y, r.z + 1.75 - drop, w, h);
			var dist = Math.sqrt(dx * dx + dy * dy + (r.z - g.pz) * (r.z - g.pz));
			var size = 3 / Math.sqrt(Math.max(0.01, dist));
			var shown = name;
			if( size > 2 ) size = 2;
			if( size < 0.8 ) { size = 0.8; shown = "?"; }
			var behind = p.z < 0 || p.z > 1;
			if( hidden || behind ) r.label.visible = false;
			else {
				var m = 12.;
				if( p.y < m ) { p.y = m; shown = "^"; }
				if( p.y > h - m ) { p.y = h - m; shown = "v"; }
				if( p.x < m ) { p.x = m; shown = "<"; }
				if( p.x > w - m ) { p.x = w - m; shown = ">"; }
				r.label.visible = true;
				r.label.text = shown;
				r.label.setScale(size);
				r.label.setPosition(p.x, p.y - r.label.textHeight * size * 0.5);
			}
			// su laser: de la cabeza (girada con su mirada) al punto que apunta
			if( !hidden && (t.flags & FLaser) != 0 ) {
				var id = t.charge < 0 ? 0 : 1 + t.charge;
				if( id > 3 ) id = 0;
				if( id != r.beamId ) {
					r.beamId = id;
					r.beam.mesh.material.texture = r.beam.tex[id];
				}
				var start = new h3d.Vector(r.x + Math.cos(r.yaw) * 0.3, r.y + Math.sin(r.yaw) * 0.3, r.z + 1.3 - drop);
				var ex = near(t.hx, g.px), ey = near(t.hy, g.py);
				var edx = ex - g.px, edy = ey - g.py;
				var end = new h3d.Vector(ex, ey, t.hz - (edx * edx + edy * edy) * curve);
				Fx.placeBeam(r.beam.root, r.beam.mesh, r.beam.uv, id, start, end, time);
			} else
				r.beam.root.visible = false;
		}
	}

	public function count() return Lambda.count(remotes);

	/** para las pruebas (print remotes) */
	public function devInfo() : String {
		var l = [for( r in remotes ) r.id + "@" + Math.round(r.x * 10) / 10 + "," + Math.round(r.y * 10) / 10 + "," + Math.round(r.z * 10) / 10 + (r.root.visible ? "" : "(oculto)") + (r.beam.root.visible ? " laser" : "")];
		l.sort(Reflect.compare);
		return "remotos " + l.length + ": " + l.join(" ");
	}
}
