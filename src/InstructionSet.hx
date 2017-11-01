package;
import statements.Command;
import statements.Statement;
import statements.commands.Get;
import sys.io.File;
import sys.io.FileInput;
import values.GetTypeVal;
import values.IntVal;
import values.StringVal;
import values.Value;
import values.VarVal;

class InstructionSet 
{
	private var statements:Array<Statement>;
	
	public function new(lines:Array<String>) 
	{
		statements = new Array<Statement>();
		
		for (line in lines)
		{
			var argStrings:Array<String> = line.split(' '); //TODO: make this consider quotes
			var commandString:String = argStrings.shift();
			
			var args:Array<Value> = 
				[for (s in argStrings) argToVal(s)];
			
			var command:Command =
			switch(commandString)
			{
				case 'get': new Get(args);
				default: throw 'Invalid command!';
			}
			
			statements.push(command);
		}
	}
	
	public function execute(fPath:String, outDir:String):Void
	{
		var f:FileInput = File.read(fPath);
		var store:Store = new Store(f, outDir);
		
		Sys.println('before:\n${store.toString()}');
		
		for (stmt in statements)
		{
			stmt.execute(store);
		}
		
		Sys.println('after:\n${store.toString()}');
	}
	
	public function print():Void
	{
		for (stmt in statements)
		{
			Sys.println(stmt.toString());
		}
	}
	
	private function argToVal(arg:String):Value
	{
		if (Std.parseInt(arg.charAt(0)) != null)
		{
			return new IntVal(Std.parseInt(arg));
		}
		
		if (arg.charAt(0) == '"' &&
			arg.charAt(arg.length - 1) == '"')
		{
			return new StringVal(arg.substring(1, arg.length - 1));
		}
		
		var types:Array<String> =
			[for (s in GetType.getConstructors()) s.toLowerCase()];
		var index:Int = types.indexOf(arg);
		
		if (index != -1)
		{
			return new GetTypeVal(GetType.createByIndex(index));
		}
		
		return new VarVal(arg);
	}
}