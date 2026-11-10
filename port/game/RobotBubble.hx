import Ui;

/**
 * Globo de dialogo del robot comerciante (anadido del port): al elegir Charlar se cierra el panel y el robot habla en un globo a
 * su lado, letra a letra, con un sonido de estatica de radio (sfx robotStatic) mientras escribe y moviendo la cabeza
 * (Robot.talk). Al acabar, el globo se queda un rato y se va. Sigue al robot en pantalla; si queda detras de la camara, no se ve.
 */
class RobotBubble extends h2d.Object {

	/** letras por segundo */
	static inline var CPS = 34;
	static inline var BW = 400;
	static inline var PAD = 16;

	var bg : h2d.Graphics;
	var txt : h2d.Text;
	var full = "";
	var shown = 0.;
	var hold = 0.;
	var bh = 0.;
	var chan : hxd.snd.Channel;
	var robot : Robot;

	public function new( parent : h2d.Object ) {
		super(parent);
		bg = new h2d.Graphics(this);
		txt = Theme.text(this, "", 2.0, 0x1A2030, PAD, PAD - 4);
		txt.maxWidth = (BW - PAD * 2) / txt.scaleX;
		visible = false;
	}

	public function talking() return full != "";

	public function say( r : Robot, s : String ) {
		stopSound();
		robot = r;
		full = s;
		shown = 0;
		hold = 2.5 + s.length * 0.03;
		// alto fijo con todo el texto, para que el globo no crezca mientras escribe
		txt.text = s;
		bh = txt.textHeight * txt.scaleY + PAD * 2 - 4;
		txt.text = "";
		chan = Snd.play("robotStatic", 0.9, true);
	}

	public function stop() {
		visible = false;
		full = "";
		robot = null;
		stopSound();
	}

	function stopSound() {
		if( chan != null ) {
			chan.stop();
			chan = null;
		}
	}

	public function update( dt : Float, g : GameView, cam : h3d.Camera ) {
		if( full == "" ) return;
		if( g == null || robot == null ) {
			stop();
			return;
		}
		if( shown < full.length ) {
			shown += dt * CPS;
			robot.talk = 0.2;
			if( shown >= full.length ) stopSound();
		} else {
			hold -= dt;
			if( hold <= 0 ) {
				stop();
				return;
			}
		}
		txt.text = full.substr(0, Std.int(Math.min(shown, full.length)));
		// en pantalla: a la derecha de la cabeza, con el pico hacia ella
		var a = Theme.visibleArea();
		var h = robot.headPos();
		var dx = g.wrapDist(h.x - cam.pos.x), dy = g.wrapDist(h.y - cam.pos.y);
		var fx = cam.target.x - cam.pos.x, fy = cam.target.y - cam.pos.y, fz = cam.target.z - cam.pos.z;
		if( dx * fx + dy * fy + (h.z - cam.pos.z) * fz <= 0 ) {
			visible = false;
			return;
		}
		var p = cam.project(cam.pos.x + dx, cam.pos.y + dy, h.z, a.w, a.h, false);
		var hx : Float = a.x + p.x, hy : Float = a.y + p.y;
		var bx : Float = hx + 60, by : Float = hy - bh - 40;
		if( bx + BW > a.x + a.w - 10 ) bx = hx - 60 - BW;
		bx = Math.max(a.x + 10, Math.min(a.x + a.w - BW - 10, bx));
		by = Math.max(a.y + 10, Math.min(a.y + a.h - bh - 10, by));
		x = bx;
		y = by;
		visible = true;
		bg.clear();
		// pico: de la parte de abajo del globo, del lado del robot, hacia la cabeza
		var tx = hx - bx, ty = hy - by;
		var baseX = Math.max(30, Math.min(BW - 60, tx < BW * 0.5 ? 40 : BW - 70));
		bg.beginFill(0x1A2030);
		bg.moveTo(baseX - 4, bh - 2);
		bg.lineTo(baseX + 34, bh - 2);
		bg.lineTo(tx, ty - 20);
		bg.endFill();
		bg.beginFill(0x1A2030);
		bg.drawRoundedRect(-3, -3, BW + 6, bh + 6, 12);
		bg.endFill();
		bg.beginFill(0xF4F6FB);
		bg.drawRoundedRect(0, 0, BW, bh, 10);
		bg.endFill();
		bg.beginFill(0xF4F6FB);
		bg.moveTo(baseX, bh - 3);
		bg.lineTo(baseX + 28, bh - 3);
		bg.lineTo(tx - (tx - baseX - 14) * 0.08, ty - 26);
		bg.endFill();
	}
}
