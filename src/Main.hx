package;

import haxe.io.BytesInput;
import haxe.io.Input;
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
		
		if (args.length < 2)
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
		
		var scriptFile:FileInput = File.read(scriptPath);
		var inputFile:FileInput = File.read(inputPath);
		
		parseScript(scriptFile, inputFile);
	}
	
	/**
	 * Loads input file(s) and runs the script on each.
	 */
	private function parseScript(script:FileInput, input:FileInput)
	{
		var lines:Array<String> = [while (!script.eof()) StringTools.ltrim(script.readLine())];
		
		var sp:ScriptProcess = new ScriptProcess(lines, input);
		sp.run();
	}
	
	/***************
	 * Entry point
	 */
	static function main()
	{
		var main:Main = new Main();
	}
}