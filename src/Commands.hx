package;
import sys.io.FileSeek;

/**
 * Handles performing commands and working with variables.
 */
class Commands
{
	/**
	 * The open files. 0 is the original input file.
	 */
	static public var files:Array<InputFile>;
	
	/**
	 * The output directory.
	 */
	static public var outDir:String;
	
	static private var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	
	static private var bpp:Int = 32;
	static private var format:String = 'ARGB';
	static private var indexed:Bool = false;
	static private var bpc:Int = -1;
	static private var palOff:Int = -1;
	static private var palFile:Int = -1;
	static private var palLength:Int = 0;
	
	/**
	 * Call a command.
	 */
	static public function call(command:String, stringArgs:Array<String>)
	{
		var args:Array<Dynamic>;
		
		switch(command)
		{
			case 'get':
				args = parseArgs(stringArgs, [VarNameA, TypeA, FileNumA], [null, null, 0]);
				get(args[0], args[1], args[2]);
			case 'set':
				args = parseArgs(stringArgs, [VarNameA, StringA]);
				set(args[0], args[1]);
			case 'print':
				args = parseArgs(stringArgs, [StringA]);
				print(args[0]);
			case 'getdstring':
				args = parseArgs(stringArgs, [VarNameA, IntA, FileNumA], [null, null, 0]);
				getdstring(args[0], args[1], args[2]);
			case 'string':
				args = parseArgs(stringArgs, [VarNameA, StringA, StringA]);
				string(args[0], args[1], args[2]);
			case 'math':
				args = parseArgs(stringArgs, [VarNameA, StringA, IntA]);
				math(args[0], args[1], args[2]);
			case 'idstring':
				args = parseArgs(stringArgs, [StringA, FileNumA], [null, 0]);
				idstring(args[0], args[1]);
			case 'goto':
				args = parseArgs(stringArgs, [StringA, StringA, FileNumA], [null, 'set', 0]);
				goto(args[0], args[1], args[2]);
			case 'read':
				args = parseArgs(stringArgs, [VarNameA, IntA, IntA, FileNumA, IntA], [null, null, null, 0, 0]);
				read(args[0], args[1], args[2], args[3], args[4]);
			case 'setformat':
				args = parseArgs(stringArgs, [IntA, StringA, IntA, IntA, IntA, IntA, IntA], [null, null, 0, 0, 0, 0, 0]);
				setformat(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
			case 'savepos':
				args = parseArgs(stringArgs, [VarNameA, FileNumA], [null, 0]);
				savepos(args[0], args[1]);
			case 'savepng':
				args = parseArgs(stringArgs, [ImageA, StringA], [null, files[0].baseName]);
				savepng(args[0], args[1]);
			case 'flip':
				args = parseArgs(stringArgs, [ImageA, IntA], [null, 0]);
				flip(args[0], args[1]);
			default:
				throw 'No such command: $command';
		}
	}
	
	/**
	 * Parses in string arguments into the types given.
	 */
	static private function parseArgs(args:Array<String>, types:Array<ArgType>, ?defaults:Array<Dynamic>):Array<Dynamic>
	{
		var ret:Array<Dynamic> = new Array<Dynamic>();
		
		for (i in 0...types.length)
		{
			var argNum:Int = i + 1;
			if (i >= args.length)
			{
				if (defaults == null || defaults[i] == null) throw 'Not enough arguments!';
				else ret.push(defaults[i]);
				
				continue;
			}
			
			var dynArg:Dynamic = (types[i] == OccupiedVarA || types[i] == VarNameA) ? args[i] : checkVariable(args[i]);
			
			if (Type.getClass(dynArg) == Image)
			{
				if (types[i] == ImageA)
				{
					ret.push(dynArg);
					continue;
				}
				else throw 'Argument $argNum should not be an image!';
			}
			
			var arg:String = Std.string(dynArg);
			
			ret.push(checkType(arg, types[i], argNum));
		}
		
		return ret;
	}
	
	/**
	 * Checks an argument's type and returns it in that type.
	 */
	static private function checkType(arg:String, type:ArgType, argNum:Int):Dynamic
	{
		switch(type)
			{
				case StringA:
					return arg;
				
				case IntA:
					var num:Int = Std.parseInt(arg);
					if (num == null) throw 'Argument $argNum should be an integer!';
					return num;
				
				case ImageA:
					throw 'Shouldn\'t be able to get here!!!';
				
				case OccupiedVarA:
					var varName:String = arg.toLowerCase();
					if (!isValidVarName(varName) || !variables.exists(varName)) throw 'Argument $argNum is not an existing variable!';
					return varName;
				
				case VarNameA:
					var varName:String = arg.toLowerCase();
					if (!isValidVarName(varName)) throw 'Argument $argNum is not a valid variable name!';
					return varName;
				
				case TypeA:
					var vType:VarType = varTypeFromString(arg);
					if (vType == null) throw 'Argument $argNum is not a valid type!';
					return vType;
				
				case FileNumA:
					var num:Int = Std.parseInt(arg);
					if (num == null || num >= files.length) throw 'Argument $argNum should be a valid file number!';
					return num;
			}
	}
	
	/**
	 * Checks if a string is a variable's name. If it is it returns the variable's value, otherwise it returns the string.
	 */
	static private function checkVariable(name:String):Dynamic
	{
		if(variables.exists(name.toLowerCase())) return variables[name.toLowerCase()];
		else return name;
	}
	
	/**
	 * Checks that a string is a valid variable name.
	 */
	static private function isValidVarName(name:String):Bool
	{
		return ~/^[A-Za-z]\w*$/.match(name);
	}
	
	/**
	 * Gets a VarType constructor from a string (case insensitive).
	 */
	static private function varTypeFromString(str:String):VarType
	{
		var types:Array<String> = Type.getEnumConstructs(VarType);
		var ret:VarType = null;
		
		for (t in types)
		{
			if (t.toLowerCase() == '${str.toLowerCase()}v')
			{
				ret = Type.createEnum(VarType, t);
				break;
			}
		}
		
		return ret;
	}
	
	//#############Script functions#############
	
	/**
	 * Reads file data.
	 * 
	 * Script format: Get VAR TYPE [FILENUM]
	 */
	static private function get(varName:String, type:VarType, fileNum:Int)
	{
		var val:Dynamic = null;
		
		switch(type)
		{
			case ByteV:
				val = files[fileNum].stream.readByte();
			case ShortV:
				val = files[fileNum].stream.readUInt16();
			case LongV:
				val = files[fileNum].stream.readInt32();
			case StringV:
				val = files[fileNum].stream.readUntil(0);
			case ImageV:
				throw 'Can\'t get an image like this';
		}
		
		variables[varName] = val;
	}
	
	/**
	 * Sets a variable.
	 * 
	 * Script format: Set VAR1 VAR2
	 */
	static private function set(var1Name:String, var2Name:String)
	{
		variables[var1Name] = checkVariable(var2Name);
	}
	
	/**
	 * Print out a message. Surround variables with percentage signs (%) to print their values.
	 * 
	 * Script format: Print MSG
	 */
	static private function print(msg:String)
	{
		var reg:EReg = ~/%(.+?)%/;
		
		while (reg.match(msg))
		{
			var posLen = reg.matchedPos();
			var varName:String = msg.substr(posLen.pos + 1, posLen.len - 2).toLowerCase();
			if (!variables.exists(varName) || !isValidVarName(varName)) throw '$varName is not a valid variable!';
			msg = reg.replace(msg, '${variables[varName]}');
		}
		
		Sys.println('==Script message: ');
		Sys.println('  $msg');
	}
	
	/**
	 * Reads a string of specified length.
	 * 
	 * Script format: GetDString VAR LENGTH [FILENUM]
	 */
	static private function getdstring(varName:String, length:Int, fileNum:Int)
	{
		var val:String = files[fileNum].stream.readString(length);
		variables[varName] = val;
	}
	
	/**
	 * Modifies strings, similar to Math but for strings.
	 * 
	 * Script format: String VAR1 OP VAR2
	 * The result is stored in the VAR1
	 */
	static private function string(var1Name:String, op:String, val2:String)
	{
		var val1:String = variables[var1Name];
		
		if (val1 == null) val1 = '';
		
		switch(op)
		{
			case '=':
				val1 = val2;
			case '+', '+=':
				val1 = '$val1$val2';
			case '-', '-=':
				var x:Int = Std.parseInt(val2);
				
				if (x == null) StringTools.replace(val1, val2, '');
				else val1 = (x < 0) ? val1.substring( -x) : val1.substring(0, val1.length - x);
			default:
				throw 'Invalid operator!';
		}
		
		variables[var1Name] = val1;
	}
	
	/**
	 * Performs mathematical operations on numbers.
	 * 
	 * Script format: Math VAR1 OP VAR2
	 * The result is stored in the VAR1
	 */
	static private function math(var1Name:String, op:String, val2:Int)
	{
		var val1Str:String = variables[var1Name];
		var val1:Int = 0;
		
		if (val1Str != null) val1 = checkType(val1Str, IntA, 1);
		
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
				throw 'Invalid operator!';
		}
		
		variables[var1Name] = val1;
	}
	/**
	 * Checks that the string STRING is at the current position of the file. Good for checking magic IDs.
	 * 
	 * Script format: IDString STRING [FILENUM]
	 */
	static private function idstring(val:String, fileNum:Int)
	{
		var s:String = files[fileNum].stream.readString(val.length);
		
		if (s != val)
		{
			throw 'IDString expecting $val, got $s';
		}
	}
	
	/**
	 * Goes to the position OFFSET in the file.
	 * 
	 * Script format: GoTo OFFSET [TYPE] [FILENUM]
	 * If OFFSET is 'SOF' or 'EOF' it will go to start or end of file, respectively (overrides TYPE).
	 */
	static private function goto(varName:String, type:String, fileNum:Int)
	{
		var offset:Int = 0;
		
		if (varName == 'SOF')
		{
			type = 'set';
		}
		else
		if (varName == 'EOF')
		{
			type = 'end';
		}
		else offset = checkType(checkVariable(varName), IntA, 1);
		
		var seekType:FileSeek = FileSeek.SeekBegin;
		
		switch(type.toLowerCase())
		{
			case 'set':
				seekType = FileSeek.SeekBegin;
			case 'cur':
				seekType = FileSeek.SeekCur;
			case 'end':
				seekType = FileSeek.SeekEnd;
			default:
				throw 'Invalid seek type!';
		}
		
		files[fileNum].stream.seek(offset, seekType);
	}
	
	/**
	 * Reads image data and stores it in a variable. Should be used after SetFormat.
	 * 
	 * Script format: Read VAR WIDTH HEIGHT [FILENUM] [LENGTH]
	 * The image object is stored in VAR.
	 */
	static private function read(varName:String, width:Int, height:Int, fileNum:Int, length:Int)
	{
		var img:Image = new Image();
		
		if (indexed) img.readIndexed(width, height, bpp, format, bpc, palOff, files[fileNum].stream, files[palFile].stream, length, palLength);
		else img.read(width, height, bpp, format, files[fileNum].stream, length);
		
		variables[varName] = img;
	}
	
	/**
	 * Defines the format of images and pixels. Should be used before Read.
	 * 
	 * Script format: SetFormat BPP FORMAT [INDEXED] [BPC] [PALOFF] [FILENUM] [PALLENGTH]
	 */
	static private function setformat(a1:Int, a2:String, a3:Int, a4:Int, a5:Int, a6:Int, a7:Int)
	{
		bpp = a1;
		format = a2;
		indexed = (a3 != 0);
		bpc = a4;
		palOff = a5;
		palFile = a6;
		palLength = a7;
	}
	
	/**
	 * Stores the current file position in a variable.
	 * 
	 * Script format: SavePos VAR [FILENUM]
	 */
	static private function savepos(varName:String, fileNum:Int)
	{
		variables[varName] = files[fileNum].stream.tell();
	}
	
	/**
	 * Saves an image to a PNG.
	 * 
	 * Script format: SavePNG IMG [NAME]
	 */
	static private function savepng(img:Image, fName:String)
	{
		img.savePNG(fName, outDir);
	}
	
	/**
	 * Flips an image either horizontally or vertically.
	 * 
	 * Script format: Flip IMG [VERT]
	 * VERT is false by default.
	 */
	static private function flip(img:Image, vert:Int)
	{
		img.flip(vert == 1);
	}
}

/**
 * Variable types
 */
private enum VarType
{
	ByteV;
	ShortV;
	LongV;
	StringV;
	ImageV;
}

/**
 * Argument types
 */
private enum ArgType
{
	StringA;
	IntA;
	ImageA;
	OccupiedVarA;
	VarNameA;
	TypeA;
	FileNumA;
}