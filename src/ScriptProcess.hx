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
	
	/**
	 * Holds all open files. 0 is the file originally specified by the user.
	 */
	private var files:Array<BytesInput>;
	
	/**
	 * Holds all script variables
	 */
	private var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	
	private static var types:Array<String> = ['byte',
											  'short',
											  'long',
											  'string'];
	
	/**
	 * @param	script The loaded script, as an array of its lines
	 * @param   file The loaded file
	 */
	public function new(script:Array<String>, file:BytesInput)
	{
		this.script = script;
		
		files = new Array<BytesInput>();
		files.push(file);
	}
	
	/**
	 * Run the script.
	 */
	public function run()
	{
		currentLine = 1;
		
		for (line in script)
		{
			try
			{
				parseLine(line);
				currentLine++;
			}
			catch (e:Dynamic)
			{
				error(e);
			}
		}
	}
	
	/**
	 * Read in and execute a line.
	 */
	private function parseLine(line:String)
	{
		var reg:EReg = ~/\s(?![\w!.]+")/g;
		
		var args:Array<String> = parseArgs(line);
		
		//trace(args);
		//return;
		
		var command:String = args.shift();
		var arguments:Array<String> = args;
		
		var cmdFunction:Array<String> -> Void = Reflect.field(this, command);
		
		if (cmdFunction == null)
		{
			error('No such command: $command');
		}
		
		cmdFunction(arguments);
	}
	
	/**
	 * Parses line into separate arguments
	 */
	private function parseArgs(argString:String):Array<String>
	{
		var inArgs:Array<String> = argString.split(' ');
		var outArgs:Array<String> = new Array<String>();
		
		var str:String = null;
		
		for (s in inArgs)
		{
			if (str == null)
			{
				if (s.indexOf('"') == 0)
				{
					str = s;
					
					if (s.lastIndexOf('"') == s.length - 1)
					{
						outArgs.push(str.substring(1, str.length - 1));
						str = null;
					}
				}
				else
				{
					outArgs.push(s);
				}
			}
			else
			{
				str += ' ' + s;
				
				if (s.lastIndexOf('"') == s.length - 1)
				{
					outArgs.push(str.substring(1, str.length - 1));
					str = null;
				}
			}
		}
		
		return outArgs;
	}
	
	private function parseValue(str:String, ?type:String):Dynamic
	{
		var val:Dynamic = null;
		
		if (variables.exists(name2))
		{
			val = variables.get(name2);
		}
		else
		if (type != null) //If we're given a type, assume the value is of that type
		{
			switch(types.indexOf(type))
			{
				case 0:
					val = Math.min(Std.parseInt(str), 0xFF);
				case 1:
					val = Math.min(Std.parseInt(str), 0xFFFF);
				case 2:
					val = Math.min(Std.parseInt(str), 0xFFFFFFFF);
				case 3:
					val = str;
				default:
					error('No such type: $type');
			}
		}
		else //If not, try to infer it
		{
			if (StringTools.startsWith(str, '0x') || ~/[0-9]/.match(str))
			{
				val = Std.parseInt(str);
			}
			else
			{
				val = str;
			}
		}
		
		return val;
	}
	
	/**
	 * Reads file data.
	 * 
	 * Script format: Get VAR TYPE [FILENUM]
	 * filenum is 0 by default
	 */
	private function get(args:Array<String>)
	{
		var name:String = args[0].toLowerCase();
		var type:String = args[1].toLowerCase();
		var fileNum:Int = (args.length > 2) ? Std.parseInt(args[2]) : 0;
		
		var val:Dynamic = null;
		
		switch(types.indexOf(type))
		{
			case 0:
				val = files[fileNum].readByte();
			case 1:
				val = files[fileNum].readUInt16();
			case 2:
				val = files[fileNum].readInt32();
			case 3:
				val = files[fileNum].readUntil(0);
			default:
				error('No such type: $type');
		}
		
		variables.set(name, val);
	}
	
	/**
	 * Sets a variable.
	 * 
	 * Script format: Set VAR [TYPE] VAR
	 */
	private function set(args:Array<String>)
	{
		var name1:String = args[0].toLowerCase();
		var name2:String = args[1].toLowerCase();
		
		var type:String = null;
		var val:Dynamic = null;
		
		if (types.indexOf(name2) != 1)
		{
			type = name2;
			name2 = args[2].toLowerCase();
		}
		
		if (type != null && types.indexOf(type) < 0)
		{
			error('No such type: $type');
		}
		
		if (variables.exists(name2))
		{
			val = variables.get(name2);
		}
		else
		{
			parseValue;
		}
		
		variables.set(name1, val);
	}
	
	/**
	 * Print out a message. Surround variables with percentage signs (%) to print their values.
	 * 
	 * Script format: Print MESSAGE
	 */
	private function print(args:Array<String>)
	{
		var msg:String = args[0];
		
		var reg:EReg = ~/%(.+?)%/;
		
		while (reg.match(msg))
		{
			var posLen = reg.matchedPos();
			var varName:String = msg.substr(posLen.pos + 1, posLen.len - 2).toLowerCase();
			msg = reg.replace(msg, '${variables.get(varName)}');
		}
		
		Sys.println('--Script message: ');
		Sys.println('  $msg');
	}
	
	/**
	 * Cleanly exit the program.
	 * 
	 * Script format: Exit
	 */
	private function exit(args:Array<String>)
	{
		Sys.exit(0);
	}
	
	/**
	 * Prints errors and terminates script.
	 */
	private function error(msg:String, terminate:Bool = true)
	{
		Sys.println('--Error on line $currentLine:');
		Sys.println('  $msg');
		
		if (terminate) Sys.exit(10);
	}
}