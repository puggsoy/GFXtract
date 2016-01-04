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
	var args:Array<String>;
	
	/**
	 * Takes in arguments and opens script file.
	 */
	public function new()
	{
		args = Sys.args();
		
		if (args.length < 3)
		{
			Sys.println('Not enough arguments!');
			Sys.exit(1);
		}
		
		for (i in 0...2)
		{
			if (!FileSystem.exists(args[i]))
			{
				Sys.println('${args[i]} doesn\'t exist!');
				Sys.exit(2);
			}
		}
		
		var scriptPath:String = args[0];
		var inputPath:String = args[1];
		var outPath:String = Path.addTrailingSlash(args[2]);
		
		var scriptFile:FileInput = File.read(scriptPath);
		var inputFiles:Array<String> = new Array<String>();
		
		if (FileSystem.isDirectory(inputPath))
		{
			var fileNames:Array<String> = FileSystem.readDirectory(inputPath);
			
			for (fn in fileNames) inputFiles.push(Path.addTrailingSlash(inputPath) + fn);
		}
		else inputFiles.push(inputPath);
		
		if (FileSystem.exists(outPath) && !FileSystem.isDirectory(outPath))
		{
			Sys.println('Output must be a valid directory');
			Sys.exit(3);
		}
		else
		if (!FileSystem.exists(outPath))
		{
			FileSystem.createDirectory(outPath);
		}
		
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
		
		for (f in files)
		{
			new ScriptProcess(lines, f, outPath).run();
		}
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