package;

import haxe.io.BytesInput;
import haxe.io.Input;
import haxe.io.Path;
import neko.Lib;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileSeek;

class Main 
{
	private var args:Array<String> = Sys.args();
	
	static private inline var USAGE:String = 'Usage: GFXtract script inFile [outDir]\n    script: The .gxs script containing the instructions for converting.\n    inFile: The file to convert. Can also be a directory containing the files to convert.\n    outDir: Optional, the directory to place the converted files in. If omitted, the directory of the input files is used.';
	static private inline var VERSION:String = '0.1';
	private var DATE:Date = Date.now();
	
	/**
	 * Takes in arguments and opens script file.
	 */
	public function new()
	{
		if (args.length < 2)
		{
			Sys.println('Not enough arguments!');
			Sys.exit(1);
		}
		
		Sys.println('GFXtract graphics converter $VERSION\nby puggsoy');
		Sys.println('Buildtime: ' + DateTools.format(Date.now(), '%d %b %Y - %H:%M:%S\n'));
		
		//Loading the script
		var scriptPath:String = args[0];
		
		Sys.print('- ');
		if (!FileSystem.exists(scriptPath))
		{
			Sys.println('Script $scriptPath doesn\'t exist!');
			Sys.exit(1);
		}
		
		Sys.println('Loading script $scriptPath');
		
		var scriptFile:FileInput = File.read(scriptPath);
		
		//Loading the input file
		var inputPath:String = args[1];
		
		Sys.print('- ');
		var w:String = (FileSystem.isDirectory(inputPath)) ? 'folder' : 'file';
		if (!FileSystem.exists(inputPath))
		{
			Sys.println('Input $w $inputPath doesn\'t exist!');
			Sys.exit(2);
		}
		
		Sys.println('Loading input $w $scriptPath');
		
		var inputFiles:Array<String> = new Array<String>();
		
		if (FileSystem.isDirectory(inputPath))
		{
			var fileNames:Array<String> = FileSystem.readDirectory(inputPath);
			
			for (fn in fileNames) inputFiles.push(Path.addTrailingSlash(inputPath) + fn);
		}
		else inputFiles.push(inputPath);
		
		//Setting the output directory
		var outPath:String = (args.length > 2) ? args[2] : '.';
		
		if (FileSystem.exists(outPath) && !FileSystem.isDirectory(outPath))
		{
			Sys.println('Output folder must be a valid directory');
			Sys.exit(3);
		}
		else
		if (!FileSystem.exists(outPath))
		{
			Sys.println('Output folder $outPath doesn\'t exist, do you want to create it? (y/n)');
			var c:Int = Sys.getChar(true);
			Sys.println('');
			
			if (c == 'y'.charCodeAt(0))
			{
				FileSystem.createDirectory(outPath);
			}
			else
			{
				Sys.println('Folder needs to exist!');
			}
		}
		
		Sys.println('- Setting output directory $outPath\n');
		
		parseScript(scriptFile, inputFiles, outPath);
	}
	
	/**
	 * Loads input file(s) and runs the script on each.
	 */
	private function parseScript(script:FileInput, files:Array<String>, outPath:String)
	{
		var lines:Array<String> = new Array<String>();
		var inComment:Bool = false;
		
		while (!script.eof())
		{
			var r:Array<Dynamic> = removeComments(script.readLine(), inComment);
			
			lines.push(r[0]);
			inComment = r[1];
		}
		
		var lines:Array<String> = [for(line in lines) StringTools.ltrim(line)];
		
		for (i in 0...files.length)
		{
			if (files.length > 1)
			{
				Sys.println('\nFile ${i + 1} of ${files.length}: ' + Path.withoutDirectory(files[i]));
			}
			
			Sys.println('----------------------------------------');
			
			new ScriptProcess(lines, files[i], outPath).run();
		}
		
		Sys.print('\n-Complete, press any key to close-');
		Sys.getChar(false);
	}
	
	private function removeComments(line:String, inComment:Bool):Array<Dynamic>
	{
		var startCom:Int = line.indexOf('#');
		if(startCom != -1) line = line.substring(0, startCom);
		var startCom:Int = line.indexOf('//');
		if(startCom != -1) line = line.substring(0, startCom);
		
		startCom = 0;
		var endCom:Int = -2;
		
		if (inComment)
		{
			endCom = line.indexOf('*/');
		}
		
		while(startCom != -1)
		{
			if (endCom == -1)
			{
				line = line.substring(0, startCom);
				return [line, true];
			}
			
			line = line.substring(0, startCom) + line.substring(endCom + 2);
			
			startCom = line.indexOf('/*');
			endCom = line.indexOf('*/', startCom + 2);
		}
		
		return [line, false];
	}
	
	/***************
	 * Entry point
	 */
	static function main()
	{
		var main:Main = new Main();
	}
}