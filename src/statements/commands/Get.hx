package statements.commands;

import statements.Command;
import values.*;
import values.GetTypeVal.GetType;
import sys.io.FileInput;

class Get extends Command 
{
	private var argTypes(default, never):Array<Class<Value>> =
	[
		VarVal,
		GetTypeVal,
		IntVal
	];
	
	private var requiredNum = 2;
	
	private var var1:VarVal;
	private var type:GetTypeVal;
	private var filenum:IntVal;
	
	public function new(args:Array<Value>) 
	{
		super(args);
		
		if (args.length < requiredNum)
			throw 'Get needs at least $requiredNum arguments!';
		
		for (i in 0...argTypes.length)
		{
			if (i >= args.length) break;
			
			//if (Std.is(args[i], argTypes[i]))
			if (Std.instance(args[i], argTypes[i]) == null)
				throw 'Argument ${i + 1} should be ${argTypes[i]} not ${args[i]}!';
		}
		
		var1 = cast(args[0], VarVal);
		type = cast(args[1], GetTypeVal);
		filenum = (args.length > 2) ? cast(args[2], IntVal) : null;
	}
	
	public function execute(files:Array<FileInput>, store:Store):Void
	{
		if (filenum == null) filenum = new IntVal(store.defaultFile);
		
		var f:FileInput = files[filenum.value];
		var v:Value;
		
		switch(type.value)
		{
			case Byte:
				var i:Int = f.readByte();
				v = new IntVal(i);
			case Short:
				var i:Int = f.readUInt16();
				v = new IntVal(i);
			case ThreeByte:
				var i:Int = f.readUInt24();
				v = new IntVal(i);
			case Long:
				var i:Int = f.readInt32();
				v = new IntVal(i);
		}
		
		store.set(var1, v);
	}
	
	override public function toString():String
	{
		return 'Get ${var1.name} $type $filenum';
	}
}