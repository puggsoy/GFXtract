package;
import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.geom.Point;
import openfl.utils.ByteArray;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;

class Image
{
	private var bitmap:BitmapData;
	
	public var width(get, null):Int;
	public var height(get, null):Int;
	
	public function new(){}
	
	public function read(width:Int, height:Int, bpp:Int, format:String, f:FileInput)
	{
		if (!validFormat(format)) throw 'Invalid colour format';
		if (bpp % 8 != 0) throw 'BPP must be a multiple of 8';
		if (bpp > 32) throw 'BPP can\'t be over 32';
		
		var bitsPerChannel:Int = Std.int(bpp / format.length);
		
		bitmap = new BitmapData(width, height, true, 0);
		var pixelNum:Int = width * height;
		var length:Int = Std.int(pixelNum * (bpp / 8));
		
		var bytes:Bytes = f.read(length);
		
		var pixelOutput:BytesOutput = new BytesOutput();
		pixelOutput.bigEndian = true;
		var bytepp:Int = Std.int(bpp / 8);
		var i:Int = 0;
		
		while (i < bytes.length)
		{
			var pix:Int = 0;
			
			for (j in 0...bytepp)
			{
				pix <<= 8;
				pix += bytes.get(i);
				i++;
			}
			
			var a:Int = null;
			var r:Int = 0;
			var g:Int = 0;
			var b:Int = 0;
			
			for (j in 0...format.length)
			{
				var chan:Int = pix >>> ((format.length - 1 - j) * bitsPerChannel);
				chan <<= 8 - bitsPerChannel;
				var char:String = format.charAt(j).toLowerCase();
				
				switch(char)
				{
					case 'a':
						a = chan;
					case 'r':
						r = chan;
					case 'g':
						g = chan;
					case 'b':
						b = chan;
					default:
						trace(char);
						throw 'format should only contain letters [argb]';
				}
				
				pix &= Std.int(Math.pow(2, ((format.length - 1 - j) * bitsPerChannel)) - 1);
			}
			
			if (a == null) a = 0xFF;
			
			pix = (a << 24) + (r << 16) + (g << 8) + b;
			pixelOutput.writeInt32(pix);
		}
		
		if (pixelOutput.length / 4 != pixelNum)
		{
			trace(pixelOutput.length);
			trace(pixelNum);
			throw 'Incorrect number of pixels read';
		}
		
		bitmap.setPixels(bitmap.rect, ByteArray.fromBytes(pixelOutput.getBytes()));
	}
	
	public function readIndexed(width:Int, height:Int, bpp:Int, format:String, bpc:Int, palLoc:Int, f:FileInput)
	{
		if (!validFormat(format)) throw 'Invalid colour format';
		if (bpp % 4 != 0) throw 'BPP must be a multiple of 4';
		if (bpp > 32) throw 'BPP can\'t be over 32';
		if (bpc % 8 != 0) throw 'BPC must be a multiple of 8';
		if (bpc > 32) throw 'BPC can\'t be over 32';
		
		//Read the palette first
		var bitsPerChannel:Int = Std.int(bpc / format.length);
		var palLength:Int = Std.int(Math.pow(2, bpp) * (bpc / 8));
		
		var posHolder:Int = f.tell();
		f.seek(palLoc, FileSeek.SeekBegin);
		var bytes:Bytes = f.read(palLength);
		
		var palette:Array<Int> = new Array<Int>();
		var bytepc:Int = Std.int(bpc / 8);
		var i:Int = 0;
		
		while (i < palLength)
		{
			var col:Int = 0;
			
			for (j in 0...bytepc)
			{
				col <<= 8;
				col += bytes.get(i);
				i++;
			}
			
			var a:Int = null;
			var r:Int = 0;
			var g:Int = 0;
			var b:Int = 0;
			
			for (j in 0...format.length)
			{
				var chan:Int = col >>> ((format.length - 1 - j) * bitsPerChannel);
				chan <<= 8 - bitsPerChannel;
				var char:String = format.charAt(j).toLowerCase();
				
				switch(char)
				{
					case 'a':
						a = chan;
					case 'r':
						r = chan;
					case 'g':
						g = chan;
					case 'b':
						b = chan;
					default:
						trace(char);
						throw 'format should only contain letters [argb]';
				}
				
				col &= Std.int(Math.pow(2, ((format.length - 1 - j) * bitsPerChannel)) - 1);
			}
			
			if (a == null) a = 0xFF;
			
			col = (a << 24) + (r << 16) + (g << 8) + b;
			palette.push(col);
		}
		
		//Now for the pixels
		bitmap = new BitmapData(width, height, true, 0);
		var pixelNum:Int = width * height;
		var length:Int = Std.int(pixelNum * (bpp / 8));
		
		f.seek(posHolder, FileSeek.SeekBegin);
		bytes = f.read(length);
		
		var pixelOutput:BytesOutput = new BytesOutput();
		pixelOutput.bigEndian = true;
		var bytepp:Float = bpp / 8;
		i = 0;
		var middle:Bool = false;
		
		while (i < bytes.length)
		{
			var pix:Int = 0;
			
			var j:Float = bytepp;
			
			while(j > 0)
			{
				var b:Int = bytes.get(i);
				
				if (middle)
				{
					pix <<= 4;
					
					if (f.bigEndian) pix += b & 0xF;
					else pix += (b & 0xF0) >> 4;
					
					middle = false;
					j -= 0.5;
					i++;
					continue;
				}
				else
				if (j == 0.5)
				{
					pix <<= 4;
					
					if (f.bigEndian) pix += (b & 0xF0) >> 4;
					else pix += b & 0xF;
					
					middle = true;
				}
				else
				{
					pix <<= 8;
					pix += bytes.get(i);
					i++;
				}
				
				j--;
			}
			
			pixelOutput.writeInt32(palette[pix]);
		}
		
		if (pixelOutput.length / 4 != pixelNum)
		{
			trace(pixelOutput.length);
			trace(pixelNum);
			throw 'Incorrect number of pixels read';
		}
		
		bitmap.setPixels(bitmap.rect, ByteArray.fromBytes(pixelOutput.getBytes()));
	}
	
	public function savePNG(fileName:String, outDir:String)
	{
		if (Path.extension(fileName) != 'png') fileName += '.png';
		
		var filePath:String = Path.addTrailingSlash(outDir) + fileName;
		FileSystem.createDirectory(Path.directory(filePath));
		
		Sys.println('Saving image: $width x $height - $fileName');
		
		var dat:Data = Tools.build32ARGB(bitmap.width, bitmap.height, bitmap.getPixels(bitmap.rect));
		var o:FileOutput = File.write(filePath);
		new Writer(o).write(dat);
		o.close();
	}
	
	public function flip(vert:Bool)
	{
		var newBmp:BitmapData = new BitmapData(bitmap.width, bitmap.height, true, 0);
		
		if (vert)
		{
			for (y in 0...bitmap.height)
			{
				for (x in 0...bitmap.width)
				{
					newBmp.setPixel32(x, newBmp.height - y - 1, bitmap.getPixel32(x, y));
				}
			}
		}
		else
		{
			for (y in 0...bitmap.height)
			{
				for (x in 0...bitmap.width)
				{
					newBmp.setPixel32(newBmp.width - x - 1, y, bitmap.getPixel32(x, y));
				}
			}
		}
		
		bitmap.dispose();
		bitmap = newBmp;
	}
	
	//===Utility Functions===//
	private function validFormat(fmt:String):Bool
	{
		var pattern:EReg = ~/[argb]/;
		
		if (fmt.length == 3)
		{
			pattern = ~/[rgb]/;
		}
		else
		if (fmt.length != 3 && fmt.length != 4) return false;
		
		var ls:String = '';
		
		for (i in 0...fmt.length)
		{
			var c:String = fmt.charAt(i).toLowerCase();
			if (ls.indexOf(c) != -1 || !pattern.match(c)) return false;
			
			ls += c;
		}
		
		return true;
	}
	
	private function bytesToBinary(bytes:Bytes):String
	{
		var binaryString:String = '';
		
		for (i in 0...bytes.length)
		{
			var b:Int = bytes.get(i);
			var bit:Int = 7;
			
			while(bit > -1)
			{
				if (b >= (Math.pow(2, bit))) binaryString += '1';
				else binaryString += '0';
				
				b = b & Std.int(Math.pow(2, bit) - 1);
				bit--;
			}
		}
		
		return binaryString;
	}
	
	private function binaryToInt(binaryString:String):Int
	{
		var num:Int = 0;
		
		var i:Int = 0;
		while (i < binaryString.length)
		{
			trace(i);
			num += Std.int(Std.parseInt(binaryString.charAt(binaryString.length - i - 1)) * Math.pow(2, i));
			i++;
		}
		
		return num;
	}
	
	function get_width():Int 
	{
		return bitmap.width;
	}
	
	function get_height():Int 
	{
		return bitmap.height;
	}
}