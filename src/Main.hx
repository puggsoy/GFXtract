package;

import haxe.io.BytesInput;
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
			Sys.println("Not enough arguments!");
			Sys.exit(1);
		}
		
		var scriptFile:String = args[0];
		
		if (!FileSystem.exists(scriptFile))
		{
			trace(scriptFile + " doesn't exist!");
			Sys.exit(2);
		}
		
		var bytesInput:BytesInput = new BytesInput(File.getBytes(scriptFile));
		var scriptString:String = bytesInput.readString(bytesInput.length);
		
		parseScript(scriptString);
	}
	
	private function parseScript(script:String)
	{
		var lines:Array<String> = script.split("\r\n");
		
		for (str in lines)
		{
			trace(str);
		}
	}
	
	static function main()
	{
		var main:Main = new Main();
	}
}