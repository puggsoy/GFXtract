package;

using StringTools;

class Preprocessor 
{
	private function new() {}; //Force this class as static
	
	public static function removeComments(lines:Array<String>):Array<String>
	{
		var newLines:Array<String> = new Array<String>();
		
		for (l in lines)
		{
			var nl:String = l;
			var i:Int = nl.indexOf('//');
			if (i != -1)
				nl = nl.substring(0, i);
			
			nl = l.trim();
			if (nl == '') continue;
			
			newLines.push(nl);
		}
		
		return newLines;
	}
}