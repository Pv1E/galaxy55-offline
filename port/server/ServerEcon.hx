import Common;
import Msg;
import GameServer.Session;

/**
 * La progresion de cada jugador en el servidor (anadido del port para el multijugador): la tienda del robot, los contratos de
 * la ESCorp y el planeta principal. El cliente hace la operacion en su copia de la partida (lo ve al momento) y manda CEcon;
 * aqui se repite con las mismas reglas del core sobre la partida de verdad (Session.record) y se mandan los campos que han
 * cambiado (SPatch) y el inventario (SInventory, con el numero de la peticion). Si no cuadra (sin creditos, sin bloques, otro
 * tablero...) no se hace nada: el cliente recibe lo que hay de verdad y su copia vuelve atras.
 */
class ServerEcon {

	var worlds : ServerWorlds;
	var server : GameServer;

	public function new( worlds : ServerWorlds, server : GameServer ) {
		this.worlds = worlds;
		this.server = server;
	}

	public function handle( s : Session, seq : Int, op : EconOp, a : String, n : Int ) {
		var info = s.record;
		if( info == null || info.inv == null ) return;
		// fuera de su vaisseau (en el planeta de otro, con el anfitrion...) se usa igual: el ordenador de a bordo va con el
		var inv = new Inv(info.inv);
		var ok = switch( op ) {
		case EBuy: buy(s, inv, a, n);
		case ESell: sell(s, inv, a, n);
		case EDeliver: Contracts.deliver(info, inv, n);
		case EGive:
			var act = Contracts.active(info);
			n < act.length && Contracts.give(info, inv, act[n]);
		case EAbandonContract:
			var act = Contracts.active(info);
			n < act.length && Contracts.abandon(info, act[n]);
		case EGiveSpecial: Contracts.giveSpecial(info, inv);
		case EUpgrade:
			// no hay mejoras ESCorp todavia (EscorpUpgrades.ALL esta vacia)
			false;
		case EMainPlanet: info.uni != null && Licenses.setMain(info, n) == null;
		default: false;
		}
		if( ok ) {
			worlds.markRecord(s);
			server.files.log(s.display + " " + opName(op) + " " + a + " " + n);
		}
		s.ack = seq;
		sendFields(s, op);
		worlds.items.sendInv(s);
	}

	function buy( s : Session, inv : Inv, key : String, n : Int ) : Bool {
		var w = Market.ware(key);
		if( w == null || n <= 0 ) return false;
		var info = s.record;
		var m = market(s);
		var r = m.buy(w, Std.int(Math.min(n, ShopRules.room(inv, w))), credits(info));
		if( r.n <= 0 ) return false;
		info.credits = credits(info) - r.cost;
		if( w.charge != null ) inv.addCharge(w.charge, r.n) else inv.addBlocks(w.block, r.n);
		return true;
	}

	function sell( s : Session, inv : Inv, key : String, n : Int ) : Bool {
		var w = Market.ware(key);
		if( w == null || n <= 0 ) return false;
		var info = s.record;
		n = Std.int(Math.min(n, ShopRules.have(inv, w)));
		if( n <= 0 ) return false;
		var r = market(s).sell(w, n);
		if( r.n <= 0 ) return false;
		ShopRules.take(inv, w, r.n);
		info.credits = credits(info) + r.gain;
		return true;
	}

	/** el robot de la partida, con los precios que vuelven a lo normal con el tiempo de juego (GameView.market) */
	function market( s : Session ) : Market {
		var m = new Market(s.record.market);
		s.record.market = m.info;
		m.advance(s.record.playSeconds);
		return m;
	}

	static inline function credits( info : SaveData.SaveInfo ) : Int return info.credits == null ? Market.START_CREDITS : info.credits;

	/** los campos que la operacion puede haber cambiado, tal como estan ahora */
	function sendFields( s : Session, op : EconOp ) {
		var info = s.record;
		s.send(SPatch("credits", haxe.Json.stringify(credits(info))));
		switch( op ) {
		case EBuy, ESell:
			s.send(SPatch("market", haxe.Json.stringify(info.market)));
		case EDeliver, EGive, EAbandonContract:
			s.send(SPatch("contracts", haxe.Json.stringify(info.contracts)));
		case EGiveSpecial:
			s.send(SPatch("special", haxe.Json.stringify(info.special)));
		case EUpgrade:
			s.send(SPatch("upgrades", haxe.Json.stringify(info.upgrades)));
		case EMainPlanet:
			if( info.uni != null ) s.send(SPatch("main", haxe.Json.stringify({ main : info.uni.main, mainTime : info.uni.mainTime, mainChanges : info.uni.mainChanges })));
		default:
		}
	}

	static function opName( op : EconOp ) : String {
		return switch( op ) {
		case EBuy: "compra";
		case ESell: "vende";
		case EDeliver: "entrega el contrato";
		case EGive: "da al contrato en curso";
		case EAbandonContract: "abandona el contrato en curso";
		case EGiveSpecial: "da al contrato especial";
		case EUpgrade: "compra la mejora";
		case EMainPlanet: "cambia de planeta principal a";
		default: "?";
		}
	}
}
