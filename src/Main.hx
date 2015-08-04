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
	
	public function new()
	{
		args = Sys.args();
		
		if (args.length < 1)
		{
			Sys.println('Not enough arguments!');
			Sys.exit(1);
		}
		
		var scriptFile:String = args[0];
		
		if (!FileSystem.exists(scriptFile))
		{
			Sys.println('$scriptFile doesn\'t exist!');
			Sys.exit(2);
		}
		
		var bytesInput:BytesInput = new BytesInput(File.getBytes(scriptFile));
		
		parseScript(bytesInput);
	}
	
	private function parseScript(script:BytesInput)
	{
		var lines:Array<String> = [while (script.position < script.length) script.readLine()];
		
		var sp:ScriptProcess = new ScriptProcess(lines);
		sp.run();
	}
	
	static function main()
	{
		var main:Main = new Main();
	}
}