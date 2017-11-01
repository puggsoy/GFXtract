package values;

class StringVal extends Value 
{
	public var value(default, null):String;
	
	public function new(v:String) 
	{
		super();
		value = v;
	}
}