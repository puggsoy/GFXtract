package;

/**
 * Handles the flow of script execution on a file.
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
	static public var currentLine:Int = 0;
	
	/**
	 * Constructor.
	 */
	/**
	 * Constructor.
	 * @param	script The script as an array of lines.
	 * @param	file   The filename.
	 * @param	outDir The output directory.
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
	 * @param	line The line to execute.
	 */
	private function parseLine(line:String)
	{
		//Skip empty lines
		if (line.length == 0) return;
		
		//Split the line into a command and arguments
		var args:Array<String> = splitLine(line);
		var command:String = args.shift();
		
		//If it's a special flow block, handle it specially
		if (command == 'if') return ifStatement(args);
		
		if (command == 'for') return forLoop(args);
		
		if (command == 'exit') return exit();
		
		//Otherwise call the command
		Commands.call(command, args);
	}
	
	/**
	 * Splits a line into a command and arguments.
	 * @param	line The line to split.
	 */
	private function splitLine(line:String):Array<String>
	{
		var ret:Array<String> = new Array();
		var args:Array<String> = line.split(' ');
		var command:String = args.shift().toLowerCase();
		ret.push(command);
		
		var single:Bool = false;
		var str:String = null;
		
		//This goes through and splits the line by spaces, taking quoted strings into account
		for (s in args)
		{
			//If we're not already in quotes
			if (str == null)
			{
				//Check if there's a quote at the start
				if (s.indexOf("'") == 0 || s.indexOf('"') == 0)
				{
					//Must keep track if it's single quotes
					single = (s.charAt(0) == "'");
					
					str = s;
				}
				else
				{
					ret.push(s);
				}
			}
			//If we're already in quotes
			else
			{
				str += ' $s';
			}
			
			//If we're in quotes
			if (str != null)
			{
				var q:String = single ? "'" : '"';
				
				//Check if there's closing quotes
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
	 * @param	args The condition as command arguments.
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
		//If the condition is true
		if (Commands.checkIf(args))
		{
			//Then go to the next line and keep executing it until we hit a closing of the block
			var cmd:String = splitLine(script[++currentLine])[0].toLowerCase();
			
			while (cmd != 'elif' && cmd != 'else' && cmd != 'endif')
			{
				parseLine(script[currentLine]);
				if (++currentLine >= script.length) return;
				cmd = splitLine(script[currentLine])[0].toLowerCase();
			}
			
			//Skip all elifs and elses
			if (cmd == 'elif' || cmd == 'else') skipUntil(['endif']);
		}
		//If the condition is false
		else
		{
			//Skip until we get to an elif/else or endif
			var cmd:String = skipUntil(['elif', 'else', 'endif']);
			if (cmd == 'elif')
			{
				//If it's an elif we need to check its condition
				var a:Array<String> = splitLine(script[currentLine]);
				a.shift();
				ifStatement(a);
			}
			else
			if (cmd == 'else')
			{
				//An else gets executed, we can just pass in something that's guaranteed true
				ifStatement(['1', '==', '1']);
			}
		}
	}
	
	/**
	 * Handles for loops.
	 * @param	args The condition as command arguments.
	 * 
	 * Script format: For [VAR] [OP] [VAR] [COND] [VAR]
	 * 				  ...
	 * 				  Next [VAR] [OP] [VAR]
	 */
	private function forLoop(args:Array<String>)
	{
		var condResult:Bool = true;
		var startLine:Int = currentLine;
		
		//Do math and condition checking if there are enough arguments for it
		if (args.length >= 3)
		{
			Commands.call('math', args);
			
			if (args.length >= 5)
			{
				condResult = Commands.checkCondition([args[0], args[3], args[4]]);
			}
		}
		
		//If it fails the first time, just skip the whole block
		if(!condResult)
		{
			skipUntil(['next']);
			return;
		}
		
		//While the condition is true keep looping
		while (condResult)
		{
			currentLine = startLine;
			
			//Until we hit a next or break command just keep executing
			var cmd:String = splitLine(script[++currentLine])[0].toLowerCase();
			
			while (cmd != 'next' && cmd != 'break')
			{
				parseLine(script[currentLine]);
				if (++currentLine >= script.length) return;
				cmd = splitLine(script[currentLine])[0].toLowerCase();
			}
			
			//If we hit a break, jump out
			if (cmd == 'break')
			{
				skipUntil(['next']);
				return;
			}
			
			//Otherwise we've hit a next, in which case we need to get its args
			var nArgs:Array<String> = splitLine(script[currentLine]);
			nArgs.shift();
			
			//If there's 3 or more, do maths on it
			if (nArgs.length >= 3) Commands.call('math', [nArgs[0], nArgs[1], nArgs[2]]);
			else
			//If there's less than 3 but at least 1, just increment it
			if (nArgs.length >= 1) Commands.call('math', [nArgs[0], '+=', '1']);
			
			//Check the condition again
			//BUG: This doesn't work if we didn't give it a condition!
			condResult = Commands.checkCondition([args[0], args[3], args[4]]);
		}
	}
	
	/**
	 * Skips lines until it finds one of the specified commands.
	 * @param	end
	 * @return The found command.
	 */
	private function skipUntil(end:Array<String>):String
	{
		var cmd:String = splitLine(script[++currentLine])[0].toLowerCase();
		
		while (end.indexOf(cmd) == -1)
		{
			//Need to skip nested ifs and fors
			if (cmd == 'if') skipUntil(['endif']);
			if (cmd == 'for') skipUntil(['next']);
			if (++currentLine >= script.length) return 'end of script'; //TODO: Should probably crash to be honest
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
		
		if (terminate) exit();
	}
}