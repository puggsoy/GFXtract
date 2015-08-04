package;

import haxe.ds.StringMap;

class ScriptProcess
{
	private var script:Array<String>;
	private var currentLine:Int;
	
	private var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	
	public function new(script:Array<String>) 
	{
		this.script = script;
	}
	
	public function run()
	{
		currentLine = 1;
		
		for (line in script)
		{
			parseLine(line);
			currentLine++;
		}
	}
	
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
	
	private function parseArgs(args:Array<String>):Array<Dynamic>
	{
		var ret:Array<Dynamic> = new Array<Dynamic>();
		
		for (i in 0...args.length)
		{
			if (~/^".+"$/.match(args[i]))
			{
				ret.push(args[i].substring(1, args[i].length - 2));
			}
			else
			if (~/^0x/.match(args[i]) || ~/^[0-9]+$/.match(args[i]))
			{
				ret.push(Std.parseInt(args[i]));
			}
			else
			{
				if (variables.exists(args[i])) ret.push(variables.get(args[i]));
			}
		}
		
		return ret;
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
			var varName:String = msg.substr(posLen.pos + 1, posLen.len - 2);
			reg.replace(msg, variables.get(varName));
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
		Sys.println('Error on line $currentLine:');
		Sys.println(msg);
		
		if (terminate) Sys.exit(10);
	}
}