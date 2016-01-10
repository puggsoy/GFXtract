package;

import sys.io.FileSeek;

class ScriptProcess
{
	private var script:Array<String>;
	private var currentLine:Int;
	
	/**
	 * Holds all open files. 0 is the file originally specified by the user.
	 */
	private var files:Array<InputFile>;
	
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
	private var palOff:Int = -1;
	private var palFile:Int = -1;
	private var palLength:Int = 0;
	
	/**
	 * @param	script The loaded script, as an array of its lines
	 * @param   file The loaded file
	 */
	public function new(script:Array<String>, file:String, out:String)
	{
		this.script = script;
		
		files = new Array<InputFile>();
		files.push(new InputFile(file));
		
		outDir = out;
	}
	
	/**
	 * Run the script.
	 */
	public function run()
	{
		currentLine = 0;
		
		while (currentLine < script.length)
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
	
	/*private function parseValue(str:String, ?type:String):Dynamic
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
	}*/
	
	private function isInt(val:String):Bool
	{
		return ~/^[0-9]+$/.match(val);
	}
	
	/**
	 * Reads file data.
	 * 
	 * Script format: Get VAR TYPE [FILENUM]
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
				val = files[fileNum].stream.readByte();
			case 1:
				val = files[fileNum].stream.readUInt16();
			case 2:
				val = files[fileNum].stream.readInt32();
			case 3:
				val = files[fileNum].stream.readUntil(0);
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
	 * Script format: Set VAR1 VAR2
	 */
	private function set(args:Array<String>)
	{
		var name1:String = args[0].toLowerCase();
		var name2:String = args[1];
		
		var val:Dynamic = variables[name2.toLowerCase()];
		
		if (val == null)
		{
			val = name2;
		}
		
		variables[name1] = val;
	}
	
	/**
	 * Print out a message. Surround variables with percentage signs (%) to print their values.
	 * 
	 * Script format: Print MSG
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
	 */
	private function getdstring(args:Array<String>)
	{
		var name:String = args[0].toLowerCase();
		var length:Int = Std.parseInt(args[1]);
		var fileNum:Int = (args.length > 2) ? Std.parseInt(args[2]) : 0;
		
		var val:String = files[fileNum].stream.readString(length);
		variables[name] = val;
	}
	
	/**
	 * Modifies strings, similar to Math but for strings.
	 * 
	 * Script format: String VAR1 OP VAR2
	 * The result is stored in the VAR1
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
	 * Script format: Math VAR1 OP VAR2
	 * The result is stored in the VAR1
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
	 * Checks that the string VAR is at the current position of the file. Good for checking magic IDs.
	 * 
	 * Script format: IDString VAR [FILENUM]
	 */
	private function idstring(args:Array<String>)
	{
		var name:String = args[0];
		var fileNum:Int = (args.length > 1) ? Std.parseInt(args[1]) : 0;
		
		var val:String = variables[name.toLowerCase()];
		
		if (val == null) val = name;
		
		var s:String = files[fileNum].stream.readString(val.length);
		
		if (s != val)
		{
			error('IDString expecting $val, got $s');
		}
	}
	
	/**
	 * Goes to the position VAR in the file.
	 * 
	 * Script format: GoTo VAR [TYPE] [FILENUM]
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
		
		files[fileNum].stream.seek(val, seekType);
	}
	
	/**
	 * Reads image data and stores it in a variable. Should be used after SetFormat.
	 * 
	 * Script format: Read VAR WIDTH HEIGHT [FILENUM] [LENGTH]
	 * The image object is stored in VAR.
	 */
	private function read(args:Array<String>)
	{
		var name:String = args[0].toLowerCase();
		var widthStr:String = args[1].toLowerCase();
		var heightStr:String = args[2].toLowerCase();
		var fileNum:Int = (args.length > 3) ? Std.parseInt(args[3]) : 0;
		var lengthStr:String = (args.length > 4) ? args[4].toLowerCase() : '0';
		
		var width:Int = variables[widthStr];
		var height:Int = variables[heightStr];
		var length:Int = variables[lengthStr];
		
		if (width == null) width = Std.parseInt(widthStr);
		if (height == null) height = Std.parseInt(heightStr);
		if (length == null) length = Std.parseInt(lengthStr);
		
		var img:Image = new Image();
		
		if (indexed) img.readIndexed(width, height, bpp, format, bpc, palOff, files[fileNum].stream, files[palFile].stream, length, palLength);
		else img.read(width, height, bpp, format, files[fileNum].stream, length);
		
		variables[name] = img;
	}
	
	/**
	 * Defines the format of images and pixels. Should be used before Read.
	 * 
	 * Script format: SetFormat BPP FORMAT [INDEXED] [BPC] [PALOFF] [FILENUM]
	 */
	private function setformat(args:Array<String>)
	{
		var bppStr:String = args[0].toLowerCase();
		var formatStr:String = args[1];
		
		bpp = variables[bppStr];
		format = variables[formatStr];
		
		if (bpp == null) bpp = Std.parseInt(bppStr);
		if (format == null) format = formatStr;
		
		if (args.length > 2)
		{
			var indexedStr:String = args[2].toLowerCase();
			var parsed:Int = variables[indexedStr];
			if (parsed == null) parsed = Std.parseInt(indexedStr);
			indexed = (parsed == 0) ? false : true;
			
			if (indexed)
			{
				var bpcStr:String = args[3].toLowerCase();
				var palOffStr:String = args[4].toLowerCase();
				palFile = (args.length > 5) ? Std.parseInt(args[5]) : 0;
				var palLengthStr:String = (args.length > 6) ? args[6].toLowerCase() : '0';
				
				bpc = variables[bpcStr];
				palOff = variables[palOffStr];
				palLength = variables[palLengthStr];
				
				if (bpc == null) bpc = Std.parseInt(bpcStr);
				if (palOff == null) palOff = Std.parseInt(palOffStr);
				if (palLength == null) palLength = Std.parseInt(palLengthStr);
			}
		}
	}
	
	/**
	 * Stores the current file position in a variable.
	 * 
	 * Script format: SavePos VAR [FILENUM]
	 */
	private function savepos(args:Array<String>)
	{
		var name:String = args[0].toLowerCase();
		var fileNum:Int = (args.length > 1) ? Std.parseInt(args[1]) : 0;
		
		variables[name] = files[fileNum].stream.tell();
	}
	
	/**
	 * Saves an image to a PNG.
	 * 
	 * Script format: SavePNG IMG [NAME]
	 */
	private function savepng(args:Array<String>)
	{
		var img:Image = variables[args[0].toLowerCase()];
		var name:String = (args.length > 1) ? args[1] : '';
		
		var fName:String = variables[name.toLowerCase()];
		
		if (fName == null) fName = name;
		if (fName == '') fName = files[0].baseName;
		
		img.savePNG(fName, outDir);
	}
	
	/**
	 * Flips an image either horizontally or vertically.
	 * 
	 * Script format: Flip IMG [VERT]
	 * VERT is false by default.
	 */
	private function flip(args:Array<String>)
	{
		var img:Image = variables[args[0].toLowerCase()];
		var vert:Bool = (args.length > 1 && Std.parseInt(args[1]) == 1);
		
		img.flip(vert);
	}
	
	/**
	 * Cleanly exit the program.
	 * 
	 * Script format: Exit
	 */
	private function exit(args:Array<String>)
	{
		currentLine = script.length;
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