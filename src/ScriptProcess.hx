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
		
		if (command == 'if') return ifStatement(args);
		
		if (command == 'for') return forLoop(args);
		
		if (command == 'exit') return exit();
		
		Commands.call(command, args);
	}
	
	/**
	 * Splits a line into a command and arguments.
	 */
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
	 * Handles if statements.
	 * 
	 * Script format: If VAR1 COND VAR2 [...]
	 * 				  ...
	 * 				  [Elif VAR COND VAR]
	 * 				  ...
	 * 				  [Else]
	 * 				  ...
	 * 				  Endif
	 */
	private function ifStatement(args:Array<String>)
	{
		if (Commands.checkIf(args))
		{
			var cmd:String = splitLine(script[++currentLine])[0].toLowerCase();
			
			while (cmd != 'elif' && cmd != 'else' && cmd != 'endif')
			{
				parseLine(script[currentLine]);
				if (++currentLine >= script.length) return;
				cmd = splitLine(script[currentLine])[0].toLowerCase();
			}
			
			if (cmd == 'elif' || cmd == 'else') skipUntil(['endif']);
		}
		else
		{
			var cmd:String = skipUntil(['elif', 'else', 'endif']);
			if (cmd == 'elif')
			{
				var a:Array<String> = splitLine(script[currentLine]);
				a.shift();
				ifStatement(a);
			}
			else
			if (cmd == 'else')
			{
				ifStatement(['1', '==', '1']);
			}
		}
	}
	
	/**
	 * Handles for loops
	 * 
	 * Script format: For [VAR] [OP] [VAR] [COND] [VAR]
	 * 				  ...
	 * 				  Next [VAR] [OP] [VAR]
	 */
	private function forLoop(args:Array<String>)
	{
		var condResult:Bool = true;
		var startLine:Int = currentLine;
		
		if (args.length >= 3)
		{
			Commands.call('math', args);
			
			if (args.length >= 5)
			{
				condResult = Commands.checkCondition([args[0], args[3], args[4]]);
			}
		}
		
		if(!condResult)
		{
			skipUntil(['next']);
			return;
		}
		
		while (condResult)
		{
			currentLine = startLine;
			
			var cmd:String = splitLine(script[++currentLine])[0].toLowerCase();
			
			while (cmd != 'next' && cmd != 'break')
			{
				parseLine(script[currentLine]);
				if (++currentLine >= script.length) return;
				cmd = splitLine(script[currentLine])[0].toLowerCase();
			}
			
			if (cmd == 'break')
			{
				skipUntil(['next']);
				return;
			}
			
			var nArgs:Array<String> = splitLine(script[currentLine]);
			nArgs.shift();
			
			if (nArgs.length >= 3) Commands.call('math', [nArgs[0], nArgs[1], nArgs[2]]);
			else
			if (nArgs.length >= 1) Commands.call('math', [nArgs[0], '+=', '1']);
			
			condResult = Commands.checkCondition([args[0], args[3], args[4]]);
		}
	}
	
	/**
	 * Skips lines until it finds one of the specified commands. Returns the found command.
	 */
	private function skipUntil(end:Array<String>):String
	{
		var cmd:String = splitLine(script[++currentLine])[0].toLowerCase();
		
		while (end.indexOf(cmd) == -1)
		{
			if (cmd == 'if') skipUntil(['endif']);
			if (cmd == 'for') skipUntil(['next']);
			if (++currentLine >= script.length) return 'end of script';
			cmd = splitLine(script[currentLine])[0].toLowerCase();
		}
		
		return cmd;
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