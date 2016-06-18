package;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import systools.Dialogs;

class Main 
{
	private var args:Array<String> = Sys.args();
	
	static private inline var USAGE:String = 'Usage: GFXtract <script> <inFile> [outDir]\n    script - The .gsl script containing the instructions for converting.\n    inFile - The file to convert. Can also be a directory containing the files to convert.\n    outDir - Optional, the directory to place the converted files in. If omitted, the directory of the input files is used.';
	static private inline var VERSION:String = '0.2.1';
	private var DATE:Date = CompileTime.buildDate();
	private var ALLFILES:FILEFILTERS = { count: 1, descriptions: ['All Files (*.*)'], extensions: ['*.*'] };
	
	/**
	 * The file containing the script.
	 */
	private var scriptFile:FileInput;
	
	/**
	 * Array of the input filenames.
	 */
	private var inputFiles:Array<String>;
	
	/**
	 * The output directory.
	 */
	private var outDir:String;
	
	/**
	 * Takes in arguments and opens script file.
	 */
	public function new()
	{
		Sys.println('GFXtract graphics converter $VERSION\nby puggsoy');
		Sys.println('Buildtime: ' + DateTools.format(DATE, '%d %b %Y - %H:%M:%S\n'));
		
		if (args.length == 0)
		{
			Sys.println('Choose script...');
			var scriptPaths:Array<String> = Dialogs.openFile('Choose script...', 'Choose script...', ALLFILES);
			if (scriptPaths == null) return;
			loadScript(scriptPaths[0]);
			
			Sys.println('Choose file(s)...');
			inputFiles = Dialogs.openFile('Choose file(s)...', 'Choose file(s)...', ALLFILES);
			if (inputFiles == null) return;
			Sys.println('- Loading input files');
			
			Sys.println('Choose output folder...');
			outDir = Dialogs.folder('Choose output folder...', 'Choose output folder...');
			if (outDir == null) return;
			Sys.println('- Setting output directory $outDir\n');
		}
		else
		if(args.length == 1)
		{
			Sys.print(USAGE);
			Sys.exit(1);
		}
		else
		{
			loadScript(args[0]);
			loadInput(args[1]);
			setOutput(args[2]);
		}
		
		parseScript(scriptFile, inputFiles, outDir);
	}
	
	/**
	 * Loads the script file.
	 * @param	scriptPath Path of the file.
	 */
	private function loadScript(scriptPath:String)
	{
		Sys.print('- ');
		if (!FileSystem.exists(scriptPath))
		{
			Sys.println('Script $scriptPath doesn\'t exist!');
			Sys.exit(1);
		}
		
		Sys.println('Loading script $scriptPath');
		
		scriptFile = File.read(scriptPath);
	}
	
	/**
	 * Loads the input file/folder.
	 * @param	inputPath Path of the file/folder.
	 */
	private function loadInput(inputPath:String)
	{
		Sys.print('- ');
		
		if (!FileSystem.exists(inputPath))
		{
			Sys.println('Input $inputPath doesn\'t exist!');
			Sys.exit(2);
		}
		
		var type:String = (FileSystem.isDirectory(inputPath)) ? 'folder' : 'file';
		
		Sys.println('Loading input $type $inputPath');
		
		inputFiles = new Array<String>();
		
		if (FileSystem.isDirectory(inputPath))
		{
			var fileNames:Array<String> = FileSystem.readDirectory(inputPath);
			
			for (fn in fileNames) inputFiles.push(Path.addTrailingSlash(inputPath) + fn);
		}
		else inputFiles.push(inputPath);
	}
	
	private function setOutput(outPath:String)
	{
		outDir = (outPath == null) ? Path.directory(inputFiles[0]) : outPath;
		if (outDir == '') outDir = '.';
		
		if (FileSystem.exists(outDir) && !FileSystem.isDirectory(outDir))
		{
			Sys.println('Output folder must be a valid directory');
			Sys.exit(3);
		}
		else
		if (!FileSystem.exists(outDir))
		{
			Sys.println('Output folder $outDir doesn\'t exist, do you want to create it? (y/n)');
			var c:String = Sys.stdin().readLine();
			
			if (c.charAt(0) == 'y')
			{
				FileSystem.createDirectory(outDir);
			}
			else
			{
				Sys.println('Folder needs to exist!');
			}
		}
		
		Sys.println('- Setting output directory $outDir\n');
	}
	
	/**
	 * Parses the script and runs it on each file.
	 * @param	script  The script file.
	 * @param	files   The array of files.
	 * @param	outPath The output folder.
	 */
	private function parseScript(script:FileInput, files:Array<String>, outPath:String)
	{
		var lines:Array<String> = new Array<String>();
		var inComment:Bool = false;
		
		while (!script.eof())
		{
			var r:Array<Dynamic> = removeComments(script.readLine(), inComment);
			
			lines.push(r[0]);
			inComment = r[1];
		}
		
		var lines:Array<String> = [for(line in lines) StringTools.ltrim(line)];
		
		for (i in 0...files.length)
		{
			if (files.length > 1)
			{
				Sys.println('\nFile ${i + 1} of ${files.length}: ' + Path.withoutDirectory(files[i]));
			}
			
			Sys.println('----------------------------------------');
			
			new ScriptProcess(lines, files[i], outPath).startScript();
		}
		
		if (args.length == 0)
		{
			Sys.print('\n-Complete, press any key to close-');
			Sys.getChar(false);
		}
		if (args.length > 1)
		{
			Sys.print('\n-Complete-');
		}
	}
	
	/**
	 * Removes comments from a line.
	 * @param	line      The line to remove the comment from.
	 * @param	inComment Whether this line starts in a multiline comment. .
	 * @return  An array with two elements: the line without comments, and whether we are in a multiline comment.
	 */
	private function removeComments(line:String, inComment:Bool):Array<Dynamic>
	{
		var startCom:Int = line.indexOf('#');
		if(startCom != -1) line = line.substring(0, startCom);
		var startCom:Int = line.indexOf('//');
		if(startCom != -1) line = line.substring(0, startCom);
		
		startCom = 0;
		var endCom:Int = -2;
		
		if (inComment)
		{
			endCom = line.indexOf('*/');
		}
		
		while(startCom != -1)
		{
			if (endCom == -1)
			{
				line = line.substring(0, startCom);
				return [line, true];
			}
			
			line = line.substring(0, startCom) + line.substring(endCom + 2);
			
			startCom = line.indexOf('/*');
			endCom = line.indexOf('*/', startCom + 2);
		}
		
		return [line, false];
	}
	
	/***************
	 * Entry point
	 */
	static function main()
	{
		var main:Main = new Main();
	}
}