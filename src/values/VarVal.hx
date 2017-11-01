package values;

class VarVal extends Value 
{
	public var name(default, null):String;
	
	public function new(n:String) 
	{
		super();
		name = n;
	}
}