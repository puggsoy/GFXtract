package;

import haxe.ds.StringMap;
import haxe.io.BytesInput;

typedef VarEntry = {
	var key:String;
	var value:Dynamic;
}

class ScriptProcess
{
	private var script:Array<String>;
	private var currentLine:Int;
	
	private var file:BytesInput;
	
	private var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	
	/**
	 * @param	script The loaded script, as an array of its lines.
	 */
	public function new(script:Array<String>, file:BytesInput)
	{
		this.script = script;
		this.file = file;
	}
	
	/**
	 * Run the script.
	 */
	public function run()
	{
		currentLine = 1;
		
		for (line in script)
		{
			parseLine(line);
			currentLine++;
		}
	}
	
	/**
	 * Read in and execute a line.
	 */
	private function parseLine(line:String)
	{
		var reg = ~/[^\s"']+|"[^"]*"|'[^']*'/;
		
		var parts:Array<String> = new Array<String>();
		
		while(reg.match(line))
		{
			parts.push(reg.matched(0));
			line = reg.replace(line, '');
		}
		
		var command:String = parts.shift();
		var arguments:Array<String> = parts;
		
		var cmdFunction:Array<String> -> Void = Reflect.field(this, command);
		
		if (cmdFunction == null)
		{
			error('No such command: $command');
		}
		
		cmdFunction(arguments);
	}
	
	/**
	 * Parses array of command arguments, converting them to their appropriate type.
	 * @param	args
	 * @return
	 */
	private function parseArgs(args:Array<String>):Array<Dynamic>
	{
		var ret:Array<Dynamic> = new Array<Dynamic>();
		
		for (arg in args)
		{
			if (~/^".+"$/.match(arg))
			{
				ret.push(arg.substring(1, arg.length - 2));
			}
			else
			if (~/^0x/.match(arg) || ~/^[0-9]+$/.match(arg))
			{
				ret.push(Std.parseInt(arg));
			}
			else
			{
				if (!variables.exists(arg)) variables.set(arg, null);
				var entry:VarEntry = { key: arg, value: variables.get(arg) };
				
				ret.push(entry);
			}
		}
		
		return ret;
	}
	
	/*private function checkArgs(args:Array<Dynamic>, types:Array<Dynamic>)
	{
		if (args.length < types.length) error("Not enough arguments!");
		for (i in 0...args.length)
		{
			if (Type.getClass(args[i]) != types[i])
			{
				error("Invalid argument type, " + Type.getClassName(Type.getClass(args[i])) + " given, expected " + types[i]);
			}
			else
			{
				trace("correct");
			}
		}
	}
	*/
	
	private function get(args:Array<String>)
	{
		//var pargs:Array<Dynamic> = parseArgs(args.splice(0, 3));
		
		var name:String = args[0].toLowerCase();
		var type:String = args[1].toLowerCase();
		var fileNum:Int = (args.length > 2) ? Std.parseInt(args[2]) : 0;
		
		var val:Dynamic = null;
		
		switch(type)
		{
			case "byte":
				val = file.readByte();
			case "short":
				val = file.readUInt16();
			case "long":
				val = file.readInt32();
			case "string":
				val = file.readUntil(0);
		}
		
		variables.set(name, val);
	}
	
	private function print(args:Array<String>)
	{
		var msg:String = args[0];
		
		if (~/^".+"$/.match(msg))
		{
			msg = msg.substring(1, msg.length - 1);
		}
		
		var reg:EReg = ~/%(.+?)%/g;
		
		while (reg.match(msg))
		{
			var posLen = reg.matchedPos();
			var varName:String = msg.substr(posLen.pos + 1, posLen.len - 2).toLowerCase();
			msg = reg.replace(msg, '${variables.get(varName)}');
		}
		
		Sys.println('--Script message: ');
		Sys.println('  $msg');
	}
	
	private function exit(args:Array<String>)
	{
		Sys.exit(0);
	}
	
	private function error(msg:String, terminate:Bool = true)
	{
		Sys.println('--Error on line $currentLine:');
		Sys.println('  $msg');
		
		if (terminate) Sys.exit(10);
	}
}