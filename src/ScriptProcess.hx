package;

/**
 * Handles the flow of script execution.
 */
class ScriptProcess
{
	/**
	 * The script, in separate lines.
	 */
	private var script:Array<String>;
	
	/**
	 * The current line the script reader is on.
	 */
	private var currentLine:Int = 0;
	
	
	/**
	 * Constructor.
	 */
	public function new(script:Array<String>, file:String, outDir:String)
	{
		this.script = script;
		Commands.files = new Array<InputFile>();
		Commands.files.push(new InputFile(file));
		Commands.outDir = outDir;
	}
	
	/**
	 * Start the script.
	 */
	public function startScript()
	{
		currentLine = 0;
		
		while (currentLine < script.length)
		{
			try
			{
				parseLine(script[currentLine]);
				currentLine++;
			}
			catch (e:Dynamic)
			{
				error(e);
			}
		}
	}
	
	/**
	 * Read in and execute a line.
	 */
	private function parseLine(line:String)
	{
		if (line.length == 0) return;
		
		var args:Array<String> = splitLine(line);
		var command:String = args.shift();
		
		if (command == 'exit') exit();
		
		Commands.call(command, args);
	}
	
	private function splitLine(line:String):Array<String>
	{
		var ret:Array<String> = new Array();
		var args:Array<String> = line.split(' ');
		var command:String = args.shift().toLowerCase();
		ret.push(command);
		
		var single:Bool = false;
		var str:String = null;
		
		for (s in args)
		{
			if (str == null)
			{
				if (s.indexOf("'") == 0 || s.indexOf('"') == 0)
				{
					single = (s.charAt(0) == "'");
					
					str = s;
				}
				else
				{
					ret.push(s);
				}
			}
			else
			{
				str += ' $s';
			}
			
			if (str != null)
			{
				var q:String = single ? "'" : '"';
				
				if (s.lastIndexOf(q) == s.length - 1)
				{
					ret.push(str.substring(1, str.length - 1));
					str = null;
				}
			}
		}
		
		return ret;
	}
	
	/**
	 * Cleanly exit the program.
	 * 
	 * Script format: Exit
	 */
	private function exit()
	{
		currentLine = script.length;
	}
	
	/**
	 * Prints errors and terminates script.
	 */
	public function error(msg:String, terminate:Bool = true)
	{
		Sys.println('--Error on line ${currentLine + 1}:');
		Sys.println('  $msg');
		
		if (terminate) Sys.exit(-1);
	}
}