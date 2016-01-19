package;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileSeek;

class InputFile
{
	public var stream:FileInput;
	public var size:Int;
	public var fileName:String;
	public var baseName:String;
	public var fullName:String;
	public var fullBaseName:String;
	public var filePath:String;
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