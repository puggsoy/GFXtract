package statements;
import values.StringVal;
import values.Value;

class Command implements Statement
{
	private var args:Array<Value>;
	
	public function new(args:Array<Value>)
	{
		this.args = args;
	}
	
	public function toString():String
	{
		return null;
	}
}