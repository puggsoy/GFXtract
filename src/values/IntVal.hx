package values;

class IntVal extends Value 
{
	public var value(default, null):Int;
	
	public function new(v:Int) 
	{
		super();
		value = v;
	}
}