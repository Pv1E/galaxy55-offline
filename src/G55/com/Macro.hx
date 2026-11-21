import haxe.macro.Context;
import haxe.macro.Expr;

class Macro {

	/**
	 * Cada instruccion del bloque es un paso del generador (addStep); las lineas var se ejecutan ya, al registrar los pasos.
	 * Anadido del port (generador version 1): cada paso lleva un nombre, su instruccion principal (la funcion a la que llama, o
	 * for / while / if) y cuantas habia antes con la misma en el bloque ("addHeight#2"): de el sale su azar (Generator.initStep),
	 * asi que anadir o quitar una instruccion solo cambia el azar de las del mismo nombre que van detras.
	 */
	macro public static function generate( e : Expr ) : Expr {
		var el = switch( e.expr ) {
		case EBlock(el): el;
		default: [e];
		}
		var out = [];
		var seen = new Map<String, Int>();
		for( e in el ) {
			var p = e.pos;
			switch( e.expr ) {
			case EVars(_):
				out.push(e);
			case EReturn(e):
				if( e != null )
					Context.error("No value allowed here", e.pos);
				break;
			default:
				var key = stepKey(e);
				var rank = seen.exists(key) ? seen.get(key) : 0;
				seen.set(key, rank + 1);
				var name = { expr : EConst(CString(key + "#" + rank)), pos : p };
				out.push( { expr : ECall( { expr : EConst(CIdent("addStep")), pos : p }, [ name, { expr : EFunction(null, { ret : null, params : [], expr : e, args : [] } ), pos : p } ]), pos : p } );
			}
		}
		return { expr : EBlock(out), pos : e.pos };
	}

	#if macro
	/** la instruccion principal de un paso: la funcion llamada (tambien en "t += addHeight(...)"), o for / while / if */
	static function stepKey( e : Expr ) : String {
		return switch( e.expr ) {
		case ECall(f, _):
			var s = haxe.macro.ExprTools.toString(f);
			s.substr(s.lastIndexOf(".") + 1);
		case EBinop(_, _, e2): stepKey(e2);
		case EParenthesis(e2), EMeta(_, e2), EUntyped(e2): stepKey(e2);
		case EFor(_, _): "for";
		case EWhile(_, _, _): "while";
		case EIf(_, _, _): "if";
		case EBlock(_): "block";
		default: "stmt";
		}
	}
	#end
	
	macro public static function getModel( file : String ) : Expr {
		var p = Context.currentPos();
		var f = try Context.resolvePath(file) catch( e : Dynamic ) Context.error(Std.string(e), p);
		var i = sys.io.File.read(f);
		i.readByte();
		var count = i.readInt32();
		var buf = [];
		for( x in 0...count*6 )
			buf.push( { expr : EConst(CFloat(Std.string(i.readFloat()))), pos : p } );
		i.close();
		return { expr : EArrayDecl(buf), pos : p };
	}
	
}