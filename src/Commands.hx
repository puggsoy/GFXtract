package;
import haxe.io.Path;
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
	
	/**
	 * Checks an if statement's arguments, including AND (&&) and OR (||) connectors.
	 * @param	args The if's arguments.
	 * @return The result of the arguments.
	 */
	static public function checkIf(args:Array<String>):Bool
	{
		if (args.length < 3) throw 'A condition requires 3 arguments!';
		
		var ret:Bool = false;
		
		//A condition needs three arguments (LHS, operator, RHS)
		while (args.length >= 3)
		{
			ret = checkCondition(args.splice(0, 3));
			
			if (args.length > 0)
			{
				var op:String = args.shift();
				
				if (op == '&&')
				{
					//AND breaks  if the first is false
					if (!ret) break;
					else continue;
				}
				else
				if (op == '||')
				{
					//OR breaks if the first is true
					if (!ret) continue;
					else break;
				}
				else break;
			}
		}
		
		return ret;
	}
	
	/**
	 * Checks a conditional statement made up of two values and a comparator.
	 * @param	args The arguments of the condition.
	 * @return The result of the condition.
	 */
	static public function checkCondition(args:Array<String>):Bool
	{
		var var1:Dynamic = checkVariable(args[0]);
		var comp:String = args[1];
		var var2:Dynamic = checkVariable(args[2]);
		
		var num1:Int = Std.parseInt(var1);
		var num2:Int = Std.parseInt(var2);
		
		switch(comp)
		{
			//Can compare any type
			case '==':
				if (Type.getClass(var1) == Image) return Image.equals(var1, var2);
				if (num1 != null && num2 != null) return num1 == num2;
				return var1 == var2;
			
			case '!=':
				if (Type.getClass(var1) == Image) return !Image.equals(var1, var2);
				if (num1 != null && num2 != null) return num1 != num2;
				return var1 != var2;
			
			//Can only compare integers
			case '<', '>', '<=', '>=':
				if (num1 == null || num2 == null) throw 'Can only use $comp to compare integers!';
				if (comp == '<') return num1 < num2;
				if (comp == '>') return num1 > num2;
				if (comp == '<=') return num1 <= num2;
				if (comp == '>=') return num1 >= num2;
			
			default:
				throw 'Invalid comparison $comp';
		}
		
		return false;
	}
	
	/**
	 * Call a command.
	 * @param	command    The command to call.
	 * @param	stringArgs The command's arguments.
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
			case 'endian':
				args = parseArgs(stringArgs, [StringA, VarNameA], [null, '']);
				endian(args[0], args[1]);
			case 'open':
				args = parseArgs(stringArgs, [StringA, StringA, IntA, VarNameA], [null, null, 0, '']);
				open(args[0], args[1], args[2], args[3]);
			case 'tiled':
				args = args = parseArgs(stringArgs, [IntA, IntA, IntA], [null, null, 0]);
				tiled(args[0], args[1], args[2]);
			/*case 'transcol':
				args = parseArgs(stringArgs, [IntA, IntA], null, true);
				transcol(args[0], args.slice(1));*/
			default:
				throw 'No such command: $command';
		}
	}
	
	/**
	 * Parses in string arguments into the types given.
	 * @param	args     The string arguments.
	 * @param	types    The type each argument should be.
	 * @param	defaults The default values for each argument.
	 * @param	rest     Whether or not there can be an indefinite number of the last argument. (currently unused)
	 * @return An array of the parsed arguments, in their types.
	 */
	static private function parseArgs(args:Array<String>, types:Array<ArgType>, ?defaults:Array<Dynamic>, ?rest:Bool = false):Array<Dynamic>
	{
		var ret:Array<Dynamic> = new Array<Dynamic>();
		
		//Go through all the types
		for (i in 0...types.length)
		{
			//If there are no arguments at this point
			if (i >= args.length)
			{
				//If the default is null, we need an argument!
				if (defaults == null || defaults[i] == null) throw 'Not enough arguments!';
				//Otherwise just give it the default
				else ret.push(defaults[i]);
				//Move onto the next one
				continue;
			}
			
			//If there is an argument
			//If we're at the last one and rest is true, we can take in all the ones after this point
			if (i == types.length - 1 && rest)
			{
				var j:Int = i;
				while (j < args.length)
				{
					ret.push(checkType(args[j], types[i], j));
					j++;
				}
			}
			//Otherwise just grab it
			else
			{
				ret.push(checkType(args[i], types[i], i));
			}
		}
		
		return ret;
	}
	
	/**
	 * Checks an argument's type and returns it in that type.
	 * @param	stringArg The argument as a string.
	 * @param	type      The type we want it in.
	 * @param	argNum    The number of this argument (for error messages).
	 * @return The argument in the requested type.
	 */
	static private function checkType(stringArg:String, type:ArgType, argNum:Int):Dynamic
	{
		//Get the variable as some unknown type
		var dynArg:Dynamic = (type == OccupiedVarA || type == VarNameA) ? stringArg : checkVariable(stringArg);
		
		//If we got an image, handle that
		if (Type.getClass(dynArg) == Image)
		{
			if (type == ImageA)
			{
				return dynArg;
			}
			else throw 'Argument $argNum should not be an image!';
		}
		
		//Otherwise we're gonna handle it as a string
		var arg:String = Std.string(dynArg);
		
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
	 * Checks if a string is a variable's name.
	 * @param	name The name of the variable.
	 * @return The variable's value, if it exists; otherwise it returns the given name.
	 */
	static private function checkVariable(name:String):Dynamic
	{
		if(variables.exists(name.toLowerCase())) return variables[name.toLowerCase()];
		else return name;
	}
	
	/**
	 * Checks that a string is a valid variable name. This means it can contain a-z, A-Z, 0-9, underscore (_), and starts with
	 * an alphabetical character.
	 * @param	name The variable name.
	 * @return Whether or not it's a valid name.
	 */
	static private function isValidVarName(name:String):Bool
	{
		return ~/^[A-Za-z]\w*$/.match(name);
	}
	
	/**
	 * Gets a VarType from a string (case insensitive).
	 * @param	str The string.
	 * @return The VarType.
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
	
	/**
	 * Replaces "\x" notation bytes with their string characters.
	 * @param	str The string containing the bytes
	 * @return The filtered string.
	 */
	static private function filterBytes(str:String):String
	{
		var reg:EReg = ~/\\x[A-Za-z0-9][A-Za-z0-9]/;
		
		while (reg.match(str))
		{
			var pos:Int = reg.matchedPos().pos;
			var num:Int = Std.parseInt('0x${str.substr(pos + 2, 2)}');
			if (num == null) throw '\\x${str.substr(pos + 2, 2)} is an invalid binary number!';
			
			str = reg.replace(str, String.fromCharCode(num));
		}
		
		return str;
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
		var f:InputFile = files[fileNum];
		
		switch(type)
		{
			case ByteV:
				val = Std.string(f.stream.readByte());
			case ShortV:
				val = Std.string(f.stream.readUInt16());
			case LongV:
				val = Std.string(f.stream.readInt32());
			case StringV:
				val = f.stream.readUntil(0);
			case ImageV:
				throw 'Can\'t get an image like this';
			case ASizeV:
				val = f.size;
			case FileNameV:
				val = f.fileName;
			case BaseNameV:
				val = f.baseName;
			case FullNameV:
				val = f.fullName;
			case FullBaseNameV:
				val = f.fullBaseName;
			case FilePathV:
				val = f.filePath;
			case ExtensionV:
				val = f.extension;
			case LineV:
				val = f.stream.readLine();
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
		if (variables.exists(var2Name.toLowerCase()))
		{
			filterBytes(var2Name);
		}
		
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
		
		msg = filterBytes(msg);
		
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
		var val1:String = '';
		
		if (variables.exists(var1Name)) val1 = checkType(var1Name, StringA, 1);
		
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
		
		val1 = filterBytes(val1);
		
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
		var val1:Int = 0;
		
		if (variables.exists(var1Name)) val1 = checkType(var1Name, IntA, 1);
		
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
			case '>>', '>>=':
				val1 >>= val2;
			case '<<', '<<=':
				val1 <<= val2;
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
		val = filterBytes(val);
		
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
		else offset = checkType(varName, IntA, 1);
		
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
		
		img.read(width, height, fileNum, length);
		
		variables[varName] = img;
	}
	
	/**
	 * Defines the format of images and pixels. Should be used before Read.
	 * 
	 * Script format: SetFormat BPP FORMAT [INDEXED] [BPC] [PALOFF] [FILENUM] [PALLENGTH]
	 */
	static private function setformat(a1:Int, a2:String, a3:Int, a4:Int, a5:Int, a6:Int, a7:Int)
	{
		Image.bpp = a1;
		Image.format = a2;
		Image.indexed = (a3 != 0);
		Image.bpc = a4;
		Image.palOff = a5;
		Image.palFile = a6;
		Image.palLengthCheck = a7;
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
	
	/**
	 * Changes the endianess of commands that read from files.
	 * 
	 * Script format: Endian TYPE [VAR]
	 * Little endian by default.
	 */
	static private function endian(type:String, varName:String)
	{
		var big:Bool = files[0].stream.bigEndian;
		
		switch(type)
		{
			case 'little', 'intel':
				big = false;
			case 'big', 'network':
				big = true;
			case 'swap', 'change', 'invert':
				big = !big;
			case 'save', 'store':
				variables[varName] = big ? 1 : 0;
				return;
			default:
				throw 'Invalid endian argument: $type';
		}
		
		for (f in files)
		{
			f.stream.bigEndian = big;
		}
	}
	
	/**
	 * Opens a file
	 * 
	 * Script format: Open FOLDER NAME [FILENUM] [EXISTS]
	 * FILENUM is the file number of the opened file.
	 * If EXISTS is specified, it will store 1 if the file does exist and 0 if it doesn't. If not specified, will crash if it doesn't exist.
	 */
	static private function open(folder:String, name:String, fileNum:Int, exists:String)
	{
		var path:String = null;
		
		if (name == '?')
		{
			Sys.println('Please input the filename to open (script line ${ScriptProcess.currentLine}):');
			name = Sys.stdin().readLine();
		}
		
		switch(folder)
		{
			case 'FDDE':
				path = files[0].fullBaseName + '.$name';
			case 'FDSE':
				path = Path.join([files[0].filePath, name]);
			default:
				path = Path.join([outDir, folder, name]);
		}
		
		var file:InputFile;
		
		try
		{
			file = new InputFile(path);
		}
		catch (e:Dynamic)
		{
			if (exists != '')
			{
				variables[exists] = 0;
				return;
			}
			else throw 'Could not open file: $path';
		}
		
		variables[exists] = 1;
		files[fileNum] = file;
	}
	
	static private function tiled(width:Int, height:Int, indexed:Int)
	{
		if (indexed == 0)
		{
			Image.tileW = width;
			Image.tileH = height;
		}
		else
		{
			Image.palTileW = width;
			Image.palTileH = height;
		}
	}
	
	static private function transcol(indexed:Int, cols:Array<Dynamic>)
	{
		Image.excludedIndexed = (indexed != 0);
		Image.excludedCols = new Array<Int>();
		
		for (col in cols)
		{
			Image.excludedCols.push(col);
		}
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
	ASizeV;
	FileNameV;
	BaseNameV;
	FullNameV;
	FullBaseNameV;
	FilePathV;
	ExtensionV;
	LineV;
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