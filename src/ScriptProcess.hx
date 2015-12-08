package;

import haxe.ds.StringMap;
import haxe.io.BytesInput;
import sys.io.FileInput;

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
	private var files:Array<FileInput>;
	
	/**
	 * Stores all script variables
	 */
	private var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	
	private static var types:Array<String> = ['byte',
											  'short',
											  'long',
											  'string',
											  'image'];
	
	/**
	 * @param	script The loaded script, as an array of its lines
	 * @param   file The loaded file
	 */
	public function new(script:Array<String>, file:FileInput)
	{
		this.script = script;
		
		files = new Array<FileInput>();
		files.push(file);
	}
	
	/**
	 * Run the script.
	 */
	public function run()
	{
		currentLine = 0;
		
		while (currentLine != script.length)
		{
			try
			{
				parseLine(script[currentLine]);
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
		if (line.length == 0) return;
		
		line = line.toLowerCase();
		var command:String = line.split(' ')[0];
		
		var args:Array<String> = parseArgs(line);
		args.shift();
		var arguments:Array<String> = args;
		
		if (command == 'if')
		{
			currentLine++;
			skipUntil(['endif']);
			return;
		}
		
		if (command == 'for')
		{
			currentLine++;
			skipUntil(['next']);
			return;
		}
		
		var cmdFunction:Array<String> -> Void = Reflect.field(this, command);
		
		if (cmdFunction == null)
		{
			error('No such command: $command');
		}
		
		cmdFunction(arguments);
	}
	
	private function skipUntil(end:Array<String>)
	{
		while (end.indexOf(script[currentLine].split(' ')[0]) == -1)
		{
			currentLine++;
		}
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
		
		if (type != null) //If we're given a type, assume the value is of that type
		{
			switch(types.indexOf(type))
			{
				case 0, 1, 2:
					val = Std.parseInt(str);
				case 3:
					val = str;
				case 4:
					error("Can't set an image like this");
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
	
	private function isInt(val:String):Bool
	{
		return ~/^[0-9]+$/.match(val);
	}
	
	/**
	 * Reads file data.
	 * 
	 * Script format: Get VAR TYPE [FILENUM]
	 * FILENUM is 0 by default
	 */
	private function get(args:Array<String>)
	{
		var name:String = args[0];
		var type:String = args[1];
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
			case 4:
				error("Can't get an image like this");
			default:
				error('No such type: $type');
		}
		
		variables[name] = val;
	}
	
	/**
	 * Sets a variable.
	 * 
	 * Script format: Set VAR [TYPE] VAR
	 */
	private function set(args:Array<String>)
	{
		var name1:String = args[0];
		var name2:String = args[1];
		
		var type:String = null;
		var val:Dynamic = null;
		
		if (types.indexOf(name2) != -1)
		{
			type = name2;
			name2 = args[2];
		}
		
		if (type != null && types.indexOf(type) == -1)
		{
			error('No such type: $type');
		}
		
		val = variables[name2];
		
		if (val == null)
		{
			val = name2;
		}
		
		variables[name1] = val;
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
			var varName:String = msg.substr(posLen.pos + 1, posLen.len - 2);
			msg = reg.replace(msg, '${variables[varName]}');
		}
		
		Sys.println('==Script message: ');
		Sys.println('  $msg');
	}
	
	/**
	 * Reads a string of specified length.
	 * 
	 * Script format: GetDString VAR LENGTH [FILENUM]
	 * FILENUM is 0 by default
	 */
	private function getdstring(args:Array<String>)
	{
		var name:String = args[0];
		var length:Int = Std.parseInt(args[1]);
		var fileNum:Int = (args.length > 2) ? Std.parseInt(args[2]) : 0;
		
		var val:String = files[fileNum].readString(length);
		variables[name] = val;
	}
	
	/**
	 * Modifies strings.
	 * 
	 * Script format: String VAR OP VAR
	 * The result is stored in the first VAR
	 */
	private function string(args:Array<String>)
	{
		var name1:String = args[0];
		var op:String = args[1];
		var name2:String = args[2];
		
		var val1:String = variables[name1];
		var val2:String = variables[name2];
		
		if (val1 == null) val1 = '';
		if (val2 == null) val2 = name2;
		
		switch(op)
		{
			case '=':
				val1 = val2;
			case '+', '+=':
				val1 = '$val1$val2';
			case '-', '-=':
				if (isInt(val2))
				{
					var x:Int = Std.parseInt(val2);
					
					val1 = (x < 0) ? val1.substring( -x) : val1.substring(0, val1.length - x);
				}
				else
				{
					StringTools.replace(val1, val2, '');
				}
			default:
				error('Invalid operator!');
		}
		
		variables[name1] = val1;
	}
	
	private function math(args:Array<String>)
	{
		var name1:String = args[0];
		var op:String = args[1];
		var name2:String = args[2];
		
		var val1:Int = Std.parseInt(variables[name1]);
		var val2:Int = Std.parseInt(variables[name2]);
		
		if (val1 == null) val1 = 0;
		if (val2 == null) val2 = Std.parseInt(name2);
		
		switch(op)
		{
			case '=':
				val1 = val2;
			case '+', '+=':
				val1 += val2;
			case '-', '-=':
				val1 -= val2;
			case '*', '*=':
				val1 *= val2;
			case '/', '/=':
				val1 = Std.int(val1 / val2);
			case '%', '%=':
				val1 %= val2;
			default:
				error('Invalid operator!');
		}
		
		variables[name1] = val1;
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
		Sys.println('--Error on line ${currentLine + 1}:');
		Sys.println('  $msg');
		
		if (terminate) Sys.exit(10);
	}
}