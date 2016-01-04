package;

import haxe.ds.StringMap;
import haxe.io.BytesInput;
import haxe.io.Path;
import openfl.geom.Point;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileSeek;

typedef VarEntry = {
	var key:String;
	var value:Dynamic;
}

class ScriptProcess
{
	private var script:Array<String>;
	private var currentLine:Int;
	private var basename:String;
	
	/**
	 * Holds all open files. 0 is the file originally specified by the user.
	 */
	private var files:Array<FileInput>;
	
	/**
	 * Directory of output files
	 */
	private var outDir:String;
	
	/**
	 * Stores all script variables
	 */
	private var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	
	private static var types:Array<String> = ['byte',
											  'short',
											  'long',
											  'string',
											  'image'];
	
	private var bpp:Int = 32;
	private var format:String = 'ARGB';
	private var indexed:Bool = false;
	private var bpc:Int = -1;
	private var palLoc:Int = -1;
	
	/**
	 * @param	script The loaded script, as an array of its lines
	 * @param   file The loaded file
	 */
	public function new(script:Array<String>, file:String, out:String)
	{
		this.script = script;
		
		files = new Array<FileInput>();
		files.push(File.read(file));
		
		basename = Path.withoutExtension(Path.withoutDirectory(file));
		outDir = out;
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
		
		var command:String = line.split(' ')[0].toLowerCase();
		
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
		var name1:String = args[0].toLowerCase();
		var name2:String = args[1];
		
		var type:String = null;
		var val:Dynamic = null;
		
		if (types.indexOf(name2) != -1)
		{
			type = name2.toLowerCase();
			name2 = args[2];
		}
		
		if (type != null && types.indexOf(type) == -1)
		{
			error('No such type: $type');
		}
		
		val = variables[name2.toLowerCase()];
		
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
			msg = reg.replace(msg, '${variables[varName.toLowerCase()]}');
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
		var name:String = args[0].toLowerCase();
		var length:Int = Std.parseInt(args[1]);
		var fileNum:Int = (args.length > 2) ? Std.parseInt(args[2]) : 0;
		
		var val:String = files[fileNum].readString(length);
		variables[name] = val;
	}
	
	/**
	 * Math for strings, modifies them.
	 * 
	 * Script format: String VAR OP VAR
	 * The result is stored in the first VAR
	 */
	private function string(args:Array<String>)
	{
		var name1:String = args[0].toLowerCase();
		var op:String = args[1];
		var name2:String = args[2];
		
		var val1:String = variables[name1];
		var val2:String = variables[name2.toLowerCase()];
		
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
	
	/**
	 * Performs mathematical operations on numbers.
	 * 
	 * Script format: Math VAR OP VAR
	 * The result is stored in the first VAR
	 */
	private function math(args:Array<String>)
	{
		var name1:String = args[0].toLowerCase();
		var op:String = args[1];
		var name2:String = args[2];
		
		var val1:Int = Std.parseInt(variables[name1]);
		var val2:Int = Std.parseInt(variables[name2.toLowerCase()]);
		
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
	 * Checks that the string VAR is at the current point in the archive. Good for checking magic IDs.
	 * 
	 * Script format: IDString VAR [FILENUM]
	 */
	private function idstring(args:Array<String>)
	{
		var name:String = args[0];
		var fileNum:Int = (args.length > 1) ? Std.parseInt(args[1]) : 0;
		
		var val:String = variables[name.toLowerCase()];
		
		if (val == null) val = name;
		
		var s:String = files[fileNum].readString(val.length);
		
		if (s != val)
		{
			error('IDString expecting $val, got $s');
		}
	}
	
	/**
	 * Checks that the string VAR is at the current point in the archive. Good for checking magic IDs.
	 * 
	 * Script format: GoTo OFFSET [TYPE] [FILENUM]
	 * If OFFSET is 'SOF' or 'EOF' it will go to start or end of file, respectively (overrides TYPE).
	 */
	private function goto(args:Array<String>)
	{
		var name:String = args[0].toLowerCase();
		var type:String = (args.length > 1) ? args[1] : 'set';
		var fileNum:Int = (args.length > 2) ? Std.parseInt(args[2]) : 0;
		
		var val:Int = Std.parseInt(variables[name]);
		
		if (name == 'SOF')
		{
			val = 0;
			type = 'set';
		}
		else
		if (name == 'EOF')
		{
			val = 0;
			type = 'end';
		}
		else
		if (val == null) val = Std.parseInt(name);
		
		var seekType:FileSeek = FileSeek.SeekBegin;
		
		switch(type)
		{
			case 'cur':
				seekType = FileSeek.SeekCur;
			case 'end':
				seekType = FileSeek.SeekEnd;
		}
		
		files[fileNum].seek(val, seekType);
	}
	
	/**
	 * Reads image data and stores it in an object.
	 * 
	 * Script format: Read VAR WIDTH HEIGHT BPP FORMAT [FILENUM]
	 * The image object is stored in VAR.
	 */
	private function read(args:Array<String>)
	{
		var name:String = args[0].toLowerCase();
		var widthStr:String = args[1].toLowerCase();
		var heightStr:String = args[2].toLowerCase();
		var fileNum:Int = (args.length > 3) ? Std.parseInt(args[3]) : 0;
		
		var width:Int = variables[widthStr];
		var height:Int = variables[heightStr];
		
		if (width == null) width = Std.parseInt(widthStr);
		if (height == null) height = Std.parseInt(heightStr);
		
		var img:Image = new Image();
		
		if (indexed) img.readIndexed(width, height, bpp, format, bpc, palLoc, files[fileNum]);
		else img.read(width, height, bpp, format, files[fileNum]);
		
		variables[name] = img;
	}
	
	private function setformat(args:Array<String>)
	{
		var bppStr:String = args[0];
		var formatStr:String = args[1];
		
		bpp = variables[bppStr];
		format = variables[formatStr];
		
		if (bpp == null) bpp = Std.parseInt(bppStr);
		if (format == null) format = formatStr;
		
		if (args.length > 2)
		{
			var indexedStr:String = args[2];
			var parsed:Int = variables[indexedStr];
			if (parsed == null) parsed = Std.parseInt(indexedStr);
			indexed = (parsed == 0) ? false : true;
			
			if (indexed)
			{
				var bpcStr:String = args[3];
				var palLocStr:String = args[4];
				
				bpc = variables[bpcStr];
				palLoc = variables[palLocStr];
				
				if (bpc == null) bpc = Std.parseInt(bpcStr);
				if (palLoc == null) palLoc = Std.parseInt(palLocStr);
			}
		}
	}
	
	private function savepos(args:Array<String>)
	{
		var name:String = args[0];
		var fileNum:Int = (args.length > 1) ? Std.parseInt(args[1]) : 0;
		
		variables[name] = files[fileNum].tell();
	}
	
	private function savepng(args:Array<String>)
	{
		var img:Image = variables[args[0].toLowerCase()];
		var name:String = args[1];
		
		var fName:String = variables[name.toLowerCase()];
		
		if (fName == null) fName = name;
		if (fName == '') fName = basename;
		
		img.savePNG(fName, outDir);
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