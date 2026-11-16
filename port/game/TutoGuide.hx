import Tutorial.TutoTarget;
import Ui;

/**
 * Lo que se ve del tutorial (anadido del port): el objetivo en un recuadro arriba, un aura verde que late en los bloques que
 * hay que usar y una flecha verde que senala el primero (encima de el si se ve; si no, en el borde de la pantalla hacia el).
 * El verde es el de las flechas del GPS del mapa (Explorer.gpsArrow).
 */
class TutoGuide {

	/** tambien el del boton que toca en los menus del ordenador de a bordo (GalaxyApp.markTutoButton) */
	public static inline var GREEN = 0x80FF00;
	static inline var PANEL_W = 700;

	var root : h2d.Object;
	var panel : h2d.Graphics;
	var title : h2d.Text;
	var text : h2d.Text;
	var arrow : h2d.Graphics;
	var dist : h2d.Text;
	var shown : String;
	/** borde de abajo del recuadro (en la zona visible): la flecha del borde de la pantalla queda por debajo */
	var panelBottom = 0.;
	var time = 0.;
	var auras : Array<h3d.scene.Mesh> = [];
	var auraWorld : World;
	var fog : Sky.FogShader;

	public function new( parent : h2d.Object ) {
		root = new h2d.Object(parent);
		panel = new h2d.Graphics(root);
		title = Theme.text(root, TutoText.get("title"), 1.2, GREEN);
		text = Theme.text(root, "", 1.6, Theme.TEXT);
		text.maxWidth = (PANEL_W - 32) / text.scaleX;
		text.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 0.9 };
		arrow = new h2d.Graphics(parent);
		arrow.beginFill(GREEN, 0.9);
		arrow.moveTo(14, 0);
		arrow.lineTo(-10, -12);
		arrow.lineTo(-4, 0);
		arrow.lineTo(-10, 12);
		arrow.lineTo(14, 0);
		arrow.endFill();
		arrow.filter = new h2d.filter.Glow(GREEN, 0.6, 6, 1, 1, true);
		dist = Theme.text(parent, "", 1.4, GREEN);
		dist.dropShadow = { dx : 1, dy : 1, color : 0, alpha : 0.9 };
		root.visible = arrow.visible = dist.visible = false;
		fog = new Sky.FogShader();
		fog.fogK = 0;
	}

	/**
	 * msg: texto del objetivo (null = nada); g: la partida (null en el espacio, en pausa o en los menus);
	 * top: por debajo de esta altura (la barra del inventario y la ayuda de las teclas, arriba, ocupan todo el ancho)
	 */
	public function update( dt : Float, msg : String, g : GameView, targets : Array<TutoTarget>, cam : h3d.Camera, top : Float ) {
		time += dt;
		root.visible = msg != null;
		panelBottom = 0;
		if( msg != null ) layoutPanel(msg, top);
		if( g == null ) targets = [];
		updateAuras(g, targets);
		updateArrow(g, targets.length > 0 ? targets[0] : null, cam);
	}

	function layoutPanel( msg : String, top : Float ) {
		var a = Theme.visibleArea();
		root.x = Std.int(a.x + (a.w - PANEL_W) * 0.5);
		root.y = Std.int(Math.max(a.y + 10, top));
		if( msg != shown ) {
			shown = msg;
			title.text = TutoText.get("title");
			title.setPosition(14, 8);
			text.text = msg;
			text.setPosition(14, 28);
			panel.clear();
			Theme.rect(panel, 0, 0, PANEL_W, panelH(), Theme.PANEL, 0.75);
			Theme.rect(panel, 0, 0, 3, panelH(), GREEN, 0.9);
		}
		panelBottom = root.y - a.y + panelH();
	}

	inline function panelH() return 28 + text.textHeight * text.scaleY + 10;

	// ---------------------------------------------------------------- aura

	function updateAuras( g : GameView, targets : Array<TutoTarget> ) {
		if( g == null || g.world != auraWorld ) {
			for( m in auras ) m.remove();
			auras = [];
			auraWorld = g == null ? null : g.world;
		}
		if( g == null ) return;
		while( auras.length < targets.length ) auras.push(makeAura(g));
		while( auras.length > targets.length ) auras.pop().remove();
		fog.curve = g.world.sky.fog.curve;
		var pulse = 0.12 + 0.07 * Math.sin(time * 5);
		for( i in 0...targets.length ) {
			var t = targets[i], m = auras[i];
			// en la copia del planeta mas cercana al jugador, como el rayo de la nave
			m.setPosition(g.px + g.wrapDist(t.x + 0.5 - g.px), g.py + g.wrapDist(t.y + 0.5 - g.py), t.z + 0.5);
			m.material.color.set(0.15, 1, 0.05, pulse);
		}
	}

	function makeAura( g : GameView ) : h3d.scene.Mesh {
		var c = new h3d.prim.Cube(1.06, 1.06, 1.06, true);
		c.addNormals();
		var mat = h3d.mat.Material.create();
		mat.shadows = false;
		mat.mainPass.enableLights = false;
		mat.mainPass.culling = None;
		mat.blendMode = Add;
		mat.mainPass.depthWrite = false;
		mat.mainPass.setPassName("alpha");
		mat.mainPass.addShader(fog);
		return new h3d.scene.Mesh(c, mat, g.world.root.getScene());
	}

	// ---------------------------------------------------------------- flecha

	function updateArrow( g : GameView, t : TutoTarget, cam : h3d.Camera ) {
		arrow.visible = dist.visible = g != null && t != null;
		if( !arrow.visible ) return;
		var a = Theme.visibleArea();
		var dx = g.wrapDist(t.x + 0.5 - cam.pos.x), dy = g.wrapDist(t.y + 0.5 - cam.pos.y);
		// la curva del planeta (Sky.FogShader): lo lejano se ve mas bajo
		var z = t.z + 1.0 - (dx * dx + dy * dy) * g.world.sky.fog.curve;
		var p = cam.project(cam.pos.x + dx, cam.pos.y + dy, z, a.w, a.h, false);
		var fx = cam.target.x - cam.pos.x, fy = cam.target.y - cam.pos.y, fz = cam.target.z - cam.pos.z;
		var front = dx * fx + dy * fy + (z - cam.pos.z) * fz > 0;
		var cx = a.w * 0.5, cy = a.h * 0.5;
		var m = 70.;
		var bob = Math.sin(time * 6) * 6;
		var d = Math.sqrt(dx * dx + dy * dy + (t.z - g.pz) * (t.z - g.pz));
		dist.text = d >= 4 ? Std.int(d) + " m" : "";
		if( front && p.x > m && p.x < a.w - m && p.y > m && p.y < a.h - m ) {
			// se ve: encima del bloque, apuntando hacia abajo
			arrow.rotation = Math.PI / 2;
			arrow.setPosition(a.x + p.x, a.y + p.y - 30 + bob);
			dist.setPosition(a.x + p.x - dist.textWidth * dist.scaleX * 0.5, a.y + p.y - 70 + bob);
			return;
		}
		// fuera de la pantalla o detras: en el borde, hacia el
		var vx = p.x - cx, vy = p.y - cy;
		if( !front ) {
			vx = -vx;
			vy = -vy;
		}
		if( vx == 0 && vy == 0 ) vy = 1;
		// por debajo del recuadro del objetivo
		var top = Math.max(m, panelBottom + 40);
		var k = Math.min((cx - m) / Math.max(Math.abs(vx), 1e-6), (vy < 0 ? cy - top : cy - m) / Math.max(Math.abs(vy), 1e-6));
		var ex = cx + vx * k, ey = cy + vy * k;
		var ang = Math.atan2(vy, vx);
		arrow.rotation = ang;
		arrow.setPosition(a.x + ex + Math.cos(ang) * bob, a.y + ey + Math.sin(ang) * bob);
		dist.setPosition(a.x + ex - Math.cos(ang) * 40 - dist.textWidth * dist.scaleX * 0.5, a.y + ey - Math.sin(ang) * 40 - 10);
	}
}
