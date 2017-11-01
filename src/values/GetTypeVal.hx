package values;

class GetTypeVal extends Value 
{
	public var value(default, null):GetType;
	
	public function new(v:GetType)
	{
		super();
		value = v;
	}
}

enum GetType
{
	Byte;
	Short;
	ThreeByte;
	Long;
	LongLong;
	String;  //Needs to be named the same way as the script uses it
	/*ASize;
	FileName;
	BaseName;
	FilePath;
	FullName;
	FullBaseName;
	Extension;*/
}