import Common;
import Msg;

/**
 * La partida multijugador dentro de GameView (anadido del port): manda donde esta el jugador y su laser 20 veces por segundo,
 * anuncia al servidor lo que rompe y pone (el jugador lo ve al momento; si el servidor dice que no, la celda vuelve a lo que
 * hay de verdad), aplica los cambios que manda el servidor (los de los demas y los del proceso del mundo, que solo corre alli)
 * y dibuja a los demas (RemotePlayers).
 */
class NetGame {

	var mp : MultiSession;
	var g : GameView;
	public var remotes(default, null) : RemotePlayers;
	/** aplicando un cambio del servidor: no se vuelve a mandar */
	public var applying(default, null) = false;
	var seq = 0;
	/** celda de cada peticion sin respuesta (para deshacerla si el servidor dice que no) */
	var pending = new Map<Int, Int>();
	var stateAcc = 0.;
	static inline var STATE_RATE = 0.05;

	public function new( mp : MultiSession, g : GameView, root3d : h3d.scene.Object, s2d : h2d.Object ) {
		this.mp = mp;
		this.g = g;
		remotes = new RemotePlayers(g, root3d, s2d);
		remotes.names = function( id ) {
			var p = mp.players.get(id);
			return p == null ? null : p.name;
		};
	}

	public function dispose() {
		remotes.dispose();
	}

	public function update( dt : Float ) {
		stateAcc += dt;
		if( stateAcc >= STATE_RATE ) {
			stateAcc = 0;
			sendState();
		}
		remotes.update(dt);
	}

	function sendState() {
		var sel = g.select;
		var laser = g.laserActive && sel != null;
		var flags = (laser ? (FLaser : Int) : 0) | (g.pz >= WorldData.SHIP_Z - 1 ? (FInShip : Int) : 0);
		mp.client.send(CState({ id : 0, x : g.px, y : g.py, z : g.pz, yaw : g.yaw, pitch : g.pitch, flags : flags,
			charge : g.laserCharge == null ? -1 : Type.enumIndex(g.laserCharge),
			hx : laser ? sel.hx : 0, hy : laser ? sel.hy : 0, hz : laser ? sel.hz : 0 }));
	}

	/** el jugador ha roto un bloque del planeta */
	public function sentBreak( x : Int, y : Int, z : Int, b : Block ) {
		pending.set(++seq, cellKey(x, y, z));
		mp.client.send(CBreak(seq, x, y, z, b.index));
	}

	/** el jugador ha puesto un bloque del planeta (level: nivel del agua puesta) */
	public function sentPlace( x : Int, y : Int, z : Int, b : Block, level : Int, slot : Int ) {
		pending.set(++seq, cellKey(x, y, z));
		mp.client.send(CPlace(seq, x, y, z, b.index, level, slot));
	}

	public function onMessage( m : ServerMsg ) {
		switch( m ) {
		case SChanges(list):
			for( c in list ) apply(c.key, c.v, true);
		case SSetResult(s, ok, current):
			var key = pending.get(s);
			pending.remove(s);
			if( !ok && key != null ) apply(key, current, false);
			// el servidor manda tambien el cambio real (SChanges) si lo habia; aqui solo hace falta deshacer lo que no se acepto
		case SStates(list):
			remotes.setStates(list);
		case SGone(id):
			remotes.remove(id);
		case SReduceWater:
			applying = true;
			g.world.reduceWater();
			applying = false;
		default:
		}
	}

	/** pone la celda key como dice el servidor (valor de editMap: bloque global | nivel << 16) si no lo esta ya */
	function apply( key : Int, v : Int, effects : Bool ) {
		var w = g.world;
		var z = key & (WorldData.HEIGHT - 1), col = key >> WorldData.ZBITS;
		var x = col % w.size, y = Std.int(col / w.size);
		var gi = v & 0xFFFF, lvl = v >> 16;
		var b = gi == 0 || gi >= Block.all.length ? null : Block.all[gi];
		var old = w.block(x, y, z);
		if( old == b && w.waterLevelAt(x, y, z) == lvl ) return;
		applying = true;
		if( b != null && b.type == BTWater ) w.setWater(x, y, z, b, lvl) else w.setBlock(x, y, z, b);
		applying = false;
		// lo que rompen los demas se ve romperse
		if( effects && b == null && old != null && old.type != BTWater ) @:privateAccess g.parts.doBreak(x, y, z, old);
	}

	inline function cellKey( x : Int, y : Int, z : Int ) return ((x + y * g.world.size) << WorldData.ZBITS) | z;

	public function devInfo() return remotes.devInfo() + " pendientes " + Lambda.count(pending);
}
