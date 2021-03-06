package;

import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.utils.ByteArray;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;

/**
 * Object that holds a read image.
 */
class Image
{
	//Static variables that dictate how images are read in
	static public var bpp:Int = 32;
	static public var format:String = 'ARGB';
	static public var indexed:Bool = false;
	static public var bpc:Int = -1;
	static public var palOff:Int = -1;
	static public var palFile:Int = -1;
	static public var palLengthCheck:Int = 0;
	static public var tileW:Int = 1;
	static public var tileH:Int = 1;
	static public var palTileW:Int = 1;
	static public var palTileH:Int = 1;
	static public var excludedCols:Array<Int> = new Array<Int>();
	static public var excludedIndexed:Bool = false;
	
	/**
	 * The BitmapData of this image.
	 */
	private var bitmap:BitmapData;
	
	public var width(get, null):Int;
	public var height(get, null):Int;
	
	/**
	 * Constructor.
	 */
	public function new(){}
	
	/**
	 * Wrapper function for reading an image.
	 * @param	width
	 * @param	height
	 * @param	fileNum
	 * @param	lengthCheck
	 */
	public function read(width:Int, height:Int, fileNum:Int, lengthCheck:Int)
	{
		if (indexed) readIndexed(width, height, fileNum, lengthCheck);
		else readNoIndex(width, height, fileNum, lengthCheck);
	}
	
	//TODO: I should probably redo these completely, they're a bit ugly
	/**
	 * Read in a non-indexed image
	 * @param	width
	 * @param	height
	 * @param	fileNum
	 * @param	lengthCheck
	 */
	private function readNoIndex(width:Int, height:Int, fileNum:Int, lengthCheck:Int)
	{
		//Some validity checks
		if (!validFormat(format)) throw 'Invalid colour format';
		if (bpp % 8 != 0) throw 'BPP must be a multiple of 8';
		if (bpp > 32) throw 'BPP can\'t be over 32';
		if (width % tileW != 0) throw 'Width must be a multiple of the tile width!';
		if (height % tileH != 0) throw 'Height must be a multiple of the tile height!';
		
		//Calculate the bits per channel
		var bitsPerChannel:Int = Std.int(bpp / format.length);
		
		//Initialize the bitmap and basic info
		bitmap = new BitmapData(width, height, true, 0);
		var pixelNum:Int = width * height;
		var length:Int = Std.int(pixelNum * (bpp / 8));
		
		//Check that our length check is valid
		if (lengthCheck != 0 && length != lengthCheck) throw 'Given length does not match detected length!';
		
		//Get the file and the bytes we're going to read
		var f:FileInput = Commands.files[fileNum].stream;
		var bytes:Bytes = f.read(length);
		
		//Excluded colours (currently unused/incomplete)
		var ex:Array<Int> = new Array<Int>();
		if (!excludedIndexed) ex = excludedCols;
		
		//Tile-related variables
		var ntx:Int = Std.int(width / tileW);//Number of tiles horizontally
		var nty:Int = Std.int(height / tileH);//Number of tiles vertically
		var tx:Int = 0, ty:Int = 0;//X and Y of a tile
		var xintl:Int = -1, yintl:Int = 0;//X and Y within a tile
		
		var x:Int = -1, y:Int = 0;//Overall X and Y
		
		//2D vector that will contain our pixel values
		var pixelVector:Vector<Vector<Int>> = new Vector<Vector<Int>>(height);
		for (v in 0...pixelVector.length)
		{
			pixelVector[v] = new Vector<Int>(width);
		}
		
		//Bytes per pixel
		var bytepp:Int = Std.int(bpp / 8);
		var i:Int = 0;
		
		while (i < bytes.length)
		{
			//Initialize our pixel value
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
			
			if (ex.indexOf(pix) != -1) pix &= 0xFFFFFF;
			
			if (tileH != 1)
			{
				if (++xintl == tileW)
				{
					xintl = 0;
					
					if (++yintl == tileH)
					{
						yintl = 0;
						
						if (++tx == ntx)
						{
							tx = 0;
							
							if (++ty == nty) break;
						}
					}
				}
				
				x = tx * tileW + xintl;
				y = ty * tileH + yintl;
			}
			else
			{
				if (++x == width)
				{
					x = 0;
					
					if (++y == height) break;
				}
			}
			
			pixelVector[y][x] = pix;
		}
		
		var pixelOutput:BytesOutput = new BytesOutput();
		pixelOutput.bigEndian = true;
		
		for (y in 0...height)
		{
			for (x in 0...width)
			{
				pixelOutput.writeInt32(pixelVector[y][x]);
			}
		}
		
		if (pixelOutput.length / 4 != pixelNum)
		{
			trace(pixelOutput.length);
			trace(pixelNum);
			throw 'Incorrect number of pixels read';
		}
		
		bitmap.setPixels(bitmap.rect, ByteArray.fromBytes(pixelOutput.getBytes()));
	}
	
	private function readIndexed(width:Int, height:Int, fileNum:Int, lengthCheck:Int)
	{
		if (!validFormat(format)) throw 'Invalid colour format';
		if (bpp % 4 != 0) throw 'BPP must be a multiple of 4';
		if (bpp > 32) throw 'BPP can\'t be over 32';
		if (bpc % 8 != 0) throw 'BPC must be a multiple of 8';
		if (bpc > 32) throw 'BPC can\'t be over 32';
		if (width % tileW != 0) throw 'Width must be a multiple of the tile width!';
		if (height % tileH != 0) throw 'Height must be a multiple of the tile height!';
		if (16 % palTileW != 0) throw '16 must be divisible by the palette tile width!';
		if (16 % palTileH != 0) throw '16 must be divisible by the palette tile height!';
		
		//Read the palette first
		var bitsPerChannel:Int = Std.int(bpc / format.length);
		var palLength:Int = Std.int(Math.pow(2, bpp) * (bpc / 8));
		
		if (palLengthCheck != 0 && palLength != palLengthCheck) throw 'Given palette length does not match detected length!';
		
		var f:FileInput = Commands.files[fileNum].stream;
		var pf:FileInput = Commands.files[palFile].stream;
		
		var posHolder:Int = f.tell();
		pf.seek(palOff, FileSeek.SeekBegin);
		var bytes:Bytes = pf.read(palLength);
		
		var ex:Array<Int> = excludedCols;
		
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
						throw 'Format should only contain letters [argb]';
				}
				
				col &= Std.int(Math.pow(2, ((format.length - 1 - j) * bitsPerChannel)) - 1);
			}
			
			if (a == null) a = 0xFF;
			
			col = (a << 24) + (r << 16) + (g << 8) + b;
			
			if ((excludedIndexed && ex.indexOf(palette.length) != -1) ||
				(!excludedIndexed && ex.indexOf(col) != -1))
			{
				col &= 0xFFFFFF;
			}
			
			palette.push(col);
		}
		
		//If the palette is tiled, tile it!
		if (palTileH != 1)
		{
			var tiledPal:Vector<Int> = new Vector<Int>(palette.length);
			
			var ntx:Int = Std.int(16 / palTileW);
			var nty:Int = Std.int(16 / palTileH);
			var i:Int = 0;
			
			for (ty in 0...nty)
			{
				for (tx in 0...ntx)
				{
					for (y in 0...palTileH)
					{
						for (x in 0...palTileW)
						{
							tiledPal[(ty * palTileH + y) * 16 + (tx * palTileW + x)] = palette[i++];
						}
					}
				}
			}
			
			palette = tiledPal.toArray();
		}
		
		//Now for the pixels
		bitmap = new BitmapData(width, height, true, 0);
		var pixelNum:Int = width * height;
		var length:Int = Std.int(pixelNum * (bpp / 8));
		
		if (lengthCheck != 0 && length != lengthCheck) throw 'Given length does not match detected length!';
		
		f.seek(posHolder, FileSeek.SeekBegin);
		bytes = f.read(length);
		
		var ntx:Int = Std.int(width / tileW);
		var nty:Int = Std.int(height / tileH);
		var tx:Int = 0, ty:Int = 0;
		var xintl:Int = -1, yintl:Int = 0;
		var x:Int = -1, y:Int = 0;
		
		var pixelVector:Vector<Vector<Int>> = new Vector<Vector<Int>>(height);
		for (v in 0...pixelVector.length)
		{
			pixelVector[v] = new Vector<Int>(width);
		}
		
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
					pix += b;
					i++;
				}
				
				j--;
			}
			
			if (tileH != 1)
			{
				if (++xintl == tileW)
				{
					xintl = 0;
					
					if (++yintl == tileH)
					{
						yintl = 0;
						
						if (++tx == ntx)
						{
							tx = 0;
							
							if (++ty == nty) break;
						}
					}
				}
				
				x = tx * tileW + xintl;
				y = ty * tileH + yintl;
			}
			else
			{
				if (++x == width)
				{
					x = 0;
					
					if (++y == height) break;
				}
			}
			
			pixelVector[y][x] = palette[pix];
		}
		
		var pixelOutput:BytesOutput = new BytesOutput();
		pixelOutput.bigEndian = true;
		
		for (y in 0...height)
		{
			for (x in 0...width)
			{
				pixelOutput.writeInt32(pixelVector[y][x]);
			}
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
	static public function validFormat(fmt:String):Bool
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
	
	public function get_width():Int 
	{
		return bitmap.width;
	}
	
	public function get_height():Int 
	{
		return bitmap.height;
	}
	
	static public function equals(obj1:Dynamic, obj2:Dynamic):Bool
	{
		if (Type.getClass(obj1) != Image || Type.getClass(obj1) != Image) throw 'Must compare images!';
		
		var img1:Image = obj1;
		var img2:Image = obj2;
		
		if (img1 == img2) return true;
		if (img1.width != img2.width || img1.height != img2.height) return false;
		
		return obj1.bitmap.compare(obj2.bitmap) == 0;
	}
}