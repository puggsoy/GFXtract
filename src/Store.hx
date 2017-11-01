package;
import values.*;
import sys.io.FileInput;

/**
 * Stores variable and other 
 */
class Store 
{
	private var map:Map<VarVal, Value>;
	
	public var files(default, null):Array<FileInput>;
	public var defaultFile(default, set):Int;
	
	public var outDir(default, null):String;
	
	public function new(file:FileInput, outDir:String) 
	{
		map = new Map<VarVal, Value>();
		
		files = [file];
		defaultFile = 0;
		this.outDir = outDir;
	}
	
	public function exists(n:VarVal):Bool
	{
		return map.exists(n);
	}
	
	public function existsS(s:String):Bool
	{
		for (k in map.keys())
		{
			if (s == k.name) return true;
		}
		
		return false;
	}
	
	public function get(n:VarVal):Value
	{
		return map.get(n);
	}
	
	public function set(n:VarVal, v:Value)
	{
		map.set(n, v);
	}
	
	public function set_defaultFile(value:Int):Int 
	{
		if (value >= files.length)
			throw 'No file of index $value';
		
		return defaultFile = value;
	}
	
	public function toString():String
	{
		var r:String = '';
		
		for (k in map.keys())
		{
			r += '$k -> ${map.get(k)}\n';
		}
		
		return r;
	}
}