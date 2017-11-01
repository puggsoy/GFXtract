package;
import values.*;

class Store 
{
	private var map:Map<VarVal, Value>;
	
	public var defaultFile(default, null):Int;
	
	public function new() 
	{
		map = new Map<VarVal, Value>();
		defaultFile = 0;
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
}