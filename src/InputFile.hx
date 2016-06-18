package;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileSeek;

class InputFile
{
	/**
	 * The actual stream to the file.
	 */
	public var stream:FileInput;
	
	/**
	 * The file's size in bytes.
	 */
	public var size:Int;
	
	/**
	 * The file's name.
	 */
	public var fileName:String;
	
	/**
	 * The file's name, not including extension.
	 */
	public var baseName:String;
	
	/**
	 * The file's fully qualified path.
	 */
	public var fullName:String;
	
	/**
	 * The file's fully qualified path, not including extension.
	 */
	public var fullBaseName:String;
	
	/**
	 * The fully qualified path to the file's directory.
	 */
	public var filePath:String;
	
	/**
	 * The extension of the file.
	 */
	public var extension:String;
	
	public function new(fn:String)
	{
		stream = File.read(fn);
		
		stream.seek(0, FileSeek.SeekEnd);
		size = stream.tell();
		stream.seek(0, FileSeek.SeekBegin);
		
		fileName = Path.withoutDirectory(fn);
		baseName = Path.withoutExtension(Path.withoutDirectory(fn));
		fullName = FileSystem.fullPath(fn);
		fullBaseName = Path.withoutExtension(fullName);
		filePath = Path.directory(fullName);
		extension = Path.extension(fn);
	}
}